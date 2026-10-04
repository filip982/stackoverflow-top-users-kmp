package dev.filip.sotopusers.android.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import androidx.test.ext.junit.runners.AndroidJUnit4
import dev.filip.sotopusers.android.list.UserListRoute
import dev.filip.sotopusers.android.list.UserListStore
import dev.filip.sotopusers.android.testing.FakeFollowStore
import dev.filip.sotopusers.android.testing.FakeUserApi
import dev.filip.sotopusers.android.testing.FixtureUsers
import dev.filip.sotopusers.android.testing.TestCore
import dev.filip.sotopusers.model.Outcome
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Compose + Robolectric smoke test: real list store over the shared core with a fake service layer. */
@RunWith(AndroidJUnit4::class)
class UserListScreenSmokeTest {
    @get:Rule
    val compose = createComposeRule()

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    @After
    fun tearDown() = scope.cancel()

    @Test
    fun `renders fixture users and a follow tap updates the indicator`() {
        val core = TestCore(
            api = FakeUserApi(autoRespond = Outcome.Success(FixtureUsers.all)),
            followStore = FakeFollowStore(),
            observerContext = Dispatchers.Main,
        )
        val store = UserListStore(scope, core.getTopUsers, core.toggleFollow, core.sortUsers, core.repository.followedIdsFlow)
        compose.setContent { UserListRoute(store, onUserClick = {}, onSortClick = {}) }

        val jon = 22656L
        compose.onNodeWithText("Jon Skeet").assertIsDisplayed()
        compose.onNodeWithText("1,520,345", substring = true).assertIsDisplayed()
        // All 20 fixture users are in the list (last one by reputation is reachable by scrolling).
        compose.onNodeWithTag(TestTags.USER_LIST).performScrollToNode(hasTestTag(TestTags.userRow(4086)))
        compose.onNodeWithTag(TestTags.USER_LIST).performScrollToNode(hasTestTag(TestTags.userRow(jon)))

        compose.onNodeWithTag(TestTags.followedIndicator(jon)).assertDoesNotExist()
        compose.onNodeWithTag(TestTags.followButton(jon)).performClick()
        compose.waitForIdle()

        compose.onNodeWithTag(TestTags.followedIndicator(jon)).assertIsDisplayed()
        assertEquals(setOf(jon), core.followStore.saved)
    }
}
