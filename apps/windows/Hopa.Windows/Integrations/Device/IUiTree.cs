namespace Hopa.Windows.Integrations.Device;

/// <summary>The two elements observation and app search start from.</summary>
public interface IUiTree : IDisposable
{
    /// <summary>The window that currently owns input, or null when there is none.</summary>
    IUiNode? Foreground();

    /// <summary>The desktop root, whose children are the top-level windows.</summary>
    IUiNode Desktop();
}
