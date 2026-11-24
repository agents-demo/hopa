using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Linq;
using System.Text.Json.Nodes;
using Hopa.Windows.Integrations.Device;
using Hopa.Windows.Integrations.Engine;
using Hopa.Windows.Integrations.Gateway;
using Hopa.Windows.Storage;
using Hopa.Windows.Ui.Shell;

namespace Hopa.Windows.Ui.Dialogs;

/// <summary>
/// The settings hub. General and Profiles write settings; Memory, Skills,
/// Usage, Capabilities, Recipes and History read the sidecar's shared data.
/// </summary>
public partial class SettingsWindow : Window
{
    private readonly SettingsStore store = new();
    private readonly EngineHostClient? engine;
    private readonly WindowsDevice? device;
    private bool loaded;

    public SettingsWindow() : this(null, null)
    {
    }

    public SettingsWindow(EngineHostClient? engine, WindowsDevice? device = null)
    {
        this.engine = engine;
        this.device = device;
        InitializeComponent();
        LoadSettings();
        SettingsNav.SelectedIndex = 0;
        Loaded += async (_, _) => await RefreshAllAsync();
    }

    private void LoadSettings()
    {
        var settings = store.Load();
        BridgeUrlBox.Text = settings.BridgeUrl;
        BridgeTokenBox.Password = CredentialStore.Read("hopa.bridge.token");
        UseBridgeBox.IsChecked = settings.UseBridge;
        Select(ProviderBox, settings.ModelProvider);
        BaseUrlBox.Text = settings.ModelBaseUrl;
        ModelNameBox.Text = settings.ModelName;
        ModelKeyBox.Password = CredentialStore.Read("hopa.model.key");
        Select(ToneBox, settings.Tone);
        ProfileStatus.Text = $"Current: {settings.Profile}";
        var gateway = GatewayCredentials.Load();
        GatewayStatusText.Text = gateway == null
            ? "Not paired. Pairing is the first step for phone approval."
            : $"Paired as {gateway.DeviceId}.";
        AboutText.Text =
            "HOPA for Windows\n" +
            $"Version {typeof(SettingsWindow).Assembly.GetName().Version}\n\n" +
            "The loop, the gate and the records come from the shared core; " +
            "the Kotlin sidecar is the Windows engine host.\n\n" +
            "Screen text stays out of logs; secrets stay in Windows Credential Manager.";
    }

    private async Task RefreshAllAsync()
    {
        if (loaded)
        {
            return;
        }

        loaded = true;
        await RefreshProfilesAsync();
        await RefreshMemoryAsync();
        await RefreshSkillsAsync();
        await RefreshUsageAsync();
        await RefreshCapabilitiesAsync();
        await RefreshRecipesAsync();
        await RefreshHistoryAsync();
        await RefreshPrivacyAsync();
        RefreshNotifications();
    }

    private async Task RefreshProfilesAsync()
    {
        if (engine == null)
        {
            ProfileStatus.Text = "Start the sidecar from the main window to load profiles.";
            return;
        }

        try
        {
            var (selected, profiles) = await engine.ListProfilesAsync();
            ProfileList.Items.Clear();
            foreach (var profile in profiles)
            {
                var item = new ListBoxItem { Content = profile.Label, Tag = profile.Key };
                ProfileList.Items.Add(item);
                if (profile.Key == selected)
                {
                    ProfileList.SelectedItem = item;
                }
            }

            ProfileStatus.Text = $"Current: {selected}";
        }
        catch (Exception error)
        {
            ProfileStatus.Text = error.Message;
        }
    }

    private async Task RefreshMemoryAsync()
    {
        if (engine == null)
        {
            MemoryStatus.Text = "Start the sidecar from the main window to load memory.";
            return;
        }

        try
        {
            var facts = await engine.ListMemoryAsync();
            MemoryList.Items.Clear();
            foreach (var fact in facts)
            {
                MemoryList.Items.Add(new ListBoxItem { Content = fact, Tag = fact });
            }

            MemoryStatus.Text = facts.Count == 0
                ? "Nothing remembered yet."
                : $"{facts.Count} fact(s) remembered.";
        }
        catch (Exception error)
        {
            MemoryStatus.Text = error.Message;
        }
    }

    private async Task RefreshSkillsAsync()
    {
        if (engine == null)
        {
            SkillStatus.Text = "Start the sidecar from the main window to load skills.";
            return;
        }

        try
        {
            var skills = await engine.ListSkillsAsync();
            SkillList.Items.Clear();
            foreach (var skill in skills)
            {
                SkillList.Items.Add(new ListBoxItem
                {
                    Content = $"\"{skill.Trigger}\" → {skill.Action}",
                    Tag = skill.Trigger,
                });
            }

            SkillStatus.Text = skills.Count == 0
                ? "No skills taught yet."
                : $"{skills.Count} skill(s) taught.";
        }
        catch (Exception error)
        {
            SkillStatus.Text = error.Message;
        }
    }

    private async Task RefreshUsageAsync()
    {
        if (engine == null)
        {
            UsageStatus.Text = "Start the sidecar from the main window to load usage.";
            return;
        }

        try
        {
            var usage = await engine.UsageAsync();
            UsageTotal.Text = $"Total actions: {usage.Total}";
            UsageExecuted.Text = $"Executed: {usage.Executed}";
            UsageFailed.Text = $"Failed or denied: {usage.Failed}";
            UsagePayments.Text = $"Payment actions: {usage.Payments}";
            UsageWeek.Text = $"Last 7 days: {usage.LastSevenDays}";
            UsageTop.Text = usage.TopActions.Count == 0
                ? "No actions recorded."
                : string.Join("\n", usage.TopActions.Select(action => $"{action.Kind}: {action.Count}"));
            UsageStatus.Text = "";
        }
        catch (Exception error)
        {
            UsageStatus.Text = error.Message;
        }
    }

    private async Task RefreshCapabilitiesAsync()
    {
        if (engine == null)
        {
            CapabilityStatus.Text = "Start the sidecar from the main window to probe capabilities.";
            return;
        }

        try
        {
            var summary = await engine.CapabilitiesAsync();
            CapabilityText.Text = string.Join("\n", new[]
            {
                $"Platform: {summary.Platform}",
                $"Profile: {summary.Profile}",
                $"Model: {summary.ModelProvider} / {summary.ModelName} ({(summary.ModelReady ? "ready" : "no key")})",
                $"Bridge: {(summary.Bridge ? "on" : "off")}",
                $"Gateway: {(summary.GatewayPaired ? "paired" : "not paired")}; phone {(summary.PhoneOnline ? "online" : "offline")}",
                $"Memory: {summary.Memory} fact(s)",
                $"Skills: {summary.Skills}",
                $"Recipes: {summary.Recipes}",
                $"Runs: {summary.Runs}",
                $"Windows apps in the catalogue: {summary.WindowsApps}",
            });
            CapabilityStatus.Text = "";
        }
        catch (Exception error)
        {
            CapabilityStatus.Text = error.Message;
        }
    }

    private async Task RefreshRecipesAsync()
    {
        if (engine == null)
        {
            RecipeStatus.Text = "Start the sidecar from the main window to load recipes.";
            return;
        }

        try
        {
            var recipes = await engine.ListRecipesAsync();
            RecipeList.Items.Clear();
            foreach (var recipe in recipes)
            {
                RecipeList.Items.Add(new ListBoxItem
                {
                    Content = $"{recipe.Goal} · {recipe.App} · {recipe.Steps} steps" +
                              (recipe.Replayable ? "" : " · not replayable"),
                    Tag = recipe.Goal,
                });
            }

            RecipeStatus.Text = recipes.Count == 0
                ? "No recipes saved yet."
                : $"{recipes.Count} recipe(s) saved.";
        }
        catch (Exception error)
        {
            RecipeStatus.Text = error.Message;
        }
    }

    private async Task RefreshHistoryAsync()
    {
        if (engine == null)
        {
            HistoryStatus.Text = "Start the sidecar from the main window to load history.";
            return;
        }

        try
        {
            var history = await engine.ListHistoryAsync();
            HistoryList.Items.Clear();
            foreach (var entry in history)
            {
                var at = DateTimeOffset.FromUnixTimeMilliseconds(entry.CreatedAt).LocalDateTime;
                HistoryList.Items.Add(new ListBoxItem
                {
                    Content = $"{entry.Title} · {entry.Steps} steps · " +
                              $"{entry.Executed} executed / {entry.Failed} failed · {at:g}",
                });
            }

            HistoryStatus.Text = history.Count == 0
                ? "No finished turns yet."
                : $"{history.Count} turn(s).";
        }
        catch (Exception error)
        {
            HistoryStatus.Text = error.Message;
        }
    }

    private async void MemoryAdd_Click(object sender, RoutedEventArgs e)
    {
        if (engine == null)
        {
            return;
        }

        var text = MemoryTextBox.Text.Trim();
        if (text.Length == 0)
        {
            MemoryStatus.Text = "Type a fact first.";
            return;
        }

        try
        {
            await engine.AddMemoryAsync(text);
            MemoryTextBox.Clear();
            await RefreshMemoryAsync();
        }
        catch (Exception error)
        {
            MemoryStatus.Text = error.Message;
        }
    }

    private async void MemoryDelete_Click(object sender, RoutedEventArgs e)
    {
        if (engine == null || MemoryList.SelectedItem is not ListBoxItem item)
        {
            return;
        }

        try
        {
            await engine.DeleteMemoryAsync(item.Tag?.ToString() ?? "");
            await RefreshMemoryAsync();
        }
        catch (Exception error)
        {
            MemoryStatus.Text = error.Message;
        }
    }

    private async void SkillAdd_Click(object sender, RoutedEventArgs e)
    {
        if (engine == null)
        {
            return;
        }

        var trigger = SkillTriggerBox.Text.Trim();
        var action = SkillActionBox.Text.Trim();
        if (trigger.Length == 0 || action.Length == 0)
        {
            SkillStatus.Text = "Both a trigger and an action are required.";
            return;
        }

        try
        {
            await engine.AddSkillAsync(trigger, action);
            SkillTriggerBox.Clear();
            SkillActionBox.Clear();
            await RefreshSkillsAsync();
        }
        catch (Exception error)
        {
            SkillStatus.Text = error.Message;
        }
    }

    private async void SkillDelete_Click(object sender, RoutedEventArgs e)
    {
        if (engine == null || SkillList.SelectedItem is not ListBoxItem item)
        {
            return;
        }

        try
        {
            await engine.DeleteSkillAsync(item.Tag?.ToString() ?? "");
            await RefreshSkillsAsync();
        }
        catch (Exception error)
        {
            SkillStatus.Text = error.Message;
        }
    }

    private async void RecipeDelete_Click(object sender, RoutedEventArgs e)
    {
        if (engine == null || RecipeList.SelectedItem is not ListBoxItem item)
        {
            return;
        }

        try
        {
            await engine.DeleteRecipeAsync(item.Tag?.ToString() ?? "");
            await RefreshRecipesAsync();
        }
        catch (Exception error)
        {
            RecipeStatus.Text = error.Message;
        }
    }

    private async void RecipeClear_Click(object sender, RoutedEventArgs e)
    {
        if (engine == null)
        {
            return;
        }

        try
        {
            await engine.ClearRecipesAsync();
            await RefreshRecipesAsync();
        }
        catch (Exception error)
        {
            RecipeStatus.Text = error.Message;
        }
    }

    private async void HistoryRefresh_Click(object sender, RoutedEventArgs e)
    {
        await RefreshHistoryAsync();
    }

    private async Task RefreshPrivacyAsync()
    {
        if (engine == null)
        {
            PrivacyStatus.Text = "Start the sidecar from the main window to load the record summary.";
            return;
        }

        try
        {
            var history = await engine.ListHistoryAsync();
            PrivacyList.Items.Clear();
            foreach (var entry in history)
            {
                var at = DateTimeOffset.FromUnixTimeMilliseconds(entry.CreatedAt).LocalDateTime;
                PrivacyList.Items.Add(new ListBoxItem
                {
                    Content = $"{at:g} · {entry.Title} · {entry.Steps} step(s) · " +
                              $"{entry.Executed} executed / {entry.Failed} failed",
                });
            }

            PrivacyStatus.Text = history.Count == 0
                ? "No finished turns yet."
                : $"{history.Count} turn(s) in the record chain.";
        }
        catch (Exception error)
        {
            PrivacyStatus.Text = error.Message;
        }
    }

    private void RefreshNotifications()
    {
        NotificationList.Items.Clear();
        foreach (var entry in NotificationHistory.Recent())
        {
            NotificationList.Items.Add(new ListBoxItem
            {
                Content = $"{entry.At:g} · {entry.Title}: {entry.Text}",
            });
        }

        NotificationStatus.Text = NotificationHistory.Recent().Count == 0
            ? "No toasts yet."
            : $"{NotificationHistory.Recent().Count} toast(s).";
    }

    private async void PrivacyRefresh_Click(object sender, RoutedEventArgs e)
    {
        await RefreshPrivacyAsync();
    }

    private void NotificationRefresh_Click(object sender, RoutedEventArgs e) => RefreshNotifications();

    private void NotificationClear_Click(object sender, RoutedEventArgs e)
    {
        NotificationHistory.Clear();
        RefreshNotifications();
    }

    private async void LaunchpadRefresh_Click(object sender, RoutedEventArgs e)
    {
        if (device == null)
        {
            LaunchpadStatus.Text = "The device adapter is not attached in this window.";
            return;
        }

        LaunchpadStatus.Text = "Reading the Start menu...";
        LaunchpadRefreshButton.IsEnabled = false;
        try
        {
            var apps = await Task.Run(() => device.Apps());
            LaunchpadList.Items.Clear();
            foreach (var app in apps)
            {
                LaunchpadList.Items.Add(new ListBoxItem
                {
                    Content = $"{app.Label} · {app.Package}",
                    Tag = app,
                });
            }

            LaunchpadStatus.Text = $"{apps.Count} app(s) from the Start menu.";
        }
        catch (Exception error)
        {
            LaunchpadStatus.Text = error.Message;
        }
        finally
        {
            LaunchpadRefreshButton.IsEnabled = true;
        }
    }

    private void LaunchpadLaunch_Click(object sender, RoutedEventArgs e)
    {
        if (device == null || LaunchpadList.SelectedItem is not ListBoxItem { Tag: DeviceApp app })
        {
            return;
        }

        try
        {
            LaunchpadStatus.Text = device.Act("launch", new JsonObject { ["app"] = app.Package });
        }
        catch (Exception error)
        {
            LaunchpadStatus.Text = error.Message;
        }
    }

    private void LaunchpadStop_Click(object sender, RoutedEventArgs e)
    {
        if (device == null || LaunchpadList.SelectedItem is not ListBoxItem { Tag: DeviceApp app })
        {
            return;
        }

        try
        {
            LaunchpadStatus.Text = device.Act("stop", new JsonObject { ["app"] = app.Package });
        }
        catch (Exception error)
        {
            LaunchpadStatus.Text = error.Message;
        }
    }

    private async void SelfCheck_Click(object sender, RoutedEventArgs e)
    {
        SelfCheckButton.IsEnabled = false;
        var lines = new List<string>();
        try
        {
            lines.Add($"Sidecar: {(engine == null ? "not connected" : "connected")}");
            if (engine != null)
            {
                try
                {
                    var capabilities = await engine.CapabilitiesAsync();
                    lines.Add($"Model: {capabilities.ModelProvider} / {capabilities.ModelName} " +
                              $"({(capabilities.ModelReady ? "key present" : "no key")})");
                    lines.Add($"Bridge: {(capabilities.Bridge ? "on" : "off")}");
                    lines.Add($"Gateway: {(capabilities.GatewayPaired ? "paired" : "not paired")}; " +
                              $"phone {(capabilities.PhoneOnline ? "online" : "offline")}");
                    lines.Add($"Runtime: {capabilities.Runs} run(s), {capabilities.WindowsApps} Windows app(s)");
                }
                catch (Exception error)
                {
                    lines.Add($"Sidecar probe failed: {error.Message}");
                }
            }

            if (device == null)
            {
                lines.Add("UI Automation: not attached in this window");
            }
            else
            {
                lines.Add($"UI Automation: {device.UnreadableReason() ?? "ready"}");
                lines.Add($"Foreground: {device.ForegroundApp()}");
            }

            lines.Add($"Bridge token: {Present("hopa.bridge.token")}");
            lines.Add($"Model key: {Present("hopa.model.key")}");
        }
        finally
        {
            SelfCheckText.Text = string.Join("\n", lines);
            SelfCheckButton.IsEnabled = true;
        }
    }

    private static string Present(string name) =>
        CredentialStore.Read(name).Length > 0 ? "present" : "missing";

    private void SettingsNav_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (GeneralPage == null)
        {
            return;
        }

        var tag = (SettingsNav.SelectedItem as ListBoxItem)?.Tag?.ToString() ?? "general";
        GeneralPage.Visibility = tag == "general" ? Visibility.Visible : Visibility.Collapsed;
        ProfilesPage.Visibility = tag == "profiles" ? Visibility.Visible : Visibility.Collapsed;
        MemoryPage.Visibility = tag == "memory" ? Visibility.Visible : Visibility.Collapsed;
        SkillsPage.Visibility = tag == "skills" ? Visibility.Visible : Visibility.Collapsed;
        UsagePage.Visibility = tag == "usage" ? Visibility.Visible : Visibility.Collapsed;
        CapabilitiesPage.Visibility = tag == "capabilities" ? Visibility.Visible : Visibility.Collapsed;
        RecipesPage.Visibility = tag == "recipes" ? Visibility.Visible : Visibility.Collapsed;
        HistoryPage.Visibility = tag == "history" ? Visibility.Visible : Visibility.Collapsed;
        PrivacyPage.Visibility = tag == "privacy" ? Visibility.Visible : Visibility.Collapsed;
        NotificationsPage.Visibility = tag == "notifications" ? Visibility.Visible : Visibility.Collapsed;
        LaunchpadPage.Visibility = tag == "launchpad" ? Visibility.Visible : Visibility.Collapsed;
        SelfCheckPage.Visibility = tag == "selfcheck" ? Visibility.Visible : Visibility.Collapsed;
        AboutPage.Visibility = tag == "about" ? Visibility.Visible : Visibility.Collapsed;
    }

    private void SettingsSearch_TextChanged(object sender, TextChangedEventArgs e)
    {
        if (SettingsNav == null)
        {
            return;
        }

        var query = SettingsSearch.Text.Trim();
        foreach (var item in SettingsNav.Items.OfType<ListBoxItem>())
        {
            item.Visibility = query.Length == 0 ||
                              (item.Content?.ToString()?.Contains(query, StringComparison.OrdinalIgnoreCase) ?? false)
                ? Visibility.Visible
                : Visibility.Collapsed;
        }

        if (SettingsNav.SelectedItem is ListBoxItem selected && selected.Visibility != Visibility.Visible)
        {
            var first = SettingsNav.Items.OfType<ListBoxItem>().FirstOrDefault(i => i.Visibility == Visibility.Visible);
            if (first != null)
            {
                SettingsNav.SelectedItem = first;
            }
        }
    }

    private async void PairGateway_Click(object sender, RoutedEventArgs e)
    {
        var link = GatewayLinkBox.Text.Trim();
        if (link.Length == 0)
        {
            GatewayStatusText.Text = "Paste the hopa://pair link first.";
            return;
        }

        PairGatewayButton.IsEnabled = false;
        GatewayStatusText.Text = "Pairing...";
        try
        {
            var credentials = await GatewayPairing.PairAsync(link, Environment.MachineName);
            GatewayLinkBox.Clear();
            GatewayStatusText.Text = $"Paired as {credentials.DeviceId}.";
        }
        catch (Exception error)
        {
            GatewayStatusText.Text = error.Message;
        }
        finally
        {
            PairGatewayButton.IsEnabled = true;
        }
    }

    private void Header_Drag(object sender, MouseButtonEventArgs e)
    {
        if (e.ButtonState == MouseButtonState.Pressed)
        {
            DragMove();
        }
    }

    private void Close_Click(object sender, RoutedEventArgs e) => Close();

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        var settings = store.Load();
        settings.BridgeUrl = BridgeUrlBox.Text.Trim();
        settings.UseBridge = UseBridgeBox.IsChecked == true;
        settings.ModelProvider = Value(ProviderBox, "openai");
        settings.ModelBaseUrl = BaseUrlBox.Text.Trim();
        settings.ModelName = ModelNameBox.Text.Trim();
        settings.Tone = Value(ToneBox, "warm");
        settings.Profile = SelectedProfile(settings.Profile);
        store.Save(settings);
        SaveSecret("hopa.bridge.token", BridgeTokenBox.Password);
        SaveSecret("hopa.model.key", ModelKeyBox.Password);
        DialogResult = true;
    }

    private string SelectedProfile(string fallback) =>
        (ProfileList.SelectedItem as ListBoxItem)?.Tag?.ToString() ?? fallback;

    private static void Select(ComboBox box, string value)
    {
        foreach (var item in box.Items)
        {
            if (item is ComboBoxItem candidate &&
                string.Equals(candidate.Content?.ToString(), value, StringComparison.OrdinalIgnoreCase))
            {
                box.SelectedItem = candidate;
                return;
            }
        }

        if (box.Items.Count > 0)
        {
            box.SelectedIndex = 0;
        }
    }

    private static string Value(ComboBox box, string fallback) =>
        (box.SelectedItem as ComboBoxItem)?.Content?.ToString() ?? fallback;

    private static void SaveSecret(string name, string value)
    {
        if (string.IsNullOrEmpty(value))
        {
            CredentialStore.Delete(name);
        }
        else
        {
            CredentialStore.Write(name, value);
        }
    }
}
