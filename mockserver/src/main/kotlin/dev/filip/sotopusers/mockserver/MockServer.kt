package dev.filip.sotopusers.mockserver

import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.Application
import io.ktor.server.application.ApplicationCall
import io.ktor.server.cio.CIO
import io.ktor.server.cio.CIOApplicationEngine
import io.ktor.server.engine.EmbeddedServer
import io.ktor.server.engine.embeddedServer
import io.ktor.server.request.receiveText
import io.ktor.server.response.respondBytes
import io.ktor.server.response.respondText
import io.ktor.server.routing.get
import io.ktor.server.routing.post
import io.ktor.server.routing.routing
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import java.awt.Color
import java.awt.image.BufferedImage
import java.io.ByteArrayOutputStream
import java.util.concurrent.ConcurrentHashMap
import javax.imageio.ImageIO
import kotlin.concurrent.thread

enum class Scenario {
    SUCCESS, ERROR, EMPTY, SLOW, MALFORMED;

    val wireName: String get() = name.lowercase()

    companion object {
        fun parse(value: String): Scenario? = entries.firstOrNull { it.wireName == value.trim().lowercase() }
    }
}

/**
 * Embeddable StackExchange `/2.3/users` fake. Each instance owns its own port and default scenario,
 * so parallel tests never share mutable state.
 *
 * - `GET /2.3/users` — scenario from the `X-Mock-Scenario` header, else the instance default.
 * - `GET|POST /__scenario` — read / set the instance default (body = scenario name).
 * - `GET /__ready`, `POST /__shutdown` — lifecycle for e2e harnesses.
 * - `GET /avatars/{id}.png` — small generated PNG, so no internet is needed.
 */
class MockServer(
    private val requestedPort: Int = 0,
    private val host: String = "127.0.0.1",
    defaultScenario: Scenario = Scenario.SUCCESS,
    val slowDelayMillis: Long = DEFAULT_SLOW_DELAY_MS,
) {
    @Volatile var defaultScenario: Scenario = defaultScenario

    private var server: EmbeddedServer<CIOApplicationEngine, CIOApplicationEngine.Configuration>? = null
    private var boundPort: Int = -1
    private val avatarCache = ConcurrentHashMap<Long, ByteArray>()

    val port: Int get() = boundPort.takeIf { it > 0 } ?: error("MockServer not started")

    /** Base URL for clients on this host. For an Android emulator use `http://10.0.2.2:<port>`. */
    val baseUrl: String get() = "http://${if (host == "0.0.0.0") "127.0.0.1" else host}:$port"

    @Synchronized
    fun start(): MockServer {
        check(server == null) { "already started" }
        val s = embeddedServer(CIO, port = requestedPort, host = host) { module() }.start(wait = false)
        server = s
        boundPort = runBlocking { s.engine.resolvedConnectors().first().port }
        return this
    }

    /** Blocks until the server stops (standalone use). */
    fun join() {
        while (server != null) Thread.sleep(200)
    }

    @Synchronized
    fun stop() {
        server?.stop(gracePeriodMillis = 0, timeoutMillis = 2_000)
        server = null
    }

    private fun Application.module() {
        routing {
            get("/__ready") { call.respondText("ready") }
            get("/__scenario") { call.respondText(defaultScenario.wireName) }
            post("/__scenario") {
                val requested = call.request.queryParameters["name"] ?: call.receiveText()
                val scenario = Scenario.parse(requested)
                if (scenario == null) {
                    call.respondText(unknownScenario(requested), status = HttpStatusCode.BadRequest)
                } else {
                    defaultScenario = scenario
                    call.respondText(scenario.wireName)
                }
            }
            post("/__shutdown") {
                call.respondText("stopping", status = HttpStatusCode.Accepted)
                thread(name = "mockserver-shutdown") { Thread.sleep(100); stop() }
            }
            get("/2.3/users") { serveUsers(call) }
            get("/avatars/{file}") {
                val id = call.parameters["file"]?.removeSuffix(".png")?.toLongOrNull()
                if (id == null) {
                    call.respondText("not found", status = HttpStatusCode.NotFound)
                } else {
                    call.respondBytes(avatarCache.getOrPut(id) { avatarPng(id) }, ContentType.Image.PNG)
                }
            }
        }
    }

    private suspend fun serveUsers(call: ApplicationCall) {
        val header = call.request.headers[SCENARIO_HEADER]
        val scenario = if (header == null) defaultScenario else Scenario.parse(header)
        if (scenario == null) {
            call.respondText(unknownScenario(header.orEmpty()), status = HttpStatusCode.BadRequest)
            return
        }
        if (call.request.queryParameters["site"] != "stackoverflow") {
            call.respondJson(BAD_SITE, HttpStatusCode.BadRequest)
            return
        }
        when (scenario) {
            Scenario.SUCCESS -> call.respondJson(usersBody(call))
            Scenario.SLOW -> {
                delay(call.request.headers[DELAY_HEADER]?.toLongOrNull() ?: slowDelayMillis)
                call.respondJson(usersBody(call))
            }
            Scenario.EMPTY -> call.respondJson(Fixtures.usersEmpty)
            Scenario.MALFORMED -> call.respondJson(Fixtures.usersMalformed)
            // The real API answers throttle violations with HTTP 400 and an error object.
            Scenario.ERROR -> call.respondJson(Fixtures.apiError, HttpStatusCode.BadRequest)
        }
    }

    /** Avatar URLs point back at whatever host the client used (localhost, 10.0.2.2, LAN IP...). */
    private fun usersBody(call: ApplicationCall): String {
        val origin = "http://" + (call.request.headers[HttpHeaders.Host] ?: "127.0.0.1:$port")
        return Fixtures.users.replace(BASE_URL_PLACEHOLDER, origin)
    }

    private suspend fun ApplicationCall.respondJson(body: String, status: HttpStatusCode = HttpStatusCode.OK) =
        respondText(body, ContentType.Application.Json, status)

    private fun unknownScenario(value: String) =
        "unknown scenario '$value'; expected one of ${Scenario.entries.joinToString { it.wireName }}"

    companion object {
        const val SCENARIO_HEADER = "X-Mock-Scenario"
        const val DELAY_HEADER = "X-Mock-Delay-Ms"
        const val DEFAULT_SLOW_DELAY_MS = 3_000L
        const val BASE_URL_PLACEHOLDER = "{{BASE_URL}}"

        private val BAD_SITE =
            """{"error_id":400,"error_message":"site is required","error_name":"bad_parameter"}"""

        init {
            System.setProperty("java.awt.headless", "true")
        }

        internal fun avatarPng(id: Long, size: Int = 64): ByteArray {
            val hue = ((id * 2654435761L) % 360).toFloat() / 360f
            val image = BufferedImage(size, size, BufferedImage.TYPE_INT_RGB)
            val g = image.createGraphics()
            g.color = Color.getHSBColor(hue, 0.55f, 0.85f)
            g.fillRect(0, 0, size, size)
            g.color = Color.getHSBColor(hue, 0.55f, 0.55f)
            g.fillOval(size / 4, size / 4, size / 2, size / 2)
            g.dispose()
            return ByteArrayOutputStream().also { ImageIO.write(image, "png", it) }.toByteArray()
        }
    }
}

/** Fixtures from <root>/fixtures, packaged on the classpath under fixtures/. */
object Fixtures {
    val users: String by lazy { load("users.json") }
    val usersEmpty: String by lazy { load("users_empty.json") }
    val usersMalformed: String by lazy { load("users_malformed.json") }
    val apiError: String by lazy { load("api_error.json") }

    private fun load(name: String): String =
        requireNotNull(Fixtures::class.java.getResource("/fixtures/$name")) { "missing fixture $name" }.readText()
}
