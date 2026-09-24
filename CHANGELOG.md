# Changelog

All notable changes to ScreenDimmer are documented here.

## v1.2.0 — 2026-09-24

- Added this release history and repository-contract checks for required project metadata.
- Added a GitHub Actions workflow for the local brightness-policy and gamma tests.
- Added an MIT license file so redistribution terms are explicit.

## v1.1.0 — 2026-09-22

- Replaced the primary overlay-only dimming path with display gamma-table dimming to avoid flashes during Spaces transitions.
- Added live verification notes for gamma readback, restoration, and transition sampling.
- Kept the overlay implementation as a labeled fallback for unsupported displays.

## v1.0.0 — 2026-09-22

- Initial local macOS menu bar app for synchronized software dimming across selected displays.
- Added display selection persistence, pause/restore controls, diagnostics, and integration-test entry points.
