package com.fyp.fyp_app

import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Bundle
import android.os.Looper
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.Surface
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.PI
import kotlin.math.sqrt

/**
 * Exposes:
 * 1) `fyp/tilt`: Rotation vector + gyroscope + linear-acceleration impact for
 *    distinguishing steady wheelchair slope climbing from sudden rollover/falls.
 * 2) `fyp/location`: Lightweight native GPS/Network location lookup for nearby
 *    bus stops and SOS location sharing without extra Gradle plugins.
 */
class MainActivity : FlutterActivity(), SensorEventListener {
    companion object {
        private const val TILT_CHANNEL = "fyp/tilt"
        private const val LOCATION_CHANNEL = "fyp/location"
    }

    private var tiltChannel: MethodChannel? = null
    private var locationChannel: MethodChannel? = null

    private lateinit var sensorManager: SensorManager
    private var rotationSensor: Sensor? = null
    private var gyroSensor: Sensor? = null
    private var linearAccelSensor: Sensor? = null
    private var registered = false
    private var tone: ToneGenerator? = null
    private var keepScreenOn = false

    private var latestGyroDegPerSec: Double = 0.0
    private var latestImpactG: Double = 0.0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        rotationSensor = sensorManager.getDefaultSensor(Sensor.TYPE_GAME_ROTATION_VECTOR)
            ?: sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        gyroSensor = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
        linearAccelSensor = sensorManager.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)

        tiltChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TILT_CHANNEL,
        ).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> result.success(startMonitoring())
                    "stop" -> {
                        stopMonitoring()
                        result.success(true)
                    }
                    "playAlert" -> {
                        playAlert(call.argument<Boolean>("danger") ?: false)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        locationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LOCATION_CHANNEL,
        ).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCurrentLocation" -> fetchLocation(result)
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun startMonitoring(): Map<String, Any> {
        val currentSensor = rotationSensor
        if (currentSensor == null) {
            return mapOf(
                "supported" to false,
                "sensor" to "",
                "type" to "none",
            )
        }
        if (!registered) {
            registered = sensorManager.registerListener(
                this,
                currentSensor,
                SensorManager.SENSOR_DELAY_GAME,
            )
            gyroSensor?.let {
                sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
            }
            linearAccelSensor?.let {
                sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
            }
        }
        if (registered && !keepScreenOn) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            keepScreenOn = true
        }
        return mapOf(
            "supported" to registered,
            "sensor" to currentSensor.name,
            "type" to if (currentSensor.type == Sensor.TYPE_GAME_ROTATION_VECTOR) {
                "game"
            } else {
                "rotation"
            },
        )
    }

    private fun stopMonitoring() {
        if (registered) {
            sensorManager.unregisterListener(this)
            registered = false
        }
        if (keepScreenOn) {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            keepScreenOn = false
        }
        latestGyroDegPerSec = 0.0
        latestImpactG = 0.0
        tone?.release()
        tone = null
    }

    @Suppress("DEPRECATION")
    private fun screenRotation(): Int =
        if (Build.VERSION.SDK_INT >= 30) {
            display?.rotation ?: Surface.ROTATION_0
        } else {
            windowManager.defaultDisplay.rotation
        }

    override fun onSensorChanged(event: SensorEvent) {
        if (!registered) return

        when (event.sensor.type) {
            Sensor.TYPE_GYROSCOPE -> {
                val gx = event.values.getOrNull(0) ?: 0f
                val gy = event.values.getOrNull(1) ?: 0f
                val gz = event.values.getOrNull(2) ?: 0f
                val radPerSec = sqrt(gx * gx + gy * gy + gz * gz).toDouble()
                latestGyroDegPerSec = radPerSec * 180.0 / PI
                return
            }
            Sensor.TYPE_LINEAR_ACCELERATION -> {
                val ax = event.values.getOrNull(0) ?: 0f
                val ay = event.values.getOrNull(1) ?: 0f
                val az = event.values.getOrNull(2) ?: 0f
                val mps2 = sqrt(ax * ax + ay * ay + az * az).toDouble()
                latestImpactG = mps2 / 9.80665
                return
            }
        }

        if (event.sensor != rotationSensor) return

        val rotationMatrix = FloatArray(9)
        try {
            SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
        } catch (_: RuntimeException) {
            return
        }

        val x = rotationMatrix[6]
        val y = rotationMatrix[7]
        val z = rotationMatrix[8]
        val norm = sqrt(x * x + y * y + z * z)
        if (!norm.isFinite() || norm < 0.9f) return

        tiltChannel?.invokeMethod(
            "sample",
            mapOf(
                "x" to (x / norm).toDouble(),
                "y" to (y / norm).toDouble(),
                "z" to (z / norm).toDouble(),
                "rotation" to screenRotation(),
                "accuracy" to event.accuracy,
                "elapsedMs" to SystemClock.elapsedRealtime(),
                "gyroDegPerSec" to latestGyroDegPerSec,
                "impactG" to latestImpactG,
            ),
        )
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        if (sensor != rotationSensor || !registered) return
        tiltChannel?.invokeMethod("accuracy", mapOf("accuracy" to accuracy))
    }

    @SuppressLint("MissingPermission")
    private fun fetchLocation(result: MethodChannel.Result) {
        val fine = checkSelfPermission(
            android.Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        val coarse = checkSelfPermission(
            android.Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        if (!fine && !coarse) {
            result.success(mapOf("ok" to false, "error" to "未授予位置權限"))
            return
        }

        val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        if (lm == null) {
            result.success(mapOf("ok" to false, "error" to "無法取得定位服務"))
            return
        }

        val providers = listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER,
            LocationManager.PASSIVE_PROVIDER,
        )
        var best: Location? = null
        val now = System.currentTimeMillis()
        for (p in providers) {
            try {
                if (!lm.isProviderEnabled(p) && p != LocationManager.PASSIVE_PROVIDER) continue
                val loc = lm.getLastKnownLocation(p) ?: continue
                if (best == null || loc.time > best!!.time) {
                    best = loc
                }
            } catch (_: Exception) {}
        }

        if (best != null && now - best!!.time < 5 * 60 * 1000L) {
            result.success(
                mapOf(
                    "ok" to true,
                    "lat" to best!!.latitude,
                    "lon" to best!!.longitude,
                    "accuracyM" to best!!.accuracy.toDouble(),
                ),
            )
            return
        }

        val activeProvider = when {
            lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
            lm.isProviderEnabled(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
            else -> null
        }

        if (activeProvider == null) {
            if (best != null) {
                result.success(
                    mapOf(
                        "ok" to true,
                        "lat" to best!!.latitude,
                        "lon" to best!!.longitude,
                        "accuracyM" to best!!.accuracy.toDouble(),
                    ),
                )
            } else {
                result.success(mapOf("ok" to false, "error" to "請開啟系統定位（GPS）"))
            }
            return
        }

        var replied = false
        val listener = object : LocationListener {
            override fun onLocationChanged(loc: Location) {
                if (replied) return
                replied = true
                lm.removeUpdates(this)
                result.success(
                    mapOf(
                        "ok" to true,
                        "lat" to loc.latitude,
                        "lon" to loc.longitude,
                        "accuracyM" to loc.accuracy.toDouble(),
                    ),
                )
            }
            @Deprecated("Deprecated in Java")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
            override fun onProviderEnabled(provider: String) {}
            override fun onProviderDisabled(provider: String) {}
        }

        try {
            lm.requestLocationUpdates(activeProvider, 0L, 0f, listener, Looper.getMainLooper())
            window.decorView.postDelayed({
                if (!replied) {
                    replied = true
                    try {
                        lm.removeUpdates(listener)
                    } catch (_: Exception) {}
                    if (best != null) {
                        result.success(
                            mapOf(
                                "ok" to true,
                                "lat" to best!!.latitude,
                                "lon" to best!!.longitude,
                                "accuracyM" to best!!.accuracy.toDouble(),
                            ),
                        )
                    } else {
                        result.success(mapOf("ok" to false, "error" to "定位逾時，請到空曠位置或手動輸入起點"))
                    }
                }
            }, 4500L)
        } catch (e: Exception) {
            result.success(mapOf("ok" to false, "error" to "定位失敗：${e.message}"))
        }
    }

    private fun playAlert(danger: Boolean) {
        try {
            if (tone == null) {
                tone = ToneGenerator(AudioManager.STREAM_ALARM, 100)
            }
            tone?.startTone(
                if (danger) {
                    ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD
                } else {
                    ToneGenerator.TONE_PROP_BEEP
                },
                if (danger) 800 else 250,
            )
        } catch (_: RuntimeException) {}

        try {
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            if (vibrator?.hasVibrator() == true) {
                val duration = if (danger) 500L else 150L
                if (Build.VERSION.SDK_INT >= 26) {
                    vibrator.vibrate(
                        VibrationEffect.createOneShot(
                            duration,
                            VibrationEffect.DEFAULT_AMPLITUDE,
                        ),
                    )
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(duration)
                }
            }
        } catch (_: RuntimeException) {}
    }

    override fun onDestroy() {
        stopMonitoring()
        tiltChannel?.setMethodCallHandler(null)
        tiltChannel = null
        locationChannel?.setMethodCallHandler(null)
        locationChannel = null
        super.onDestroy()
    }
}
