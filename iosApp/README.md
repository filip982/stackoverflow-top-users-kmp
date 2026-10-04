# iosApp: SwiftUI + MVI over the Kotlin `Shared` core

This is the handoff doc for building and testing the iOS app on a Mac. The Linux dev host can't compile
Swift or Kotlin/Native Apple targets, so this app is proven in two places: CI (`ios-app` and `ios-ui-tests` in
`.github/workflows/macos.yml`, `macos-14`) and the owner's Apple Silicon Mac, using the commands below.

## Layout

```
iosApp/
  project.yml                     XcodeGen spec (the .xcodeproj is generated and git-ignored)
  Config/                         Debug/Release xcconfigs + partial Info.plists (Debug only: MockBaseURL + localhost ATS exception)
  scripts/start-mockserver.sh     builds and starts :mockserver, then waits for /__ready
  scripts/ci-select-xcode.sh      CI only: picks Xcode 16.x and makes sure an "iPhone 16" simulator exists
  StackOverflowTopUsers/
    App/                          @main App (builds the single core), RootView navigation, AppConfiguration
    Core/CoreGateway.swift        Swift models + the CoreGateway protocol that stores depend on
    Core/SharedCoreGateway.swift  the ONLY file that imports `Shared` (all Kotlin interop lives here)
    MVI/Store.swift               @MainActor Store<State, Intent, Message, Effect> (ObservableObject)
    Features/{UserList,UserDetail,SortOptions}/   <Feature>Store.swift (pure reducer + effects) and <Feature>View.swift
    UI/                           shared views, accessibility ids, formatting, error copy
  StackOverflowTopUsersTests/     XCTest unit tests, hosted in the app
  StackOverflowTopUsersUITests/   XCUITest acceptance suite (runs against :mockserver)
```

The app uses the same MVI shape as `androidApp`: Intent → Store → pure reducer → State, with side effects
in the store. Its rules match too:

- **Latest request wins.** Every fetch gets a request id. A completion whose id isn't the active one is ignored.
- **Rapid taps on follow are dropped.** Only one toggle per user can be in flight. Taps on that user are ignored until it finishes.
- **Sort uses a draft.** Sort edits change a draft. Apply commits it, and Cancel throws it away.
- **One source of follow state.** Follow state comes from the single app-scoped `UserRepository` through
  `watchFollowedIds`. Updates are delivered on the main actor, and the observation is cancelled when the store deinits.

## Prerequisites

- An Apple Silicon Mac. The Kotlin framework is built only for `iosArm64` and `iosSimulatorArm64`,
  and `ARCHS = arm64` is forced, so Intel Macs and Rosetta simulators aren't supported.
- **Xcode 16.x** with an iOS 18 simulator runtime and an "iPhone 16" simulator. Check with `xcodebuild -version` and
  `xcrun simctl list devices available | grep "iPhone 16 ("`.
- **JDK 21**, for example `brew install --cask temurin@21`. Xcode's build phase runs Gradle. If `JAVA_HOME`
  isn't set, the phase falls back to `/usr/libexec/java_home -v 21`.
- **XcodeGen**: `brew install xcodegen`.

All commands below run from the repository root.

## 1. Generate the project

```sh
(cd iosApp && xcodegen generate)
open iosApp/StackOverflowTopUsers.xcodeproj   # optional
```

Run this again whenever `project.yml` changes or Swift files are added or removed.

## 2. Build for the simulator

```sh
xcodebuild build-for-testing \
  -project iosApp/StackOverflowTopUsers.xcodeproj -scheme StackOverflowTopUsers \
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath build/DerivedData
```

The pre-build phase **Build Kotlin Shared framework** runs `./gradlew :shared:embedAndSignAppleFrameworkForXcode`.
That builds the static `Shared.framework` for the current configuration and SDK into
`shared/build/xcode-frameworks/<Configuration>/<sdk>/`, which is where `FRAMEWORK_SEARCH_PATHS` points. The
first build downloads Kotlin/Native (~1 GB into `~/.konan`), so expect several minutes. To iterate on Swift
only, you can pass `SKIP_KOTLIN_BUILD=YES` to xcodebuild, which reuses the last framework.

To run the app in Xcode, pick the `StackOverflowTopUsers` scheme and an iPhone 16 simulator. Debug builds call
the production API unless they're given a mock URL (see below).

## 3. Unit tests (no server needed)

```sh
xcodebuild test \
  -project iosApp/StackOverflowTopUsers.xcodeproj -scheme StackOverflowTopUsers \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath build/DerivedData \
  -only-testing:StackOverflowTopUsersTests
```

- `UserListStoreTests`, `UserDetailStoreTests`, `SortOptionsStoreTests`: the stores against `FakeCoreGateway`,
  which defers completions under test control.
- `AppConfigurationTests`: debug-only base-URL injection, the reset flag, formatting, and error copy.
- `SharedContractTests`: the **real** Kotlin framework, exercised through `SharedCoreGateway` and the DEBUG-only
  `SharedContractProbe`. Covers entity round-trips, `Outcome` and `CoreError` mapping, enums, `SortUsers`, the suspend bridge
  (a connection refused on `localhost:9` maps to `.network`), NSUserDefaults persistence and fresh-instance
  reload, observer delivery on main and disposal, and corrupt-storage reset.

The test bundle doesn't link `Shared`. It is linked into the host app only, and autolinking is disabled
in the test target, so the process never loads two Kotlin runtimes.

## 4. UI tests against the mockserver

```sh
iosApp/scripts/start-mockserver.sh 8080        # or: ./gradlew :mockserver:installDist && mockserver/build/install/mockserver/bin/mockserver 8080

TEST_RUNNER_MOCK_BASE_URL=http://localhost:8080 xcodebuild test \
  -project iosApp/StackOverflowTopUsers.xcodeproj -scheme StackOverflowTopUsers \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath build/DerivedData \
  -only-testing:StackOverflowTopUsersUITests

curl -X POST http://localhost:8080/__shutdown  # stop the server
```

- The simulator shares the Mac's network stack, so the app reaches the server at `http://localhost:8080`.
  Plain HTTP to `localhost` is allowed only by the Debug Info.plist (`Config/Info-Debug.plist`). Release
  builds have no ATS exception and ignore every override.
- **Launch environment** (read by the app only in DEBUG builds):

  | Variable | Effect |
  |---|---|
  | `MOCK_BASE_URL` | API base URL, e.g. `http://localhost:8080`. Takes precedence over the Info.plist `MockBaseURL` key. |
  | `RESET_FOLLOWS=1` | Clears persisted follows before the core starts. The UI tests set it on every launch except the "relaunch" launch. |

- `TEST_RUNNER_MOCK_BASE_URL` reaches the XCUITest runner as `MOCK_BASE_URL`, and the runner passes it to the
  app's launch environment. It defaults to `http://localhost:8080`, so you can leave it out when the server
  is on 8080.
- The UI tests switch scenarios with `POST /__scenario?name=error|success`, sent over a raw TCP connection
  (`MockServerControl`). That bypasses ATS in the test runner.
- Suite: navigation list→detail→back, follow persisting across a real relaunch, follow from detail showing
  in the list, sorting (Cancel discards, Apply commits name-ascending), and retry recovering from a server error.

### Running the app against the mockserver by hand

In Xcode, open Edit Scheme → Run → Arguments → Environment Variables and add
`MOCK_BASE_URL = http://localhost:8080`. You can also bake the URL in at build time with
`MOCK_BASE_URL = http:/$()/localhost:8080` in `Config/Debug.xcconfig`. The `$()` is needed because xcconfig
treats `//` as the start of a comment.

## Interop notes (Kotlin/Native → Swift)

All interop assumptions live in `Core/SharedCoreGateway.swift`. If the generated `Shared.h` names
something differently, fix that one file. To see the real names, look at
`shared/build/xcode-frameworks/Debug/iphonesimulator*/Shared.framework/Headers/Shared.h`.

- Top-level functions in `HttpClientFactory.ios.kt` become members of `HttpClientFactory_iosKt`.
- Default arguments aren't exported, so the code passes `httpClient` and every other parameter explicitly.
- `Outcome<List<User>>` becomes `Outcome<NSArray>`. The code uses its `getOrNull()` and `errorOrNull()` members.
  `CoreError.Http` becomes `CoreErrorHttp` (nested sealed subclasses are flattened).
- `suspend fun invoke(...)` becomes `invoke(...completionHandler:)`. The code calls it on the main actor and bridges
  it with a continuation. Gradle also sets `objcExportSuspendFunctionLaunchThreadRestriction=none`.
- `Long?` becomes `KotlinLong?`, and `Set<Long>` becomes `Set<KotlinLong>`.
- `multiplatform-settings` is `export(...)`-ed from `:shared` so that `NSUserDefaultsSettings(delegate:)` is visible to Swift.

## Troubleshooting

- **`No such module 'Shared'`**: the Gradle phase didn't run or failed. Check the build log for the
  **Build Kotlin Shared framework** phase. Make sure `ENABLE_USER_SCRIPT_SANDBOXING = NO` (it's set in `project.yml`) and that a JDK 21 is installed.
- **Gradle can't find Java inside Xcode**: run `export JAVA_HOME=$(/usr/libexec/java_home -v 21)` before
  `xcodebuild`, or install a JDK 21 where `java_home` can find it.
- **The UI tests fail at `setUp` with "mockserver not ready"**: start the server first, and check
  `curl http://localhost:8080/__ready`.
- **Signing on a real device**: set your team under Signing & Capabilities. Simulator builds don't need one.
