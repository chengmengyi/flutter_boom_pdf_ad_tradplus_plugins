# flutter_boom_pdf_ad_tradplus_plugins

TradPlus adapter for `flutter_boom_pdf_ad_core_plugins`, backed by
`tradplus_sdk: ^1.2.8`.

## Registration and initialization

```dart
import 'package:flutter_boom_pdf_ad_core_plugins/flutter_boom_pdf_ad_core_plugins.dart';
import 'package:flutter_boom_pdf_ad_tradplus_plugins/flutter_boom_pdf_ad_tradplus_plugins.dart';

Future<void> initializeAds() async {
  FlutterBoomPdfAdTradplusPlugins.install(
    appId: 'YOUR_TRADPLUS_APP_ID',
  );

  await FlutterPdfAdPlugins.instance.initPlugins(
    distinctId: 'current-user-id',
  );
  await FlutterPdfAdPlugins.instance.initializeNetwork('tradplus');
}
```

The app ID can instead be provided through Core:

```dart
FlutterBoomPdfAdTradplusPlugins.install();
FlutterPdfAdPlugins.instance.configureNetwork(
  'tradplus',
  options: {
    TradplusAdOptions.appId: 'YOUR_TRADPLUS_APP_ID',
  },
);
```

Configure a placement with `adPlat: 'tradplus'`. Core's existing
`loadPlacement`, `showCachedAd`, `buildCachedAdWidget`, and
`takeCachedAdWidget` APIs remain unchanged.

```dart
FlutterPdfAdPlugins.instance.updatePlacementConfig(
  'home_interstitial',
  [
    AdInfoBean(
      adId: 'YOUR_TRADPLUS_AD_UNIT_ID',
      adPlat: 'tradplus',
      adType: 'int',
      sort: 100,
      userGroup: [0],
    ),
  ],
);

await FlutterPdfAdPlugins.instance.loadPlacement('home_interstitial');
await FlutterPdfAdPlugins.instance.showCachedAd(
  'home_interstitial',
  adPosId: 'home_interstitial',
);
```

Supported Core types:

- `open`: TradPlus splash
- `int`: TradPlus interstitial
- `rv`, `raw`, `rwd`: TradPlus rewarded video
- `ban`: TradPlus banner platform view
- `nat`: TradPlus native platform view

Android splash is a platform view, so `showCachedAd` requires a mounted
`BuildContext`. iOS splash uses TradPlus's full-screen show API.

## TradPlus options

Use `configureNetwork('tradplus', options: ...)` before initialization. The
adapter accepts privacy switches, custom segmentation maps, scene IDs,
per-format load maps, template class names, native dimensions, custom ad info,
and initialization/load timeouts through the constants in
`TradplusAdOptions`.

Example:

```dart
FlutterPdfAdPlugins.instance.configureNetwork(
  'tradplus',
  options: {
    TradplusAdOptions.appId: 'YOUR_TRADPLUS_APP_ID',
    TradplusAdOptions.privacyUserAgree: true,
    TradplusAdOptions.openPersonalizedAd: true,
    TradplusAdOptions.customMap: {
      'channel': 'google_play',
    },
    TradplusAdOptions.sceneIds: {
      'home_interstitial': 'YOUR_SCENE_ID',
    },
    TradplusAdOptions.loadTimeout: const Duration(seconds: 20),
  },
);
```

`adInfo.ecpm` received at impression time is converted into Core's paid event.
Set `TradplusAdOptions.emitPaidEventFromEcpm` to `false` if revenue is reported
through another channel.

## Native SDK dependencies

`tradplus_sdk` contains the Flutter bridge. This adapter includes the TradPlus
Android native core required by that bridge. The application must additionally
include the ad-network adapters it enables, following the TradPlus Android/iOS
integration documentation. Only include networks actually configured for the
application.
