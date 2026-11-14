namespace Hopa.Windows;

/// <summary>One row in the sidebar.</summary>
public sealed class ConversationVm
{
    public string Id { get; init; } = "";

    public string Title { get; set; } = "";

    public string UpdatedLabel { get; set; } = "";

    public int MessageCount { get; set; }
}
