package dev.filip.sotopusers.data

import dev.filip.sotopusers.model.CoreError
import dev.filip.sotopusers.model.Outcome
import dev.filip.sotopusers.model.User
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
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
    private val mutex = Mutex()
    private val observerScope = CoroutineScope(SupervisorJob() + observerContext)
    private val followed: MutableStateFlow<Set<Long>>

    /** Non-null if persisted follow state was unreadable at startup (it was reset to empty). */
    val startupStorageError: CoreError.Storage?

    init {
        var error: CoreError.Storage? = null
        val initial = try {
            followStore.load()
        } catch (e: Exception) {
            error = e as? CoreError.Storage ?: CoreError.Storage(e)
            try {
                followStore.save(emptySet())
            } catch (_: Exception) {
                // Reset is best effort; the in-memory state is empty either way.
            }
            emptySet()
        }
        followed = MutableStateFlow(initial)
        startupStorageError = error
    }

    val followedIdsFlow: StateFlow<Set<Long>> = followed.asStateFlow()

    fun followedIds(): Set<Long> = followed.value

    suspend fun getTopUsers(): Outcome<List<User>> = api.fetchTopUsers()

    /** Flips follow state for [userId]; returns the new state (true = followed). */
    suspend fun toggleFollow(userId: Long): Outcome<Boolean> = mutex.withLock {
        val current = followed.value
        val nowFollowing = userId !in current
        val next = if (nowFollowing) current + userId else current - userId
        try {
            followStore.save(next)
        } catch (e: Exception) {
            return@withLock Outcome.Failure(e as? CoreError.Storage ?: CoreError.Storage(e))
        }
        followed.value = next
        Outcome.Success(nowFollowing)
    }

    /**
     * Callback-style observation for Swift (no SKIE): [onChange] gets the current set immediately,
     * then every change, on the repository's observer context (background by default; hop to the
     * main actor on the Swift side). Call [Cancellable.cancel] to stop.
     */
    fun watchFollowedIds(onChange: (Set<Long>) -> Unit): Cancellable {
        val job = observerScope.launch { followed.collect { onChange(it) } }
        return Cancellable { job.cancel() }
    }
}

fun interface Cancellable {
    fun cancel()
}
