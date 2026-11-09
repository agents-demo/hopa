import { ChatSession } from '@hopa/core';

/** One labelled block of conversations in the Chats sheet. */
export class ChatSection {
  label: string = '';
  sessions: ChatSession[] = [];
}

const DAY_MS: number = 24 * 60 * 60 * 1000;

/** Chats whose title matches the search text, newest first. */
export function searchSessions(sessions: ChatSession[], query: string): ChatSession[] {
  const needle: string = query.trim().toLowerCase();
  if (needle.length === 0) {
    return sessions.slice();
  }
  const matches: ChatSession[] = [];
  for (const session of sessions) {
    if (session.title.toLowerCase().indexOf(needle) >= 0) {
      matches.push(session);
    }
  }
  return matches;
}

/** Splits the chat list into Today, Previous 7 days and Older. */
export function sectionsOf(sessions: ChatSession[], now: number): ChatSection[] {
  const today: ChatSection = new ChatSection();
  today.label = 'Today';
  const week: ChatSection = new ChatSection();
  week.label = 'Previous 7 days';
  const older: ChatSection = new ChatSection();
  older.label = 'Older';

  const todayStart: number = startOfDay(now);
  const weekStart: number = todayStart - 6 * DAY_MS;
  for (const session of sessions) {
    if (session.updatedAt >= todayStart) {
      today.sessions.push(session);
    } else if (session.updatedAt >= weekStart) {
      week.sessions.push(session);
    } else {
      older.sessions.push(session);
    }
  }

  const sections: ChatSection[] = [];
  for (const section of [today, week, older]) {
    if (section.sessions.length > 0) {
      sections.push(section);
    }
  }
  return sections;
}

function startOfDay(ms: number): number {
  const date: Date = new Date(ms);
  date.setHours(0, 0, 0, 0);
  return date.getTime();
}
