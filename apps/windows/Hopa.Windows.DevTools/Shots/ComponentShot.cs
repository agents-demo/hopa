using System.IO;
using System.Text.Json.Nodes;
using System.Windows;
using Hopa.Windows.Ui;
using Hopa.Windows.Ui.Dialogs;
using Hopa.Windows.Ui.Shell;

namespace Hopa.Windows.DevTools.Shots;

/// <summary>W6: the windows that only appear mid-turn, rendered for the parity table.</summary>
internal static class ComponentShot
{
    public static void Run(MainWindow window, string directory)
    {
        Directory.CreateDirectory(directory);

        var approval = new ApprovalWindow(new JsonObject
        {
            ["title"] = "Pay the internet bill?",
            ["body"] = "The bank app is open on the payment screen.",
            ["amount"] = "42.00",
            ["merchant"] = "CityNet",
            ["consequence"] = "The money leaves the account and cannot be taken back.",
        })
        {
            Owner = window,
        };
        approval.Show();
        approval.UpdateLayout();
        WindowScreenshot.Save(approval, Path.Combine(directory, "windows-w6-approval.png"));
        approval.Close();

        var steps = new RunDetailsWindow(new[]
        {
            "1 tap Payments (verified)",
            "2 tap Internet (verified)",
            "3 type 42.00 (verified)",
            "4 tap Confirm, payment, approved by the family",
        })
        {
            Owner = window,
        };
        steps.Show();
        steps.UpdateLayout();
        WindowScreenshot.Save(steps, Path.Combine(directory, "windows-w6-steps.png"));
        steps.Close();

        window.Tools.Shutdown();
    }
}
