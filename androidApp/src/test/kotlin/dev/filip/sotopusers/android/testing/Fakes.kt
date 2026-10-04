package dev.filip.sotopusers.android.testing

import dev.filip.sotopusers.data.FollowStore
import dev.filip.sotopusers.data.UserApiService
import dev.filip.sotopusers.data.UserRepository
import dev.filip.sotopusers.domain.GetTopUsers
import dev.filip.sotopusers.domain.SortUsers
import dev.filip.sotopusers.domain.ToggleFollow
import dev.filip.sotopusers.model.CoreError
import dev.filip.sotopusers.model.Outcome
import dev.filip.sotopusers.model.User
import kotlinx.coroutines.CompletableDeferred
import kotlin.coroutines.CoroutineContext

/**
 * Fake service layer under the *real* shared repository and use cases, so store tests exercise the
 * production business logic and only the I/O edges are faked.
 *
 * Each `fetchTopUsers` call gets its own [CompletableDeferred] (see [calls]) unless [autoRespond]
 * is set, so tests control completion order explicitly.
 */
class FakeUserApi(var autoRespond: Outcome<List<User>>? = null) : UserApiService {
    val calls = mutableListOf<CompletableDeferred<Outcome<List<User>>>>()

    override suspend fun fetchTopUsers(): Outcome<List<User>> {
        val deferred = CompletableDeferred<Outcome<List<User>>>()
        autoRespond?.let { deferred.complete(it) }
        calls += deferred
        return deferred.await()
    }

    fun respond(index: Int, outcome: Outcome<List<User>>) {
        calls[index].complete(outcome)
    }
}

class FakeFollowStore(initial: Set<Long> = emptySet(), var loadError: Exception? = null) : FollowStore {
    var saved: Set<Long> = initial
    var saveCount = 0
    var failSaves = false

    override fun load(): Set<Long> {
        loadError?.let { throw it }
        return saved
    }

    override fun save(ids: Set<Long>) {
        if (failSaves) throw CoreError.Storage(IllegalStateException("disk full"))
        saveCount++
        saved = ids
    }
}

/** The shared core assembled over fakes; mirrors what [dev.filip.sotopusers.StackOverflowCore] wires. */
class TestCore(
    val api: FakeUserApi = FakeUserApi(),
    val followStore: FakeFollowStore = FakeFollowStore(),
    observerContext: CoroutineContext,
) {
    val repository = UserRepository(api, followStore, observerContext)
    val getTopUsers = GetTopUsers(repository)
    val toggleFollow = ToggleFollow(repository)
    val sortUsers = SortUsers()
}

fun user(
    id: Long,
    name: String = "User $id",
    reputation: Long = id * 100,
    creationDate: Long = 1_000_000 + id,
    lastModifiedDate: Long? = 2_000_000 + id,
    location: String? = null,
    websiteUrl: String? = null,
) = User(id, name, reputation, avatarUrl = null, location = location, websiteUrl = websiteUrl, creationDate = creationDate, lastModifiedDate = lastModifiedDate)
