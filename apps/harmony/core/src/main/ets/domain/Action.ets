/**
 * A proposed device/browser/system action. The executor owns risk
 * classification; a model never sets `isPayment`.
 */
export class Action {
  id: string;
  kind: string;
  target: string = '';
  text: string = '';
  url: string = '';
  app: string = '';
  x: number = 0;
  y: number = 0;
  toX: number = 0;
  toY: number = 0;
  isPayment: boolean = false;

  constructor(kind: string) {
    this.id = `action-${Date.now()}-${Math.floor(Math.random() * 1000000)}`;
    this.kind = kind;
  }
}
