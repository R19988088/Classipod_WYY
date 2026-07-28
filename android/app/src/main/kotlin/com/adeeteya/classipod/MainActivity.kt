package com.adeeteya.classipod

import android.content.pm.PackageManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.adeeteya.classipod/device",
        ).setMethodCallHandler { call, result ->
            if (call.method == "isTelevision") {
                val manager = applicationContext.packageManager
                val isTelevision =
                    manager.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
                        manager.hasSystemFeature(PackageManager.FEATURE_TELEVISION) ||
                        !manager.hasSystemFeature(PackageManager.FEATURE_TOUCHSCREEN)
                result.success(isTelevision)
            } else {
                result.notImplemented()
            }
        }
    }
}
