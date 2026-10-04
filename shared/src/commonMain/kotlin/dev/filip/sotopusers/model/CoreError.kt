package dev.filip.sotopusers.model

/** Typed failures surfaced by the shared core. */
sealed class CoreError(message: String?, cause: Throwable? = null) : Exception(message, cause) {
    /** Transport failure: offline, DNS, connection refused, timeout. */
    class Network(cause: Throwable? = null) : CoreError("Network error: ${cause?.message ?: "unknown"}", cause)

    /** Non-success HTTP status, or a StackExchange error object (`error_id` mirrors HTTP codes). */
    class Http(val code: Int, val apiMessage: String? = null) : CoreError("HTTP $code${apiMessage?.let { ": $it" } ?: ""}")

    /** Response body could not be decoded into the expected shape. */
    class Decoding(cause: Throwable? = null) : CoreError("Decoding error: ${cause?.message ?: "unknown"}", cause)

    /** Local persistence failed or was corrupt. */
    class Storage(cause: Throwable? = null) : CoreError("Storage error: ${cause?.message ?: "unknown"}", cause)
}

/** Result type with a typed error; a class (not Kotlin's inline `Result`) so it exports cleanly to Swift. */
sealed class Outcome<out T> {
    data class Success<out T>(val value: T) : Outcome<T>()
    data class Failure(val error: CoreError) : Outcome<Nothing>()

    fun getOrNull(): T? = (this as? Success)?.value
    fun errorOrNull(): CoreError? = (this as? Failure)?.error

    inline fun <R> map(transform: (T) -> R): Outcome<R> = when (this) {
        is Success -> Success(transform(value))
        is Failure -> this
    }
}
