using System.Text.Json.Nodes;

namespace Hopa.Windows.Engine;

/// <summary>The engine operations the chat controller uses; the process client implements it.</summary>
public interface IChatEngine
{
    Task<TurnResult> StartTurnAsync(string goal, string? conversationId, JsonObject? attachment = null);

    Task<JsonObject?> OpenConversationAsync(string id);

    Task<JsonObject?> CreateConversationAsync();

    Task<List<JsonObject>> ListConversationsAsync(bool includeArchived = false);
}
