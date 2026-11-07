import { describe, expect, it } from '@ohos/hypium';
import { RiskLevel } from '../main/ets/Types';
import { ToolDescriptor, ToolRegistry } from '../main/ets/ToolRegistry';

export default function toolRegistryTest(): void {
  describe('ToolRegistry', () => {
    it('registers_and_looks_up_tools', 0, () => {
      const registry = new ToolRegistry();
      registry.register(new ToolDescriptor('web.navigate', 'Navigate a page', RiskLevel.Read));

      expect(registry.has('web.navigate')).assertTrue();
      expect(registry.get('web.navigate')?.description).assertEqual('Navigate a page');
      expect(registry.all().length).assertEqual(1);
    });

    it('overwrites_same_name', 0, () => {
      const registry = new ToolRegistry();
      registry.register(new ToolDescriptor('ui.tap', 'Old', RiskLevel.Read));
      registry.register(new ToolDescriptor('ui.tap', 'New', RiskLevel.Read));

      expect(registry.all().length).assertEqual(1);
      expect(registry.get('ui.tap')?.description).assertEqual('New');
    });

    it('clear_removes_all', 0, () => {
      const registry = new ToolRegistry();
      registry.register(new ToolDescriptor('ui.tap', 'Tap', RiskLevel.Read));
      registry.clear();

      expect(registry.all().length).assertEqual(0);
      expect(registry.has('ui.tap')).assertFalse();
    });
  });
}
