import { Action, ActionCapability, Observation } from '@hopa/core';
import { A11yBridge } from './A11yBridge';

/**
 * On-device UI actions on top of the accessibility extension.
 *
 * Every action is refused unless the bridge is attached (extension declared,
 * ACL approved, service enabled). Coordinates are never taken from the model:
 * `ui.tap` and `ui.type` address element refs from the latest observation, and
 * `ui.swipe` uses the coordinates the gate already received.
 */
export class UiCapability implements ActionCapability {
  canHandle(kind: string): boolean {
    return kind === 'ui.tap' || kind === 'ui.type' || kind === 'ui.swipe' || kind === 'ui.longPress';
  }

  async execute(action: Action): Promise<Observation> {
    const bridge = A11yBridge.get();
    if (!bridge.isAvailable()) {
      return Observation.fail(
        'accessibility unavailable: restricted permission/ACL not granted or service disabled'
      );
    }

    if (action.kind === 'ui.tap') {
      if (action.target.length === 0) {
        return Observation.fail('ui.tap needs an element ref in target');
      }
      const clicked: boolean = await bridge.tap(action.target);
      return clicked
        ? Observation.ok(`tapped ${action.target}`)
        : Observation.fail(`tap failed: ${action.target}`);
    }

    if (action.kind === 'ui.type') {
      if (action.target.length === 0) {
        return Observation.fail('ui.type needs an element ref in target');
      }
      const typed: boolean = await bridge.typeInto(action.target, action.text);
      return typed
        ? Observation.ok(`typed ${action.text.length} characters into ${action.target}`)
        : Observation.fail(`type failed: ${action.target} does not accept setText`);
    }

    if (action.kind === 'ui.swipe') {
      const swiped: boolean = await bridge.swipe(action.x, action.y, action.toX, action.toY);
      return swiped
        ? Observation.ok(`swiped ${action.x},${action.y} -> ${action.toX},${action.toY}`)
        : Observation.fail('swipe failed');
    }

    if (action.kind === 'ui.longPress') {
      if (action.target.length === 0) {
        return Observation.fail('ui.longPress needs an element ref in target');
      }
      const pressed: boolean = await bridge.longPress(action.target);
      return pressed
        ? Observation.ok(`long-pressed ${action.target}`)
        : Observation.fail(`long press failed: ${action.target}`);
    }

    return Observation.fail(`unsupported ui action: ${action.kind}`);
  }
}
