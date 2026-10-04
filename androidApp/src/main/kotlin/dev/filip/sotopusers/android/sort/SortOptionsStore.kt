package dev.filip.sotopusers.android.sort

import dev.filip.sotopusers.android.mvi.Store
import dev.filip.sotopusers.model.SortDirection
import dev.filip.sotopusers.model.SortField
import dev.filip.sotopusers.model.SortOption
import kotlinx.coroutines.CoroutineScope

/** [committed] is what the list currently uses; edits only touch [draft] until Apply. */
data class SortOptionsState(
    val committed: SortOption,
    val draft: SortOption = committed,
)

sealed interface SortOptionsIntent {
    data class SelectField(val field: SortField) : SortOptionsIntent
    data class SelectDirection(val direction: SortDirection) : SortOptionsIntent
    data object Apply : SortOptionsIntent
    data object Cancel : SortOptionsIntent
}

sealed interface SortOptionsEffect {
    data class Applied(val option: SortOption) : SortOptionsEffect
    data object Dismissed : SortOptionsEffect
}

fun reduceSortOptions(state: SortOptionsState, intent: SortOptionsIntent): SortOptionsState = state

class SortOptionsStore(
    scope: CoroutineScope,
    initial: SortOption,
) : Store<SortOptionsState, SortOptionsIntent, SortOptionsIntent, SortOptionsEffect>(SortOptionsState(initial), scope) {
    override fun reduce(state: SortOptionsState, message: SortOptionsIntent) = reduceSortOptions(state, message)

    override fun dispatch(intent: SortOptionsIntent) {
    }
}
