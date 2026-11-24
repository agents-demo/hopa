using System.Text.Json.Nodes;

namespace Hopa.Windows.Integrations.Engine;

/// <summary>The live capability probe for the Windows capabilities screen.</summary>
public sealed partial class EngineHostClient
{
    public async Task<CapabilitiesSummary> CapabilitiesAsync()
    {
        var response = await RequestAsync("capabilities.summary", new JsonObject(), TimeSpan.FromSeconds(10));
        Error(response);
        return new CapabilitiesSummary(
            response["platform"]?.GetValue<string>() ?? "windows",
            response["profile"]?.GetValue<string>() ?? "everyday",
            response["modelProvider"]?.GetValue<string>() ?? "",
            response["modelName"]?.GetValue<string>() ?? "",
            response["modelReady"]?.GetValue<bool>() ?? false,
            response["bridge"]?.GetValue<bool>() ?? false,
            response["gatewayPaired"]?.GetValue<bool>() ?? false,
            response["phoneOnline"]?.GetValue<bool>() ?? false,
            response["memory"]?.GetValue<int>() ?? 0,
            response["skills"]?.GetValue<int>() ?? 0,
            response["recipes"]?.GetValue<int>() ?? 0,
            response["runs"]?.GetValue<int>() ?? 0,
            response["windowsApps"]?.GetValue<int>() ?? 0);
    }
}
