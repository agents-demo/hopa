import { common } from '@kit.AbilityKit';
import { APP_CATALOG, CatalogApp, SITE_CATALOG, CatalogSite } from '../../services/AppCatalog';
import { AppLauncher } from '../../services/AppLauncher';

/**
 * The app and site catalogue. Only verified bundles are launchable; sites open
 * in the built-in browser through the parent callback.
 */
@Component
export struct AppsPage {
  onOpenSite: (url: string) => void = () => {};

  @State section: number = 0;
  @State status: string = '';

  private async launch(bundle: string, ability: string): Promise<void> {
    const launcher = new AppLauncher(getContext(this) as common.UIAbilityContext);
    const opened: boolean = await launcher.launch(bundle, ability);
    this.status = opened
      ? `opened ${bundle}`
      : `could not open ${bundle}`;
  }

  @Builder
  AppList() {
    List({ space: 8 }) {
      ForEach(APP_CATALOG, (app: CatalogApp, index: number) => {
        ListItem() {
          Column({ space: 2 }) {
            Row({ space: 8 }) {
              Text(app.display)
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .layoutWeight(1)
              if (app.verified && app.ability.length > 0) {
                Button('Open')
                  .fontSize(12)
                  .height(28)
                  .onClick(() => {
                    this.launch(app.bundle, app.ability);
                  })
              }
              Text(app.verified
                ? 'bundle verified'
                : (app.confirmed ? 'bundle unverified' : 'no bundle yet'))
                .fontSize(11)
                .fontColor(app.verified ? '#0A7F3F' : (app.confirmed ? '#B26A00' : '#8A8A8A'))
            }
            .width('100%')
            Text(app.bundle.length > 0 ? app.bundle : 'no HarmonyOS bundle yet')
              .fontSize(12)
              .fontColor('#666666')
            if (app.aliases.length > 0) {
              Text(app.aliases.slice(0, 3).join(', '))
                .fontSize(11)
                .fontColor('#999999')
                .maxLines(1)
            }
          }
          .width('100%')
          .padding(10)
          .backgroundColor('#F7F8FA')
          .borderRadius(8)
          .alignItems(HorizontalAlign.Start)
        }
      }, (app: CatalogApp) => app.name)
    }
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  SiteList() {
    List({ space: 8 }) {
      ForEach(SITE_CATALOG, (site: CatalogSite, index: number) => {
        ListItem() {
          Column({ space: 2 }) {
            Row({ space: 8 }) {
              Text(site.display)
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .layoutWeight(1)
              if (site.domains.length > 0) {
                Button('Open')
                  .fontSize(12)
                  .height(28)
                  .onClick(() => {
                    this.onOpenSite(`https://${site.domains[0]}`);
                  })
              }
            }
            .width('100%')
            Text(site.domains.join(', '))
              .fontSize(12)
              .fontColor('#666666')
            Text(`validated: ${site.validated}`)
              .fontSize(11)
              .fontColor('#999999')
          }
          .width('100%')
          .padding(10)
          .backgroundColor('#F7F8FA')
          .borderRadius(8)
          .alignItems(HorizontalAlign.Start)
        }
      }, (site: CatalogSite) => site.name)
    }
    .layoutWeight(1)
    .width('100%')
  }

  build() {
    Column({ space: 10 }) {
      Text(`Catalogue (${APP_CATALOG.length} apps, ${SITE_CATALOG.length} sites)`)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Row({ space: 8 }) {
        Button(`Apps ${APP_CATALOG.length}`)
          .backgroundColor(this.section === 0 ? '#0A59F7' : '#E5E6E8')
          .fontColor(this.section === 0 ? '#FFFFFF' : '#333333')
          .onClick(() => {
            this.section = 0;
          })
        Button(`Sites ${SITE_CATALOG.length}`)
          .backgroundColor(this.section === 1 ? '#0A59F7' : '#E5E6E8')
          .fontColor(this.section === 1 ? '#FFFFFF' : '#333333')
          .onClick(() => {
            this.section = 1;
          })
      }
      .width('100%')
      Text(this.section === 0
        ? 'Verified bundles can launch. Unverified and unconfirmed names never launch a guessed bundle.'
        : 'Sites open in the built-in browser. Only https pages are allowed.')
        .fontSize(12)
        .fontColor('#666666')
      if (this.status.length > 0) {
        Text(this.status)
          .fontSize(11)
          .fontColor('#666666')
      }
      if (this.section === 0) {
        this.AppList()
      } else {
        this.SiteList()
      }
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }
}
