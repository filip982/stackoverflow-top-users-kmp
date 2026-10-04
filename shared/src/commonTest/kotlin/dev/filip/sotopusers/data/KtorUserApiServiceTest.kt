package dev.filip.sotopusers.data

import dev.filip.sotopusers.fixtures.Fixtures
import dev.filip.sotopusers.model.CoreError
import dev.filip.sotopusers.model.Outcome
import dev.filip.sotopusers.model.User
import dev.filip.sotopusers.usersFixture
import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.MockRequestHandleScope
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.client.request.HttpResponseData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertTrue

class KtorUserApiServiceTest {
    private val requests = mutableListOf<HttpRequestData>()

    private fun service(
        baseUrl: String = "https://api.example.test",
        handler: suspend MockRequestHandleScope.(HttpRequestData) -> HttpResponseData,
    ) = KtorUserApiService(
        baseUrl,
        HttpClient(MockEngine { request -> requests += request; handler(request) }) { expectSuccess = false },
    )

    private fun MockRequestHandleScope.json(body: String, status: HttpStatusCode = HttpStatusCode.OK) =
        respond(body, status, headersOf(HttpHeaders.ContentType, "application/json; charset=utf-8"))

    @Test fun requestsTopUsersWithExplicitQuery() = runTest {
        service("https://api.example.test/") { json(usersFixture) }.fetchTopUsers()
        val request = requests.single()
        assertEquals(HttpMethod.Get, request.method)
        assertEquals("https://api.example.test/2.3/users", request.url.toString().substringBefore('?'))
        assertEquals(
            mapOf("site" to "stackoverflow", "pagesize" to "20", "order" to "desc", "sort" to "reputation"),
            request.url.parameters.entries().associate { it.key to it.value.single() },
        )
    }

    @Test fun successReturnsMappedUsers() = runTest {
        val users = assertIs<Outcome.Success<List<User>>>(service { json(usersFixture) }.fetchTopUsers()).value
        assertEquals(20, users.size)
        assertEquals("Günter Zöchbauer", users.single { it.id == 217408L }.displayName)
    }

    @Test fun emptySuccessIsDistinctFromFailure() = runTest {
        assertEquals(Outcome.Success(emptyList()), service { json(Fixtures.usersEmpty) }.fetchTopUsers())
    }

    @Test fun nonSuccessStatusWithApiErrorBodyIsHttpErrorWithMessage() = runTest {
        val error = assertIs<CoreError.Http>(service { json(Fixtures.apiError, HttpStatusCode.BadRequest) }.fetchTopUsers().errorOrNull())
        assertEquals(400, error.code)
        assertTrue(error.apiMessage!!.startsWith("too many requests"))
    }

    @Test fun nonSuccessStatusWithNonJsonBodyIsHttpErrorWithoutMessage() = runTest {
        val error = assertIs<CoreError.Http>(
            service { respond("<html>Service Unavailable</html>", HttpStatusCode.ServiceUnavailable) }.fetchTopUsers().errorOrNull(),
        )
        assertEquals(503, error.code)
        assertNull(error.apiMessage)
    }

    @Test fun malformedSuccessBodyIsDecodingError() = runTest {
        assertIs<CoreError.Decoding>(service { json(Fixtures.usersMalformed) }.fetchTopUsers().errorOrNull())
    }

    @Test fun errorObjectInSuccessStatusIsHttpError() = runTest {
        assertEquals(502, assertIs<CoreError.Http>(service { json(Fixtures.apiError) }.fetchTopUsers().errorOrNull()).code)
    }

    @Test fun transportFailureIsNetworkError() = runTest {
        val error = service { throw RuntimeException("connection reset") }.fetchTopUsers().errorOrNull()
        assertIs<CoreError.Network>(error)
        assertEquals("connection reset", error.cause?.message)
    }

    @Test fun cancellationPropagatesInsteadOfBecomingAFailure() = runTest {
        val started = CompletableDeferred<Unit>()
        var result: Outcome<List<User>>? = null
        val api = service { started.complete(Unit); awaitCancellation() }
        val job = launch { result = api.fetchTopUsers() }
        started.await()
        job.cancel()
        job.join()
        assertTrue(job.isCancelled)
        assertNull(result)
        assertFalse(requests.isEmpty())
    }
}
