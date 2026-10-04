package dev.filip.sotopusers.data

import app.cash.turbine.test
import com.russhwolf.settings.MapSettings
import dev.filip.sotopusers.FailingSaveFollowStore
import dev.filip.sotopusers.FakeUserApiService
import dev.filip.sotopusers.model.CoreError
import dev.filip.sotopusers.model.Outcome
import dev.filip.sotopusers.user
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withContext
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertSame

@OptIn(ExperimentalCoroutinesApi::class)
class UserRepositoryTest {
    private val settings = MapSettings()
    private val api = FakeUserApiService()
    private fun repository(store: FollowStore = SettingsFollowStore(settings)) = UserRepository(api, store)

    @Test fun startsFromPersistedFollows() {
        SettingsFollowStore(settings).save(setOf(3L, 4L))
        val repo = repository()
        assertEquals(setOf(3L, 4L), repo.followedIds())
        assertEquals(setOf(3L, 4L), repo.followedIdsFlow.value)
        assertNull(repo.startupStorageError)
    }

    @Test fun toggleFollowsThenUnfollowsAndPersists() = runTest {
        val repo = repository()
        assertEquals(Outcome.Success(true), repo.toggleFollow(7))
        assertEquals(setOf(7L), repo.followedIds())
        assertEquals(setOf(7L), SettingsFollowStore(settings).load())
        assertEquals(Outcome.Success(false), repo.toggleFollow(7))
        assertEquals(emptySet(), repo.followedIds())
        assertEquals(emptySet(), SettingsFollowStore(settings).load())
    }

    @Test fun flowEmitsEveryFollowChange() = runTest {
        val repo = repository()
        repo.followedIdsFlow.test {
            assertEquals(emptySet(), awaitItem())
            repo.toggleFollow(1)
            assertEquals(setOf(1L), awaitItem())
            repo.toggleFollow(2)
            assertEquals(setOf(1L, 2L), awaitItem())
            repo.toggleFollow(1)
            assertEquals(setOf(2L), awaitItem())
        }
    }

    @Test fun rapidConcurrentTogglesAreSerialized() = runTest {
        val repo = repository()
        withContext(Dispatchers.Default) {
            // 101 toggles of id 1 (odd -> followed), 100 of id 2 (even -> not followed), interleaved.
            (List(101) { 1L } + List(100) { 2L }).shuffled()
                .map { id -> async { repo.toggleFollow(id) } }
                .awaitAll()
        }
        assertEquals(setOf(1L), repo.followedIds())
        assertEquals(setOf(1L), SettingsFollowStore(settings).load())
    }

    @Test fun freshInstanceReloadsPersistedFollows() = runTest {
        val first = repository()
        first.toggleFollow(5)
        first.toggleFollow(7)
        first.toggleFollow(9)
        first.toggleFollow(9)
        assertEquals(setOf(5L, 7L), repository().followedIds())
    }

    @Test fun corruptPersistedStateResetsToEmptyAndSurfacesStorageError() = runTest {
        settings.putString(SettingsFollowStore.DEFAULT_KEY, "garbage!")
        val repo = repository()
        assertNotNull(repo.startupStorageError)
        assertEquals(emptySet(), repo.followedIds())
        // Store was reset, so the next instance starts clean without an error.
        assertEquals(emptySet(), SettingsFollowStore(settings).load())
        assertEquals(Outcome.Success(true), repo.toggleFollow(1))
        assertNull(repository().startupStorageError)
    }

    @Test fun failedSaveLeavesStateUnchangedAndReturnsStorageError() = runTest {
        val repo = repository(FailingSaveFollowStore(initial = setOf(1L)))
        repo.followedIdsFlow.test {
            assertEquals(setOf(1L), awaitItem())
            assertIs<CoreError.Storage>(repo.toggleFollow(2).errorOrNull())
            assertIs<CoreError.Storage>(repo.toggleFollow(1).errorOrNull())
            expectNoEvents()
        }
        assertEquals(setOf(1L), repo.followedIds())
    }

    @Test fun getTopUsersDelegatesToApi() = runTest {
        val users = listOf(user(1), user(2))
        api.result = Outcome.Success(users)
        assertEquals(Outcome.Success(users), repository().getTopUsers())
        val failure = Outcome.Failure(CoreError.Http(500))
        api.result = failure
        assertSame(failure, repository().getTopUsers())
    }

    @Test fun watchFollowedIdsDeliversCurrentAndChangesUntilCancelled() = runTest {
        val repo = UserRepository(api, SettingsFollowStore(settings), UnconfinedTestDispatcher(testScheduler))
        val received = Channel<Set<Long>>(Channel.UNLIMITED)
        val handle = repo.watchFollowedIds { received.trySend(it) }
        assertEquals(emptySet(), received.receive())
        repo.toggleFollow(3)
        assertEquals(setOf(3L), received.receive())
        handle.cancel()
        repo.toggleFollow(4)
        assertNull(received.tryReceive().getOrNull())
    }
}
