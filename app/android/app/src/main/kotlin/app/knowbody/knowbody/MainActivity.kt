package app.knowbody.knowbody

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Ongoing workout notification (Android "Now bar" style) with a live chronometer,
 * a progress bar, Pause/Finish action buttons, and a tap target that opens the app.
 * Action taps are broadcast back into Flutter over the same MethodChannel.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "knowbody/liveactivity"
    private val notifId = 42
    private val chanId = "knowbody_workout"
    private val actionToggle = "app.knowbody.knowbody.TOGGLE"
    private val actionFinish = "app.knowbody.knowbody.FINISH"

    private var channel: MethodChannel? = null
    private var startWhen = 0L
    private var pauseLabel = ""
    private var finishLabel = ""
    private var paused = false

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = when (intent?.action) {
                actionToggle -> "toggle"
                actionFinish -> "finish"
                else -> return
            }
            channel?.invokeMethod("onAction", mapOf("action" to action))
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensureChannel()
        maybeRequestPermission()
        val filter = IntentFilter().apply { addAction(actionToggle); addAction(actionFinish) }
        ContextCompat.registerReceiver(this, receiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
    }

    override fun onDestroy() {
        try { unregisterReceiver(receiver) } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    ensureChannel()
                    maybeRequestPermission()
                    readArgs(call)
                    val base = call.argument<Long>("baseWhen") ?: System.currentTimeMillis()
                    startWhen = base
                    show(call.argument<String>("title") ?: "Workout", call.argument<String>("sub") ?: "",
                        0, call.argument<Int>("max") ?: 0)
                    result.success(null)
                }
                "update" -> {
                    readArgs(call)
                    (call.argument<Long>("baseWhen"))?.let { startWhen = it }
                    show(
                        call.argument<String>("title") ?: "Workout",
                        call.argument<String>("sub") ?: "",
                        call.argument<Int>("progress") ?: 0,
                        call.argument<Int>("max") ?: 0
                    )
                    result.success(null)
                }
                "stop" -> {
                    NotificationManagerCompat.from(this).cancel(notifId)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun readArgs(call: io.flutter.plugin.common.MethodCall) {
        pauseLabel = call.argument<String>("pauseLabel") ?: pauseLabel
        finishLabel = call.argument<String>("finishLabel") ?: finishLabel
        paused = call.argument<Boolean>("paused") ?: false
    }

    private fun maybeRequestPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val chan = NotificationChannel(chanId, "Workout", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Ongoing workout progress"
                setShowBadge(false)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(chan)
        }
    }

    private fun piFlags() = PendingIntent.FLAG_UPDATE_CURRENT or
        (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)

    private fun contentIntent(): PendingIntent {
        val intent = (packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
        }
        return PendingIntent.getActivity(this, 0, intent, piFlags())
    }

    private fun broadcast(action: String, reqCode: Int): PendingIntent {
        val intent = Intent(action).setPackage(packageName)
        return PendingIntent.getBroadcast(this, reqCode, intent, piFlags())
    }

    private fun show(title: String, sub: String, progress: Int, max: Int) {
        val builder = NotificationCompat.Builder(this, chanId)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(title)
            .setContentText(sub)
            .setStyle(NotificationCompat.BigTextStyle().bigText(sub))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_WORKOUT)
            .setContentIntent(contentIntent())
        if (max > 0) builder.setProgress(max, progress, false)
        // Live chronometer while running; frozen (time shown in sub) while paused.
        if (startWhen > 0 && !paused) {
            builder.setWhen(startWhen).setShowWhen(true).setUsesChronometer(true)
        } else {
            builder.setShowWhen(false).setUsesChronometer(false)
        }
        if (pauseLabel.isNotEmpty()) builder.addAction(0, pauseLabel, broadcast(actionToggle, 1))
        if (finishLabel.isNotEmpty()) builder.addAction(0, finishLabel, broadcast(actionFinish, 2))
        try {
            NotificationManagerCompat.from(this).notify(notifId, builder.build())
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS not granted — best-effort feature
        }
    }
}
