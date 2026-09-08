# Rules supplied by compare_price-release.aar. Keep them in this plugin
# because the AAR's classes.jar is embedded directly for Flutter hosts.
-keep public class com.tradplus.** { *; }
-keep class com.tradplus.ads.** { *; }

# Keep the local comparison entry point used by the Android method channel.
-keep class com.tp.compareprice.** { *; }
