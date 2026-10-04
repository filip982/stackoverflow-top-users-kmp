package dev.filip.sotopusers.data

import io.ktor.client.HttpClient

/** Platform engine: OkHttp (Android), CIO (JVM), Darwin (iOS). */
expect fun createPlatformHttpClient(requestTimeoutMillis: Long = DEFAULT_REQUEST_TIMEOUT_MS): HttpClient

const val DEFAULT_REQUEST_TIMEOUT_MS: Long = 15_000
