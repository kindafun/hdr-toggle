# Development

Author-only notes. This file is not part of the extension published to the Store.

## Layout

```
src/            TypeScript commands
swift/          Swift package exposed through Raycast's Swift bridge
metadata/       Store screenshots (2000×1250)
design/         Icon and screenshot generators (author-only)
```

## Requirements

- Xcode 16.3 or later, selected as the active developer directory. Raycast's
  bundler shells out to `xcodebuild` for the Swift package; Command Line Tools
  alone are not enough.
- Node 22 and npm.

## Build

```sh
npm install
npm run build        # ray build, includes the Swift package
npm run dev          # hot reload in Raycast
npm run lint
```

The Swift package is compiled by Raycast's bundler, not by `swift build` alone.
For a faster edit loop on the native side, `cd swift && swift build` still
catches type errors, but the bundler produces the TypeScript bindings.

`swift/index.d.ts` is a hand-maintained declaration of the generated bridge, so
`tsc` can typecheck before `xcodebuild` has produced `.build/.../raycast.d.ts`.
Keep it in sync with `swift/Sources/ExternalHDR/API.swift`.

## Private framework

The Swift target links the private `MonitorPanel` framework with:

```swift
.unsafeFlags(["-F/System/Library/PrivateFrameworks"]),
.linkedFramework("MonitorPanel")
```

`hdr_set` in `swift/Sources/HDRCore/HDRCore.m` is the only code that touches the
display. It calls `setPreferHDRModes:` and polls until the mode settles.

## Icon

```sh
swift design/icon.swift assets/icon.png word   # or monitor / sun
```

Rendered at 1024 and downscaled to 512 with `sips -z 512 512`.

## Screenshots

```sh
swift design/store-shot.swift raw.png metadata/external-hdr-1.png
```

The source capture must be 1500×950 (a 2× window capture) to land on Raycast's
2000×1250 canvas without scaling.
