package com.buxoropos.buxoro_pos

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// mDNS/Bonjour printer discovery Android'da faqat WifiManager.MulticastLock
/// ushlab turilganda ishlaydi — aks holda WiFi drayveri multicast paketlarni
/// energiya tejash uchun bloklaydi. Flutter tomon skan boshlashidan oldin
/// `acquire`, tugagach `release` chaqiradi.
class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null
    private val channelName = "xposter/printer_multicast"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> {
                        try {
                            if (multicastLock == null) {
                                val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                                multicastLock = wifi.createMulticastLock("xposter-mdns").apply {
                                    setReferenceCounted(true)
                                    acquire()
                                }
                            } else if (multicastLock?.isHeld == false) {
                                multicastLock?.acquire()
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "release" -> {
                        try {
                            if (multicastLock?.isHeld == true) multicastLock?.release()
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
