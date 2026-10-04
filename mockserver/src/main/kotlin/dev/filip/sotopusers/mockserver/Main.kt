package dev.filip.sotopusers.mockserver

/**
 * Standalone mock server for e2e / manual runs.
 *
 * Usage: `./gradlew :mockserver:run --args="8080"` (or env MOCK_PORT, MOCK_HOST, MOCK_SCENARIO).
 * Binds 0.0.0.0 by default so an Android emulator can reach it at http://10.0.2.2:<port>.
 */
fun main(args: Array<String>) {
    val port = args.getOrNull(0)?.toIntOrNull() ?: System.getenv("MOCK_PORT")?.toIntOrNull() ?: 8080
    val host = System.getenv("MOCK_HOST") ?: "0.0.0.0"
    val scenario = System.getenv("MOCK_SCENARIO")?.let { requireNotNull(Scenario.parse(it)) { "unknown scenario $it" } }
        ?: Scenario.SUCCESS
    val server = MockServer(requestedPort = port, host = host, defaultScenario = scenario).start()
    println("mockserver listening on $host:${server.port} (scenario=${scenario.wireName}); try ${server.baseUrl}/2.3/users?site=stackoverflow")
    Runtime.getRuntime().addShutdownHook(Thread { server.stop() })
    server.join()
}
