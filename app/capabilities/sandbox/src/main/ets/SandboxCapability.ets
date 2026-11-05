import { Action, ActionCapability, Observation } from '@hopa/core';

/**
 * Bridge to the hidden ArkWeb page hosting Pyodide (Python) and QuickJS
 * (JavaScript). The entry app attaches the bridge after the hidden page is ready.
 *
 * The bundled WASM/JS assets live under rawfile and are loaded offline by
 * default. Do not expose device APIs, files, or the network to scripts without an
 * explicit, logged user grant.
 */
export interface SandboxBridge {
  run(script: string, language: string): Promise<string>;
}

export class SandboxCapability implements ActionCapability {
  private bridge: SandboxBridge | undefined = undefined;
  private offline: boolean = true;

  setBridge(bridge: SandboxBridge): void {
    this.bridge = bridge;
  }

  setOffline(offline: boolean): void {
    this.offline = offline;
  }

  isOffline(): boolean {
    return this.offline;
  }

  canHandle(kind: string): boolean {
    return kind === 'sandbox.run';
  }

  async execute(action: Action): Promise<Observation> {
    if (this.bridge === undefined) {
      return Observation.fail('sandbox bridge is not attached (hidden ArkWeb page not ready)');
    }
    const language: string = action.target.length > 0 ? action.target : 'python';
    try {
      const output: string = await this.bridge.run(action.text, language);
      return Observation.ok(output);
    } catch (error) {
      return Observation.fail(`sandbox error: ${error}`);
    }
  }
}
