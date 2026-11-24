using System.Text.Json.Nodes;

namespace Hopa.Windows.Integrations.Engine;

/// <summary>What one engine turn produced, as the window shows it.</summary>
public sealed record TurnResult(
    string Answer,
    string ConversationId,
    string Title,
    JsonArray? Steps,
    bool ChainOk);
