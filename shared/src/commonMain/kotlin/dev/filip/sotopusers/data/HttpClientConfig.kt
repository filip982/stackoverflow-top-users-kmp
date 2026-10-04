package dev.filip.sotopusers.data

import io.ktor.client.HttpClientConfig
import io.ktor.client.plugins.HttpTimeout

internal fun HttpClientConfig<*>.configureCommon(requestTimeoutMillis: Long) {
    expectSuccess = false
    install(HttpTimeout) {
        this.requestTimeoutMillis = requestTimeoutMillis
        connectTimeoutMillis = requestTimeoutMillis
        socketTimeoutMillis = requestTimeoutMillis
    }
}
