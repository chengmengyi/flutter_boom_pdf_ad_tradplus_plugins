import 'dart:async';

import 'package:flutter_boom_pdf_ad_core_plugins/flutter_boom_pdf_ad_core_plugins.dart'
    as core;
import 'package:flutter_boom_pdf_ad_tradplus_plugins/flutter_boom_pdf_ad_tradplus_plugins.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:tradplus_sdk/tradplus_sdk.dart' as tp;

const _adapterChannel = MethodChannel('flutter_boom_pdf_ad_tradplus_plugins');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(tp.TradplusSdk.channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_adapterChannel, null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(tp.TradplusSdk.channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_adapterChannel, null);
  });

  test('adapter supports every Core ad type', () {
    final adapter = FlutterBoomPdfAdTradplusAdapter();
    for (final type in core.AdType.values) {
      expect(adapter.supports(type), isTrue);
    }
  });

  test('invalid config fails without invoking TradPlus', () async {
    final adapter = FlutterBoomPdfAdTradplusAdapter();
    final result = await adapter.load(_request(adUnitId: ''));
    expect(result.ad, isNull);
    expect(result.failureReason, 'invalid-ad-config');
  });

  test('initializes, loads and shows an interstitial', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(tp.TradplusSdk.channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'tp_init':
              scheduleMicrotask(
                () => tp.TPListenerManager.tpMethodCall(
                  'tp_initFinish',
                  <String, dynamic>{'success': true},
                ),
              );
            case 'interstitial_load':
              scheduleMicrotask(
                () => tp.TPListenerManager.tpMethodCall(
                  'interstitial_loaded',
                  <String, dynamic>{
                    'adUnitID': 'unit-id',
                    'adInfo': <String, dynamic>{'networkName': 'Test network'},
                  },
                ),
              );
            case 'interstitial_ready':
              return true;
            case 'interstitial_show':
              scheduleMicrotask(() {
                tp.TPListenerManager.tpMethodCall(
                  'interstitial_impression',
                  <String, dynamic>{
                    'adUnitID': 'unit-id',
                    'adInfo': <String, dynamic>{
                      'networkName': 'Test network',
                      'ecpm': '2.5',
                    },
                  },
                );
                tp.TPListenerManager.tpMethodCall(
                  'interstitial_closed',
                  <String, dynamic>{
                    'adUnitID': 'unit-id',
                    'adInfo': <String, dynamic>{'networkName': 'Test network'},
                  },
                );
              });
          }
          return null;
        });

    final adapter = FlutterBoomPdfAdTradplusAdapter()..setAppId('test-app-id');
    await adapter.initialize();
    final loaded = await adapter.load(_request(adUnitId: 'unit-id'));
    expect(loaded.ad, isNotNull);
    expect(loaded.ad!.adNetwork, 'Test network');

    final events = <core.AdNetworkEvent>[];
    final subscription = loaded.ad!.events.listen(events.add);
    final shown = await loaded.ad!.show();
    expect(shown.shown, isTrue);
    expect(
      events.map((event) => event.type),
      containsAllInOrder(<core.AdNetworkEventType>[
        core.AdNetworkEventType.impression,
        core.AdNetworkEventType.paid,
        core.AdNetworkEventType.closed,
      ]),
    );
    expect(
      calls,
      containsAll(<String>[
        'tp_init',
        'interstitial_load',
        'interstitial_ready',
        'interstitial_show',
      ]),
    );

    await subscription.cancel();
    await loaded.ad!.dispose();
    await adapter.dispose();
  });

  test('auction forwards normalized AdMob price to native call', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(tp.TradplusSdk.channel, (call) async {
          if (call.method == 'interstitial_ready') return true;
          if (call.method == 'interstitial_load') {
            scheduleMicrotask(
              () => tp.TPListenerManager.tpMethodCall(
                'interstitial_loaded',
                <String, dynamic>{
                  'adUnitID': 'auction-unit',
                  'adInfo': <String, dynamic>{
                    'ecpm': '3.0',
                    'adNetworkId': '9',
                  },
                },
              ),
            );
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_adapterChannel, (call) async {
          switch (call.method) {
            case 'getTradplusEstimatedPrice':
              expect(call.arguments['adUnitId'], 'auction-unit');
              return 3.25;
            case 'isTradplusWinner':
              expect(call.arguments['admobPrice'], 2.5);
              expect(call.arguments['tpAdInfo']['ecpm'], '3.0');
              return true;
          }
          return null;
        });

    final adapter = FlutterBoomPdfAdTradplusAdapter();
    final loaded = await adapter.load(_request(adUnitId: 'auction-unit'));
    final candidate = loaded.ad! as core.AdAuctionCandidate;
    final competitor = core.AdInfoBean(
      adId: 'admob-unit',
      adPlat: 'admob',
      adType: 'int',
    );
    final tradplusInfo = core.AdInfoBean(
      adId: 'auction-unit',
      adPlat: 'tradplus',
      adType: 'int',
    );
    final callbacks = <String>[];

    expect(
      await candidate.winsAgainst(
        competitorRevenueMicros: 2.5,
        competitorInfo: competitor,
        candidateInfo: tradplusInfo,
        onBidStart: (admobInfo, tpInfo) =>
            callbacks.add('start:${admobInfo.price}:${tpInfo.price}'),
        onBidOver: (winnerInfo) =>
            callbacks.add('over:${winnerInfo.adPlat}:${winnerInfo.price}'),
      ),
      isTrue,
    );
    expect(competitor.price, 2.5);
    expect(tradplusInfo.price, closeTo(0.00325, 0.000000001));
    expect(callbacks, <String>['start:2.5:0.00325', 'over:tradplus:0.00325']);
    await loaded.ad!.dispose();
    await adapter.dispose();
  });

  test(
    'TradPlus estimated eCPM is converted to per-impression price',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(tp.TradplusSdk.channel, (call) async {
            if (call.method == 'interstitial_ready') return true;
            if (call.method == 'interstitial_load') {
              scheduleMicrotask(
                () => tp.TPListenerManager.tpMethodCall(
                  'interstitial_loaded',
                  <String, dynamic>{
                    'adUnitID': 'price-unit',
                    'adInfo': <String, dynamic>{'ecpm': '5.0'},
                  },
                ),
              );
            }
            return null;
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_adapterChannel, (call) async {
            expect(call.method, 'getTradplusEstimatedPrice');
            expect(call.arguments['adUnitId'], 'price-unit');
            return 6.25;
          });

      final adapter = FlutterBoomPdfAdTradplusAdapter();
      final loaded = await adapter.load(_request(adUnitId: 'price-unit'));
      final candidate = loaded.ad! as core.AdEstimatedRevenueCandidate;

      expect(
        await candidate.getEstimatedRevenueMicros(),
        closeTo(0.00625, 0.000000001),
      );
      await loaded.ad!.dispose();
      await adapter.dispose();
    },
  );

  test('auction forwards zero revenue without applying a fallback', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(tp.TradplusSdk.channel, (call) async {
          if (call.method == 'interstitial_ready') return true;
          if (call.method == 'interstitial_load') {
            scheduleMicrotask(
              () => tp.TPListenerManager.tpMethodCall(
                'interstitial_loaded',
                <String, dynamic>{
                  'adUnitID': 'debug-auction-unit',
                  'adInfo': <String, dynamic>{'ecpm': '3.0'},
                },
              ),
            );
          }
          return null;
        });
    double? receivedAdmobPrice;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_adapterChannel, (call) async {
          if (call.method == 'getTradplusEstimatedPrice') return 4.0;
          receivedAdmobPrice = call.arguments['admobPrice'] as double;
          return false;
        });

    final adapter = FlutterBoomPdfAdTradplusAdapter();
    final loaded = await adapter.load(_request(adUnitId: 'debug-auction-unit'));
    final candidate = loaded.ad! as core.AdAuctionCandidate;
    final admobInfo = core.AdInfoBean(
      adId: 'admob-unit',
      adPlat: 'admob',
      adType: 'int',
    );
    final tradplusInfo = core.AdInfoBean(
      adId: 'debug-auction-unit',
      adPlat: 'tradplus',
      adType: 'int',
    );
    core.AdInfoBean? callbackWinner;
    var didStart = false;

    await candidate.winsAgainst(
      competitorRevenueMicros: 0,
      competitorInfo: admobInfo,
      candidateInfo: tradplusInfo,
      onBidStart: (admob, tradplus) {
        didStart = true;
        expect(admob.price, 0);
        expect(tradplus.price, closeTo(0.004, 0.000000001));
      },
      onBidOver: (winnerInfo) => callbackWinner = winnerInfo,
    );

    expect(receivedAdmobPrice, 0);
    expect(didStart, isTrue);
    expect(callbackWinner, same(admobInfo));
    await loaded.ad!.dispose();
    await adapter.dispose();
  });

  test('enables automatic-load callbacks for every ad type', () async {
    final cases =
        <
          ({
            String adType,
            String loadMethod,
            String loadedMethod,
            String optionKey,
          })
        >[
          (
            adType: 'open',
            loadMethod: 'splash_load',
            loadedMethod: 'splash_loaded',
            optionKey: TradplusAdOptions.splashExtraMap,
          ),
          (
            adType: 'int',
            loadMethod: 'interstitial_load',
            loadedMethod: 'interstitial_loaded',
            optionKey: TradplusAdOptions.interstitialExtraMap,
          ),
          (
            adType: 'rv',
            loadMethod: 'rewardVideo_load',
            loadedMethod: 'rewardVideo_loaded',
            optionKey: TradplusAdOptions.rewardedExtraMap,
          ),
          (
            adType: 'ban',
            loadMethod: 'banner_load',
            loadedMethod: 'banner_loaded',
            optionKey: TradplusAdOptions.bannerExtraMap,
          ),
          (
            adType: 'nat',
            loadMethod: 'native_load',
            loadedMethod: 'native_loaded',
            optionKey: TradplusAdOptions.nativeExtraMap,
          ),
        ];

    for (final adCase in cases) {
      final adUnitId = '${adCase.adType}-unit';
      Map<dynamic, dynamic>? receivedExtraMap;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(tp.TradplusSdk.channel, (call) async {
            if (call.method == adCase.loadMethod) {
              final arguments = call.arguments as Map<dynamic, dynamic>;
              receivedExtraMap = Map<dynamic, dynamic>.from(
                arguments['extraMap'] as Map,
              );
              scheduleMicrotask(
                () => tp.TPListenerManager.tpMethodCall(
                  adCase.loadedMethod,
                  <String, dynamic>{
                    'adUnitID': adUnitId,
                    'adInfo': <String, dynamic>{},
                  },
                ),
              );
            }
            return null;
          });

      final adapter = FlutterBoomPdfAdTradplusAdapter();
      final loaded = await adapter.load(
        core.AdLoadRequest(
          placement: 'home',
          info: core.AdInfoBean(
            adId: adUnitId,
            adPlat: 'tradplus',
            adType: adCase.adType,
          ),
          interstitialLikeNative: false,
          smallTemplateNative: false,
          largeBanner: false,
          networkOptions: <String, Object?>{
            adCase.optionKey: <String, Object?>{
              'customOption': 'kept',
              'openAutoLoadCallback': false,
            },
          },
        ),
      );

      expect(loaded.ad, isNotNull, reason: adCase.adType);
      expect(receivedExtraMap?['customOption'], 'kept', reason: adCase.adType);
      expect(
        receivedExtraMap?['openAutoLoadCallback'],
        isTrue,
        reason: adCase.adType,
      );
      await loaded.ad!.dispose();
      await adapter.dispose();
    }
  });

  test(
    'recovers a loaded splash when the native loaded callback is lost',
    () async {
      var readyChecks = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(tp.TradplusSdk.channel, (call) async {
            switch (call.method) {
              case 'splash_load':
                return null;
              case 'splash_ready':
                readyChecks++;
                return true;
            }
            return null;
          });

      final adapter = FlutterBoomPdfAdTradplusAdapter();
      final loaded = await adapter.load(
        core.AdLoadRequest(
          placement: 'launch',
          info: core.AdInfoBean(
            adId: 'splash-unit',
            adPlat: 'tradplus',
            adType: 'open',
          ),
          interstitialLikeNative: false,
          smallTemplateNative: false,
          largeBanner: false,
          networkOptions: const <String, Object?>{
            TradplusAdOptions.loadTimeout: 2,
          },
        ),
      );

      expect(readyChecks, greaterThan(0));
      expect(loaded.ad, isNotNull);
      expect(loaded.ad!.networkId, 'tradplus');
      await loaded.ad!.dispose();
      await adapter.dispose();
    },
  );
}

core.AdLoadRequest _request({required String adUnitId}) {
  return core.AdLoadRequest(
    placement: 'home',
    info: core.AdInfoBean(adId: adUnitId, adPlat: 'tradplus', adType: 'int'),
    interstitialLikeNative: false,
    smallTemplateNative: false,
    largeBanner: false,
  );
}
