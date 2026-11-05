import AccessibilityExtensionAbility from '@ohos.application.AccessibilityExtensionAbility';
import { AccessibilityEvent } from '@ohos.accessibility';

/**
 * AccessibilityExtensionAbility skeleton.
 *
 * REQUIRES: a restricted permission + an approved ACL request, an
 * `extensionAbilities` declaration in this module's module.json5, and the user
 * enabling the service in Settings -> Accessibility. Do not claim it works until
 * all three are verified on a real device.
 *
 * The exact import path/signature is validated against the installed API 26 SDK
 * at build time (see docs/architecture.md).
 */
export default class HopaAccessibilityExtension extends AccessibilityExtensionAbility {
  onConnect(): void {
    // Mark the capability available only after the system connects the service.
  }

  onAccessibilityEvent(event: AccessibilityEvent): void {
    // Observe the active window and forward a redacted event to the agent.
  }

  onDisconnect(): void {
    // Mark the capability unavailable.
  }
}
