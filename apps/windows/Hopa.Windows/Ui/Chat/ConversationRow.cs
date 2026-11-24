using System.ComponentModel;
using System.Text.Json.Nodes;

namespace Hopa.Windows.Ui.Chat;

/// <summary>One row in the sidebar.</summary>
public sealed class ConversationRow : INotifyPropertyChanged
{
    private string title = "";
    private string updatedLabel = "";
    private bool pinned;
    private bool archived;

    public event PropertyChangedEventHandler? PropertyChanged;

    public string Id { get; init; } = "";

    public string SearchText { get; init; } = "";

    public int MessageCount { get; set; }

    private long updatedAt;

    public long UpdatedAt
    {
        get => updatedAt;
        set
        {
            if (updatedAt == value)
            {
                return;
            }

            updatedAt = value;
            Raise(nameof(GroupLabel));
        }
    }

    /// <summary>Today / Previous 7 days / Older, like the laptop sidebar.</summary>
    public string GroupLabel
    {
        get
        {
            if (updatedAt <= 0)
            {
                return "Older";
            }

            var when = DateTimeOffset.FromUnixTimeMilliseconds(updatedAt).LocalDateTime;
            if (when.Date == DateTime.Today)
            {
                return "Today";
            }

            return when >= DateTime.Today.AddDays(-7) ? "Previous 7 days" : "Older";
        }
    }

    public string Title
    {
        get => title;
        set
        {
            if (title == value)
            {
                return;
            }

            title = value;
            Raise(nameof(Title));
        }
    }

    public string UpdatedLabel
    {
        get => updatedLabel;
        set
        {
            if (updatedLabel == value)
            {
                return;
            }

            updatedLabel = value;
            Raise(nameof(UpdatedLabel));
        }
    }

    public bool Pinned
    {
        get => pinned;
        set
        {
            if (pinned == value)
            {
                return;
            }

            pinned = value;
            Raise(nameof(Pinned));
            Raise(nameof(PinLabel));
        }
    }

    public bool Archived
    {
        get => archived;
        set
        {
            if (archived == value)
            {
                return;
            }

            archived = value;
            Raise(nameof(Archived));
            Raise(nameof(ArchivedLabel));
        }
    }

    public System.Windows.Media.Brush TitleInk => Selected
        ? new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(0x1C, 0x1B, 0x18))
        : new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(0x6B, 0x66, 0x5C));

    private bool selected;

    public bool Selected
    {
        get => selected;
        set
        {
            if (selected == value)
            {
                return;
            }

            selected = value;
            Raise(nameof(Selected));
            Raise(nameof(TitleInk));
        }
    }

    public string PinLabel => pinned ? "PIN" : "";

    public string ArchivedLabel => archived ? "archived" : "";

    /// <summary>Builds a row from the engine's conversation JSON.</summary>
    public static ConversationRow From(JsonObject item)
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

        return new ConversationRow
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

    private void Raise(string name) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}
