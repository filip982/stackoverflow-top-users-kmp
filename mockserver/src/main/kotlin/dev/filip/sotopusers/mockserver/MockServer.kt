package dev.filip.sotopusers.mockserver

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
 */
class MockServer(
    private val requestedPort: Int = 0,
    private val host: String = "127.0.0.1",
    defaultScenario: Scenario = Scenario.SUCCESS,
    val slowDelayMillis: Long = DEFAULT_SLOW_DELAY_MS,
) {
    @Volatile var defaultScenario: Scenario = defaultScenario

    val port: Int get() = TODO()
    val baseUrl: String get() = TODO()

    fun start(): MockServer = TODO()
    fun stop(): Unit = TODO()

    companion object {
        const val SCENARIO_HEADER = "X-Mock-Scenario"
        const val DELAY_HEADER = "X-Mock-Delay-Ms"
        const val DEFAULT_SLOW_DELAY_MS = 3_000L
    }
}
