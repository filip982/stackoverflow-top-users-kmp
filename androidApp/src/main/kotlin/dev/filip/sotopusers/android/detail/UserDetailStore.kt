package dev.filip.sotopusers.android.detail

import dev.filip.sotopusers.android.mvi.Store
import dev.filip.sotopusers.android.mvi.UserMessage
import dev.filip.sotopusers.domain.ToggleFollow
import dev.filip.sotopusers.model.CoreError
import dev.filip.sotopusers.model.User
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
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

fun reduceUserDetail(state: UserDetailState, msg: UserDetailMsg): UserDetailState = when (msg) {
    is UserDetailMsg.FollowedIdsChanged -> state.copy(isFollowed = state.user.id in msg.ids)
    UserDetailMsg.ToggleStarted -> state.copy(isTogglePending = true)
    is UserDetailMsg.ToggleFinished -> state.copy(
        isTogglePending = false,
        message = msg.error?.let { UserMessage.FollowFailed(state.user.id, it) } ?: state.message,
    )
    UserDetailMsg.MessageShown -> state.copy(message = null)
}

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

    init {
        // Follow state is never cached locally: it always mirrors the app-scoped repository.
        scope.launch { followedIds.collect { apply(UserDetailMsg.FollowedIdsChanged(it)) } }
    }

    override fun dispatch(intent: UserDetailIntent) {
        when (intent) {
            UserDetailIntent.ToggleFollow -> {
                if (state.value.isTogglePending) return // rapid-toggle policy: drop taps while in flight
                apply(UserDetailMsg.ToggleStarted)
                val userId = state.value.user.id
                scope.launch { apply(UserDetailMsg.ToggleFinished(toggleFollow(userId).errorOrNull())) }
            }
            UserDetailIntent.MessageShown -> apply(UserDetailMsg.MessageShown)
        }
    }
}
