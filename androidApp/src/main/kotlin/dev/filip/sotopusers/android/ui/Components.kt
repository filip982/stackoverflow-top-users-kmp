package dev.filip.sotopusers.android.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.painter.ColorPainter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import dev.filip.sotopusers.android.mvi.UserMessage
import dev.filip.sotopusers.model.CoreError

@Composable
fun UserAvatar(url: String?, name: String, size: Dp, modifier: Modifier = Modifier) {
    val placeholder = ColorPainter(MaterialTheme.colorScheme.surfaceVariant)
    AsyncImage(
        model = ImageRequest.Builder(LocalContext.current).data(url).crossfade(true).build(),
        contentDescription = "Avatar of $name",
        placeholder = placeholder,
        error = placeholder,
        fallback = placeholder,
        contentScale = ContentScale.Crop,
        modifier = modifier.size(size).clip(CircleShape),
    )
}

@Composable
fun FollowButton(isFollowed: Boolean, enabled: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier) {
    if (isFollowed) {
        OutlinedButton(onClick = onClick, enabled = enabled, modifier = modifier) { Text("Unfollow") }
    } else {
        Button(onClick = onClick, enabled = enabled, modifier = modifier) { Text("Follow") }
    }
}

@Composable
fun FollowedIndicator(modifier: Modifier = Modifier) {
    Icon(
        imageVector = Icons.Filled.Star,
        contentDescription = "Followed",
        tint = MaterialTheme.colorScheme.primary,
        modifier = modifier.size(18.dp),
    )
}

/** Full-screen notice with an optional action (error and empty states). */
@Composable
fun MessageState(
    title: String,
    body: String,
    actionLabel: String,
    onAction: () -> Unit,
    modifier: Modifier = Modifier,
    actionModifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxSize().padding(32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(title, style = MaterialTheme.typography.titleLarge, textAlign = TextAlign.Center)
        Spacer(Modifier.height(8.dp))
        Text(body, style = MaterialTheme.typography.bodyMedium, textAlign = TextAlign.Center)
        Spacer(Modifier.height(24.dp))
        Button(onClick = onAction, modifier = actionModifier) { Text(actionLabel) }
    }
}

/** Shows [message] once in a snackbar, then reports it consumed via [onShown]. */
@Composable
fun MessageSnackbarEffect(message: UserMessage?, host: SnackbarHostState, onShown: () -> Unit) {
    val currentOnShown = rememberUpdatedState(onShown)
    LaunchedEffect(message) {
        if (message != null) {
            host.showSnackbar(userMessageText(message))
            currentOnShown.value()
        }
    }
}

fun coreErrorText(error: CoreError): String = when (error) {
    is CoreError.Network -> "Can't reach Stack Overflow. Check your connection and try again."
    is CoreError.Http -> "Stack Overflow returned an error (HTTP ${error.code})." +
        (error.apiMessage?.let { "\n$it" } ?: "")
    is CoreError.Decoding -> "Received an unexpected response from Stack Overflow."
    is CoreError.Storage -> "Couldn't save your follow changes on this device."
}

fun userMessageText(message: UserMessage): String = when (message) {
    is UserMessage.FollowFailed -> "Couldn't update follow. ${coreErrorText(message.error)}"
    is UserMessage.FollowStateReset -> "Your saved follows could not be read and were reset."
}

fun formatReputation(reputation: Long): String = "%,d".format(reputation)
