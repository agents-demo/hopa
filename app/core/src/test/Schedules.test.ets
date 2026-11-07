import { describe, expect, it } from '@ohos/hypium';
import { ScheduleBook, ScheduledTask } from '../main/ets/Schedules';

export default function schedulesTest(): void {
  describe('ScheduleBook', () => {
    it('adds_a_repeating_task', 0, () => {
      const book = new ScheduleBook();
      const task = book.add('check the weather', 60000, 1000);
      expect(task !== undefined).assertTrue();
      expect(book.size()).assertEqual(1);
      if (task !== undefined) {
        expect(task.nextRunAt).assertEqual(61000);
        expect(task.label()).assertEqual('every 1 min');
      }
    });

    it('rejects_an_empty_goal', 0, () => {
      expect(new ScheduleBook().add('   ', 60000, 1000) === undefined).assertTrue();
    });

    it('is_not_due_before_time', 0, () => {
      const book = new ScheduleBook();
      book.add('later', 60000, 1000);
      expect(book.nextDue(2000) === undefined).assertTrue();
      expect(book.nextDue(61000) !== undefined).assertTrue();
    });

    it('repeats_and_moves_the_next_run', 0, () => {
      const book = new ScheduleBook();
      const task = book.add('repeat', 60000, 0);
      expect(task !== undefined).assertTrue();
      if (task !== undefined) {
        book.markRan(task.id, 61000);
        expect(task.enabled).assertTrue();
        expect(task.nextRunAt).assertEqual(121000);
        expect(task.lastRunAt).assertEqual(61000);
      }
    });

    it('disables_a_one_shot_after_it_runs', 0, () => {
      const book = new ScheduleBook();
      const task = book.add('once', 0, 0, 5000);
      expect(task !== undefined).assertTrue();
      if (task !== undefined) {
        book.markRan(task.id, 5000);
        expect(task.enabled).assertFalse();
        expect(book.nextDueInMs(6000)).assertEqual(-1);
      }
    });

    it('removes_a_task', 0, () => {
      const book = new ScheduleBook();
      const task = book.add('x', 60000, 0);
      expect(task !== undefined).assertTrue();
      if (task !== undefined) {
        expect(book.remove(task.id)).assertTrue();
        expect(book.size()).assertEqual(0);
      }
    });

    it('reports_the_nearest_due_task', 0, () => {
      const book = new ScheduleBook();
      book.add('a', 60000, 0);
      book.add('b', 10000, 0);
      expect(book.nextDueInMs(0)).assertEqual(10000);
    });

    it('round_trips_json', 0, () => {
      const book = new ScheduleBook();
      book.add('persist me', 300000, 1000);
      const copy: ScheduleBook = ScheduleBook.fromJson(book.toJson());
      expect(copy.size()).assertEqual(1);
      const item: ScheduledTask | undefined = copy.all()[0];
      expect(item !== undefined).assertTrue();
      if (item !== undefined) {
        expect(item.goal).assertEqual('persist me');
        expect(item.intervalMs).assertEqual(300000);
      }
    });

    it('survives_bad_json', 0, () => {
      expect(ScheduleBook.fromJson('not json').size()).assertEqual(0);
      expect(ScheduleBook.fromJson('').size()).assertEqual(0);
    });
  });
}
