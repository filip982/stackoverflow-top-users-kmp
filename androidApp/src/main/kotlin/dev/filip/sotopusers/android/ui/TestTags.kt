package dev.filip.sotopusers.android.ui

/** Stable semantics tags shared by the Compose UI and its Robolectric / instrumented tests. */
object TestTags {
    const val USER_LIST = "user_list"
    const val LOADING = "loading"
    const val ERROR_STATE = "error_state"
    const val EMPTY_STATE = "empty_state"
    const val RETRY = "retry_button"
    const val SORT_BUTTON = "sort_button"

    const val DETAIL_NAME = "detail_name"
    const val DETAIL_REPUTATION = "detail_reputation"
    const val DETAIL_LOCATION = "detail_location"
    const val DETAIL_WEBSITE = "detail_website"
    const val DETAIL_FOLLOW = "detail_follow_button"
    const val DETAIL_FOLLOWED_INDICATOR = "detail_followed_indicator"

    const val SORT_DIRECTION_ASC = "sort_direction_asc"
    const val SORT_DIRECTION_DESC = "sort_direction_desc"
    const val SORT_APPLY = "sort_apply"
    const val SORT_CANCEL = "sort_cancel"

    fun userRow(id: Long) = "user_row_$id"
    fun followButton(id: Long) = "follow_button_$id"
    fun followedIndicator(id: Long) = "followed_indicator_$id"
    fun sortField(name: String) = "sort_field_$name"
}
