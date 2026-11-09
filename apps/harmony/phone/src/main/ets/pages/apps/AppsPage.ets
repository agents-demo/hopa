import { common } from '@kit.AbilityKit';
import { APP_CATALOG, CatalogApp, SITE_CATALOG, CatalogSite } from '../../services/AppCatalog';
import { AppLauncher } from '../../services/AppLauncher';

/**
 * The app and site catalogue as a searchable list.
 *
 * A row is an app or a site; tapping an app opens it, tapping a site opens it
 * in the built-in browser. The status is a small dot + word, not a bundle dump.
 */
@Component
export struct AppsPage {
  onOpenSite: (url: string) => void = () => {};

  @State section: number = 0;
  @State query: string = '';
  @State status: string = '';

  private matches(text: string, needle: string): boolean {
    return text.toLowerCase().indexOf(needle) >= 0;
  }

  private apps(): CatalogApp[] {
    const needle: string = this.query.trim().toLowerCase();
    if (needle.length === 0) {
      return APP_CATALOG;
    }
    const result: CatalogApp[] = [];
    for (const app of APP_CATALOG) {
      let hit: boolean = this.matches(app.display, needle) || this.matches(app.name, needle);
      for (const alias of app.aliases) {
        if (this.matches(alias, needle)) {
          hit = true;
        }
      }
      if (hit) {
        result.push(app);
      }
    }
    return result;
  }

  private sites(): CatalogSite[] {
    const needle: string = this.query.trim().toLowerCase();
    if (needle.length === 0) {
      return SITE_CATALOG;
    }
    const result: CatalogSite[] = [];
    for (const site of SITE_CATALOG) {
      let hit: boolean = this.matches(site.display, needle) || this.matches(site.name, needle);
      for (const domain of site.domains) {
        if (this.matches(domain, needle)) {
          hit = true;
        }
      }
      for (const alias of site.aliases) {
        if (this.matches(alias, needle)) {
          hit = true;
        }
      }
      if (hit) {
        result.push(site);
      }
    }
    return result;
  }

  private monogram(text: string): string {
    return text.length > 0 ? text.substring(0, 1).toUpperCase() : '?';
  }

  private async openApp(app: CatalogApp): Promise<void> {
    if (app.bundle.length === 0) {
      return;
    }
    const launcher = new AppLauncher(getContext(this) as common.UIAbilityContext);
    const opened: boolean = await launcher.launch(app.bundle, app.ability);
    this.status = opened
      ? `Opened ${app.display}.`
      : `Couldn't open ${app.display}: ${launcher.lastFailure()}`;
  }

  @Builder
  Segment(label: string, count: number, index: number) {
    Text(`${label}  ${count}`)
      .fontSize(13)
      .fontWeight(this.section === index ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.section === index
        ? $r('app.color.text_primary')
        : $r('app.color.text_secondary'))
      .textAlign(TextAlign.Center)
      .height(32)
      .layoutWeight(1)
      .backgroundColor(this.section === index ? $r('app.color.surface') : Color.Transparent)
      .borderRadius(8)
      .onClick(() => {
        this.section = index;
        this.status = '';
      })
  }

  @Builder
  StatusDot(verified: boolean, confirmed: boolean) {
    Row({ space: 4 }) {
      Column()
        .width(6)
        .height(6)
        .borderRadius(3)
        .backgroundColor(verified
          ? $r('app.color.success')
          : (confirmed ? $r('app.color.warning') : $r('app.color.text_hint')))
      Text(verified ? 'Verified' : (confirmed ? 'Unverified' : 'No app bundle'))
        .fontSize(10)
        .fontColor(verified
          ? $r('app.color.success')
          : (confirmed ? $r('app.color.warning') : $r('app.color.text_hint')))
    }
  }

  @Builder
  AppRow(app: CatalogApp) {
    Row({ space: 10 }) {
      Text(this.monogram(app.display))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.primary'))
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.primary_soft'))
        .borderRadius(10)
      Column({ space: 3 }) {
        Text(app.display)
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(app.purpose.length > 0 ? app.purpose : app.name)
          .fontSize(11)
          .fontColor($r('app.color.text_hint'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        this.StatusDot(app.verified, app.confirmed)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (app.bundle.length > 0) {
        Text('›')
          .fontSize(17)
          .fontColor($r('app.color.text_hint'))
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.divider') })
    .borderRadius(12)
    .onClick(() => {
      this.openApp(app);
    })
  }

  @Builder
  SiteRow(site: CatalogSite) {
    Row({ space: 10 }) {
      Text(this.monogram(site.display))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.surface_muted'))
        .borderRadius(10)
      Column({ space: 3 }) {
        Text(site.display)
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(site.domains.join(' · '))
          .fontSize(11)
          .fontColor($r('app.color.text_hint'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('›')
        .fontSize(17)
        .fontColor($r('app.color.text_hint'))
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.divider') })
    .borderRadius(12)
    .onClick(() => {
      if (site.domains.length > 0) {
        this.onOpenSite(`https://${site.domains[0]}`);
      }
    })
  }

  @Builder
  Empty() {
    Text(`Nothing matches “${this.query.trim()}”.`)
      .fontSize(12)
      .fontColor($r('app.color.text_hint'))
      .width('100%')
      .padding({ left: 4, top: 12 })
  }

  build() {
    Column({ space: 10 }) {
      Row({ space: 2 }) {
        this.Segment('Apps', APP_CATALOG.length, 0)
        this.Segment('Sites', SITE_CATALOG.length, 1)
      }
      .width('100%')
      .padding(3)
      .backgroundColor($r('app.color.surface_muted'))
      .borderRadius(11)
      TextInput({ placeholder: 'Search apps and sites', text: this.query })
        .height(38)
        .fontSize(13)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(10)
        .placeholderColor($r('app.color.text_hint'))
        .onChange((value: string) => {
          this.query = value;
        })
      if (this.status.length > 0) {
        Text(this.status)
          .fontSize(11)
          .fontColor(this.status.indexOf('Couldn') === 0
            ? $r('app.color.danger')
            : $r('app.color.text_secondary'))
          .width('100%')
          .maxLines(2)
      }
      if (this.section === 0) {
        List({ space: 6 }) {
          ForEach(this.apps(), (app: CatalogApp) => {
            ListItem() {
              this.AppRow(app)
            }
          }, (app: CatalogApp) => app.name)
          if (this.apps().length === 0) {
            ListItem() {
              this.Empty()
            }
          }
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      } else {
        List({ space: 6 }) {
          ForEach(this.sites(), (site: CatalogSite) => {
            ListItem() {
              this.SiteRow(site)
            }
          }, (site: CatalogSite) => site.name)
          if (this.sites().length === 0) {
            ListItem() {
              this.Empty()
            }
          }
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
  }
}
