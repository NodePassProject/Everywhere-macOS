# Patches

Consumer-side notes for `Everywhere-macOS`. Build mechanics, upstream
tag matrix, `gomobile bind` flags, and per-core wiring quirks now live
upstream at
[NodePassProject/EverywhereCore](https://github.com/NodePassProject/EverywhereCore) —
see its README and `Scripts/build.sh` if you need to touch the Go side.

## Pinned EverywhereCore version

`Scripts/wire_project.rb` pins the SwiftPM dependency to a single tag:

```ruby
EVERYWHERE_CORE_VERSION = '2026.05.14'
```

Bump that string and rerun `./build.sh` to roll forward. The upstream
ships a daily-rolled `vYYYY.MM.DD` tag whenever Xray / sing-box / mihomo
release; pick the latest tag that has had time to soak.

## Wiring requirements `Scripts/wire_project.rb` enforces

These are not patches — they are settings that the Xcode project needs
on both targets for the framework to load and the Go runtime to find
its DNS resolver. The wire script is idempotent, so running it after
an Xcode UI edit reasserts them.

- `MACOSX_DEPLOYMENT_TARGET = 14.0` — driven by `ContentUnavailableView`
  in `Everywhere/Editor/ConfigEditorScreen.swift`. Upstream
  `EverywhereCore`'s `Package.swift` only requires `.macOS(.v13)`, so
  this is purely a consumer-side decision.
- `libresolv.tbd` linked into both `Everywhere` and `EverywhereNE` —
  the Go runtime's DNS resolver path on darwin pulls `res_*` symbols
  from `libresolv`.
- No manual `Embed Frameworks` entry for the SwiftPM product. Xcode
  auto-embeds binary targets that appear in the Frameworks build phase.
  Adding the product to a Copy Files phase by `productRef` double-
  resolves and fails with `No such file or directory` on the bare
  product name.
- `ThirdParty/zashboard` registered as a folder reference (blue folder,
  `lastKnownFileType = folder`) on the app target's Resources phase —
  zashboard's `index.html` references its bundled assets via relative
  paths (`./assets/index-*.js`), which only works if Xcode preserves
  the directory layout on copy. The release build is checked into the
  repo as a static bundle; there is no source build step.

## NEPacketTunnelProvider on macOS

The Network Extension is shipped as an `.appex` bundled in
`Everywhere.app/Contents/PlugIns/`. The provider is loaded by the
system's `nesessionmanager`, talks to the app over the App Group
container `group.com.argsment.Everywhere`, and owns the `utun` device.
The extension links against the same `EverywhereCore` SwiftPM product
as the app and resolves the framework at runtime from the host app's
`Frameworks/` directory — only the app target embeds, not the
extension.
