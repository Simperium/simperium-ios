simperium-ios
=============

Simperium is a simple way for developers to move data as it changes, instantly and automatically. This is the iOS / OSX library. You can [browse the documentation](http://simperium.com/docs/ios/) or [try a tutorial](https://simperium.com/tutorials/simpletodo-ios/).

You can [sign up](http://simperium.com) for a hosted version of Simperium. There are Simperium libraries for [other languages](https://simperium.com/overview/) too.

Adding Simperium to your project
--------------------------------
The easiest way to add Simperium is to [download the latest release](https://github.com/Simperium/simperium-ios/releases/latest). Unzip the source code somewhere convenient.

Then, drag and drop Simperium.xcodeproj into your application's project, then add libSimperium.a in your target's Build Phase tab (under Link Binary with Libraries). You'll still need to [add some dependencies](http://simperium.com/docs/ios/#add). Note that you shouldn't have Simperium.xcodeproj open in another window at the same time. Xcode doesn't like this.

If for some reason you want to build a binary framework, open Simperium.xcodeproj, then select and build the Framework target for iOS Device. You can build a release version of the Framework target by choosing Product -> Build for Archiving.

OSX
---
Everything works pretty much the same on OSX. Some changes are noted [in the online documentation](http://simperium.com/docs/ios/).

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

**Binary**. Basic support for moving binary files, either between client devices or potentially from a server to clients. Currently works by syncing a file URI and then using that to upload/download the corresponding data to/from S3. Still under development.

Known transgressions
--------------------
If you decide to dig into the source code, please expect problems and violations of best practices. Your help in identifying these would be greatly appreciated.

* ASI is still being used for HTTP requests, but WebSockets are intended to replace HTTP eventually anyway
* Core Data threading is currently messy (iOS 4 was originally targeted)
* Full WebSockets support is still being fleshed out
* Support for raw JSON (without Core Data) is still being fleshed out
* Some TODOs and hacks remain in the code
* Some support for binary files and collaboration is committed, but not finished
* Auth UI is in a .xib but could live more happily as code instead
* External libraries are included as source files instead of submodules

If you spot more transgressions that you don't feel like fixing yourself, you can add an issue, append to this list via a pull request, or [contact us](http://simperium.com/contact/).

License
-------
The Simperium iOS library is available for free and commercial use under the MIT license.