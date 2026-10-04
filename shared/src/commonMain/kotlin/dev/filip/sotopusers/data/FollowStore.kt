package dev.filip.sotopusers.data

import com.russhwolf.settings.Settings
import dev.filip.sotopusers.model.CoreError

/** Persistence for followed user ids. Implementations throw [dev.filip.sotopusers.model.CoreError.Storage]. */
interface FollowStore {
    fun load(): Set<Long>
    fun save(ids: Set<Long>)
}

class SettingsFollowStore(
    private val settings: Settings,
    private val key: String = DEFAULT_KEY,
) : FollowStore {
    override fun load(): Set<Long> {
        val raw = try {
            settings.getStringOrNull(key)
        } catch (e: Exception) { // e.g. ClassCastException from SharedPreferences on a type clash
            throw CoreError.Storage(e)
        } ?: return emptySet()
        if (raw.isBlank()) return emptySet()
        return raw.split(SEPARATOR).mapTo(mutableSetOf()) {
            it.trim().toLongOrNull() ?: throw CoreError.Storage(IllegalStateException("corrupt follow entry '$it'"))
        }
    }

    override fun save(ids: Set<Long>) {
        try {
            settings.putString(key, ids.sorted().joinToString(SEPARATOR))
        } catch (e: Exception) {
            throw CoreError.Storage(e)
        }
    }

    companion object {
        const val DEFAULT_KEY = "followed_user_ids"
        private const val SEPARATOR = ","
    }
}
