package dev.filip.sotopusers.android.sort

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.filip.sotopusers.android.ui.BackNavScaffold
import dev.filip.sotopusers.android.ui.TestTags
import dev.filip.sotopusers.model.SortDirection
import dev.filip.sotopusers.model.SortField
import dev.filip.sotopusers.model.SortOption

@Composable
fun SortOptionsRoute(store: SortOptionsStore, onApplied: (SortOption) -> Unit, onDismissed: () -> Unit) {
    val state by store.state.collectAsStateWithLifecycle()
    val applied by rememberUpdatedState(onApplied)
    val dismissed by rememberUpdatedState(onDismissed)
    LaunchedEffect(store) {
        store.effects.collect { effect ->
            when (effect) {
                is SortOptionsEffect.Applied -> applied(effect.option)
                SortOptionsEffect.Dismissed -> dismissed()
            }
        }
    }
    SortOptionsScreen(state, store::dispatch)
}

private val SortField.label: String
    get() = when (this) {
        SortField.REPUTATION -> "Reputation"
        SortField.NAME -> "Name"
        SortField.CREATION -> "Date created"
        SortField.MODIFIED -> "Date updated"
    }

@Composable
fun SortOptionsScreen(state: SortOptionsState, onIntent: (SortOptionsIntent) -> Unit) {
    // System back behaves like Cancel: the draft is discarded.
    BackHandler { onIntent(SortOptionsIntent.Cancel) }

    BackNavScaffold(
        title = "Sort users",
        onBack = { onIntent(SortOptionsIntent.Cancel) },
        bottomBar = {
            // Pinned so Apply/Cancel stay reachable however small the screen is.
            Row(
                Modifier.fillMaxWidth().navigationBarsPadding().padding(16.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                OutlinedButton(
                    onClick = { onIntent(SortOptionsIntent.Cancel) },
                    modifier = Modifier.weight(1f).testTag(TestTags.SORT_CANCEL),
                ) { Text("Cancel") }
                Button(
                    onClick = { onIntent(SortOptionsIntent.Apply) },
                    modifier = Modifier.weight(1f).testTag(TestTags.SORT_APPLY),
                ) { Text("Apply") }
            }
        },
    ) { modifier ->
        Column(modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
            Text("Sort by", style = MaterialTheme.typography.titleMedium)
            Column(Modifier.selectableGroup()) {
                SortField.entries.forEach { field ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(52.dp)
                            .selectable(
                                selected = state.draft.field == field,
                                onClick = { onIntent(SortOptionsIntent.SelectField(field)) },
                                role = Role.RadioButton,
                            )
                            .testTag(TestTags.sortField(field.name)),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        RadioButton(selected = state.draft.field == field, onClick = null)
                        Text(field.label, Modifier.padding(start = 12.dp))
                    }
                }
            }

            Spacer(Modifier.height(16.dp))
            Text("Order", style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(8.dp))
            // Ascending/descending toggle: a two-option selectable group.
            Row(Modifier.fillMaxWidth().selectableGroup(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                listOf(SortDirection.ASC to "Ascending", SortDirection.DESC to "Descending").forEach { (direction, label) ->
                    Row(
                        modifier = Modifier
                            .weight(1f)
                            .height(52.dp)
                            .selectable(
                                selected = state.draft.direction == direction,
                                onClick = { onIntent(SortOptionsIntent.SelectDirection(direction)) },
                                role = Role.RadioButton,
                            )
                            .testTag(if (direction == SortDirection.ASC) TestTags.SORT_DIRECTION_ASC else TestTags.SORT_DIRECTION_DESC),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        RadioButton(selected = state.draft.direction == direction, onClick = null)
                        Text(label, Modifier.padding(start = 12.dp))
                    }
                }
            }
        }
    }
}
