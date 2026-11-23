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
    private (int X, int Y) PointFor(JsonObject message)
    {
        var refId = message["ref"]?.GetValue<string>();
        if (!string.IsNullOrEmpty(refId))
        {
            if (!refs.TryGetValue(refId, out var element))
            {
                throw new InvalidOperationException($"stale ref {refId}; observe again");
            }

            var bounds = Call(() => element.BoundingRectangle, "bounds");
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

        Mouse.Click(new System.Drawing.Point(point.X, point.Y));
        return $"clicked {point.X},{point.Y}";
    }

    /// <summary>Pattern first: the control's own contract, not the mouse position.</summary>
    private static string? TryPattern(AutomationElement element, string refId)
    {
        if (Call(() => element.Patterns.Invoke.IsSupported, "Invoke support"))
        {
            try
            {
                Call(() => element.Patterns.Invoke.Pattern.Invoke(), "Invoke");
                return $"invoked {refId}";
            }
            catch (Exception error) when (error is TimeoutException or InvalidOperationException)
            {
                // Fall through: the control offered the pattern but did not honour it.
            }
        }

        if (Call(() => element.Patterns.Toggle.IsSupported, "Toggle support"))
        {
            try
            {
                Call(() => element.Patterns.Toggle.Pattern.Toggle(), "Toggle");
                return $"toggled {refId}";
            }
            catch (Exception error) when (error is TimeoutException or InvalidOperationException)
            {
            }
        }

        if (Call(() => element.Patterns.SelectionItem.IsSupported, "SelectionItem support"))
        {
            try
            {
                Call(() => element.Patterns.SelectionItem.Pattern.Select(), "Select");
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

        if (Call(() => element.Patterns.Value.IsSupported, "Value support"))
        {
            try
            {
                Call(() => element.Patterns.Value.Pattern.SetValue(text), "SetValue");
                return $"set {refId} to {text.Length} chars";
            }
            catch (Exception error) when (error is TimeoutException or InvalidOperationException)
            {
                // Fall through to the keyboard.
            }
        }

        Call(() => element.Focus(), "Focus");
        Keyboard.Type(text);
        return $"typed {text.Length} chars";
    }

    private string Swipe(JsonObject message)
    {
        var fromX = message["fromX"]?.GetValue<int>() ?? 0;
        var fromY = message["fromY"]?.GetValue<int>() ?? 0;
        var toX = message["toX"]?.GetValue<int>() ?? 0;
        var toY = message["toY"]?.GetValue<int>() ?? 0;
        Mouse.MoveTo(new System.Drawing.Point(fromX, fromY));
        Mouse.Down(MouseButton.Left);
        Thread.Sleep(80);
        Mouse.MoveTo(new System.Drawing.Point(toX, toY));
        Mouse.Up(MouseButton.Left);
        return $"swiped {fromX},{fromY} -> {toX},{toY}";
    }

    private string Key(JsonObject message)
    {
        var key = message["key"]?.GetValue<string>() ?? "";
        switch (key)
        {
            case "back":
                Keyboard.Type(VirtualKeyShort.ESC);
                return "pressed Escape (back)";
            case "home":
                Keyboard.Press(VirtualKeyShort.LWIN);
                Keyboard.Type(VirtualKeyShort.KEY_D);
                Keyboard.Release(VirtualKeyShort.LWIN);
                return "showed the desktop (home)";
            default:
                throw new InvalidOperationException($"unknown key {key}");
        }
    }
}
