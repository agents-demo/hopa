namespace Hopa.Windows.Cli;

/// <summary>Every way the process can be started, as named by its command line.</summary>
public enum RunMode
{
    ObservationCheck,
    DevicePortCheck,
    DevicePortWait,
    IntentCheck,
    AppMatrixCheck,
    VoiceCheck,
    SettingsCheck,
    Turn,
    ConversationList,
    SettingsShot,
    SettingsPagesShot,
    DraftCheck,
    BridgeCheck,
    ChatShot,
    KeyboardCheck,
    ComponentShot,
    FrameShot,
    WindowCheck,
    AttachCheck,
    CancelCheck,
    HistoryCheck,
    PcCheck,
    Pair,
    StaleCheck,
    WebCheck,
    P5Check,
}

/// <summary>One command line, already split into a mode and its operands.</summary>
internal sealed record Command(RunMode Mode, string?[] Args)
{
    public string Arg(int index) => Args[index] ?? "";

    public string ArgOr(int index, string fallback) =>
        Args[index] is { Length: > 0 } value ? value : fallback;

    public string? ArgOrNull(int index) => Args[index];

    public int Int(int index, int fallback) =>
        int.TryParse(Args[index], out var value) ? value : fallback;
}

/// <summary>
/// Parses the flags the docs and tools already use. The spellings never change;
/// a flag with too few operands falls back to the normal window, as before.
/// </summary>
internal static class CommandLine
{
    public static Command? Parse(string[] args)
    {
        if (args.Length == 0)
        {
            return null;
        }

        // `--list` has no required operand; every other mode does.
        if (args[0] == "--list")
        {
            return new Command(
                RunMode.ConversationList,
                new[] { args.Length >= 3 && args[1] == "--out" ? args[2] : null });
        }

        if (args.Length < 2)
        {
            return null;
        }

        return args[0] switch
        {
            "--w3-check" => new Command(RunMode.ObservationCheck, new[] { args[1] }),
            "--p2-check" => new Command(RunMode.DevicePortCheck, new[] { args[1] }),
            "--p2-wait" => new Command(
                RunMode.DevicePortWait,
                new[]
                {
                    args[1],
                    args.Length >= 3 ? args[2] : null,
                    args.Length >= 4 ? args[3] : null,
                }),
            "--p3-check" => new Command(RunMode.IntentCheck, new[] { args[1] }),
            "--matrix-check" => new Command(RunMode.AppMatrixCheck, new[] { args[1] }),
            "--voice-check" => args.Length >= 3
                ? new Command(RunMode.VoiceCheck, new[] { args[1], args[2] })
                : null,
            "--settings-check" => new Command(RunMode.SettingsCheck, new[] { args[1] }),
            "--turn" => Turn(args),
            "--shot-settings" => new Command(RunMode.SettingsShot, new[] { args[1] }),
            "--shot-settings-pages" => new Command(RunMode.SettingsPagesShot, new[] { args[1] }),
            "--draft-check" => new Command(RunMode.DraftCheck, new[] { args[1] }),
            "--bridge-check" => args.Length >= 4
                ? new Command(RunMode.BridgeCheck, new[] { args[1], args[2], args[3] })
                : null,
            "--shot-chat" => new Command(RunMode.ChatShot, new[] { args[1] }),
            "--keyboard-check" => new Command(RunMode.KeyboardCheck, new[] { args[1] }),
            "--shot-components" => new Command(RunMode.ComponentShot, new[] { args[1] }),
            "--shot-frame" => new Command(RunMode.FrameShot, new[] { args[1] }),
            "--w4-check" => new Command(RunMode.WindowCheck, new[] { args[1] }),
            "--attach-check" => args.Length >= 3
                ? new Command(RunMode.AttachCheck, new[] { args[1], args[2] })
                : null,
            "--cancel-check" => new Command(RunMode.CancelCheck, new[] { args[1] }),
            "--history-check" => new Command(RunMode.HistoryCheck, new[] { args[1] }),
            "--pc-check" => new Command(RunMode.PcCheck, new[] { args[1] }),
            "--pair" => args.Length >= 4
                ? new Command(RunMode.Pair, new[] { args[1], args[2], args[3] })
                : null,
            "--stale-check" => args.Length >= 3
                ? new Command(RunMode.StaleCheck, new[] { args[1], args[2] })
                : null,
            "--web-check" => new Command(RunMode.WebCheck, new[] { args[1] }),
            "--p5-check" => new Command(
                RunMode.P5Check,
                new[] { args[1], args.Length >= 3 && args[2] == "--auto-sign" ? "auto" : null }),
            _ => null,
        };
    }

    private static Command? Turn(string[] args)
    {
        string? output = null;
        string? shot = null;
        string? approval = null;
        for (var index = 2; index + 1 < args.Length; index += 2)
        {
            switch (args[index])
            {
                case "--out":
                    output = args[index + 1];
                    break;
                case "--shot":
                    shot = args[index + 1];
                    break;
                case "--approval":
                    approval = args[index + 1];
                    break;
            }
        }

        return new Command(RunMode.Turn, new[] { args[1], output, shot, approval });
    }
}
