using System.Threading.Channels;
using GuGuTalk.Core.Models;

namespace GuGuTalk.Core;

public interface ISpeechProvider
{
    RecognitionMode Mode { get; }
    ChannelReader<TranscriptEvent> Events { get; }
    Task StartSessionAsync(RecognitionConfig config, CancellationToken ct = default);
    Task SendAudioAsync(AudioChunk chunk, CancellationToken ct = default);
    Task FinishAudioAsync(CancellationToken ct = default);
    Task CancelAsync();
}
