import AccessibilityExtensionAbility from '@ohos.application.AccessibilityExtensionAbility';
import { AccessibilityEvent } from '@ohos.accessibility';
import { AccessibilityBridge } from '../AccessibilityBridge';

/**
 * AccessibilityExtensionAbility.
 *
 * REQUIRES: a restricted permission + an approved ACL request, an
 * `extensionAbilities` declaration in this module's module.json5, and the user
 * enabling the service in Settings -> Accessibility. Until then this class is
 * compiled but never connected.
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
