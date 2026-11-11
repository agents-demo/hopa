/**
 * The phone's policy for the PC bridge: the local accessibility service wins,
 * and the bridge never acts while HOPA's own chat is in front.
 */
import {
  BridgeScreenSource as SharedBridgeScreenSource,
  RemoteUiCapability as SharedRemoteUiCapability,
  RemoteUiGates
} from '@hopa/app';
import { AccessibilityBridge } from '@hopa/capability-accessibility';
import { AppFocus } from './AppFocus';
import { BridgeClient } from './BridgeClient';

class PhoneGates implements RemoteUiGates {
  selfInFront(): boolean {
    return AppFocus.active;
  }

  preferBridge(): boolean {
    if (AccessibilityBridge.get().isBridgePreferred()) {
      return true;
    }
    return !AccessibilityBridge.get().isAvailable();
  }
}

const PHONE_GATES: PhoneGates = new PhoneGates();

/** Feeds the loop the bridge's layout instead of the local screen. */
export class BridgeScreenSource extends SharedBridgeScreenSource {
  constructor(bridge: BridgeClient) {
    super(bridge, PHONE_GATES);
  }
}

/** Runs ui actions through the PC bridge, under the phone's policy. */
export class RemoteUiCapability extends SharedRemoteUiCapability {
  constructor(bridge: BridgeClient) {
    super(bridge, PHONE_GATES);
  }
}
