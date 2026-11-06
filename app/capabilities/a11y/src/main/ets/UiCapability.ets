import { Action, ActionCapability, Observation } from '@hopa/core';
import { A11yBridge } from './A11yBridge';

/** Starts another app; implemented by the entry module with a UI context. */
export interface UiLauncher {
  launch(bundle: string, ability: string): Promise<boolean>;
}

/**
 * On-device UI actions on top of the accessibility extension.
 *
 * Every action is refused unless the bridge is attached (extension declared,
 * ACL approved, service enabled). Coordinates are never taken from the model:
 * `ui.tap` and `ui.type` address element refs from the latest observation, and
 * `ui.swipe` uses the coordinates the gate already received.
 */
export class UiCapability implements ActionCapability {
  private launcher: UiLauncher | undefined = undefined;

  setLauncher(launcher: UiLauncher): void {
    this.launcher = launcher;
  }

  canHandle(kind: string): boolean {
    return kind === 'ui.tap' ||
      kind === 'ui.doubleTap' ||
      kind === 'ui.type' ||
      kind === 'ui.swipe' ||
      kind === 'ui.longPress' ||
      kind === 'ui.launch' ||
      kind === 'ui.back' ||
      kind === 'ui.home' ||
      kind === 'ui.scroll';
  }

  async execute(action: Action): Promise<Observation> {
    // Launching another app does not need the accessibility tree.
    if (action.kind === 'ui.launch') {
      if (this.launcher === undefined) {
        return Observation.fail('no app launcher is wired');
      }
      const bundle: string = action.app.length > 0
        ? action.app
        : (action.target.startsWith('com.') ? action.target : '');
      if (bundle.length === 0) {
        return Observation.fail('ui.launch needs the app bundle in app');
      }
      const launched: boolean = await this.launcher.launch(bundle, '');
      return launched
        ? Observation.ok(`launched ${bundle}`)
        : Observation.fail(`could not launch ${bundle}`);
    }

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

    if (action.kind === 'ui.doubleTap') {
      if (action.target.length === 0) {
        return Observation.fail('ui.doubleTap needs an element ref in target');
      }
      const first: boolean = await bridge.tap(action.target);
      const second: boolean = first ? await bridge.tap(action.target) : false;
      return second
        ? Observation.ok(`double-tapped ${action.target}`)
        : Observation.fail(`double tap failed: ${action.target}`);
    }

    if (action.kind === 'ui.back') {
      const done: boolean = await bridge.back();
      return done ? Observation.ok('back') : Observation.fail('back gesture failed');
    }

    if (action.kind === 'ui.home') {
      const done: boolean = await bridge.home();
      return done ? Observation.ok('home') : Observation.fail('home gesture failed');
    }

    if (action.kind === 'ui.scroll') {
      const direction: string = action.text.length > 0 ? action.text : 'down';
      const done: boolean = await bridge.scroll(direction);
      return done ? Observation.ok(`scrolled ${direction}`) : Observation.fail('scroll failed');
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
