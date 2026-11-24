using System.Text.Json.Nodes;

namespace Hopa.Windows.Integrations.Engine;

/// <summary>The finished turns, read from the sidecar's record store.</summary>
public sealed partial class EngineHostClient
{
    public async Task<List<HistoryEntry>> ListHistoryAsync()
    {
        var response = await RequestAsync("history.list", new JsonObject(), TimeSpan.FromSeconds(10));
        return History(response);
    }

    private static List<HistoryEntry> History(JsonObject response)
    {
        Error(response);
        var items = new List<HistoryEntry>();
        if (response["items"] is not JsonArray array)
        {
            return items;
        }

        foreach (var item in array)
        {
            if (item is not JsonObject row)
            {
                continue;
            }

            items.Add(new HistoryEntry(
                row["conversationId"]?.GetValue<string>() ?? "",
                row["title"]?.GetValue<string>() ?? "New chat",
                row["runId"]?.GetValue<string>() ?? "",
                row["createdAt"]?.GetValue<long>() ?? 0,
                row["steps"]?.GetValue<int>() ?? 0,
                row["executed"]?.GetValue<int>() ?? 0,
                row["failed"]?.GetValue<int>() ?? 0));
        }

        return items;
    }
}
