using System.Text.Json.Nodes;

namespace Hopa.Windows.Integrations.Engine;

/// <summary>The memory family: facts the user asked HOPA to keep.</summary>
public sealed partial class EngineHostClient
{
    public async Task<List<string>> ListMemoryAsync()
    {
        var response = await RequestAsync("memory.list", new JsonObject(), TimeSpan.FromSeconds(10));
        return Memory(response);
    }

    public async Task<List<string>> AddMemoryAsync(string text)
    {
        var response = await RequestAsync(
            "memory.add",
            new JsonObject { ["text"] = text },
            TimeSpan.FromSeconds(10));
        return Memory(response);
    }

    public async Task<List<string>> DeleteMemoryAsync(string text)
    {
        var response = await RequestAsync(
            "memory.delete",
            new JsonObject { ["text"] = text },
            TimeSpan.FromSeconds(10));
        return Memory(response);
    }

    public async Task<List<string>> ClearMemoryAsync()
    {
        var response = await RequestAsync("memory.clear", new JsonObject(), TimeSpan.FromSeconds(10));
        return Memory(response);
    }

    private static List<string> Memory(JsonObject response)
    {
        Error(response);
        var items = new List<string>();
        if (response["items"] is JsonArray array)
        {
            foreach (var item in array)
            {
                if (item?.GetValue<string>() is { Length: > 0 } fact)
                {
                    items.Add(fact);
                }
            }
        }

        return items;
    }

    private static void Error(JsonObject response)
    {
        if (response["ok"]?.GetValue<bool>() == false)
        {
            throw new InvalidOperationException(
                response["error"]?.GetValue<string>() ?? "the sidecar refused the request");
        }
    }
}
