import AccessibilityExtensionAbility, {
  AccessibilityEvent
} from '@ohos.application.AccessibilityExtensionAbility';
import { A11yBridge } from '@hopa/capability-a11y';

/**
 * AccessibilityExtensionAbility for HOPA.
 *
 * REQUIRES: the restricted permission, an ACL entry in the signing profile,
 * this declaration in the entry module, and the user enabling the service in
 * Settings -> Accessibility. Until all four are true, it never connects.
 */
export default class HopaAccessibilityExtension extends AccessibilityExtensionAbility {
  onConnect(): void {
    A11yBridge.get().attach(this.context);
  }

  onAccessibilityEvent(event: AccessibilityEvent): void {
    // Capture is pull-based; the event only tells us the screen changed.
  }

  onDisconnect(): void {
    A11yBridge.get().detach();
  }
}
