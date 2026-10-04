package dev.filip.sotopusers.mockserver

import io.ktor.client.HttpClient
import io.ktor.client.engine.cio.CIO
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsBytes
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue
import kotlin.time.measureTime
import kotlin.time.Duration.Companion.milliseconds

class MockServerTest {
    private val servers = mutableListOf<MockServer>()
    private val client = HttpClient(CIO) { expectSuccess = false }

    private fun server(default: Scenario = Scenario.SUCCESS) =
        MockServer(defaultScenario = default, slowDelayMillis = 300).start().also { servers += it }

    @AfterTest fun tearDown() {
        client.close()
        servers.forEach { runCatching { it.stop() } }
    }

    private suspend fun users(server: MockServer, scenario: String? = null, query: String = USERS_QUERY): HttpResponse =
        client.get("${server.baseUrl}/2.3/users?$query") { scenario?.let { header(MockServer.SCENARIO_HEADER, it) } }

    private suspend fun HttpResponse.json(): JsonObject = Json.parseToJsonElement(bodyAsText()).jsonObject

    @Test fun startsOnEphemeralPortAndReportsReady() = runBlocking<Unit> {
        val server = server()
        assertTrue(server.port > 0)
        assertEquals("http://127.0.0.1:${server.port}", server.baseUrl)
        assertEquals(HttpStatusCode.OK, client.get("${server.baseUrl}/__ready").status)
    }

    @Test fun successServesTwentyUsersWithAvatarsOnThisServer() = runBlocking<Unit> {
        val server = server()
        val response = users(server)
        assertEquals(HttpStatusCode.OK, response.status)
        assertTrue(response.headers[HttpHeaders.ContentType]!!.startsWith("application/json"))
        val items = response.json()["items"]!!.jsonArray
        assertEquals(20, items.size)
        val avatars = items.mapNotNull { it.jsonObject["profile_image"]?.jsonPrimitive?.content }
        assertTrue(avatars.isNotEmpty())
        assertTrue(avatars.all { it.startsWith("${server.baseUrl}/avatars/") }, "avatars: $avatars")
    }

    @Test fun errorScenarioReturnsApiErrorObject() = runBlocking<Unit> {
        val response = users(server(), "error")
        assertEquals(HttpStatusCode.BadRequest, response.status)
        assertEquals(502, response.json()["error_id"]!!.jsonPrimitive.int)
    }

    @Test fun emptyScenarioReturnsNoItems() = runBlocking<Unit> {
        val response = users(server(), "empty")
        assertEquals(HttpStatusCode.OK, response.status)
        assertEquals(0, response.json()["items"]!!.jsonArray.size)
    }

    @Test fun malformedScenarioReturnsUnparseableJson() = runBlocking<Unit> {
        val response = users(server(), "malformed")
        assertEquals(HttpStatusCode.OK, response.status)
        assertFailsWith<Exception> { Json.parseToJsonElement(response.bodyAsText()) }
    }

    @Test fun slowScenarioDelaysThenSucceeds() = runBlocking<Unit> {
        val server = server()
        lateinit var response: HttpResponse
        val elapsed = measureTime { response = users(server, "slow") }
        assertTrue(elapsed >= 300.milliseconds, "elapsed $elapsed")
        assertEquals(20, response.json()["items"]!!.jsonArray.size)
    }

    @Test fun delayHeaderOverridesSlowDelay() = runBlocking<Unit> {
        val server = server()
        val elapsed = measureTime {
            client.get("${server.baseUrl}/2.3/users?$USERS_QUERY") {
                header(MockServer.SCENARIO_HEADER, "slow")
                header(MockServer.DELAY_HEADER, "700")
            }
        }
        assertTrue(elapsed >= 700.milliseconds, "elapsed $elapsed")
    }

    @Test fun unknownScenarioHeaderIsRejected() = runBlocking<Unit> {
        assertEquals(HttpStatusCode.BadRequest, users(server(), "teapot").status)
    }

    @Test fun missingSiteParameterIsRejectedLikeTheRealApi() = runBlocking<Unit> {
        val response = users(server(), query = "pagesize=20")
        assertEquals(HttpStatusCode.BadRequest, response.status)
        assertEquals("bad_parameter", response.json()["error_name"]!!.jsonPrimitive.content)
    }

    @Test fun scenarioEndpointSetsInstanceDefaultAndHeaderStillWins() = runBlocking<Unit> {
        val server = server()
        val set = client.post("${server.baseUrl}/__scenario") { setBody("empty") }
        assertEquals(HttpStatusCode.OK, set.status)
        assertEquals(Scenario.EMPTY, server.defaultScenario)
        assertEquals("empty", client.get("${server.baseUrl}/__scenario").bodyAsText())
        assertEquals(0, users(server).json()["items"]!!.jsonArray.size)
        assertEquals(20, users(server, "success").json()["items"]!!.jsonArray.size)
        assertEquals(HttpStatusCode.BadRequest, client.post("${server.baseUrl}/__scenario") { setBody("nope") }.status)
    }

    @Test fun instancesAreIsolated() = runBlocking<Unit> {
        val a = server(default = Scenario.ERROR)
        val b = server()
        assertNotEquals(a.port, b.port)
        assertEquals(HttpStatusCode.BadRequest, users(a).status)
        assertEquals(HttpStatusCode.OK, users(b).status)
    }

    @Test fun servesGeneratedPngAvatars() = runBlocking<Unit> {
        val server = server()
        val response = client.get("${server.baseUrl}/avatars/22656.png")
        assertEquals(HttpStatusCode.OK, response.status)
        assertEquals(ContentType.Image.PNG.toString(), response.headers[HttpHeaders.ContentType])
        assertContentEquals(PNG_SIGNATURE, response.bodyAsBytes().copyOf(8))
        assertEquals(HttpStatusCode.NotFound, client.get("${server.baseUrl}/avatars/abc.png").status)
    }

    @Test fun shutdownEndpointStopsTheServer() = runBlocking<Unit> {
        val server = MockServer().start()
        assertEquals(HttpStatusCode.Accepted, client.post("${server.baseUrl}/__shutdown").status)
        var refused = false
        repeat(50) {
            if (!refused) {
                refused = runCatching { client.get("${server.baseUrl}/__ready") }.isFailure
                if (!refused) delay(100)
            }
        }
        assertTrue(refused, "server still accepting connections after shutdown")
    }

    private companion object {
        const val USERS_QUERY = "site=stackoverflow&pagesize=20&order=desc&sort=reputation"
        val PNG_SIGNATURE = byteArrayOf(0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
    }
}
