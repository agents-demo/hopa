import type {
  AccessibilityElement,
  AccessibilityExtensionContext
} from '@ohos.application.AccessibilityExtensionAbility';
import { GesturePath, GesturePoint } from '@kit.AccessibilityKit';
import { Screen, ScreenNode } from '@hopa/core';

/**
 * Bridges the accessibility extension to the core `Screen` model.
 *
 * It is inert until the extension is declared, the ACL is approved and the user
 * enables the service. `capture()` never throws to the agent: on any failure it
 * returns the last known screen.
 */
export class AccessibilityBridge {
  private static instance: AccessibilityBridge | undefined = undefined;
  private context?: AccessibilityExtensionContext;
  private connected: boolean = false;
  private bridgePreferred: boolean = false;
  private lastScreen: Screen = new Screen();
  private elements: Map<string, AccessibilityElement> = new Map<string, AccessibilityElement>();
  private nextRef: number = 0;
  private width: number = 0;
  private height: number = 0;

  static get(): AccessibilityBridge {
    if (AccessibilityBridge.instance === undefined) {
      AccessibilityBridge.instance = new AccessibilityBridge();
    }
    return AccessibilityBridge.instance;
  }

  attach(context: AccessibilityExtensionContext): void {
    this.context = context;
    this.connected = true;
  }

  detach(): void {
    this.context = undefined;
    this.connected = false;
    this.elements.clear();
  }

  isAvailable(): boolean {
    return this.connected;
  }

  /**
   * Marks the PC bridge as the active control backend.
   *
   * The extension can report `connected` even when the user has not enabled
   * the service, and in that state `capture()` and gestures can hang. When a
   * bridge is configured it is the only safe backend for both the screen and
   * the actions, so the on-device path stands down.
   */
  setBridgePreferred(value: boolean): void {
    this.bridgePreferred = value;
  }

  isBridgePreferred(): boolean {
    return this.bridgePreferred;
  }

  find(ref: string): AccessibilityElement | undefined {
    return this.elements.get(ref);
  }

  /** Clicks the element captured in the last `capture()`. */
  async tap(ref: string): Promise<boolean> {
    const element: AccessibilityElement | undefined = this.elements.get(ref);
    if (element === undefined) {
      return false;
    }
    try {
      const names = await element.actionNames();
      if (!names.includes('click')) {
        return false;
      }
      await element.performAction('click');
      return true;
    } catch (error) {
      return false;
    }
  }

  /** Sets text on an editable element captured in the last `capture()`. */  async typeInto(ref: string, text: string): Promise<boolean> {
    const element: AccessibilityElement | undefined = this.elements.get(ref);
    if (element === undefined) {
      return false;
    }
    try {
      const names = await element.actionNames();
      if (!names.includes('setText')) {
        if (names.includes('focus')) {
          await element.performAction('focus');
        }
        return false;
      }
      await element.performAction('setText', { setText: text });
      return true;
    } catch (error) {
      return false;
    }
  }

  /** Long-presses the element captured in the last `capture()`. */
  async longPress(ref: string): Promise<boolean> {
    const element: AccessibilityElement | undefined = this.elements.get(ref);
    if (element === undefined) {
      return false;
    }
    try {
      const names = await element.actionNames();
      if (!names.includes('longClick')) {
        return false;
      }
      await element.performAction('longClick');
      return true;
    } catch (error) {
      return false;
    }
  }

  /** Swipes between two screen points, in layout pixels. */
  async swipe(fromX: number, fromY: number, toX: number, toY: number): Promise<boolean> {
    if (this.context === undefined) {
      return false;
    }
    try {
      const path = new GesturePath(300);
      path.points.push(new GesturePoint(fromX, fromY));
      path.points.push(new GesturePoint(toX, toY));
      await this.context.injectGesture(path);
      return true;
    } catch (error) {
      return false;
    }
  }

  /** System back via the edge-back gesture. */
  async back(): Promise<boolean> {
    if (this.width <= 0 || this.height <= 0) {
      return false;
    }
    return this.swipe(2, this.height / 2, this.width * 0.65, this.height / 2);
  }

  /** Home via the bottom-up gesture. */
  async home(): Promise<boolean> {
    if (this.width <= 0 || this.height <= 0) {
      return false;
    }
    return this.swipe(this.width / 2, this.height - 5, this.width / 2, this.height * 0.55);
  }

  /** Scrolls the content: "down" moves the page down (finger moves up). */
  async scroll(direction: string): Promise<boolean> {
    if (this.width <= 0 || this.height <= 0) {
      return false;
    }
    const cx: number = this.width / 2;
    const cy: number = this.height / 2;
    const dx: number = this.width * 0.3;
    const dy: number = this.height * 0.3;
    const dir: string = direction.toLowerCase();
    if (dir === 'up') {
      return this.swipe(cx, cy - dy, cx, cy + dy);
    }
    if (dir === 'left') {
      return this.swipe(cx - dx, cy, cx + dx, cy);
    }
    if (dir === 'right') {
      return this.swipe(cx + dx, cy, cx - dx, cy);
    }
    return this.swipe(cx, cy + dy, cx, cy - dy);
  }

  async capture(): Promise<Screen> {
    if (this.context === undefined) {
      return this.lastScreen;
    }
    try {
      const root = await this.context.getWindowRootElement();
      this.elements.clear();
      this.nextRef = 0;
      const rootRect = await this.rectAttribute(root);
      if (rootRect.length === 4) {
        this.width = rootRect[2];
        this.height = rootRect[3];
      }
      const node = await this.convert(root);
      this.lastScreen = new Screen(this.flatten(node), [node]);
      return this.lastScreen;
    } catch (error) {
      return this.lastScreen;
    }
  }

  private async convert(element: AccessibilityElement): Promise<ScreenNode> {
    this.nextRef++;
    const ref = `e${this.nextRef}`;
    this.elements.set(ref, element);

    const node = new ScreenNode();
    node.ref = ref;
    node.type = await this.textAttribute(element, 'componentType');
    node.text = await this.textAttribute(element, 'text');
    if (node.text.length === 0) {
      node.text = await this.textAttribute(element, 'accessibilityText');
    }
    node.clickable = await this.boolAttribute(element, 'clickable');
    node.checked = await this.boolAttribute(element, 'checked');
    node.bounds = await this.rectAttribute(element);

    try {
      const children = await element.attributeValue('children');
      for (const child of children) {
        node.children.push(await this.convert(child));
      }
    } catch (error) {
      // A leaf or a restricted node: no children.
    }
    return node;
  }

  private async textAttribute(
    element: AccessibilityElement,
    name: 'componentType' | 'text' | 'accessibilityText'
  ): Promise<string> {
    try {
      const value = await element.attributeValue(name);
      return value === undefined || value === null ? '' : `${value}`;
    } catch (error) {
      return '';
    }
  }

  private async boolAttribute(
    element: AccessibilityElement,
    name: 'clickable' | 'checked'
  ): Promise<boolean> {
    try {
      return (await element.attributeValue(name)) === true;
    } catch (error) {
      return false;
    }
  }

  private async rectAttribute(element: AccessibilityElement): Promise<number[]> {
    try {
      const rect = await element.attributeValue('rect');
      return [rect.left, rect.top, rect.left + rect.width, rect.top + rect.height];
    } catch (error) {
      return [];
    }
  }

  private flatten(node: ScreenNode): string {
    const lines: string[] = [];
    if (node.text.length > 0) {
      lines.push(node.text);
    }
    for (const child of node.children) {
      const text = this.flatten(child);
      if (text.length > 0) {
        lines.push(text);
      }
    }
    return lines.join('\n');
  }
}
