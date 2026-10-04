package dev.filip.sotopusers.data

import io.ktor.client.HttpClient
import io.ktor.client.engine.okhttp.OkHttp

actual fun createPlatformHttpClient(requestTimeoutMillis: Long): HttpClient = HttpClient(OkHttp) {
    configureCommon(requestTimeoutMillis)
}
