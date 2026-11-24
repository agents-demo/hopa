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
    private (int X, int Y) PointFor(JsonObject message)
    {
        var refId = message["ref"]?.GetValue<string>();
        if (!string.IsNullOrEmpty(refId))
        {
            if (!refs.TryGetValue(refId, out var element))
            {
                throw new InvalidOperationException($"stale ref {refId}; observe again");
            }

            var bounds = UiCalls.Call(() => element.Bounds, "bounds")
                ?? throw new InvalidOperationException($"ref {refId} has no bounds; observe again");
            return ((int)(bounds.X + bounds.Width / 2), (int)(bounds.Y + bounds.Height / 2));
        }

        var x = message["x"]?.GetValue<int>() ?? 0;
        var y = message["y"]?.GetValue<int>() ?? 0;
        return (x, y);
    }

    private string Tap((int X, int Y) point, JsonObject message)
    {
        var refId = message["ref"]?.GetValue<string>();
        if (!string.IsNullOrEmpty(refId) && refs.TryGetValue(refId, out var element))
        {
            var byPattern = TryPattern(element, refId);
            if (byPattern != null)
            {
                return byPattern;
            }
        }

        input.Click(point.X, point.Y);
        return $"clicked {point.X},{point.Y}";
    }

    /// <summary>Pattern first: the control's own contract, not the mouse position.</summary>
    private static string? TryPattern(IUiNode element, string refId)
    {
        if (UiCalls.Call(() => element.CanInvoke, "Invoke support"))
        {
            try
            {
                UiCalls.Call(() => element.Invoke(), "Invoke");
                return $"invoked {refId}";
            }
            catch (Exception error) when (error is TimeoutException or InvalidOperationException)
            {
                // Fall through: the control offered the pattern but did not honour it.
            }
        }

        if (UiCalls.Call(() => element.CanToggle, "Toggle support"))
        {
            try
            {
                UiCalls.Call(() => element.Toggle(), "Toggle");
                return $"toggled {refId}";
            }
            catch (Exception error) when (error is TimeoutException or InvalidOperationException)
            {
            }
        }

        if (UiCalls.Call(() => element.CanSelectItem, "SelectionItem support"))
        {
            try
            {
                UiCalls.Call(() => element.SelectItem(), "Select");
                return $"selected {refId}";
            }
            catch (Exception error) when (error is TimeoutException or InvalidOperationException)
            {
            }
        }

        return null;
    }

    private string Type(JsonObject message)
    {
        var text = message["text"]?.GetValue<string>() ?? "";
        var refId = message["ref"]?.GetValue<string>();
        if (string.IsNullOrEmpty(refId))
        {
            throw new InvalidOperationException(
                "type needs a ref on Windows; blind typing would hit whatever window is focused");
        }

        if (!refs.TryGetValue(refId, out var element))
        {
            throw new InvalidOperationException($"stale ref {refId}; observe again");
        }

        if (UiCalls.Call(() => element.SupportsValue, "Value support"))
        {
            try
            {
                UiCalls.Call(() => element.SetValue(text), "SetValue");
                return $"set {refId} to {text.Length} chars";
            }
            catch (Exception error) when (error is TimeoutException or InvalidOperationException)
            {
                // Fall through to the keyboard.
            }
        }

        UiCalls.Call(() => element.Focus(), "Focus");
        input.Type(text);
        return $"typed {text.Length} chars";
    }

    private string Swipe(JsonObject message)
    {
        var fromX = message["fromX"]?.GetValue<int>() ?? 0;
        var fromY = message["fromY"]?.GetValue<int>() ?? 0;
        var toX = message["toX"]?.GetValue<int>() ?? 0;
        var toY = message["toY"]?.GetValue<int>() ?? 0;
        input.MoveTo(fromX, fromY);
        input.MouseDown();
        Thread.Sleep(80);
        input.MoveTo(toX, toY);
        input.MouseUp();
        return $"swiped {fromX},{fromY} -> {toX},{toY}";
    }

    private string Key(JsonObject message)
    {
        var key = message["key"]?.GetValue<string>() ?? "";
        switch (key)
        {
            case "back":
                input.PressBack();
                return "pressed Escape (back)";
            case "home":
                input.ShowDesktop();
                return "showed the desktop (home)";
            default:
                throw new InvalidOperationException($"unknown key {key}");
        }
    }
}
