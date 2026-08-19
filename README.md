# LiftDrop

LiftDrop is a native SwiftUI iOS app for sending and receiving files over
Google Quick Share. It is a port of
[NearDrop](https://github.com/grishka/NearDrop), a partial implementation of
the protocol.

The iOS app sends and receives files and links over the local Wi-Fi network
without accounts or cloud uploads. It uses a foreground-only availability
model, sandboxed received-file storage, system export surfaces, and a SwiftUI
share extension.

LiftDrop is an independent open-source project. It is not affiliated with,
endorsed by, or sponsored by Google. Quick Share is a trademark of Google LLC.

The original macOS source remains in `NearDrop/` and `ShareExtension/` for
upstream reference. The iOS application lives in `Sources/`, shares the
protocol implementation in `NearbyShare/`, and is described by `project.yml`.

## Generate the Xcode project

On macOS with Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
xcodegen generate
open LiftDrop.xcodeproj
```

Set your development team and bundle identifiers before running on a device.
Simulator discovery is not representative; verify interoperability with
physical iPhone/iPad and Android devices.

## Current constraints

- Wi-Fi LAN only.
- iOS asks for Local Network access the first time LiftDrop looks for devices.
  Discovery and receiving stay unavailable until it is allowed, and the app
  offers a link to Settings if it was refused.
- LiftDrop must remain open in the foreground to receive.
- Both devices must be on a local network that allows peer-to-peer traffic.
- Android visibility may require scanning the QR code shown by LiftDrop.

[Protocol documentation](PROTOCOL.md), [product brief](PRODUCT.md), and
[design brief](DESIGN.md) are available in the repository.

## Attribution

This repository preserves the history and public-domain dedication of
[grishka/NearDrop](https://github.com/grishka/NearDrop). Generated protocol
definitions retain their original Apache 2.0 copyright and license notices.
