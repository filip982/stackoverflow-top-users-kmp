# Stack Overflow Top Users

Top 20 Stack Overflow users with local follow persistence. UIKit + MVVM, modular SPM, no dependencies.
Lists the top 20 Stack Overflow users by reputation. Follow/unfollow is local and persists across launches.

UIKit, MVVM, no third-party dependencies.

## Run

Open `StackOverflow Top Users.xcodeproj`, pick an iOS simulator, press ⌘R.

## Test

⌘U. Covers networking, decoding, image loading, follow persistence, and the view model.

## Architecture
```
App (UIKit, MVVM)
├─ Networking      Client + RemoteClient   (SPM package)
├─ UserService     fetch + decode users
├─ ImageService    avatar loading + cache
└─ FollowService   follow state (UserDefaults)
```

Networking is a local Swift package so its `Client` can be mocked. The other services live in the app target. The view model depends on protocols, so it's tested with in-memory fakes.

## Follow

No API call - followed user IDs are stored in `UserDefaults`, so state survives relaunch.
