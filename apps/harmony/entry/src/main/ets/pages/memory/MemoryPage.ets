import { Skill } from '@hopa/core';
import { Context } from '@kit.AbilityKit';
import { AgentService } from '../../services/AgentService';
import { MemoryItem } from '../../services/MemoryStore';

/** Facts and skills: the part of HOPA's memory the user can see and edit. */
@Component
export struct MemoryPage {
  @State section: number = 0;
  @State facts: MemoryItem[] = [];
  @State skills: Skill[] = [];
  @State memoryDraft: string = '';
  @State skillName: string = '';
  @State skillTrigger: string = '';
  @State skillGuidance: string = '';
  @State status: string = '';

  aboutToAppear(): void {
    this.refresh();
  }

  private refresh(): void {
    this.facts = AgentService.get().memory.all().slice();
    this.skills = AgentService.get().skills.all().slice();
  }

  private saveMemory(): void {
    AgentService.get().memory.save(getContext(this) as Context).catch(() => {
      // Persistence is best effort; memory still works in this session.
    });
  }

  private saveSkills(): void {
    AgentService.get().skills.save(getContext(this) as Context).catch(() => {
      // Persistence is best effort.
    });
  }

  private addFact(): void {
    const item: MemoryItem | undefined = AgentService.get().memory.add(this.memoryDraft);
    if (item === undefined) {
      return;
    }
    this.memoryDraft = '';
    this.refresh();
    this.saveMemory();
    this.status = `remembered: ${item.text}`;
  }

  private removeFact(id: string): void {
    if (AgentService.get().memory.remove(id)) {
      this.refresh();
      this.saveMemory();
    }
  }

  private clearFacts(): void {
    AgentService.get().memory.clear();
    this.refresh();
    this.saveMemory();
    this.status = 'cleared all remembered facts';
  }

  private async exportAll(): Promise<void> {
    try {
      const path: string = await AgentService.get().exportData(getContext(this) as Context);
      this.status = `exported to ${path}`;
    } catch (error) {
      this.status = `export failed: ${error}`;
    }
  }

  private addSkill(): void {
    const skill: Skill | undefined = AgentService.get().skills.add(
      this.skillName,
      this.skillTrigger,
      this.skillGuidance
    );
    if (skill === undefined) {
      return;
    }
    this.skillName = '';
    this.skillTrigger = '';
    this.skillGuidance = '';
    this.refresh();
    this.saveSkills();
    this.status = `saved skill "${skill.name}"`;
  }

  private removeSkill(id: string): void {
    if (AgentService.get().skills.remove(id)) {
      this.refresh();
      this.saveSkills();
    }
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Button('Facts')
          .backgroundColor(this.section === 0 ? $r('app.color.primary') : $r('app.color.divider'))
          .fontColor(this.section === 0 ? $r('app.color.on_primary') : $r('app.color.text_primary'))
          .onClick(() => {
            this.section = 0;
          })
        Button('Skills')
          .backgroundColor(this.section === 1 ? $r('app.color.primary') : $r('app.color.divider'))
          .fontColor(this.section === 1 ? $r('app.color.on_primary') : $r('app.color.text_primary'))
          .onClick(() => {
            this.section = 1;
          })
      }
      .width('100%')
      if (this.status.length > 0) {
        Text(this.status)
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
      }
      if (this.section === 0) {
        Column({ space: 12 }) {
          Text('Only what you type here is stored. It is added to HOPA\'s prompt; delete anything you do not want kept.')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
          Row({ space: 8 }) {
            TextInput({ placeholder: 'e.g. I prefer aisle seats', text: this.memoryDraft })
              .layoutWeight(1)
              .onChange((value: string) => {
                this.memoryDraft = value;
              })
              .onSubmit(() => {
                this.addFact();
              })
            Button('Add')
              .onClick(() => {
                this.addFact();
              })
          }
          .width('100%')
          Row({ space: 8 }) {
            Button('Export data')
              .fontSize(12)
              .onClick(() => {
                this.exportAll();
              })
            Button('Clear facts')
              .fontSize(12)
              .backgroundColor($r('app.color.divider'))
              .fontColor($r('app.color.danger'))
              .onClick(() => {
                this.clearFacts();
              })
          }
          .width('100%')
          List({ space: 8 }) {
            ForEach(this.facts, (item: MemoryItem, index: number) => {
              ListItem() {
                Row({ space: 8 }) {
                  Text(item.text)
                    .layoutWeight(1)
                    .fontSize(14)
                  Button('Delete')
                    .fontSize(12)
                    .onClick(() => {
                      this.removeFact(item.id);
                    })
                }
                .width('100%')
                .padding(12)
                .backgroundColor($r('app.color.surface_alt'))
                .borderRadius(8)
              }
            }, (item: MemoryItem) => item.id)
          }
          .layoutWeight(1)
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      } else {
        Column({ space: 10 }) {
          Text('A skill is a procedure HOPA follows when your request contains the trigger words.')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
          TextInput({ placeholder: 'Skill name, e.g. Book a table', text: this.skillName })
            .onChange((value: string) => {
              this.skillName = value;
            })
          TextInput({ placeholder: 'Trigger words, e.g. book a table', text: this.skillTrigger })
            .onChange((value: string) => {
              this.skillTrigger = value;
            })
          TextArea({ placeholder: 'Steps to follow', text: this.skillGuidance })
            .height(90)
            .onChange((value: string) => {
              this.skillGuidance = value;
            })
          Button('Save skill')
            .onClick(() => {
              this.addSkill();
            })
          List({ space: 8 }) {
            ForEach(this.skills, (item: Skill, index: number) => {
              ListItem() {
                Column({ space: 4 }) {
                  Row({ space: 8 }) {
                    Text(item.name)
                      .fontWeight(FontWeight.Bold)
                      .fontSize(14)
                      .layoutWeight(1)
                    Button('Delete')
                      .fontSize(12)
                      .onClick(() => {
                        this.removeSkill(item.id);
                      })
                  }
                  .width('100%')
                  Text(`when: ${item.trigger}`)
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                  Text(`used ${item.uses}, ok ${item.successes}`)
                    .fontSize(11)
                    .fontColor($r('app.color.text_hint'))
                  Text(item.guidance)
                    .fontSize(13)
                    .maxLines(4)
                }
                .width('100%')
                .padding(12)
                .backgroundColor($r('app.color.surface_alt'))
                .borderRadius(8)
                .alignItems(HorizontalAlign.Start)
              }
            }, (item: Skill) => item.id)
          }
          .layoutWeight(1)
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      Text(`Runs recorded: ${AgentService.get().runs.all().length}`)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }
}
