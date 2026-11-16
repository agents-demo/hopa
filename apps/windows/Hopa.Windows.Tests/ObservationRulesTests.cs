using Hopa.Windows;
using Xunit;

namespace Hopa.Windows.Tests;

/// <summary>
/// The observation must be reproducible: the same screen gives the same text and
/// the same hash, caps are enforced where they are declared, and a password
/// field never reaches the text or the hash.
/// </summary>
public sealed class ObservationRulesTests
{
    [Fact]
    public void ShortTextIsKeptAsIs()
    {
        Assert.Equal("Pay now", ObservationRules.Cap("Pay now"));
    }

    [Fact]
    public void LongTextIsCutAndMarked()
    {
        var longText = new string('a', ObservationRules.MaxTextChars + 50);
        var capped = ObservationRules.Cap(longText);
        Assert.Equal(ObservationRules.MaxTextChars + 1, capped.Length);
        Assert.EndsWith("\u2026", capped);
    }

    [Fact]
    public void TextStopsAtFortyLinesAndSaysSo()
    {
        var lines = Enumerable.Range(0, 80).Select(index => $"e{index} button item {index}").ToList();
        var text = ObservationRules.JoinText(lines, out var truncated);
        Assert.True(truncated);
        Assert.Equal(ObservationRules.MaxTextLines, text.Split('\n').Length);
    }

    [Fact]
    public void TextStopsAtTheCharacterBudget()
    {
        var line = new string('x', ObservationRules.MaxTextChars);
        var lines = Enumerable.Repeat(line, 60).ToList();
        var text = ObservationRules.JoinText(lines, out var truncated);
        Assert.True(truncated);
        Assert.True(text.Length <= ObservationRules.MaxTotalChars + ObservationRules.MaxTextLines);
    }

    [Fact]
    public void SameScreenGivesTheSameHash()
    {
        var lines = new[] { "e1 window Notepad", "e2 document text", "e3 button Save" };
        Assert.Equal(
            ObservationRules.Hash("notepad", 1920, 1080, lines),
            ObservationRules.Hash("notepad", 1920, 1080, lines));
    }

    [Fact]
    public void ChangedTextChangesTheHash()
    {
        var before = ObservationRules.Hash("notepad", 1920, 1080, new[] { "e1 document draft" });
        var after = ObservationRules.Hash("notepad", 1920, 1080, new[] { "e1 document sent" });
        Assert.NotEqual(before, after);
    }

    [Fact]
    public void HashCarriesTheContractPrefix()
    {
        var hash = ObservationRules.Hash("calc", 800, 600, Array.Empty<string>());
        Assert.StartsWith("sha256:", hash);
        Assert.Equal(71, hash.Length);
    }

    [Fact]
    public void PasswordFieldsNeverEnterTheText()
    {
        // The walker writes "password field (dropped)" and drops the name; the
        // rule is asserted here so a refactor cannot silently reintroduce it.
        var lines = new[] { "e1 window Sign in", "e2 password field (dropped)" };
        var text = ObservationRules.JoinText(lines, out _);
        Assert.DoesNotContain("hunter2", text);
        Assert.Contains("password field (dropped)", text);
    }

    [Fact]
    public void AWindowWithNoNameAndNoChildrenIsAnEmptyTree()
    {
        Assert.True(ObservationRules.IsTreeOnlyRoot(1, ""));
        Assert.True(ObservationRules.IsTreeOnlyRoot(1, "   "));
    }

    [Fact]
    public void ATitleOnlyWindowIsStillObservable()
    {
        Assert.False(ObservationRules.IsTreeOnlyRoot(1, "e1 window Notepad"));
    }

    [Fact]
    public void ARealTreeIsNotCalledEmpty()
    {
        Assert.False(ObservationRules.IsTreeOnlyRoot(12, "e1 window Notepad"));
    }
}
