import { describe, expect, it } from '@ohos/hypium';
import { Action } from '../main/ets/Types';
import { Screen, ScreenNode } from '../main/ets/domain/Screen';
import { ApprovalDescription } from '../main/ets/gate/ApprovalDescription';

function names(): Map<string, string> {
  const map = new Map<string, string>();
  map.set('com.huawei.hmos.settings', 'Settings');
  return map;
}

function screenWith(ref: string, text: string, type: string): Screen {
  const node = new ScreenNode();
  node.ref = ref;
  node.text = text;
  node.type = type;
  return new Screen('', [node]);
}

export default function approvalDescriptionTest(): void {
  describe('ApprovalDescription', () => {
    it('names_a_launched_app', 0, () => {
      const action = new Action('ui.launch');
      action.app = 'com.huawei.hmos.settings';
      const title: string = ApprovalDescription.title(action, undefined, names());
      const body: string = ApprovalDescription.body(action, undefined, names());
      expect(title).assertEqual('Open Settings?');
      expect(body.includes('Settings')).assertTrue();
      expect(body.includes('ui.launch')).assertFalse();
    });

    it('uses_the_visible_label_of_a_tap_target', 0, () => {
      const action = new Action('ui.tap');
      action.target = 'e8';
      const screen = screenWith('e8', 'Send', 'Button');
      const title: string = ApprovalDescription.title(action, screen, names());
      const body: string = ApprovalDescription.body(action, screen, names());
      expect(title).assertEqual('Send this message?');
      expect(body.includes('Send')).assertTrue();
      expect(body.includes('e8')).assertFalse();
    });

    it('names_a_delete_action', 0, () => {
      const action = new Action('system.delete');
      const title: string = ApprovalDescription.title(action, undefined, names());
      const body: string = ApprovalDescription.body(action, undefined, names());
      expect(title).assertEqual('Delete this?');
      expect(body.toLowerCase().includes('delete')).assertTrue();
    });

    it('shows_the_text_that_will_be_typed', 0, () => {
      const action = new Action('ui.type');
      action.target = 'e9';
      action.text = 'running 10 minutes late';
      const screen = screenWith('e9', '', 'TextInput');
      const body: string = ApprovalDescription.body(action, screen, names());
      expect(body.includes('running 10 minutes late')).assertTrue();
      expect(body.includes('e9')).assertFalse();
    });

    it('shows_a_navigation_url', 0, () => {
      const action = new Action('web.navigate');
      action.url = 'https://bilibili.com';
      const title: string = ApprovalDescription.title(action, undefined, names());
      const body: string = ApprovalDescription.body(action, undefined, names());
      expect(title).assertEqual('Open this page?');
      expect(body.includes('https://bilibili.com')).assertTrue();
      expect(body.includes('web.navigate')).assertFalse();
    });

    it('names_a_message_action', 0, () => {
      const action = new Action('ui.sendMessage');
      action.target = 'Alice';
      action.text = 'running late';
      const title: string = ApprovalDescription.title(action, undefined, names());
      const body: string = ApprovalDescription.body(action, undefined, names());
      expect(title).assertEqual('Send this message?');
      expect(body.includes('Alice')).assertTrue();
      expect(body.includes('running late')).assertTrue();
    });
  });
}
