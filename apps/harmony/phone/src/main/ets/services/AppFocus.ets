/**
 * Whether HOPA's own window is in front.
 *
 * The PC bridge can see HOPA's own UI, which made the loop type into its own
 * composer and screenshot itself. Lifecycle callbacks are the reliable signal;
 * they also stay correct when the front-app query is slow or stale.
 */
export class AppFocus {
  static active: boolean = true;
}
