# Repository Guidelines

## Project Structure & Module Organization
Tone is a Tuist-managed Swift project. Application targets live under `Sources/` (e.g. `ActivityContent`, `LiveActivity`, `UIComponents`, `AppService`). Shared logic that is consumed by multiple targets sits in `CorePackage/Sources`, with corresponding unit tests in `CorePackage/Tests`. Tuist manifests (`Project.swift`, `Tuist/`, `Tuist.swift`) control target definitions; update these when adding modules. Runtime configuration such as environment descriptors and automation live in `Environment/` and `fastlane/`. Keep previews and playgrounds inside the existing module folder (`Sources/UIComponents/Playground`) so they stay scoped to the component they exercise.

## Build, Test, and Development Commands
Run `mise install` once to provision the pinned Tuist version, then `tuist install` to fetch plugins. Use `tuist generate -n` to regenerate `Tone.xcodeproj` without opening Xcode, and `open Tone.xcodeproj` to begin editing. During development, `tuist build Tone` builds the main app, while `tuist test Tone` runs the configured schemes. For package-only checks, run `swift test` inside `CorePackage/`. When debugging from the command line, `xcodebuild -workspace Tone.xcworkspace -scheme Tone -destination 'platform=iOS Simulator,name=iPhone 15' build` mirrors CI expectations.

## Coding Style & Naming Conventions
Follow Swift API Design Guidelines: PascalCase for types, camelCase for values and functions, and use expressive enum cases (e.g. `PlaybackState.playing`). Maintain two-space indentation as seen in `Sources/UIComponents/ListComponents.swift` and keep braces on the same line as declarations. Group view helpers inside enums (e.g. `enum ListComponents`) to keep namespaces clean. Prefer SwiftUI previews under the same file using `#if DEBUG`, and annotate public APIs with brief doc comments where behavior is non-obvious.

## Testing Guidelines
Tests use XCTest. Mirror production module names, appending `Tests` (e.g. `CorePackageTests`). Place SwiftUI snapshot or behavior tests alongside their module inside a `Tests/` directory to preserve module visibility. Run `tuist test Tone` before submitting a pull request; add targeted `swift test --filter ModuleNameTests/testScenario` runs when focusing on a single case. Document new test fixtures in the README within the relevant folder so future contributors understand data contracts.

## Commit & Pull Request Guidelines
Write imperative, scope-prefixed commit messages such as `UIComponents: Add marquee text ticker`. Squash noisy WIP commits before merging. Each pull request should include a concise summary, screenshots or GIFs for UI-visible changes, and links to the tracking Issue or task. Confirm CI builds and tests pass, note any follow-up work in the PR description, and tag reviewers responsible for the touched modules. Avoid force-pushing after review without highlighting the changes.
