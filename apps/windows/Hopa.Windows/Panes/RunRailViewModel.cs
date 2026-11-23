using System.Collections.ObjectModel;
using System.Text.Json.Nodes;
using System.Windows.Media;
using Hopa.Windows.Chat;

namespace Hopa.Windows.Panes;

/// <summary>
/// The right rail: what the last answer actually ran. It reads one turn and
/// knows nothing about the window, the engine client or the clipboard.
/// </summary>
public sealed class RunRailViewModel : ObservableObject
{
    private static readonly Brush Green = new SolidColorBrush(Color.FromRgb(0x2E, 0x7D, 0x5B));
    private static readonly Brush Red = new SolidColorBrush(Color.FromRgb(0xC0, 0x39, 0x2B));
    private static readonly Brush Amber = new SolidColorBrush(Color.FromRgb(0xB2, 0x6A, 0x00));
    private static readonly Brush Quiet = new SolidColorBrush(Color.FromRgb(0x9A, 0x94, 0x88));

    private string title = "THIS ANSWER";
    private string status = "Nothing ran yet";
    private string facts = "";
    private string earlier = "";
    private string measured = "";
    private string bridgeText = "No bridge \u00B7 this conversation only";
    private Brush dot = Quiet;
    private Brush bridgeDot = Amber;

    public ObservableCollection<RunStepRow> Steps { get; } = new();

    public string Title
    {
        get => title;
        private set => Set(ref title, value);
    }

    public string Status
    {
        get => status;
        private set => Set(ref status, value);
    }

    public string Facts
    {
        get => facts;
        private set => Set(ref facts, value);
    }

    public string Earlier
    {
        get => earlier;
        private set
        {
            if (Set(ref earlier, value))
            {
                Raise(nameof(HasEarlier));
            }
        }
    }

    public bool HasEarlier => earlier.Length > 0;

    public string Measured
    {
        get => measured;
        private set
        {
            if (Set(ref measured, value))
            {
                Raise(nameof(HasMeasured));
            }
        }
    }

    public bool HasMeasured => measured.Length > 0;

    public string BridgeText
    {
        get => bridgeText;
        private set => Set(ref bridgeText, value);
    }

    public Brush Dot
    {
        get => dot;
        private set => Set(ref dot, value);
    }

    public Brush BridgeDot
    {
        get => bridgeDot;
        private set => Set(ref bridgeDot, value);
    }

    /// <summary>Shows one real turn: its steps, the gate result and how long it took.</summary>
    public void ShowTurn(JsonArray? steps, bool chainOk, TimeSpan elapsed, string question)
    {
        Steps.Clear();
        var count = steps?.Count ?? 0;
        if (count > 0)
        {
            Title = "LAST RUN";
            Status = chainOk ? "Succeeded" : "Failed";
            Facts = $"{count} steps";
            Dot = chainOk ? Green : Red;
            foreach (var step in steps!.OfType<JsonObject>())
            {
                Steps.Add(RunStepRow.From(step));
            }
        }
        else
        {
            Title = "THIS ANSWER";
            Status = "Answered";
            Facts = "no local record";
            Dot = Green;
        }

        Measured = $"answered in {elapsed.TotalSeconds:0.0} s";
        Earlier = question.Length > 0 ? "Earlier: " + question : "";
    }

    /// <summary>The rail line about the bridge; the composer and header stay elsewhere.</summary>
    public void ShowBridge(bool live)
    {
        BridgeText = live
            ? "Bridge connected \u00B7 every action asks first."
            : "No bridge \u00B7 this conversation only.";
        BridgeDot = live ? Green : Amber;
    }

    /// <summary>The fixture behind the W6 screenshot; it is not a real turn.</summary>
    public void ShowMock(string status, string facts, IEnumerable<RunStepRow> steps)
    {
        Title = "LAST RUN";
        Status = status;
        Facts = facts;
        Dot = Green;
        Steps.Clear();
        foreach (var step in steps)
        {
            Steps.Add(step);
        }
    }

    public void Reset()
    {
        Title = "THIS ANSWER";
        Status = "Nothing ran yet";
        Facts = "";
        Earlier = "";
        Measured = "";
        Dot = Quiet;
        Steps.Clear();
    }
}
