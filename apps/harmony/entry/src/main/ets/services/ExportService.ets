import { RunRecord, RunStore, Skill } from '@hopa/core';
import { Context } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { MemoryItem, MemoryStore } from './MemoryStore';
import { SkillStore } from './SkillStore';

class ExportPayload {
  exportedAt: string = '';
  memory: MemoryItem[] = [];
  skills: Skill[] = [];
  runs: RunRecord[] = [];
}

/**
 * Writes memory, skills and runs to one JSON file in the app sandbox.
 * The API key is never included.
 */
export class ExportService {
  private memory: MemoryStore;
  private skills: SkillStore;
  private runs: RunStore;

  constructor(memory: MemoryStore, skills: SkillStore, runs: RunStore) {
    this.memory = memory;
    this.skills = skills;
    this.runs = runs;
  }

  async exportData(context: Context): Promise<string> {
    const payload = new ExportPayload();
    payload.exportedAt = new Date().toISOString();
    payload.memory = this.memory.all();
    payload.skills = this.skills.all();
    payload.runs = this.runs.all();
    const path: string = `${context.filesDir}/hopa-export.json`;
    const file = fileIo.openSync(
      path,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
    );
    try {
      fileIo.writeSync(file.fd, JSON.stringify(payload, null, 2));
    } finally {
      fileIo.closeSync(file);
    }
    return path;
  }
}
