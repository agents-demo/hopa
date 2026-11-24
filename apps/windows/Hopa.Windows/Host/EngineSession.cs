using System.Text.Json.Nodes;
using Hopa.Windows.Integrations.Engine;
using Hopa.Windows.Integrations.Gateway;

namespace Hopa.Windows.Host;

/// <summary>
/// The two processes of one host session: the Kotlin engine host client and the
/// gateway. It owns their construction, events and shutdown; the window owns the
/// UI reactions.
/// </summary>
public sealed class EngineSession : IAsyncDisposable
{
    public EngineSession()
    {
        Client = new EngineHostClient();
        Client.LogReceived += line => Log?.Invoke(line);
        Client.DeviceRequested += message => DeviceRequested?.Invoke(message);
        Client.ApprovalRequested += message => ApprovalRequested?.Invoke(message);
        Client.SessionUpdated += message => SessionUpdated?.Invoke(message);
        Client.StepReceived += message => StepReceived?.Invoke(message);
        Gateway = CreateGateway();
    }

    public EngineHostClient Client { get; }

    public GatewayClient Gateway { get; private set; }

    public event Action<string>? Log;

    public event Action<JsonObject>? DeviceRequested;

    public event Action<JsonObject>? ApprovalRequested;

    public event Action<JsonObject>? SessionUpdated;

    public event Action<JsonObject>? StepReceived;

    /// <summary>Raised for the current gateway whenever its status or phone set changes.</summary>
    public event Action<GatewayClient>? GatewayStateChanged;

    public event Action<JsonObject>? TaskReceived;

    /// <summary>Starts the gateway after the window has subscribed to its events.</summary>
    public void Start() => Gateway.Start();

    public async Task RestartGatewayAsync()
    {
        await Gateway.DisposeAsync();
        Gateway = CreateGateway();
        Gateway.Start();
    }

    public async ValueTask DisposeAsync()
    {
        await Gateway.DisposeAsync();
        await Client.DisposeAsync();
    }

    private GatewayClient CreateGateway()
    {
        var gateway = new GatewayClient();
        gateway.StateChanged += () => GatewayStateChanged?.Invoke(gateway);
        gateway.TaskReceived += message => TaskReceived?.Invoke(message);
        return gateway;
    }
}
