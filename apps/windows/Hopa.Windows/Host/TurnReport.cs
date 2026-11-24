using System.Text.Json.Nodes;

namespace Hopa.Windows.Host;

/// <summary>What one turn did, in the terms the window needs to draw it.</summary>
public sealed record TurnReport(
    string Answer,
    string Title,
    JsonArray? Steps,
    bool ChainOk,
    TimeSpan Elapsed,
    string Earlier,
    string? Error);
