using System.Collections.ObjectModel;
using Hopa.Windows.Ui.Chat;

namespace Hopa.Windows.Ui.Panes;

/// <summary>The sidebar state: the rows, the search, the archive switch and the selection.</summary>
public sealed class ConversationsViewModel : ObservableObject
{
    private string search = "";
    private bool includeArchived;
    private ConversationRow? selected;
    private bool bridgeMissing;

    /// <summary>Every conversation the engine has told us about, archived included.</summary>
    public List<ConversationRow> All { get; } = new();

    /// <summary>The rows the list shows, after the search and the archive switch.</summary>
    public ObservableCollection<ConversationRow> Visible { get; } = new();

    public string Search
    {
        get => search;
        set
        {
            if (Set(ref search, value))
            {
                ApplyFilter();
            }
        }
    }

    public bool IncludeArchived
    {
        get => includeArchived;
        set
        {
            if (Set(ref includeArchived, value))
            {
                ApplyFilter();
            }
        }
    }

    public ConversationRow? Selected
    {
        get => selected;
        set => Set(ref selected, value);
    }

    /// <summary>True when no bridge URL is configured; the "Set up" hint follows it.</summary>
    public bool BridgeMissing
    {
        get => bridgeMissing;
        set => Set(ref bridgeMissing, value);
    }

    public void ReplaceAll(IEnumerable<ConversationRow> rows)
    {
        All.Clear();
        All.AddRange(rows);
        ApplyFilter();
    }

    /// <summary>Adds a conversation the turn just created, or refreshes its title.</summary>
    public void Upsert(string id, string title)
    {
        var existing = All.FirstOrDefault(item => item.Id == id);
        if (existing != null)
        {
            existing.Title = title;
            existing.UpdatedLabel = "now";
            existing.UpdatedAt = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            return;
        }

        var created = new ConversationRow
        {
            Id = id,
            Title = title,
            UpdatedLabel = "now",
            UpdatedAt = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
        };
        All.Insert(0, created);
        if (Search.Trim().Length == 0)
        {
            Visible.Insert(0, created);
        }
    }

    /// <summary>Marks the row the chat is showing; the list selection stays separate.</summary>
    public void MarkSelected(string? id)
    {
        foreach (var item in All)
        {
            item.Selected = item.Id == id;
        }
    }

    public void Remove(ConversationRow row)
    {
        All.Remove(row);
        Visible.Remove(row);
        ApplyFilter();
    }

    public void ApplyFilter()
    {
        var rows = ConversationFilter.Apply(All, Search, IncludeArchived);
        Visible.Clear();
        foreach (var row in rows)
        {
            Visible.Add(row);
        }
    }
}
