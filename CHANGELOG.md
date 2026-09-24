# Changelog

The format of this document is inspired by [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!-- This is a comment, you won't see it when GitHub renders the Markdown file.

When releasing a new version:

1. Remove any empty section (those with `_None._`)
2. Update the `## Unreleased` header to `## <version_number>`
3. Add a new "Unreleased" section for the next iteration, by copy/pasting the following template:

## Unreleased

### Breaking Changes

_None._

### New Features

_None._

### Bug Fixes

_None._

### Internal Changes

_None._

-->

## Unreleased

### Breaking Changes

_None._

### New Features

_None._

### Bug Fixes

_None._

### Internal Changes

_None._

## 1.9.2

### Bug Fixes

- Fix the XCFramework failing Xcode's signature verification, which stopped apps from building against 1.9.1 via Swift Package Manager. [#631]

## 1.9.1

### New Features

- The library can now be integrated via Swift Package Manager, as a prebuilt XCFramework. [#624]

### Bug Fixes

- Retry websocket connections that drop before completing the handshake, instead of leaving the client stuck offline. [#628]
