package dev.filip.sotopusers.data

import dev.filip.sotopusers.model.CoreError
import dev.filip.sotopusers.model.Outcome
import dev.filip.sotopusers.model.User
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.StateFlow
import kotlin.coroutines.CoroutineContext

/**
 * Single app-scoped source of truth for users and follow state.
 * Follow mutations are serialized; every successful mutation is persisted before it is published.
 */
class UserRepository(
    private val api: UserApiService,
    private val followStore: FollowStore,
    observerContext: CoroutineContext = Dispatchers.Default,
) {
    /** Non-null if persisted follow state was unreadable at startup (it was reset to empty). */
    val startupStorageError: CoreError.Storage? get() = TODO()

    val followedIdsFlow: StateFlow<Set<Long>> get() = TODO()

    fun followedIds(): Set<Long> = TODO()

    suspend fun getTopUsers(): Outcome<List<User>> = TODO()

    /** Flips follow state for [userId]; returns the new state (true = followed). */
    suspend fun toggleFollow(userId: Long): Outcome<Boolean> = TODO()

    /**
     * Callback-style observation for Swift (no SKIE): [onChange] gets the current set immediately,
     * then every change, on the repository's observer context (background by default; hop to the
     * main actor on the Swift side). Call [Cancellable.cancel] to stop.
     */
    fun watchFollowedIds(onChange: (Set<Long>) -> Unit): Cancellable = TODO()
}

fun interface Cancellable {
    fun cancel()
}
