package com.zeroex.annua

import android.app.Activity
import android.content.Intent
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Sound helper for Annua: system sound picker + short previews. */
class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var player: MediaPlayer? = null

    private fun stopPreview() {
        try { player?.stop() } catch (_: Exception) {}
        try { player?.release() } catch (_: Exception) {}
        player = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "annua/sound").setMethodCallHandler { call, result ->
            when (call.method) {
                "pick" -> {
                    pending?.success(null)
                    pending = result
                    val i = Intent(RingtoneManager.ACTION_RINGTONE_PICKER)
                    i.putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, call.argument<Int>("type") ?: RingtoneManager.TYPE_NOTIFICATION)
                    i.putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                    i.putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                    i.putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, call.argument<String>("title") ?: "Select sound")
                    val cur = call.argument<String>("current")
                    if (!cur.isNullOrEmpty()) i.putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(cur))
                    @Suppress("DEPRECATION")
                    startActivityForResult(i, 4711)
                }
                "preview" -> {
                    stopPreview()
                    try {
                        val raw = call.argument<String>("raw")
                        val uri = call.argument<String>("uri")
                        val mp: MediaPlayer
                        if (raw != null) {
                            val id = resources.getIdentifier(raw, "raw", packageName)
                            mp = MediaPlayer.create(this, id)
                        } else {
                            val u = when (uri) {
                                "default_notification" -> RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                                "default_alarm" -> RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                                else -> Uri.parse(uri)
                            }
                            mp = MediaPlayer()
                            mp.setDataSource(this, u)
                            mp.prepare()
                        }
                        mp.setOnCompletionListener { stopPreview() }
                        mp.start()
                        player = mp
                    } catch (_: Exception) {}
                    result.success(null)
                }
                "stop" -> { stopPreview(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == 4711) {
            val r = pending
            pending = null
            if (resultCode == Activity.RESULT_OK && data != null) {
                val u: Uri? = data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
                val name = if (u != null) (RingtoneManager.getRingtone(this, u)?.getTitle(this) ?: "Custom") else "Custom"
                r?.success(mapOf("uri" to (u?.toString() ?: ""), "name" to name))
            } else {
                r?.success(null)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        stopPreview()
        super.onDestroy()
    }
}
