package dev.filip.sotopusers.android.detail

import app.cash.turbine.test
import dev.filip.sotopusers.android.list.UserListIntent
import dev.filip.sotopusers.android.list.UserListStore
import dev.filip.sotopusers.android.mvi.UserMessage
import dev.filip.sotopusers.android.testing.FakeFollowStore
import dev.filip.sotopusers.android.testing.FakeUserApi
import dev.filip.sotopusers.android.testing.TestCore
import dev.filip.sotopusers.android.testing.user
import dev.filip.sotopusers.model.CoreError
import dev.filip.sotopusers.model.Outcome
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Stores run in `backgroundScope` (their observers never complete). Background work is not counted
 * by `advanceUntilIdle`, so tests step the scheduler with `runCurrent` - nothing here uses delays.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class UserDetailStoreTest {
    private val jon = user(22656, "Jon Skeet", location = "Reading", websiteUrl = "http://csharpindepth.com")

    private fun TestScope.core(followStore: FakeFollowStore = FakeFollowStore()) =
        TestCore(FakeUserApi(autoRespond = Outcome.Success(listOf(jon, user(1)))), followStore, StandardTestDispatcher(testScheduler))

    private fun TestScope.detail(core: TestCore) =
        UserDetailStore(backgroundScope, jon, core.toggleFollow, core.repository.followedIdsFlow)

    @Test
    fun `initial follow state comes from the repository`() = runTest {
        val store = detail(core(FakeFollowStore(initial = setOf(jon.id))))
        assertTrue(store.state.value.isFollowed)
        assertEquals(jon, store.state.value.user)
    }

    @Test
    fun `toggle follows with a pending phase, then unfollows`() = runTest {
        val core = core()
        val store = detail(core)
        store.state.test {
            assertFalse(awaitItem().isFollowed)
            store.dispatch(UserDetailIntent.ToggleFollow)
            assertTrue(awaitItem().isTogglePending)
            runCurrent()
            val settled = expectMostRecentItem()
            assertTrue(settled.isFollowed)
            assertFalse(settled.isTogglePending)
        }
        store.dispatch(UserDetailIntent.ToggleFollow)
        runCurrent()
        assertFalse(store.state.value.isFollowed)
        assertEquals(emptySet<Long>(), core.followStore.saved)
    }

    @Test
    fun `rapid toggles while one is in flight are dropped`() = runTest {
        val core = core()
        val store = detail(core)
        repeat(4) { store.dispatch(UserDetailIntent.ToggleFollow) }
        runCurrent()
        assertEquals(1, core.followStore.saveCount)
        assertTrue(store.state.value.isFollowed)
    }

    @Test
    fun `follow failure is surfaced`() = runTest {
        val core = core(FakeFollowStore().apply { failSaves = true })
        val store = detail(core)
        store.dispatch(UserDetailIntent.ToggleFollow)
        runCurrent()
        val message = store.state.value.message
        assertTrue(message is UserMessage.FollowFailed && message.error is CoreError.Storage)
        assertFalse(store.state.value.isFollowed)
        assertFalse(store.state.value.isTogglePending)
        store.dispatch(UserDetailIntent.MessageShown)
        assertNull(store.state.value.message)
    }

    @Test
    fun `list and detail stay in sync through the shared repository flow`() = runTest {
        val core = core()
        val list = UserListStore(backgroundScope, core.getTopUsers, core.toggleFollow, core.sortUsers, core.repository.followedIdsFlow)
        val detail = detail(core)
        runCurrent()

        detail.dispatch(UserDetailIntent.ToggleFollow)
        runCurrent()
        assertEquals(setOf(jon.id), list.state.value.followedIds)

        list.dispatch(UserListIntent.ToggleFollow(jon.id))
        runCurrent()
        assertFalse(detail.state.value.isFollowed)
        assertEquals(emptySet<Long>(), list.state.value.followedIds)
    }
}
