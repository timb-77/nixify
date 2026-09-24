# Requirements: nixify

**Defined:** Tue Sep 22 2026
**Core Value:** A single declarative source of truth makes every Linux machine reproducible, version-controlled, and provisionable from a fresh install in under an hour.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Infrastructure

- [ ] **NIX-01**: Support both NixOS hosts and non-NixOS hosts (standalone Home Manager) from the same flake
- [ ] **NIX-02**: Provide identical user-level configuration across both host types
- [x] **NIX-03**: Implement layered configuration (Base → Roles → Host) with clear precedence
- [x] **NIX-04**: Enable adding new hosts by touching only hosts/<name>/ and one line in flake.nix
- [x] **NIX-12**: Use single nixpkgs input (26.05 stable) with Home Manager following same nixpkgs
- [x] **NIX-13**: Support x86_64-linux with aarch64-linux possible without redesign

### Base Tooling

- [ ] **NIX-05**: Include base tools on all machines (git, tmux, vim, vim-cpp, vim-py)
- [ ] **NIX-06**: Provide vim-cpp and vim-py as side-by-side flavors with shared core, no runtime plugin fetching
- [ ] **NIX-07**: Keep plain vim available with common core only
- [ ] **NIX-14**: Implement working Vim debugging (vimspector) for both C++ and Python
- [ ] **NIX-15**: Manage bash as base shell

### Secrets

- [ ] **NIX-08**: Manage secrets with sops-nix, encrypted in repo, decrypted only on target machine
- [ ] **NIX-09**: Support both NixOS and standalone Home Manager with sops-nix

### Verification & Bootstrap

- [x] **NIX-10**: Pass nix flake check building all host closures and Home Manager configs
- [x] **NIX-11**: Use nixfmt/alejandra with formatter wired to nix flake check
- [ ] **NIX-16**: Manage critical GUI apps in Nix where appropriate on non-NixOS hosts
- [ ] **NIX-17**: Enable bootstrap from fresh machine in under 1 hour with <10 manual steps
- [ ] **NIX-18**: Support first host (Pop!_OS 22.04 x86_64) as standalone Home Manager

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Multi-Host

- **NIX-19**: Fully manage one NixOS host with system modules and NixOS-level secrets
- **NIX-20**: Verify bootstrap by provisioning a fresh VM of each host kind

### GUI

- **NIX-21**: Manage full desktop application set through Nix on non-NixOS hosts

## Out of Scope

| Feature | Reason |
|---------|--------|
| Remote/fleet tooling (deploy-rs, colmena, nixops) | Single-user, single maintainer |
| macOS / nix-darwin / WSL | Linux only |
| CI pipeline | Local nix flake check sufficient for v1 |
| Disk partitioning (disko), impermanence, secure boot | Not needed for personal config |
| Desktop environment theming | Beyond installing apps |
| Neovim | Vim proper specified |
| Runtime plugin fetching at all | Violates pinned/offline constraint |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| NIX-01 | Phase 7 | Pending |
| NIX-02 | Phase 7 | Pending |
| NIX-03 | Phase 1 | Complete |
| NIX-04 | Phase 1 | Complete |
| NIX-05 | Phase 2 | Pending |
| NIX-06 | Phase 3 | Pending |
| NIX-07 | Phase 2 | Pending |
| NIX-08 | Phase 5 | Pending |
| NIX-09 | Phase 5 | Pending |
| NIX-10 | Phase 1 | Complete |
| NIX-11 | Phase 1 | Complete |
| NIX-12 | Phase 1 | Complete |
| NIX-13 | Phase 1 | Complete |
| NIX-14 | Phase 4 | Pending |
| NIX-15 | Phase 2 | Pending |
| NIX-16 | Phase 7 | Pending |
| NIX-17 | Phase 6 | Pending |
| NIX-18 | Phase 6 | Pending |

**Coverage:**

- v1 requirements: 18 total
- Mapped to phases: 18
- Unmapped: 0 ✓

---
*Requirements defined: Tue Sep 22 2026*
*Last updated: Tue Sep 22 2026 after roadmap traceability mapping*
