using System.Collections.ObjectModel;
using System.Text.Json.Nodes;
using System.Windows.Media;
using Hopa.Windows.Chat;

namespace Hopa.Windows.Panes;

/// <summary>
/// The conversation pane: the bubbles, the composer, the attachment and the
/// last answer's actions. It does not own the engine client; the window calls
/// the model when a turn starts or ends.
/// </summary>
public sealed class ChatViewModel : ObservableObject
{
    private static readonly Brush Blue = new SolidColorBrush(Color.FromRgb(0x0A, 0x59, 0xF7));
    private static readonly Brush Quiet = new SolidColorBrush(Color.FromRgb(0x6B, 0x66, 0x5C));

    private string composerText = "";
    private string error = "";
    private string attachmentName = "";
    private string attachmentDetail = "";
    private bool running;
    private bool emptyVisible = true;
    private bool answerActionsVisible;
    private bool copyEnabled;
    private bool speakEnabled;
    private bool detailsEnabled;
    private bool attachmentVisible;
    private bool targetVisible;
    private string targetText = "Laptop";
    private Brush targetInk = Quiet;
    private string sendGlyph = "\u2191";
    private string micText = "\uE720";
    private string lastAnswer = "";
    private JsonArray? lastSteps;
    private bool lastChainOk;
    private string lastQuestion = "";

    public ObservableCollection<MessageBubble> Messages { get; } = new();

    /// <summary>Composer text per conversation, so switching rows keeps the draft.</summary>
    public Dictionary<string, string> Drafts { get; } = new();

    public string ComposerText
    {
        get => composerText;
        set
        {
            if (Set(ref composerText, value))
            {
                Raise(nameof(ComposerEmpty));
            }
        }
    }

    public bool ComposerEmpty => composerText.Length == 0;

    public string Error
    {
        get => error;
        private set
        {
            if (Set(ref error, value))
            {
                Raise(nameof(ErrorVisible));
            }
        }
    }

    public bool ErrorVisible => error.Length > 0;

    public string AttachmentName
    {
        get => attachmentName;
        private set => Set(ref attachmentName, value);
    }

    public string AttachmentDetail
    {
        get => attachmentDetail;
        private set => Set(ref attachmentDetail, value);
    }

    public bool AttachmentVisible
    {
        get => attachmentVisible;
        private set => Set(ref attachmentVisible, value);
    }

    public bool Running
    {
        get => running;
        private set => Set(ref running, value);
    }

    public string SendGlyph
    {
        get => sendGlyph;
        private set => Set(ref sendGlyph, value);
    }

    public string MicText
    {
        get => micText;
        private set => Set(ref micText, value);
    }

    public bool EmptyVisible
    {
        get => emptyVisible;
        private set => Set(ref emptyVisible, value);
    }

    public bool AnswerActionsVisible
    {
        get => answerActionsVisible;
        private set => Set(ref answerActionsVisible, value);
    }

    public bool CopyEnabled
    {
        get => copyEnabled;
        private set => Set(ref copyEnabled, value);
    }

    public bool SpeakEnabled
    {
        get => speakEnabled;
        private set => Set(ref speakEnabled, value);
    }

    public bool DetailsEnabled
    {
        get => detailsEnabled;
        private set => Set(ref detailsEnabled, value);
    }

    public bool TargetVisible
    {
        get => targetVisible;
        private set => Set(ref targetVisible, value);
    }

    public string TargetText
    {
        get => targetText;
        private set => Set(ref targetText, value);
    }

    public Brush TargetInk
    {
        get => targetInk;
        private set => Set(ref targetInk, value);
    }

    public string LastAnswer => lastAnswer;

    public JsonArray? LastSteps => lastSteps;

    public bool LastChainOk => lastChainOk;

    public string LastQuestion
    {
        get => lastQuestion;
        set => Set(ref lastQuestion, value);
    }

    public void ShowConversation(JsonArray? messages, string draft)
    {
        Messages.Clear();
        if (messages != null)
        {
            foreach (var node in messages)
            {
                if (node is JsonObject message)
                {
                    Messages.Add(MessageBubble.From(message));
                }
            }
        }

        ComposerText = draft;
        EmptyVisible = Messages.Count == 0;
        AnswerActionsVisible = false;
        CopyEnabled = false;
        SpeakEnabled = false;
        DetailsEnabled = false;
        LastAnswerReset();
    }

    public void AddUser(string text)
    {
        Messages.Add(new MessageBubble { Role = "user", Text = text });
        EmptyVisible = false;
    }

    public void AddAnswer(string answer, JsonArray? steps, bool chainOk)
    {
        Messages.Add(new MessageBubble { Role = "assistant", Text = answer });
        lastAnswer = answer;
        lastSteps = steps;
        lastChainOk = chainOk;
        AnswerActionsVisible = true;
        CopyEnabled = answer.Length > 0;
        SpeakEnabled = answer.Length > 0;
        DetailsEnabled = steps is { Count: > 0 };
    }

    /// <summary>The W6 fixture: a conversation with a long answer, an error and an attachment.</summary>
    public void ShowMock(
        IEnumerable<MessageBubble> bubbles,
        string error,
        string attachmentName,
        string attachmentDetail)
    {
        Messages.Clear();
        foreach (var bubble in bubbles)
        {
            Messages.Add(bubble);
        }

        EmptyVisible = false;
        AnswerActionsVisible = false;
        CopyEnabled = false;
        SpeakEnabled = false;
        DetailsEnabled = false;
        ShowError(error);
        ShowAttachment(attachmentName, attachmentDetail);
    }

    public void ShowError(string message) => Error = message;

    public void ClearError() => Error = "";

    public void SetRunning(bool value)
    {
        Running = value;
        SendGlyph = value ? "\u25A0" : "\u2191";
    }

    public void SetMic(bool recording) => MicText = recording ? "Stop" : "Mic";

    public void ShowAttachment(string name, string detail)
    {
        AttachmentName = name;
        AttachmentDetail = detail;
        AttachmentVisible = true;
    }

    public void ClearAttachment()
    {
        AttachmentName = "";
        AttachmentDetail = "";
        AttachmentVisible = false;
    }

    public void AppendComposer(string text)
    {
        ComposerText = ComposerText.Length == 0 ? text : ComposerText + " " + text;
    }

    public void SetTarget(bool visible, bool useBridge)
    {
        TargetVisible = visible;
        TargetText = useBridge ? "Phone" : "Laptop";
        TargetInk = useBridge ? Blue : Quiet;
    }

    private void LastAnswerReset()
    {
        lastAnswer = "";
        lastSteps = null;
        lastChainOk = false;
    }
}
