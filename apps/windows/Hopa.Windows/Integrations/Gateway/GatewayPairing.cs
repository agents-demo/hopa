using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;

namespace Hopa.Windows.Integrations.Gateway;

/// <summary>Claiming the pairing link, refreshing the token pair, and the HTTP base.</summary>
internal static class GatewayPairing
{
    private static readonly HttpClient Http = new();

    /// <summary>Claim a `hopa://pair?...` link as a Windows device.</summary>
    public static async Task<GatewayCredentials> PairAsync(
        string link,
        string name,
        CancellationToken cancellationToken = default)
    {
        var uri = new Uri(link.Trim());
        if (!uri.Scheme.Equals("hopa", StringComparison.OrdinalIgnoreCase) ||
            !uri.Host.Equals("pair", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException("expected a hopa://pair link");
        }

        var query = ParseQuery(uri.Query);
        var session = query.GetValueOrDefault("p") ?? "";
        var gatewayUrl = query.GetValueOrDefault("u") ?? "";
        if (session.Length == 0 || gatewayUrl.Length == 0)
        {
            throw new InvalidOperationException("the pairing link has no session or gateway URL");
        }

        var privateKey = RandomNumberGenerator.GetBytes(32);
        var body = new JsonObject
        {
            ["session"] = session,
            ["platform"] = "windows",
            ["name"] = name,
            ["publicKey"] = Convert.ToBase64String(privateKey),
            ["alg"] = "x25519",
        };
        var httpBase = HttpBase(gatewayUrl);
        using var response = await Http.PostAsync(
            httpBase + "/v1/pair/claim",
            new StringContent(body.ToJsonString(), Encoding.UTF8, "application/json"),
            cancellationToken);
        var text = await response.Content.ReadAsStringAsync(cancellationToken);
        var payload = JsonNode.Parse(text) as JsonObject
            ?? throw new InvalidOperationException("pairing returned no JSON object");
        if (!response.IsSuccessStatusCode)
        {
            var code = payload["code"]?.GetValue<string>() ?? $"HTTP {(int)response.StatusCode}";
            var message = payload["message"]?.GetValue<string>() ?? "pairing refused";
            throw new InvalidOperationException($"{code}: {message}");
        }

        var credentials = new GatewayCredentials
        {
            GatewayUrl = gatewayUrl,
            DeviceId = payload["deviceId"]?.GetValue<string>() ?? "",
            HouseholdId = payload["householdId"]?.GetValue<string>() ?? "",
            AccessToken = payload["accessToken"]?.GetValue<string>() ?? "",
            RefreshToken = payload["refreshToken"]?.GetValue<string>() ?? "",
            ExpiresAt = payload["expiresAt"]?.GetValue<string>() ?? "",
            PrivateKey = Convert.ToBase64String(privateKey),
        };
        if (credentials.DeviceId.Length == 0 ||
            credentials.AccessToken.Length == 0 ||
            credentials.RefreshToken.Length == 0)
        {
            throw new InvalidOperationException("pairing response is incomplete");
        }

        GatewayCredentials.Save(credentials);
        return credentials;
    }

    internal static async Task<GatewayCredentials?> RefreshAsync(
        GatewayCredentials credentials,
        CancellationToken cancellationToken)
    {
        try
        {
            using var response = await Http.PostAsync(
                HttpBase(credentials.GatewayUrl) + "/v1/token/refresh",
                new StringContent(
                    new JsonObject { ["refreshToken"] = credentials.RefreshToken }.ToJsonString(),
                    Encoding.UTF8,
                    "application/json"),
                cancellationToken);
            var payload = JsonNode.Parse(await response.Content.ReadAsStringAsync(cancellationToken)) as JsonObject;
            if (!response.IsSuccessStatusCode || payload == null)
            {
                return null;
            }

            credentials.AccessToken = payload["accessToken"]?.GetValue<string>() ?? "";
            credentials.RefreshToken = payload["refreshToken"]?.GetValue<string>() ?? "";
            credentials.ExpiresAt = payload["expiresAt"]?.GetValue<string>() ?? credentials.ExpiresAt;
            if (credentials.AccessToken.Length == 0 || credentials.RefreshToken.Length == 0)
            {
                return null;
            }

            GatewayCredentials.Save(credentials);
            return credentials;
        }
        catch (Exception)
        {
            return null;
        }
    }

    internal static string HttpBase(string gatewayUrl) =>
        gatewayUrl
            .Replace("wss://", "https://", StringComparison.OrdinalIgnoreCase)
            .Replace("ws://", "http://", StringComparison.OrdinalIgnoreCase)
            .Replace("/v1/gateway", "", StringComparison.OrdinalIgnoreCase)
            .TrimEnd('/');

    private static Dictionary<string, string> ParseQuery(string query)
    {
        var values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var part in query.TrimStart('?').Split('&', StringSplitOptions.RemoveEmptyEntries))
        {
            var pair = part.Split('=', 2);
            var key = Uri.UnescapeDataString(pair[0]);
            var value = pair.Length == 2 ? Uri.UnescapeDataString(pair[1]) : "";
            values[key] = value;
        }
        return values;
    }
}
