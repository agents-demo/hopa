-- P4: an approval request is a task state, not a second queue.
alter table tasks drop constraint if exists tasks_state_check;
alter table tasks add constraint tasks_state_check check (state in (
    'queued', 'delivered', 'acked', 'progress', 'needs_approval',
    'done', 'failed', 'cancelled'
));
