# Frank for iOS

Frank is an AI accessibility assistant for blind and low-vision users. This
repository contains the native SwiftUI client. The existing Frank server remains
the source of truth for conversation, memory, product actions and Context Snapshot
policy.

## Current foundation

- SwiftUI application shell with VoiceOver-friendly state announcements.
- Explicit configuration boundary for server URL and access credentials.
- Typed assistant state and transport boundaries.
- Initial unit-test target and feature-oriented source layout.

The first working milestone is the voice conversation loop. Context Snapshot,
saved places, memory actions and prepared camera evidence follow on the same
versioned server contracts.

## Local build

Copy `Configuration/Local.xcconfig.example` to
`Configuration/Local.xcconfig`, fill in local values, then select the `Frank`
scheme in Xcode. `Local.xcconfig` is ignored and must never be committed.

```sh
xcodebuild -project Frank.xcodeproj -scheme Frank \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Frank currently targets iOS 17 and later. Physical-device audio, camera, location
and VoiceOver checks remain required before TestFlight distribution.

## Ownership

All source code remains the intellectual property of **Hilary Asogwa**. No
permission is granted to copy, modify, redistribute or use this software without
prior written consent.
