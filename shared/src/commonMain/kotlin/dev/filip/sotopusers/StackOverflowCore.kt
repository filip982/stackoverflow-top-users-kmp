package dev.filip.sotopusers

import com.russhwolf.settings.Settings
import dev.filip.sotopusers.data.KtorUserApiService
import dev.filip.sotopusers.data.SettingsFollowStore
import dev.filip.sotopusers.data.UserRepository
import dev.filip.sotopusers.data.createPlatformHttpClient
import dev.filip.sotopusers.domain.GetTopUsers
import dev.filip.sotopusers.domain.SortUsers
import dev.filip.sotopusers.domain.ToggleFollow
import io.ktor.client.HttpClient

/**
 * Public entry point of the shared core. Create exactly one per app process (it owns the single
 * app-scoped [UserRepository]) and pass it to the platform MVI stores.
 *
 * @param baseUrl e.g. `https://api.stackexchange.com`, or the mockserver URL in debug/e2e builds.
 * @param settings platform storage (SharedPreferencesSettings on Android, NSUserDefaultsSettings on iOS).
 */
class StackOverflowCore(
    baseUrl: String,
    settings: Settings,
    httpClient: HttpClient = createPlatformHttpClient(),
) {
    val repository = UserRepository(KtorUserApiService(baseUrl, httpClient), SettingsFollowStore(settings))
    val getTopUsers = GetTopUsers(repository)
    val toggleFollow = ToggleFollow(repository)
    val sortUsers = SortUsers()

    companion object {
        const val PRODUCTION_BASE_URL = "https://api.stackexchange.com"
    }
}
