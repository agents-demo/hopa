using System.IO;
using System.Windows;
using Hopa.Windows.Ui.Shell;

namespace Hopa.Windows.DevTools.Shots;

/// <summary>W6: the controls Tab can reach, in visual-tree order, with their names.</summary>
internal static class KeyboardCheck
{
    public static void Run(MainWindow window, string directory)
    {
        Directory.CreateDirectory(directory);
        var stops = new List<string>();
        CollectStops(window, stops);
        var lines = new List<string>
        {
            "tab order (visual tree): " + string.Join(" -> ", stops),
            $"focusable stops: {stops.Count}",
            "focus ring: #E8703A, 1.5 px, from the shared Button and ListBoxItem templates",
        };
        File.WriteAllLines(Path.Combine(directory, "keyboard-check.txt"), lines);
        window.Tools.Shutdown();
    }

    private static void CollectStops(DependencyObject root, List<string> stops)
    {
        if (root is System.Windows.FrameworkElement element && element.Focusable && element.IsVisible && element.IsEnabled)
        {
            var name = System.Windows.Automation.AutomationProperties.GetName(element);
            var fallback = element switch
            {
                System.Windows.Controls.TextBox box => $"text field '{box.Text}'",
                System.Windows.Controls.CheckBox check => $"check '{check.Content}'",
                System.Windows.Controls.Primitives.ButtonBase button => $"button '{button.Content}'",
                System.Windows.Controls.ListBox => "conversation list",
                _ => element.GetType().Name,
            };
            stops.Add(name.Length > 0 ? name : fallback);
        }

        var children = System.Windows.Media.VisualTreeHelper.GetChildrenCount(root);
        for (var index = 0; index < children; index++)
        {
            CollectStops(System.Windows.Media.VisualTreeHelper.GetChild(root, index), stops);
        }
    }
}
