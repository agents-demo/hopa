using System.Collections.ObjectModel;
using System.IO;
using System.Text.Json.Nodes;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace Hopa.Windows;

public partial class MainWindow : Window
{
    private readonly ObservableCollection<ConversationVm> conversations = new();
    private readonly ObservableCollection<MessageVm> messages = new();
    private readonly Dictionary<string, string> drafts = new();
    private readonly List<string> log = new();
    private SidecarClient? client;
    private Task? connecting;
    private string? currentId;
    private string? outputPath;
    private bool switching;
    private bool running;

    public MainWindow()
    {
        InitializeComponent();
        ConversationList.ItemsSource = conversations;
        MessagesList.ItemsSource = messages;
        Loaded += async (_, _) => await ConnectAsync();
    }

    public async Task RunTurnAsync(string goal, string? outPath, string? shotPath)
    {
        outputPath = outPath;
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

    public void SaveShot(string path)
    {
        UpdateLayout();
        var width = (int)Math.Max(ActualWidth, 1);
        var height = (int)Math.Max(ActualHeight, 1);
        var bitmap = new RenderTargetBitmap(width, height, 96, 96, PixelFormats.Pbgra32);
        bitmap.Render(this);
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var stream = File.Create(path);
        encoder.Save(stream);
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
            client = started;
            StatusText.Text = "Ready";
            await RefreshAsync();
        }
        catch (Exception error)
        {
            StatusText.Text = error.Message;
            Log($"error: {error.Message}");
        }
    }

    private async Task RefreshAsync()
    {
        if (client == null)
        {
            return;
        }

        var items = await client.ListConversationsAsync();
        conversations.Clear();
        foreach (var item in items)
        {
            conversations.Add(ToVm(item));
        }

        if (conversations.Count == 0)
        {
            var created = await client.CreateConversationAsync();
            if (created != null)
            {
                conversations.Add(ToVm(created));
            }
        }

        if (conversations.Count > 0)
        {
            await SelectAsync(conversations[0].Id);
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
        ConversationList.SelectedItem = conversations.FirstOrDefault(item => item.Id == id);
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

        running = true;
        SendButton.IsEnabled = false;
        StatusText.Text = "Working...";
        messages.Add(new MessageVm { Role = "user", Text = goal });
        EmptyState.Visibility = Visibility.Collapsed;
        ScrollToEnd();
        try
        {
            var (answer, conversationId, title) = await client.StartTurnAsync(goal, currentId);
            currentId = conversationId;
            messages.Add(new MessageVm { Role = "assistant", Text = answer });
            Log($"HOPA: {answer}");
            TitleText.Text = title;
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
        }
    }

    private async Task SendFromComposerAsync()
    {
        var goal = Composer.Text.Trim();
        if (goal.Length == 0)
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

    private void UpsertConversation(string id, string title)
    {
        var existing = conversations.FirstOrDefault(item => item.Id == id);
        if (existing != null)
        {
            existing.Title = title;
            existing.UpdatedLabel = "now";
            return;
        }

        conversations.Insert(0, new ConversationVm { Id = id, Title = title, UpdatedLabel = "now" });
    }

    private async void NewChat_Click(object sender, RoutedEventArgs e)
    {
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
        conversations.Insert(0, vm);
        currentId = null;
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
            if (op == "tap")
            {
                var result = NotepadClicker.ClickTextArea();
                Log($"device: {result}");
                client.SendDeviceResult(id, true);
                return;
            }

            var reason = $"the W1 host cannot do '{op}' yet";
            Log($"device: {reason}");
            client.SendDeviceResult(id, false, reason);
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
        return new ConversationVm
        {
            Id = item["id"]?.GetValue<string>() ?? "",
            Title = item["title"]?.GetValue<string>() ?? "New chat",
            UpdatedLabel = FormatTime(updatedAt),
            MessageCount = (item["messages"] as JsonArray)?.Count ?? 0,
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
