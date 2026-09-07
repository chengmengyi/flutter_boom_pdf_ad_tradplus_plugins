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

  test('auction converts AdMob micros to revenue before native call', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(tp.TradplusSdk.channel, (call) async {
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
          expect(call.method, 'isTradplusWinner');
          expect(call.arguments['admobPrice'], 2.5);
          expect(call.arguments['tpAdInfo']['ecpm'], '3.0');
          return true;
        });

    final adapter = FlutterBoomPdfAdTradplusAdapter();
    final loaded = await adapter.load(_request(adUnitId: 'auction-unit'));
    final candidate = loaded.ad! as core.AdAuctionCandidate;

    expect(
      await candidate.winsAgainst(competitorRevenueMicros: 2500000),
      isTrue,
    );
    await loaded.ad!.dispose();
    await adapter.dispose();
  });
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
