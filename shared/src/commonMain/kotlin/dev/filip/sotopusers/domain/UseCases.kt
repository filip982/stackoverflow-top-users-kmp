package dev.filip.sotopusers.domain

import dev.filip.sotopusers.data.UserRepository
import dev.filip.sotopusers.model.Outcome
import dev.filip.sotopusers.model.SortDirection
import dev.filip.sotopusers.model.SortField
import dev.filip.sotopusers.model.SortOption
import dev.filip.sotopusers.model.User

/** Client-side sort. Ties break on id ascending; missing dates always sort last, in either direction. */
class SortUsers {
    operator fun invoke(users: List<User>, option: SortOption): List<User> {
        val sign = if (option.direction == SortDirection.DESC) -1 else 1
        val key: (User) -> Comparable<*>? = when (option.field) {
            SortField.REPUTATION -> { u -> u.reputation }
            SortField.NAME -> { u -> u.displayName.lowercase() }
            SortField.CREATION -> { u -> u.creationDate }
            SortField.MODIFIED -> { u -> u.lastModifiedDate }
        }
        val primary = Comparator<User> { a, b ->
            val ka = key(a)
            val kb = key(b)
            when {
                ka == null && kb == null -> 0
                ka == null -> 1
                kb == null -> -1
                else -> sign * compareValues(ka, kb)
            }
        }
        return users.sortedWith(primary.thenBy { it.id })
    }
}

class GetTopUsers(
    private val repository: UserRepository,
    private val sortUsers: SortUsers = SortUsers(),
) {
    suspend operator fun invoke(option: SortOption = SortOption.Default): Outcome<List<User>> =
        repository.getTopUsers().map { sortUsers(it, option) }
}

class ToggleFollow(private val repository: UserRepository) {
    suspend operator fun invoke(userId: Long): Outcome<Boolean> = repository.toggleFollow(userId)
}
