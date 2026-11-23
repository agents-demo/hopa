using System.Diagnostics;
using System.Text.Json.Nodes;
using Hopa.Windows.Chat;
using Hopa.Windows.Engine;
using Hopa.Windows.Panes;

namespace Hopa.Windows.Shell;

/// <summary>
/// The turn lifecycle: one send, one select, one create. It owns the current
/// conversation and the running flag; the window owns the client and the view.
/// </summary>
public sealed class ChatController
{
    private readonly IChatEngine engine;
    private readonly ChatViewModel chat;
    private readonly ConversationsViewModel conversations;
    private bool running;

    public ChatController(IChatEngine engine, ChatViewModel chat, ConversationsViewModel conversations)
    {
        this.engine = engine;
        this.chat = chat;
        this.conversations = conversations;
    }

    public string? CurrentId { get; private set; }

    public bool Running => running;

    /// <summary>Raised when a user bubble or an answer enters the conversation.</summary>
    public event Action? MessagesChanged;

    /// <summary>The current conversation is gone (archived or deleted).</summary>
    public void Forget() => CurrentId = null;

    public async Task<TurnReport> SendAsync(string body, JsonObject? attachment)
    {
        var earlier = chat.LastQuestion;
        var clock = Stopwatch.StartNew();
        running = true;
        chat.SetRunning(true);
        chat.ClearError();
        chat.AddUser(body);
        MessagesChanged?.Invoke();
        try
        {
            var result = await engine.StartTurnAsync(body, CurrentId, attachment);
            CurrentId = result.ConversationId;
            chat.AddAnswer(result.Answer, result.Steps, result.ChainOk);
            MessagesChanged?.Invoke();
            chat.LastQuestion = body;
            conversations.MarkSelected(result.ConversationId);
            conversations.Upsert(result.ConversationId, result.Title);
            return new TurnReport(
                result.Answer,
                result.Title,
                result.Steps,
                result.ChainOk,
                clock.Elapsed,
                earlier,
                null);
        }
        catch (Exception error)
        {
            chat.ShowError(error.Message);
            return new TurnReport("", "", null, false, clock.Elapsed, earlier, error.Message);
        }
        finally
        {
            running = false;
            chat.SetRunning(false);
        }
    }

    /// <summary>Opens a conversation, keeping the composer draft of the previous one.</summary>
    public async Task<string?> SelectAsync(string id)
    {
        if (CurrentId == id)
        {
            return null;
        }

        if (CurrentId != null)
        {
            chat.Drafts[CurrentId] = chat.ComposerText;
        }

        var open = await engine.OpenConversationAsync(id);
        CurrentId = id;
        chat.ShowConversation(
            open?["messages"] as JsonArray,
            chat.Drafts.TryGetValue(id, out var draft) ? draft : "");
        return open?["title"]?.GetValue<string>() ?? "New chat";
    }

    public async Task<ConversationRow?> CreateAsync()
    {
        var created = await engine.CreateConversationAsync();
        if (created == null)
        {
            return null;
        }

        var row = ConversationRow.From(created);
        conversations.All.Insert(0, row);
        conversations.ApplyFilter();
        return row;
    }

    /// <summary>
    /// Loads the list, optionally creating the first conversation, and returns
    /// the row the window should open. Both the first load and the archive
    /// switch go through here.
    /// </summary>
    public async Task<string?> LoadAsync(bool includeArchived, bool createIfEmpty)
    {
        var items = await engine.ListConversationsAsync(includeArchived);
        var rows = items.Select(ConversationRow.From).ToList();
        if (rows.Count == 0 && createIfEmpty)
        {
            var created = await engine.CreateConversationAsync();
            if (created != null)
            {
                rows.Add(ConversationRow.From(created));
            }
        }

        conversations.ReplaceAll(rows);
        return conversations.Visible.FirstOrDefault()?.Id
            ?? conversations.All.FirstOrDefault()?.Id;
    }
}
