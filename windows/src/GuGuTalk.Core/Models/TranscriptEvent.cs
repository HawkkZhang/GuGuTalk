namespace GuGuTalk.Core.Models;

public abstract record TranscriptEvent
{
    public sealed record SessionStarted(RecognitionMode Mode) : TranscriptEvent;
    public sealed record AudioLevelUpdated(float Level) : TranscriptEvent;
    public sealed record PartialTextUpdated(string Text, int Revision) : TranscriptEvent;
    public sealed record FinalTextReady(string Text) : TranscriptEvent;
    public sealed record ProviderSwitched(RecognitionMode From, RecognitionMode To, string Reason) : TranscriptEvent;
    public sealed record SessionFailed(string Message) : TranscriptEvent;
    public sealed record SessionEnded() : TranscriptEvent;
}
