# Stack Overflow Top Users

Top 20 Stack Overflow users by reputation, with follow persistence, user detail screen, and sort options. UIKit + MVVM, no third-party dependencies.

## Run

Open `StackOverflow Top Users.xcodeproj`, pick an iOS simulator, press ⌘R.

## Test

⌘U. Covers networking, decoding, image loading, follow persistence, view models, and sort logic.

## Features

- **User list** — top 20 users showing avatar, name, and reputation
- **Follow / Unfollow** — local toggle, persisted in `UserDefaults`, survives relaunch
- **User detail** — profile picture, name, reputation, location, website (tappable), follow toggle
- **Sort options** — sort by reputation, name, date created, or date updated; ascending or descending
- **Error state** — shown when the server is unavailable, with a retry button

## Architecture

```
App (UIKit, MVVM)
├─ Networking          Client + RemoteClient            (local SPM package)
├─ UserService         fetch + decode users
├─ ImageService        avatar loading + NSCache
├─ FollowService       follow state (UserDefaults)
└─ Features
   ├─ UserList         UserListViewModel + UserListViewController
   ├─ UserDetails      UserDetailsViewModel + UserDetailsViewController
   └─ SortOptions      SortOptionsViewModel + SortOptionsViewController
```

`Networking` is a local Swift package so its `Client` protocol can be mocked in tests. All other services live as folders in the app target. ViewModels depend only on protocols and are tested with in-memory fakes — no mocking framework needed.

Navigation is handled by `AppCoordinator`, which owns all service instances and acts as the composition root.

## Technical decisions

- **UIKit** — programmatic UI, no storyboards
- **MVVM** — VCs are dumb; all logic lives in VMs tested without UIKit
- **Protocol-driven DI** — `UserServicing`, `FollowStoring`, `ImageLoading`, `Client` are all protocols; fakes injected in tests
- **No 3rd-party frameworks** — `HttpURLConnection` → `URLSession` via `RemoteClient`, `BitmapFactory` → `NSCache` for images, `DataStore` → `UserDefaults` for follow state
- **Swift Testing** — `@Test`, `#expect`, `Issue.record`
