import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_boom_pdf_ad_tradplus_plugins_method_channel.dart';

abstract class FlutterBoomPdfAdTradplusPluginsPlatform
    extends PlatformInterface {
  /// Constructs a FlutterBoomPdfAdTradplusPluginsPlatform.
  FlutterBoomPdfAdTradplusPluginsPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterBoomPdfAdTradplusPluginsPlatform _instance =
      MethodChannelFlutterBoomPdfAdTradplusPlugins();

  /// The default instance of [FlutterBoomPdfAdTradplusPluginsPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterBoomPdfAdTradplusPlugins].
  static FlutterBoomPdfAdTradplusPluginsPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterBoomPdfAdTradplusPluginsPlatform] when
  /// they register themselves.
  static set instance(FlutterBoomPdfAdTradplusPluginsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
