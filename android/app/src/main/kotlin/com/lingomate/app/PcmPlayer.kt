package com.lingomate.app

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack

/** Streams mono PCM16 audio (Live translations) through a low-latency AudioTrack. */
class PcmPlayer {
    private var track: AudioTrack? = null

    /** Opens a streaming track at [sampleRate]. */
    fun start(sampleRate: Int) {
        stop()
        val minBuffer = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .build(),
            )
            .setBufferSizeInBytes(minBuffer * 4)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
            .build()
            .also { it.play() }
    }

    /** Queues PCM16 bytes for playback without blocking. */
    fun write(bytes: ByteArray) {
        track?.write(bytes, 0, bytes.size, AudioTrack.WRITE_NON_BLOCKING)
    }

    /** Stops playback and releases the track. */
    fun stop() {
        track?.let {
            it.pause()
            it.flush()
            it.release()
        }
        track = null
    }
}
