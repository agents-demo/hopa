namespace Hopa.Windows.Ui.Chat;

/// <summary>Which conversation rows the sidebar shows, and in what order.</summary>
public static class ConversationFilter
{
    public static List<ConversationRow> Apply(
        IEnumerable<ConversationRow> rows,
        string query,
        bool showArchived)
    {
        var text = query.Trim();
        return rows
            .Where(row => showArchived || !row.Archived)
            .Where(row => text.Length == 0 ||
                          row.SearchText.Contains(text, StringComparison.OrdinalIgnoreCase))
            .OrderByDescending(row => row.Pinned)
            .ThenByDescending(row => row.UpdatedAt)
            .ToList();
    }
}
