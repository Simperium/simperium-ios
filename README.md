simperium-ios
=============
[![Pod Version](http://img.shields.io/cocoapods/v/Simperium.svg?style=flat)](http://www.github.com/Simperium/simperium-ios)
[![Pod Platform](http://img.shields.io/cocoapods/p/Simperium.svg?style=flat)](http://www.simperium.com)
[![Pod Platform](http://img.shields.io/cocoapods/p/Simperium-OSX.svg?style=flat)](http://www.simperium.com)
[![Pod License](http://img.shields.io/cocoapods/l/Simperium.svg?style=flat)](http://www.simperium.com)

Simperium is a simple way for developers to move data as it changes, instantly and automatically. This is the iOS / OSX library. You can [browse the documentation](http://simperium.com/docs/ios/) or [try a tutorial](https://simperium.com/tutorials/simpletodo-ios/).

You can [sign up](http://simperium.com) for a hosted version of Simperium. There are Simperium libraries for [other languages](https://simperium.com/overview/) too.

Adding Simperium to your project
--------------------------------

### Swift Package Manager

From version 1.9.1, the project support integrating via Swift Package Manager.
This is the recommended mode of integration.

```swift
.package(url: "https://github.com/Simperium/simperium-ios", from: "1.9.1-beta.2")
```

> [!IMPORTANT]
> Notice that Simperium is distributed as a binary target and that only tagged versions have the binary attached.
> As such **you must point to a tagged version**.
> If you point to a commit or branch, SwiftPM will checkout the source for it without issue, but the binary it will download will be the one for the tag specified in the `Package.swift` it checks out; SwiftPM does not build the binary target for you.

### CocoaPods

There are two pods: `Simperium` for iOS and `Simperium-OSX` for macOS.

### Manually

[Download the latest release](https://github.com/Simperium/simperium-ios/releases/latest). Unzip the source code somewhere convenient.

Then, drag and drop Simperium.xcodeproj into your application's project, and add Simperium.framework in your target's Build Phase tab (under Link Binary with Libraries). You'll still need to [add some dependencies](http://simperium.com/docs/ios/#add).

OSX
---
Everything works pretty much the same on OSX. Some changes are noted [in the online documentation](http://simperium.com/docs/ios/).

Releases
--------
The `main` branch always has the latest stable release, and is tagged. Simperium is used by hundreds of thousands of people across many different apps and devices, and is considered production-ready.

The `develop` branch has an ongoing development build (not intended for production use).

Folder structure
----------------
**Simperium**. Everything is accessed from a `Simperium` instance. This class can be safely instantiated more than once in the same app (e.g. for unit testing).

**Object**. Simperium does a lot of diffing in order to send only data that changes. Any object class that conforms to the `SPDiffable` protocol can be supported. `SPManagedObject` is for Core Data, and `SPObject` is a container for raw JSON (not yet supported). `SPGhost` is an object's opinion of its own state on the server (the name "ghost" was borrowed from the [Tribes Networking Model](http://www.pingz.com/wordpress/wp-content/uploads/2009/11/tribes_networking_model.pdf)).

**Diffing**. An `SPDiffer` can perform diffs on any `SPDiffable` object. Each differ adheres to an `SPSchema`. The schema stores a list of members/properties (of type `SPMember`) for an object of a particular type. Each subclass of `SPMember` corresponds to a data type, and knows how to diff itself. In the future these will be parameterized for custom diffing, conflict resolution, validation, etc.

**System**. An `SPBucket` provides access to a synchronized bucket of objects of a particular type. The `SPBucket` has an `SPDiffer` to perform diffs, an `SPStorageProvider` for locally reading and writing data, an `SPChangeProcessor` for processing incoming and outgoing changes, and an `SPIndexProcessor` for processing indexes retrieved from the server. The processors run in their own threads.

**Storage**. An `SPStorageProvider` defines an interface for local reading and writing of objects. In particular it defines a `threadSafeStorage` method that returns a thread safe instance. `SPCoreDataProvider` is currently the only fully functional storage provider.

**Authentication**. An `SPAuthenticator` handles all authentication with Simperium, and can be customized or overridden as necessary. There are companion classes for iOS and OSX that provide a code-driven UI for signing in and signing up (`SPAuthenticationViewController` and `SPAuthenticationWindowController`).

**Networking**. An `SPNetworkProvider` defines an interface for remote reading and writing of objects in an `SPBucket`. The network provider sends local data and receives remote data in the background, passing it through threaded processors as necessary. Although there is an HTTP provider, the WebSockets provider is intended to become the default (but is still under development).

**User**. Basic access to a user's data. In the future this will hold custom properties and presence information.

**Helpers**. Exporter, keychain, etc.

Building a new release
----------------------

The release process is not yet automated.

1. Ensure `SPLibraryVersion` in `Simperium/SPEnvironment.m` has the version number of the new release you want to publish.
1. Ensure the `tag` in `Package.swift` has the same value.
3. Run `make` to create the XCFramework for SwiftPM, notice the checksum value it prints in the output.
4. Update the `checksum` in `Package.swift` with the checksum value from the step above.
5. Validate the CocoaPods specs with `pod lib lint --allow-warnings`.
6. Commit, tag the repo, and push.
7. Create a new GitHub release from the tag and add the ZIP at `.build/xcframework/Simperium.xcframework.zip` as an artifact.
8. Publish the GitHub release. This will make the new version available via Swift Package Manager.
9. Publish a new CocoaPods version for iOS with `pod trunk push Simperium.podspec` and for macOS with `pod trunk push Simperium-OSX.podspec`.

License
-------
The Simperium iOS library is available for free and commercial use under the MIT license.
