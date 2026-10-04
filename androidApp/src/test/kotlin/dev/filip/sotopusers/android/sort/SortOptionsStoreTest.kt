package dev.filip.sotopusers.android.sort

import app.cash.turbine.test
import dev.filip.sotopusers.model.SortDirection
import dev.filip.sotopusers.model.SortField
import dev.filip.sotopusers.model.SortOption
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

class SortOptionsStoreTest {
    private val committed = SortOption.Default // reputation, descending

    @Test
    fun `defaults to reputation descending with draft equal to committed`() = runTest {
        val store = SortOptionsStore(backgroundScope, committed)
        assertEquals(SortOptionsState(committed, committed), store.state.value)
        assertEquals(SortField.REPUTATION, store.state.value.draft.field)
        assertEquals(SortDirection.DESC, store.state.value.draft.direction)
    }

    @Test
    fun `edits change only the draft`() = runTest {
        val store = SortOptionsStore(backgroundScope, committed)
        store.dispatch(SortOptionsIntent.SelectField(SortField.CREATION))
        store.dispatch(SortOptionsIntent.SelectDirection(SortDirection.ASC))
        assertEquals(SortOption(SortField.CREATION, SortDirection.ASC), store.state.value.draft)
        assertEquals(committed, store.state.value.committed)
    }

    @Test
    fun `cancel discards the draft and never applies`() = runTest {
        val store = SortOptionsStore(backgroundScope, committed)
        store.effects.test {
            store.dispatch(SortOptionsIntent.SelectField(SortField.NAME))
            store.dispatch(SortOptionsIntent.Cancel)
            assertEquals(SortOptionsEffect.Dismissed, awaitItem())
            expectNoEvents()
        }
        assertEquals(SortOptionsState(committed, committed), store.state.value)
    }

    @Test
    fun `apply commits the draft and emits it`() = runTest {
        val store = SortOptionsStore(backgroundScope, committed)
        val chosen = SortOption(SortField.MODIFIED, SortDirection.ASC)
        store.effects.test {
            store.dispatch(SortOptionsIntent.SelectField(SortField.MODIFIED))
            store.dispatch(SortOptionsIntent.SelectDirection(SortDirection.ASC))
            store.dispatch(SortOptionsIntent.Apply)
            assertEquals(SortOptionsEffect.Applied(chosen), awaitItem())
        }
        assertEquals(SortOptionsState(chosen, chosen), store.state.value)
    }

    @Test
    fun `reducer resets the draft to committed on Cancel`() {
        val edited = SortOptionsState(committed, SortOption(SortField.NAME, SortDirection.ASC))
        assertEquals(SortOptionsState(committed, committed), reduceSortOptions(edited, SortOptionsIntent.Cancel))
    }
}
