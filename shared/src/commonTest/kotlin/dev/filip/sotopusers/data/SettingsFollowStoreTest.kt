package dev.filip.sotopusers.data

import com.russhwolf.settings.MapSettings
import dev.filip.sotopusers.model.CoreError
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class SettingsFollowStoreTest {
    private val settings = MapSettings()

    @Test fun emptyByDefault() = assertEquals(emptySet(), SettingsFollowStore(settings).load())

    @Test fun roundTripsAcrossInstances() {
        SettingsFollowStore(settings).save(setOf(22656L, 6309L, 9_007_199_254_740_993L))
        assertEquals(setOf(22656L, 6309L, 9_007_199_254_740_993L), SettingsFollowStore(settings).load())
    }

    @Test fun savingEmptySetClearsFollows() {
        val store = SettingsFollowStore(settings)
        store.save(setOf(1L))
        store.save(emptySet())
        assertEquals(emptySet(), store.load())
    }

    @Test fun usesConfiguredKeyOnly() {
        SettingsFollowStore(settings, key = "a").save(setOf(1L))
        assertEquals(emptySet(), SettingsFollowStore(settings, key = "b").load())
    }

    @Test fun corruptValueIsAStorageError() {
        settings.putString(SettingsFollowStore.DEFAULT_KEY, "1,banana,3")
        assertFailsWith<CoreError.Storage> { SettingsFollowStore(settings).load() }
    }
}
