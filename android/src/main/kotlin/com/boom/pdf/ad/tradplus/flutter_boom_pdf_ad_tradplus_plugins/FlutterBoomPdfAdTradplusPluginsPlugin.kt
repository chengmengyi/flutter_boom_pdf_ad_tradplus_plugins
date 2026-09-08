package com.boom.pdf.ad.tradplus.flutter_boom_pdf_ad_tradplus_plugins

import com.tp.compareprice.ComparePriceUtil.recursiveComparePrice
import com.tradplus.ads.base.bean.TPAdInfo
import com.tradplus.ads.mgr.TPOutcome
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** FlutterBoomPdfAdTradplusPluginsPlugin */
class FlutterBoomPdfAdTradplusPluginsPlugin :
    FlutterPlugin,
    MethodCallHandler {
    // The MethodChannel that will the communication between Flutter and native Android
    //
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_boom_pdf_ad_tradplus_plugins")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "isTradplusWinner" -> compareRevenue(call, result)
            "getTradplusEstimatedPrice" -> getEstimatedPrice(call, result)
            else -> result.notImplemented()
        }
    }

    private fun getEstimatedPrice(call: MethodCall, result: Result) {
        val adUnitId = call.argument<String>("adUnitId")
        if (adUnitId.isNullOrBlank()) {
            result.error("invalid_ad_unit_id", "adUnitId is required", null)
            return
        }
        runCatching {
            recursiveComparePrice(adUnitId)
        }.onSuccess(result::success).onFailure {
            result.error("tradplus_price_query_failed", it.message, null)
        }
    }

    private fun compareRevenue(call: MethodCall, result: Result) {
        val admobPrice = call.argument<Number>("admobPrice")?.toDouble()
        val rawAdInfo = call.argument<Map<*, *>>("tpAdInfo")
        if (admobPrice == null || rawAdInfo == null) {
            result.error("invalid_auction_arguments", "admobPrice and tpAdInfo are required", null)
            return
        }
        runCatching {
            TPOutcome().isTPW(admobPrice, rawAdInfo.toTPAdInfo())
        }.onSuccess(result::success).onFailure {
            result.error("tradplus_auction_failed", it.message, null)
        }
    }

    private fun Map<*, *>.toTPAdInfo(): TPAdInfo {
        val tpAdUnitId = stringValue("tpAdUnitId") ?: stringValue("adUnitId").orEmpty()
        return TPAdInfo(tpAdUnitId, null).also { info ->
            info.tpAdUnitId = tpAdUnitId
            info.adUnitId = stringValue("adUnitId")
            info.ecpm = stringValue("ecpm") ?: "0"
            info.adNetworkId = stringValue("adNetworkId")
            info.requestId = stringValue("requestId")
            info.adSourcePlacementId = stringValue("adSourcePlacementId")
            info.isBiddingNetwork = booleanValue("isBiddingNetwork")
        }
    }

    private fun Map<*, *>.stringValue(key: String): String? =
        get(key)?.toString()?.takeIf { it.isNotBlank() && it != "null" }

    private fun Map<*, *>.booleanValue(key: String): Boolean =
        when (val value = get(key)) {
            is Boolean -> value
            is Number -> value.toInt() != 0
            else -> value?.toString()?.equals("true", ignoreCase = true) == true ||
                value?.toString() == "1"
        }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
