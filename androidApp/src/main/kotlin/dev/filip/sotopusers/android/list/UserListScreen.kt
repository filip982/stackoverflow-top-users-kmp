package dev.filip.sotopusers.android.list

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.filip.sotopusers.android.ui.FollowButton
import dev.filip.sotopusers.android.ui.FollowedIndicator
import dev.filip.sotopusers.android.ui.MessageSnackbarEffect
import dev.filip.sotopusers.android.ui.MessageState
import dev.filip.sotopusers.android.ui.TestTags
import dev.filip.sotopusers.android.ui.UserAvatar
import dev.filip.sotopusers.android.ui.coreErrorText
import dev.filip.sotopusers.android.ui.formatReputation
import dev.filip.sotopusers.model.User

@Composable
fun UserListRoute(store: UserListStore, onUserClick: (User) -> Unit, onSortClick: () -> Unit) {
    val state by store.state.collectAsStateWithLifecycle()
    UserListScreen(state, store::dispatch, onUserClick, onSortClick)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UserListScreen(
    state: UserListState,
    onIntent: (UserListIntent) -> Unit,
    onUserClick: (User) -> Unit,
    onSortClick: () -> Unit,
) {
    val snackbar = remember { SnackbarHostState() }
    MessageSnackbarEffect(state.message, snackbar) { onIntent(UserListIntent.MessageShown) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Top Stack Overflow users") },
                actions = {
                    TextButton(onClick = onSortClick, modifier = Modifier.testTag(TestTags.SORT_BUTTON)) { Text("Sort") }
                },
            )
        },
        snackbarHost = { SnackbarHost(snackbar) },
    ) { padding ->
        val modifier = Modifier.padding(padding)
        when (val status = state.status) {
            ListStatus.Loading -> Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(Modifier.testTag(TestTags.LOADING))
            }
            is ListStatus.Failed -> MessageState(
                title = "Couldn't load users",
                body = coreErrorText(status.error),
                actionLabel = "Retry",
                onAction = { onIntent(UserListIntent.Retry) },
                modifier = modifier.testTag(TestTags.ERROR_STATE),
                actionModifier = Modifier.testTag(TestTags.RETRY),
            )
            ListStatus.Empty -> MessageState(
                title = "No users found",
                body = "Stack Overflow returned an empty list.",
                actionLabel = "Reload",
                onAction = { onIntent(UserListIntent.Retry) },
                modifier = modifier.testTag(TestTags.EMPTY_STATE),
                actionModifier = Modifier.testTag(TestTags.RETRY),
            )
            ListStatus.Content -> LazyColumn(modifier.fillMaxSize().testTag(TestTags.USER_LIST)) {
                items(state.users, key = { it.id }) { user ->
                    UserRow(
                        user = user,
                        isFollowed = user.id in state.followedIds,
                        isPending = user.id in state.pendingFollowIds,
                        onClick = { onUserClick(user) },
                        onToggleFollow = { onIntent(UserListIntent.ToggleFollow(user.id)) },
                    )
                    HorizontalDivider()
                }
            }
        }
    }
}

@Composable
private fun UserRow(
    user: User,
    isFollowed: Boolean,
    isPending: Boolean,
    onClick: () -> Unit,
    onToggleFollow: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp)
            .testTag(TestTags.userRow(user.id)),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        UserAvatar(user.avatarUrl, user.displayName, 48.dp)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    user.displayName,
                    style = MaterialTheme.typography.titleMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false),
                )
                if (isFollowed) FollowedIndicator(Modifier.testTag(TestTags.followedIndicator(user.id)))
            }
            Text(
                "Reputation: ${formatReputation(user.reputation)}",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Spacer(Modifier.width(8.dp))
        FollowButton(
            isFollowed = isFollowed,
            enabled = !isPending,
            onClick = onToggleFollow,
            modifier = Modifier.testTag(TestTags.followButton(user.id)),
        )
    }
}
