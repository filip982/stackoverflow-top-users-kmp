package dev.filip.sotopusers.android.list

import app.cash.turbine.test
import dev.filip.sotopusers.android.StartupNotice
import dev.filip.sotopusers.android.mvi.UserMessage
import dev.filip.sotopusers.android.testing.FakeFollowStore
import dev.filip.sotopusers.android.testing.FakeUserApi
import dev.filip.sotopusers.android.testing.TestCore
import dev.filip.sotopusers.android.testing.user
import dev.filip.sotopusers.model.CoreError
import dev.filip.sotopusers.model.Outcome
import dev.filip.sotopusers.model.SortDirection
import dev.filip.sotopusers.model.SortField
import dev.filip.sotopusers.model.SortOption
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Stores run in `backgroundScope` (their observers never complete). Background work is not counted
 * by `advanceUntilIdle`, so tests step the scheduler with `runCurrent` - nothing here uses delays.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class UserListStoreTest {
    private val users = listOf(user(1, "Carol", reputation = 300), user(2, "alice", reputation = 900), user(3, "Bob", reputation = 500))

    private fun TestScope.newStore(core: TestCore, startupError: CoreError.Storage? = null) = UserListStore(
        scope = backgroundScope,
        getTopUsers = core.getTopUsers,
        toggleFollow = core.toggleFollow,
        sortUsers = core.sortUsers,
        followedIds = core.repository.followedIdsFlow,
        startupStorageError = startupError,
    )

    private fun TestScope.core(
        api: FakeUserApi = FakeUserApi(),
        followStore: FakeFollowStore = FakeFollowStore(),
    ) = TestCore(api, followStore, StandardTestDispatcher(testScheduler))

    @Test
    fun `initial load goes Loading then Content sorted by reputation desc`() = runTest {
        val core = core()
        val store = newStore(core)
        store.state.test {
            assertEquals(ListStatus.Loading, awaitItem().status)
            runCurrent()
            core.api.respond(0, Outcome.Success(users))
            val loaded = awaitItem()
            assertEquals(ListStatus.Content, loaded.status)
            assertEquals(listOf(2L, 3L, 1L), loaded.users.map { it.id })
        }
    }

    @Test
    fun `empty success is Empty, not an error`() = runTest {
        val core = core(FakeUserApi(autoRespond = Outcome.Success(emptyList())))
        val store = newStore(core)
        runCurrent()
        assertEquals(ListStatus.Empty, store.state.value.status)
        assertTrue(store.state.value.users.isEmpty())
    }

    @Test
    fun `failure is Failed with the typed core error`() = runTest {
        val error = CoreError.Http(400, "throttle_violation")
        val core = core(FakeUserApi(autoRespond = Outcome.Failure(error)))
        val store = newStore(core)
        runCurrent()
        assertEquals(ListStatus.Failed(error), store.state.value.status)
    }

    @Test
    fun `retry after an error recovers to Content`() = runTest {
        val core = core()
        val store = newStore(core)
        runCurrent()
        core.api.respond(0, Outcome.Failure(CoreError.Network()))
        runCurrent()
        assertTrue(store.state.value.status is ListStatus.Failed)

        store.dispatch(UserListIntent.Retry)
        assertEquals(ListStatus.Loading, store.state.value.status)
        runCurrent()
        core.api.respond(1, Outcome.Success(users))
        runCurrent()
        assertEquals(ListStatus.Content, store.state.value.status)
        assertEquals(3, store.state.value.users.size)
    }

    @Test
    fun `stale completion of an older request is suppressed - latest request wins`() = runTest {
        val core = core()
        val store = newStore(core)
        runCurrent()
        store.dispatch(UserListIntent.Retry)
        runCurrent()
        assertEquals(2, core.api.calls.size)

        core.api.respond(1, Outcome.Failure(CoreError.Network()))
        runCurrent()
        // The first (older) request completes last, with data: it must not overwrite the newer result.
        core.api.respond(0, Outcome.Success(users))
        runCurrent()
        assertTrue(store.state.value.status is ListStatus.Failed)
        assertTrue(store.state.value.users.isEmpty())
    }

    @Test
    fun `reducer ignores LoadFinished for a request that is no longer active`() {
        val state = UserListState(status = ListStatus.Loading, activeRequestId = 2)
        val next = reduceUserList(state, UserListMsg.LoadFinished(1, Outcome.Success(users)))
        assertEquals(state, next)
    }

    @Test
    fun `rapid toggles on the same user while one is in flight are dropped`() = runTest {
        val core = core(FakeUserApi(autoRespond = Outcome.Success(users)))
        val store = newStore(core)
        runCurrent()

        store.dispatch(UserListIntent.ToggleFollow(1))
        store.dispatch(UserListIntent.ToggleFollow(1))
        store.dispatch(UserListIntent.ToggleFollow(1))
        assertEquals(setOf(1L), store.state.value.pendingFollowIds)
        runCurrent()

        assertEquals(1, core.followStore.saveCount)
        assertEquals(setOf(1L), store.state.value.followedIds)
        assertTrue(store.state.value.pendingFollowIds.isEmpty())

        // Once settled, the next tap toggles again.
        store.dispatch(UserListIntent.ToggleFollow(1))
        runCurrent()
        assertEquals(emptySet<Long>(), store.state.value.followedIds)
        assertEquals(emptySet<Long>(), core.followStore.saved)
    }

    @Test
    fun `rapid toggles on different users are all applied`() = runTest {
        val core = core(FakeUserApi(autoRespond = Outcome.Success(users)))
        val store = newStore(core)
        runCurrent()
        store.dispatch(UserListIntent.ToggleFollow(1))
        store.dispatch(UserListIntent.ToggleFollow(2))
        store.dispatch(UserListIntent.ToggleFollow(3))
        runCurrent()
        assertEquals(setOf(1L, 2L, 3L), store.state.value.followedIds)
        assertEquals(setOf(1L, 2L, 3L), core.followStore.saved)
    }

    @Test
    fun `follow failure is surfaced and follow state is unchanged`() = runTest {
        val core = core(FakeUserApi(autoRespond = Outcome.Success(users)), FakeFollowStore().apply { failSaves = true })
        val store = newStore(core)
        runCurrent()

        store.dispatch(UserListIntent.ToggleFollow(2))
        runCurrent()

        val state = store.state.value
        val message = state.message
        assertTrue(message is UserMessage.FollowFailed && message.userId == 2L && message.error is CoreError.Storage)
        assertTrue(state.followedIds.isEmpty())
        assertTrue(state.pendingFollowIds.isEmpty())

        store.dispatch(UserListIntent.MessageShown)
        assertNull(store.state.value.message)
    }

    @Test
    fun `startup storage error is surfaced once per process`() = runTest {
        val core = core(followStore = FakeFollowStore(loadError = IllegalStateException("corrupt")))
        val notice = StartupNotice(core.repository.startupStorageError)

        val first = newStore(core, notice.take())
        assertTrue(first.state.value.message is UserMessage.FollowStateReset)
        first.dispatch(UserListIntent.MessageShown)
        assertNull(first.state.value.message)

        // A later store (e.g. the screen re-created) does not show it again.
        val second = newStore(core, notice.take())
        assertNull(second.state.value.message)
    }

    @Test
    fun `applying a sort re-sorts loaded users without refetching`() = runTest {
        val core = core(FakeUserApi(autoRespond = Outcome.Success(users)))
        val store = newStore(core)
        runCurrent()

        val byName = SortOption(SortField.NAME, SortDirection.ASC)
        store.dispatch(UserListIntent.ApplySort(byName))
        assertEquals(byName, store.state.value.sort)
        assertEquals(listOf("alice", "Bob", "Carol"), store.state.value.users.map { it.displayName })
        assertEquals(1, core.api.calls.size)
    }

    @Test
    fun `a sort applied while loading is honoured by the load result`() = runTest {
        val core = core()
        val store = newStore(core)
        runCurrent()
        store.dispatch(UserListIntent.ApplySort(SortOption(SortField.REPUTATION, SortDirection.ASC)))
        core.api.respond(0, Outcome.Success(users))
        runCurrent()
        assertEquals(listOf(1L, 3L, 2L), store.state.value.users.map { it.id })
    }
}
