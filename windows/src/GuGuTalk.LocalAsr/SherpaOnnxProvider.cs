using System.Threading.Channels;
using GuGuTalk.Core;
using GuGuTalk.Core.Models;
using Serilog;
using SherpaOnnx;

namespace GuGuTalk.LocalAsr;

public sealed class SherpaOnnxProvider : ISpeechProvider
{
    private static readonly ILogger Logger = Log.ForContext<SherpaOnnxProvider>();

    private readonly Channel<TranscriptEvent> _channel = Channel.CreateUnbounded<TranscriptEvent>();
    private OnlineRecognizer? _recognizer;
    private OnlineStream? _stream;
    private int _revision;
    private string _lastText = "";
    private bool _hasTerminated;

    public RecognitionMode Mode => RecognitionMode.Local;
    public ChannelReader<TranscriptEvent> Events => _channel.Reader;

    public Task StartSessionAsync(RecognitionConfig config, CancellationToken ct = default)
    {
        var tokensPath = ModelManager.GetTokensPath();
        if (tokensPath is null)
            throw new InvalidOperationException("本地识别模型未找到。安装包中应已包含模型，请检查安装目录。");

        var modelDir = Path.GetDirectoryName(tokensPath)!;
        Logger.Information("Loading local ASR model from: {Dir}", modelDir);

        var onlineModelConfig = new OnlineModelConfig();
        onlineModelConfig.Tokens = tokensPath;
        onlineModelConfig.NumThreads = 4;
        onlineModelConfig.Provider = "cpu";

        // Try transducer (zipformer) - file name varies between models
        var encoder = FindFile(modelDir, "encoder*.onnx");
        var decoder = FindFile(modelDir, "decoder*.onnx");
        var joiner = FindFile(modelDir, "joiner*.onnx");

        if (encoder is not null && decoder is not null && joiner is not null)
        {
            onlineModelConfig.Transducer.Encoder = encoder;
            onlineModelConfig.Transducer.Decoder = decoder;
            onlineModelConfig.Transducer.Joiner = joiner;
            Logger.Information("Detected transducer model");
        }
        else if (encoder is not null && decoder is not null)
        {
            onlineModelConfig.Paraformer.Encoder = encoder;
            onlineModelConfig.Paraformer.Decoder = decoder;
            Logger.Information("Detected paraformer model");
        }
        else
        {
            throw new InvalidOperationException($"未找到有效的识别模型文件 (位置: {modelDir})");
        }

        var recognizerConfig = new OnlineRecognizerConfig();
        recognizerConfig.ModelConfig = onlineModelConfig;
        recognizerConfig.FeatConfig.SampleRate = (int)config.SampleRate;
        recognizerConfig.FeatConfig.FeatureDim = 80;
        recognizerConfig.DecodingMethod = "greedy_search";
        recognizerConfig.EnableEndpoint = 1;
        recognizerConfig.Rule1MinTrailingSilence = 2.4f;
        recognizerConfig.Rule2MinTrailingSilence = 1.2f;
        recognizerConfig.Rule3MinUtteranceLength = 20.0f;

        _recognizer = new OnlineRecognizer(recognizerConfig);
        _stream = _recognizer.CreateStream();
        _revision = 0;
        _lastText = "";
        _hasTerminated = false;

        _channel.Writer.TryWrite(new TranscriptEvent.SessionStarted(Mode));
        Logger.Information("Local ASR session started with sherpa-onnx");

        return Task.CompletedTask;
    }

    public Task SendAudioAsync(AudioChunk chunk, CancellationToken ct = default)
    {
        if (_recognizer is null || _stream is null) return Task.CompletedTask;

        float[] samples = ConvertPcm16ToFloat(chunk.PcmData);
        _stream.AcceptWaveform((int)chunk.SampleRate, samples);

        while (_recognizer.IsReady(_stream))
        {
            _recognizer.Decode(_stream);
        }

        string text = _recognizer.GetResult(_stream).Text.Trim();
        if (!string.IsNullOrEmpty(text) && text != _lastText)
        {
            _lastText = text;
            _revision++;
            _channel.Writer.TryWrite(new TranscriptEvent.PartialTextUpdated(text, _revision));
        }

        if (_recognizer.IsEndpoint(_stream))
        {
            string endpointText = _recognizer.GetResult(_stream).Text.Trim();
            if (!string.IsNullOrEmpty(endpointText))
            {
                _lastText = endpointText;
            }
            _recognizer.Reset(_stream);
        }

        return Task.CompletedTask;
    }

    public Task FinishAudioAsync(CancellationToken ct = default)
    {
        if (_recognizer is null || _stream is null) return Task.CompletedTask;

        // Feed tail silence to trigger endpoint
        float[] silence = new float[16000]; // 1 second of silence
        _stream.AcceptWaveform(16000, silence);
        _stream.InputFinished();

        while (_recognizer.IsReady(_stream))
        {
            _recognizer.Decode(_stream);
        }

        string finalText = _recognizer.GetResult(_stream).Text.Trim();
        if (string.IsNullOrEmpty(finalText))
        {
            finalText = _lastText;
        }

        if (!string.IsNullOrEmpty(finalText))
        {
            _channel.Writer.TryWrite(new TranscriptEvent.FinalTextReady(finalText));
        }

        EmitSessionEndedIfNeeded();
        return Task.CompletedTask;
    }

    public Task CancelAsync()
    {
        EmitSessionEndedIfNeeded();
        Cleanup();
        return Task.CompletedTask;
    }

    private void EmitSessionEndedIfNeeded()
    {
        if (_hasTerminated) return;
        _hasTerminated = true;
        _channel.Writer.TryWrite(new TranscriptEvent.SessionEnded());
    }

    private void Cleanup()
    {
        _stream?.Dispose();
        _stream = null;
        _recognizer?.Dispose();
        _recognizer = null;
    }

    private static float[] ConvertPcm16ToFloat(byte[] pcm16)
    {
        int sampleCount = pcm16.Length / 2;
        float[] samples = new float[sampleCount];
        for (int i = 0; i < sampleCount; i++)
        {
            short sample = (short)(pcm16[i * 2] | (pcm16[i * 2 + 1] << 8));
            samples[i] = sample / 32768.0f;
        }
        return samples;
    }

    private static string? FindFile(string dir, string searchPattern)
    {
        try
        {
            var matches = Directory.GetFiles(dir, searchPattern);
            // For zipformer: prefer "int8" quantized variants if both present
            return matches
                .OrderByDescending(p => p.Contains("int8", StringComparison.OrdinalIgnoreCase))
                .FirstOrDefault();
        }
        catch
        {
            return null;
        }
    }
}
