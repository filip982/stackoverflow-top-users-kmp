package dev.filip.sotopusers.data

import dev.filip.sotopusers.model.Outcome
import dev.filip.sotopusers.model.User
import dev.filip.sotopusers.model.CoreError
import io.ktor.client.HttpClient
import io.ktor.client.request.get
import io.ktor.client.request.parameter
import io.ktor.client.statement.bodyAsText
import io.ktor.http.isSuccess
import kotlinx.coroutines.CancellationException

interface UserApiService {
    suspend fun fetchTopUsers(): Outcome<List<User>>
}

class KtorUserApiService(
    baseUrl: String,
    private val client: HttpClient = createPlatformHttpClient(),
) : UserApiService {
    private val baseUrl = baseUrl.trimEnd('/')

    override suspend fun fetchTopUsers(): Outcome<List<User>> {
        val (status, body) = try {
            val response = client.get("$baseUrl/2.3/users") {
                parameter("site", "stackoverflow")
                parameter("pagesize", 20)
                parameter("order", "desc")
                parameter("sort", "reputation")
            }
            response.status to response.bodyAsText()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            return Outcome.Failure(CoreError.Network(e))
        }
        if (!status.isSuccess()) return Outcome.Failure(CoreError.Http(status.value, parseApiErrorMessage(body)))
        return parseUsersResponse(body)
    }
}
