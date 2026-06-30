# StackOverflow Top Users — Engineering Context

## Platforms
- `ios/` — Swift, MVVM, UIKit (assignment), SwiftUI next
- `android/` — Kotlin, MVVM, Jetpack Compose
- `rust/` — common core (planned)

## Shared conventions
- No 3rd party dependencies (assignment constraint carried forward)
- Protocol/interface-driven DI — all services behind abstractions
- Unit tested with in-memory fakes, no mocking frameworks
- Separate networking module per platform (SPM on iOS, Gradle module on Android)

## Current state
- iOS: complete (user-list, user-detail, sort, follow, tests)
- Android: planned, not started
- Rust common-core: not started

## Engineering process
- Orchestrator pattern: networking → persistence → viewmodel → view per feature
- GitHub Issues track features, PRs against develop, review before merge
- Platforms developed independently, then unified via Rust common-core

## Skills to use
| Skill | When |
|-------|------|
| `/plan-eng-review` | Before starting any feature |
| `/review` | Ad-hoc spot check |
| `/code-review` | PR review |
| `/investigate` | Debugging |
| `/ship` | PR creation |
| `/careful` | Before destructive ops |
