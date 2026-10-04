package dev.filip.sotopusers.android.mvi

import dev.filip.sotopusers.model.CoreError

/** Transient, show-once notices carried in screen state and cleared by a `MessageShown` intent. */
sealed interface UserMessage {
    data class FollowFailed(val userId: Long, val error: CoreError) : UserMessage

    /** Persisted follow state was unreadable at startup and has been reset. */
    data class FollowStateReset(val error: CoreError.Storage) : UserMessage
}
