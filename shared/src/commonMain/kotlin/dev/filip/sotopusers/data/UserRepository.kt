package dev.filip.sotopusers.data

import dev.filip.sotopusers.model.CoreError
import dev.filip.sotopusers.model.Outcome
import dev.filip.sotopusers.model.User
import kotlinx.coroutines.flow.StateFlow

/**
 * Single app-scoped source of truth for users and follow state.
 * Follow mutations are serialized; every successful mutation is persisted before it is published.
 */
class UserRepository(
    private val api: UserApiService,
    private val followStore: FollowStore,
) {
    /** Non-null if persisted follow state was unreadable at startup (it was reset to empty). */
    val startupStorageError: CoreError.Storage? get() = TODO()

    val followedIdsFlow: StateFlow<Set<Long>> get() = TODO()

    fun followedIds(): Set<Long> = TODO()

    suspend fun getTopUsers(): Outcome<List<User>> = TODO()

    /** Flips follow state for [userId]; returns the new state (true = followed). */
    suspend fun toggleFollow(userId: Long): Outcome<Boolean> = TODO()
}
