import { describe, expect, it } from '@ohos/hypium';
import { ChatHistory, ChatSession } from '../main/ets/ChatHistory';

export default function chatHistoryTest(): void {
  describe('ChatHistory', () => {
    it('creates_the_first_conversation', 0, () => {
      const history = new ChatHistory();
      const session = history.ensureCurrent(1000);
      expect(history.all().length).assertEqual(1);
      expect(session.title).assertEqual('New chat');
      expect(history.currentId()).assertEqual(session.id);
    });

    it('titles_from_the_first_user_message', 0, () => {
      const history = new ChatHistory();
      history.add('user', 'Open Settings and turn on Wi-Fi', 2000);
      const session = history.current();
      expect(session !== undefined).assertTrue();
      if (session !== undefined) {
        expect(session.title).assertEqual('Open Settings and turn on Wi-Fi');
        expect(session.entries.length).assertEqual(1);
      }
    });

    it('truncates_a_long_title', 0, () => {
      const history = new ChatHistory();
      history.add('user', 'a'.repeat(80), 1);
      const session = history.current();
      expect(session !== undefined).assertTrue();
      if (session !== undefined) {
        expect(session.title.length).assertEqual(43);
      }
    });

    it('adds_assistant_entries', 0, () => {
      const history = new ChatHistory();
      history.add('user', 'hi', 1);
      history.add('assistant', 'hello', 2);
      const session = history.current();
      expect(session !== undefined).assertTrue();
      if (session !== undefined) {
        expect(session.entries.length).assertEqual(2);
        expect(session.entries[1].role).assertEqual('assistant');
      }
    });

    it('rejects_empty_text', 0, () => {
      const history = new ChatHistory();
      expect(history.add('user', '   ', 1)).assertFalse();
    });

    it('starts_a_new_conversation', 0, () => {
      const history = new ChatHistory();
      history.add('user', 'first', 1);
      const second: ChatSession = history.newSession(2);
      expect(history.all().length).assertEqual(2);
      expect(history.currentId()).assertEqual(second.id);
      history.add('user', 'second', 3);
      expect(history.currentId()).assertEqual(second.id);
    });

    it('selects_an_older_conversation', 0, () => {
      const history = new ChatHistory();
      const first: ChatSession = history.newSession(1);
      history.add('user', 'old', 2);
      const second: ChatSession = history.newSession(3);
      history.add('user', 'new', 4);
      expect(history.select(first.id)).assertTrue();
      const current = history.current();
      expect(current !== undefined).assertTrue();
      if (current !== undefined) {
        expect(current.entries[0].text).assertEqual('old');
      }
      expect(history.currentId()).assertEqual(first.id);
      expect(second.id === first.id).assertFalse();
    });

    it('removes_a_conversation', 0, () => {
      const history = new ChatHistory();
      history.add('user', 'x', 1);
      const id: string = history.currentId();
      expect(history.remove(id)).assertTrue();
      expect(history.all().length).assertEqual(0);
      expect(history.currentId()).assertEqual('');
    });

    it('round_trips_json', 0, () => {
      const history = new ChatHistory();
      history.add('user', 'persist me', 10);
      history.add('assistant', 'saved', 11);
      const copy: ChatHistory = ChatHistory.fromJson(history.toJson());
      expect(copy.all().length).assertEqual(1);
      const session = copy.current();
      expect(session !== undefined).assertTrue();
      if (session !== undefined) {
        expect(session.title).assertEqual('persist me');
        expect(session.entries.length).assertEqual(2);
        expect(session.entries[1].text).assertEqual('saved');
      }
    });

    it('survives_bad_json', 0, () => {
      expect(ChatHistory.fromJson('nope').all().length).assertEqual(0);
      expect(ChatHistory.fromJson('').all().length).assertEqual(0);
    });
  });
}
