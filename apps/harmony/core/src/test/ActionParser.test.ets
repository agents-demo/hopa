import { describe, expect, it } from '@ohos/hypium';
import { Action } from '../main/ets/Types';
import { ActionParser } from '../main/ets/agent/ActionParser';

export default function actionParserTest(): void {
  describe('ActionParser', () => {
    it('parses_a_bare_action', 0, () => {
      const action: Action | undefined =
        ActionParser.parse('{"kind":"web.navigate","url":"https://example.com"}');
      expect(action === undefined).assertFalse();
      expect(action?.kind).assertEqual('web.navigate');
      expect(action?.url).assertEqual('https://example.com');
    });

    it('parses_an_action_after_prose', 0, () => {
      const action: Action | undefined = ActionParser.parse(
        'I will open the site.\n{"kind":"web.navigate","url":"https://bilibili.com"}'
      );
      expect(action === undefined).assertFalse();
      expect(action?.kind).assertEqual('web.navigate');
      expect(action?.url).assertEqual('https://bilibili.com');
    });

    it('parses_an_action_in_a_code_fence', 0, () => {
      const action: Action | undefined =
        ActionParser.parse('```json\n{"kind":"web.read"}\n```');
      expect(action === undefined).assertFalse();
      expect(action?.kind).assertEqual('web.read');
    });

    it('keeps_plain_text_as_an_answer', 0, () => {
      const action: Action | undefined =
        ActionParser.parse('The page title is "Example Domain".');
      expect(action === undefined).assertTrue();
    });

    it('ignores_json_without_a_known_kind', 0, () => {
      const action: Action | undefined =
        ActionParser.parse('Here is the shape: {"kind":"example.value"}');
      expect(action === undefined).assertTrue();
    });

    it('treats_finish_as_an_answer', 0, () => {
      const action: Action | undefined = ActionParser.parse('{"kind":"finish"}');
      expect(action === undefined).assertTrue();
    });
  });
}
