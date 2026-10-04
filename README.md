# Stack Overflow Top Users — Kotlin Multiplatform

Top 20 Stack Overflow users by reputation, with local follow persistence, a detail screen and sort
options. Android and iOS apps share one Kotlin Multiplatform core. See `docs/REWRITE_PLAN.md`.

## Layout

```
shared/        KMP core (android, jvm, iosArm64, iosSimulatorArm64)
               model/   User, SortField, SortDirection, SortOption, CoreError, Outcome
               data/    DTOs + HTML-entity decoding, Ktor UserApiService, FollowStore
                        (multiplatform-settings), UserRepository
               domain/  GetTopUsers, ToggleFollow, SortUsers
               StackOverflowCore: the public entry point (baseUrl + Settings)
mockserver/    Ktor JVM fake of GET /2.3/users with per-instance scenarios
fixtures/      JSON fixtures shared by every test level (mockserver resources +
               generated constants for shared commonTest)
androidApp/    Compose app, MVI stores over the shared core (see androidApp/README.md)
iosApp/        SwiftUI app (phase A4, placeholder)
legacy/        previous UIKit app, kept for reference
.github/workflows/  linux.yml (tests, android app unit/Robolectric + assemble, emulator e2e vs mockserver),
                    macos.yml (iOS compile + sim tests)
```

## Requirements

- JDK 17+ (CI uses 21)
- Android SDK (compileSdk 35). Create `local.properties` with `sdk.dir=/path/to/Android/Sdk`, or set `ANDROID_HOME`.
- iOS targets compile only on macOS; on Linux they are skipped automatically.

## Run tests locally

```sh
./gradlew :shared:jvmTest            # commonTest on the JVM + socket-level integration tests vs mockserver
./gradlew :shared:testDebugUnitTest  # commonTest on the Android unit-test JVM
./gradlew :mockserver:test           # mock server contract
./gradlew :shared:assembleDebug      # Android target compiles
./gradlew :androidApp:testDebugUnitTest :androidApp:assembleDebug   # app store tests + Robolectric smoke, APK
LIVE_API=1 ./gradlew :shared:jvmTest --tests '*LiveApiSmokeTest*'   # opt-in check against the real API

# macOS only
./gradlew :shared:compileKotlinIosArm64 :shared:compileKotlinIosSimulatorArm64 :shared:iosSimulatorArm64Test
```

## Mock server

```sh
./gradlew :mockserver:run --args="8080"     # binds 0.0.0.0; env MOCK_PORT, MOCK_HOST, MOCK_SCENARIO
curl 'http://localhost:8080/2.3/users?site=stackoverflow&pagesize=20&order=desc&sort=reputation'
```

| Endpoint | Purpose |
|---|---|
| `GET /2.3/users` | fixture of 20 users; requires `site=stackoverflow` (400 `bad_parameter` otherwise) |
| header `X-Mock-Scenario: success\|error\|empty\|slow\|malformed` | per-request scenario (wins over the default) |
| header `X-Mock-Delay-Ms` | delay for `slow` (default 3000 ms) |
| `GET` / `POST /__scenario` | read / set the instance default scenario (body or `?name=`) |
| `GET /__ready`, `POST /__shutdown` | readiness and shutdown |
| `GET /avatars/{id}.png` | generated PNG avatars (fixture `profile_image` URLs point here) |

`error` returns HTTP 400 with a StackExchange error object (`throttle_violation`), as the real API does.
Tests embed it with `MockServer().start()` on an ephemeral port; every test owns its own instance, so
there is no shared scenario state between tests. From an Android emulator, use `http://10.0.2.2:<port>`.
