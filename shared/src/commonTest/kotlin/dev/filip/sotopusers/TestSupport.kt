package dev.filip.sotopusers

import dev.filip.sotopusers.data.FollowStore
import dev.filip.sotopusers.data.UserApiService
import dev.filip.sotopusers.fixtures.Fixtures
import dev.filip.sotopusers.model.CoreError
import dev.filip.sotopusers.model.Outcome
import dev.filip.sotopusers.model.User

const val FIXTURE_BASE_URL = "http://mock.local"

/** The success fixture with the mockserver's base-url placeholder resolved. */
val usersFixture: String get() = Fixtures.users.replace("{{BASE_URL}}", FIXTURE_BASE_URL)

fun user(
    id: Long,
    name: String = "user$id",
    reputation: Long = 0,
    created: Long = 0,
    modified: Long? = null,
) = User(
    id = id,
    displayName = name,
    reputation = reputation,
    avatarUrl = null,
    location = null,
    websiteUrl = null,
    creationDate = created,
    lastModifiedDate = modified,
)

class FakeUserApiService(var result: Outcome<List<User>> = Outcome.Success(emptyList())) : UserApiService {
    var calls = 0
        private set

    override suspend fun fetchTopUsers(): Outcome<List<User>> {
        calls++
        return result
    }
}

class FailingSaveFollowStore(private val initial: Set<Long> = emptySet()) : FollowStore {
    override fun load(): Set<Long> = initial
    override fun save(ids: Set<Long>) = throw CoreError.Storage(IllegalStateException("disk full"))
}
