using System.Text.Json.Nodes;

namespace Hopa.Windows.Integrations.Engine;

/// <summary>The shared profile catalogue and the selected shell.</summary>
public sealed partial class EngineHostClient
{
    public async Task<(string Selected, List<ProfileChoice> Profiles)> ListProfilesAsync()
    {
        var response = await RequestAsync("profiles.list", new JsonObject(), TimeSpan.FromSeconds(10));
        return Profiles(response);
    }

    public async Task<(string Selected, List<ProfileChoice> Profiles)> SelectProfileAsync(string key)
    {
        var response = await RequestAsync(
            "profiles.select",
            new JsonObject { ["profile"] = key },
            TimeSpan.FromSeconds(10));
        return Profiles(response);
    }

    private static (string Selected, List<ProfileChoice> Profiles) Profiles(JsonObject response)
    {
        Error(response);
        var items = new List<ProfileChoice>();
        if (response["items"] is JsonArray array)
        {
            foreach (var item in array)
            {
                if (item is JsonObject row)
                {
                    var key = row["key"]?.GetValue<string>() ?? "";
                    var label = row["label"]?.GetValue<string>() ?? "";
                    if (key.Length > 0)
                    {
                        items.Add(new ProfileChoice(key, label));
                    }
                }
            }
        }

        return (response["selected"]?.GetValue<string>() ?? "everyday", items);
    }
}
