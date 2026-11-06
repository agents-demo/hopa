/**
 * A screen snapshot for the gate and the loop.
 *
 * The on-device a11y capability will produce this from the accessibility tree.
 * Local tests use it directly. It carries text, not pixels, so the payment
 * classifier can run without a screenshot.
 */
export class ScreenNode {
  ref: string = '';
  type: string = '';
  text: string = '';
  nodeId: string = '';
  bounds: number[] = [];
  clickable: boolean = false;
  children: ScreenNode[] = [];
}

export class Screen {
  text: string = '';
  focus: string = '';
  nodes: ScreenNode[] = [];

  constructor(text: string = '', nodes: ScreenNode[] = [], focus: string = '') {
    this.text = text;
    this.nodes = nodes;
    this.focus = focus;
  }

  containsAny(words: string[]): boolean {
    const haystack: string = this.text.toLowerCase();
    for (const word of words) {
      if (haystack.includes(word.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  findRef(ref: string): ScreenNode | undefined {
    for (const node of this.nodes) {
      const found: ScreenNode | undefined = this.findInNode(node, ref);
      if (found !== undefined) {
        return found;
      }
    }
    return undefined;
  }

  private findInNode(node: ScreenNode, ref: string): ScreenNode | undefined {
    if (node.ref === ref) {
      return node;
    }
    for (const child of node.children) {
      const found: ScreenNode | undefined = this.findInNode(child, ref);
      if (found !== undefined) {
        return found;
      }
    }
    return undefined;
  }
}

/** The capability that captures the current screen. */
export interface ScreenSource {
  capture(): Promise<Screen>;
}
