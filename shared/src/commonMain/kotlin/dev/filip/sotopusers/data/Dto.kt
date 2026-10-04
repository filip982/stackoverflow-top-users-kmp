package dev.filip.sotopusers.data

import dev.filip.sotopusers.model.CoreError
import dev.filip.sotopusers.model.Outcome
import dev.filip.sotopusers.model.User
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNames

/** StackExchange `/2.3/users` wrapper. Also carries the API error object fields, which share the top level. */
@Serializable
internal data class UsersResponseDto(
    val items: List<UserDto>? = null,
    @SerialName("has_more") val hasMore: Boolean? = null,
    @SerialName("error_id") val errorId: Int? = null,
    @SerialName("error_name") val errorName: String? = null,
    @SerialName("error_message") val errorMessage: String? = null,
)

@OptIn(ExperimentalSerializationApi::class)
@Serializable
internal data class UserDto(
    @SerialName("user_id") val userId: Long,
    @SerialName("display_name") val displayName: String,
    val reputation: Long,
    @SerialName("creation_date") val creationDate: Long,
    // Documented wire name is last_modified_date; last_modify_date accepted for tolerance.
    @SerialName("last_modified_date") @JsonNames("last_modify_date") val lastModifiedDate: Long? = null,
    @SerialName("profile_image") val profileImage: String? = null,
    val location: String? = null,
    @SerialName("website_url") val websiteUrl: String? = null,
)

internal val StackExchangeJson = Json {
    ignoreUnknownKeys = true
    explicitNulls = false
    coerceInputValues = true
}

internal fun UserDto.toDomain(): User = User(
    id = userId,
    displayName = HtmlEntities.decode(displayName),
    reputation = reputation,
    avatarUrl = profileImage.cleaned(),
    location = location.cleaned(),
    websiteUrl = websiteUrl.cleaned(),
    creationDate = creationDate,
    lastModifiedDate = lastModifiedDate,
)

private fun String?.cleaned(): String? = this?.takeIf { it.isNotBlank() }?.let(HtmlEntities::decode)

/** Parses a `/2.3/users` body: Success, Http for an API error object, Decoding for anything malformed. */
internal fun parseUsersResponse(body: String): Outcome<List<User>> {
    val dto = try {
        StackExchangeJson.decodeFromString(UsersResponseDto.serializer(), body)
    } catch (e: SerializationException) {
        return Outcome.Failure(CoreError.Decoding(e))
    } catch (e: IllegalArgumentException) {
        return Outcome.Failure(CoreError.Decoding(e))
    }
    dto.errorId?.let { return Outcome.Failure(CoreError.Http(it, dto.errorMessage?.let(HtmlEntities::decode))) }
    val items = dto.items ?: return Outcome.Failure(CoreError.Decoding(IllegalStateException("response has no 'items'")))
    return Outcome.Success(items.map { it.toDomain() })
}

/** Best-effort extraction of `error_message` from a non-2xx body. */
internal fun parseApiErrorMessage(body: String): String? = try {
    StackExchangeJson.decodeFromString(UsersResponseDto.serializer(), body).errorMessage?.let(HtmlEntities::decode)
} catch (e: SerializationException) {
    null
} catch (e: IllegalArgumentException) {
    null
}
