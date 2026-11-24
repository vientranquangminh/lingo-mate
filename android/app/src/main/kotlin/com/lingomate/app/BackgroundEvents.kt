package com.lingomate.app

/** Forwards events from the service and the overlay to the Dart event channel. */
object BackgroundEvents {
    var sink: ((Map<String, Any>) -> Unit)? = null

    /** Sends one event to Dart if it is listening. */
    fun emit(type: String, text: String? = null) {
        val event = mutableMapOf<String, Any>("type" to type)
        if (text != null) event["text"] = text
        sink?.invoke(event)
    }
}
