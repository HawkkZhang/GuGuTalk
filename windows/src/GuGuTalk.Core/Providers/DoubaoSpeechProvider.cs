using System.IO.Compression;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.Channels;
using GuGuTalk.Core.Models;
using Serilog;

namespace GuGuTalk.Core.Providers;

public sealed class DoubaoSpeechProvider : ISpeechProvider, IAsyncDisposable
{
    private static readonly ILogger Logger = Log.ForContext<DoubaoSpeechProvider>();

    private readonly Channel<TranscriptEvent> _channel = Channel.CreateUnbounded<TranscriptEvent>();
    private WebSocketTransport? _transport;
    private int _revision;
    private bool _hasTerminatedSession;
    private bool _hasEmittedFinalResult;
    private string _latestTranscript = "";
    private bool _hasRequestedFinish;
    private CancellationTokenSource? _sessionCts;

    public RecognitionMode Mode => RecognitionMode.Doubao;
    public ChannelReader<TranscriptEvent> Events => _channel.Reader;

    public async Task StartSessionAsync(RecognitionConfig config, CancellationToken ct = default)
    {
        if (!config.DoubaoCredentials.IsConfigured)
            throw new InvalidOperationException("豆包语音识别凭证未配置。");

        if (!Uri.TryCreate(config.DoubaoCredentials.Endpoint, UriKind.Absolute, out var uri))
            throw new InvalidOperationException("豆包 WebSocket 地址无效。");

        _revision = 0;
        _hasTerminatedSession = false;
        _hasEmittedFinalResult = false;
        _latestTranscript = "";
        _hasRequestedFinish = false;
        _sessionCts = CancellationTokenSource.CreateLinkedTokenSource(ct);

        string connectId = Guid.NewGuid().ToString();
        var headers = new Dictionary<string, string>
        {
            ["X-Api-App-Key"] = config.DoubaoCredentials.AppId,
            ["X-Api-Access-Key"] = config.DoubaoCredentials.AccessKey,
            ["X-Api-Resource-Id"] = config.DoubaoCredentials.ResourceId,
            ["X-Api-Connect-Id"] = connectId
        };

        _transport = new WebSocketTransport();
        _transport.OnBinaryMessage += HandleBinaryMessage;
        _transport.OnTextMessage += HandleTextMessage;
        _transport.OnDisconnected += HandleDisconnected;

        await _transport.ConnectAsync(uri, headers, _sessionCts.Token);
        await _channel.Writer.WriteAsync(new TranscriptEvent.SessionStarted(Mode), ct);

        var initialPayload = BuildInitialRequest(config);
        byte[] initialFrame = BuildJsonRequestFrame(initialPayload);
        await _transport.SendBinaryAsync(initialFrame, _sessionCts.Token);

        Logger.Information("Doubao session started. endpoint={Endpoint}", config.DoubaoCredentials.Endpoint);
    }

    public async Task SendAudioAsync(AudioChunk chunk, CancellationToken ct = default)
    {
        if (_transport is null || _sessionCts is null) return;
        byte[] frame = BuildAudioFrame(chunk.PcmData, isLastFrame: false);
        await _transport.SendBinaryAsync(frame, _sessionCts.Token);
    }

    public async Task FinishAudioAsync(CancellationToken ct = default)
    {
        if (_transport is null || _sessionCts is null) return;
        _hasRequestedFinish = true;
        byte[] frame = BuildAudioFrame([], isLastFrame: true);
        await _transport.SendBinaryAsync(frame, _sessionCts.Token);
        Logger.Debug("Sent Doubao finish audio frame");
    }

    public async Task CancelAsync()
    {
        if (_transport is not null)
            await _transport.CloseAsync();
        EmitSessionEndedIfNeeded();
    }

    private void HandleBinaryMessage(byte[] data)
    {
        if (IsLikelyJson(data))
        {
            HandleJsonPayload(data);
            return;
        }

        try
        {
            var response = ParseFrame(data);

            if (response.TransportError is not null)
            {
                _channel.Writer.TryWrite(new TranscriptEvent.SessionFailed($"豆包协议错误：{response.TransportError}"));
                EmitSessionEndedIfNeeded();
                return;
            }

            if (response.ErrorMessage is not null)
            {
                _channel.Writer.TryWrite(new TranscriptEvent.SessionFailed($"豆包识别失败：{response.ErrorMessage}"));
                EmitSessionEndedIfNeeded();
                return;
            }

            if (response.TranscriptText is null)
            {
                if (response.IsTerminal && _hasRequestedFinish && !_hasEmittedFinalResult)
                {
                    _hasEmittedFinalResult = true;
                    _channel.Writer.TryWrite(new TranscriptEvent.FinalTextReady(_latestTranscript));
                    EmitSessionEndedIfNeeded();
                }
                return;
            }

            _latestTranscript = response.TranscriptText;
            _revision++;

            if (response.IsTerminal && _hasRequestedFinish)
            {
                _hasEmittedFinalResult = true;
                _channel.Writer.TryWrite(new TranscriptEvent.FinalTextReady(_latestTranscript));
                EmitSessionEndedIfNeeded();
            }
            else
            {
                _channel.Writer.TryWrite(new TranscriptEvent.PartialTextUpdated(_latestTranscript, _revision));
            }
        }
        catch (Exception ex)
        {
            _channel.Writer.TryWrite(new TranscriptEvent.SessionFailed($"豆包响应解析失败：{ex.Message}"));
            EmitSessionEndedIfNeeded();
        }
    }

    private void HandleTextMessage(string text)
    {
        HandleJsonPayload(Encoding.UTF8.GetBytes(text));
    }

    private void HandleJsonPayload(byte[] data)
    {
        try
        {
            using var doc = JsonDocument.Parse(data);
            var root = doc.RootElement;

            int code = -1;
            if (root.TryGetProperty("code", out var codeProp)) code = codeProp.GetInt32();
            else if (root.TryGetProperty("status_code", out var scProp)) code = scProp.GetInt32();

            string? message = null;
            if (root.TryGetProperty("message", out var msgProp)) message = msgProp.GetString();
            else if (root.TryGetProperty("error", out var errProp)) message = errProp.GetString();
            else if (root.TryGetProperty("msg", out var msgProp2)) message = msgProp2.GetString();

            if (message is not null)
            {
                if (_hasRequestedFinish && !_hasEmittedFinalResult && !string.IsNullOrEmpty(_latestTranscript))
                {
                    _hasEmittedFinalResult = true;
                    _channel.Writer.TryWrite(new TranscriptEvent.FinalTextReady(_latestTranscript));
                    EmitSessionEndedIfNeeded();
                    return;
                }
                _channel.Writer.TryWrite(new TranscriptEvent.SessionFailed($"豆包返回消息[{code}]：{message}"));
                EmitSessionEndedIfNeeded();
                return;
            }

            if (root.TryGetProperty("result", out var resultProp))
            {
                string? transcript = ExtractTranscriptFromResult(resultProp);
                if (!string.IsNullOrEmpty(transcript))
                {
                    _latestTranscript = transcript;
                    _revision++;
                    _channel.Writer.TryWrite(new TranscriptEvent.PartialTextUpdated(_latestTranscript, _revision));
                }
            }
        }
        catch (Exception ex)
        {
            Logger.Warning(ex, "Failed to parse Doubao JSON payload");
        }
    }

    private void HandleDisconnected(Exception? error)
    {
        if (_hasTerminatedSession) return;

        if (_hasRequestedFinish && !_hasEmittedFinalResult && !string.IsNullOrEmpty(_latestTranscript))
        {
            _hasEmittedFinalResult = true;
            _channel.Writer.TryWrite(new TranscriptEvent.FinalTextReady(_latestTranscript));
        }

        if (_hasRequestedFinish || _hasEmittedFinalResult)
        {
            EmitSessionEndedIfNeeded();
            return;
        }

        if (error is not null)
        {
            _channel.Writer.TryWrite(new TranscriptEvent.SessionFailed($"豆包连接中断：{error.Message}"));
        }
        EmitSessionEndedIfNeeded();
    }

    private void EmitSessionEndedIfNeeded()
    {
        if (_hasTerminatedSession) return;
        _hasTerminatedSession = true;
        _channel.Writer.TryWrite(new TranscriptEvent.SessionEnded());
    }

    // --- Frame Builder ---

    private static byte[] BuildJsonRequestFrame(object payload)
    {
        byte[] json = JsonSerializer.SerializeToUtf8Bytes(payload, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
        });
        byte[] compressed = GzipCompress(json);
        return BuildFrame(messageType: 0x01, messageFlags: 0x00, serialization: 0x01, compression: 0x01, compressed);
    }

    private static byte[] BuildAudioFrame(byte[] pcmData, bool isLastFrame)
    {
        byte[] compressed = GzipCompress(pcmData);
        byte flags = isLastFrame ? (byte)0x02 : (byte)0x00;
        return BuildFrame(messageType: 0x02, messageFlags: flags, serialization: 0x00, compression: 0x01, compressed);
    }

    private static byte[] BuildFrame(byte messageType, byte messageFlags, byte serialization, byte compression, byte[] payload)
    {
        using var ms = new MemoryStream();
        ms.WriteByte(0x11);
        ms.WriteByte((byte)((messageType << 4) | messageFlags));
        ms.WriteByte((byte)((serialization << 4) | compression));
        ms.WriteByte(0x00);

        // payload size (big-endian int32)
        int size = payload.Length;
        ms.WriteByte((byte)(size >> 24));
        ms.WriteByte((byte)(size >> 16));
        ms.WriteByte((byte)(size >> 8));
        ms.WriteByte((byte)size);

        ms.Write(payload);
        return ms.ToArray();
    }

    // --- Frame Parser ---

    private static DoubaoFrameResponse ParseFrame(byte[] data)
    {
        if (data.Length < 8)
            throw new InvalidOperationException("豆包响应帧长度不合法。");

        byte messageType = (byte)((data[1] & 0xF0) >> 4);
        byte messageFlags = (byte)(data[1] & 0x0F);
        byte compression = (byte)(data[2] & 0x0F);

        // Error frame
        if (messageType == 0x0F)
        {
            if (data.Length < 12)
                throw new InvalidOperationException("豆包错误帧长度不合法。");

            int payloadSize = ReadInt32BE(data, 8);
            byte[] payload = data[12..Math.Min(12 + payloadSize, data.Length)];
            string message = TryExtractErrorMessage(payload) ?? $"错误码 {ReadInt32BE(data, 4)}";
            return new DoubaoFrameResponse(null, true, null, message);
        }

        // Only handle server response types
        if (messageType != 0x09 && messageType != 0x0B)
            return new DoubaoFrameResponse(null, false, null, null);

        byte[] decompressed = ExtractPayload(data, compression);

        using var doc = JsonDocument.Parse(decompressed);
        var root = doc.RootElement;

        int code = 1000;
        if (root.TryGetProperty("code", out var codeProp)) code = codeProp.GetInt32();

        if (code != 1000 && code != 0)
        {
            string? msg = root.TryGetProperty("message", out var mp) ? mp.GetString() : "请求失败";
            return new DoubaoFrameResponse(null, true, msg, null);
        }

        bool isTerminal = messageFlags == 0x03;
        string? transcript = null;
        if (root.TryGetProperty("result", out var resultProp))
        {
            transcript = ExtractTranscriptFromResult(resultProp);
        }

        return new DoubaoFrameResponse(transcript, isTerminal, null, null);
    }

    private static byte[] ExtractPayload(byte[] data, byte compression)
    {
        // Try offset 4 first (no sequence), then offset 8 (with sequence)
        int[] offsets = [4, 8];
        foreach (int offset in offsets)
        {
            if (data.Length < offset + 4) continue;
            int payloadSize = ReadInt32BE(data, offset);
            int payloadStart = offset + 4;
            if (payloadSize < 0 || data.Length < payloadStart + payloadSize) continue;

            byte[] payload = data[payloadStart..(payloadStart + payloadSize)];
            byte[] decoded = compression == 0x01 ? GzipDecompress(payload) : payload;
            if (IsLikelyJson(decoded)) return decoded;
        }

        throw new InvalidOperationException("豆包响应负载位置无法判定。");
    }

    private static string? ExtractTranscriptFromResult(JsonElement result)
    {
        // result can be object or array
        var results = new List<JsonElement>();
        if (result.ValueKind == JsonValueKind.Array)
        {
            foreach (var item in result.EnumerateArray()) results.Add(item);
        }
        else if (result.ValueKind == JsonValueKind.Object)
        {
            results.Add(result);
        }

        // Extract text from result objects
        var texts = new List<string>();
        foreach (var r in results)
        {
            if (r.TryGetProperty("text", out var textProp))
            {
                string? t = textProp.GetString()?.Trim();
                if (!string.IsNullOrEmpty(t)) texts.Add(t);
            }
        }

        // Also check utterances
        if (texts.Count == 0)
        {
            foreach (var r in results)
            {
                if (r.TryGetProperty("utterances", out var uttProp) && uttProp.ValueKind == JsonValueKind.Array)
                {
                    foreach (var utt in uttProp.EnumerateArray())
                    {
                        if (utt.TryGetProperty("text", out var uttText))
                        {
                            string? t = uttText.GetString()?.Trim();
                            if (!string.IsNullOrEmpty(t)) texts.Add(t);
                        }
                    }
                }
            }
        }

        return texts.Count > 0 ? string.Join("", texts) : null;
    }

    private static string? TryExtractErrorMessage(byte[] payload)
    {
        try
        {
            using var doc = JsonDocument.Parse(payload);
            var root = doc.RootElement;
            if (root.TryGetProperty("message", out var msg)) return msg.GetString();
            if (root.TryGetProperty("error", out var err)) return err.GetString();
        }
        catch { }
        return Encoding.UTF8.GetString(payload);
    }

    // --- Helpers ---

    private static byte[] GzipCompress(byte[] data)
    {
        using var output = new MemoryStream();
        using (var gzip = new GZipStream(output, CompressionLevel.Fastest))
        {
            gzip.Write(data);
        }
        return output.ToArray();
    }

    private static byte[] GzipDecompress(byte[] data)
    {
        using var input = new MemoryStream(data);
        using var gzip = new GZipStream(input, CompressionMode.Decompress);
        using var output = new MemoryStream();
        gzip.CopyTo(output);
        return output.ToArray();
    }

    private static int ReadInt32BE(byte[] data, int offset) =>
        (data[offset] << 24) | (data[offset + 1] << 16) | (data[offset + 2] << 8) | data[offset + 3];

    private static bool IsLikelyJson(byte[] data)
    {
        foreach (byte b in data)
        {
            if (b == ' ' || b == '\t' || b == '\n' || b == '\r') continue;
            return b == '{' || b == '[';
        }
        return false;
    }

    private static object BuildInitialRequest(RecognitionConfig config) => new
    {
        user = new
        {
            uid = Environment.MachineName,
            did = Environment.MachineName,
            platform = "Windows",
            sdk_version = "GuGuTalk/1.0",
            app_version = "1.0"
        },
        audio = new
        {
            format = "pcm",
            codec = "raw",
            rate = (int)config.SampleRate,
            bits = 16,
            channel = 1
        },
        request = new
        {
            model_name = "bigmodel",
            enable_nonstream = true,
            show_utterances = true,
            result_type = "full",
            enable_itn = true,
            enable_ddc = false,
            enable_punc = true,
            show_speech_rate = false,
            show_volume = false,
            enable_lid = false,
            enable_emotion_detection = false
        }
    };

    public async ValueTask DisposeAsync()
    {
        _sessionCts?.Cancel();
        if (_transport is not null)
            await _transport.DisposeAsync();
        _sessionCts?.Dispose();
    }
}

internal sealed record DoubaoFrameResponse(
    string? TranscriptText,
    bool IsTerminal,
    string? ErrorMessage,
    string? TransportError
);
