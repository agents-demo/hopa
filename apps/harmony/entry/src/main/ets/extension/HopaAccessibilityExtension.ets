import AccessibilityExtensionAbility, {
  AccessibilityEvent
} from '@ohos.application.AccessibilityExtensionAbility';
import { AccessibilityBridge } from '@hopa/capability-accessibility';

/**
 * AccessibilityExtensionAbility for HOPA.
 *
 * REQUIRES: the restricted permission, an ACL entry in the signing profile,
 * this declaration in the entry module, and the user enabling the service in
 * Settings -> Accessibility. Until all four are true, it never connects.
 */
export default class HopaAccessibilityExtension extends AccessibilityExtensionAbility {
  onConnect(): void {
    AccessibilityBridge.get().attach(this.context);
  }

  onAccessibilityEvent(event: AccessibilityEvent): void {
    // Capture is pull-based; the event only tells us the screen changed.
  }

  onDisconnect(): void {
    AccessibilityBridge.get().detach();
  }
}
