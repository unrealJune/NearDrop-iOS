# LiftDrop for iOS

## Product

LiftDrop moves files and links between Android and iPhone or iPad on the same
Wi-Fi network, without accounts or cloud uploads.

The first release is for general App Store users who regularly cross the
Android and Apple ecosystem boundary. Sending and receiving are equally
important. The app is useful only while it is open in the foreground; the
interface must communicate that constraint without making the product feel
broken.

## Experience principles

- Calm, tactile, and quietly technical.
- One continuous island changes state instead of stacking dashboard cards.
- Native SwiftUI controls, navigation, sheets, importers, and share surfaces.
- Dot-matrix text is a signature status readout, never body copy or a control.
- Files remain local. Received content is stored in the app sandbox and is
  exported with the system share sheet.
- Accessibility follows the platform: Dynamic Type, VoiceOver, Reduce Motion,
  increased contrast, and minimum 44-point targets.

## Core flow

1. Open LiftDrop to become available on the local network.
2. Choose files or a link, then select a discovered Android device.
3. If the Android receiver is not visible, show a Quick Share QR code.
4. Verify the four-digit code, accept on the receiving device, and watch
   transfer progress in place.
5. For incoming content, review the sender and payload before accepting.
6. Share or save received content through system destinations.

## Scope

The initial transport is Quick Share over Wi-Fi LAN. Background receiving,
Bluetooth discovery, Wi-Fi Direct, contact visibility, cloud relay, and direct
Photos-library writes are out of scope for the first release.

## Success

- An Android user and an iPhone user can complete a transfer without creating
  an account or understanding network terminology.
- Foreground availability and same-Wi-Fi requirements are apparent before a
  failed transfer.
- Protocol failures are explicit and recoverable.
- The app remains legible and operable with accessibility text sizes and
  Reduce Motion enabled.
