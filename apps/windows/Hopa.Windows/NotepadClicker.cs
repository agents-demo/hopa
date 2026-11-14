using System.Diagnostics;
using FlaUI.Core.AutomationElements;
using FlaUI.Core.Definitions;
using FlaUI.Core.Input;
using FlaUI.UIA3;

namespace Hopa.Windows;

/// <summary>W0: the one UIA action that proves the device seam.</summary>
public static class NotepadClicker
{
    public static string ClickTextArea()
    {
        // Notepad on Windows 11 redirects to the packaged app, so the launched
        // process id is not the window's process. Find the window by name.
        Process.Start(new ProcessStartInfo("notepad.exe") { UseShellExecute = true });

        using var automation = new UIA3Automation();
        var deadline = DateTime.UtcNow.AddSeconds(20);
        Window? window = null;
        while (DateTime.UtcNow < deadline && window == null)
        {
            window = FindNotepadWindow(automation);
            if (window == null)
            {
                Thread.Sleep(300);
            }
        }

        if (window == null)
        {
            throw new InvalidOperationException("Notepad window did not appear");
        }

        var edit = window.FindFirstDescendant(cf => cf.ByControlType(ControlType.Document))
            ?? window.FindFirstDescendant(cf => cf.ByControlType(ControlType.Edit))
            ?? throw new InvalidOperationException("Notepad has no text area this build can see");

        window.Focus();
        Thread.Sleep(200);
        var bounds = edit.BoundingRectangle;
        var point = new System.Drawing.Point(bounds.X + bounds.Width / 2, bounds.Y + bounds.Height / 2);
        Mouse.Click(point);
        return $"clicked Notepad '{window.Title}' text area at {point.X},{point.Y}";
    }

    private static Window? FindNotepadWindow(UIA3Automation automation)
    {
        foreach (var candidate in automation.GetDesktop().FindAllChildren(cf => cf.ByControlType(ControlType.Window)))
        {
            var name = SafeName(candidate);
            if (name.Contains("Notepad", StringComparison.OrdinalIgnoreCase)
                || name.Contains("Блокнот", StringComparison.OrdinalIgnoreCase)
                || ProcessName(candidate).Contains("notepad", StringComparison.OrdinalIgnoreCase))
            {
                return candidate.AsWindow();
            }
        }

        return null;
    }

    private static string SafeName(AutomationElement element)
    {
        try
        {
            return element.Name ?? "";
        }
        catch
        {
            return "";
        }
    }

    private static string ProcessName(AutomationElement element)
    {
        try
        {
            var pid = element.Properties.ProcessId.Value;
            return Process.GetProcessById(pid).ProcessName;
        }
        catch
        {
            return "";
        }
    }
}
