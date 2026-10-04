package dev.filip.sotopusers.data

import dev.filip.sotopusers.model.Outcome
import dev.filip.sotopusers.model.User
import io.ktor.client.HttpClient

interface UserApiService {
    suspend fun fetchTopUsers(): Outcome<List<User>>
}

class KtorUserApiService(
    baseUrl: String,
    private val client: HttpClient = createPlatformHttpClient(),
) : UserApiService {
    private val baseUrl = baseUrl.trimEnd('/')

    override suspend fun fetchTopUsers(): Outcome<List<User>> = TODO()
}
