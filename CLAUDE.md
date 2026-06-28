# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Tooling and commands

- Package manager: `pnpm` (the repo also contains `package-lock.json` / `bun.lock`, but `package.json` declares pnpm)
- Frontend install: `pnpm install`
- Frontend dev server only: `pnpm run dev`
- Desktop app dev: `pnpm run tauri dev`
- Alternative desktop dev entry: `make dev`
- Frontend build: `pnpm run build`
- Lint frontend/TS: `pnpm run lint`
- Preview built frontend: `pnpm run preview`
- Run raw Tauri CLI: `pnpm run tauri <args>`

## Rust / Tauri commands

- Build standalone CLI binary: `cargo build --manifest-path src-tauri/Cargo.toml --bin codex-tools-cli`
- Build standalone proxy daemon binary: `cargo build --manifest-path src-tauri/Cargo.toml --bin codex-tools-proxyd`
- Run Rust tests: `cargo test --manifest-path src-tauri/Cargo.toml`
- Run a single Rust test: `cargo test --manifest-path src-tauri/Cargo.toml <test_name>`
  - Example: `cargo test --manifest-path src-tauri/Cargo.toml api_proxy_key_validation_accepts_fast_service_tier_alias`

## Local service helper commands

The root `Makefile` wraps local service scripts for the codex proxy workflow:

- `make codex-start`
- `make codex-stop`
- `make codex-restart`
- `make codex-status`
- `make codex-tail`
- `make codex-logs`
- `make codex-install`
- `make codex-uninstall`
- `make codex-service-status`
- `make codex-service-restart`

## Architecture overview

This repo is a Tauri desktop application with three closely related surfaces:

1. A React + Vite desktop frontend in `src/`
2. A Rust Tauri backend in `src-tauri/src/`
3. Standalone Rust binaries for CLI/TUI and proxy-daemon use

### Frontend shape

- `src/main.tsx` mounts the app and wraps it with the i18n provider.
- `src/App.tsx` is the top-level composition layer for the UI panels.
- `src/hooks/useCodexController.ts` is the main frontend orchestration point. It owns the bulk of UI state, calls Tauri `invoke(...)` commands, localizes backend errors, and coordinates account management, API proxy state, cloudflared, remote proxy deployment, settings, and updates.
- `src/components/` contains the major product surfaces (`AccountsGrid`, `AnalyticsPanel`, `ApiProxyPanel`, `SettingsPanel`, etc.). Most of them are relatively presentational compared with `useCodexController`.
- `src/types/app.ts` mirrors the backend command payload/result shapes used by the frontend.

When adding frontend behavior, check `useCodexController` first before introducing new state containers.

### Backend shape

- `src-tauri/src/lib.rs` is the backend hub. It wires the Tauri app, registers all `#[tauri::command]` handlers, initializes tray/menu/update/autostart behavior, hydrates settings into memory, and starts background loops.
- The command handlers in `lib.rs` are intentionally thin wrappers. Core logic lives in focused modules such as:
  - `account_service.rs` for account CRUD/import/export/switch flows
  - `settings_service.rs` for persisted settings and live in-memory synchronization
  - `proxy_service.rs` for the OpenAI-compatible `/v1` proxy, API keys, usage logs, and request-body capture
  - `cloudflared_service.rs` for public tunnel management
  - `remote_service.rs` for deploying/running the proxy on remote Linux hosts
  - `store.rs` for persisted account/settings storage
  - `profile_files.rs` / `auth.rs` / `usage.rs` for Codex auth/profile/usage integration

### Persistence and runtime state

There are two important state layers:

- Persistent store: `AccountsStore` in `src-tauri/src/models.rs`, loaded/saved via `store.rs`. This is the durable source for saved accounts and app settings.
- Runtime process state: `AppState` in `src-tauri/src/state.rs`. It holds mutex-protected live handles for store access, OAuth flow state, the in-process API proxy, and cloudflared.

A key design detail: `settings_service.rs` hydrates persisted settings into `AppState.settings` at startup and updates that in-memory copy on settings changes, so long-running runtime components can read fresh settings without requiring an app restart.

### Desktop app, CLI, and daemon relationship

There is one shared Rust codebase with multiple entrypoints:

- `src-tauri/src/main.rs` launches either CLI mode or the Tauri desktop app.
- `src-tauri/src/command_line.rs` implements the standalone CLI/TUI commands such as `list`, `switch`, `login`, `import`, `export`, `usage`, `doctor`, `report`, and `tui`.
- `src-tauri/src/bin/codex-tools-cli.rs` exposes that CLI directly as a dedicated binary.
- `src-tauri/src/proxy_daemon.rs` runs the API proxy as a standalone daemon process.
- `src-tauri/src/bin/codex-tools-proxyd.rs` and the separate crate under `src-tauri/proxyd/` both package the daemon entrypoint.

Important: the standalone `src-tauri/proxyd/` crate reuses source files from `src-tauri/src/` via `#[path = ...]` includes rather than maintaining a second implementation. Changes to proxy/runtime/store code often affect both the desktop app and standalone proxyd builds.

### Proxy subsystem

The local API proxy is one of the core architectural features of the repo.

- Main implementation lives in `src-tauri/src/proxy_service.rs`.
- It serves an OpenAI-compatible `/v1` API, manages API keys, request logging, usage aggregation, supported-model filtering, service-tier/reasoning validation, and account selection.
- Runtime selection/affinity state is tracked in `ApiProxyRuntimeSnapshot` / `ApiProxyRuntimeHandle` in `state.rs`.
- The same proxy logic can run:
  - inside the desktop app via Tauri commands
  - as a standalone daemon via `proxy_daemon.rs`
  - on remote hosts via `remote_service.rs`

Because this area is reused in several execution modes, verify whether a change affects desktop-only behavior, standalone proxyd behavior, or both.

### Distribution layout

- `npm/` contains the npm wrapper package plus platform-specific native package metadata.
- `public/` contains app assets such as screenshots.
- `docs/` contains feature-specific docs, especially `docs/api-proxy.md` and `docs/linux-proxyd.md`.

## Notes for future edits

- Frontend tests are not configured in `package.json`; validation is mainly via `pnpm run lint` and Rust tests in `src-tauri`.
- `src-tauri/tauri.conf.json` still uses `npm run dev` / `npm run build` in Tauri’s `beforeDevCommand` and `beforeBuildCommand`, but when operating manually in this repo prefer `pnpm` commands.
- After modifying code, run `codegraph sync`.
