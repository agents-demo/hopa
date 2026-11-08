/** The observed result of executing an action. */
export class Observation {
  success: boolean = false;
  summary: string = '';
  detail: string = '';
  layoutHash: string = '';
  screenshotRef: string = '';

  static ok(summary: string): Observation {
    const observation = new Observation();
    observation.success = true;
    observation.summary = summary;
    return observation;
  }

  static fail(detail: string): Observation {
    const observation = new Observation();
    observation.success = false;
    observation.detail = detail;
    return observation;
  }
}
