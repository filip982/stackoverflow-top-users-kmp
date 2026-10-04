package dev.filip.sotopusers.data

import io.ktor.client.HttpClient
import io.ktor.client.engine.darwin.Darwin

actual fun createPlatformHttpClient(requestTimeoutMillis: Long): HttpClient = HttpClient(Darwin) {
    configureCommon(requestTimeoutMillis)
}
