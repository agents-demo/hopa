namespace Hopa.Windows.Integrations.Browser;

/// <summary>The browser operations the engine can ask for.</summary>
public interface IBrowserController
{
    Task<string> NavigateAsync(string url);

    Task<string> ReadAsync();

    Task<string> ClickAsync(string reference);

    Task<string> TypeAsync(string text, string? reference);
}
