namespace GuGuTalk.Core.Models;

public sealed record AudioChunk(
    byte[] PcmData,
    double SampleRate,
    int Channels,
    float AudioLevel
);
