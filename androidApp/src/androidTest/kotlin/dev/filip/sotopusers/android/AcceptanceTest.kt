package dev.filip.sotopusers.android

import android.content.Context
import androidx.compose.ui.test.SemanticsNodeInteraction
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onChildAt
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import dev.filip.sotopusers.android.ui.TestTags
import org.junit.After
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.net.HttpURLConnection
import java.net.URL

/**
 * Acceptance suite: the real app (real shared core, OkHttp, SharedPreferences) against the
 * standalone :mockserver on the host, reached from the emulator at http://10.0.2.2:<port>.
 *
 * CI only. Build with `-PsoBaseUrl=http://10.0.2.2:8080` and start the server first — see
 * androidApp/README.md and the `android-emulator` job in .github/workflows/linux.yml.
 */
@RunWith(AndroidJUnit4::class)
class AcceptanceTest {
    @get:Rule
    val compose = createEmptyComposeRule()

    private val app: SoTopUsersApp get() = ApplicationProvider.getApplicationContext()
    private val scenarios = mutableListOf<ActivityScenario<MainActivity>>()

    @Before
    fun setUp() {
        assertTrue(
            "Instrumented tests must target the mockserver; build with -PsoBaseUrl=http://10.0.2.2:<port> (got ${BuildConfig.BASE_URL})",
            BuildConfig.BASE_URL.startsWith("http://10.0.2.2") || BuildConfig.BASE_URL.startsWith("http://localhost"),
        )
        setScenario("success")
        app.getSharedPreferences(AppContainer.PREFS_NAME, Context.MODE_PRIVATE).edit().clear().commit()
        app.rebuildContainer()
    }

    @After
    fun tearDown() {
        scenarios.forEach { it.close() }
        setScenario("success")
    }

    @Test
    fun navigatesFromListToDetailAndBack() {
        launch()
        awaitTag(TestTags.USER_LIST)

        compose.onNodeWithTag(TestTags.userRow(JON)).performClick()
        awaitTag(TestTags.DETAIL_NAME)
        compose.onNodeWithTag(TestTags.DETAIL_NAME).assertTextEquals("Jon Skeet")
        compose.onNodeWithTag(TestTags.DETAIL_REPUTATION).assertTextEquals("Reputation: 1,520,345")
        compose.onNodeWithTag(TestTags.DETAIL_LOCATION).performScrollTo().assertIsDisplayed()
        compose.onNodeWithTag(TestTags.DETAIL_WEBSITE).performScrollTo().assertIsDisplayed()

        compose.onNodeWithContentDescription("Back").performClick()
        awaitTag(TestTags.USER_LIST)
    }

    @Test
    fun followPersistsAcrossRelaunch() {
        val first = launch()
        awaitTag(TestTags.USER_LIST)
        indicator(JON).assertDoesNotExist()

        compose.onNodeWithTag(TestTags.followButton(JON)).performClick()
        awaitTag(TestTags.followedIndicator(JON))

        // Simulate a process restart: close the UI and rebuild the core from persisted storage.
        first.close()
        scenarios.remove(first)
        app.rebuildContainer()

        launch()
        awaitTag(TestTags.USER_LIST)
        awaitTag(TestTags.followedIndicator(JON))

        // Detail reflects the same persisted state.
        compose.onNodeWithTag(TestTags.userRow(JON)).performClick()
        awaitTag(TestTags.DETAIL_FOLLOWED_INDICATOR)
    }

    @Test
    fun sortingAppliesOnApplyAndIsDiscardedOnCancel() {
        launch()
        awaitTag(TestTags.USER_LIST)
        firstRow().assert(hasTestTag(TestTags.userRow(JON))) // reputation, descending by default

        // Cancel discards the draft.
        openSort()
        compose.onNodeWithTag(TestTags.sortField("NAME")).performScrollTo().performClick()
        compose.onNodeWithTag(TestTags.SORT_CANCEL).performClick()
        awaitTag(TestTags.USER_LIST)
        firstRow().assert(hasTestTag(TestTags.userRow(JON)))

        // Apply commits: name ascending puts "Alex Martelli" first.
        openSort()
        compose.onNodeWithTag(TestTags.sortField("NAME")).performScrollTo().performClick()
        compose.onNodeWithTag(TestTags.SORT_DIRECTION_ASC).performScrollTo().performClick()
        compose.onNodeWithTag(TestTags.SORT_APPLY).performClick()
        awaitTag(TestTags.USER_LIST)
        firstRow().assert(hasTestTag(TestTags.userRow(ALEX_MARTELLI)))
    }

    @Test
    fun retryRecoversFromServerError() {
        setScenario("error")
        launch()
        awaitTag(TestTags.ERROR_STATE)

        setScenario("success")
        compose.onNodeWithTag(TestTags.RETRY).performClick()
        awaitTag(TestTags.USER_LIST)
        compose.onNodeWithTag(TestTags.userRow(JON)).assertIsDisplayed()
    }

    private fun launch(): ActivityScenario<MainActivity> =
        ActivityScenario.launch(MainActivity::class.java).also { scenarios += it }

    private fun openSort() {
        compose.onNodeWithTag(TestTags.SORT_BUTTON).performClick()
        awaitTag(TestTags.SORT_APPLY)
    }

    private fun firstRow(): SemanticsNodeInteraction = compose.onNodeWithTag(TestTags.USER_LIST).onChildAt(0)

    private fun indicator(id: Long) = compose.onNodeWithTag(TestTags.followedIndicator(id), useUnmergedTree = true)

    /** Network and persistence run off the main thread, so wait on semantics rather than idling. */
    private fun awaitTag(tag: String, timeoutMillis: Long = 15_000) {
        compose.waitUntil(timeoutMillis) {
            compose.onAllNodes(hasTestTag(tag), useUnmergedTree = true).fetchSemanticsNodes().isNotEmpty()
        }
    }

    /** POST /__scenario on the mockserver (instance default scenario for subsequent requests). */
    private fun setScenario(name: String) {
        val connection = URL("${BuildConfig.BASE_URL}/__scenario?name=$name").openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 5_000
            connection.readTimeout = 5_000
            check(connection.responseCode == 200) { "mockserver /__scenario returned ${connection.responseCode}" }
        } finally {
            connection.disconnect()
        }
    }

    private companion object {
        const val JON = 22656L
        const val ALEX_MARTELLI = 95810L
    }
}
