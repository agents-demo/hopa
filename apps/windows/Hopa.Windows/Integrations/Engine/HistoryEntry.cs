namespace Hopa.Windows.Integrations.Engine;

/// <summary>One finished turn in the history surface.</summary>
public sealed record HistoryEntry(
    string ConversationId,
    string Title,
    string RunId,
    long CreatedAt,
    int Steps,
    int Executed,
    int Failed);
