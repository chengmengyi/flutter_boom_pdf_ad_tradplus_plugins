import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_boom_pdf_ad_core_plugins/flutter_boom_pdf_ad_core_plugins.dart'
    as core;
import 'package:tradplus_sdk/tradplus_sdk.dart' as tp;

import 'flutter_boom_pdf_ad_tradplus_plugins_platform_interface.dart';

/// Installs the TradPlus implementation into the provider-neutral ad Core.
class FlutterBoomPdfAdTradplusPlugins {
  FlutterBoomPdfAdTradplusPlugins();

  static final FlutterBoomPdfAdTradplusAdapter adapter =
      FlutterBoomPdfAdTradplusAdapter();

  /// [appId] may be supplied here or through
  /// `core.configureNetwork('tradplus', options: {'appId': '...'})`.
  static void install({String? appId, core.FlutterBoomPdfAdCorePlugins? into}) {
    adapter.setAppId(appId);
    (into ?? core.FlutterBoomPdfAdCorePlugins.instance).registerAdapter(
      adapter,
    );
  }

  Future<String?> getPlatformVersion() =>
      FlutterBoomPdfAdTradplusPluginsPlatform.instance.getPlatformVersion();

  static Future<bool?> isTradplusWinner({
    required double admobPrice,
    required Map<dynamic, dynamic> tpAdInfo,
  }) async {
    if (kDebugMode) {
      debugPrint('isTradplusWinner --->admobPrice=$admobPrice');
    }
    try {
      final tpWins = await FlutterBoomPdfAdTradplusPluginsPlatform.instance
          .isTradplusWinner(
            admobPrice: admobPrice,
            tpAdInfo: tpAdInfo.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          );
      if (kDebugMode) {
        final winner = tpWins == null
            ? 'unknown'
            : tpWins
            ? 'tradplus'
            : 'admob';
        debugPrint(
          'isTradplusWinner --->admobPrice=$admobPrice--->winner=$winner',
        );
      }
      return tpWins;
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'isTradplusWinner fail --->admobPrice=$admobPrice'
          '--->reason=$error',
        );
      }
      rethrow;
    }
  }
}

/// TradPlus-specific option keys accepted by Core's `configureNetwork` API.
abstract final class TradplusAdOptions {
  static const appId = 'appId';
  static const customMap = 'customMap';
  static const settingData = 'settingData';
  static const customTestId = 'customTestId';
  static const privacyUserAgree = 'privacyUserAgree';
  static const gdprDataCollection = 'gdprDataCollection';
  static const lgpdDataCollection = 'lgpdDataCollection';
  static const ccpaDoNotSell = 'ccpaDoNotSell';
  static const coppaAgeRestricted = 'coppaAgeRestricted';
  static const openPersonalizedAd = 'openPersonalizedAd';
  static const initializeTimeout = 'initializeTimeout';
  static const loadTimeout = 'loadTimeout';
  static const sceneId = 'sceneId';
  static const sceneIds = 'sceneIds';
  static const interstitialExtraMap = 'interstitialExtraMap';
  static const rewardedExtraMap = 'rewardedExtraMap';
  static const bannerExtraMap = 'bannerExtraMap';
  static const nativeExtraMap = 'nativeExtraMap';
  static const splashExtraMap = 'splashExtraMap';
  static const bannerClassName = 'bannerClassName';
  static const nativeClassName = 'nativeClassName';
  static const smallNativeClassName = 'smallNativeClassName';
  static const fullScreenNativeClassName = 'fullScreenNativeClassName';
  static const splashClassName = 'splashClassName';
  static const nativeWidth = 'nativeWidth';
  static const nativeHeight = 'nativeHeight';
  static const nativeViewExtraMap = 'nativeViewExtraMap';
  static const customAdInfo = 'customAdInfo';
  static const emitPaidEventFromEcpm = 'emitPaidEventFromEcpm';
}

class FlutterBoomPdfAdTradplusAdapter extends core.FlutterBoomPdfAdAdapter {
  core.AdNetworkConfiguration _configuration =
      const core.AdNetworkConfiguration();
  final Map<String, _TradplusSlot> _slots = <String, _TradplusSlot>{};

  String? _installedAppId;
  bool _initialized = false;
  Future<void>? _initializing;

  @override
  String get networkId => 'tradplus';

  void setAppId(String? appId) {
    final normalized = appId?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      _installedAppId = normalized;
    }
  }

  @override
  Future<void> configure(core.AdNetworkConfiguration configuration) async {
    _configuration = configuration;
  }

  @override
  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initializing ??= _initializeInternal().whenComplete(() {
      _initializing = null;
    });
  }

  Future<void> _initializeInternal() async {
    final options = _configuration.options;
    final appId = _string(options[TradplusAdOptions.appId]) ?? _installedAppId;
    if (appId == null || appId.isEmpty) {
      throw StateError(
        'TradPlus appId is required. Pass it to '
        'FlutterBoomPdfAdTradplusPlugins.install(appId: ...) or '
        'Core.configureNetwork("tradplus", options: {"appId": ...}).',
      );
    }

    await _applyPreInitializationOptions(options);
    final completer = Completer<void>();
    tp.TPSDKManager.setInitListener(
      tp.TPInitListener(
        initFinish: (success) {
          if (completer.isCompleted) return;
          if (success) {
            _initialized = true;
            completer.complete();
          } else {
            completer.completeError(
              StateError('TradPlus SDK initialization failed.'),
            );
          }
        },
      ),
    );
    await tp.TPSDKManager.init(appId);
    await completer.future.timeout(
      _duration(
        options[TradplusAdOptions.initializeTimeout],
        const Duration(seconds: 30),
      ),
      onTimeout: () =>
          throw TimeoutException('TradPlus SDK initialization timed out.'),
    );
  }

  Future<void> _applyPreInitializationOptions(
    Map<String, Object?> options,
  ) async {
    final customMap = _map(options[TradplusAdOptions.customMap]);
    if (customMap != null) await tp.TPSDKManager.setCustomMap(customMap);
    final settingData = _map(options[TradplusAdOptions.settingData]);
    if (settingData != null) {
      await tp.TPSDKManager.setSettingDataParam(settingData);
    }
    final customTestId = _string(options[TradplusAdOptions.customTestId]);
    if (customTestId != null) {
      await tp.TPSDKManager.setCustomTestID(customTestId);
    }
    final privacy = options[TradplusAdOptions.privacyUserAgree];
    if (privacy is bool && defaultTargetPlatform == TargetPlatform.android) {
      await tp.TPSDKManager.setPrivacyUserAgree(privacy);
    }
    final gdpr = options[TradplusAdOptions.gdprDataCollection];
    if (gdpr is bool) await tp.TPSDKManager.setGDPRDataCollection(gdpr);
    final lgpd = options[TradplusAdOptions.lgpdDataCollection];
    if (lgpd is bool) await tp.TPSDKManager.setLGPDDataCollection(lgpd);
    final ccpa = options[TradplusAdOptions.ccpaDoNotSell];
    if (ccpa is bool) await tp.TPSDKManager.setCCPADoNotSell(ccpa);
    final coppa = options[TradplusAdOptions.coppaAgeRestricted];
    if (coppa is bool) {
      await tp.TPSDKManager.setCOPPAIsAgeRestrictedUser(coppa);
    }
    final personalized = options[TradplusAdOptions.openPersonalizedAd];
    if (personalized is bool) {
      await tp.TPSDKManager.setOpenPersonalizedAd(personalized);
    }
  }

  @override
  bool supports(core.AdType adType) => true;

  @override
  Future<core.AdLoadResult> load(core.AdLoadRequest request) async {
    final adUnitId = request.info.adId?.trim();
    final adType = request.info.parsedAdType;
    if (adUnitId == null || adUnitId.isEmpty || adType == null) {
      return const core.AdLoadResult.failure(
        'invalid-ad-config',
        adNetwork: 'TradPlus',
        adSourceName: 'TradPlus',
      );
    }

    final slot = _slot(adType, adUnitId);
    if (slot.pendingLoad != null) {
      return const core.AdLoadResult.failure(
        'load-already-in-progress',
        adNetwork: 'TradPlus',
        adSourceName: 'TradPlus',
      );
    }
    if (slot.loaded != null && !slot.loaded!.isDisposed) {
      return const core.AdLoadResult.failure(
        'ad-unit-already-owned',
        adNetwork: 'TradPlus',
        adSourceName: 'TradPlus',
      );
    }

    final completer = Completer<core.AdLoadResult>();
    slot
      ..pendingLoad = completer
      ..pendingRequest = request;
    _attachListener(slot);
    try {
      await _startLoad(adType, adUnitId, request);
    } catch (error) {
      slot.clearPending();
      return core.AdLoadResult.failure(
        'exception=$error',
        adNetwork: 'TradPlus',
        adSourceName: 'TradPlus',
      );
    }

    return completer.future.timeout(
      _duration(
        request.networkOptions[TradplusAdOptions.loadTimeout],
        const Duration(seconds: 30),
      ),
      onTimeout: () {
        if (identical(slot.pendingLoad, completer)) slot.clearPending();
        return const core.AdLoadResult.failure(
          'load-timeout',
          adNetwork: 'TradPlus',
          adSourceName: 'TradPlus',
        );
      },
    );
  }

  Future<void> _startLoad(
    core.AdType adType,
    String adUnitId,
    core.AdLoadRequest request,
  ) {
    switch (adType) {
      case core.AdType.appOpen:
        return tp.TPSplashManager.loadSplashAd(
          adUnitId,
          extraMap: _map(
            request.networkOptions[TradplusAdOptions.splashExtraMap],
          ),
        );
      case core.AdType.interstitial:
        return tp.TPInterstitialManager.loadInterstitialAd(
          adUnitId,
          extraMap: _map(
            request.networkOptions[TradplusAdOptions.interstitialExtraMap],
          ),
        );
      case core.AdType.rewarded:
        return tp.TPRewardVideoManager.loadRewardVideoAd(
          adUnitId,
          extraMap: _map(
            request.networkOptions[TradplusAdOptions.rewardedExtraMap],
          ),
        );
      case core.AdType.banner:
        return tp.TPBannerManager.loadBannerAd(
          adUnitId,
          extraMap: _map(
            request.networkOptions[TradplusAdOptions.bannerExtraMap],
          ),
        );
      case core.AdType.native:
        final width =
            _number(
              request.networkOptions[TradplusAdOptions.nativeWidth],
            )?.toDouble() ??
            320;
        final height =
            _number(
              request.networkOptions[TradplusAdOptions.nativeHeight],
            )?.toDouble() ??
            (request.interstitialLikeNative
                ? 640
                : request.smallTemplateNative
                ? 100
                : 360);
        final configured = _map(
          request.networkOptions[TradplusAdOptions.nativeExtraMap],
        );
        final extra =
            configured ??
            tp.TPNativeManager.createNativeExtraMap(
              templateWidth: width,
              templateHeight: height,
            );
        return tp.TPNativeManager.loadNativeAd(adUnitId, extraMap: extra);
    }
  }

  _TradplusSlot _slot(core.AdType type, String adUnitId) {
    final key = '${type.name}:$adUnitId';
    return _slots.putIfAbsent(
      key,
      () => _TradplusSlot(
        adUnitId: adUnitId,
        adType: type,
        removeSelf: () => _slots.remove(key),
      ),
    );
  }

  void _attachListener(_TradplusSlot slot) {
    switch (slot.adType) {
      case core.AdType.appOpen:
        tp.TPSplashManager.setSplashListener(
          tp.TPSplashAdListener(
            onAdLoaded: (_, info) => _loaded(slot, info),
            onAdLoadFailed: (_, error) => _loadFailed(slot, error),
            onAdImpression: (_, info) => slot.impression(info),
            onAdShowFailed: (_, info, error) => slot.showFailed(info, error),
            onAdClicked: (_, info) => slot.clicked(info),
            onAdClosed: (_, info) => slot.closed(info),
            oneLayerLoadFailed: (_, _, _) {},
            onAdStartLoad: (_, _) {},
            onBiddingStart: (_, _) {},
            onBiddingEnd: (_, _, _) {},
            onAdIsLoading: (_) {},
            oneLayerStartLoad: (_, _) {},
            oneLayerLoaded: (_, _) {},
            onAdAllLoaded: (_, _) {},
            onZoomOutStart: (_, _) {},
            onZoomOutEnd: (_, _) {},
            onSkip: (_, _) {},
          ),
          adUnitId: slot.adUnitId,
        );
      case core.AdType.interstitial:
        tp.TPInterstitialManager.setInterstitialListener(
          tp.TPInterstitialAdListener(
            onAdLoaded: (_, info) => _loaded(slot, info),
            onAdLoadFailed: (_, error) => _loadFailed(slot, error),
            onAdImpression: (_, info) => slot.impression(info),
            onAdShowFailed: (_, info, error) => slot.showFailed(info, error),
            onAdClicked: (_, info) => slot.clicked(info),
            onAdClosed: (_, info) => slot.closed(info),
            oneLayerLoadFailed: (_, _, _) {},
            onAdStartLoad: (_, _) {},
            onBiddingStart: (_, _) {},
            onBiddingEnd: (_, _, _) {},
            onAdIsLoading: (_) {},
            oneLayerStartLoad: (_, _) {},
            oneLayerLoaded: (_, _) {},
            onAdAllLoaded: (_, _) {},
            onVideoPlayStart: (_, _) {},
            onVideoPlayEnd: (_, _) {},
          ),
          adUnitId: slot.adUnitId,
        );
      case core.AdType.rewarded:
        tp.TPRewardVideoManager.setRewardVideoListener(
          tp.TPRewardVideoAdListener(
            onAdLoaded: (_, info) => _loaded(slot, info),
            onAdLoadFailed: (_, error) => _loadFailed(slot, error),
            onAdImpression: (_, info) => slot.impression(info),
            onAdShowFailed: (_, info, error) => slot.showFailed(info, error),
            onAdClicked: (_, info) => slot.clicked(info),
            onAdClosed: (_, info) => slot.closed(info),
            onAdReward: (_, info) => slot.reward(info),
            oneLayerLoadFailed: (_, _, _) {},
            onAdStartLoad: (_, _) {},
            onBiddingStart: (_, _) {},
            onBiddingEnd: (_, _, _) {},
            onAdIsLoading: (_) {},
            oneLayerStartLoad: (_, _) {},
            oneLayerLoaded: (_, _) {},
            onAdAllLoaded: (_, _) {},
            onVideoPlayStart: (_, _) {},
            onVideoPlayEnd: (_, _) {},
            onPlayAgainImpression: (_, info) => slot.impression(info),
            onPlayAgainReward: (_, info) => slot.reward(info),
            onPlayAgainClicked: (_, info) => slot.clicked(info),
            onPlayAgainVideoPlayStart: (_, _) {},
            onPlayAgainVideoPlayEnd: (_, _) {},
          ),
          adUnitId: slot.adUnitId,
        );
      case core.AdType.banner:
        tp.TPBannerManager.setBannerListener(
          tp.TPBannerAdListener(
            onAdLoaded: (_, info) => _loaded(slot, info),
            onAdLoadFailed: (_, error) => _loadFailed(slot, error),
            onAdImpression: (_, info) => slot.impression(info),
            onAdShowFailed: (_, info, error) => slot.showFailed(info, error),
            onAdClicked: (_, info) => slot.clicked(info),
            onAdClosed: (_, info) => slot.closed(info),
            oneLayerLoadFailed: (_, _, _) {},
            onAdStartLoad: (_, _) {},
            onBiddingStart: (_, _) {},
            onBiddingEnd: (_, _, _) {},
            onAdIsLoading: (_) {},
            oneLayerStartLoad: (_, _) {},
            oneLayerLoaded: (_, _) {},
            onAdAllLoaded: (_, _) {},
          ),
          adUnitId: slot.adUnitId,
        );
      case core.AdType.native:
        tp.TPNativeManager.setNativeAdListener(
          tp.TPNativeAdListener(
            onAdLoaded: (_, info) => _loaded(slot, info),
            onAdLoadFailed: (_, error) => _loadFailed(slot, error),
            onAdImpression: (_, info) => slot.impression(info),
            onAdShowFailed: (_, info, error) => slot.showFailed(info, error),
            onAdClicked: (_, info) => slot.clicked(info),
            onAdClosed: (_, info) => slot.closed(info),
            oneLayerLoadFailed: (_, _, _) {},
            onAdStartLoad: (_, _) {},
            onBiddingStart: (_, _) {},
            onBiddingEnd: (_, _, _) {},
            onAdIsLoading: (_) {},
            oneLayerStartLoad: (_, _) {},
            oneLayerLoaded: (_, _) {},
            onAdAllLoaded: (_, _) {},
            onVideoPlayStart: (_, _) {},
            onVideoPlayEnd: (_, _) {},
          ),
          adUnitId: slot.adUnitId,
        );
    }
  }

  void _loaded(_TradplusSlot slot, Map<dynamic, dynamic> adInfo) {
    final completer = slot.pendingLoad;
    final request = slot.pendingRequest;
    if (completer == null || request == null || completer.isCompleted) return;
    final ad = _TradplusLoadedAd(
      slot: slot,
      request: request,
      initialAdInfo: Map<dynamic, dynamic>.from(adInfo),
    );
    slot
      ..loaded = ad
      ..clearPending();
    completer.complete(core.AdLoadResult.success(ad));
  }

  void _loadFailed(_TradplusSlot slot, Map<dynamic, dynamic> error) {
    final completer = slot.pendingLoad;
    if (completer == null || completer.isCompleted) return;
    slot.clearPending();
    completer.complete(
      core.AdLoadResult.failure(
        _formatError(error),
        adNetwork: 'TradPlus',
        adSourceName: 'TradPlus',
      ),
    );
  }

  @override
  Future<String?> openAdInspector() async {
    final appId =
        _string(_configuration.options[TradplusAdOptions.appId]) ??
        _installedAppId;
    if (appId == null || appId.isEmpty) return 'missing-tradplus-app-id';
    await tp.TPSDKManager.openTradPlusTool(appId);
    return null;
  }

  @override
  Future<void> dispose() async {
    final slots = _slots.values.toList(growable: false);
    _slots.clear();
    for (final slot in slots) {
      await slot.dispose();
    }
    _initialized = false;
    _initializing = null;
  }
}

class _TradplusLoadedAd
    implements core.LoadedNetworkAd, core.AdAuctionCandidate {
  _TradplusLoadedAd({
    required this.slot,
    required this.request,
    required Map<dynamic, dynamic> initialAdInfo,
  }) : _adInfo = initialAdInfo;

  final _TradplusSlot slot;
  final core.AdLoadRequest request;
  final _TradplusEventEmitter _events = _TradplusEventEmitter();
  Map<dynamic, dynamic> _adInfo;
  Completer<core.AdShowResult>? _showCompleter;
  core.OnUserEarnedRewardCallback? _rewardCallback;
  bool _disposed = false;
  bool _paidEmitted = false;

  bool get isDisposed => _disposed;

  @override
  String get networkId => 'tradplus';

  @override
  String get adNetwork =>
      _firstString(_adInfo, const <String>[
        'networkName',
        'adNetworkName',
        'networkId',
      ]) ??
      'TradPlus';

  @override
  String get adSourceName =>
      _firstString(_adInfo, const <String>[
        'adSourceName',
        'placementName',
        'networkName',
      ]) ??
      adNetwork;

  @override
  core.AdType get adType => slot.adType;

  @override
  Object get rawAd => this;

  @override
  bool get supportsWidget =>
      adType == core.AdType.banner ||
      adType == core.AdType.native ||
      (adType == core.AdType.appOpen &&
          defaultTargetPlatform == TargetPlatform.android);

  @override
  Stream<core.AdNetworkEvent> get events => _events.stream;

  @override
  Future<bool?> winsAgainst({required double competitorRevenueMicros}) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return Future<bool?>.value(null);
    }
    return FlutterBoomPdfAdTradplusPlugins.isTradplusWinner(
      admobPrice: competitorRevenueMicros / 1000000,
      tpAdInfo: _adInfo,
    );
  }

  @override
  Widget? buildWidget() {
    if (_disposed) return null;
    slot.activate(this);
    final options = request.networkOptions;
    final sceneId = _sceneId(request);
    final customAdInfo = _map(options[TradplusAdOptions.customAdInfo]);
    switch (adType) {
      case core.AdType.banner:
        return tp.TPBannerViewWidget(
          slot.adUnitId,
          className: _string(options[TradplusAdOptions.bannerClassName]) ?? '',
        );
      case core.AdType.native:
        final width =
            _number(options[TradplusAdOptions.nativeWidth])?.toDouble() ?? 320;
        final height =
            _number(options[TradplusAdOptions.nativeHeight])?.toDouble() ??
            (request.interstitialLikeNative
                ? 640
                : request.smallTemplateNative
                ? 100
                : 360);
        final className = request.interstitialLikeNative
            ? _string(options[TradplusAdOptions.fullScreenNativeClassName])
            : request.smallTemplateNative
            ? _string(options[TradplusAdOptions.smallNativeClassName])
            : _string(options[TradplusAdOptions.nativeClassName]);
        return tp.TPNativeViewWidget(
          slot.adUnitId,
          width,
          height,
          sceneId: sceneId ?? '',
          className: className ?? '',
          extraMap: _map(options[TradplusAdOptions.nativeViewExtraMap]),
          customAdInfo: customAdInfo,
        );
      case core.AdType.appOpen:
        if (defaultTargetPlatform != TargetPlatform.android) return null;
        return tp.TPSplashViewWidget(
          slot.adUnitId,
          layoutName: _string(options[TradplusAdOptions.splashClassName]) ?? '',
        );
      case core.AdType.interstitial:
      case core.AdType.rewarded:
        return null;
    }
  }

  @override
  Future<core.AdShowResult> show({
    core.OnUserEarnedRewardCallback? onUserEarnedReward,
  }) async {
    if (_disposed) {
      return const core.AdShowResult.failure('ad-disposed');
    }
    if (supportsWidget) {
      return const core.AdShowResult.failure('ad-requires-widget');
    }
    final ready = await _isReady();
    if (!ready) return const core.AdShowResult.failure('ad-not-ready');
    slot.activate(this);
    _rewardCallback = onUserEarnedReward;
    final completer = Completer<core.AdShowResult>();
    _showCompleter = completer;
    try {
      final customAdInfo = _map(
        request.networkOptions[TradplusAdOptions.customAdInfo],
      );
      if (customAdInfo != null) await _setCustomAdInfo(customAdInfo);
      final sceneId = _sceneId(request);
      switch (adType) {
        case core.AdType.appOpen:
          await tp.TPSplashManager.showSplashAd(
            slot.adUnitId,
            className:
                _string(
                  request.networkOptions[TradplusAdOptions.splashClassName],
                ) ??
                '',
            sceneId: sceneId,
          );
        case core.AdType.interstitial:
          await tp.TPInterstitialManager.showInterstitialAd(
            slot.adUnitId,
            sceneId: sceneId,
          );
        case core.AdType.rewarded:
          await tp.TPRewardVideoManager.showRewardVideoAd(
            slot.adUnitId,
            sceneId: sceneId,
          );
        case core.AdType.banner:
        case core.AdType.native:
          return const core.AdShowResult.failure('ad-requires-widget');
      }
    } catch (error) {
      if (identical(slot.showing, this)) slot.showing = null;
      _showCompleter = null;
      return core.AdShowResult.failure('exception=$error');
    }
    return completer.future;
  }

  Future<bool> _isReady() {
    switch (adType) {
      case core.AdType.appOpen:
        return tp.TPSplashManager.splashAdReady(slot.adUnitId);
      case core.AdType.interstitial:
        return tp.TPInterstitialManager.interstitialAdReady(slot.adUnitId);
      case core.AdType.rewarded:
        return tp.TPRewardVideoManager.rewardVideoAdReady(slot.adUnitId);
      case core.AdType.banner:
        return tp.TPBannerManager.bannerAdReady(slot.adUnitId);
      case core.AdType.native:
        return tp.TPNativeManager.nativeAdReady(slot.adUnitId);
    }
  }

  Future<void> _setCustomAdInfo(Map<dynamic, dynamic> value) {
    switch (adType) {
      case core.AdType.appOpen:
        return tp.TPSplashManager.setCustomAdInfo(slot.adUnitId, value);
      case core.AdType.interstitial:
        return tp.TPInterstitialManager.setCustomAdInfo(slot.adUnitId, value);
      case core.AdType.rewarded:
        return tp.TPRewardVideoManager.setCustomAdInfo(slot.adUnitId, value);
      case core.AdType.banner:
        return tp.TPBannerManager.setCustomAdInfo(slot.adUnitId, value);
      case core.AdType.native:
        return tp.TPNativeManager.setCustomAdInfo(slot.adUnitId, value);
    }
  }

  void updateAdInfo(Map<dynamic, dynamic> value) {
    if (value.isNotEmpty) _adInfo = Map<dynamic, dynamic>.from(value);
  }

  void impression(Map<dynamic, dynamic> info) {
    updateAdInfo(info);
    _events.impression();
    if (_paidEmitted ||
        request.networkOptions[TradplusAdOptions.emitPaidEventFromEcpm] ==
            false) {
      return;
    }
    final ecpm = _firstNumber(_adInfo, const <String>['ecpm', 'eCPM']);
    if (ecpm == null || ecpm <= 0) return;
    _paidEmitted = true;
    // eCPM is revenue per thousand impressions; Core expects micros per
    // individual impression.
    _events.paid(
      valueMicros: ecpm * 1000,
      currencyCode:
          _firstString(_adInfo, const <String>['currency', 'currencyCode']) ??
          'USD',
      precisionType:
          _firstString(_adInfo, const <String>['ecpmPrecision', 'ecpmLevel']) ??
          'tradplus-ecpm',
    );
  }

  void clicked(Map<dynamic, dynamic> info) {
    updateAdInfo(info);
    _events.clicked();
  }

  void showFailed(Map<dynamic, dynamic> info, Map<dynamic, dynamic> error) {
    updateAdInfo(info);
    final completer = _showCompleter;
    _showCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(core.AdShowResult.failure(_formatError(error)));
    }
  }

  void reward(Map<dynamic, dynamic> info) {
    updateAdInfo(info);
    final amount =
        _firstNumber(info, const <String>['rewardAmount', 'amount']) ?? 1;
    final type =
        _firstString(info, const <String>['rewardName', 'rewardType']) ??
        'tradplus';
    _rewardCallback?.call(this, core.AdRewardItem(amount: amount, type: type));
  }

  void closed(Map<dynamic, dynamic> info) {
    updateAdInfo(info);
    _events.closed();
    final completer = _showCompleter;
    _showCompleter = null;
    _rewardCallback = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(const core.AdShowResult.success());
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    slot.detach(this);
    final completer = _showCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(
        const core.AdShowResult.failure('disposed-before-close'),
      );
    }
    _showCompleter = null;
    _rewardCallback = null;
    await _events.close();
  }
}

class _TradplusSlot {
  _TradplusSlot({
    required this.adUnitId,
    required this.adType,
    required this.removeSelf,
  });

  final String adUnitId;
  final core.AdType adType;
  final VoidCallback removeSelf;
  Completer<core.AdLoadResult>? pendingLoad;
  core.AdLoadRequest? pendingRequest;
  _TradplusLoadedAd? loaded;
  _TradplusLoadedAd? showing;

  void clearPending() {
    pendingLoad = null;
    pendingRequest = null;
  }

  void activate(_TradplusLoadedAd ad) {
    showing = ad;
    if (identical(loaded, ad)) loaded = null;
  }

  _TradplusLoadedAd? get eventTarget => showing ?? loaded;

  void impression(Map<dynamic, dynamic> info) => eventTarget?.impression(info);
  void clicked(Map<dynamic, dynamic> info) => eventTarget?.clicked(info);
  void reward(Map<dynamic, dynamic> info) => eventTarget?.reward(info);

  void showFailed(Map<dynamic, dynamic> info, Map<dynamic, dynamic> error) {
    final target = eventTarget;
    target?.showFailed(info, error);
    if (identical(showing, target)) showing = null;
  }

  void closed(Map<dynamic, dynamic> info) {
    final target = eventTarget;
    target?.closed(info);
    if (identical(showing, target)) showing = null;
  }

  void detach(_TradplusLoadedAd ad) {
    if (identical(loaded, ad)) loaded = null;
    if (identical(showing, ad)) showing = null;
    if (pendingLoad == null && loaded == null && showing == null) removeSelf();
  }

  Future<void> dispose() async {
    final pending = pendingLoad;
    clearPending();
    if (pending != null && !pending.isCompleted) {
      pending.complete(
        const core.AdLoadResult.failure(
          'adapter-disposed',
          adNetwork: 'TradPlus',
          adSourceName: 'TradPlus',
        ),
      );
    }
    final ads = <_TradplusLoadedAd>{
      if (loaded != null) loaded!,
      if (showing != null) showing!,
    };
    loaded = null;
    showing = null;
    for (final ad in ads) {
      await ad.dispose();
    }
  }
}

class _TradplusEventEmitter {
  final StreamController<core.AdNetworkEvent> _controller =
      StreamController<core.AdNetworkEvent>.broadcast(sync: true);
  bool _closed = false;

  Stream<core.AdNetworkEvent> get stream => _controller.stream;

  void impression() => _add(const core.AdNetworkEvent.impression());
  void clicked() => _add(const core.AdNetworkEvent.clicked());
  void closed() => _add(const core.AdNetworkEvent.closed());
  void paid({
    required double valueMicros,
    required String currencyCode,
    required String precisionType,
  }) => _add(
    core.AdNetworkEvent.paid(
      valueMicros: valueMicros,
      currencyCode: currencyCode,
      precisionType: precisionType,
    ),
  );

  void _add(core.AdNetworkEvent event) {
    if (!_closed) _controller.add(event);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _controller.close();
  }
}

String? _sceneId(core.AdLoadRequest request) {
  final options = request.networkOptions;
  final direct = _string(options[TradplusAdOptions.sceneId]);
  if (direct != null) return direct;
  final scenes = options[TradplusAdOptions.sceneIds];
  if (scenes is! Map) return null;
  return _string(scenes[request.placement]) ??
      _string(scenes[request.placement.toString()]) ??
      _string(scenes[request.info.parsedAdType?.rawValue]);
}

Duration _duration(Object? value, Duration fallback) {
  if (value is Duration && value > Duration.zero) return value;
  if (value is num && value > 0) {
    return Duration(milliseconds: (value * 1000).round());
  }
  return fallback;
}

Map<dynamic, dynamic>? _map(Object? value) =>
    value is Map ? Map<dynamic, dynamic>.from(value) : null;

String? _string(Object? value) {
  if (value == null) return null;
  final result = value.toString().trim();
  return result.isEmpty ? null : result;
}

num? _number(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

String? _firstString(Map<dynamic, dynamic> map, Iterable<String> keys) {
  for (final key in keys) {
    final result = _string(map[key]);
    if (result != null) return result;
  }
  return null;
}

num? _firstNumber(Map<dynamic, dynamic> map, Iterable<String> keys) {
  for (final key in keys) {
    final result = _number(map[key]);
    if (result != null) return result;
  }
  return null;
}

String _formatError(Map<dynamic, dynamic> error) {
  final code = error['code'] ?? error['errorCode'] ?? 'unknown';
  final message =
      error['msg'] ?? error['message'] ?? error['errorMessage'] ?? 'unknown';
  return 'code=$code message=$message';
}
