package dev.filip.sotopusers.data

import dev.filip.sotopusers.FIXTURE_BASE_URL
import dev.filip.sotopusers.fixtures.Fixtures
import dev.filip.sotopusers.model.CoreError
import dev.filip.sotopusers.model.Outcome
import dev.filip.sotopusers.model.User
import dev.filip.sotopusers.usersFixture
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertTrue

class DtoMappingTest {
    private fun users(): List<User> = assertIs<Outcome.Success<List<User>>>(parseUsersResponse(usersFixture)).value
    private fun byId(id: Long) = users().single { it.id == id }

    @Test fun parsesAllTwentyFixtureUsersInWireOrder() {
        val users = users()
        assertEquals(20, users.size)
        assertEquals(22656, users.first().id)
        assertEquals(users.sortedByDescending { it.reputation }.map { it.reputation }, users.map { it.reputation })
    }

    @Test fun mapsEveryFieldOfACompleteUser() = assertEquals(
        User(
            id = 22656,
            displayName = "Jon Skeet",
            reputation = 1520345,
            avatarUrl = "$FIXTURE_BASE_URL/avatars/22656.png",
            location = "Reading, United Kingdom",
            websiteUrl = "http://csharpindepth.com",
            creationDate = 1222430705,
            lastModifiedDate = 1727873400,
        ),
        byId(22656),
    )

    @Test fun decodesHtmlEntitiesInDisplayNamesAndLocations() {
        assertEquals("Günter Zöchbauer", byId(217408).displayName)
        assertEquals("Wiktor Stribiżew", byId(3832970).displayName)
        assertEquals("Jean-François Fabre", byId(6451573).displayName)
        assertEquals("René \"Ren\" Gentle", byId(1240000).displayName)
        assertEquals("Peter O'Callaghan & Sons", byId(4086).displayName)
        assertEquals("Willemstad, Curaçao", byId(157882).location)
    }

    @Test fun missingOptionalFieldsBecomeNull() {
        val hans = byId(17034)
        assertNull(hans.lastModifiedDate)
        assertNull(hans.websiteUrl)
        assertNull(byId(95810).avatarUrl)
        assertNull(byId(19068).location)
        val rene = byId(1240000)
        assertNull(rene.avatarUrl); assertNull(rene.location); assertNull(rene.websiteUrl); assertNull(rene.lastModifiedDate)
    }

    @Test fun blankWebsiteUrlBecomesNull() {
        assertNull(byId(29407).websiteUrl)
        assertNull(byId(4086).websiteUrl)
    }

    @Test fun ignoresUnknownFieldsAtEveryLevel() {
        val body = """{"items":[{"user_id":1,"display_name":"A","reputation":5,"creation_date":10,
            "brand_new":{"nested":[1,2]},"collectives":[]}],"quota_max":300,"backoff":10,"surprise":true}"""
        assertEquals(listOf(1L), assertIs<Outcome.Success<List<User>>>(parseUsersResponse(body)).value.map { it.id })
    }

    @Test fun acceptsLegacyLastModifyDateAlias() {
        val body = """{"items":[{"user_id":1,"display_name":"A","reputation":5,"creation_date":10,"last_modify_date":99}]}"""
        assertEquals(99L, assertIs<Outcome.Success<List<User>>>(parseUsersResponse(body)).value.single().lastModifiedDate)
    }

    @Test fun explicitNullOptionalFieldsAreTolerated() {
        val body = """{"items":[{"user_id":1,"display_name":"A","reputation":5,"creation_date":10,
            "location":null,"website_url":null,"profile_image":null,"last_modified_date":null}]}"""
        val u = assertIs<Outcome.Success<List<User>>>(parseUsersResponse(body)).value.single()
        assertNull(u.location); assertNull(u.websiteUrl); assertNull(u.avatarUrl); assertNull(u.lastModifiedDate)
    }

    @Test fun emptyItemsIsAnEmptySuccess() =
        assertEquals(Outcome.Success(emptyList()), parseUsersResponse(Fixtures.usersEmpty))

    @Test fun malformedJsonIsADecodingError() {
        assertIs<CoreError.Decoding>(parseUsersResponse(Fixtures.usersMalformed).errorOrNull())
        assertIs<CoreError.Decoding>(parseUsersResponse("").errorOrNull())
        assertIs<CoreError.Decoding>(parseUsersResponse("<html>502 Bad Gateway</html>").errorOrNull())
    }

    @Test fun missingRequiredFieldIsADecodingError() {
        val body = """{"items":[{"display_name":"no id","reputation":5,"creation_date":10}]}"""
        assertIs<CoreError.Decoding>(parseUsersResponse(body).errorOrNull())
    }

    @Test fun missingItemsWrapperIsADecodingError() {
        assertIs<CoreError.Decoding>(parseUsersResponse("""{"quota_max":300}""").errorOrNull())
    }

    @Test fun apiErrorObjectIsAnHttpErrorCarryingTheApiMessage() {
        val error = assertIs<CoreError.Http>(parseUsersResponse(Fixtures.apiError).errorOrNull())
        assertEquals(502, error.code)
        assertTrue(error.apiMessage!!.startsWith("too many requests"))
    }
}
