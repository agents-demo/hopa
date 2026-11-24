namespace Hopa.Windows.Integrations.Engine;

/// <summary>One saved repetition, flattened for the recipes screen.</summary>
public sealed record RecipeSummary(
    string Goal,
    string App,
    int Steps,
    long At,
    bool Replayable,
    string ScreenHash,
    string EndHash);
