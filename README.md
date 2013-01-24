# simperium-ios

Simperium is a simple way for developers to move data as it changes, instantly and automatically. This is the iOS / OSX library. You can [browse the documentation](http://simperium.com/docs/ios/) or [try a tutorial](https://simperium.com/tutorials/simpletodo-ios/).

You can [sign up](http://simperium.com) for a hosted version of Simperium. There are Simperium libraries for [other languages](https://simperium.com/overview/) too.

### Known transgressions
If you decide to dig into the source code, please expect problems and violations of best practices. Your help in identifying these would be greatly appreciated.

* ASI is still being used for HTTP requests, but WebSockets are intended to replace HTTP eventually anyway
* Some external libraries (still) haven't been properly "namespaced" (with prefixes)
* Core Data threading is currently messy (iOS 4 was originally targeted)
* Full WebSockets support is still being fleshed out
* Support for raw JSON (without Core Data) is still being fleshed out
* No CocoaPods support yet
* Some TODOs and hacks remain in the code
* Some support for binary files and collaboration is committed, but not finished
* Auth UI is in a .xib but could live more happily as code instead
* External libraries are included as source files instead of submodules

If you spot more transgressions that you don't feel like fixing yourself, please add an issue, append to this list via a pull request, or [contact us](http://simperium.com/contact/).

### License
The Simperium iOS library is available for free and commercial use under the MIT license.