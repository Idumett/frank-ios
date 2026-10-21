# Frank for iOS

Frank is an AI accessibility assistant for blind and low-vision users. This
repository contains the native SwiftUI client. The existing Frank server remains
the source of truth for conversation, memory, product actions and Context Snapshot
policy.

## Stage 1 baseline

- Authenticated WebSocket connection to `/v1/device/stream`, with bounded reconnects.
- Request-bound voice turns, adaptive quiet-speech detection and WAV upload.
- Typed transcript, reply, audio, error, stop and acknowledgement handling.
- Spoken MP3 replies with interruption, route-change and cancellation handling.
- A short camera buffer that continuously focuses and only supplies fresh evidence
  after the server asks for it.
- Context Snapshot V1 for time, permissions, app state, device state, location,
  movement and evidence. Unknown and denied signals remain distinct.
- Server-owned memory, saved-place and product-action conversations. The iOS app
  keeps follow-ups in the same session and does not guess action phrases locally.
- Deterministic protocol, recovery, cancellation, audio, evidence and context tests.

Stage 1 proves that a native iOS client can complete Frank's main online loop.
Apple signing, deliberate permission onboarding, visual design and physical-device
accessibility checks belong to Stages 2 and 3.

## Project map

- `Frank/App` creates the live dependencies.
- `Frank/Core/Networking` owns the authenticated WebSocket and reconnect policy.
- `Frank/Core/Protocol` mirrors the server's versioned device messages.
- `Frank/Core/Audio` records, detects speech, encodes and plays audio.
- `Frank/Core/Camera` prepares a small fresh-frame buffer.
- `Frank/Core/Context` creates Context Snapshot V1.
- `Frank/Features/Assistant` coordinates one user turn and drives the screen.
- `FrankTests` contains contract, unit and complete-flow tests.

## Local build

Copy `Configuration/Local.xcconfig.example` to
`Configuration/Local.xcconfig`, fill in local values, then select the `Frank`
scheme in Xcode. `Local.xcconfig` is ignored and must never be committed.

`FRANK_SERVER_URL` is the HTTPS base URL, without `/v1/device/stream`. The client
adds the path and changes HTTPS to WSS. `FRANK_ACCESS_TOKEN` is the matching
mobile access token. Keep both values out of Git.

```sh
xcodebuild -project Frank.xcodeproj -scheme Frank \
  -destination 'generic/platform=iOS' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

Run the test suite against an installed simulator:

```sh
xcodebuild -project Frank.xcodeproj -scheme Frank \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO test
```

Frank targets iOS 17 and later. The GitHub workflow repeats the unsigned build
and simulator tests for pull requests and pushes to `main`.

## Stage 2 hand-off

Stage 2 needs the Apple Developer team, bundle signing and a physical iPhone.
That stage will request microphone, camera, location and motion permissions in a
clear onboarding flow, then verify Bluetooth audio, phone-in-pocket use, camera
focus, poor GPS, interruption recovery and VoiceOver on hardware. Stage 1 does
not claim those physical checks have happened.

## Ownership

All source code remains the intellectual property of **Hilary Asogwa**. No
permission is granted to copy, modify, redistribute or use this software without
prior written consent.
