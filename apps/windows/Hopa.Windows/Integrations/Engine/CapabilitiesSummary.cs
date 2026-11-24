namespace Hopa.Windows.Integrations.Engine;

/// <summary>What the PC can actually do, read live from the sidecar.</summary>
public sealed record CapabilitiesSummary(
    string Platform,
    string Profile,
    string ModelProvider,
    string ModelName,
    bool ModelReady,
    bool Bridge,
    bool GatewayPaired,
    bool PhoneOnline,
    int Memory,
    int Skills,
    int Recipes,
    int Runs,
    int WindowsApps);
