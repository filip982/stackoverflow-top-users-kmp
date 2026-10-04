package dev.filip.sotopusers.data

import com.russhwolf.settings.Settings

/** Persistence for followed user ids. Implementations throw [dev.filip.sotopusers.model.CoreError.Storage]. */
interface FollowStore {
    fun load(): Set<Long>
    fun save(ids: Set<Long>)
}

class SettingsFollowStore(
    private val settings: Settings,
    private val key: String = DEFAULT_KEY,
) : FollowStore {
    override fun load(): Set<Long> = TODO()
    override fun save(ids: Set<Long>): Unit = TODO()

    companion object {
        const val DEFAULT_KEY = "followed_user_ids"
    }
}
