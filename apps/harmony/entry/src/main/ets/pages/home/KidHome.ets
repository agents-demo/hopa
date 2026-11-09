import { StyleProfile } from '../../services/StyleProfile';
import { HopaMark } from '../chat/HopaMark';

/** Alpha home: four big picture tiles, no settings in sight. */
@Component
export struct KidHome {
  onOpenChat: (goal: string, voice: boolean) => void = () => {};
  onOpenSettings: () => void = () => {};
  @StorageLink('hopa.style') styleName: string = 'vivid';
  @StorageLink('hopa.accent') accentColor: string = '';

  private style(): StyleProfile {
    return StyleProfile.of(this.styleName);
  }

  private accent(): ResourceColor {
    return this.accentColor.length > 0 ? this.accentColor : $r('app.color.primary');
  }

  @Builder
  BigTile(icon: string, label: string, goal: string, voice: boolean) {
    Column({ space: 6 }) {
      Text(icon)
        .fontSize(40)
      Text(label)
        .fontSize(this.style().body)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
    }
    .layoutWeight(1)
    .height(120)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.divider') })
    .borderRadius(this.style().cardRadius)
    .onClick(() => {
      this.onOpenChat(goal, voice);
    })
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 6 }) {
        HopaMark({ state: 'idle', markSize: 96, animate: true })
        Text('What shall we do?')
          .fontSize(this.style().title - 4)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ top: 18 })

      Row({ space: 12 }) {
        this.BigTile('🎤', 'Talk', '', true)
        this.BigTile('📷', 'Photos', 'Open my photos', false)
      }
      .width('100%')
      Row({ space: 12 }) {
        this.BigTile('🎵', 'Music', 'Play some music', false)
        this.BigTile('🎨', 'Draw', 'Open my notes so I can draw', false)
      }
      .width('100%')

      Blank()
      Text('A grown-up can tap here for Settings.')
        .fontSize(10)
        .fontColor($r('app.color.text_hint'))
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding(8)
        .onClick(() => {
          this.onOpenSettings();
        })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 18, right: 18, top: 10, bottom: 20 })
    .alignItems(HorizontalAlign.Center)
  }
}
