import { APP_CATALOG, CatalogApp } from '../../services/AppCatalog';

/** The launch policy: only verified bundles. */
@Component
export struct AppAccessPage {
  private verifiedApps(): CatalogApp[] {
    const apps: CatalogApp[] = [];
    for (const app of APP_CATALOG) {
      if (app.verified) {
        apps.push(app);
      }
    }
    return apps;
  }

  build() {
    Column({ space: 10 }) {
      Text('Verified bundles open from the Apps tab.')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
      Text('A confirmed bundle without a device check may still be tried by the agent. Unconfirmed catalogue entries never launch a guessed bundle. This is the app access policy; there is no per-app toggle.')
        .fontSize(12)
        .fontColor('#666666')
      List({ space: 6 }) {
        ForEach(this.verifiedApps(), (app: CatalogApp, index: number) => {
          ListItem() {
            Column({ space: 2 }) {
              Text(app.display)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
              Text(app.bundle)
                .fontSize(11)
                .fontColor('#666666')
              Text(`ability: ${app.ability.length > 0 ? app.ability : 'unknown'}`)
                .fontSize(10)
                .fontColor('#999999')
            }
            .width('100%')
            .padding(10)
            .backgroundColor('#F7F8FA')
            .borderRadius(8)
            .alignItems(HorizontalAlign.Start)
          }
        }, (app: CatalogApp, index: number) => app.bundle)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
