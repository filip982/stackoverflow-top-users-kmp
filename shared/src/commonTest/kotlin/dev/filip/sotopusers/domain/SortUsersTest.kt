package dev.filip.sotopusers.domain

import dev.filip.sotopusers.model.SortDirection.ASC
import dev.filip.sotopusers.model.SortDirection.DESC
import dev.filip.sotopusers.model.SortField
import dev.filip.sotopusers.model.SortOption
import dev.filip.sotopusers.user
import kotlin.random.Random
import kotlin.test.Test
import kotlin.test.assertEquals

class SortUsersTest {
    private val sort = SortUsers()
    private fun ids(option: SortOption, vararg users: dev.filip.sotopusers.model.User) =
        sort(users.toList(), option).map { it.id }

    @Test fun defaultIsReputationDescending() = assertEquals(
        listOf(2L, 3L, 1L),
        ids(SortOption.Default, user(1, reputation = 10), user(2, reputation = 30), user(3, reputation = 20)),
    )

    @Test fun reputationAscending() = assertEquals(
        listOf(1L, 3L, 2L),
        ids(SortOption(SortField.REPUTATION, ASC), user(1, reputation = 10), user(2, reputation = 30), user(3, reputation = 20)),
    )

    @Test fun reputationTiesBreakOnIdAscendingInBothDirections() {
        val users = arrayOf(user(157247, reputation = 1_000_000), user(23354, reputation = 1_000_000), user(9, reputation = 5))
        assertEquals(listOf(23354L, 157247L, 9L), ids(SortOption(SortField.REPUTATION, DESC), *users))
        assertEquals(listOf(9L, 23354L, 157247L), ids(SortOption(SortField.REPUTATION, ASC), *users))
    }

    @Test fun nameSortIsCaseInsensitive() {
        val users = arrayOf(user(1, name = "carol"), user(2, name = "Bob"), user(3, name = "alice"))
        assertEquals(listOf(3L, 2L, 1L), ids(SortOption(SortField.NAME, ASC), *users))
        assertEquals(listOf(1L, 2L, 3L), ids(SortOption(SortField.NAME, DESC), *users))
    }

    @Test fun nameTiesBreakOnIdAscending() = assertEquals(
        listOf(4L, 7L, 1L),
        ids(SortOption(SortField.NAME, DESC), user(7, name = "Sam"), user(1, name = "Al"), user(4, name = "sam")),
    )

    @Test fun creationDateBothDirections() {
        val users = arrayOf(user(1, created = 300), user(2, created = 100), user(3, created = 200))
        assertEquals(listOf(2L, 3L, 1L), ids(SortOption(SortField.CREATION, ASC), *users))
        assertEquals(listOf(1L, 3L, 2L), ids(SortOption(SortField.CREATION, DESC), *users))
    }

    @Test fun missingModifiedDatesSortLastInBothDirections() {
        val users = arrayOf(user(5, modified = null), user(1, modified = 100), user(3, modified = null), user(2, modified = 200))
        assertEquals(listOf(1L, 2L, 3L, 5L), ids(SortOption(SortField.MODIFIED, ASC), *users))
        assertEquals(listOf(2L, 1L, 3L, 5L), ids(SortOption(SortField.MODIFIED, DESC), *users))
    }

    @Test fun resultIsIndependentOfInputOrder() {
        val users = (1L..40L).map { user(it, name = "n${it % 5}", reputation = it % 3, created = it % 4, modified = if (it % 2 == 0L) null else it % 6) }
        for (field in SortField.entries) for (dir in listOf(ASC, DESC)) {
            val option = SortOption(field, dir)
            val expected = sort(users, option)
            repeat(10) { seed ->
                assertEquals(expected, sort(users.shuffled(Random(seed)), option), "unstable for $option seed $seed")
            }
        }
    }

    @Test fun emptyListStaysEmpty() = assertEquals(emptyList(), sort(emptyList(), SortOption.Default))
}
