package dev.filip.sotopusers.android.testing

import dev.filip.sotopusers.model.User
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import kotlinx.serialization.json.longOrNull

/**
 * Users from the shared `/fixtures/users.json` (on the test classpath). The shared core's DTO
 * mapping is internal, so this reads only the fields the UI needs; avatars are dropped so tests
 * never touch the network.
 */
object FixtureUsers {
    val all: List<User> by lazy {
        val text = requireNotNull(FixtureUsers::class.java.getResource("/users.json")) { "missing fixture" }.readText()
        Json.parseToJsonElement(text).jsonObject.getValue("items").jsonArray.map { element ->
            val o = element.jsonObject
            User(
                id = o.getValue("user_id").jsonPrimitive.long,
                displayName = o.getValue("display_name").jsonPrimitive.content,
                reputation = o.getValue("reputation").jsonPrimitive.long,
                avatarUrl = null,
                location = o["location"]?.jsonPrimitive?.content,
                websiteUrl = o["website_url"]?.jsonPrimitive?.content,
                creationDate = o.getValue("creation_date").jsonPrimitive.long,
                lastModifiedDate = o["last_modified_date"]?.jsonPrimitive?.longOrNull,
            )
        }
    }
}
