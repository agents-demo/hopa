import { Skill } from '@hopa/core';
import { AgentService } from '../../services/AgentService';
import { ModeProfile } from '../../services/ModeProfile';

/** Personal skills: a trigger phrase, the guidance behind it, and a score. */
@Component
export struct SkillsPage {
  @StorageLink('hopa.profile') profileName: string = 'everyday';

  private skills(): Skill[] {
    return AgentService.get().skills.all();
  }

  private modeNote(): string {
    const name: string = ModeProfile.of(this.profileName).name;
    if (name === 'power') {
      return 'Power: triggers work as short commands.';
    }
    if (name === 'social') {
      return 'Social: triggers can be short handles.';
    }
    return 'Say the trigger and HOPA follows the guidance.';
  }

  private use(trigger: string): void {
    AppStorage.setOrCreate<string>('hopa.pendingGoal', trigger);
    AppStorage.setOrCreate<string>('hopa.goto', 'chat');
  }

  build() {
    Scroll() {
      Column({ space: 10 }) {
        Text(this.modeNote())
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')

        if (this.skills().length === 0) {
          Column({ space: 6 }) {
            Text('No personal skills yet.')
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
            Text('A skill is a trigger phrase plus one sentence of guidance. HOPA learns one when you say "remember how to ...".')
              .fontSize(11.5)
              .lineHeight(17)
              .fontColor($r('app.color.text_hint'))
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(14)
          .alignItems(HorizontalAlign.Start)
        } else {
          ForEach(this.skills(), (skill: Skill) => {
            Column({ space: 5 }) {
              Row({ space: 8 }) {
                Text(skill.name)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Text('Use')
                  .fontSize(10.5)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.primary'))
                  .padding({ left: 9, right: 9, top: 4, bottom: 4 })
                  .backgroundColor($r('app.color.primary_soft'))
                  .borderRadius(8)
                  .onClick(() => {
                    this.use(skill.trigger);
                  })
              }
              .width('100%')
              Text(`“${skill.trigger}”`)
                .fontSize(11)
                .fontColor($r('app.color.primary'))
              Text(skill.guidance)
                .fontSize(11.5)
                .lineHeight(17)
                .fontColor($r('app.color.text_secondary'))
                .maxLines(3)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(`${skill.uses} used · ${skill.successes} worked`)
                .fontSize(9.5)
                .fontColor($r('app.color.text_hint'))
            }
            .width('100%')
            .padding(12)
            .backgroundColor($r('app.color.surface'))
            .border({ width: 1, color: $r('app.color.divider') })
            .borderRadius(14)
            .alignItems(HorizontalAlign.Start)
          }, (skill: Skill) => skill.id)
        }
      }
      .width('100%')
      .padding(20)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
