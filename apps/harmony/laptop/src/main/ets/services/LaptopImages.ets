import { ChatSync } from '@hopa/app';
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';

/**
 * Frames uploaded by another device, copied here once.
 *
 * A turn carries `shotId=` (the shared store's id), never a path, because a
 * path inside the phone's sandbox means nothing on this laptop. The bytes are
 * fetched from the bridge on demand and kept by content hash.
 */
export class LaptopImages {
  private sync: ChatSync | undefined = undefined;
  private dir: string = '';
  private known: Map<string, string> = new Map();

  attach(context: common.UIAbilityContext, sync: ChatSync): void {
    this.dir = `${context.filesDir}/images`;
    try {
      if (!fs.accessSync(this.dir)) {
        fs.mkdirSync(this.dir);
      }
    } catch (error) {
      // The download below will fail cleanly if the directory cannot be made.
    }
    this.sync = sync;
  }

  /** The local file for this id, or '' until it is available. */
  path(id: string): string {
    return id.length === 0 ? '' : (this.known.get(id) ?? '');
  }

  /** Fetch every id we do not have yet; true when at least one arrived. */
  async ensure(ids: string[]): Promise<boolean> {
    let changed: boolean = false;
    for (const id of ids) {
      if (id.length === 0 || this.known.has(id)) {
        continue;
      }
      const local: string = `${this.dir}/${id}.jpg`;
      try {
        if (fs.accessSync(local)) {
          this.known.set(id, local);
          changed = true;
          continue;
        }
      } catch (error) {
        // Not cached yet.
      }
      if (this.sync === undefined) {
        continue;
      }
      const data: ArrayBuffer | undefined = await this.sync.downloadImage(id);
      if (data === undefined) {
        continue;
      }
      try {
        const file = fs.openSync(local, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.READ_WRITE);
        fs.writeSync(file.fd, data);
        fs.closeSync(file);
        this.known.set(id, local);
        changed = true;
      } catch (error) {
        // A frame that cannot be written is simply not shown.
      }
    }
    return changed;
  }
}
