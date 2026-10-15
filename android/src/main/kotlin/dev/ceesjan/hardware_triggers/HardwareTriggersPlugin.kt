package dev.ceesjan.hardware_triggers

import android.app.Activity
import android.os.Build
import android.view.InputDevice
import android.view.KeyEvent
import android.view.Window
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Intercepts hardware keys before Flutter's view sees them by wrapping the
 * Activity window's [Window.Callback]. No changes to the host app's
 * MainActivity are needed. See the package README.
 */
class HardwareTriggersPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware {

    private data class Rule(val code: Int, val consume: Boolean, val externalOnly: Boolean)

    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private var sink: EventChannel.EventSink? = null
    private var activity: Activity? = null
    private var proxy: KeyInterceptingCallback? = null

    @Volatile
    private var rules: List<Rule> = emptyList()

    // FlutterPlugin

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods = MethodChannel(binding.binaryMessenger, "hardware_triggers")
        methods.setMethodCallHandler(this)
        events = EventChannel(binding.binaryMessenger, "hardware_triggers/events")
        events.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }

    // MethodCallHandler

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startIntercepting" -> {
                val raw = call.argument<List<Map<String, Any?>>>("rules") ?: emptyList()
                rules = raw.map {
                    Rule(
                        code = it["code"] as Int,
                        consume = it["policy"] != "observe",
                        externalOnly = it["externalOnly"] as? Boolean ?: false,
                    )
                }
                installProxy()
                result.success(null)
            }
            "stopIntercepting" -> {
                rules = emptyList()
                result.success(null)
            }
            "isInterceptSupported" -> result.success(true)
            "connectedDevices" -> result.success(connectedDevices())
            else -> result.notImplemented()
        }
    }

    // StreamHandler

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    // ActivityAware

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        installProxy()
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        uninstallProxy()
        activity = null
    }

    // Interception

    private fun installProxy() {
        val window = activity?.window ?: return
        if (proxy != null) return
        val wrapped = KeyInterceptingCallback(window.callback)
        window.callback = wrapped
        proxy = wrapped
    }

    private fun uninstallProxy() {
        val window = activity?.window
        val current = proxy ?: return
        // Only unwrap if nobody wrapped us in the meantime.
        if (window != null && window.callback === current) {
            window.callback = current.base
        }
        proxy = null
    }

    private inner class KeyInterceptingCallback(val base: Window.Callback) : Window.Callback by base {
        override fun dispatchKeyEvent(event: KeyEvent): Boolean {
            val rule = rules.firstOrNull { it.code == event.keyCode }
                ?: return base.dispatchKeyEvent(event)
            val device = event.device
            val external = isExternal(device)
            if (rule.externalOnly && external != true) return base.dispatchKeyEvent(event)

            if (event.repeatCount == 0) {
                val phase = when (event.action) {
                    KeyEvent.ACTION_DOWN -> "down"
                    KeyEvent.ACTION_UP -> "up"
                    else -> null
                }
                if (phase != null) {
                    sink?.success(
                        mapOf(
                            "code" to event.keyCode,
                            "phase" to phase,
                            "timestamp" to System.currentTimeMillis(),
                            "deviceId" to device?.id,
                            "deviceName" to device?.name,
                            "isExternal" to external,
                        )
                    )
                }
            }
            return if (rule.consume) true else base.dispatchKeyEvent(event)
        }
    }

    private fun isExternal(device: InputDevice?): Boolean? =
        if (device != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) device.isExternal else null

    private fun connectedDevices(): List<Map<String, Any?>> =
        InputDevice.getDeviceIds().toList()
            .mapNotNull { id: Int -> InputDevice.getDevice(id) }
            .filter { device: InputDevice ->
                !device.isVirtual && (device.sources and KEY_SOURCES) != 0
            }
            .map { device: InputDevice ->
                mapOf<String, Any?>(
                    "id" to device.id,
                    "name" to device.name,
                    "isExternal" to isExternal(device),
                )
            }

    private companion object {
        const val KEY_SOURCES =
            InputDevice.SOURCE_KEYBOARD or InputDevice.SOURCE_DPAD or InputDevice.SOURCE_GAMEPAD
    }
}
