namespace Hopa.Windows.Ui.Shell;

/// <summary>One toast the PC showed.</summary>
public sealed record NotificationEntry(string Title, string Text, DateTimeOffset At);

/// <summary>The in-memory history behind the notification center.</summary>
public static class NotificationHistory
{
    private const int Limit = 50;
    private static readonly object Gate = new();
    private static readonly List<NotificationEntry> Entries = new();

    public static void Record(string title, string text)
    {
        lock (Gate)
        {
            Entries.Insert(0, new NotificationEntry(title, text, DateTimeOffset.Now));
            if (Entries.Count > Limit)
            {
                Entries.RemoveRange(Limit, Entries.Count - Limit);
            }
        }
    }

    public static IReadOnlyList<NotificationEntry> Recent()
    {
        lock (Gate)
        {
            return Entries.ToList();
        }
    }

    public static void Clear()
    {
        lock (Gate)
        {
            Entries.Clear();
        }
    }
}
