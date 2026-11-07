import { describe, expect, it } from '@ohos/hypium';
import { Screen, ScreenNode } from '../main/ets/Screen';

function node(ref: string, text: string, clickable: boolean): ScreenNode {
  const item = new ScreenNode();
  item.ref = ref;
  item.type = 'Button';
  item.text = text;
  item.clickable = clickable;
  return item;
}

export default function screenTest(): void {
  describe('Screen', () => {
    it('describes_refs_for_the_prompt', 0, () => {
      const screen = new Screen(
        'HOPA',
        [node('e1', 'Web', false), node('e2', 'Send', true)]
      );
      const text: string = screen.describeNodes();
      expect(text.includes('e1 Button "Web"')).assertTrue();
      expect(text.includes('e2 Button "Send" [tap]')).assertTrue();
    });

    it('limits_the_element_list', 0, () => {
      const nodes: ScreenNode[] = [];
      for (let index = 0; index < 10; index++) {
        nodes.push(node(`e${index}`, `Item ${index}`, true));
      }
      const lines: string[] = new Screen(`x`, nodes).describeNodes(3).split('\n');
      expect(lines.length).assertEqual(3);
    });

    it('returns_empty_without_nodes', 0, () => {
      expect(new Screen('only text').describeNodes()).assertEqual('');
    });

    it('finds_a_ref', 0, () => {
      const screen = new Screen('x', [node('e7', 'WLAN', true)]);
      const found = screen.findRef('e7');
      expect(found !== undefined).assertTrue();
      if (found !== undefined) {
        expect(found.text).assertEqual('WLAN');
      }
    });
  });
}
