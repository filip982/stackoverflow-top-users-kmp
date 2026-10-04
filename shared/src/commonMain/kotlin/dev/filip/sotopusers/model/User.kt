package dev.filip.sotopusers.model

/**
 * A Stack Overflow user as seen by the app. Never a wire DTO.
 *
 * Dates are epoch seconds (UTC), exactly as delivered by the StackExchange API.
 * Text fields are already HTML-entity decoded; blank optional fields are `null`.
 */
data class User(
    val id: Long,
    val displayName: String,
    val reputation: Long,
    val avatarUrl: String?,
    val location: String?,
    val websiteUrl: String?,
    val creationDate: Long,
    val lastModifiedDate: Long?,
)

enum class SortField { REPUTATION, NAME, CREATION, MODIFIED }

enum class SortDirection { ASC, DESC }

data class SortOption(
    val field: SortField = SortField.REPUTATION,
    val direction: SortDirection = SortDirection.DESC,
) {
    companion object {
        val Default = SortOption()
    }
}
