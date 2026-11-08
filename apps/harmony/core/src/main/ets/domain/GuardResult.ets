export class GuardResult {
  allowed: boolean;
  reason: string;

  constructor(allowed: boolean, reason: string = '') {
    this.allowed = allowed;
    this.reason = reason;
  }
}
