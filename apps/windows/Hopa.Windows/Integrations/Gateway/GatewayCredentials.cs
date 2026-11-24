using System.Text.Json.Nodes;
using Hopa.Windows.Storage;

namespace Hopa.Windows.Integrations.Gateway;

/// <summary>The backend credential this PC owns. Never the phone's token.</summary>
public sealed class GatewayCredentials
{
    private const string CredentialName = "hopa.gateway";

    public string GatewayUrl { get; set; } = "";
    public string DeviceId { get; set; } = "";
    public string HouseholdId { get; set; } = "";
    public string AccessToken { get; set; } = "";
    public string RefreshToken { get; set; } = "";
    public string ExpiresAt { get; set; } = "";
    /// <summary>Kept for the week-2 key wrap; P4 only enrolls the public half.</summary>
    public string PrivateKey { get; set; } = "";

    public static GatewayCredentials? Load()
    {
        var text = CredentialStore.Read(CredentialName);
        if (string.IsNullOrWhiteSpace(text))
        {
            return null;
        }

        try
        {
            var parsed = JsonNode.Parse(text) as JsonObject;
            if (parsed == null)
            {
                return null;
            }

            var credentials = new GatewayCredentials
            {
                GatewayUrl = parsed["GatewayUrl"]?.GetValue<string>() ?? "",
                DeviceId = parsed["DeviceId"]?.GetValue<string>() ?? "",
                HouseholdId = parsed["HouseholdId"]?.GetValue<string>() ?? "",
                AccessToken = parsed["AccessToken"]?.GetValue<string>() ?? "",
                RefreshToken = parsed["RefreshToken"]?.GetValue<string>() ?? "",
                ExpiresAt = parsed["ExpiresAt"]?.GetValue<string>() ?? "",
                PrivateKey = parsed["PrivateKey"]?.GetValue<string>() ?? "",
            };
            return credentials.GatewayUrl.Length == 0 || credentials.AccessToken.Length == 0
                ? null
                : credentials;
        }
        catch (Exception)
        {
            return null;
        }
    }

    public static void Save(GatewayCredentials credentials) =>
        CredentialStore.Write(CredentialName, new JsonObject
        {
            ["GatewayUrl"] = credentials.GatewayUrl,
            ["DeviceId"] = credentials.DeviceId,
            ["HouseholdId"] = credentials.HouseholdId,
            ["AccessToken"] = credentials.AccessToken,
            ["RefreshToken"] = credentials.RefreshToken,
            ["ExpiresAt"] = credentials.ExpiresAt,
            ["PrivateKey"] = credentials.PrivateKey,
        }.ToJsonString());

    public static void Forget() => CredentialStore.Delete(CredentialName);
}
