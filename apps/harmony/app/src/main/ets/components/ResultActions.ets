/** Icon actions for the latest answer: copy, share, bookmark, open. */
@Component
export struct ResultActions {
  @Prop showOpen: boolean = false;
  @State pressed: number = -1;
  onOpen: () => void = () => {};
  onCopy: () => void = () => {};
  onShare: () => void = () => {};
  onRemember: () => void = () => {};

  private tint(): ResourceColor {
    return $r('app.color.text_secondary');
  }

  @Builder
  CopyIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width(8)
        .height(10)
        .border({ width: 1.3, color: this.tint() })
        .borderRadius(2)
        .offset({ x: 3, y: 3 })
      Column()
        .width(8)
        .height(10)
        .border({ width: 1.3, color: this.tint() })
        .borderRadius(2)
        .backgroundColor($r('app.color.bg'))
    }
    .width(14)
    .height(14)
  }

  @Builder
  ShareIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width(11)
        .height(7)
        .border({ width: 1.3, color: this.tint() })
        .borderRadius(2)
        .offset({ x: 1.5, y: 7 })
      Column()
        .width(1.3)
        .height(8)
        .backgroundColor(this.tint())
        .offset({ x: 6.3, y: 0.5 })
      Column()
        .width(4)
        .height(4)
        .backgroundColor(this.tint())
        .rotate({ angle: 45 })
        .offset({ x: 4.9, y: 0 })
    }
    .width(14)
    .height(14)
  }

  @Builder
  BookmarkIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width(9)
        .height(12)
        .border({ width: 1.3, color: this.tint() })
        .borderRadius(1.5)
        .offset({ x: 2.5, y: 1 })
      // Ribbon notch: the page background cuts into the lower edge.
      Column()
        .width(4.4)
        .height(4.4)
        .backgroundColor($r('app.color.bg'))
        .rotate({ angle: 45 })
        .offset({ x: 4.8, y: 10 })
    }
    .width(14)
    .height(14)
  }

  @Builder
  OpenIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width(9)
        .height(9)
        .border({ width: 1.3, color: this.tint() })
        .borderRadius(2)
        .offset({ x: 1, y: 4 })
      Column()
        .width(1.3)
        .height(7)
        .backgroundColor(this.tint())
        .rotate({ angle: -45 })
        .offset({ x: 7.4, y: 1.5 })
      Column()
        .width(4)
        .height(4)
        .backgroundColor(this.tint())
        .rotate({ angle: 45 })
        .offset({ x: 8, y: 0 })
    }
    .width(14)
    .height(14)
  }

  build() {
    Row({ space: 2 }) {
      if (this.showOpen) {
        Row() {
          this.OpenIcon()
        }
        .width(30)
        .height(30)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .accessibilityText('Open')
        .onClick(() => {
          this.onOpen();
        })
      }
      Row() {
        this.CopyIcon()
      }
      .width(30)
      .height(30)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .accessibilityText('Copy')
      .onClick(() => {
        this.onCopy();
      })
      Row() {
        this.ShareIcon()
      }
      .width(30)
      .height(30)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .accessibilityText('Share')
      .onClick(() => {
        this.onShare();
      })
      Row() {
        this.BookmarkIcon()
      }
      .width(30)
      .height(30)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .accessibilityText('Remember')
      .onClick(() => {
        this.onRemember();
      })
    }
    .width('100%')
    .padding({ left: 2, top: 2 })
  }
}
