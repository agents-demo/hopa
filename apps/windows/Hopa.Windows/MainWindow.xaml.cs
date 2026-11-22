using System.Collections.ObjectModel;
using System.IO;
using System.Net.Http;
using System.Speech.Synthesis;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Microsoft.Win32;
using System.Windows.Shell;

namespace Hopa.Windows;

public partial class MainWindow : Window
{
    private readonly ObservableCollection<ConversationVm> conversations = new();
    private readonly List<ConversationVm> allConversations = new();
    private readonly ObservableCollection<MessageVm> messages = new();
    private readonly Dictionary<string, string> drafts = new();
    private readonly List<string> log = new();
    private readonly WindowsDevice device = new();
    private readonly VoiceClient voice = new();
    private SpeechSynthesizer? speech;
    private System.Windows.Forms.NotifyIcon? tray;

    [System.Runtime.InteropServices.DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);
    private System.Windows.Forms.ToolStripItem? trayStop;
    private string lastAnswer = "";
    private SidecarClient? client;
    private GatewayClient? gateway;
    private Task? connecting;
    private string? currentId;
    private JsonArray? lastSteps;
    private bool lastChainOk;
    private JsonObject? pendingAttachment;
    private string? autoApproval;
    private string? outputPath;
    private bool switching;
    private bool running;
    private string lastQuestion = "";

    public MainWindow()
    {
        InitializeComponent();
        // The Harmony laptop app hides the system decoration and keeps its own
        // window controls. WindowChrome does the same here: the top 52 px drags,
        // the three buttons stay clickable, the resize border remains.
        WindowChrome.SetWindowChrome(this, new WindowChrome
        {
            CaptionHeight = 52,
            ResizeBorderThickness = new Thickness(6),
            GlassFrameThickness = new Thickness(0),
            CornerRadius = new CornerRadius(0),
            UseAeroCaptionButtons = false,
        });
        foreach (var button in new[] { MinimizeButton, MaximizeButton, CloseButton })
        {
            WindowChrome.SetIsHitTestVisibleInChrome(button, true);
        }

        StateChanged += (_, _) => MaximizeButton.Content = WindowState == WindowState.Maximized
            ? "\u2750"
            : "\u25A1";
        var grouped = new System.Windows.Data.CollectionViewSource { Source = conversations };
        grouped.GroupDescriptions.Add(new System.Windows.Data.PropertyGroupDescription("GroupLabel"));
        ConversationList.ItemsSource = grouped.View;
        MessagesList.ItemsSource = messages;
        SetupTray();
        using (var icon = LaptopIcon())
        {
            Icon = System.Windows.Interop.Imaging.CreateBitmapSourceFromHIcon(
                icon.Handle, Int32Rect.Empty,
                System.Windows.Media.Imaging.BitmapSizeOptions.FromEmptyOptions());
        }

        SourceInitialized += (_, _) => RoundCorners();
        Loaded += (_, _) => RestoreWindowState();
        Closing += (_, _) => SaveWindowState();
        Closed += (_, _) =>
        {
            tray?.Dispose();
            speech?.Dispose();
            voice.Dispose();
            device.Dispose();
            _ = gateway?.StopAsync();
        };
        Loaded += async (_, _) => await ConnectAsync();
    }

    /// <summary>Win11 draws the rounded frame; Win10 ignores the attribute.</summary>
    private void RoundCorners()
    {
        var handle = new System.Windows.Interop.WindowInteropHelper(this).Handle;
        var round = 2;
        DwmSetWindowAttribute(handle, 33, ref round, sizeof(int));
    }

    /// <summary>The laptop mark, drawn once at 32 px for the tray and the taskbar.</summary>
    private static System.Drawing.Icon LaptopIcon()
    {
        var bitmap = new System.Drawing.Bitmap(32, 32);
        using (var g = System.Drawing.Graphics.FromImage(bitmap))
        {
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            g.Clear(System.Drawing.Color.Transparent);
            var orange = new System.Drawing.SolidBrush(System.Drawing.Color.FromArgb(0xE8, 0x70, 0x3A));
            var cream = new System.Drawing.SolidBrush(System.Drawing.Color.FromArgb(0xFF, 0xFD, 0xF7));
            var ink = new System.Drawing.SolidBrush(System.Drawing.Color.FromArgb(0x1C, 0x1B, 0x18));
            g.FillRectangle(orange, 5, 6, 22, 16);
            g.FillRectangle(orange, 25, 10, 3, 5);
            g.FillRectangle(cream, 8, 9, 16, 10);
            g.FillEllipse(ink, 11, 12, 2, 2);
            g.FillEllipse(ink, 17, 12, 2, 2);
            g.DrawArc(new System.Drawing.Pen(ink, 1.6f), 12, 14, 8, 4, 20, 140);
            g.FillRectangle(orange, 2, 23, 28, 4);
            g.FillRectangle(cream, 14, 24, 4, 1);
        }

        var handle = bitmap.GetHicon();
        return System.Drawing.Icon.FromHandle(handle);
    }

    private void SetupTray()
    {
        tray = new System.Windows.Forms.NotifyIcon
        {
            Icon = LaptopIcon(),
            Text = "HOPA",
            Visible = true,
        };
        var menu = new System.Windows.Forms.ContextMenuStrip();
        menu.Items.Add("Open", null, (_, _) => ShowFromTray());
        var stopItem = menu.Items.Add("Stop", null, (_, _) =>
            Dispatcher.Invoke(() => client?.CancelTurn()));
        stopItem.Enabled = false;
        trayStop = stopItem;
        menu.Items.Add("Exit", null, (_, _) => Close());
        tray.ContextMenuStrip = menu;
        tray.DoubleClick += (_, _) => ShowFromTray();
    }

    private void ShowFromTray()
    {
        Show();
        if (WindowState == WindowState.Minimized)
        {
            WindowState = WindowState.Normal;
        }

        Activate();
    }

    private void RestoreWindowState()
    {
        var settings = new SettingsStore().Load();
        if (settings.WindowWidth >= 800 && settings.WindowHeight >= 500)
        {
            Width = settings.WindowWidth;
            Height = settings.WindowHeight;
        }

        if (settings.WindowLeft is { } left && settings.WindowTop is { } top)
        {
            Left = left;
            Top = top;
            if (!IsOnAnyScreen(new Rect(left, top, Width, Height)))
            {
                // The monitor that held the window is gone or was rearranged.
                WindowStartupLocation = WindowStartupLocation.CenterScreen;
                Left = double.NaN;
                Top = double.NaN;
            }
        }

        if (settings.WindowMaximized)
        {
            WindowState = WindowState.Maximized;
        }
    }

    /// <summary>A saved position is only useful if that part of the desktop still exists.</summary>
    private static bool IsOnAnyScreen(Rect bounds)
    {
        var virtualScreen = new Rect(
            SystemParameters.VirtualScreenLeft,
            SystemParameters.VirtualScreenTop,
            SystemParameters.VirtualScreenWidth,
            SystemParameters.VirtualScreenHeight);
        var overlap = Rect.Intersect(bounds, virtualScreen);
        return !overlap.IsEmpty && overlap.Width > 80 && overlap.Height > 40;
    }

    private void SaveWindowState()
    {
        var settings = new SettingsStore();
        var current = settings.Load();
        var bounds = WindowState == WindowState.Normal
            ? new Rect(Left, Top, Width, Height)
            : RestoreBounds;
        current.WindowLeft = bounds.Left;
        current.WindowTop = bounds.Top;
        current.WindowWidth = bounds.Width;
        current.WindowHeight = bounds.Height;
        current.WindowMaximized = WindowState == WindowState.Maximized;
        settings.Save(current);
    }

    private void Minimize_Click(object sender, RoutedEventArgs e)
    {
        SystemCommands.MinimizeWindow(this);
    }

    private void Maximize_Click(object sender, RoutedEventArgs e)
    {
        if (WindowState == WindowState.Maximized)
        {
            SystemCommands.RestoreWindow(this);
        }
        else
        {
            SystemCommands.MaximizeWindow(this);
        }
    }

    private void Close_Click(object sender, RoutedEventArgs e)
    {
        SystemCommands.CloseWindow(this);
    }

    public async Task RunTurnAsync(string goal, string? outPath, string? shotPath, string? approval = null)
    {
        outputPath = outPath;
        autoApproval = approval;
        await ConnectAsync();
        await SendAsync(goal);
        WriteLog();
        if (shotPath != null)
        {
            await Task.Delay(400);
            SaveShot(shotPath);
        }

        Application.Current.Shutdown();
    }

    public async Task ListAsync(string? outPath)
    {
        outputPath = outPath;
        await ConnectAsync();
        foreach (var conversation in conversations)
        {
            Log($"{conversation.Id} | {conversation.Title} | {conversation.MessageCount}");
        }

        WriteLog();
        Application.Current.Shutdown();
    }

    public void SaveShot(string path) => WindowShot.Save(this, path);

    /// <summary>A real screen grab of the window, frame and shadow included.</summary>
    public void FrameShot(string path)
    {
        Activate();
        Thread.Sleep(700);
        var png = device.CaptureWindow();
        if (png == null)
        {
            File.WriteAllText(path + ".error", "no frame");
        }
        else
        {
            File.WriteAllBytes(path, png);
        }

        Application.Current.Shutdown();
    }

    /// <summary>W6: a chat with real content, a long answer, an attachment and an error line.</summary>
    public void ShotChat(string directory)
    {
        Directory.CreateDirectory(directory);
        EmptyState.Visibility = Visibility.Collapsed;
        messages.Clear();
        messages.Add(new MessageVm { Role = "user", Text = "Pay the internet bill, then email me the receipt." });
        messages.Add(new MessageVm
        {
            Role = "assistant",
            Text = "Done. CityNet was paid 42.00 from the household account, the payment screen " +
                   "confirmed it, and the receipt went to your inbox. The bank app is still open " +
                   "on the payments screen if you want to check the reference number yourself.",
        });
        messages.Add(new MessageVm { Role = "user", Text = "Thanks, and remind me on the 3rd." });
        pendingAttachment = null;
        PendingAttachmentName.Text = "bill-2026-11.pdf";
        PendingAttachmentDetail.Text = "48 KB \u00B7 application/pdf";
        PendingAttachmentBar.Visibility = Visibility.Visible;
        StatusText.Text = "";
        ErrorText.Text = "The bridge is not running; the last step was not verified.";
        ErrorText.Visibility = Visibility.Visible;
        RailStatus.Text = "Succeeded";
        RailFacts.Text = "4 steps · 6.2 s";
        RailDot.Fill = new SolidColorBrush(Color.FromRgb(0x2E, 0x7D, 0x5B));
        RailTitle.Text = "LAST RUN";
        RailSteps.ItemsSource = new[]
        {
            new RailStepVm { Number = "1", Verb = "Open app", Detail = "Calculator, brought to the front",
                Dot = new SolidColorBrush(Color.FromRgb(0x2E, 0x7D, 0x5B)) },
            new RailStepVm { Number = "2", Verb = "Type", Detail = "42.00 into the amount field",
                Dot = new SolidColorBrush(Color.FromRgb(0x2E, 0x7D, 0x5B)) },
            new RailStepVm { Number = "3", Verb = "Tap", Detail = "Confirm, payment, approved by the family",
                Dot = new SolidColorBrush(Color.FromRgb(0x2E, 0x7D, 0x5B)) },
            new RailStepVm { Number = "4", Verb = "Verified", Detail = "receipt sent; the paid screen matched",
                Dot = new SolidColorBrush(Color.FromRgb(0x7B, 0x61, 0x3A)) },
        };
        WindowShot.Save(this, Path.Combine(directory, "windows-w6-chat.png"));
        Application.Current.Shutdown();
    }

    /// <summary>W6: the controls Tab can reach, in visual-tree order, with their names.</summary>
    public void KeyboardCheck(string directory)
    {
        Directory.CreateDirectory(directory);
        var stops = new List<string>();
        CollectStops(this, stops);
        var lines = new List<string>
        {
            "tab order (visual tree): " + string.Join(" -> ", stops),
            $"focusable stops: {stops.Count}",
            "focus ring: #E8703A, 1.5 px, from the shared Button and ListBoxItem templates",
        };
        File.WriteAllLines(Path.Combine(directory, "keyboard-check.txt"), lines);
        Application.Current.Shutdown();
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

    /// <summary>W6: the windows that only appear mid-turn, rendered for the parity table.</summary>
    public void ShotComponents(string directory)
    {
        Directory.CreateDirectory(directory);

        var approval = new ApprovalWindow(new System.Text.Json.Nodes.JsonObject
        {
            ["title"] = "Pay the internet bill?",
            ["body"] = "The bank app is open on the payment screen.",
            ["amount"] = "42.00",
            ["merchant"] = "CityNet",
            ["consequence"] = "The money leaves the account and cannot be taken back.",
        })
        {
            Owner = this,
        };
        approval.Show();
        approval.UpdateLayout();
        Directory.CreateDirectory(directory);
        WindowShot.Save(approval, Path.Combine(directory, "windows-w6-approval.png"));
        approval.Close();

        var steps = new StepsWindow(new[]
        {
            "1 tap Payments (verified)",
            "2 tap Internet (verified)",
            "3 type 42.00 (verified)",
            "4 tap Confirm, payment, approved by the family",
        })
        {
            Owner = this,
        };
        steps.Show();
        steps.UpdateLayout();
        WindowShot.Save(steps, Path.Combine(directory, "windows-w6-steps.png"));
        steps.Close();

        Application.Current.Shutdown();
    }

    /// <summary>
    /// W4 close-out: the desktop behaviours that need a window but not a sidecar.
    /// Writes a transcript and one screenshot; every line is a claim the reader
    /// can check in the UI.
    /// </summary>
    public void W4Check(string directory)
    {
        Directory.CreateDirectory(directory);
        var lines = new List<string>();
        try
        {
            W4CheckBody(directory, lines);
        }
        catch (Exception error)
        {
            lines.Add($"error: {error.GetType().Name}: {error.Message}");
        }

        File.WriteAllLines(Path.Combine(directory, "w4-check.txt"), lines);
        Application.Current.Shutdown();
    }

    private void W4CheckBody(string directory, List<string> lines)
    {
        lines.AddRange(new[]
        {
            $"tray icon created: {tray != null}",
            $"tray Stop disabled before a turn: {trayStop?.Enabled == false}",
            $"tray tooltip: '{tray?.Text}'",
            $"high contrast active: {SystemParameters.HighContrast}",
            "shortcuts: Ctrl+N new chat; Ctrl+F or Ctrl+K search; Enter send; Shift+Enter newline; Esc stop",
            $"window bounds: {Left:0},{Top:0} {Width:0}x{Height:0}",
            $"window on a screen: {IsOnAnyScreen(new Rect(Left, Top, Width, Height))}",
            $"off-screen restore refused: {!IsOnAnyScreen(new Rect(-9000, -9000, Width, Height))}",
            $"automation names on controls: {CountNames(this)}",
            $"focusable controls: {CountFocusable(this)}",
            $"tab navigation: {KeyboardNavigation.GetTabNavigation(this)}",
        });

        if (tray != null)
        {
            tray.ShowBalloonTip(3000, "HOPA", "W4 check: notification while the window is unfocused", System.Windows.Forms.ToolTipIcon.Info);
            lines.Add("toast: shown through the tray balloon");
        }
        else
        {
            lines.Add("toast: no tray icon");
        }

        var shot = Path.Combine(directory, "windows-w4.png");
        WindowShot.Save(this, shot);
        lines.Add($"screenshot: {shot}");
    }

    private static int CountFocusable(DependencyObject root)
    {
        var count = root is System.Windows.FrameworkElement element && element.Focusable && element.IsVisible ? 1 : 0;
        var children = System.Windows.Media.VisualTreeHelper.GetChildrenCount(root);
        for (var index = 0; index < children; index++)
        {
            count += CountFocusable(System.Windows.Media.VisualTreeHelper.GetChild(root, index));
        }

        return count;
    }

    private static int CountNames(DependencyObject root)
    {
        var count = System.Windows.Automation.AutomationProperties.GetName(root).Length > 0 ? 1 : 0;
        var children = System.Windows.Media.VisualTreeHelper.GetChildrenCount(root);
        for (var index = 0; index < children; index++)
        {
            count += CountNames(System.Windows.Media.VisualTreeHelper.GetChild(root, index));
        }

        return count;
    }

    public async Task ShotSettingsAsync(string path)
    {
        await ConnectAsync();
        var dialog = new SettingsWindow { Owner = this };
        dialog.Show();
        await Task.Delay(600);
        WindowShot.Save(dialog, path);
        dialog.Close();
        Application.Current.Shutdown();
    }

    public async Task DraftCheckAsync(string path)
    {
        await ConnectAsync();
        var lines = new List<string>();
        if (client == null || currentId == null)
        {
            lines.Add("draft round-trip: FAIL (not connected)");
            File.WriteAllLines(path, lines);
            Application.Current.Shutdown();
            return;
        }

        var firstId = currentId;
        var other = conversations.FirstOrDefault(item => item.Id != firstId);
        if (other == null)
        {
            var created = await client.CreateConversationAsync();
            var id = created?["id"]?.GetValue<string>();
            if (id != null)
            {
                conversations.Add(ToVm(created!));
                other = conversations.First(item => item.Id == id);
            }
        }

        if (other == null)
        {
            lines.Add("draft round-trip: FAIL (no second conversation)");
            File.WriteAllLines(path, lines);
            Application.Current.Shutdown();
            return;
        }

        Composer.Text = "draft one";
        await SelectAsync(other.Id);
        var cleared = Composer.Text;
        await SelectAsync(firstId);
        var restored = Composer.Text;
        lines.Add($"second conversation: {other.Id}");
        lines.Add($"composer after switch: '{cleared}' (expected '')");
        lines.Add($"draft restored: '{restored}' (expected 'draft one')");
        lines.Add($"draft round-trip: {(cleared.Length == 0 && restored == "draft one" ? "ok" : "FAIL")}");
        File.WriteAllLines(path, lines);
        Application.Current.Shutdown();
    }

    public async Task BridgeCheckAsync(string url, string token, string path)
    {
        var settings = new SettingsStore();
        var current = settings.Load();
        current.BridgeUrl = url;
        current.UseBridge = true;
        settings.Save(current);
        CredentialStore.Write("hopa.bridge.token", token);

        outputPath = path;
        autoApproval = "allow";
        await ConnectAsync();
        await SendAsync("open settings on the phone");
        WriteLog();
        Application.Current.Shutdown();
    }

    public async Task MatrixCheckAsync(string path)
    {
        await ConnectAsync();
        var lines = new List<string>();
        var directory = Path.GetDirectoryName(Path.GetFullPath(path)) ?? ".";
        try
        {
            device.Act("type", new JsonObject { ["text"] = "blind" });
            lines.Add("blind type: FAIL (it was allowed)");
        }
        catch (Exception error)
        {
            lines.Add($"blind type refused: {error.Message}");
        }

        foreach (var app in new[] { "notepad", "calc", "explorer", "chrome", "code" })
        {
            lines.Add($"--- {app}");
            try
            {
                lines.Add(device.Act("launch", new JsonObject { ["app"] = app }));
                await Task.Delay(1500);
                var (observation, nodes) = device.Observe();
                var foreground = observation["app"]?.GetValue<string>() ?? "";
                lines.Add($"observe: app={foreground} nodes={nodes}");
                var png = device.CaptureWindow();
                if (png != null)
                {
                    var shot = Path.Combine(directory, $"windows-matrix-{app}.png");
                    File.WriteAllBytes(shot, png);
                    lines.Add($"screenshot: {shot} ({png.Length} bytes)");
                }
                else
                {
                    lines.Add("screenshot: none");
                }

                if (app == "notepad")
                {
                    if (!foreground.Contains("notepad", StringComparison.OrdinalIgnoreCase))
                    {
                        lines.Add($"type skipped: foreground={foreground}, not Notepad");
                    }
                    else
                    {
                        var refId = device.FirstEditableRef();
                        if (refId == null)
                        {
                            lines.Add("type: no editable field in the observation");
                        }
                        else
                        {
                            device.Act("tap", new JsonObject { ["ref"] = refId });
                            device.Act("type", new JsonObject
                            {
                                ["ref"] = refId,
                                ["text"] = "HOPA matrix 2026",
                            });
                            lines.Add($"type via {refId}: readback='{device.ReadRefValue(refId)}'");
                        }
                    }
                }
            }
            catch (Exception error)
            {
                lines.Add($"error: {error.Message}");
            }
        }

        File.WriteAllLines(path, lines);
        Application.Current.Shutdown();
    }

    public async Task AttachCheckAsync(string file, string path)
    {
        outputPath = path;
        await ConnectAsync();
        var lines = new List<string>();
        if (client == null)
        {
            lines.Add("attach check: FAIL (not connected)");
        }
        else
        {
            try
            {
                var attachment = await client.AttachFileAsync(file);
                var name = attachment["name"]?.GetValue<string>() ?? "";
                var bytes = attachment["bytes"]?.GetValue<long>() ?? 0;
                var local = attachment["path"]?.GetValue<string>() ?? "";
                var created = await client.CreateConversationAsync();
                var id = created?["id"]?.GetValue<string>() ?? "";
                await client.StartTurnAsync($"attached {name}", id, attachment);
                var exported = await client.ExportConversationAsync(id);
                lines.Add($"attached: {name} ({bytes} bytes)");
                lines.Add($"in conversation: {exported.Contains(name)}");
                lines.Add($"copy exists: {File.Exists(local)}");
            }
            catch (Exception error)
            {
                lines.Add($"error: {error.Message}");
            }
        }

        File.WriteAllLines(path, lines);
        Application.Current.Shutdown();
    }

    public async Task CancelCheckAsync(string path)
    {
        outputPath = path;
        autoApproval = "allow";
        await ConnectAsync();
        var lines = new List<string>();
        if (client == null)
        {
            lines.Add("cancel check: FAIL (not connected)");
        }
        else
        {
            try
            {
                var turn = client.StartTurnAsync("slow turn please", currentId);
                await Task.Delay(1000);
                client.CancelTurn();
                var (answer, _, _, steps, _) = await turn;
                lines.Add($"answer: {answer}");
                lines.Add($"cancelled: {answer.Contains("Stopped", StringComparison.OrdinalIgnoreCase)}");
                lines.Add($"steps: {steps?.Count ?? 0}");
            }
            catch (Exception error)
            {
                lines.Add($"error: {error.Message}");
            }
        }

        File.WriteAllLines(path, lines);
        Application.Current.Shutdown();
    }

    public async Task VoiceCheckAsync(string url, string path)
    {
        var token = CredentialStore.Read("hopa.bridge.token");
        var lines = new List<string>();
        try
        {
            var wav = await voice.SpeakAsync(url, token, "hello from hopa");
            lines.Add($"speak: {(wav is { Length: > 44 } ? "ok" : "FAIL")} ({wav?.Length ?? 0} bytes)");
            if (wav != null)
            {
                var text = await voice.TranscribeAsync(url, token, wav);
                lines.Add($"transcribe: '{text}'");
                lines.Add($"round-trip: {(text.Length > 0 ? "ok" : "FAIL")}");
            }
        }
        catch (Exception error)
        {
            lines.Add($"error: {error.Message}");
        }

        File.WriteAllLines(path, lines);
        Application.Current.Shutdown();
    }

    public async Task HistoryCheckAsync(string path)
    {
        outputPath = path;
        await ConnectAsync();
        var lines = new List<string>();
        if (client == null)
        {
            lines.Add("history check: FAIL (not connected)");
            File.WriteAllLines(path, lines);
            Application.Current.Shutdown();
            return;
        }

        var created = await client.CreateConversationAsync();
        var id = created?["id"]?.GetValue<string>() ?? "";
        string renamed = "FAIL";
        var hits = new List<JsonObject>();
        var exported = "";
        var deleted = false;
        var remaining = -1;
        try
        {
            renamed = await client.RenameConversationAsync(id, "Groceries") is { } r
                ? r["title"]?.GetValue<string>() ?? "FAIL"
                : "FAIL";
            hits = await client.SearchConversationsAsync("Grocer");
            exported = await client.ExportConversationAsync(id);
            var pinned = (await client.PinConversationAsync(id, true))?["pinned"]?.GetValue<bool>() == true;
            var archived = (await client.ArchiveConversationAsync(id, true))?["archivedAt"]?.GetValue<long>() > 0;
            var hidden = !(await client.ListConversationsAsync(false))
                .Any(item => item["id"]?.GetValue<string>() == id);
            var shown = (await client.ListConversationsAsync(true))
                .Any(item => item["id"]?.GetValue<string>() == id);
            lines.Add($"pin: {pinned}");
            lines.Add($"archive: {archived}; hidden: {hidden}; shown when asked: {shown}");
            deleted = await client.DeleteConversationAsync(id);
            remaining = (await client.ListConversationsAsync()).Count;
        }
        catch (Exception error)
        {
            lines.Add($"error: {error.Message}");
        }

        lines.Add($"created: {(id.Length > 0 ? "ok" : "FAIL")}");
        lines.Add($"renamed: {renamed}");
        lines.Add($"search hits: {hits.Count}");
        lines.Add($"export has title: {exported.Contains("\"Groceries\"")}");
        lines.Add($"delete: {deleted}");
        lines.Add($"conversations left: {remaining}");
        File.WriteAllLines(path, lines);
        Application.Current.Shutdown();
    }

    public async Task PcCheckAsync(string path)
    {
        var settings = new SettingsStore();
        var current = settings.Load();
        current.UseBridge = false;
        settings.Save(current);

        outputPath = path;
        autoApproval = "allow";
        await ConnectAsync();
        await SendAsync("open notepad");
        await SendAsync("type hello in notepad");
        WriteLog();
        Application.Current.Shutdown();
    }

    public async Task PairAsync(string url, string code, string path)
    {
        var (ok, token, refresh) = await PostAsync(url, "/pair", new { code });
        if (ok && token.Length > 0)
        {
            CredentialStore.Write("hopa.bridge.token", token);
            CredentialStore.Write("hopa.bridge.refresh", refresh);
            var settings = new SettingsStore();
            var current = settings.Load();
            current.BridgeUrl = url;
            current.UseBridge = true;
            settings.Save(current);
        }

        File.WriteAllLines(path, new[]
        {
            $"pair: {(ok && token.Length > 0 ? "ok" : "FAIL")}",
            $"refresh stored: {refresh.Length > 0}",
        });
        Application.Current.Shutdown();
    }

    public async Task StaleCheckAsync(string url, string path)
    {
        var staleToken = CredentialStore.Read("hopa.bridge.token");
        var refresh = CredentialStore.Read("hopa.bridge.refresh");
        var (ok, newToken, newRefresh) = await PostAsync(url, "/refresh", new { refresh });
        // Keep the old token (now rejected) and hand the sidecar the rotated refresh.
        CredentialStore.Write("hopa.bridge.refresh", newRefresh);
        outputPath = path;
        autoApproval = "allow";
        await ConnectAsync();
        await SendAsync("open settings on the phone");
        Log($"stale check: rotation={(ok && newToken.Length > 0 ? "ok" : "FAIL")} " +
            $"token_changed={newToken != staleToken}");
        WriteLog();
        Application.Current.Shutdown();
    }

    private static async Task<(bool Ok, string Token, string Refresh)> PostAsync(
        string url,
        string path,
        object body)
    {
        using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(15) };
        var payload = JsonSerializer.Serialize(body);
        var response = await http.PostAsync(
            url.TrimEnd('/') + path,
            new StringContent(payload, Encoding.UTF8, "application/json"));
        var text = await response.Content.ReadAsStringAsync();
        var node = response.IsSuccessStatusCode ? JsonNode.Parse(text) as JsonObject : null;
        return (
            response.IsSuccessStatusCode,
            node?["token"]?.GetValue<string>() ?? "",
            node?["refresh"]?.GetValue<string>() ?? "");
    }

    public Task SettingsCheckAsync(string path)
    {
        var store = new SettingsStore();
        var original = store.Load();
        var probe = new AppSettings
        {
            BridgeUrl = "http://127.0.0.1:8901",
            UseBridge = true,
            ModelProvider = "lan",
            ModelBaseUrl = "http://127.0.0.1:11434/v1",
            Tone = "neutral",
        };
        store.Save(probe);
        var loaded = store.Load();
        var settingsOk = loaded.BridgeUrl == probe.BridgeUrl
            && loaded.UseBridge
            && loaded.ModelProvider == "lan"
            && loaded.Tone == "neutral";

        CredentialStore.Write("hopa.test.secret", "s3cret");
        var secretOk = CredentialStore.Read("hopa.test.secret") == "s3cret";
        CredentialStore.Delete("hopa.test.secret");
        var gone = CredentialStore.Read("hopa.test.secret").Length == 0;

        store.Save(original);
        File.WriteAllLines(path, new[]
        {
            $"settings round-trip: {(settingsOk ? "ok" : "FAIL")}",
            $"credential round-trip: {(secretOk ? "ok" : "FAIL")}",
            $"credential delete: {(gone ? "ok" : "FAIL")}",
            $"settings file: {store.FilePath}",
        });
        Application.Current.Shutdown();
        return Task.CompletedTask;
    }

    private async Task ConnectAsync()
    {
        connecting ??= ConnectCoreAsync();
        await connecting;
    }

    private async Task ConnectCoreAsync()
    {
        try
        {
            var started = new SidecarClient();
            started.LogReceived += line => Log($"sidecar: {line}");
            started.DeviceRequested += OnDeviceRequested;
            started.ApprovalRequested += OnApprovalRequested;
            started.SessionUpdated += message =>
            {
                var token = message["token"]?.GetValue<string>() ?? "";
                var refresh = message["refresh"]?.GetValue<string>() ?? "";
                if (token.Length > 0)
                {
                    CredentialStore.Write("hopa.bridge.token", token);
                    CredentialStore.Write("hopa.bridge.refresh", refresh);
                    Log("bridge session rotated; the host stored the new pair");
                }
            };
            started.StepReceived += message =>
            {
                var index = message["index"]?.GetValue<int>() ?? 0;
                var action = message["action"]?.GetValue<string>() ?? "?";
                var tier = message["tier"]?.GetValue<string>() ?? "";
                var executed = message["executed"]?.GetValue<bool>() == true;
                Log($"step {index}: {action} tier={tier} executed={executed}");
            };
            client = started;

            gateway = CreateGateway();

            StatusText.Text = "Ready";
            UpdateRailBridge();
            await RefreshAsync();
            await ApplySettingsAsync();
        }
        catch (Exception error)
        {
            ErrorText.Text = error.Message;
            ErrorText.Visibility = Visibility.Visible;
            StatusText.Text = error.Message;
            Log($"error: {error.Message}");
        }
    }

    private GatewayClient CreateGateway()
    {
        var created = new GatewayClient();
        created.StateChanged += () => Dispatcher.BeginInvoke(() =>
        {
            client?.SendGatewayState(created.Paired, created.HasPhone);
            Log($"gateway: {created.Status}; phone={(created.HasPhone ? "online" : "offline")}");
        });
        created.TaskReceived += message => Dispatcher.BeginInvoke(() =>
            Log($"gateway task: {(message["body"] as JsonObject)?["goal"]?.GetValue<string>() ?? message["task"]?.GetValue<string>()}"));
        created.Start();
        return created;
    }

    private async Task RefreshAsync()
    {
        if (client == null)
        {
            return;
        }

        var items = await client.ListConversationsAsync(ShowArchivedBox.IsChecked == true);
        allConversations.Clear();
        foreach (var item in items)
        {
            allConversations.Add(ToVm(item));
        }

        if (allConversations.Count == 0)
        {
            var created = await client.CreateConversationAsync();
            if (created != null)
            {
                allConversations.Add(ToVm(created));
            }
        }

        ApplyFilter();
        if (allConversations.Count > 0)
        {
            await SelectAsync(allConversations[0].Id);
        }
    }

    private async Task SelectAsync(string id)
    {
        if (client == null || currentId == id)
        {
            return;
        }

        if (currentId != null)
        {
            drafts[currentId] = Composer.Text;
        }

        var open = await client.OpenConversationAsync(id);
        currentId = id;
        messages.Clear();
        if (open?["messages"] is JsonArray list)
        {
            foreach (var node in list)
            {
                if (node is JsonObject message)
                {
                    messages.Add(new MessageVm
                    {
                        Role = message["role"]?.GetValue<string>() ?? "assistant",
                        Text = message["text"]?.GetValue<string>() ?? "",
                    });
                }
            }
        }

        Composer.Text = drafts.TryGetValue(id, out var draft) ? draft : "";
        TitleText.Text = open?["title"]?.GetValue<string>() ?? "New chat";
        EmptyState.Visibility = messages.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
        switching = true;
        ConversationList.SelectedItem = conversations.FirstOrDefault(item => item.Id == id)
            ?? allConversations.FirstOrDefault(item => item.Id == id);
        switching = false;
        ScrollToEnd();
        StatusText.Text = "";
    }

    private async Task SendAsync(string goal)
    {
        if (client == null || running)
        {
            return;
        }

        var attachment = pendingAttachment;
        pendingAttachment = null;
        PendingAttachmentBar.Visibility = Visibility.Collapsed;
        var body = goal.Length > 0
            ? goal
            : attachment != null ? Describe(attachment) : "";

        var previousQuestion = lastQuestion;
        var clock = System.Diagnostics.Stopwatch.StartNew();
        running = true;
        SendButton.IsEnabled = true;
        SendButton.Content = "\u25A0";
        if (tray != null)
        {
            tray.Text = "HOPA (working)";
        }

        if (trayStop != null)
        {
            trayStop.Enabled = true;
        }

        StatusText.Text = "Working...";
        ErrorText.Visibility = Visibility.Collapsed;
        messages.Add(new MessageVm { Role = "user", Text = body });
        EmptyState.Visibility = Visibility.Collapsed;
        ScrollToEnd();
        try
        {
            var (answer, conversationId, title, steps, chainOk) =
                await client.StartTurnAsync(body, currentId, attachment);
            currentId = conversationId;
            MarkSelected(conversationId);
            messages.Add(new MessageVm { Role = "assistant", Text = answer });
            Log($"HOPA: {answer}");
            lastAnswer = answer;
            CopyButton.IsEnabled = answer.Length > 0;
            SpeakButton.IsEnabled = answer.Length > 0;
            AnswerActions.Visibility = Visibility.Visible;
            if (!IsActive)
            {
                var preview = answer.Length > 140 ? answer[..140] + "..." : answer;
                tray?.ShowBalloonTip(4000, "HOPA", preview, System.Windows.Forms.ToolTipIcon.Info);
            }
            lastSteps = steps;
            lastChainOk = chainOk;
            DetailsButton.IsEnabled = steps is { Count: > 0 };
            foreach (var line in StepLines(steps))
            {
                Log($"step {line}");
            }

            if (steps is { Count: > 0 })
            {
                Log($"chain: {(chainOk ? "ok" : "failed")}");
                RailTitle.Text = "LAST RUN";
                RailStatus.Text = chainOk ? "Succeeded" : "Failed";
                RailFacts.Text = $"{steps.Count} steps";
                RailDot.Fill = new SolidColorBrush(chainOk
                    ? Color.FromRgb(0x2E, 0x7D, 0x5B)
                    : Color.FromRgb(0xC0, 0x39, 0x2B));
                RailSteps.ItemsSource = steps
                    .OfType<JsonObject>()
                    .Select(step => ToRailStep(step))
                    .ToList();
            }
            else
            {
                RailTitle.Text = "THIS ANSWER";
                RailStatus.Text = "Answered";
                RailFacts.Text = "no local record";
                RailDot.Fill = new SolidColorBrush(Color.FromRgb(0x2E, 0x7D, 0x5B));
            }

            TitleText.Text = title;
            clock.Stop();
            RailMeasured.Text = $"answered in {clock.Elapsed.TotalSeconds:0.0} s";
            RailMeasured.Visibility = Visibility.Visible;
            if (previousQuestion.Length > 0)
            {
                RailEarlier.Text = "Earlier: " + previousQuestion;
                RailEarlier.Visibility = Visibility.Visible;
            }

            lastQuestion = body;
            UpsertConversation(conversationId, title);
            ScrollToEnd();
            StatusText.Text = "";
        }
        catch (Exception error)
        {
            StatusText.Text = error.Message;
            Log($"error: {error.Message}");
        }
        finally
        {
            running = false;
            SendButton.IsEnabled = true;
            SendButton.Content = "\u2191";
            if (tray != null)
            {
                tray.Text = "HOPA";
            }

            if (trayStop != null)
            {
                trayStop.Enabled = false;
            }

            WriteLog();
        }
    }

    private async Task SendFromComposerAsync()
    {
        if (running)
        {
            client?.CancelTurn();
            StatusText.Text = "Stopping...";
            return;
        }

        var goal = Composer.Text.Trim();
        if (goal.Length == 0 && pendingAttachment == null)
        {
            return;
        }

        if (currentId != null)
        {
            drafts[currentId] = "";
        }

        Composer.Text = "";
        await SendAsync(goal);
    }

    private void UpdateRailBridge()
    {
        var settings = new SettingsStore().Load();
        var live = settings.BridgeUrl.Length > 0;
        RailBridge.Text = live
            ? "Bridge connected · every action asks first."
            : "No bridge · HOPA sees only this conversation.";
        NoBridgeHint.Visibility = live ? Visibility.Collapsed : Visibility.Visible;
        var useBridge = new SettingsStore().Load().UseBridge;
        TargetChip.Visibility = live ? Visibility.Visible : Visibility.Collapsed;
        TargetChip.Text = useBridge ? "Phone" : "Laptop";
        TargetChip.Foreground = useBridge
            ? new SolidColorBrush(Color.FromRgb(0x0A, 0x59, 0xF7))
            : new SolidColorBrush(Color.FromRgb(0x6B, 0x66, 0x5C));
        SubtitleText.Text = live ? "HOPA · Running on this laptop" : "Running on this laptop";
        RailBridgeDot.Fill = new SolidColorBrush(live
            ? Color.FromRgb(0x2E, 0x7D, 0x5B)
            : Color.FromRgb(0xB2, 0x6A, 0x00));
    }

    private void MarkSelected(string? id)
    {
        foreach (var item in allConversations)
        {
            item.Selected = item.Id == id;
        }
    }

    private void UpsertConversation(string id, string title)
    {
        var existing = allConversations.FirstOrDefault(item => item.Id == id);
        if (existing != null)
        {
            existing.Title = title;
            existing.UpdatedLabel = "now";
            existing.UpdatedAt = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            return;
        }

        var created = new ConversationVm
        {
            Id = id,
            Title = title,
            UpdatedLabel = "now",
            UpdatedAt = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
        };
        allConversations.Insert(0, created);
        if (SearchBox.Text.Trim().Length == 0)
        {
            conversations.Insert(0, created);
        }
    }

    private void Composer_TextChanged(object sender, TextChangedEventArgs e) =>
        ComposerPlaceholder.Visibility = Composer.Text.Length == 0 ? Visibility.Visible : Visibility.Collapsed;

    private async void TargetChip_Click(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        var store = new SettingsStore();
        var settings = store.Load();
        settings.UseBridge = !settings.UseBridge;
        store.Save(settings);
        UpdateRailBridge();
        await ApplySettingsAsync();
    }

    private void NoBridge_Click(object sender, System.Windows.Input.MouseButtonEventArgs e) =>
        Settings_Click(this, new RoutedEventArgs());

    private void UpdateSearchPlaceholder() =>
        SearchPlaceholder.Visibility = SearchBox.Text.Length == 0 ? Visibility.Visible : Visibility.Collapsed;

    private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        UpdateSearchPlaceholder();
        ApplyFilter();
    }

    private async void Window_Drop(object sender, DragEventArgs e)
    {
        if (client == null || !e.Data.GetDataPresent(DataFormats.FileDrop))
        {
            return;
        }

        if (e.Data.GetData(DataFormats.FileDrop) is not string[] files || files.Length == 0)
        {
            return;
        }

        try
        {
            var attachment = await client.AttachFileAsync(files[0]);
            pendingAttachment = attachment;
            PendingAttachmentName.Text = attachment["name"]?.GetValue<string>() ?? "file";
            var bytes = attachment["bytes"]?.GetValue<long>() ?? 0;
            PendingAttachmentDetail.Text =
                $"{HumanSize(bytes)} \u00B7 {attachment["mime"]?.GetValue<string>()}";
            PendingAttachmentBar.Visibility = Visibility.Visible;
            StatusText.Text = "File ready to send";
        }
        catch (Exception error)
        {
            StatusText.Text = error.Message;
        }
    }

    private async void RemoveAttachment_Click(object sender, RoutedEventArgs e)
    {
        var path = pendingAttachment?["path"]?.GetValue<string>();
        pendingAttachment = null;
        PendingAttachmentBar.Visibility = Visibility.Collapsed;
        if (path != null && client != null)
        {
            try
            {
                await client.RequestAsync("file.remove", new JsonObject { ["path"] = path },
                    TimeSpan.FromSeconds(10));
            }
            catch (Exception error)
            {
                Log($"attachment: {error.Message}");
            }
        }
    }

    private static string HumanSize(long bytes) => bytes switch
    {
        >= 1024 * 1024 => $"{bytes / (1024.0 * 1024.0):0.0} MB",
        >= 1024 => $"{bytes / 1024} KB",
        _ => $"{bytes} B",
    };

    private static string Describe(JsonObject attachment)
    {
        var name = attachment["name"]?.GetValue<string>() ?? "file";
        var mime = attachment["mime"]?.GetValue<string>() ?? "";
        return mime.StartsWith("image/", StringComparison.OrdinalIgnoreCase)
            ? $"Shared an image: {name}"
            : $"Shared a file: {name}";
    }

    private void ApplyFilter()
    {
        var query = SearchBox.Text.Trim();
        var showArchived = ShowArchivedBox.IsChecked == true;
        var ordered = allConversations
            .OrderByDescending(item => item.Pinned)
            .ThenByDescending(item => item.UpdatedAt)
            .ToList();
        conversations.Clear();
        foreach (var conversation in ordered)
        {
            if (!showArchived && conversation.Archived)
            {
                continue;
            }

            if (query.Length == 0 ||
                conversation.SearchText.Contains(query, StringComparison.OrdinalIgnoreCase))
            {
                conversations.Add(conversation);
            }
        }
    }

    private async void ShowArchived_Click(object sender, RoutedEventArgs e)
    {
        if (client == null)
        {
            return;
        }

        var items = await client.ListConversationsAsync(ShowArchivedBox.IsChecked == true);
        allConversations.Clear();
        foreach (var item in items)
        {
            allConversations.Add(ToVm(item));
        }

        ApplyFilter();
    }

    private void More_Click(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        if (sender is not FrameworkElement element || element.DataContext is not ConversationVm vm)
        {
            return;
        }

        ConversationList.SelectedItem = vm;
        if (ConversationList.ContextMenu is { } menu)
        {
            menu.PlacementTarget = element;
            menu.IsOpen = true;
        }

        e.Handled = true;
    }

    private async void Pin_Click(object sender, RoutedEventArgs e)
    {
        if (client == null || ConversationList.SelectedItem is not ConversationVm vm)
        {
            return;
        }

        var pinned = !vm.Pinned;
        if (await client.PinConversationAsync(vm.Id, pinned) != null)
        {
            vm.Pinned = pinned;
            ApplyFilter();
        }
    }

    private async void Archive_Click(object sender, RoutedEventArgs e)
    {
        if (client == null || ConversationList.SelectedItem is not ConversationVm vm)
        {
            return;
        }

        var archived = !vm.Archived;
        if (await client.ArchiveConversationAsync(vm.Id, archived) != null)
        {
            vm.Archived = archived;
            ApplyFilter();
            if (archived && !ShowArchivedBox.IsChecked.GetValueOrDefault() && currentId == vm.Id)
            {
                currentId = null;
                messages.Clear();
                if (allConversations.Any(item => !item.Archived))
                {
                    await SelectAsync(allConversations.First(item => !item.Archived).Id);
                }
            }
        }
    }

    private async void Rename_Click(object sender, RoutedEventArgs e)
    {
        if (client == null || ConversationList.SelectedItem is not ConversationVm vm)
        {
            return;
        }

        var dialog = new RenameWindow(vm.Title) { Owner = this };
        if (dialog.ShowDialog() != true || dialog.TitleValue.Length == 0)
        {
            return;
        }

        var renamed = await client.RenameConversationAsync(vm.Id, dialog.TitleValue);
        if (renamed?["title"]?.GetValue<string>() is { } title)
        {
            vm.Title = title;
            TitleText.Text = title;
        }
    }

    private async void Delete_Click(object sender, RoutedEventArgs e)
    {
        if (client == null || ConversationList.SelectedItem is not ConversationVm vm)
        {
            return;
        }

        if (MessageBox.Show($"Delete \"{vm.Title}\"?", "HOPA", MessageBoxButton.OKCancel,
                MessageBoxImage.Question) != MessageBoxResult.OK)
        {
            return;
        }

        if (!await client.DeleteConversationAsync(vm.Id))
        {
            return;
        }

        allConversations.Remove(vm);
        ApplyFilter();
        if (currentId == vm.Id)
        {
            currentId = null;
            messages.Clear();
            if (allConversations.Count > 0)
            {
                await SelectAsync(allConversations[0].Id);
            }
            else
            {
                await RefreshAsync();
            }
        }
    }

    private async void Export_Click(object sender, RoutedEventArgs e)
    {
        if (client == null || ConversationList.SelectedItem is not ConversationVm vm)
        {
            return;
        }

        var json = await client.ExportConversationAsync(vm.Id);
        var dialog = new SaveFileDialog
        {
            FileName = $"{vm.Title}.json",
            Filter = "JSON|*.json",
        };
        if (dialog.ShowDialog() == true)
        {
            File.WriteAllText(dialog.FileName, json);
        }
    }

    private void Copy_Click(object sender, RoutedEventArgs e)
    {
        if (lastAnswer.Length > 0)
        {
            Clipboard.SetText(lastAnswer);
            StatusText.Text = "Copied";
        }
    }

    private async void Speak_Click(object sender, RoutedEventArgs e)
    {
        if (lastAnswer.Length == 0)
        {
            return;
        }

        var settings = new SettingsStore().Load();
        var token = CredentialStore.Read("hopa.bridge.token");
        if (settings.BridgeUrl.Length > 0 && token.Length > 0)
        {
            try
            {
                var wav = await voice.SpeakAsync(settings.BridgeUrl, token, lastAnswer);
                if (wav is { Length: > 44 })
                {
                    voice.Play(wav);
                    StatusText.Text = "Reading aloud";
                    return;
                }
            }
            catch (Exception error)
            {
                Log($"voice: {error.Message}");
            }
        }

        speech ??= new SpeechSynthesizer();
        speech.SpeakAsyncCancelAll();
        speech.SpeakAsync(lastAnswer);
        StatusText.Text = "Reading aloud";
    }

    private async void Mic_Click(object sender, RoutedEventArgs e)
    {
        if (voice.Recording)
        {
            var wav = voice.StopCapture();
            MicButton.Content = "Mic";
            StatusText.Text = "";
            if (wav.Length <= 44)
            {
                StatusText.Text = "Nothing recorded.";
                return;
            }

            await TranscribeAsync(wav);
            return;
        }

        try
        {
            voice.StartCapture();
            MicButton.Content = "Stop";
            StatusText.Text = "Listening...";
        }
        catch (Exception error)
        {
            StatusText.Text = $"No microphone: {error.Message}";
        }
    }

    private async Task TranscribeAsync(byte[] wav)
    {
        var settings = new SettingsStore().Load();
        var token = CredentialStore.Read("hopa.bridge.token");
        if (settings.BridgeUrl.Length == 0 || token.Length == 0)
        {
            StatusText.Text = "Dictation needs the bridge. Set its address and token in Settings.";
            return;
        }

        StatusText.Text = "Transcribing...";
        try
        {
            var text = await voice.TranscribeAsync(settings.BridgeUrl, token, wav);
            if (text.Length == 0)
            {
                StatusText.Text = "I did not catch that.";
                return;
            }

            Composer.Text = Composer.Text.Length == 0 ? text : $"{Composer.Text} {text}";
            Composer.CaretIndex = Composer.Text.Length;
            StatusText.Text = "";
        }
        catch (Exception error)
        {
            StatusText.Text = error.Message;
            Log($"voice: {error.Message}");
        }
    }

    protected override void OnPreviewKeyDown(KeyEventArgs e)
    {
        if ((Keyboard.Modifiers & ModifierKeys.Control) != 0)
        {
            switch (e.Key)
            {
                case Key.N:
                    NewChat_Click(this, new RoutedEventArgs());
                    e.Handled = true;
                    break;
                case Key.F:
                case Key.K:
                    SearchBox.Focus();
                    SearchBox.SelectAll();
                    e.Handled = true;
                    break;
            }
        }

        if (e.Key == Key.Escape)
        {
            if (running)
            {
                client?.CancelTurn();
            }

            speech?.SpeakAsyncCancelAll();
            voice.StopPlayback();
        }

        base.OnPreviewKeyDown(e);
    }

    private async void Settings_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new SettingsWindow { Owner = this };
        if (dialog.ShowDialog() == true)
        {
            await ApplySettingsAsync();
            if (gateway != null)
            {
                await gateway.StopAsync();
                await gateway.DisposeAsync();
            }
            gateway = CreateGateway();
            StatusText.Text = "Settings saved";
        }
    }

    private async Task ApplySettingsAsync()
    {
        if (client == null)
        {
            return;
        }

        try
        {
            var settings = new SettingsStore().Load();
            await client.ConfigureAsync(
                settings,
                CredentialStore.Read("hopa.bridge.token"),
                CredentialStore.Read("hopa.model.key"));
        }
        catch (Exception error)
        {
            StatusText.Text = error.Message;
            Log($"error: {error.Message}");
        }
    }

    private async void NewChat_Click(object sender, RoutedEventArgs e)    {
        if (client == null)
        {
            return;
        }

        var created = await client.CreateConversationAsync();
        if (created == null)
        {
            return;
        }

        var vm = ToVm(created);
        allConversations.Insert(0, vm);
        SearchBox.Clear();
        ApplyFilter();
        currentId = null;
        MarkSelected(vm.Id);
        await SelectAsync(vm.Id);
    }

    private async void ConversationList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (switching || ConversationList.SelectedItem is not ConversationVm vm)
        {
            return;
        }

        await SelectAsync(vm.Id);
    }

    private async void Send_Click(object sender, RoutedEventArgs e)
    {
        await SendFromComposerAsync();
    }

    private async void Composer_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter && (Keyboard.Modifiers & ModifierKeys.Shift) == 0)
        {
            e.Handled = true;
            await SendFromComposerAsync();
        }
    }

    private void OnApprovalRequested(JsonObject message)
    {
        if (autoApproval != null)
        {
            var allowed = autoApproval == "allow";
            Log($"approval: auto-{(allowed ? "allow" : "deny")} {message["title"]?.GetValue<string>()}");
            client?.SendApprovalResult(message["id"]?.GetValue<string>() ?? "", allowed);
            return;
        }

        var phone = gateway?.PhoneDeviceId ?? "";
        if (gateway != null && gateway.IsLive && phone.Length > 0)
        {
            var requestId = message["id"]?.GetValue<string>() ?? "";
            _ = Task.Run(async () =>
            {
                var allow = false;
                var source = "pc";
                try
                {
                    var result = await gateway.RequestApprovalAsync(
                        BuildApproval(message),
                        phone,
                        TimeSpan.FromSeconds(100));
                    allow = ApprovalAllowed(result);
                    source = result == null ? "pc" : "phone";
                    if (result == null)
                    {
                        Log("approval: the phone did not answer; deny");
                    }
                }
                catch (Exception error)
                {
                    Log($"approval: the phone link failed ({error.Message}); deny");
                }
                finally
                {
                    client?.SendApprovalResult(requestId, allow, source);
                    _ = Dispatcher.BeginInvoke(() =>
                        Log($"approval: {(allow ? "allow" : "deny")} from {source}: {message["title"]?.GetValue<string>()}"));
                }
            });
            return;
        }

        Dispatcher.Invoke(() =>
        {
            var allow = false;
            var dialog = new ApprovalWindow(message) { Owner = this };
            if (dialog.ShowDialog() == true)
            {
                allow = true;
            }

            Log($"approval: {(allow ? "allow" : "deny")} {message["title"]?.GetValue<string>()}");
            client?.SendApprovalResult(message["id"]?.GetValue<string>() ?? "", allow);
        });
    }

    private static JsonObject BuildApproval(JsonObject message) => new()
    {
        ["title"] = message["title"]?.GetValue<string>() ?? "Allow this action?",
        ["body"] = message["body"]?.GetValue<string>() ?? "",
        ["amount"] = message["amount"]?.GetValue<string>() ?? "",
        ["merchant"] = message["merchant"]?.GetValue<string>() ?? "",
        ["consequence"] = message["consequence"]?.GetValue<string>() ?? "",
        ["isPayment"] = message["isPayment"]?.GetValue<bool>() ?? false,
        ["action"] = new JsonObject
        {
            ["schemaVersion"] = "1",
            ["kind"] = message["action"]?.GetValue<string>() ?? "ui.tap",
            ["timeoutMs"] = 3000,
        },
    };

    private static bool ApprovalAllowed(JsonObject? result) =>
        (result?["body"] as JsonObject)?["approval"] is JsonObject approval &&
        (approval["allow"]?.GetValue<bool>() ?? false);

    private void Details_Click(object sender, RoutedEventArgs e)
    {
        if (lastSteps == null)
        {
            return;
        }

        var lines = StepLines(lastSteps).ToList();
        if (lines.Count == 0)
        {
            lines.Add("No steps: the answer came without an action.");
        }
        else
        {
            lines.Add($"chain: {(lastChainOk ? "ok" : "failed")}");
        }

        new StepsWindow(lines) { Owner = this }.ShowDialog();
    }

    private static RailStepVm ToRailStep(JsonObject step)
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
        return new RailStepVm
        {
            Number = number > 0 ? number.ToString() : "•",
            Verb = verb,
            Detail = detail,
            Dot = new SolidColorBrush(verified
                ? Color.FromRgb(0x2E, 0x7D, 0x5B)
                : error.Length > 0 ? Color.FromRgb(0xC0, 0x39, 0x2B) : Color.FromRgb(0xB2, 0x6A, 0x00)),
        };
    }

    private static IEnumerable<string> StepLines(JsonArray? steps)
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

    private void OnDeviceRequested(JsonObject message)
    {
        var id = message["id"]?.GetValue<string>() ?? "";
        var op = message["op"]?.GetValue<string>() ?? "";
        if (client == null)
        {
            return;
        }

        try
        {
            if (op == "observe")
            {
                var (observation, nodes) = device.Observe();
                Log($"device: observed {nodes} nodes in '{observation["app"]}'");
                client.SendDeviceResult(id, true, observation: observation);
                return;
            }

            if (op == "foreground")
            {
                var app = device.ForegroundApp();
                client.SendDeviceResult(id, true, app: app);
                return;
            }

            if (op == "screenshot")
            {
                var png = device.CaptureWindow();
                if (png == null)
                {
                    Log("device: no frame (protected or not capturable)");
                    client.SendDeviceResult(id, true);
                    return;
                }

                client.SendDeviceResult(id, true, image: Convert.ToBase64String(png));
                return;
            }

            if (op == "apps")
            {
                var entries = device.Apps();
                var array = new JsonArray();
                foreach (var entry in entries)
                {
                    array.Add(new JsonObject
                    {
                        ["package"] = entry.Package,
                        ["label"] = entry.Label,
                    });
                }

                Log($"device: {entries.Count} apps");
                client.SendDeviceResult(id, true, apps: array);
                return;
            }

            if (op == "openLink")
            {
                var opened = device.OpenLink(message["url"]?.GetValue<string>() ?? "");
                Log($"device: {opened}");
                client.SendDeviceResult(id, true, text: opened);
                return;
            }

            var info = device.Act(op, message);
            Log($"device: {info}");
            client.SendDeviceResult(id, true, text: info);
        }
        catch (Exception error)
        {
            Log($"device error: {error.Message}");
            client.SendDeviceResult(id, false, error.Message);
        }
    }

    private void ScrollToEnd()
    {
        Dispatcher.Invoke(() => MessagesScroll.ScrollToEnd());
    }

    private void Log(string line)
    {
        lock (log)
        {
            log.Add(line);
        }
    }

    private void WriteLog()
    {
        if (outputPath == null)
        {
            return;
        }

        lock (log)
        {
            File.WriteAllLines(outputPath, log);
        }
    }

    private static ConversationVm ToVm(JsonObject item)
    {
        var updatedAt = item["updatedAt"]?.GetValue<long>() ?? 0;
        var title = item["title"]?.GetValue<string>() ?? "New chat";
        var searchParts = new List<string> { title };
        if (item["messages"] is JsonArray messages)
        {
            foreach (var node in messages)
            {
                if (node?["text"]?.GetValue<string>() is { Length: > 0 } text)
                {
                    searchParts.Add(text);
                }
            }
        }

        return new ConversationVm
        {
            Id = item["id"]?.GetValue<string>() ?? "",
            Title = title,
            UpdatedLabel = FormatTime(updatedAt),
            UpdatedAt = updatedAt,
            MessageCount = (item["messages"] as JsonArray)?.Count ?? 0,
            SearchText = string.Join("\n", searchParts),
            Pinned = item["pinned"]?.GetValue<bool>() == true,
            Archived = (item["archivedAt"]?.GetValue<long>() ?? 0) > 0,
        };
    }

    private static string FormatTime(long millis)
    {
        if (millis <= 0)
        {
            return "";
        }

        var time = DateTimeOffset.FromUnixTimeMilliseconds(millis).LocalDateTime;
        return time.Date == DateTime.Today ? time.ToString("HH:mm") : time.ToString("dd MMM");
    }
}
