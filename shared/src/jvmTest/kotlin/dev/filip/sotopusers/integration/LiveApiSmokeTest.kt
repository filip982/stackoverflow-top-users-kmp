package dev.filip.sotopusers.integration

import dev.filip.sotopusers.StackOverflowCore
import dev.filip.sotopusers.data.KtorUserApiService
import dev.filip.sotopusers.data.createPlatformHttpClient
import dev.filip.sotopusers.model.Outcome
import dev.filip.sotopusers.model.User
import kotlinx.coroutines.runBlocking
import org.junit.Assume.assumeTrue
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

/** Opt-in check of the real StackExchange wire contract (gzip, field names). Run with LIVE_API=1. */
class LiveApiSmokeTest {
    @Test fun fetchesTopUsersFromRealApi() = runBlocking<Unit> {
        assumeTrue("set LIVE_API=1 to run", System.getenv("LIVE_API") == "1")
        val api = KtorUserApiService(StackOverflowCore.PRODUCTION_BASE_URL, createPlatformHttpClient())
        val users = assertIs<Outcome.Success<List<User>>>(api.fetchTopUsers()).value
        assertEquals(20, users.size)
        assertEquals(22656L, users.first().id)
    }
}
