using System.Text.Json.Nodes;

namespace Hopa.Windows.Integrations.Device;

/// <summary>
/// W3: the Windows device adapter. Observation is a UI Automation tree with
/// pre-order refs, bounded depth, bounded text and a hash. Actions try the UIA
/// pattern first and fall back to the input stack. The tree, input, desktop and
/// app ports keep the rules testable without a real desktop.
/// </summary>
public sealed partial class WindowsDevice
{
    /// <summary>Builds the observation JSON the Kotlin contract decodes.</summary>
    public (JsonObject Observation, int Nodes) Observe()
    {
        Refuse();
        counter = 0;
        textChars = 0;
        refs.Clear();
        root = tree.Foreground();
        var lines = new List<string>();
        var truncated = false;
        var treeJson = root == null
            ? Node("root", "root", "", "", null, false, true, false, true, false, false, new List<JsonObject>())
            : Walk(root, 0, lines, ref truncated);
        var app = desktop.ForegroundApp();
        var screen = desktop.ScreenSize();
        var text = ObservationRules.JoinText(lines, out var textTruncated);
        if (ObservationRules.IsTreeOnlyRoot(counter, text))
        {
            throw new InvalidOperationException(
                $"'{app}' exposes no UI Automation tree; HOPA cannot see its controls");
        }

        var dpi = desktop.Dpi();
        var observation = new JsonObject
        {
            ["schemaVersion"] = "1",
            ["id"] = $"win-{DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}",
            ["timestamp"] = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
            ["displayId"] = 0,
            ["windowId"] = "active",
            ["rotation"] = 0,
            ["density"] = Math.Round(dpi / 96.0, 2),
            ["screenSize"] = new JsonObject
            {
                ["width"] = (int)screen.Width,
                ["height"] = (int)screen.Height,
            },
            ["focus"] = "",
            ["text"] = text,
            ["tree"] = treeJson,
            ["screenshotRef"] = "",
            ["app"] = app,
            ["hash"] = ObservationRules.Hash(app, (int)screen.Width, (int)screen.Height, lines),
            ["truncated"] = truncated || textTruncated || counter >= MaxNodes,
        };
        return (observation, refs.Count);
    }

    private JsonObject Walk(IUiNode element, int depth, List<string> lines, ref bool truncated)
    {
        var refId = $"e{++counter}";
        var controlType = UiCalls.Property(() => element.ControlType, "Unknown");
        var name = ObservationRules.Cap(UiCalls.Property(() => element.Name, ""));
        var automationId = UiCalls.Property(() => element.AutomationId, "");
        var isPassword = UiCalls.Property(() => element.IsPassword, false);
        var enabled = UiCalls.Property(() => element.IsEnabled, false);
        var offscreen = UiCalls.Property(() => element.IsOffscreen, true);
        var focused = UiCalls.Property(() => element.HasKeyboardFocus, false);
        var clickable = UiCalls.Property(
            () => element.CanInvoke || element.CanToggle || element.CanSelectItem,
            false);
        var scrollable = UiCalls.Property(() => element.CanScroll, false);
        var bounds = UiCalls.Property<System.Drawing.Rectangle?>(() => element.Bounds, null);

        var type = isPassword ? "password" : controlType.ToLowerInvariant();
        if (!isPassword)
        {
            refs[refId] = element;
            if (name.Length > 0 && textChars < ObservationRules.MaxTotalChars)
            {
                lines.Add($"{refId} {type} {name}");
                textChars += name.Length;
            }
        }
        else
        {
            name = "";
            lines.Add($"{refId} password field (dropped)");
        }

        var children = new List<JsonObject>();
        if (depth >= MaxDepth)
        {
            truncated = true;
        }
        else if (counter >= MaxNodes)
        {
            truncated = true;
        }
        else
        {
            IReadOnlyList<IUiNode> kids;
            try
            {
                kids = UiCalls.Call(() => element.Children(), "children");
            }
            catch (Exception error) when (error is TimeoutException or InvalidOperationException)
            {
                truncated = true;
                kids = Array.Empty<IUiNode>();
            }

            foreach (var child in kids)
            {
                if (counter >= MaxNodes)
                {
                    truncated = true;
                    break;
                }

                children.Add(Walk(child, depth + 1, lines, ref truncated));
            }
        }

        return Node(
            refId,
            type,
            name,
            automationId,
            bounds,
            clickable,
            enabled,
            false,
            !offscreen,
            scrollable,
            focused,
            children);
    }

    private static JsonObject Node(
        string refId,
        string type,
        string text,
        string id,
        System.Drawing.Rectangle? bounds,
        bool clickable,
        bool enabled,
        bool isChecked,
        bool visible,
        bool scrollable,
        bool focused,
        List<JsonObject> children)
    {
        var node = new JsonObject
        {
            ["ref"] = refId,
            ["type"] = type,
            ["text"] = text,
            ["description"] = "",
            ["id"] = id,
            ["clickable"] = clickable,
            ["enabled"] = enabled,
            ["checked"] = isChecked,
            ["scrollable"] = scrollable,
            ["visible"] = visible,
            ["focused"] = focused,
            ["children"] = new JsonArray(children.ToArray()),
        };
        node["bounds"] = bounds is { Width: > 0 } rect
            ? new JsonArray(rect.X, rect.Y, rect.X + rect.Width, rect.Y + rect.Height)
            : null;
        return node;
    }

    public string? FirstEditableRef()
    {
        foreach (var pair in refs)
        {
            if (UiCalls.Call(() => pair.Value.SupportsValue, "Value support"))
            {
                return pair.Key;
            }
        }

        return null;
    }

    public string ReadRefValue(string refId)
    {
        if (!refs.TryGetValue(refId, out var element))
        {
            return "";
        }

        try
        {
            return UiCalls.Call(
                () => element.SupportsValue ? element.Value : "",
                "read value");
        }
        catch
        {
            return "";
        }
    }
}
