# androidApp — Jetpack Compose, MVI over the shared core

Package `dev.filip.sotopusers.android`. Screens: user list, user detail, sort options.

## Architecture

- **MVI, hand-rolled** (`mvi/Store.kt`): `dispatch(intent)` → side effects in the store → messages →
  pure `reduce(state, msg)` → one immutable `State` per screen (`UserListState`, `UserDetailState`,
  `SortOptionsState`). One-shot outputs (sort Apply/Cancel) go through `effects`.
- **Thin stores**: fetching, sorting and follow mutation are the shared use cases (`GetTopUsers`,
  `SortUsers`, `ToggleFollow`); follow state is observed from `UserRepository.followedIdsFlow`, so
  list and detail always agree.
- **Behavioural policies** (all covered by store tests):
  - latest request wins: a new load cancels the previous one and the reducer ignores any completion
    whose request id is not the active one;
  - rapid toggles: one in-flight toggle per user, further taps on that user are dropped (the button is
    disabled meanwhile); taps on other users proceed, serialized by the repository;
  - `Empty` (successful, zero users) is distinct from `Failed(CoreError)`; both offer retry;
  - follow failures and the repository's `startupStorageError` surface as one-shot snackbar messages;
    the startup error is shown once per process (`StartupNotice`);
  - sort options edit a draft: Cancel (button, back arrow or system back) discards it, Apply commits it
    and the list re-sorts client-side without refetching.
- **DI**: `SoTopUsersApp` owns one `AppContainer` → one `StackOverflowCore` (one repository) per
  process, backed by `SharedPreferences`. Stores live in `StoreViewModel`s scoped to nav entries.

## Base URL

The core appends `/2.3/users`, so the configured value is the API host.

| Build | `BuildConfig.BASE_URL` |
|---|---|
| release | `https://api.stackexchange.com` (fixed) |
| debug | `-PsoBaseUrl=...` if given, else production |

Cleartext HTTP is allowed **only in debug** and only for `10.0.2.2`, `localhost` and `127.0.0.1`
(`src/debug/res/xml/network_security_config.xml`).

## Run the app

```sh
./gradlew :androidApp:installDebug                                   # real API
./gradlew :mockserver:run --args="8080"                              # terminal 1
./gradlew :androidApp:installDebug -PsoBaseUrl=http://10.0.2.2:8080  # terminal 2, emulator -> mockserver
```

## Tests

### Store unit tests + Robolectric smoke (local, no device)

```sh
./gradlew :androidApp:testDebugUnitTest
```

- `list/UserListStoreTest`, `detail/UserDetailStoreTest`, `sort/SortOptionsStoreTest`: the real shared
  repository and use cases over a fake `UserApiService` (per-call `CompletableDeferred`, so tests decide
  completion order) and a fake `FollowStore`; controlled `StandardTestDispatcher` + Turbine.
- `ui/UserListScreenSmokeTest`: Compose on Robolectric 4.14.1 (SDK 34, pinned in
  `src/test/resources/robolectric.properties`); renders the users from `/fixtures/users.json` and checks
  that a follow tap shows the followed indicator.

### Instrumented acceptance suite (emulator; CI)

`src/androidTest/.../AcceptanceTest.kt`: list → detail → back, follow + relaunch persistence (core rebuilt
from storage), sort Cancel/Apply, error → retry. It drives the real app against the standalone mockserver
and switches scenarios through `POST /__scenario`. It refuses to run unless the build points at the
mockserver.

```sh
./gradlew :mockserver:installDist
mockserver/build/install/mockserver/bin/mockserver 8080 &            # binds 0.0.0.0
./gradlew :androidApp:connectedDebugAndroidTest -PsoBaseUrl=http://10.0.2.2:8080
curl -X POST http://localhost:8080/__shutdown
```

In CI (`.github/workflows/linux.yml`, job `android-emulator`), the runner builds the mockserver
distribution and both APKs with `-PsoBaseUrl=http://10.0.2.2:8080`, starts the server on the host, waits
for `/__ready`, then runs `connectedDebugAndroidTest` in `reactivecircus/android-emulator-runner` (API 34,
x86_64, google_apis). On failure it uploads the reports and `mockserver.log`.
