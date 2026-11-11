import { ActionOutcome } from '@hopa/core';

/**
 * What the agent runtime needs from its host.
 *
 * The runtime owns the loop; the host owns the machine. Declaring these here
 * is what lets the same runtime run on a phone (bridge + accessibility) and on
 * a laptop (local equivalents) without importing either platform's modules.
 */

export interface RuntimeBrowser {
  isReady(): boolean;
  currentUrl(): string;
  currentTitle(): string;
  pageText(): Promise<string>;
}

export interface RuntimeBridge {
  isConfigured(): boolean;
  screenshot(): Promise<string>;
  foregroundBundle(): Promise<string>;
  launch(bundle: string): Promise<boolean>;
}

export interface RuntimeBackground {
  begin(): Promise<void>;
  end(): Promise<void>;
  returnToForeground(): Promise<boolean>;
}

export interface RuntimeAccessibility {
  isAvailable(): boolean;
}

export interface RuntimePageLinks {
  capture(outcomes: ActionOutcome[], browser: RuntimeBrowser): void;
  clear(): void;
}
