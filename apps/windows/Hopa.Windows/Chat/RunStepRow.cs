using System.Text.Json.Nodes;
using System.Windows.Media;

namespace Hopa.Windows.Chat;

/// <summary>One step in the right rail: what was tried, what happened, and its colour.</summary>
public sealed class RunStepRow
{
    public string Number { get; init; } = "";

    public string Verb { get; init; } = "";

    public string Detail { get; init; } = "";

    public Brush Dot { get; init; } = Brushes.Gray;

    /// <summary>Builds a row from one step in the engine's turn JSON.</summary>
    public static RunStepRow From(JsonObject step)
    {
        var number = step["step"]?.GetValue<int>() ?? 0;
        var kind = step["action"]?["kind"]?.GetValue<string>() ?? "?";
        var executed = step["executed"]?.GetValue<bool>() == true;
        var verified = step["verified"]?.GetValue<bool>() == true;
        var approved = step["approved"]?.GetValue<bool?>();
        var error = step["error"]?.GetValue<string>() ?? "";
        var detail = error.Length > 0
            ? error
            : approved == false ? "refused by the gate"
            : verified ? "verified" : executed ? "ran, not verified" : "did not run";
        var verb = kind switch
        {
            "ui.launch" => "Open app",
            "ui.tap" => "Tap",
            "ui.doubleTap" => "Double-tap",
            "ui.longPress" => "Long-press",
            "ui.type" => "Type",
            "ui.back" => "Back",
            "ui.home" => "Home",
            "ui.swipe" or "ui.scroll" => "Swipe",
            _ => kind,
        };
        return new RunStepRow
        {
            Number = number > 0 ? number.ToString() : "\u2022",
            Verb = verb,
            Detail = detail,
            Dot = new SolidColorBrush(verified
                ? Color.FromRgb(0x2E, 0x7D, 0x5B)
                : error.Length > 0 ? Color.FromRgb(0xC0, 0x39, 0x2B) : Color.FromRgb(0xB2, 0x6A, 0x00)),
        };
    }

    /// <summary>The plain-text transcript behind "Run details".</summary>
    public static IEnumerable<string> Lines(JsonArray? steps)
    {
        if (steps == null)
        {
            yield break;
        }

        foreach (var node in steps)
        {
            if (node is not JsonObject step)
            {
                continue;
            }

            var number = step["step"]?.GetValue<int>() ?? 0;
            var kind = step["action"]?["kind"]?.GetValue<string>() ?? "?";
            var classification = step["classification"]?.GetValue<string>() ?? "?";
            var approved = step["approved"]?.GetValue<bool?>();
            var executed = step["executed"]?.GetValue<bool>() == true;
            var verified = step["verified"]?.GetValue<bool>() == true;
            var error = step["error"]?.GetValue<string>() ?? "";
            var hash = step["hash"]?.GetValue<string>() ?? "";
            yield return $"#{number} {kind} [{classification}] approved={approved} " +
                         $"executed={executed} verified={verified} error={error} " +
                         $"hash={hash[..Math.Min(10, hash.Length)]}";
        }
    }
}
