/**
 * One bottom-bar icon, drawn from plain components.
 *
 * ArkUI shapes use their own coordinate space, which made path icons look
 * clipped; sized containers render exactly at the density of the screen.
 */
@Component
export struct TabIcon {
  @Prop kind: string = 'chat';
  @Prop active: boolean = false;

  private color(): ResourceColor {
    return this.active ? $r('app.color.primary') : $r('app.color.text_secondary');
  }

  build() {
    if (this.kind === 'chat') {
      Stack() {
        Column()
          .width(20)
          .height(15)
          .borderRadius(5)
          .backgroundColor(this.color())
          .offset({ y: -1 })
        Row()
          .width(6)
          .height(6)
          .borderRadius(1)
          .backgroundColor(this.color())
          .rotate({ angle: 45 })
          .offset({ x: -6, y: 8 })
      }
      .width(22)
      .height(22)
    } else if (this.kind === 'plans') {
      Column({ space: 3 }) {
        Row().width(16).height(2.6).borderRadius(1.3).backgroundColor(this.color())
        Row().width(11).height(2.6).borderRadius(1.3).backgroundColor(this.color())
        Row().width(14).height(2.6).borderRadius(1.3).backgroundColor(this.color())
      }
      .width(22)
      .height(22)
      .padding({ left: 3 })
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
    } else if (this.kind === 'browser') {
      Column() {
        Row()
          .width(19)
          .height(4)
          .backgroundColor(this.color())
          .borderRadius({ topLeft: 3.5, topRight: 3.5 })
        Column()
          .width(19)
          .height(11)
          .border({ width: 1.7, color: this.color() })
          .borderRadius({ bottomLeft: 3.5, bottomRight: 3.5 })
      }
      .width(22)
      .height(22)
      .justifyContent(FlexAlign.Center)
    } else if (this.kind === 'settings') {
      Column({ space: 4 }) {
        Row({ space: 2 }) {
          Column().width(3.6).height(3.6).borderRadius(1.8).backgroundColor(this.color())
          Row().width(13).height(2.2).borderRadius(1.1).backgroundColor(this.color())
        }
        Row({ space: 2 }) {
          Row().width(7).height(2.2).borderRadius(1.1).backgroundColor(this.color())
          Column().width(3.6).height(3.6).borderRadius(1.8).backgroundColor(this.color())
          Row().width(5).height(2.2).borderRadius(1.1).backgroundColor(this.color())
        }
        Row({ space: 2 }) {
          Column().width(3.6).height(3.6).borderRadius(1.8).backgroundColor(this.color())
          Row().width(13).height(2.2).borderRadius(1.1).backgroundColor(this.color())
        }
      }
      .width(22)
      .height(22)
      .justifyContent(FlexAlign.Center)
    } else {
      Column({ space: 3 }) {
        Row({ space: 3 }) {
          Column().width(7).height(7).borderRadius(2).backgroundColor(this.color())
          Column().width(7).height(7).borderRadius(2).backgroundColor(this.color())
        }
        Row({ space: 3 }) {
          Column().width(7).height(7).borderRadius(2).backgroundColor(this.color())
          Column().width(7).height(7).borderRadius(2).backgroundColor(this.color())
        }
      }
      .width(22)
      .height(22)
      .justifyContent(FlexAlign.Center)
    }
  }
}
