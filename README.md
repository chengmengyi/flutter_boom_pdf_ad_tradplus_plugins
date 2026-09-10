# flutter_boom_pdf_ad_tradplus_plugins

TradPlus adapter for `flutter_boom_pdf_ad_core_plugins`, backed by
`tradplus_sdk: ^1.2.8`.

The Android adapter supplies Gson `2.10.1`, which TP Exchange/Adx needs for
bidding payload parsing but does not declare transitively. The host App does
not need to add Gson separately.

## Registration and initialization

```dart
import 'package:flutter_boom_pdf_ad_core_plugins/flutter_boom_pdf_ad_core_plugins.dart';
import 'package:flutter_boom_pdf_ad_tradplus_plugins/flutter_boom_pdf_ad_tradplus_plugins.dart';

Future<void> initializeAds() async {
  FlutterBoomPdfAdTradplusPlugins.install(
    appId: 'YOUR_TRADPLUS_APP_ID',
    smallNativeAdLayoutName: 'tradplus_small_native_ad',
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
FlutterPdfAdPlugins.instance.updateConfigs<String>(
  {
    'home_interstitial': [
      AdInfoBean(
        adId: 'YOUR_TRADPLUS_AD_UNIT_ID',
        adPlat: 'tradplus',
        adType: 'int',
        sort: 100,
        userGroup: [0],
      ),
    ],
  },
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

`smallNativeAdLayoutName` is a TradPlus-only Android XML layout. At minimum it
must define `tp_native_title`, `tp_native_text`, `tp_native_cta_btn`,
`tp_native_icon_image`, and `tp_ad_choices_container`. AdMob native layouts
cannot be reused because their required view IDs are different.

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

The estimated price returned for cache auctioning is eCPM. The adapter divides
it by `1000` before assigning it to `AdInfoBean.price`, so it uses the same
per-impression comparison unit as AdMob.

## Native SDK dependencies

`tradplus_sdk` contains the Flutter bridge. This adapter includes the TradPlus
Android native core required by that bridge. The application must additionally
include the ad-network adapters it enables, following the TradPlus Android/iOS
integration documentation. Only include networks actually configured for the
application.
