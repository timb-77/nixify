# nixify

## What This Is

nixify is a single Nix flake repository that declaratively defines the complete configuration of every Linux computer I own. It supports both NixOS hosts (full system configuration) and non-NixOS hosts with standalone Home Manager (user environment only), applying the same configuration to any machine with one command. The same user-level configuration produces an identical experience across both host types.

## Core Value

A single declarative source of truth makes every Linux machine reproducible, version-controlled, and provisionable from a fresh install in under an hour.

## Business Context

Not applicable — single-person personal project.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] **NIX-01**: Support both NixOS hosts and non-NixOS hosts (standalone Home Manager) from the same flake
- [ ] **NIX-02**: Provide identical user-level configuration across both host types
- [ ] **NIX-03**: Implement layered configuration (Base → Roles → Host) with clear precedence
- [ ] **NIX-04**: Enable adding new hosts by touching only hosts/<name>/ and one line in flake.nix
- [ ] **NIX-05**: Include base tools on all machines (git, tmux, vim, vim-cpp, vim-py)
- [ ] **NIX-06**: Provide vim-cpp and vim-py as side-by-side flavors with shared core, no runtime plugin fetching
- [ ] **NIX-07**: Keep plain vim available with common core only
- [ ] **NIX-08**: Manage secrets with sops-nix, encrypted in repo, decrypted only on target machine
- [ ] **NIX-09**: Support both NixOS and standalone Home Manager with sops-nix
- [ ] **NIX-10**: Pass nix flake check building all host closures and Home Manager configs
- [ ] **NIX-11**: Use nixfmt/alejandra with formatter wired to nix flake check
- [ ] **NIX-12**: Use single nixpkgs input (26.05 stable) with Home Manager following same nixpkgs
- [ ] **NIX-13**: Support x86_64-linux with aarch64-linux possible without redesign
- [ ] **NIX-14**: Implement working Vim debugging (vimspector) for both C++ and Python
- [ ] **NIX-15**: Manage bash as base shell
- [ ] **NIX-16**: Manage critical GUI apps in Nix where appropriate on non-NixOS hosts
- [ ] **NIX-17**: Enable bootstrap from fresh machine in under 1 hour with <10 manual steps
- [ ] **NIX-18**: Support first host (Pop!_OS 22.04 x86_64) as standalone Home Manager

### Out of Scope

- **Remote/fleet tooling** — deploy-rs, colmena, nixops (not needed for single-user)
- **macOS/WSL** — Linux only
- **CI pipeline** — local nix flake check sufficient for v1
- **Disk partitioning** — disko, impermanence, secure boot not in scope
- **Full DE theming** — beyond installing apps

## Context

Current environment: Pop!_OS 22.04, x86_64-linux, Nix 2.29 with flakes enabled, standalone Home Manager 25.11-pre installed. Single user, personal machines. Goal is to replace per-machine manual setup with declarative configuration.

## Constraints

- **Nix flakes only** — pure evaluation, no channels, no nix-env, no imperative state
- **Single nixpkgs input** — pinned to nixos-26.05 stable (25.05 EOL 2025-12-31; superseded to avoid known-vulnerable packages)
- **Home Manager integration** — as NixOS module on NixOS, standalone elsewhere, sharing modules/home
- **Secrets security** — plaintext never in repo or world-readable store; one age key per host
- **Vim constraints** — Vim proper (not Neovim), two flavors side-by-side without sharing plugin state, plugins pinned in Nix, no runtime fetching

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| nixpkgs pinned to 26.05 stable | 25.05 EOL 2025-12-31 (no security updates); 26.05 is the only supported stable | — Pending |
| Use vimspector for Vim debugging | Unified debugging UI for both C++ and Python | — Pending |
| Manage bash as base shell | Universal, works everywhere by default | — Pending |
| Critical GUI apps in Nix on non-NixOS | Balance reproducibility with practicality | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: Tue Sep 22 2026 after initialization*