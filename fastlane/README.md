fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

### mac_test

```sh
[bundle exec] fastlane mac_test
```

Run the macOS unit test suite (VizRemoteTests)

### mac_build

```sh
[bundle exec] fastlane mac_build
```

Debug build sanity check — compiles the app, no signing/export/upload

### mac_release

```sh
[bundle exec] fastlane mac_release
```

Archive, sign, and upload to the Mac App Store — requires a paid Developer Program membership

### ci

```sh
[bundle exec] fastlane ci
```

Run the macOS tests and confirm the app builds

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
