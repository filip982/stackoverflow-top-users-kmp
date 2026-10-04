package dev.filip.sotopusers.android.detail

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.filip.sotopusers.android.ui.BackNavScaffold
import dev.filip.sotopusers.android.ui.FollowButton
import dev.filip.sotopusers.android.ui.FollowedIndicator
import dev.filip.sotopusers.android.ui.MessageSnackbarEffect
import dev.filip.sotopusers.android.ui.TestTags
import dev.filip.sotopusers.android.ui.UserAvatar
import dev.filip.sotopusers.android.ui.formatReputation

@Composable
fun UserDetailRoute(store: UserDetailStore, onBack: () -> Unit) {
    val state by store.state.collectAsStateWithLifecycle()
    UserDetailScreen(state, store::dispatch, onBack)
}

@Composable
fun UserDetailScreen(state: UserDetailState, onIntent: (UserDetailIntent) -> Unit, onBack: () -> Unit) {
    val user = state.user
    val snackbar = remember { SnackbarHostState() }
    MessageSnackbarEffect(state.message, snackbar) { onIntent(UserDetailIntent.MessageShown) }
    val uriHandler = LocalUriHandler.current

    BackNavScaffold(title = user.displayName, onBack = onBack, snackbar = snackbar) { modifier ->
        Column(
            modifier = modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            UserAvatar(user.avatarUrl, user.displayName, 128.dp)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(user.displayName, style = MaterialTheme.typography.headlineSmall, modifier = Modifier.testTag(TestTags.DETAIL_NAME))
                if (state.isFollowed) FollowedIndicator(Modifier.testTag(TestTags.DETAIL_FOLLOWED_INDICATOR))
            }
            Text(
                "Reputation: ${formatReputation(user.reputation)}",
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.testTag(TestTags.DETAIL_REPUTATION),
            )
            FollowButton(
                isFollowed = state.isFollowed,
                enabled = !state.isTogglePending,
                onClick = { onIntent(UserDetailIntent.ToggleFollow) },
                modifier = Modifier.testTag(TestTags.DETAIL_FOLLOW),
            )
            Spacer(Modifier.height(8.dp))
            user.location?.let { location ->
                LabeledValue("Location", location, Modifier.testTag(TestTags.DETAIL_LOCATION))
            }
            user.websiteUrl?.let { url ->
                LabeledValue(
                    label = "Website",
                    value = url,
                    isLink = true,
                    modifier = Modifier
                        .testTag(TestTags.DETAIL_WEBSITE)
                        .clickable { runCatching { uriHandler.openUri(url) } },
                )
            }
        }
    }
}

@Composable
private fun LabeledValue(label: String, value: String, modifier: Modifier = Modifier, isLink: Boolean = false) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(
            value,
            style = MaterialTheme.typography.bodyLarge,
            color = if (isLink) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
            textDecoration = if (isLink) TextDecoration.Underline else null,
        )
    }
}
