# Android Plan — Stack Overflow Top Users

Android version of the iOS take-home (`/Users/filipm/develop/stackoverflow-top-users-ios`),
mirroring the same MVVM + one-networking-module architecture.

## Working rule
User writes ALL code by hand. Assistant only shows terminal/paste snippets and reads
to track progress — never edits files in this repo. (Assignment: "avoid using AI to
write this project.") Same rule as iOS.

## Tech decisions (made 2026-06-16)
- **UI:** Jetpack Compose (LazyColumn).
- **Language/build:** Kotlin + Gradle Kotlin DSL (`build.gradle.kts`), Coroutines/Flow for async.
- **Deps — HYBRID rule:**
  - Allowed (treated as "the SDK"): AndroidX/Jetpack — ViewModel, DataStore, Coroutines, Flow, Compose.
  - NOT allowed (hand-roll, mirror iOS no-3rd-party spirit): networking, JSON, image loading.
    - Networking → `HttpURLConnection`
    - JSON → `org.json` or manual parsing (no Moshi/Gson)
    - Images → `BitmapFactory` + own `LruCache` (no Coil/Glide)
  - No Retrofit / Ktor / Moshi / Gson / Coil / Glide / Hilt.
- **Min/target SDK:** proposed minSdk 24, target 34/35 (confirm vs assignment).

## Module / folder structure
```
StackOverflowTopUsers/                 (Gradle root project)
├─ settings.gradle.kts                 (includes :app and :networking)
├─ build.gradle.kts                    (root)
│
├─ networking/                         ← the ONE separate module (= iOS Networking SPM package)
│   ├─ build.gradle.kts                (android-library)
│   └─ src/
│       ├─ main/java/.../networking/
│       │     Client.kt                (interface — the mockable seam)
│       │     HttpClient.kt            (HttpURLConnection impl = RemoteClient)
│       │     NetworkError.kt          (sealed class = NetworkError enum)
│       ├─ testFixtures/java/.../      (FakeClient = NetworkingTestSupport / MockClient)
│       └─ test/java/.../              (HttpClient tests)
│
└─ app/
    ├─ build.gradle.kts                (android-application; depends on :networking)
    └─ src/
        ├─ main/java/.../
        │   ├─ user/                   (= Services/UserService)
        │   │     StackOverflowUser.kt, UsersResponse.kt
        │   │     UserService.kt (interface), StackOverflowUserService.kt
        │   ├─ image/                  (= Services/ImageService)
        │   │     ImageLoader.kt (interface), BitmapImageLoader.kt, ImageCache.kt (LruCache)
        │   ├─ follow/                 (= Services/FollowService)
        │   │     FollowStore.kt (interface), DataStoreFollowStore.kt
        │   ├─ userlist/               (= Features/UserList)
        │   │     UserListViewModel.kt (StateFlow<UiState>)
        │   │     UserListScreen.kt    (Composable: LazyColumn + states)
        │   │     UserRow.kt           (Composable cell: avatar + name + rep + follow btn)
        │   └─ MainActivity.kt         (composition root = SceneDelegate)
        └─ test/java/.../              (ViewModel + service + store tests with fakes)
```

## iOS → Android mapping
| iOS | Android |
|---|---|
| `Networking` SPM package | `:networking` Gradle library module |
| `NetworkingTestSupport` (shared mock product) | `testFixtures` source set (shared `FakeClient`) |
| `Client` protocol | `Client` interface |
| `RemoteClient` (URLSession) | `HttpClient` (HttpURLConnection + Coroutines) |
| `async/await` | `suspend` functions + Coroutines |
| `NetworkError` enum | `sealed class NetworkError` |
| `Codable` | hand-rolled parse from `org.json` (no Moshi) |
| `UserListViewModel` + `onChange` | `ViewModel` + `StateFlow<UiState>` |
| `@MainActor` | `viewModelScope` + `Dispatchers` |
| `UITableView` / `UserCell` | `LazyColumn` / `UserRow` composable |
| `NSCache` | `LruCache` |
| `UserDefaults` follow store | DataStore (`FollowStore` interface) |
| `SceneDelegate` composition root | `MainActivity` (manual DI, no Hilt) |
| Swift Testing + fakes | JUnit + fakes (no MockK needed) |

Key parallel preserved: only networking is a separate module (so `Client` is mockable via
`testFixtures`); everything else is packages in `:app`; the ViewModel depends only on
interfaces and is tested with in-memory fakes.

## Commit sequence (mirrors iOS)
1. scaffold + .gitignore + README stub
2. `:networking` — Client, HttpClient, NetworkError, FakeClient (testFixtures) + tests
3. user package — model, UsersResponse, UserService + parsing tests
4. UI/VM — UserListViewModel (StateFlow), UserListScreen, UserRow; loading/error/empty
5. image — BitmapImageLoader + LruCache + avatars
6. follow — DataStoreFollowStore + follow button + tests
7. README

## Open questions to confirm when starting
1. Repo path (this folder) + package name (e.g. `com.filipm.stackoverflowtopusers`)?
2. Confirm same "I write everything" rule.
3. `testFixtures` for shared FakeClient vs duplicating a small fake per test — leaning testFixtures.
4. Min/target SDK — any assignment constraint? (proposed minSdk 24, target 34/35)

## API reference (same as iOS)
`https://api.stackexchange.com/2.2/users?page=1&pagesize=20&order=desc&sort=reputation&site=stackoverflow`

## Build sequence lesson from iOS
Integrate the project + module early and add code incrementally (let the IDE/Gradle sync
write project files), rather than building all modules first and wiring the app last.
