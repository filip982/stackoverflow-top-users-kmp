package dev.filip.sotopusers.domain

import com.russhwolf.settings.MapSettings
import dev.filip.sotopusers.FakeUserApiService
import dev.filip.sotopusers.data.SettingsFollowStore
import dev.filip.sotopusers.data.UserRepository
import dev.filip.sotopusers.model.CoreError
import dev.filip.sotopusers.model.Outcome
import dev.filip.sotopusers.model.SortDirection
import dev.filip.sotopusers.model.SortField
import dev.filip.sotopusers.model.SortOption
import dev.filip.sotopusers.user
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertSame

class UseCasesTest {
    private val api = FakeUserApiService()
    private val repository = UserRepository(api, SettingsFollowStore(MapSettings()))

    @Test fun getTopUsersSortsByDefaultOption() = runTest {
        api.result = Outcome.Success(listOf(user(1, reputation = 1), user(2, reputation = 3), user(3, reputation = 2)))
        assertEquals(listOf(2L, 3L, 1L), GetTopUsers(repository)().getOrNull()!!.map { it.id })
    }

    @Test fun getTopUsersAppliesRequestedSort() = runTest {
        api.result = Outcome.Success(listOf(user(1, name = "b"), user(2, name = "c"), user(3, name = "a")))
        val result = GetTopUsers(repository)(SortOption(SortField.NAME, SortDirection.ASC))
        assertEquals(listOf(3L, 1L, 2L), result.getOrNull()!!.map { it.id })
    }

    @Test fun getTopUsersPassesFailuresThrough() = runTest {
        val failure = Outcome.Failure(CoreError.Network())
        api.result = failure
        assertSame(failure, GetTopUsers(repository)())
    }

    @Test fun toggleFollowUpdatesRepository() = runTest {
        val toggle = ToggleFollow(repository)
        assertEquals(Outcome.Success(true), toggle(42))
        assertEquals(setOf(42L), repository.followedIds())
        assertEquals(Outcome.Success(false), toggle(42))
        assertEquals(emptySet(), repository.followedIds())
    }
}
