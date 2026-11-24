using System.Text.Json.Nodes;

namespace Hopa.Windows.Integrations.Engine;

/// <summary>The usage counters, computed by the sidecar from the record chain.</summary>
public sealed partial class EngineHostClient
{
    public async Task<UsageSummary> UsageAsync()
    {
        var response = await RequestAsync("usage.summary", new JsonObject(), TimeSpan.FromSeconds(10));
        Error(response);
        var actions = new List<UsageAction>();
        if (response["topActions"] is JsonArray array)
        {
            foreach (var item in array)
            {
                if (item is JsonObject row)
                {
                    actions.Add(new UsageAction(
                        row["kind"]?.GetValue<string>() ?? "",
                        row["count"]?.GetValue<int>() ?? 0));
                }
            }
        }

        return new UsageSummary(
            response["total"]?.GetValue<int>() ?? 0,
            response["executed"]?.GetValue<int>() ?? 0,
            response["failed"]?.GetValue<int>() ?? 0,
            response["payments"]?.GetValue<int>() ?? 0,
            response["lastSevenDays"]?.GetValue<int>() ?? 0,
            actions);
    }
}
