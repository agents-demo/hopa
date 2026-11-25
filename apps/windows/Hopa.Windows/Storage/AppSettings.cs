namespace Hopa.Windows.Storage;

/// <summary>Non-secret preferences; keys live in Windows Credential Manager.</summary>
public sealed class AppSettings
{
    public string BridgeUrl { get; set; } = "";

    public bool UseBridge { get; set; }

    public string ModelProvider { get; set; } = "openai";

    public string ModelBaseUrl { get; set; } = "https://api.openai.com/v1";

    public string ModelName { get; set; } = "gpt-4o-mini";

    public string Tone { get; set; } = "warm";

    public string Profile { get; set; } = "everyday";

    /// <summary>`auto` uses recipes and instant commands before the model; `model` skips both.</summary>
    public string StepSource { get; set; } = "auto";

    /// <summary>Try a stored recipe before asking the model.</summary>
    public bool ReplaySkills { get; set; } = true;

    /// <summary>Ask for a plan and wait for approval before acting.</summary>
    public bool PlanFirst { get; set; }

    /// <summary>Run recognized launch/back/home/scroll goals without the model.</summary>
    public bool InstantCommands { get; set; } = true;

    /// <summary>Attach a screenshot when the model accepts images.</summary>
    public bool Vision { get; set; }

    public double? WindowLeft { get; set; }

    public double? WindowTop { get; set; }

    public double WindowWidth { get; set; } = 1140;

    public double WindowHeight { get; set; } = 760;

    public bool WindowMaximized { get; set; }
}
