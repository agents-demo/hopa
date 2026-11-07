import {
  Action,
  ActionCapability,
  Observation,
  Screen,
  ScreenNode,
  ScreenSource
} from '@hopa/core';
import { A11yBridge } from '@hopa/capability-a11y';
import { RemoteBridge, RemoteNode } from './RemoteBridge';
/** Feeds the loop with the PC bridge's layout instead of the local screen. */
export class RemoteScreenSource implements ScreenSource {
  private bridge: RemoteBridge;

  constructor(bridge: RemoteBridge) {
    this.bridge = bridge;
  }

  async capture(): Promise<Screen> {
    const ok: boolean = await this.bridge.observe();
    if (!ok) {
      return new Screen('');
    }
    const nodes: ScreenNode[] = [];
    for (const node of this.bridge.nodes()) {
      const item = new ScreenNode();
      item.ref = node.ref;
      item.type = node.type;
      item.text = node.text.length > 0 ? node.text : node.description;
      item.bounds = node.bounds;
      item.clickable = node.clickable;
      nodes.push(item);
    }
    return new Screen(this.bridge.lastPageText(), nodes);
  }
}

/**
 * Executes ui actions through the PC bridge.
 *
 * It only handles actions when the bridge is configured and the local
 * accessibility service is not available, so the on-device path always wins.
 */
export class RemoteUiCapability implements ActionCapability {
  private bridge: RemoteBridge;

  constructor(bridge: RemoteBridge) {
    this.bridge = bridge;
  }

  canHandle(kind: string): boolean {
    if (!this.bridge.isConfigured()) {
      return false;
    }
    const wanted: boolean = kind === 'ui.tap' ||
      kind === 'ui.doubleTap' ||
      kind === 'ui.type' ||
      kind === 'ui.launch' ||
      kind === 'ui.back' ||
      kind === 'ui.home' ||
      kind === 'ui.scroll' ||
      kind === 'ui.swipe' ||
      kind === 'ui.longPress';
    if (!wanted) {
      return false;
    }
    if (A11yBridge.get().isRemotePreferred()) {
      return true;
    }
    return !A11yBridge.get().isAvailable();
  }

  private center(ref: string): number[] {
    const bounds: number[] = this.bridge.boundsFor(ref);
    if (bounds.length !== 4) {
      return [];
    }
    return [(bounds[0] + bounds[2]) / 2, (bounds[1] + bounds[3]) / 2];
  }

  async execute(action: Action): Promise<Observation> {
    if (action.kind === 'ui.launch') {
      const launched: boolean = await this.bridge.launch(action.app);
      return launched
        ? Observation.ok(`launched ${action.app} (PC bridge)`)
        : Observation.fail('bridge launch failed');
    }

    if (action.kind === 'ui.back') {
      const done: boolean = await this.bridge.key('Back');
      return done ? Observation.ok('back (PC bridge)') : Observation.fail('bridge back failed');
    }

    if (action.kind === 'ui.home') {
      const done: boolean = await this.bridge.key('Home');
      return done ? Observation.ok('home (PC bridge)') : Observation.fail('bridge home failed');
    }

    if (action.kind === 'ui.tap' || action.kind === 'ui.doubleTap' || action.kind === 'ui.longPress') {
      const point: number[] = this.center(action.target);
      if (point.length !== 2) {
        return Observation.fail(`no bounds for ${action.target}`);
      }
      const first: boolean = await this.bridge.tap(point[0], point[1]);
      if (!first) {
        return Observation.fail('bridge tap failed');
      }
      if (action.kind !== 'ui.tap') {
        await this.bridge.tap(point[0], point[1]);
      }
      return Observation.ok(`tapped ${action.target} (PC bridge)`);
    }

    if (action.kind === 'ui.type') {
      const point: number[] = this.center(action.target);
      if (point.length !== 2) {
        return Observation.fail(`no bounds for ${action.target}`);
      }
      const typed: boolean = await this.bridge.typeText(action.text, point[0], point[1]);
      return typed
        ? Observation.ok(`typed into ${action.target} (PC bridge)`)
        : Observation.fail('bridge type failed');
    }

    if (action.kind === 'ui.swipe') {
      const done: boolean = await this.bridge.swipe(
        action.x,
        action.y,
        action.toX,
        action.toY
      );
      return done ? Observation.ok('swiped (PC bridge)') : Observation.fail('bridge swipe failed');
    }

    if (action.kind === 'ui.scroll') {
      const width: number = this.bridge.screenWidth();
      const height: number = this.bridge.screenHeight();
      if (width <= 0 || height <= 0) {
        return Observation.fail('bridge has no screen size');
      }
      const cx: number = width / 2;
      const cy: number = height / 2;
      const dy: number = height * 0.3;
      const dx: number = width * 0.3;
      const direction: string = action.text.length > 0 ? action.text.toLowerCase() : 'down';
      let done: boolean = false;
      if (direction === 'up') {
        done = await this.bridge.swipe(cx, cy - dy, cx, cy + dy);
      } else if (direction === 'left') {
        done = await this.bridge.swipe(cx - dx, cy, cx + dx, cy);
      } else if (direction === 'right') {
        done = await this.bridge.swipe(cx + dx, cy, cx - dx, cy);
      } else {
        done = await this.bridge.swipe(cx, cy + dy, cx, cy - dy);
      }
      return done
        ? Observation.ok(`scrolled ${direction} (PC bridge)`)
        : Observation.fail('bridge scroll failed');
    }

    return Observation.fail(`unsupported bridge action: ${action.kind}`);
  }
}
