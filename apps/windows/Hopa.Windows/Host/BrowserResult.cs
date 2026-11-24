namespace Hopa.Windows.Host;

/// <summary>One answer to a browser request, in the shape the engine expects.</summary>
public sealed record BrowserResult(
    string Id,
    bool Ok,
    string? Error = null,
    string? Text = null);
