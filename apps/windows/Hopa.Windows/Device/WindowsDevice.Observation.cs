using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;
using FlaUI.Core.AutomationElements;
using FlaUI.Core.Definitions;
using FlaUI.Core.Input;
using FlaUI.Core.WindowsAPI;
using FlaUI.UIA3;

namespace Hopa.Windows.Device;

/// <summary>
/// W3: the Windows device adapter. Observation is a real UI Automation tree with
/// pre-order refs, bounded depth, bounded text and a hash. Actions try the UIA
/// pattern first and fall back to the input stack. Every UIA call has a timeout:
/// a hung provider is reported, never allowed to freeze the turn.
/// </summary>
public sealed partial class WindowsDevice
{
    /// <summary>Builds the observation JSON the Kotlin contract decodes.</summary>
    public (JsonObject Observation, int Nodes) Observe()
    {
        RefuseSecureSurface();
        RefuseElevatedBoundary();
        counter = 0;
        textChars = 0;
        refs.Clear();
        root = ForegroundElement();
        var lines = new List<string>();
        var truncated = false;
        var tree = root == null
            ? Node("root", "root", "", "", null, false, true, false, true, false, false, new List<JsonObject>())
            : Walk(root, 0, lines, ref truncated);
        var app = ForegroundApp();
        var screen = ScreenSize();
        var text = ObservationRules.JoinText(lines, out var textTruncated);
        if (ObservationRules.IsTreeOnlyRoot(counter, text))
        {
            throw new InvalidOperationException(
                $"'{app}' exposes no UI Automation tree; HOPA cannot see its controls");
        }

        var dpi = DpiFor(GetForegroundWindow());
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
            ["tree"] = tree,
            ["screenshotRef"] = "",
            ["app"] = app,
            ["hash"] = ObservationRules.Hash(app, (int)screen.Width, (int)screen.Height, lines),
            ["truncated"] = truncated || textTruncated || counter >= MaxNodes,
        };
        return (observation, refs.Count);
    }

    private static double DpiFor(IntPtr hwnd) => hwnd == IntPtr.Zero ? 96 : Math.Max(96, GetDpiForWindow(hwnd));

    private AutomationElement? ForegroundElement()
    {
        try
        {
            var hwnd = GetForegroundWindow();
            return hwnd == IntPtr.Zero ? null : automation.FromHandle(hwnd);
        }
        catch
        {
            return null;
        }
    }

    private JsonObject Walk(AutomationElement element, int depth, List<string> lines, ref bool truncated)
    {
        var refId = $"e{++counter}";
        var controlType = Property(() => element.Properties.ControlType.ValueOrDefault.ToString(), "Unknown");
        var name = ObservationRules.Cap(Property(() => element.Properties.Name.ValueOrDefault ?? "", ""));
        var automationId = Property(() => element.Properties.AutomationId.ValueOrDefault ?? "", "");
        var isPassword = Property(() => element.Properties.IsPassword.ValueOrDefault, false);
        var enabled = Property(() => element.Properties.IsEnabled.ValueOrDefault, false);
        var offscreen = Property(() => element.Properties.IsOffscreen.ValueOrDefault, true);
        var focused = Property(() => element.Properties.HasKeyboardFocus.ValueOrDefault, false);
        var clickable = Property(
            () => element.Patterns.Invoke.IsSupported
                || element.Patterns.Toggle.IsSupported
                || element.Patterns.SelectionItem.IsSupported,
            false);
        var scrollable = Property(() => element.Patterns.Scroll.IsSupported, false);
        var bounds = Property<System.Drawing.Rectangle?>(() => element.BoundingRectangle, null);

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
            AutomationElement[] kids;
            try
            {
                kids = Call(() => element.FindAllChildren(), "children");
            }
            catch (Exception error) when (error is TimeoutException or InvalidOperationException)
            {
                truncated = true;
                kids = Array.Empty<AutomationElement>();
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
            if (Call(() => pair.Value.Patterns.Value.IsSupported, "Value support"))
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
            return Call(
                () => element.Patterns.Value.IsSupported
                    ? element.Patterns.Value.Pattern.Value.Value ?? ""
                    : "",
                "read value");
        }
        catch
        {
            return "";
        }
    }

    /// <summary>PNG of the foreground window, or null when the screen is not capturable.</summary>
    public byte[]? CaptureWindow()
    {
        try
        {
            var handle = GetForegroundWindow();
            if (!GetWindowRect(handle, out var rect))
            {
                return null;
            }

            var width = rect.Right - rect.Left;
            var height = rect.Bottom - rect.Top;
            if (width <= 0 || height <= 0)
            {
                return null;
            }

            using var bitmap = new System.Drawing.Bitmap(width, height);
            using (var graphics = System.Drawing.Graphics.FromImage(bitmap))
            {
                graphics.CopyFromScreen(rect.Left, rect.Top, 0, 0, bitmap.Size);
            }

            using var stream = new MemoryStream();
            bitmap.Save(stream, System.Drawing.Imaging.ImageFormat.Png);
            return stream.ToArray();
        }
        catch
        {
            return null;
        }
    }
}
