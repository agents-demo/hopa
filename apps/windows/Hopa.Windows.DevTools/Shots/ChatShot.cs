using System.IO;
using System.Windows.Media;
using Hopa.Windows.Ui;
using Hopa.Windows.Ui.Chat;
using Hopa.Windows.Ui.Shell;

namespace Hopa.Windows.DevTools.Shots;

/// <summary>W6: a chat with real content, a long answer, an attachment and an error line.</summary>
internal static class ChatShot
{
    public static void Run(MainWindow window, string directory)
    {
        Directory.CreateDirectory(directory);
        var tools = window.Tools;
        tools.Chat.Model.ShowMock(
            new[]
            {
                new MessageBubble { Role = "user", Text = "Pay the internet bill, then email me the receipt." },
                new MessageBubble
                {
                    Role = "assistant",
                    Text = "Done. CityNet was paid 42.00 from the household account, the payment screen " +
                           "confirmed it, and the receipt went to your inbox. The bank app is still open " +
                           "on the payments screen if you want to check the reference number yourself.",
                },
                new MessageBubble { Role = "user", Text = "Thanks, and remind me on the 3rd." },
            },
            "The bridge is not running; the last step was not verified.",
            "bill-2026-11.pdf",
            "48 KB \u00B7 application/pdf");
        tools.SetPendingAttachment(null);
        tools.ClearStatus();
        tools.Rail.Model.ShowMock("Succeeded", "4 steps \u00B7 6.2 s", new[]
        {
            new RunStepRow
            {
                Number = "1", Verb = "Open app", Detail = "Calculator, brought to the front",
                Dot = new SolidColorBrush(Color.FromRgb(0x2E, 0x7D, 0x5B)),
            },
            new RunStepRow
            {
                Number = "2", Verb = "Type", Detail = "42.00 into the amount field",
                Dot = new SolidColorBrush(Color.FromRgb(0x2E, 0x7D, 0x5B)),
            },
            new RunStepRow
            {
                Number = "3", Verb = "Tap", Detail = "Confirm, payment, approved by the family",
                Dot = new SolidColorBrush(Color.FromRgb(0x2E, 0x7D, 0x5B)),
            },
            new RunStepRow
            {
                Number = "4", Verb = "Verified", Detail = "receipt sent; the paid screen matched",
                Dot = new SolidColorBrush(Color.FromRgb(0x7B, 0x61, 0x3A)),
            },
        });
        WindowScreenshot.Save(window, Path.Combine(directory, "windows-w6-chat.png"));
        tools.Shutdown();
    }
}
