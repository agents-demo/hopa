using System.Security.Cryptography;
using System.Text;

namespace Hopa.Windows.Integrations.Device;

/// <summary>
/// The parts of an observation that must be identical on every run with the same
/// screen: text caps, total text budget and the hash.
/// </summary>
public static class ObservationRules
{
    public const int MaxTextLines = 40;
    public const int MaxTextChars = 200;
    public const int MaxTotalChars = 4000;

    /// <summary>
    /// A window that produced one anonymous node and no text exposes no usable
    /// tree. Saying so is better than handing the loop an empty screen.
    /// </summary>
    public static bool IsTreeOnlyRoot(int nodes, string text) =>
        nodes <= 1 && string.IsNullOrWhiteSpace(text);

    /// <summary>Long labels are cut, not dropped: the hash must not depend on luck.</summary>
    public static string Cap(string text) =>
        text.Length <= MaxTextChars ? text : text[..MaxTextChars] + "\u2026";

    public static string JoinText(IEnumerable<string> lines, out bool truncated)
    {
        var kept = new List<string>();
        var length = 0;
        foreach (var line in lines)
        {
            if (kept.Count == MaxTextLines || length + line.Length > MaxTotalChars)
            {
                truncated = true;
                return string.Join("\n", kept);
            }

            kept.Add(line);
            length += line.Length;
        }

        truncated = false;
        return string.Join("\n", kept);
    }

    public static string Hash(string app, int width, int height, IEnumerable<string> lines)
    {
        var canonical = $"{app}|{width}x{height}|" + string.Join("\n", lines);
        var digest = SHA256.HashData(Encoding.UTF8.GetBytes(canonical));
        return "sha256:" + Convert.ToHexString(digest).ToLowerInvariant();
    }
}
