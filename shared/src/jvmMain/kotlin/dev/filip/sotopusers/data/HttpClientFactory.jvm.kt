package dev.filip.sotopusers.data

import io.ktor.client.HttpClient
import io.ktor.client.engine.cio.CIO
import io.ktor.client.plugins.compression.ContentEncoding

actual fun createPlatformHttpClient(requestTimeoutMillis: Long): HttpClient = HttpClient(CIO) {
    // CIO does not decompress transparently; the real API always gzips.
    install(ContentEncoding) {
        gzip()
        deflate()
    }
    configureCommon(requestTimeoutMillis)
}
