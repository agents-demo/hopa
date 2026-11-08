import { RiskLevel, ToolDescriptor, ToolRegistry } from '@hopa/core';

/** The tool list the prompt can offer. One place, alphabetical by kind. */
export class ToolRegistryDefaults {
  static create(): ToolRegistry {
    const tools = new ToolRegistry();
    tools.register(new ToolDescriptor('payment.confirm', 'Confirm a payment', RiskLevel.Payment));
    tools.register(new ToolDescriptor('sandbox.run', 'Run an offline script', RiskLevel.Read));
    tools.register(new ToolDescriptor('system.openLink', 'Open an https link', RiskLevel.Read));
    tools.register(new ToolDescriptor('ui.longPress', 'Long-press a screen element', RiskLevel.Sensitive));
    tools.register(new ToolDescriptor('ui.sendMessage', 'Send a message', RiskLevel.Sensitive));
    tools.register(new ToolDescriptor('ui.swipe', 'Scroll the current screen', RiskLevel.Read));
    tools.register(new ToolDescriptor('ui.tap', 'Tap a screen element', RiskLevel.Read));
    tools.register(new ToolDescriptor('ui.type', 'Type into a screen element', RiskLevel.Sensitive));
    tools.register(new ToolDescriptor('web.navigate', 'Navigate the web view', RiskLevel.Read));
    tools.register(new ToolDescriptor('web.read', 'Read the current page', RiskLevel.Read));
    return tools;
  }
}
