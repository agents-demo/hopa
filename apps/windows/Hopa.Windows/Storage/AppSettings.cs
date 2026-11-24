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

    /// <summary>Try a stored recipe before asking the model.</summary>
    public bool ReplaySkills { get; set; } = true;

    /// <summary>Attach a screenshot when the model accepts images.</summary>
    public bool Vision { get; set; }

    public double? WindowLeft { get; set; }

    public double? WindowTop { get; set; }

    public double WindowWidth { get; set; } = 1140;

    public double WindowHeight { get; set; } = 760;

    public bool WindowMaximized { get; set; }
}
