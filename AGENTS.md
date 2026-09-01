# Simperium iOS

The Simperium client library for Apple platforms, written in Objective-C.

## Running the tests

```sh
bundle exec fastlane ios test
```

The lane targets the simulator named in `fastlane/Fastfile`; `xcrun simctl list devices available` lists what your machine has.
To narrow a run, call `xcodebuild` directly with `-only-testing:UnitTests/SPWebSocketInterfaceTests`.

The scheme's test action runs `UnitTests` and skips `IntegrationTests`, which talk to a live Simperium account.
There is no macOS equivalent: the `Simperium OSX` scheme has an empty test action, so `bundle exec fastlane mac build` only compiles it.

Buildkite runs both lanes on every pull request, on the Xcode version pinned in `.xcode-version`.

## Integration is a prebuilt binary, not source

`Package.swift` declares Simperium as a `binaryTarget`: an `XCFramework.zip` attached to a GitHub release, pinned by URL and checksum.
SwiftPM never compiles this repository's sources.

Two consequences, both of which bite when reasoning about how a change reaches an app:

- **Merging to `develop` changes nothing for SwiftPM consumers.**
  They resolve whatever binary the tagged release holds.
  Source changes ship only when someone cuts a release and rebuilds the XCFramework.
- **Pointing a consumer at a branch or commit does not test that branch.**
  SwiftPM checks out the source, then downloads the binary named by the `Package.swift` at that revision — new manifest, old binary.
  Only tagged versions carry a matching binary.

To exercise an unreleased change in a host app, build the XCFramework locally with `make` and point the app at that artifact, or integrate `Simperium.xcodeproj` directly.

CocoaPods integration does build from source, but no client uses it.

## Releases

`make` builds, signs and zips the XCFramework and prints the checksum `Package.swift` needs.
The version lives in two places that must move together: `SPLibraryVersion` in `Simperium/SPEnvironment.m` and `version` in `Package.swift`.

The full sequence is in the README under "Building a new release".
It is manual end to end; there is no release automation.
