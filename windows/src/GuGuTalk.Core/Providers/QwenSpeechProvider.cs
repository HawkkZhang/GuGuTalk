using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.Channels;
using GuGuTalk.Core.Models;
using Serilog;

namespace GuGuTalk.Core.Providers;

public sealed class QwenSpeechProvider : ISpeechProvider, IAsyncDisposable
{
    private static readonly ILogger Logger = Log.ForContext<QwenSpeechProvider>();

    private readonly Channel<TranscriptEvent> _channel = Channel.CreateUnbounded<TranscriptEvent>();
    private WebSocketTransport? _transport;
    private int _revision;
    private EndpointingPolicy _endpointingPolicy;
    private string _accumulatedTranscript = "";
    private string _latestTranscript = "";
    private bool _hasRequestedFinish;
    private bool _hasEmittedFinalResult;
    private bool _hasTerminatedSession;
    private CancellationTokenSource? _sessionCts;

    public RecognitionMode Mode => RecognitionMode.Qwen;
    public ChannelReader<TranscriptEvent> Events => _channel.Reader;

    public async Task StartSessionAsync(RecognitionConfig config, CancellationToken ct = default)
    {
        if (!config.QwenCredentials.IsConfigured)
            throw new InvalidOperationException("千问语音识别凭证未配置。");

        var uri = MakeRealtimeUri(config.QwenCredentials.Endpoint, config.QwenCredentials.Model);
        if (uri is null)
            throw new InvalidOperationException("千问 WebSocket 地址无效。");

        _revision = 0;
        _endpointingPolicy = config.Endpointing;
        _accumulatedTranscript = "";
        _latestTranscript = "";
        _hasRequestedFinish = false;
        _hasEmittedFinalResult = false;
        _hasTerminatedSession = false;
        _sessionCts = CancellationTokenSource.CreateLinkedTokenSource(ct);

        _transport = new WebSocketTransport();
        _transport.OnTextMessage += HandleMessage;
        _transport.OnDisconnected += HandleDisconnected;

        var headers = new Dictionary<string, string>
        {
            ["Authorization"] = $"Bearer {config.QwenCredentials.ApiKey}",
            ["OpenAI-Beta"] = "realtime=v1"
        };

        await _transport.ConnectAsync(uri, headers, _sessionCts.Token);
        await _channel.Writer.WriteAsync(new TranscriptEvent.SessionStarted(Mode), ct);

        var sessionUpdate = BuildSessionUpdate(config);
        await _transport.SendTextAsync(sessionUpdate, _sessionCts.Token);
    }

    public async Task SendAudioAsync(AudioChunk chunk, CancellationToken ct = default)
    {
        if (_transport is null || _sessionCts is null) return;

        string base64 = Convert.ToBase64String(chunk.PcmData);
        string json = JsonSerializer.Serialize(new
        {
            event_id = Guid.NewGuid().ToString(),
            type = "input_audio_buffer.append",
            audio = base64
        });

        await _transport.SendTextAsync(json, _sessionCts.Token);
    }

    public async Task FinishAudioAsync(CancellationToken ct = default)
    {
        if (_transport is null || _sessionCts is null) return;

        _hasRequestedFinish = true;

        if (_endpointingPolicy == EndpointingPolicy.Manual)
        {
            string commit = JsonSerializer.Serialize(new
            {
                event_id = Guid.NewGuid().ToString(),
                type = "input_audio_buffer.commit"
            });
            await _transport.SendTextAsync(commit, _sessionCts.Token);
        }

        string finish = JsonSerializer.Serialize(new
        {
            event_id = Guid.NewGuid().ToString(),
            type = "session.finish"
        });
        await _transport.SendTextAsync(finish, _sessionCts.Token);
    }

    public async Task CancelAsync()
    {
        if (_transport is not null)
        {
            await _transport.CloseAsync();
        }
        EmitSessionEndedIfNeeded();
    }

    private void HandleMessage(string text)
    {
        try
        {
            var evt = JsonSerializer.Deserialize<QwenServerEvent>(text);
            if (evt is null) return;

            switch (evt.Type)
            {
                case "conversation.item.input_audio_transcription.text":
                    _revision++;
                    string turnText = (evt.Stash ?? "") + (evt.Text ?? "");
                    _latestTranscript = _accumulatedTranscript + turnText;
                    _channel.Writer.TryWrite(new TranscriptEvent.PartialTextUpdated(_latestTranscript, _revision));
                    break;

                case "conversation.item.input_audio_transcription.completed":
                    string turnResult = evt.Transcript ?? evt.Text ?? "";
                    _accumulatedTranscript += turnResult;
                    _latestTranscript = _accumulatedTranscript;
                    if (_hasRequestedFinish && !_hasEmittedFinalResult)
                    {
                        _hasEmittedFinalResult = true;
                        _channel.Writer.TryWrite(new TranscriptEvent.FinalTextReady(_accumulatedTranscript));
                    }
                    else
                    {
                        _revision++;
                        _channel.Writer.TryWrite(new TranscriptEvent.PartialTextUpdated(_accumulatedTranscript, _revision));
                    }
                    break;

                case "conversation.item.input_audio_transcription.failed":
                    string failMsg = evt.Error?.Message ?? evt.Message ?? "识别失败";
                    _channel.Writer.TryWrite(new TranscriptEvent.SessionFailed($"千问识别失败：{failMsg}"));
                    EmitSessionEndedIfNeeded();
                    break;

                case "session.created":
                    break;

                case "session.finished":
                    if (_hasRequestedFinish && !_hasEmittedFinalResult)
                    {
                        string finalText = string.IsNullOrEmpty(_latestTranscript) ? _accumulatedTranscript : _latestTranscript;
                        if (!string.IsNullOrEmpty(finalText))
                        {
                            _hasEmittedFinalResult = true;
                            _channel.Writer.TryWrite(new TranscriptEvent.FinalTextReady(finalText));
                        }
                    }
                    EmitSessionEndedIfNeeded();
                    break;

                case "error":
                    string errMsg = evt.Message ?? evt.Error?.Message ?? "未知错误";
                    _channel.Writer.TryWrite(new TranscriptEvent.SessionFailed($"千问识别失败：{errMsg}"));
                    EmitSessionEndedIfNeeded();
                    break;
            }
        }
        catch (JsonException ex)
        {
            Logger.Warning(ex, "Failed to parse Qwen server event");
            _channel.Writer.TryWrite(new TranscriptEvent.SessionFailed($"千问响应解析失败：{ex.Message}"));
            EmitSessionEndedIfNeeded();
        }
    }

    private void HandleDisconnected(Exception? error)
    {
        if (_hasRequestedFinish || _hasEmittedFinalResult)
        {
            if (!_hasEmittedFinalResult)
            {
                string finalText = string.IsNullOrEmpty(_latestTranscript) ? _accumulatedTranscript : _latestTranscript;
                if (!string.IsNullOrEmpty(finalText))
                {
                    _hasEmittedFinalResult = true;
                    _channel.Writer.TryWrite(new TranscriptEvent.FinalTextReady(finalText));
                }
            }
            EmitSessionEndedIfNeeded();
            return;
        }

        if (error is not null)
        {
            _channel.Writer.TryWrite(new TranscriptEvent.SessionFailed($"千问连接中断：{error.Message}"));
        }
        EmitSessionEndedIfNeeded();
    }

    private void EmitSessionEndedIfNeeded()
    {
        if (_hasTerminatedSession) return;
        _hasTerminatedSession = true;
        _channel.Writer.TryWrite(new TranscriptEvent.SessionEnded());
    }

    private static string BuildSessionUpdate(RecognitionConfig config)
    {
        var turnDetection = config.Endpointing == EndpointingPolicy.VoiceActivityDetection
            ? new { type = "server_vad", threshold = config.PartialResultsEnabled ? 0.0 : 0.5, silence_duration_ms = 800 }
            : (object?)null;

        string language = MapLanguage(config.LanguageCode);

        var payload = new
        {
            event_id = Guid.NewGuid().ToString(),
            type = "session.update",
            session = new
            {
                modalities = new[] { "text" },
                input_audio_format = "pcm",
                sample_rate = (int)config.SampleRate,
                input_audio_transcription = new { language },
                turn_detection = turnDetection
            }
        };

        return JsonSerializer.Serialize(payload);
    }

    private static Uri? MakeRealtimeUri(string endpoint, string model)
    {
        if (!Uri.TryCreate(endpoint, UriKind.Absolute, out var baseUri)) return null;

        var builder = new UriBuilder(baseUri);
        string query = builder.Query.TrimStart('?');
        if (!query.Contains("model="))
        {
            query = string.IsNullOrEmpty(query) ? $"model={model}" : $"{query}&model={model}";
        }
        builder.Query = query;
        return builder.Uri;
    }

    private static string MapLanguage(string languageCode) => languageCode.ToLowerInvariant() switch
    {
        "zh-cn" or "zh" => "zh",
        "en-us" or "en" => "en",
        "ja-jp" or "ja" => "ja",
        _ => "zh"
    };

    public async ValueTask DisposeAsync()
    {
        _sessionCts?.Cancel();
        if (_transport is not null)
            await _transport.DisposeAsync();
        _sessionCts?.Dispose();
    }
}

internal sealed class QwenServerEvent
{
    [JsonPropertyName("type")]
    public string Type { get; set; } = "";

    [JsonPropertyName("text")]
    public string? Text { get; set; }

    [JsonPropertyName("stash")]
    public string? Stash { get; set; }

    [JsonPropertyName("transcript")]
    public string? Transcript { get; set; }

    [JsonPropertyName("message")]
    public string? Message { get; set; }

    [JsonPropertyName("error")]
    public QwenErrorPayload? Error { get; set; }
}

internal sealed class QwenErrorPayload
{
    [JsonPropertyName("message")]
    public string? Message { get; set; }
}
