package dev.filip.sotopusers.domain

import dev.filip.sotopusers.data.UserRepository
import dev.filip.sotopusers.model.Outcome
import dev.filip.sotopusers.model.SortOption
import dev.filip.sotopusers.model.User

/** Client-side sort. Ties break on id ascending; missing dates always sort last. */
class SortUsers {
    operator fun invoke(users: List<User>, option: SortOption): List<User> = TODO()
}

class GetTopUsers(
    private val repository: UserRepository,
    private val sortUsers: SortUsers = SortUsers(),
) {
    suspend operator fun invoke(option: SortOption = SortOption.Default): Outcome<List<User>> = TODO()
}

class ToggleFollow(private val repository: UserRepository) {
    suspend operator fun invoke(userId: Long): Outcome<Boolean> = TODO()
}
