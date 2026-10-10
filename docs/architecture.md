# Architecture

The iOS client is organised by feature with a small shared core:

- `App` owns composition and the application lifecycle.
- `Core/Configuration` reads build-time configuration without embedding secrets.
- `Core/Models` contains local state and will hold contract mirrors.
- `Core/Networking` owns the WebSocket transport boundary.
- `Features` contains SwiftUI screens and their observable state.

UI code does not parse wire messages or perform provider work. The transport will
decode versioned server envelopes into typed Swift models. Feature models will
coordinate permissions and device signals while the server remains responsible for
policy, ownership, persistence and assistant actions.
