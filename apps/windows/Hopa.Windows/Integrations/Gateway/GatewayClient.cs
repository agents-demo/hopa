using System.IO;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json.Nodes;

namespace Hopa.Windows.Integrations.Gateway;

/// <summary>
/// P4: the Windows half of the backend gateway. Pairing is HTTP; the live task
/// and approval traffic is one WebSocket. The host owns the token (Credential
/// Manager) and the sidecar only ever learns whether a phone peer is reachable.
/// </summary>
public sealed partial class GatewayClient : IAsyncDisposable, IApprovalPhone
{
    private const int MaxFrameBytes = 65_536;

    private readonly SemaphoreSlim sendGate = new(1, 1);
    private readonly object pendingGate = new();
    private readonly HashSet<string> peers = new(StringComparer.Ordinal);
    private ClientWebSocket? socket;
    private CancellationTokenSource? cts;
    private Task? loop;
    private PendingOperation? waiting;

    public event Action? StateChanged;

    /// <summary>A task the other device started; the host may show or run it.</summary>
    public event Action<JsonObject>? TaskReceived;

    /// <summary>A phone or PC asks this device to approve a step.</summary>
    public event Action<JsonObject>? ApprovalReceived;

    public string DeviceId { get; private set; } = "";
    public string PhoneDeviceId { get; private set; } = "";
    public string Status { get; private set; } = "not paired";
    public bool IsLive { get; private set; }
    public bool Paired => GatewayCredentials.Load() != null;
    public bool HasPhone => IsLive && PhoneDeviceId.Length > 0;

    public void Start()
    {
        if (loop != null)
        {
            return;
        }

        cts = new CancellationTokenSource();
        loop = Task.Run(() => RunAsync(cts.Token));
    }

    public async Task StopAsync()
    {
        cts?.Cancel();
        try
        {
            if (loop != null)
            {
                await loop;
            }
        }
        catch (OperationCanceledException)
        {
            // Expected on shutdown.
        }
        loop = null;
        cts = null;
    }




















    public async ValueTask DisposeAsync()
    {
        await StopAsync();
        socket?.Dispose();
        sendGate.Dispose();
    }

    private sealed class PendingOperation
    {
        public TaskCompletionSource<string> Ack { get; } =
            new(TaskCreationOptions.RunContinuationsAsynchronously);

        public TaskCompletionSource<JsonObject> Result { get; } =
            new(TaskCreationOptions.RunContinuationsAsynchronously);

        public string? TaskId { get; set; }
    }
}
