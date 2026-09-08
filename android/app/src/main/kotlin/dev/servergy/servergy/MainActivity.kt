package dev.servergy.servergy

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Android-only bridge for the local-network actions requested by Dart's
 * `LocalNetworkAccess` service.
 *
 * The channel deliberately exposes only permission and Wi-Fi multicast-lock
 * operations. No network target, command, profile, or secret crosses this
 * boundary. Linux and Windows bypass this activity entirely.
 */
class MainActivity : FlutterActivity() {
    // Keep this value synchronized with LocalNetworkAccess._channel in Dart.
    private val channelName = "dev.servergy.servergy/local_network"
    // A local, app-private request code; it has no security meaning itself.
    private val permissionRequestCode = 4071
    // Android resolves runtime permission asynchronously, so retain exactly
    // one Flutter callback until onRequestPermissionsResult is invoked.
    private var pendingPermissionResult: MethodChannel.Result? = null
    // mDNS replies may be filtered by Android Wi-Fi unless this short-lived
    // lock is held during discovery.
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ensureAccess" -> ensureLocalNetworkAccess(result)
                    "acquireMulticast" -> {
                        acquireMulticastLock()
                        result.success(null)
                    }
                    "releaseMulticast" -> {
                        releaseMulticastLock()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun ensureLocalNetworkAccess(result: MethodChannel.Result) {
        // Android versions and applications targeting SDK 36 or lower retain
        // the normal INTERNET-based LAN access and must not be prompted.
        if (Build.VERSION.SDK_INT < 37 || applicationInfo.targetSdkVersion < 37) {
            result.success(true)
            return
        }
        if (checkSelfPermission(Manifest.permission.ACCESS_LOCAL_NETWORK) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        // Avoid losing a MethodChannel result if the user taps discovery twice
        // while the platform dialog is still on screen.
        if (pendingPermissionResult != null) {
            result.success(false)
            return
        }
        pendingPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.ACCESS_LOCAL_NETWORK),
            permissionRequestCode,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        // Handle only Servergy's own request and always release the pending
        // result reference after replying, regardless of the user's choice.
        if (requestCode == permissionRequestCode) {
            val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    private fun acquireMulticastLock() {
        // Reference counting is disabled: discovery acquires one shared lock,
        // and its finally block releases it exactly once.
        if (multicastLock?.isHeld == true) return
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        multicastLock = wifi.createMulticastLock("servergy-mdns").apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    private fun releaseMulticastLock() {
        if (multicastLock?.isHeld == true) multicastLock?.release()
        multicastLock = null
    }

    override fun onDestroy() {
        // Protect against a route/activity teardown during an mDNS query.
        releaseMulticastLock()
        super.onDestroy()
    }
}
