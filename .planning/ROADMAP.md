# Roadmap: nixify

## Overview

nixify begins as a minimal flake skeleton that wires the first Pop!_OS host through dual-eval builders, gated by `nix flake check` and a formatter. Real user modules (git, tmux, bash, plain vim) then prove the standalone path end to end, followed by the project's differentiators: three side-by-side vim flavors and vimspector debugging with adapters resolved from the Nix store. Secrets (sops-nix) lock in their security invariants while only one host exists, then the bootstrap capstone proves the core value — a fresh machine provisioned in under an hour. A second (NixOS) host and critical GUI apps close v1 by validating the dual-host promise for real.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Flake Skeleton & Host Registry** - Minimal dual-eval flake with registry, checks, formatter, and the 26.05 single-nixpkgs pin
- [ ] **Phase 2: Base User Environment** - git, tmux, bash, and plain vim applied end-to-end on standalone Pop!_OS
- [ ] **Phase 3: Vim Flavors** - vim-cpp and vim-py side-by-side with plain vim, shared core, all plugins pinned in Nix
- [ ] **Phase 4: vimspector Debugging** - C++ and Python debugging with store-resolved adapters, zero runtime downloads
- [ ] **Phase 5: Secrets (sops-nix)** - Encrypted-in-repo secrets that decrypt only on target, on both host kinds
- [ ] **Phase 6: Bootstrap & Fresh-Machine Validation** - Fresh Pop!_OS to full managed environment in under 1 hour, <10 manual steps
- [ ] **Phase 7: Second-Host & GUI Validation** - A NixOS host joins via the same registry and home.nix; critical GUI apps managed on non-NixOS

## Phase Details

### Phase 1: Flake Skeleton & Host Registry

**Goal**: A minimal but complete flake skeleton hosts the first Pop!_OS configuration behind dual-eval builders, gated by checks and a formatter
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: NIX-03, NIX-04, NIX-10, NIX-11, NIX-12, NIX-13
**Success Criteria** (what must be TRUE):

  1. `nix flake check` passes, building the home configuration's activation package plus a formatter gate that fails on unformatted .nix files
  2. `nix fmt` (nixfmt-rfc-style) idempotently reformats all .nix files in the repo
  3. `flake.lock` contains exactly one nixpkgs node (26.05 stable) with Home Manager and sops-nix following it
  4. Adding a test host requires only a `hosts/<name>/` directory plus one registry line — flake.nix stays untouched
  5. Module imports follow Base → Roles → Host precedence (host overrides base), and systems are parametrized so aarch64-linux evaluates without redesign

**Plans**: 3 plans
Plans:
**Wave 1**

- [ ] 01-01-PLAN.md — Walking Skeleton: registry-driven flake, composer, two-gate checks, nixfmt-tree formatter, criteria battery

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 01-02-PLAN.md — Decision checkpoint: optional live home-manager switch (research assumption A2)

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 01-03-PLAN.md — User-approved live `home-manager switch --flake .#razer-blade` + marker verification

### Phase 2: Base User Environment

**Goal**: Real user modules — git, tmux, bash, plain vim — apply end-to-end on the standalone Pop!_OS host
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: NIX-05, NIX-07, NIX-15
**Success Criteria** (what must be TRUE):

  1. After `home-manager switch`, git, tmux, and bash are configured by the flake rather than hand-edited dotfiles
  2. Plain `vim` launches with the shared core config (syntax highlighting, migrated settings) and is installed as a Nix package
  3. bash is the managed base shell; opening a new shell loads Home Manager session variables
  4. `nix flake check` still passes with the real modules in the tree

**Plans**: TBD

### Phase 3: Vim Flavors

**Goal**: vim-cpp and vim-py exist side-by-side with plain vim, sharing one core, with every plugin pinned in Nix
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: NIX-06
**Success Criteria** (what must be TRUE):

  1. `vim`, `vim-cpp`, and `vim-py` all launch, each loading only its own disjoint plugin set
  2. Building and installing the flavors never fetches plugins at runtime — an offline build succeeds from pinned `pkgs.vimPlugins`
  3. viminfo/swap/undo/backup state does not leak between flavors — no cross-flavor swap prompts or shared history
  4. Each flavor is buildable standalone (`nix build .#vim-cpp`, `.#vim-py`, `.#vim`) and plain vim still runs with the common core

**Plans**: TBD

### Phase 4: vimspector Debugging

**Goal**: C++ and Python debugging works inside the vim flavors with debug adapters resolved from the Nix store
**Mode:** mvp
**Depends on**: Phase 3
**Requirements**: NIX-14
**Success Criteria** (what must be TRUE):

  1. In vim-cpp, vimspector debugs a sample C++ program (breakpoints, stepping) via CodeLLDB resolved from the nix store
  2. In vim-py, vimspector debugs a sample Python program via debugpy resolved from the nix store
  3. No runtime adapter downloads occur — `~/.vimspector` is never written and `g:vimspector_install_gadgets = []` forbids installs

**Plans**: TBD

### Phase 5: Secrets (sops-nix)

**Goal**: User-level secrets are encrypted in the repo and decrypt only on the target machine at activation, working on both host kinds
**Mode:** mvp
**Depends on**: Phase 4
**Requirements**: NIX-08, NIX-09
**Success Criteria** (what must be TRUE):

  1. A secret's ciphertext is committed while plaintext never appears in the repo or the /nix/store, and `keyFile` is a string path (never `./`)
  2. First activation on Pop!_OS generates the host age key and decrypts the secret into place
  3. The admin key can decrypt every secret file offline (recovery verified)
  4. The same `home/secrets.nix` module evaluates under both standalone Home Manager and the NixOS Home Manager module

**Plans**: TBD

### Phase 6: Bootstrap & Fresh-Machine Validation

**Goal**: A fresh Pop!_OS machine reaches the full managed environment in under an hour with fewer than 10 manual steps
**Mode:** mvp
**Depends on**: Phase 5
**Requirements**: NIX-17, NIX-18
**Success Criteria** (what must be TRUE):

  1. Following `scripts/setup.sh` and docs on a wiped Pop!_OS, the machine reaches the managed environment in under 1 hour with fewer than 10 manual steps
  2. The two-pass secrets sequence (placeholder secrets → keygen on target → register in .sops.yaml → `sops updatekeys` → redeploy) completes without manual debugging
  3. Bootstrap uses the repo-pinned Home Manager via `nix run home-manager/release-26.05 -- switch --flake .#pop` — no dependency on a locally installed CLI
  4. Post-bootstrap, the freshly provisioned machine's environment matches the previously configured machine (git, tmux, bash, vim flavors)

**Plans**: TBD

### Phase 7: Second-Host & GUI Validation

**Goal**: A NixOS host joins the flake through the same registry and shared home.nix, and critical GUI apps are managed on non-NixOS hosts
**Mode:** mvp
**Depends on**: Phase 6
**Requirements**: NIX-01, NIX-02, NIX-16
**Success Criteria** (what must be TRUE):

  1. A NixOS host is added with only `hosts/<name>/` plus one registry line, reusing the identical `home.nix` (no second copy)
  2. `nix flake check` builds the NixOS system closure and the standalone Home Manager activation package together
  3. User-level configuration on the NixOS host matches the standalone host by construction (same module tree, dual-eval)
  4. A critical GUI app installed via Nix launches on Pop!_OS with a working desktop entry

**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Flake Skeleton & Host Registry | 0/3 | Not started | - |
| 2. Base User Environment | 0/0 | Not started | - |
| 3. Vim Flavors | 0/0 | Not started | - |
| 4. vimspector Debugging | 0/0 | Not started | - |
| 5. Secrets (sops-nix) | 0/0 | Not started | - |
| 6. Bootstrap & Fresh-Machine Validation | 0/0 | Not started | - |
| 7. Second-Host & GUI Validation | 0/0 | Not started | - |
