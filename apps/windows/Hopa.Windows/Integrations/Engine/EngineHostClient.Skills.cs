using System.Text.Json.Nodes;

namespace Hopa.Windows.Integrations.Engine;

/// <summary>The skill family: trigger → action pairs the user taught HOPA.</summary>
public sealed partial class EngineHostClient
{
    public async Task<List<Skill>> ListSkillsAsync()
    {
        var response = await RequestAsync("skills.list", new JsonObject(), TimeSpan.FromSeconds(10));
        return Skills(response);
    }

    public async Task<List<Skill>> AddSkillAsync(string trigger, string action)
    {
        var response = await RequestAsync(
            "skills.add",
            new JsonObject { ["trigger"] = trigger, ["action"] = action },
            TimeSpan.FromSeconds(10));
        return Skills(response);
    }

    public async Task<List<Skill>> DeleteSkillAsync(string trigger)
    {
        var response = await RequestAsync(
            "skills.delete",
            new JsonObject { ["trigger"] = trigger },
            TimeSpan.FromSeconds(10));
        return Skills(response);
    }

    public async Task<List<Skill>> ClearSkillsAsync()
    {
        var response = await RequestAsync("skills.clear", new JsonObject(), TimeSpan.FromSeconds(10));
        return Skills(response);
    }

    private static List<Skill> Skills(JsonObject response)
    {
        Error(response);
        var items = new List<Skill>();
        if (response["items"] is JsonArray array)
        {
            foreach (var item in array)
            {
                if (item is JsonObject row)
                {
                    var trigger = row["trigger"]?.GetValue<string>() ?? "";
                    var action = row["action"]?.GetValue<string>() ?? "";
                    if (trigger.Length > 0 && action.Length > 0)
                    {
                        items.Add(new Skill(trigger, action));
                    }
                }
            }
        }

        return items;
    }
}
