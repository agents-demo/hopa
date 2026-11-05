import { RiskLevel } from './Types';

export class ToolDescriptor {
  name: string;
  description: string;
  risk: RiskLevel;

  constructor(name: string, description: string, risk: RiskLevel) {
    this.name = name;
    this.description = description;
    this.risk = risk;
  }
}

/** Registry of tools the model may propose. Execution still goes through ActionExecutor. */
export class ToolRegistry {
  private tools: Map<string, ToolDescriptor> = new Map<string, ToolDescriptor>();

  register(tool: ToolDescriptor): void {
    this.tools.set(tool.name, tool);
  }

  get(name: string): ToolDescriptor | undefined {
    return this.tools.get(name);
  }

  has(name: string): boolean {
    return this.tools.has(name);
  }

  all(): ToolDescriptor[] {
    const result: ToolDescriptor[] = [];
    this.tools.forEach((tool: ToolDescriptor) => {
      result.push(tool);
    });
    return result;
  }

  clear(): void {
    this.tools.clear();
  }
}
