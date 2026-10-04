package dev.filip.sotopusers.android.detail

import dev.filip.sotopusers.android.mvi.Store
import dev.filip.sotopusers.android.mvi.UserMessage
import dev.filip.sotopusers.domain.ToggleFollow
import dev.filip.sotopusers.model.CoreError
import dev.filip.sotopusers.model.User
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.StateFlow

data class UserDetailState(
    val user: User,
    val isFollowed: Boolean = false,
    val isTogglePending: Boolean = false,
    val message: UserMessage? = null,
)

sealed interface UserDetailIntent {
    data object ToggleFollow : UserDetailIntent
    data object MessageShown : UserDetailIntent
}

sealed interface UserDetailMsg {
    data class FollowedIdsChanged(val ids: Set<Long>) : UserDetailMsg
    data object ToggleStarted : UserDetailMsg
    data class ToggleFinished(val error: CoreError?) : UserDetailMsg
    data object MessageShown : UserDetailMsg
}

fun reduceUserDetail(state: UserDetailState, msg: UserDetailMsg): UserDetailState = state

class UserDetailStore(
    scope: CoroutineScope,
    user: User,
    private val toggleFollow: ToggleFollow,
    followedIds: StateFlow<Set<Long>>,
) : Store<UserDetailState, UserDetailIntent, UserDetailMsg, Nothing>(
    UserDetailState(user = user, isFollowed = user.id in followedIds.value),
    scope,
) {
    override fun reduce(state: UserDetailState, message: UserDetailMsg) = reduceUserDetail(state, message)

    override fun dispatch(intent: UserDetailIntent) {
    }
}
