import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_boom_pdf_ad_tradplus_plugins_platform_interface.dart';

/// An implementation of [FlutterBoomPdfAdTradplusPluginsPlatform] that uses method channels.
class MethodChannelFlutterBoomPdfAdTradplusPlugins
    extends FlutterBoomPdfAdTradplusPluginsPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel(
    'flutter_boom_pdf_ad_tradplus_plugins',
  );

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<bool?> isTradplusWinner({
    required double admobPrice,
    required Map<String, Object?> tpAdInfo,
  }) {
    return methodChannel.invokeMethod<bool>(
      'isTradplusWinner',
      <String, Object?>{'admobPrice': admobPrice, 'tpAdInfo': tpAdInfo},
    );
  }
}
