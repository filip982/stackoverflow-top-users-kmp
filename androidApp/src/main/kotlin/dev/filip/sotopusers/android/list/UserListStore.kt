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
fun reduceUserList(state: UserListState, msg: UserListMsg): UserListState = state

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

    override fun dispatch(intent: UserListIntent) {
    }
}
