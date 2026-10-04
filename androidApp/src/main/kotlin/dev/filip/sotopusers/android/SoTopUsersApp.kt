package dev.filip.sotopusers.android

import android.app.Application
import android.content.Context
import com.russhwolf.settings.SharedPreferencesSettings
import dev.filip.sotopusers.StackOverflowCore
import dev.filip.sotopusers.model.CoreError
import java.util.concurrent.atomic.AtomicBoolean

/** Manual DI root: exactly one [StackOverflowCore] (and so one UserRepository) per process. */
class SoTopUsersApp : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this, BuildConfig.BASE_URL)
    }

    /**
     * Drops the in-memory core and builds a fresh one from persisted storage — what a process
     * restart does. Used by the instrumented suite to prove follow persistence across relaunches.
     */
    fun rebuildContainer() {
        container = AppContainer(this, BuildConfig.BASE_URL)
    }
}

class AppContainer(context: Context, baseUrl: String) {
    val core = StackOverflowCore(
        baseUrl = baseUrl,
        settings = SharedPreferencesSettings(context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)),
    )

    val startupNotice = StartupNotice(core.repository.startupStorageError)

    companion object {
        const val PREFS_NAME = "so_top_users"
    }
}

/** Hands out the startup storage error at most once, so it is shown a single time per process. */
class StartupNotice(private val error: CoreError.Storage?) {
    private val taken = AtomicBoolean(false)

    fun take(): CoreError.Storage? = error
}

val Context.appContainer: AppContainer get() = (applicationContext as SoTopUsersApp).container
