package dev.filip.sotopusers.android.list

import dev.filip.sotopusers.android.mvi.Store
import dev.filip.sotopusers.android.mvi.UserMessage
import dev.filip.sotopusers.domain.GetTopUsers
import dev.filip.sotopusers.domain.SortUsers
import dev.filip.sotopusers.domain.ToggleFollow
import dev.filip.sotopusers.model.CoreError
import dev.filip.sotopusers.model.Outcome
import dev.filip.sotopusers.model.SortOption
import dev.filip.sotopusers.model.User
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.StateFlow

sealed interface ListStatus {
    data object Loading : ListStatus
    data object Content : ListStatus

    /** The request succeeded but returned no users — distinct from [Failed]. */
    data object Empty : ListStatus
    data class Failed(val error: CoreError) : ListStatus
}

data class UserListState(
    val status: ListStatus = ListStatus.Loading,
    val users: List<User> = emptyList(),
    val followedIds: Set<Long> = emptySet(),
    /** Users with a follow toggle in flight; further taps on them are ignored (rapid-toggle policy). */
    val pendingFollowIds: Set<Long> = emptySet(),
    val sort: SortOption = SortOption.Default,
    val message: UserMessage? = null,
    /** Id of the only fetch whose completion may still change state (latest request wins). */
    val activeRequestId: Long = 0,
)

sealed interface UserListIntent {
    data object Retry : UserListIntent
    data class ToggleFollow(val userId: Long) : UserListIntent
    data class ApplySort(val option: SortOption) : UserListIntent
    data object MessageShown : UserListIntent
}

/** Reducer inputs: results of intents and effects. */
sealed interface UserListMsg {
    data class LoadStarted(val requestId: Long) : UserListMsg
    data class LoadFinished(val requestId: Long, val result: Outcome<List<User>>) : UserListMsg
    data class FollowedIdsChanged(val ids: Set<Long>) : UserListMsg
    data class ToggleStarted(val userId: Long) : UserListMsg
    data class ToggleFinished(val userId: Long, val error: CoreError?) : UserListMsg
    data class SortApplied(val option: SortOption, val sortedUsers: List<User>) : UserListMsg
    data class StartupStorageError(val error: CoreError.Storage) : UserListMsg
    data object MessageShown : UserListMsg
}

/** Pure list reducer. */
fun reduceUserList(state: UserListState, msg: UserListMsg): UserListState = when (msg) {
    is UserListMsg.LoadStarted -> state.copy(status = ListStatus.Loading, users = emptyList(), activeRequestId = msg.requestId)
    is UserListMsg.LoadFinished -> when {
        msg.requestId != state.activeRequestId -> state // stale completion: a newer request owns the screen
        else -> when (val result = msg.result) {
            is Outcome.Success -> state.copy(
                status = if (result.value.isEmpty()) ListStatus.Empty else ListStatus.Content,
                users = result.value,
            )
            is Outcome.Failure -> state.copy(status = ListStatus.Failed(result.error), users = emptyList())
        }
    }
    is UserListMsg.FollowedIdsChanged -> state.copy(followedIds = msg.ids)
    is UserListMsg.ToggleStarted -> state.copy(pendingFollowIds = state.pendingFollowIds + msg.userId)
    is UserListMsg.ToggleFinished -> state.copy(
        pendingFollowIds = state.pendingFollowIds - msg.userId,
        message = msg.error?.let { UserMessage.FollowFailed(msg.userId, it) } ?: state.message,
    )
    is UserListMsg.SortApplied -> state.copy(sort = msg.option, users = msg.sortedUsers)
    is UserListMsg.StartupStorageError -> state.copy(message = state.message ?: UserMessage.FollowStateReset(msg.error))
    UserListMsg.MessageShown -> state.copy(message = null)
}

/**
 * Thin list store: fetching, sorting and follow mutation are delegated to the shared use cases;
 * follow state is observed from the single app-scoped repository so list and detail stay in sync.
 */
class UserListStore(
    scope: CoroutineScope,
    private val getTopUsers: GetTopUsers,
    private val toggleFollow: ToggleFollow,
    private val sortUsers: SortUsers,
    followedIds: StateFlow<Set<Long>>,
    startupStorageError: CoreError.Storage? = null,
) : Store<UserListState, UserListIntent, UserListMsg, Nothing>(
    UserListState(followedIds = followedIds.value),
    scope,
) {
    override fun reduce(state: UserListState, message: UserListMsg) = reduceUserList(state, message)

    private var loadJob: Job? = null
    private var lastRequestId = 0L

    init {
        startupStorageError?.let { apply(UserListMsg.StartupStorageError(it)) }
        scope.launch { followedIds.collect { apply(UserListMsg.FollowedIdsChanged(it)) } }
        load()
    }

    override fun dispatch(intent: UserListIntent) {
        when (intent) {
            UserListIntent.Retry -> load()
            is UserListIntent.ToggleFollow -> toggle(intent.userId)
            is UserListIntent.ApplySort ->
                apply(UserListMsg.SortApplied(intent.option, sortUsers(state.value.users, intent.option)))
            UserListIntent.MessageShown -> apply(UserListMsg.MessageShown)
        }
    }

    /** Latest request wins: the previous fetch is cancelled and its completion, if any, is ignored by id. */
    private fun load() {
        val requestId = ++lastRequestId
        loadJob?.cancel()
        apply(UserListMsg.LoadStarted(requestId))
        val requestedSort = state.value.sort
        loadJob = scope.launch {
            val result = getTopUsers(requestedSort).map { users ->
                // A sort applied while the request was in flight still wins.
                val current = state.value.sort
                if (current == requestedSort) users else sortUsers(users, current)
            }
            apply(UserListMsg.LoadFinished(requestId, result))
        }
    }

    /** Rapid-toggle policy: one in-flight toggle per user; taps on that user meanwhile are dropped. */
    private fun toggle(userId: Long) {
        if (userId in state.value.pendingFollowIds) return
        apply(UserListMsg.ToggleStarted(userId))
        scope.launch {
            val result = toggleFollow(userId)
            apply(UserListMsg.ToggleFinished(userId, result.errorOrNull()))
        }
    }
}
