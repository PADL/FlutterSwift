# Darwin (iOS / macOS) Xcode setup

Two pieces of host-project setup are required for any Flutter app that consumes
FlutterSwift as a Swift package on Darwin. Neither is something FlutterSwift can
do from its own `Package.swift`; both live in the app's Xcode project or in the
developer's Xcode configuration.

`Examples/counter` has both applied and can be used as a reference.

---

## 1. Add the "Prepare Flutter Framework" scheme pre-action (iOS only)

### Symptom

A clean iOS build fails while compiling the app target:

```
Runner/AppDelegate.swift:25:30: error: cannot find 'FlutterPlatformMessenger' in scope
```

Building a second time (without cleaning) turns it into a link failure, because
`FlutterSwift.swiftmodule` is regenerated but the stale object file is not:

```
Undefined symbols for architecture arm64:
  "FlutterSwift.FlutterPlatformMessenger.__allocating_init(wrapping:) -> ..."
  "protocol witness table for FlutterSwift.FlutterPlatformMessenger : FlutterSwift.FlutterBinaryMessenger in FlutterSwift"
  "type metadata accessor for FlutterSwift.FlutterPlatformMessenger"
```

### Cause

`FlutterPlatformMessenger` is guarded by `#if canImport(Flutter)`, and
`Flutter.framework` is not vendored by FlutterSwift — the host project supplies
it via `$(FRAMEWORK_SEARCH_PATHS)`/`$(BUILT_PRODUCTS_DIR)`.

On **macOS** the Runner target depends on a separate `Flutter Assemble`
aggregate target, which runs `macos_assemble.sh` and drops
`FlutterMacOS.framework` into `BUILT_PRODUCTS_DIR` before anything else builds.
That is why macOS has always worked.

On **iOS** there is no aggregate target: the equivalent work is a *"Run Script"*
build phase **inside** the Runner target (`xcode_backend.sh build`). Xcode builds
a target's dependencies — including all SwiftPM package targets — before running
that target's script phases. So when the `FlutterSwift` package target compiles,
`Flutter.framework` does not exist yet, `canImport(Flutter)` is false, and
`FlutterPlatformMessenger` is silently compiled out.

### Fix

Add the same scheme pre-action that Flutter's own Swift Package Manager
integration migration installs. It runs `xcode_backend.sh prepare`, which unpacks
the engine framework into `BUILT_PRODUCTS_DIR` *before* any target — package
targets included — is built.

Edit `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` and insert a
`<PreActions>` block as the first child of `<BuildAction>`:

```xml
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <PreActions>
         <ExecutionAction
            ActionType = "Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction">
            <ActionContent
               title = "Run Prepare Flutter Framework Script"
               scriptText = "/bin/sh &quot;$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh&quot; prepare&#10;">
               <EnvironmentBuildable>
                  <BuildableReference
                     BuildableIdentifier = "primary"
                     BlueprintIdentifier = "97C146ED1CF9000F007C117D"
                     BuildableName = "Runner.app"
                     BlueprintName = "Runner"
                     ReferencedContainer = "container:Runner.xcodeproj">
                  </BuildableReference>
               </EnvironmentBuildable>
            </ActionContent>
         </ExecutionAction>
      </PreActions>
      <BuildActionEntries>
      ...
```

Substitute `BlueprintIdentifier`, `BuildableName` and `BlueprintName` with the
values from that scheme's own `<BuildActionEntry>` — they differ per project
(e.g. `BuildableName = "Monitor Two.app"`). If the scheme already has a
`<PreActions>` block, append this `<ExecutionAction>` to it rather than adding a
second block.

**After applying, clean once** (Xcode: Product ▸ Clean Build Folder, or delete
the project's DerivedData). Existing DerivedData contains a `FlutterSwift` object
file compiled without `FlutterPlatformMessenger`; the scheme change alone will
not invalidate it, and you will keep seeing the undefined-symbol link errors.

macOS needs no change — but if a macOS scheme is ever rebuilt from scratch
without the `Flutter Assemble` aggregate target, add the equivalent pre-action
running `"$FLUTTER_ROOT"/packages/flutter_tools/bin/macos_assemble.sh prepare`.

---

## 2. Disable Xcode's prebuilt swift-syntax

### Symptom

`flutter build ios --simulator` / `flutter run` on a simulator fails while
building a dependency of FlutterSwift:

```
Swift Compiler Error (Xcode): Unable to find module dependency: 'SwiftSyntax'
  .../swift-binary-parsing/Sources/BinaryParsingMacros/Extensions.swift:11:7
warning: module file '.../prebuilts/swift-syntax/602.0.0/swiftlang-...-MacroSupport-macos_aarch64/Modules/SwiftSyntax.swiftmodule'
         is incompatible with this Swift compiler: SDK does not match
```

macOS is unaffected, and so is building from the Xcode GUI.

### Cause

FlutterSwift depends on `swift-binary-parsing`, which declares a `.macro` target
(`BinaryParsingMacros`). SwiftPM emits that as a
`com.apple.product-type.tool.host-build` target with `SDKROOT = auto`, so Xcode
normally builds it for macOS regardless of the run destination, and links it
against SwiftPM's *prebuilt, macOS-only* swift-syntax binaries.

The Flutter tool invokes xcodebuild with **`-sdk iphonesimulator`** for simulator
builds. A command-line build setting outranks everything else and is applied to
every target in the graph — including host-build tool targets. `BinaryParsingMacros`
is therefore compiled with `-target arm64-apple-ios…-simulator` against macOS
swiftmodules, which the compiler rejects.

The Xcode GUI passes a destination rather than `-sdk`, so it plans the macro for
the host correctly — which is why this only bites command-line Flutter builds.

### Fix

```sh
defaults write com.apple.dt.Xcode IDEPackageEnablePrebuilts -bool NO
```

With prebuilts off, swift-syntax is built from source alongside the macro target
(for the same, wrong, platform) so everything compiles and links. That is safe
here because FlutterSwift only uses `BinaryParsing`'s ordinary API — it never
expands `@Parser` or `#magicNumber` — so the macro plugin executable is never
loaded by the compiler.

Cost: swift-syntax is compiled from source once per DerivedData, for every
project on the machine that uses macros. There is no per-project or
per-invocation equivalent; `IDEPackageEnablePrebuilts` is an Xcode-wide user
default, and xcodebuild rejects it as a command-line flag.

To revert: `defaults delete com.apple.dt.Xcode IDEPackageEnablePrebuilts`.

### Caveat

This workaround only holds while no package in the graph actually *expands* a
macro. If one ever does, the plugin — built for iOS — cannot be loaded by the
host compiler and the build will fail again. At that point the options are to
drop `swift-binary-parsing` from FlutterSwift, or to get the `-sdk` behaviour
changed in the Flutter tool (it is redundant with the `-destination` it already
passes).

---

## Verifying

From the app directory, both of these should succeed from clean:

```sh
rm -rf build/ios
flutter build ios --debug --simulator --no-codesign
flutter build ios --debug --no-codesign
```

To confirm the macro target is being planned for the host, the compile line
should say `-target arm64-apple-macos…`, not `-target arm64-apple-ios…`:

```sh
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug \
  -destination 'generic/platform=iOS Simulator' build 2>&1 \
  | grep 'BinaryParsingMacros normal arm64'
```
