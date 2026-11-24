using System.Text.Json.Nodes;

namespace Hopa.Windows.Integrations.Engine;

/// <summary>The saved repetitions, read from the shared recipe store.</summary>
public sealed partial class EngineHostClient
{
    public async Task<List<RecipeSummary>> ListRecipesAsync()
    {
        var response = await RequestAsync("recipes.list", new JsonObject(), TimeSpan.FromSeconds(10));
        return Recipes(response);
    }

    public async Task<List<RecipeSummary>> DeleteRecipeAsync(string goal)
    {
        var response = await RequestAsync(
            "recipes.delete",
            new JsonObject { ["goal"] = goal },
            TimeSpan.FromSeconds(10));
        return Recipes(response);
    }

    public async Task<List<RecipeSummary>> ClearRecipesAsync()
    {
        var response = await RequestAsync("recipes.clear", new JsonObject(), TimeSpan.FromSeconds(10));
        return Recipes(response);
    }

    private static List<RecipeSummary> Recipes(JsonObject response)
    {
        Error(response);
        var items = new List<RecipeSummary>();
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

            items.Add(new RecipeSummary(
                row["goal"]?.GetValue<string>() ?? "",
                row["app"]?.GetValue<string>() ?? "",
                row["steps"]?.GetValue<int>() ?? 0,
                row["at"]?.GetValue<long>() ?? 0,
                row["replayable"]?.GetValue<bool>() ?? false,
                row["screenHash"]?.GetValue<string>() ?? "",
                row["endHash"]?.GetValue<string>() ?? ""));
        }

        return items;
    }
}
