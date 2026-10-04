# StackOverflow Users

Develop an iOS application that fetches a list of StackOverflow users and displays it in a list on the screen.

## Functional Requirements

When the app is launched, the user should be able to see a list of the top 20 StackOverflow users.
Each list item should contain the user's profile image, name and reputation.
Cells should contain an additional option to 'follow' a user. “Follow” functionality should just be locally simulated, i.e. no actual API call should be made.
Users that are followed should show an indicator in the list item.
Include an 'unfollow' option in the view when a user is followed.
“Follow” status should persist between sessions.
If the server is unavailable (e.g. offline, error response etc), the user should see an empty state with an error message.

## Technical Specifications

Emphasise testability and architecture - use whatever pattern you like, but be prepared to justify your decision!
Your code should be covered by unit tests.
Your UI is entirely up to you, but please use UIKit to build your views.
Write in Swift - no Objective-C.
No 3rd party frameworks - we want to see what you can do!
Please avoid using AI to write this project
Deliver your work as a Git repository, preferably on Github or Bitbucket so we can see your commit history.
Include a README explaining how your app works, any installation requirements, and details behind any technical decisions you made while developing it.

## Additional Information
This is a take-home exercise and you should take as much time as you need, but try not to spend too long on it. All code must be your own, please avoid using AI to generate any code for you.

## Example of requests/responses
StackOverflow users API:

GET <http://api.stackexchange.com/2.2/users?page=1&pagesize=20&order=desc&sort=reputation&site=stackoverflow>

Example Response (truncated for brevity):
{
"items": [
{
"badge_counts": {
"bronze": 9255,
"silver": 9202,
"gold": 877
},
"account_id": 11683,
"is_employee": false,
"last_modified_date": 1711287919,
"last_access_date": 1711355649,
"reputation_change_year": 13860,
"reputation_change_quarter": 13860,
"reputation_change_month": 3856,
"reputation_change_week": 118,
"reputation_change_day": 30,
"reputation": 1454978,
"creation_date": 1222430705,
"user_type": "registered",
"user_id": 22656,
"accept_rate": 86,
"location": "Reading, United Kingdom",
"website_url": "http://csharpindepth.com",
"link": "https://stackoverflow.com/users/22656/jon-skeet",
"profile_image": "https://www.gravatar.com/avatar/6d8ebb117e8d83d74ea95fbdd0f87e13?s=256&d=identicon&r=PG",
"display_name": "Jon Skeet"
}
]
}

Response schema:

{
"items": [
{
"badge_counts": {
"bronze": String,
"silver": String,
"gold": Int
},
"account_id": Int,
"is_employee": Boolean,
"last_modified_date": Int,
"last_access_date": Int,
"reputation_change_year": Int,
"reputation_change_quarter": Int,
"reputation_change_month": Int,
"reputation_change_week": Int,
"reputation_change_day": Int,
"reputation": Int,
"creation_date": Int,
"user_type": String,
"user_id": Int,
"accept_rate": Int,
"location": String?,
"website_url": String?,
"link": String,
"profile_image": String?,
"display_name": String
}
]
}

Full API documentation: <https://api.stackexchange.com/docs/types/user>
