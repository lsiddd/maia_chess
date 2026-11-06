package com.maiachess.maia_chess

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.SoundPool
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var moveSounds: MoveSounds? = null
    private var soundChannel: MethodChannel? = null
    private var audioActive = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        volumeControlStream = AudioManager.STREAM_MUSIC
        val sounds = MoveSounds(applicationContext)
        moveSounds = sounds
        soundChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "maia_chess/move_sounds",
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "move" -> result.success(audioActive && sounds.play(capture = false))
                    "capture" -> result.success(audioActive && sounds.play(capture = true))
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        audioActive = true
    }

    override fun onPause() {
        audioActive = false
        moveSounds?.clearPending()
        super.onPause()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        soundChannel?.setMethodCallHandler(null)
        soundChannel = null
        moveSounds?.release()
        moveSounds = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}

private class MoveSounds(context: Context) {
    private val pool = SoundPool.Builder()
        .setMaxStreams(2)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build(),
        )
        .build()
    private val loaded = mutableSetOf<Int>()
    private var pending: Int? = null
    private val moveSample: Int
    private val captureSample: Int

    init {
        pool.setOnLoadCompleteListener { _, sample, status ->
            if (status == 0) loaded.add(sample)
            if (sample == pending) {
                pending = null
                if (status == 0) playSample(sample)
            }
        }
        moveSample = pool.load(context, R.raw.chess_move, 1)
        captureSample = pool.load(context, R.raw.chess_capture, 1)
    }

    fun play(capture: Boolean): Boolean {
        val sample = if (capture) captureSample else moveSample
        // Keep the latest request if the first move arrives during preloading.
        pending = sample.takeIf { it != 0 && it !in loaded }
        return sample in loaded && playSample(sample)
    }

    fun clearPending() {
        pending = null
    }

    fun release() {
        clearPending()
        pool.setOnLoadCompleteListener(null)
        pool.release()
    }

    private fun playSample(sample: Int): Boolean =
        pool.play(sample, 1f, 1f, 1, 0, 1f) != 0
}
