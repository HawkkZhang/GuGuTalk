using System.Net.WebSockets;
using System.Text;
using Serilog;

namespace GuGuTalk.Core.Providers;

internal sealed class WebSocketTransport : IAsyncDisposable
{
    private static readonly ILogger Logger = Log.ForContext<WebSocketTransport>();

    private readonly ClientWebSocket _ws = new();
    private readonly SemaphoreSlim _sendLock = new(1, 1);
    private CancellationTokenSource? _receiveCts;
    private Task? _receiveTask;

    public event Action<byte[]>? OnBinaryMessage;
    public event Action<string>? OnTextMessage;
    public event Action<Exception?>? OnDisconnected;

    public bool IsConnected => _ws.State == WebSocketState.Open;

    public async Task ConnectAsync(Uri uri, Dictionary<string, string>? headers = null, CancellationToken ct = default)
    {
        if (headers is not null)
        {
            foreach (var (key, value) in headers)
                _ws.Options.SetRequestHeader(key, value);
        }

        Logger.Information("Connecting WebSocket to {Uri}", uri);
        await _ws.ConnectAsync(uri, ct);
        Logger.Information("WebSocket connected");

        _receiveCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        _receiveTask = ReceiveLoopAsync(_receiveCts.Token);
    }

    public async Task SendBinaryAsync(byte[] data, CancellationToken ct = default)
    {
        await _sendLock.WaitAsync(ct);
        try
        {
            await _ws.SendAsync(data.AsMemory(), WebSocketMessageType.Binary, true, ct);
        }
        finally
        {
            _sendLock.Release();
        }
    }

    public async Task SendTextAsync(string text, CancellationToken ct = default)
    {
        await _sendLock.WaitAsync(ct);
        try
        {
            var bytes = Encoding.UTF8.GetBytes(text);
            await _ws.SendAsync(bytes.AsMemory(), WebSocketMessageType.Text, true, ct);
        }
        finally
        {
            _sendLock.Release();
        }
    }

    public async Task CloseAsync(CancellationToken ct = default)
    {
        if (_ws.State == WebSocketState.Open)
        {
            try
            {
                await _ws.CloseAsync(WebSocketCloseStatus.NormalClosure, "done", ct);
            }
            catch (Exception ex)
            {
                Logger.Debug(ex, "WebSocket close encountered error");
            }
        }

        _receiveCts?.Cancel();
        if (_receiveTask is not null)
        {
            try { await _receiveTask; } catch { /* expected */ }
        }
    }

    private async Task ReceiveLoopAsync(CancellationToken ct)
    {
        var buffer = new byte[8192];
        var messageBuffer = new MemoryStream();

        try
        {
            while (!ct.IsCancellationRequested && _ws.State == WebSocketState.Open)
            {
                var result = await _ws.ReceiveAsync(buffer.AsMemory(), ct);

                if (result.MessageType == WebSocketMessageType.Close)
                {
                    Logger.Information("WebSocket received close frame");
                    break;
                }

                messageBuffer.Write(buffer, 0, result.Count);

                if (result.EndOfMessage)
                {
                    var data = messageBuffer.ToArray();
                    messageBuffer.SetLength(0);

                    if (result.MessageType == WebSocketMessageType.Text)
                    {
                        OnTextMessage?.Invoke(Encoding.UTF8.GetString(data));
                    }
                    else
                    {
                        OnBinaryMessage?.Invoke(data);
                    }
                }
            }
        }
        catch (OperationCanceledException) { }
        catch (WebSocketException ex)
        {
            Logger.Warning(ex, "WebSocket receive error");
            OnDisconnected?.Invoke(ex);
            return;
        }

        OnDisconnected?.Invoke(null);
    }

    public async ValueTask DisposeAsync()
    {
        await CloseAsync(CancellationToken.None);
        _receiveCts?.Dispose();
        _ws.Dispose();
        _sendLock.Dispose();
    }
}
