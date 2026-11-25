using System.Text.Json.Nodes;
using Hopa.Windows.Integrations.Engine;

namespace Hopa.Windows.Host;

/// <summary>What one turn did, in the terms the window needs to draw it.</summary>
public sealed record TurnReport(
    string Answer,
    string Title,
    JsonArray? Steps,
    bool ChainOk,
    TimeSpan Elapsed,
    string Earlier,
    string? Error,
    IReadOnlyList<string>? Plan = null,
    CheckpointVerification? Checkpoints = null)
{
    /// <summary>`uia-tree` when a model read the accessibility tree.</summary>
    public string ModelInput { get; init; } = "";
}
