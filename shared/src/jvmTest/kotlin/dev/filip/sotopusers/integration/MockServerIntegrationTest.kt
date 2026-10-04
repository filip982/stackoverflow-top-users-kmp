package dev.filip.sotopusers.integration

import com.russhwolf.settings.MapSettings
import dev.filip.sotopusers.data.KtorUserApiService
import dev.filip.sotopusers.data.SettingsFollowStore
import dev.filip.sotopusers.data.UserRepository
import dev.filip.sotopusers.data.createPlatformHttpClient
import dev.filip.sotopusers.domain.GetTopUsers
import dev.filip.sotopusers.domain.ToggleFollow
import dev.filip.sotopusers.mockserver.MockServer
import dev.filip.sotopusers.mockserver.Scenario
import dev.filip.sotopusers.model.CoreError
import dev.filip.sotopusers.model.Outcome
import dev.filip.sotopusers.model.SortDirection
import dev.filip.sotopusers.model.SortField
import dev.filip.sotopusers.model.SortOption
import dev.filip.sotopusers.model.User
import kotlinx.coroutines.runBlocking
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue

/** Real Ktor CIO client against a real mockserver on an ephemeral port (socket level). One server per test. */
class MockServerIntegrationTest {
    private val servers = mutableListOf<MockServer>()

    private fun server(scenario: Scenario = Scenario.SUCCESS) =
        MockServer(defaultScenario = scenario, slowDelayMillis = 2_000).start().also { servers += it }

    private fun api(baseUrl: String, timeoutMs: Long = 5_000) = KtorUserApiService(baseUrl, createPlatformHttpClient(timeoutMs))

    @AfterTest fun tearDown() = servers.forEach { runCatching { it.stop() } }

    @Test fun successDecodesFixtureOverTheWire() = runBlocking<Unit> {
        val server = server()
        val users = assertIs<Outcome.Success<List<User>>>(api(server.baseUrl).fetchTopUsers()).value
        assertEquals(20, users.size)
        assertEquals("Günter Zöchbauer", users.single { it.id == 217408L }.displayName)
        assertEquals("${server.baseUrl}/avatars/22656.png", users.first().avatarUrl)
    }

    @Test fun httpErrorCarriesStatusAndApiMessage() = runBlocking<Unit> {
        val error = assertIs<CoreError.Http>(api(server(Scenario.ERROR).baseUrl).fetchTopUsers().errorOrNull())
        assertEquals(400, error.code)
        assertTrue(error.apiMessage.orEmpty().startsWith("too many requests"))
    }

    @Test fun emptyIsSuccessWithNoUsers() = runBlocking<Unit> {
        assertEquals(Outcome.Success(emptyList()), api(server(Scenario.EMPTY).baseUrl).fetchTopUsers())
    }

    @Test fun malformedBodyIsDecodingError() = runBlocking<Unit> {
        assertIs<CoreError.Decoding>(api(server(Scenario.MALFORMED).baseUrl).fetchTopUsers().errorOrNull())
    }

    @Test fun slowResponseBeyondTimeoutIsNetworkError() = runBlocking<Unit> {
        assertIs<CoreError.Network>(api(server(Scenario.SLOW).baseUrl, timeoutMs = 300).fetchTopUsers().errorOrNull())
    }

    @Test fun connectionRefusedIsNetworkError() = runBlocking<Unit> {
        val server = server()
        val baseUrl = server.baseUrl
        server.stop()
        assertIs<CoreError.Network>(api(baseUrl).fetchTopUsers().errorOrNull())
    }

    @Test fun recoversAfterScenarioSwitch() = runBlocking<Unit> {
        val server = server(Scenario.ERROR)
        val api = api(server.baseUrl)
        assertIs<CoreError.Http>(api.fetchTopUsers().errorOrNull())
        server.defaultScenario = Scenario.SUCCESS
        assertEquals(20, api.fetchTopUsers().getOrNull()?.size)
    }

    @Test fun repositoryAndUseCasesEndToEnd() = runBlocking<Unit> {
        val settings = MapSettings()
        val repository = UserRepository(api(server().baseUrl), SettingsFollowStore(settings))
        val byName = GetTopUsers(repository)(SortOption(SortField.NAME, SortDirection.ASC)).getOrNull()!!
        assertEquals("Alex Martelli", byName.first().displayName)
        assertEquals(Outcome.Success(true), ToggleFollow(repository)(byName.first().id))
        val reloaded = UserRepository(api(server().baseUrl), SettingsFollowStore(settings))
        assertEquals(setOf(byName.first().id), reloaded.followedIds())
    }
}
