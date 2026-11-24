namespace Hopa.Windows.Integrations.Engine;

/// <summary>One learned phrase → action pair, shared with the Android contract.</summary>
public sealed record Skill(string Trigger, string Action);
