# Meridian

Meridian is a local-first senior-care monitoring prototype. The repo currently contains the product requirements, architecture/spec documents, Pi and Hub benchmark notes, and early ESP32-CAM firmware scaffolding for the camera nodes.

## Repository Layout

- `PRD.md` - product requirements and positioning.
- `docs/` - system specs, integration contracts, and implementation plans.
- `benchmarks/` - benchmark scripts and measured hardware notes.
- `firmware/esp32cam/` - ESP32-CAM camera-node firmware files.
- `meridian_hub/` - laptop/Hub application package placeholder.
- `tools/` - operational and benchmark tooling placeholder.
- `tests/` - automated test placeholder.
- `codex.md` - local Codex coordination notes for this workspace.

## Current State

The repo is still in prototype setup. The docs and benchmark work are the source of truth, and the first code currently present is ESP32-CAM configuration/pin scaffolding. The Hub implementation is planned but not yet committed as runnable application code.

## Safety Notes

Do not commit device credentials, Wi-Fi passwords, API keys, local model weights, recorded resident footage, SQLite databases, or generated build artifacts. Use the example config files as templates and keep real values local.
