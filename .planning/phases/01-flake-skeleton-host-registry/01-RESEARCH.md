# Phase 1: Flake Skeleton & Host Registry - Research

**Researched:** 2026-09-24
**Domain:** Nix flake architecture / Home Manager standalone eval / repo foundations
**Confidence:** HIGH (core claims empirically verified this session against real release-26.05 sources)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Registry entry shape
- **D-01:** Host registry lives in `hosts/default.nix` as an attrset keyed by host name; each entry is a **full attrset**: `{ system, kind, username, roles }`. Everything downstream (`homeConfigurations`, `checks`, later `nixosConfigurations`) derives from it via map/genAttrs — flake.nix stays untouched when adding hosts (NIX-04). — **Reversibility:** costly — adding/renaming fields later touches every host entry plus the composer signature.
- **D-02:** First host is named **`razer-blade`** — chosen from hardware (Razer Blade laptop, from DMI/SMBIOS product name), NOT the OS's default hostname `pop-os`. Rationale: the host name identifies the *machine*, and the OS may change over time; distro identity is carried by `kind = "standalone"` separately.
- **D-03:** `kind` field explicitly models `"standalone"` (Home Manager on non-NixOS) vs `"nixos"` — present and filled now (`kind = "standalone"` for razer-blade) even though the NixOS path is not implemented until Phase 7, so no registry redesign is needed later.

#### Skeleton module tree
- **D-04:** Phase 1 implements a **tiny functional baseline**, not an empty placeholder chain. The standalone `homeManagerConfiguration` (via `home-manager.lib.homeManagerConfiguration`, explicit `pkgs = nixpkgs.legacyPackages.${system}`) is wired end-to-end and is real — activation must install something on the live machine.
- **D-05:** The baseline consists of `targets.genericLinux.enable = true` (the mandatory, non-negotiable standalone HM env baseline per stack guidance — XDG_DATA_DIRS etc., "non-negotiable on GNOME/Pop!_OS") plus a `home.packages` marker such as `hello` to prove activation actually installs.
- **D-06:** User-facing module tree shape: `modules/base`, `modules/roles`, shared via `hosts/<name>/home.nix`. But in Phase 1 no real modules are imported — razer-blade's module list is `roles = []` (see D-08). Full-shaped env (sessionVariables, home.file) is deferred to Phase 2.

#### Dual-eval scope (standalone only)
- **D-07:** Phase 1 wires **only the standalone path**. No NixOS module wiring (`home-manager.nixosModules`, `extraSpecialArgs`, `home-manager.users`) and no NixOS host/stub until a real NixOS host exists in Phase 7 — avoids speculative system code now. "Dual-eval" in the phase goal is honored structurally (registry + composer design keeps both paths buildable later), not by placing NixOS binding now.

#### Check surface
- **D-08:** `checks.x86_64-linux` = exactly two gates, matching roadmap success criterion #1: (a) build the home configuration's **activation package** (`config.system.build.activationPackage`) for razer-blade/x86_64-linux, and (b) a **fmt gate** — a cheap check that fails `nix flake check` when any `.nix` file is not formatted (nixfmt `--check`), wired to the `nix fmt` formatter.
- **D-09:** The flake parametrizes over **both systems** (`x86_64-linux` AND `aarch64-linux`) — aarch64 `homeConfigurations` exist and evaluate (NIX-13, criterion #5) — but only x86_64 is **check-built**. No aarch64 eval-check and no both-arch builds; keep the gate fast. No NixOS stub check.

#### Role wiring
- **D-10:** Roles attach to hosts **through the registry entry** (`roles = [ "desktop" ]` style lists) — the registry hosting the full attrset is the single source of truth; role modules live centrally under `modules/roles/<name>`. NOT per-host direct imports inside `hosts/` files.
- **D-11:** A shared **role-composer helper** (small pure-Nix `lib` function, ~10 lines) maps `roles` names → `modules/roles/<name>` module paths and composes the final module list for `homeManagerConfiguration`. Base → Roles ordering is expressed as list order inside this one helper; the same composer will be reused by the NixOS `home-manager` module path in Phase 7 (enables NIX-02 "identical config by construction"). Import resolution fails fast at eval time on a missing role dir.
- **D-12:** Build the composer **now but with `roles = []`** for razer-blade in Phase 1 (precedent set, structure exercised by the checks). No placeholder/example role in Phase 1 — the first real role arrives in Phase 2.

### the agent's Discretion
- Formatter package explicitly pinned as `nixfmt-rfc-style` (already settled in roadmap/project docs) — exact derivation shape for the fmt gate left to planner.
- Marker package choice (`hello` vs alternative smoke-test) is open, though `hello` was the discussed default.
- `hosts/razer-blade/home.nix` vs `default.nix` internal filename split left to planner (must ultimately be imported by the standalone home entry; NixOS side will reuse the same entry in Phase 7).

### Deferred Ideas (OUT OF SCOPE)
- **NixOS binding of shared `home.nix`** (D-07) — wiring `home-manager.nixosModules`, `extraSpecialArgs`, and `home-manager.users` is deliberately deferred to Phase 7 when a real NixOS host exists.
- **Example/placeholder role** to structurally exercise role lookup at check time — deferred; first real role arrives in Phase 2.
- **aarch64 eval-check / both-arch checks** — deferred for speed; revisit if a second machine arch arrives.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| NIX-03 | Layered configuration (Base → Roles → Host) with clear precedence | D-10/D-11/D-12 composer design; module-list-ordered composition verified against real `homeManagerConfiguration` signature (HM lib/default.nix:5-38). Module-system last-wins ordering is the standard NixOS module semantics. |
| NIX-04 | Add hosts by touching only `hosts/<name>/` + one registry line, flake.nix untouched | Registry-driven `homeConfigurations` via `mapAttrs` verified end-to-end in a full phase-shaped probe flake (`nix flake check` green). Note: REQUIREMENTS.md's "one line in flake.nix" is superseded by D-01/AGENTS.md — the line goes in `hosts/default.nix`. |
| NIX-10 | `nix flake check` builds all host closures and Home Manager configs | Verified: `nix flake check` builds `checks.<system>.<name>` derivations and evaluates all flake outputs (probe green run, exit 0). Manual: checks must be derivations `[CITED: nix.dev nix3-flake-check]`. |
| NIX-11 | nixfmt/alejandra formatter wired to `nix flake check` | nixpkgs 26.05: `nixfmt` 1.5.0 (RFC-style; `nixfmt-rfc-style` is a warned alias) + `nixfmt-tree` 2.6.0 (treefmt) — the manual's own formatter example. Both `nix fmt` and a failing fmt gate verified empirically. |
| NIX-12 | Single nixpkgs input (26.05) with Home Manager following | Verified: HM release-26.05 branch (rev a6631107) pins nixos-26.05 internally; probe flake.lock contains exactly **one** nixpkgs node (rev c508844) with HM + sops-nix both `follows`. |
| NIX-13 | x86_64-linux with aarch64-linux possible without redesign | Verified: `formatter`/`checks` parametrized via `forAllSystems` over both systems; `checks.aarch64-linux.fmt` evaluates (`.drvPath` probe). Registry `system` field is data → an aarch64 host needs zero code changes. |
</phase_requirements>
## Project Constraints (from AGENTS.md)

Actionable directives extracted from `/home/timbernwald/prj/nixify/AGENTS.md` (source: PROJECT.md + STACK.md + workflow enforcement). The planner must not recommend approaches that contradict these:

| # | Directive | Source | Phase-1 Relevance |
|---|-----------|--------|-------------------|
| C1 | **Nix flakes only** — pure evaluation, no channels, no `nix-env`, no imperative state | PROJECT.md | The flake skeleton must use plain flake inputs + lock; `nix fmt`/`nix flake check` only. |
| C2 | **Single nixpkgs input** pinned to `nixos-26.05` (STACK.md corrects PROJECT.md's older 25.05 pin — Key Decision NIX-12: 25.05 is EOL 2025-12-31) | PROJECT.md + STACK.md | Phase 1 pins the 26.05 branch; HM + sops-nix `follows` it. |
| C3 | **Home Manager** as NixOS module on NixOS, standalone elsewhere, **sharing `modules/home`** | PROJECT.md | Phase 1 wires only standalone (D-07); `home.nix` entrypoint must be NixOS-reusable by construction. |
| C4 | **Secrets security** — plaintext never in repo or world-readable store; one age key per host | PROJECT.md | Nothing secret exists in Phase 1; home.nix must not introduce credential material (marker = `hello` only). |
| C5 | **Vim constraints** — Vim proper, flavors side-by-side, plugins pinned in Nix, **no runtime fetching** | PROJECT.md | Deferred to Phases 3–4; Phase 1 must not create plugin-download mechanisms. |
| C6 | **No flake-utils / flake-parts** — plain helpers + `genAttrs` (NixOS wiki discourages flake-utils) | STACK.md | Composer uses `nixpkgs.lib.genAttrs`/`mapAttrs`/`filterAttrs`. |
| C7 | Adding a host = `hosts/<name>/` + one line in `hosts/default.nix` — **no flake.nix edits** | STACK.md/AGENTS.md Installation | Matches D-01; registry in `hosts/default.nix`. |
| C8 | Checks are per-system; run `nix flake check` on the machine itself or `--all-systems` | STACK.md | Verified: nix omits aarch64 with a warning unless `--all-systems` (probe). |
| C9 | **GSD workflow** — enter phase work via `/gsd-execute-phase`; do not make direct repo edits outside a GSD workflow | AGENTS.md workflow section | The executor must run plans through the GSD phase harness. |
| C10 | `nixfmt-rfc-style` is the pinned formatter (RFC 166 style); wire to `nix fmt` + a `checks` entry | STACK.md | On 26.05 the attr is `pkgs.nixfmt` 1.5.0 (alias warns); `pkgs.nixfmt-tree` is the blessed wrapper (see Findings). |

Conventions file is empty ("will populate as patterns emerge"); no project skills exist; no `rules/*.md` files — no additional constraints.

## Summary

Phase 1's entire technical surface — flake shape, registry→`homeConfigurations` derivation, the two `checks` gates, the formatter wiring, and the single-nixpkgs lock — was **verified empirically this session** against the real `home-manager` release-26.05 flake (rev `a6631107`) and nixpkgs `nixos-26.05`, using a full phase-shaped probe flake evaluated through actual `nix flake check` and `nix fmt` runs (green run + negative control). The recommended shape below is not a design guess: every code pattern in the Code Examples section is the probe code that already passed `nix flake check` (exit 0) and already caught an unformatted file (exit 1).

**One locked decision requires correction.** D-08 (and STATE.md) name `config.system.build.activationPackage` as the check attribute. That attribute **does not exist** on standalone HM release-26.05 — the `system` namespace is entirely absent from standalone `homeManagerConfiguration` output (verified by evaluating real HM source and by a live eval probe: `{ hasHomeActivation = true; hasSystemNamespace = false; hasTopActivation = true; }`). The verified paths are `homeConfigurations.<name>.config.home.activationPackage` and the top-level `homeConfigurations.<name>.activationPackage` — the latter is exactly what the HM CLI reads when you run `home-manager switch` (home-manager/home-manager:668-671, `doBuildFlake "$FLAKE_CONFIG_URI.activationPackage"`). So the check's *intent* (build the activation package in checks) is preserved; only the attribute path changes. Wire the check to `self.homeConfigurations.razer-blade.config.home.activationPackage`. GSD-BRIEF's open question "`.#<host>` vs `.#<user>@<host>`" is also resolved: the name after `#` is used **verbatim** as the `homeConfigurations` key (CLI source), so `home-manager switch --flake .#razer-blade` works when the registry key is `razer-blade`.

Second correction, same family: the formatter pin "nixfmt-rfc-style" resolves on 26.05 to `pkgs.nixfmt` 1.5.0 (the `nixfmt-rfc-style` attr is a compatibility alias emitting an eval warning: *"nixfmt-rfc-style is now the same as pkgs.nixfmt which should be used instead"*). The RFC-style intent is kept by using `pkgs.nixfmt` (and `pkgs.nixfmt-tree` for the formatter output — the exact shape in the Nix manual's own `nix fmt` example). The fmt gate must run against a **writable copy** of the source: nixfmt 1.5.0 cannot run in a read-only tree (verified failure: `openTempFileWithDefaultPermissions: permission denied` when treefmt's tree-root is a store path).

**Primary recommendation:** Registry in `hosts/default.nix` + per-host dir `hosts/razer-blade/` (`default.nix` = entry attrset, `home.nix` = home module); `lib/composer.nix` builds `homeConfigurations` from the registry (injecting `home.username`/`home.homeDirectory`/`home.stateVersion`, composing Base → Roles → Host module list); `checks.x86_64-linux` = exactly two derivations — `home-razer-blade` (activation package) and `fmt` (treefmt `--ci` on a writable source copy); `formatter.<system> = pkgs.nixfmt-tree` for both systems. Single nixpkgs lock proven (one node, rev `c508844`).

**Runtime state:** Greenfield phase — no runtime systems, stored data, live-service config, OS registrations, secrets/env vars, or build artifacts exist to migrate (verified: the repo contains only `.planning/`, `.opencode/`, and docs; no `.nix` sources exist yet). The Runtime State Inventory section is therefore omitted per the output contract for greenfield phases; nothing external holds the old/new names this phase introduces.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Host registry data (`hosts/default.nix`) | Registry layer (`hosts/`) | — | D-01: single source of truth, keyed by host name; adding hosts touches only this + the host dir (C7). |
| Entry attrset shape (`{ system, kind, username, roles }`) | Registry layer (`hosts/<name>/default.nix`) | — | D-01/D-02/D-03; both eval paths (HM standalone now, NixOS Phase 7) consume it unchanged. |
| Base → Roles → Host composition | Composer layer (`lib/composer.nix`) | Registry layer | D-11: one ~10-line pure-Nix helper owns ordering; reused verbatim by the NixOS path in Phase 7 (NIX-02 by construction). |
| Home configuration eval | Flake outputs (`homeConfigurations`) via composer | HM (release-26.05 lib) | `home-manager.lib.homeManagerConfiguration` is the only sanctioned builder; verified signature `homeManagerConfiguration = { check ? true, extraSpecialArgs ? { }, lib ? pkgs.lib, modules ? [ ], pkgs, minimal ? false }` (HM `lib/default.nix:5-38`). |
| Activation package (identity: username/homeDir/stateVersion) | Composer (module injection) | Host layer | `home.username`/`home.homeDirectory` have **no default** for stateVersion ≥ 20.09 (home-environment.nix:186-231) — they must be set via the composer from the registry entry (no function args exist for them). |
| Check gates (`checks.x86_64-linux`: activation + fmt) | Flake outputs (`checks`) | Composer | D-08: exactly two checks; activation check must reference `config.home.activationPackage` — NOT `config.system.build.*`. |
| Formatter (`nix fmt`) | Flake outputs (`formatter.<system>`) | — | `pkgs.nixfmt-tree` per system; gate mirrors it (same tool/file-matching → zero drift). |
| aarch64 parametrization | Flake outputs (all `forAllSystems`) | Registry (`system` field) | D-09/NIX-13: parametrize outputs over both systems; host `system` field is data (verified `checks.aarch64-linux.fmt` evaluates). |
| Apply / bootstrap command surface | CLI (`home-manager switch --flake .#<name>`) | Flake outputs | The CLI resolves the name verbatim; the flake only needs `homeConfigurations."razer-blade"` (+ top-level `.activationPackage`, read at CLI home-manager:668-671). |
## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| nixpkgs (`nixos-26.05`) | rev `c508844` (2026-09-24) [VERIFIED: flake.lock of probe] | Package set; single pinned input (C2, NIX-12) | Only stable branch receiving security updates (25.05 EOL 2025-12-31). Locked with exactly one node. |
| Home Manager (`release-26.05`) | rev `a6631107`; internally pins nixos-26.05 rev `93108a5` [VERIFIED: `nix flake metadata`] | Standalone `homeManagerConfiguration` + (Phase 7) NixOS module | Release branch pairs with NixOS releases; its own lock pins 26.05, so `release-26.05` + nixpkgs 26.05 is the supported pairing (HM docs name `release-26.05` as a valid branch explicitly). |
| sops-nix | master rev `2bd00bd` (pinned in flake.lock) [VERIFIED: lock] | Input present now (follows) so the lock is shaped once; used Phase 5 | No release branches; flake.lock pins it. Adding it now (even unused) locks the single-nixpkgs topology (criterion #3). |
| `pkgs.nixfmt` | 1.5.0 on 26.05 [VERIFIED: package eval] | RFC 166 formatter (binary `nixfmt`; has `-c/--check`) | The RFC-style formatter; `nixfmt-rfc-style` attr is a warned alias on 26.05 ("now the same as pkgs.nixfmt"). |
| `pkgs.nixfmt-tree` | 2.6.0 (numtide/treefmt) [VERIFIED: package eval + manual example] | `formatter.<system>` + fmt-gate tool; binary `treefmt` | The Nix manual's own `nix fmt` example uses `formatter.<system> = pkgs.nixfmt-tree`; default config `formatter.nixfmt = { command = "nixfmt"; includes = ["*.nix"]; }`. |
| Nix | 2.29.0 (installed) [VERIFIED: `nix --version`] | Flake evaluation | ≥ 2.24 required by nixpkgs 26.05/HM; flakes + nix-command enabled. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `pkgs.hello` | nixpkgs 26.05 | `home.packages` activation marker (D-05) | Phase 1 acceptance proof; verified present in the built HM generation. |
| `nixpkgs.lib.{genAttrs,mapAttrs,filterAttrs,mapAttrs'}` | nixpkgs 26.05 | FLAKE parametrization + composer | All verified working in the probe flake. |
| `nix run home-manager/release-26.05 --` | release-26.05 | Bootstrap/apply CLI without persistent install | Any live-switch acceptance (note: local `home-manager` CLI on this machine is 25.11-pre — must NOT be used, see Pitfall 8). |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `pkgs.nixfmt-tree` as formatter | raw `pkgs.nixfmt` | raw nixfmt prints a deprecation warning when given directories ("use the pkgs.nixfmt-tree wrapper instead"); treefmt handles file discovery + `--ci`. |
| treefmt `--ci` gate (writable copy) | `nixfmt --check` loop over explicit files | Both verified; nixfmt `--check` gives per-file messages and avoids the copy, but the file list must be maintained separately (drift risk vs. the formatter's own matching). treefmt gate shares the formatter's exact file set. |
| `homeConfigurations` keyed by host name | keyed by `user@host` | GSD-BRIEF documents `.#<user>@<host>`; the CLI uses the name verbatim — a `user@host` key also works but renames the registry key (D-01 keys by host). Recommend host keys + `--flake .#razer-blade` (stack guidance form). |
| flake-utils / flake-parts | plain `nixpkgs.lib.genAttrs` | Explicitly discouraged (NixOS wiki) — C6. |

**Installation:**
```bash
# No registry packages — three flake inputs in flake.nix (verified to lock one nixpkgs node):
#   nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
#   home-manager.url = "github:nix-community/home-manager/release-26.05"; (inputs.nixpkgs.follows = "nixpkgs")
#   sops-nix.url = "github:Mic92/sops-nix"; (inputs.nixpkgs.follows = "nixpkgs")
nix flake lock
```

**Version verification:** All versions above were verified live this session via `nix flake metadata`, flake.lock inspection, and package evaluation against the 26.05 source (store path `/nix/store/qxgsnh9zj19dffnj2cnkc5iniy3nj99c-gsyv2ay8fc48l7vp1gspmk5pk65hrn5w-source`).

## Package Legitimacy Audit

No npm/PyPI/crates packages are installed by this phase — the ecosystem registry gate is N/A. The three **flake inputs** are the phase's supply chain; each was resolved live from its canonical GitHub remote and pinned in flake.lock (the strongest form of package-legitimacy verification for Nix: the lock records the exact fetched revision of the verified upstream repo):

| Input | Remote (canonical) | Locked rev | Source Repo | Verdict | Disposition |
|-------|--------------------|-----------|-------------|---------|-------------|
| nixpkgs | `github:NixOS/nixpkgs` branch nixos-26.05 | `c508844…` (2026-09-24) | github.com/NixOS/nixpkgs (canonical) | OK | Approved — pinned |
| home-manager | `github:nix-community/home-manager` branch release-26.05 | `a6631107…` | github.com/nix-community/home-manager (canonical) | OK | Approved — pinned |
| sops-nix | `github:Mic92/sops-nix` (master, no release branches) | `2bd00bd…` | github.com/Mic92/sops-nix (canonical) | OK | Approved — pinned (used Phase 5) |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none
**Unverified / [ASSUMED] inputs:** none — every rev above came from an actual `nix` fetch of the canonical GitHub repo this session.

## Architecture Patterns

### System Architecture Diagram

```mermaid
flowchart TD
  subgraph inputs["flake.lock — exactly ONE nixpkgs node (verified)"]
    NP[nixpkgs nixos-26.05 · rev c508844]
    HM[home-manager release-26.05 · a6631107] -. inputs.nixpkgs.follows .-> NP
    SN[sops-nix · 2bd00bd] -. inputs.nixpkgs.follows .-> NP
  end

  subgraph flake["flake.nix outputs (evaluated by nix flake check)"]
    REG[hosts/default.nix — registry<br/>razer-blade → import ./razer-blade] --> COMP[lib/composer.nix — composeHome]
    COMP --> HC[homeConfigurations.razer-blade]
    HC --> ACT[config.home.activationPackage ✓<br/>NOT config.system.build.* ✗]
    COMP -. Base → Roles → Host .-> ML[modules: base + roles[] + hosts/razer-blade/home.nix]
    COMP --> CHK[checks.x86_64-linux: home-razer-blade + fmt]
    CHK --> FMT[formatter = pkgs.nixfmt-tree for x86_64-linux + aarch64-linux]
  end

  ACT -- "home-manager switch --flake .#razer-blade" --> TARGET[target: targets.genericLinux + hello installed]
  FMT -- "nix fmt / nix flake check gate" --> TARGET
```

Data flow: flake inputs (single nixpkgs) → flake.nix outputs → registry drives the composer → composer produces `homeConfigurations.<name>` (module list Base → Roles → Host) and the checks derive from the same configurations → `home-manager switch --flake .#razer-blade` reads `homeConfigurations."razer-blade".activationPackage` (top level) and activates. Decision point: `kind` field routes a host to the standalone path now (NixOS path Phase 7 — same composer, same module list). External dependency: nixpkgs/HM/sops-nix are the only external inputs, all pinned.

### Recommended Project Structure
```
flake.nix                  # inputs (3, follows) + outputs (homeConfigurations, checks, formatter)
flake.lock                 # single nixpkgs node (verified)
hosts/
├── default.nix            # registry: { razer-blade = import ./razer-blade; }  ← the "one line" (C7)
└── razer-blade/
    ├── default.nix        # entry attrset: { system, kind, username, roles }  (D-01)
    └── home.nix           # host-layer home module (targets.genericLinux + marker) (D-05/D-06)
modules/
├── base/
│   └── default.nix        # Base layer root — empty module in Phase 1 (structure; Phase 2 fills it)
└── roles/                 # role bundles by name, resolved by composer (Phase 2+; empty now)
lib/
└── composer.nix           # composeHome(name, cfg): registry → homeConfigurations (+ shared module list)
```

Rationale: `hosts/<name>/default.nix` holds the registry *entry*, `hosts/<name>/home.nix` the shared home module — the pre-committed AGENTS.md/STACK convention (`default.nix / home.nix / secrets.yaml` per host dir); Phase 7 adds `hardware.nix` + NixOS config in the same dir and reuses `home.nix` unchanged (NIX-02, D-07).
### Pattern 1: Registry-driven homeConfigurations (dual-eval composer)
**What:** `homeConfigurations` derive entirely from the registry via one pure-Nix composer; flake.nix never lists hosts (C7, NIX-04). The composer injects identity (`home.username`, `home.homeDirectory`, `home.stateVersion`) from the registry entry — required because `homeManagerConfiguration` has **no** `username`/`homeDirectory` arguments (verified signature, `lib/default.nix:5-38`) and the options have **no default** for stateVersion ≥ 20.09 (`home-environment.nix:186-231`, defaultText: `"$USER" for state version < 20.09, undefined for state version ≥ 20.09`).
**When to use:** Every host addition; Phase 7 reuses the same module-list helper for the NixOS path.
**Example** (probe code that passed `nix flake check`):
```nix
# lib/composer.nix — shared composition helpers (pure Nix)
{ self, nixpkgs, home-manager, ... }@inputs:
let
  systems = [ "x86_64-linux" "aarch64-linux" ];
  forAllSystems = nixpkgs.lib.genAttrs systems;
  pkgsFor = system: nixpkgs.legacyPackages.${system};
  hosts = import ../hosts/default.nix { inherit inputs; };
  # D-11: the ONE place Base → Roles → Host ordering is expressed
  moduleList = name: cfg:
    [ ../modules/base ]
    ++ map (role: ../modules/roles/${role}) cfg.roles   # missing role dir → eval error (D-11)
    ++ [ ../hosts/${name}/home.nix ];
in {
  inherit systems forAllSystems pkgsFor;
  composeHome = name: cfg: home-manager.lib.homeManagerConfiguration {
    pkgs = pkgsFor cfg.system;
    extraSpecialArgs = { inherit inputs; };              # matches official template
    modules = moduleList name cfg ++ [{
      home.username = cfg.username;                      # VERIFIED: no default ≥ 20.09
      home.homeDirectory = "/home/${cfg.username}";      # VERIFIED: no default ≥ 20.09
      home.stateVersion = "26.05";                       # VERIFIED: in enum, matches branch
    }];
  };
  standaloneHosts = nixpkgs.lib.filterAttrs (name: cfg: cfg.kind == "standalone") hosts;
  homeConfigurations = nixpkgs.lib.mapAttrs composeHome standaloneHosts;
}
```

### Pattern 2: The two-gate check surface (D-08)
**What:** `checks.x86_64-linux` has exactly two derivations — build the home activation package, and the fmt gate. Activation attribute path: **`config.home.activationPackage`** (the `system` namespace does not exist on standalone HM release-26.05 — verified).
**When to use:** The phase's acceptance gate; `nix flake check` builds these and evaluates all outputs (manual: "checks.<system>.<name> must be derivations").
**Example** (probe code, verified green):
```nix
# flake.nix (outputs)
checks = forAllSystems (system: let
  pkgs = pkgsFor system;
  hostChecks = nixpkgs.lib.mapAttrs' (name: cfg:
    nixpkgs.lib.nameValuePair "home-${name}"
      self.homeConfigurations.${name}.config.home.activationPackage)   # NOT config.system.build.*
    (nixpkgs.lib.filterAttrs (name: cfg: cfg.system == system)
      (import ./hosts/default.nix { }));
in hostChecks // {
  fmt = pkgs.runCommand "fmt-check" {
    nativeBuildInputs = [ pkgs.nixfmt-tree ];
  } ''
    cp -r --no-preserve=mode,timestamps ${./.} "$TMPDIR/src"
    chmod -R u+w "$TMPDIR/src"
    treefmt --ci --tree-root "$TMPDIR/src"
    touch $out
  '';
});
```

### Pattern 3: Formatter + fmt gate on nixfmt-tree (NIX-11)
**What:** `formatter.<system> = pkgs.nixfmt-tree` (binary `treefmt`) — the exact shape in the Nix manual's `nix fmt` example — and the gate mirrors it (`treefmt --ci` = `--no-cache --fail-on-change`), so `nix fmt` and the gate always agree on file matching (`*.nix` via the package's default `formatter.nixfmt` config).
**When to use:** Any flake wanting `nix fmt` + a check gate without writing custom formatter plumbing.
**Example** (`nix fmt` manual example — Nix 2.35.2 Reference Manual):
```nix
formatter.x86_64-linux = nixpkgs.legacyPackages.${system}.nixfmt-tree;
```
Verified empirically: `nix fmt` on the probe repo reformatted both `.nix` files in place (exit 0); `treefmt --ci` on a clean tree → exit 0; on a dirty tree → formats then exits 1 with `unexpected changes detected, --fail-on-change is enabled`; treefmt's auto git-walk skips untracked files (nix fmt runs in the live writable repo).

### Anti-Patterns to Avoid
- **`config.system.build.activationPackage` in the check (or anywhere in standalone HM):** attribute `system` does not exist on release-26.05 standalone configs — eval fails with `attribute 'system' missing`. Use `config.home.activationPackage` / top-level `.activationPackage` (the latter is what the HM CLI reads). [VERIFIED — this exact trap is in D-08/STATE.md; corrected above.]
- **`nixfmt-rfc-style` as the package attr on 26.05:** alias that evaluates with a deprecation warning; use `pkgs.nixfmt` (same 1.5.0 package) or `pkgs.nixfmt-tree` for the formatter output.
- **Running the fmt gate (or nixfmt itself) against the store path in a derivation:** read-only tree → nixfmt fails `openTempFileWithDefaultPermissions: permission denied` (needs a writable cwd/temp area). Always copy the source into `$TMPDIR` first (Pattern 2).
- **Passing directories to `nixfmt --check`:** deprecated in 1.5.0 ("Please use the pkgs.nixfmt-tree wrapper instead"); keep the gate file-list-based or use treefmt.
- **Omitting `home.username`/`home.homeDirectory`:** eval fails on assertions (`home-environment.nix:573-581`: "Username could not be determined" / "Home directory could not be determined").
- **Relying on `home.stateVersion`'s default:** its default is `releaseInfo.release` (`version.nix:64`) — it drifts when the HM release branch is bumped; set `"26.05"` explicitly now to freeze semantics.
- **flake-utils / flake-parts (C6):** covered by plain `nixpkgs.lib.genAttrs`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Formatter invocation + format gate | A custom bash loop calling a formatter per file / your own file discovery | `pkgs.nixfmt-tree` (`treefmt`) as `formatter` + `treefmt --ci` gate | Zero drift between `nix fmt` and the gate (same tool, same `*.nix` matching); `--ci` = no-cache + fail-on-change built in; the Nix manual's own example (verified end-to-end). |
| Multi-host flake outputs | Hand-written `homeConfigurations.<name>` blocks per host | Registry + single `composeHome` via `nixpkgs.lib.mapAttrs` | Adding hosts becomes data, not code (NIX-04, criterion #4); one signature change touches one function. |
| Home config identity plumbing | Passing `username`/`homeDirectory` as `homeManagerConfiguration` function args | Module injection (`home.username = ...` in the modules list) | The function has no such args (verified `lib/default.nix:5-38`) — earlier skeleton assumptions in STACK.md/STATE.md assumed `config.system.build.*` and arg-style identity; both corrected by this research. |
| Role import resolution | String→module mapping with runtime checks | Pure path interpolation `../modules/roles/${role}` in the module list | Missing role dir fails **at eval** with a clear path error (D-11 "fails fast"); zero machinery. |
| `nix fmt` alternative formatters | alejandra / nixfmt-classic / nixpkgs-fmt | `nixfmt` (RFC 166; 1.5.0) | The project's settled choice (RFC-style, community standard); classic nixfmt is unmaintained; alejandra deliberately diverges from RFC 166 and is unconfigurable. |

**Key insight:** This phase is an *evaluation-topology* problem, not a code problem. The flake must make the module system do the work (registry → composer → `homeManagerConfiguration`) so that every later phase (2–7) extends data and modules, never flake.nix. Every custom mechanism you add (custom formatter wrappers, per-host code blocks, arg-style identity) is a divergence surface that the verified `homeManagerConfiguration` signature cannot support.

## Common Pitfalls

### Pitfall 1: `config.system.build.activationPackage` does not exist on standalone HM
**What goes wrong:** STATE.md and D-08 prescribe this attr for the check; evaluating it fails (`attribute 'system' missing`).
**Why it happens:** The `system` namespace is a NixOS-module concept; standalone `homeManagerConfiguration` output has no `system` namespace on release-26.05 (verified by eval probe: `hasSystemNamespace = false`).
**How to avoid:** Check `self.homeConfigurations.razer-blade.config.home.activationPackage` (or the top-level `.activationPackage` — identical value; the CLI reads the top-level one at home-manager:668-671).
**Warning signs:** An eval error mentioning `attribute 'system' missing` inside the checks wiring.

### Pitfall 2: Missing `home.username` / `home.homeDirectory` breaks eval
**What goes wrong:** `homeManagerConfiguration` builds a config with empty username/homeDirectory → module-system assertions fire.
**Why it happens:** Both options have no default for stateVersion ≥ 20.09 (only `$USER`/`$HOME` defaults for the pre-20.09 flock; `home-environment.nix:186-231`).
**How to avoid:** Composer injects both from the registry entry (Pattern 1). Never rely on the environment.
**Warning signs:** `error: Failed assertions: - Username could not be determined` / `- Home directory could not be determined` (`home-environment.nix:573-581`).

### Pitfall 3: Formatter/gate cannot run on read-only store trees
**What goes wrong:** The fmt check derivation points treefmt/nixfmt at `${./.}` (a read-only store path); nixfmt aborts with `openTempFileWithDefaultPermissions: permission denied` (or treefmt reports "formatting failures detected").
**Why it happens:** nixfmt 1.5.0 needs a writable temp area (openTempFile in the working directory); treefmt chdirs into the tree-root it was given.
**How to avoid:** `cp -r --no-preserve=mode,timestamps ${./.} "$TMPDIR/src"` + `chmod -R u+w` + `--tree-root "$TMPDIR/src"` inside the runCommand (Pattern 2, verified green + dirty-fail).
**Warning signs:** `permission denied` in `nix-store -l` logs of the fmt-check derivation.

### Pitfall 4: fmt gate catches staged/tracked files only
**What goes wrong:** Newly created, *untracked* `.nix` files are not in the flake source snapshot (`${./.}`) nor in treefmt's git walk — the gate and `nix fmt` both skip them, so an unformatted new file can slip through until committed.
**Why it happens:** Flake source = git-tracked snapshot; treefmt auto-walk = git for repos.
**How to avoid:** Commit (or `git add`) before running `nix flake check`; the phase's verification loop should `git add -A` before the gate (also makes the gate's check set == the repo's committed set).
**Warning signs:** Gate passes while a brand-new `.nix` file exists uncommitted and unformatted.

### Pitfall 5: `--flake .#name` uses the name verbatim
**What goes wrong:** `home-manager switch --flake .#jdoe@my-host` requires a `homeConfigurations."jdoe@my-host"` key; guessing wrong keys silently falls back to auto-detection (`$USER@$(hostname -f/-s)`, `home-manager/home-manager:210-225`) which here finds nothing (hostname is `pop-os`, not `razer-blade`).
**Why it happens:** The CLI sets `FLAKE_CONFIG_URI="$flake#homeConfigurations.\"$name\""` and `FLAKE_ATTR="homeConfigurations.\"$name\""` verbatim (home-manager:231-232).
**How to avoid:** Registry key ≡ the name you type: use `.#razer-blade` (stack guidance form, D-01 keys by host). Document the exact command for the host.
**Warning signs:** "No homeConfiguration found" / switching silently applies nothing.
## Code Examples

Verified patterns from official sources and this session's live probes:

### The phase-shaped flake (probe code — passed `nix flake check` exit 0; also verified vs. Nix 2.35.2 manual)
```nix
# flake.nix
{
  description = "nixify — one flake, all machines";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";   # single nixpkgs node in lock (VERIFIED)
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";         # Phase 5; locks the topology now
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, home-manager, sops-nix, ... }@inputs:
    let
      composer = import ./lib/composer.nix { inherit self nixpkgs home-manager inputs; };
      inherit (composer) systems forAllSystems pkgsFor homeConfigurations;
      hosts = import ./hosts/default.nix { inherit inputs; };
    in {
      inherit homeConfigurations;
      formatter = forAllSystems (system: (pkgsFor system).nixfmt-tree);
      checks = forAllSystems (system: let
        pkgs = pkgsFor system;
        hostChecks = nixpkgs.lib.mapAttrs' (name: cfg:
          nixpkgs.lib.nameValuePair "home-${name}"
            self.homeConfigurations.${name}.config.home.activationPackage)  # NOT system.build.*
          (nixpkgs.lib.filterAttrs (name: cfg: cfg.system == system) hosts);
      in hostChecks // {
        fmt = pkgs.runCommand "fmt-check" { nativeBuildInputs = [ pkgs.nixfmt-tree ]; } ''
          cp -r --no-preserve=mode,timestamps ${./.} "$TMPDIR/src"
          chmod -R u+w "$TMPDIR/src"
          treefmt --ci --tree-root "$TMPDIR/src"
          touch $out
        '';
      });
    };
}
```

### hosts/default.nix — the registry (one line per host; C7)
```nix
# hosts/default.nix
{ inputs, ... }:
{
  razer-blade = import ./razer-blade { inherit inputs; };
}
```

### hosts/razer-blade/default.nix — the entry attrset (D-01/D-02/D-03)
```nix
# hosts/razer-blade/default.nix
{ inputs, ... }: {
  system = "x86_64-linux";   # OS default hostname is pop-os; machine identity is razer-blade (D-02)
  kind = "standalone";       # non-NixOS + standalone Home Manager (D-03)
  username = "tim";          # same Unix username on every machine (GSD-BRIEF)
  roles = [ ];               # D-12: composer built now, no roles until Phase 2
}
```

### hosts/razer-blade/home.nix — the shared home entrypoint (D-05/D-06, NIXOS-reusable in Phase 7)
```nix
# hosts/razer-blade/home.nix   (consumed by the composer as the Host layer)
{ config, lib, pkgs, ... }:
{
  targets.genericLinux.enable = true;   # D-05: mandatory standalone env baseline (XDG_DATA_DIRS, desktop files)
  home.packages = [ pkgs.hello ];       # D-05: marker proving activation installs
}
```

### modules/base/default.nix — Base layer root (structure only in Phase 1, D-06)
```nix
# modules/base/default.nix
{ config, lib, ... }: { }   # first real base module arrives in Phase 2; file must exist (composer imports it)
```
(If an empty module bothers review, an alternatives paragraph: the composer could gate base on a directory existence check — but unconditional import + a real (even empty) `modules/base/default.nix` is simpler and makes the Base → Roles → Host ordering explicit, matching D-11.)

### Verification commands (all ran green or failing-as-intended this session)
```bash
nix flake check                                # builds home-razer-blade activation + fmt gate; evaluates all outputs
nix flake check --all-systems                  # also checks aarch64 (Nix omits it otherwise — verified warning)
nix fmt                                        # idempotent: formats .nix in place (verified: 2 files changed, exit 0)
nix eval .#checks.aarch64-linux.fmt.drvPath    # structural NIX-13 proof: aarch64 parametrization evaluates
nix flake metadata                             # shows pinned revisions of all three inputs
# single-nixpkgs-node assertion (criterion #3):
jq '[.nodes.nixpkgs, (.nodes.home-manager.inputs.nixpkgs // "follows"), (.nodes.sops-nix.inputs.nixpkgs // "follows")] | unique | length' flake.lock
# → 1 (all three resolve to the same nixpkgs node)
```
The negative control (unformatted `broken.nix` committed) made `nix flake check` exit 1 with `Error: unexpected changes detected, --fail-on-change is enabled` — the gate semantics are proven, not assumed.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `nixfmt-rfc-style` as the attr to pin | `pkgs.nixfmt` (RFC-style, 1.5.0); `nixfmt-rfc-style` = warned alias | nixpkgs 26.05 | Use `pkgs.nixfmt`/`pkgs.nixfmt-tree`; the pinned *name* keeps working but warns at eval. |
| `nixfmt` given directories / a file-list gate | `pkgs.nixfmt-tree` (treefmt wrapper, 2.6.0) as `formatter` + `--ci` gate | nixfmt 1.5.0 deprecates directory args | One tool for format + gate; manual's own example; nixpkgs ships it (`pkgs/by-name/ni/nixfmt-tree/package.nix`). |
| Per-system hand-built outputs | Registry + `forAllSystems` parametrization (D-09) | Phase 1 design (verified) | aarch64 eval without redesign (NIX-13). |
| `homeManagerConfiguration` with `username`/`homeDirectory` args (assumed in earlier skeleton docs) | No such args — inject via modules | release-26.05 (verified `lib/default.nix:5-38`) | Registry identity must flow through `home.username`/`home.homeDirectory` modules. |
| `config.system.build.activationPackage` in standalone checks | `config.home.activationPackage` / top-level `.activationPackage` | release-26.05 (verified) | The `system` namespace is absent on standalone; D-08/STATE.md wording corrected. |

**Deprecated/outdated:**
- `nixfmt-rfc-style` attr: deprecated alias → `pkgs.nixfmt`. [VERIFIED: eval warning text]
- `nixfmt` with directory arguments: deprecated → `pkgs.nixfmt-tree`. [VERIFIED: nixfmt 1.5.0 message]
- flake-utils: officially discouraged (NixOS wiki) — C6. [CITED: STACK.md sources]
- Local `home-manager` CLI (25.11-pre on this machine): version-mismatch hazard — always use `nix run home-manager/release-26.05 -- ...`. [VERIFIED: installed version]

## Assumptions Log

> All claims tagged `[ASSUMED]` in this research. The planner and discuss-phase use this section to identify decisions that need user confirmation before execution.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | D-09's "aarch64 homeConfigurations exist and evaluate" is satisfied **structurally** (registry `system` field + `forAllSystems` outputs; a host declaring `system = "aarch64-linux"` needs zero code changes) — no literal aarch64 `homeConfigurations.<name>` output exists in Phase 1 since `homeConfigurations` is keyed by host name, not system. | Architectural Responsibility Map / Patterns | If the user intended literal aarch64 home config outputs, the flake shape grows an extra output dimension (costly) — needs a nod. |
| A2 | Whether Phase 1 includes a **live** `home-manager switch --flake .#razer-blade` acceptance run on this machine (D-04 "activation must install something on the live machine" is satisfiable by the check build alone; an actual switch is non-destructive here — only genericLinux env + hello — but creates real HM generations/profile state on the dev machine). | Summary / Open Questions | Running it without user OK touches the live profile; skipping it leaves activation unproven on the real host. |
| A3 | Marker package = `hello` (discretion area noted `hello` as discussed default; probe proved `hello` lands in the generation). | Code Examples | Trivial to swap; no risk. |
| A4 | Host dir filename split: `default.nix` = entry attrset, `home.nix` = home module (matches STACK.md's `default.nix / home.nix / secrets.yaml` per-host convention). | Recommended Project Structure | Planner's discretion; alternative is a single file. |
| A5 | `modules/base/default.nix` exists in Phase 1 as an empty module (composer imports `../modules/base` unconditionally). | Recommended Project Structure | If omitted, eval fails "path does not exist" — must create the file; structure-only, no behavior. |
| A6 | Using `pkgs.nixfmt` / `pkgs.nixfmt-tree` rather than the literal `nixfmt-rfc-style` attr (alias warning) — RFC-style semantics preserved; the user's pin predates the 26.05 alias change. | Standard Stack / Patterns | Cosmetic at worst (both resolve to the same 1.5.0 package); one eval warning differ. |
| A7 | `home.stateVersion = "26.05"` is the right explicit value (matches the pinned branch; default would drift on HM release bump). | Pattern 1 | Setting the wrong enum value fails eval (enum is closed: "18.09"…"26.05"); "26.05" is the only value matching the branch. |
| A8 | The composer's module list is reusable verbatim by the NixOS HM path in Phase 7 (HM NixOS module accepts the same `modules` list — standard module-system feature). | Don't Hand-Roll / D-11 | Phase 7 integration detail; not exercised now (D-07). |
| A9 | `extraSpecialArgs = { inherit inputs; }` is passed even though Phase 1 modules don't consume it (matches official template; harmless, future-proofs Phase 2). | Pattern 1 | None — verified-legal argument of `homeManagerConfiguration`. |
| A10 | nixpkgs rev `c508844` (2026-09-24) is a valid, current 26.05 revision | Standard Stack | Locked by a real fetch this session; the lock file is the source of truth regardless. |

## Open Questions

1. **Live-switch acceptance in Phase 1?** — What we know: the check builds the real activation package (verified); a live `home-manager switch --flake .#razer-blade` on this machine would install genericLinux env + hello (non-destructive, but changes live HM profile state and generations). What's unclear: whether the user wants the phase to end with an actual applied state or only a building one (bootstrap capstone is Phase 6). Recommendation: make the live switch an optional, explicitly-flagged acceptance step gated on user confirmation (A2).
2. **Exact fmt-gate derivation shape** — What we know: both `treefmt --ci`-on-copy and `nixfmt --check`-file-list variants verified; treefmt variant mirrors the formatter exactly. What's unclear: planner's preference for diagnostics (nixfmt gives per-file messages). Recommendation: treefmt variant (Pattern 2); note the simpler `nixfmt --check` alternative in the plan.
3. **`kind` future-proofing** — What we know: registry carries `kind` now (`"standalone"`); NixOS hosts arrive Phase 7. What's unclear: nothing blocking — the composer's `filterAttrs (n: cfg: cfg.kind == "standalone")` is the seam. Recommendation: keep the filter so checks/homeConfigurations never build NixOS entries prematurely.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Nix (flakes + nix-command) | All evaluation (`nix flake check`, `nix fmt`) | ✓ | 2.29.0 (requires ≥ 2.24 ✓) | — |
| `allow-import-from-derivation` | (not required by Phase 1) | ✓ enabled | — | — |
| Network (github.com) | Fetching/updating the 3 inputs | ✓ | HTTP/2 200 (verified) | Offline: everything already in the local store works; `--offline` for lock-pinned builds |
| Local `home-manager` CLI | (must NOT be used) | ✗ wrong version (25.11-pre) | — | `nix run home-manager/release-26.05 -- switch --flake .#razer-blade` |
| nixfmt / nixfmt-tree on PATH | (not needed on PATH) | ✗ | — | Flake-internal: `nix fmt` uses `formatter`, checks use `nativeBuildInputs` |
| git | Repo state for `nix fmt` walk + flake source snapshot | ✓ | — | — |

**Missing dependencies with no fallback:** none — all phase requirements are satisfiable with the verified inputs and Nix 2.29.0.
**Missing dependencies with fallback:** local `home-manager` CLI (25.11-pre) — must never be used; any switch goes through `nix run home-manager/release-26.05 --`. [VERIFIED: the local CLI version mismatches the pinned HM release — the classic "local CLI drifts from flake" pitfall documented in PITFALLS.md]
## Validation Architecture

`workflow.nyquist_validation = true` — the phase's "test suite" is the flake's own `checks` + formatter (a Nix phase has no separate test framework; the deliverables ARE the gates).

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Nix flake checks: `checks.x86_64-linux.{home-razer-blade, fmt}` + `formatter.x86_64-linux` (nixfmt-tree 2.6.0) |
| Config file | None — gates live in `flake.nix` outputs |
| Quick run command | `nix flake check` (warm cache: seconds; first run: builds HM generation + nixfmt-tree) |
| Full suite command | `nix flake check --all-systems` (adds aarch64 eval/build) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| NIX-03 | Base → Roles → Host composition (roles=[]) | structure (composer ordering) | `nix flake check` (evaluates composer) | ✅ (built in-phase: `lib/composer.nix` + gates) |
| NIX-10 | activation package builds | build | `nix flake check` → check `home-razer-blade` = `config.home.activationPackage` | ✅ in-phase |
| NIX-10 | fmt gate fails on unformatted .nix | negative build | `printf 'let x=1;in x\n' > bad.nix && nix flake check; # expect exit 1` | ✅ in-phase (verified this session) |
| NIX-11 | `nix fmt` idempotent | tool | `nix fmt && git diff --exit-code` (run twice; second run no diff) | ✅ in-phase |
| NIX-12 | single nixpkgs node | static (lock) | `jq '[.nodes.nixpkgs, (.nodes.home-manager.inputs.nixpkgs // "follows"), (.nodes.sops-nix.inputs.nixpkgs // "follows")] \| unique \| length' flake.lock` → `1` | ✅ flake.lock in-phase |
| NIX-13 | aarch64 parametrization evaluates | eval | `nix eval .#checks.aarch64-linux.fmt.drvPath` | ✅ in-phase (verified) |
| NIX-04 | add host = dir + registry line, flake.nix untouched | manual/integration (optional) | temporarily add `hosts/test-x86/` + one registry line, `nix flake check` green, remove | ⚠️ optional acceptance — see Open Question 1/A2 |

### Sampling Rate
- **Per task commit:** `nix flake check` (after `git add -A` — Pitfall 4) + `nix fmt`
- **Per wave merge:** `nix flake check && nix fmt && git diff --exit-code`
- **Phase gate:** `nix flake check` green before `/gsd-verify-work`; optionally the live-switch acceptance (A2) with user confirmation

### Wave 0 Gaps
- [ ] `lib/composer.nix` — the composition helper (Wave 0 of the phase; gates depend on it)
- [ ] `modules/base/default.nix`, `hosts/razer-blade/{default,home}.nix`, `hosts/default.nix` — structure the gates evaluate (A5)
- [ ] The two `checks` + `formatter` outputs in `flake.nix` — the actual test infrastructure
- [ ] flake.lock with the verified 3-input topology (needs `nix flake lock` after first eval)

## Security Domain

`workflow.security_enforcement = true` (no ASVS level configured → treat as level 1). Phase 1 introduces **no secrets, no authentication, no network services** — the applicable controls are about not *creating* leak vectors while the flake substrate is laid down.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — (no auth surface in Phase 1; secrets/keys arrive Phase 5) |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | **yes** | Nix module system types reject malformed registry/config at eval: `home.username` is `types.str`, `home.stateVersion` is a closed `types.enum` (verified `home-environment.nix:186-201`, `version.nix:11-43`), registry `kind` is a plain string compared by the composer — malformed entries fail eval, not at runtime. Flake purity (no IFD, locked inputs) is the input-integrity control. |
| V6 Cryptography | no (Phase 1) | — (age keys, sops-nix: Phase 5, `Mic92/sops-nix` already pinned in the lock) |

### Known Threat Patterns for {stack}
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Secret material accidentally committed in the flake source (world-readable /nix/store) | Information Disclosure | Phase 1 home.nix contains only `targets.genericLinux` + `hello` — no credential material; the phase's verification should grep the repo for key material as part of the gate (cheap `rg` check). Secrets enter only via sops-nix-encrypted files in Phase 5 (encrypted-in-repo constraint C4). |
| Supply-chain drift of the three flake inputs | Tampering | flake.lock pins exact revisions, all resolved from canonical upstream repos this session (verification table above); `nix flake update` is the only mutation path, still pinned to canonical remotes. |
| Eval-time side effects / impurity | Tampering | Flakes-only constraint (C1): pure evaluation, no IFD in Phase 1 outputs (all paths are static module paths); `nix flake check` in the sandbox exercises exactly this. |
| Local CLI version drift applying an old HM | Tampering (config integrity) | Never use the local 25.11-pre `home-manager`; document the `nix run home-manager/release-26.05 --` bootstrap form (Pitfall 8 / Environment). |

No additional ASVS categories apply; the phase ships no user-facing attack surface — the security posture is *foundational hygiene* (purity, pinning, no secrets, no world-readable sensitive state) that later phases build on.

## Sources

### Primary (HIGH confidence — tool-verified this session)
- **Home Manager release-26.05 flake source** (store path `/nix/store/n1sgi5817026lapddn1n9a095falqbhz-source`, rev `a6631107…` fetched from github.com/nix-community/home-manager): `lib/default.nix:5-38` (`homeManagerConfiguration` signature), `modules/home-environment.nix:186-231,573-581` (`home.username`/`home.homeDirectory`/assertions), `modules/misc/version.nix:11-43,64` (`home.stateVersion` enum + default), `home-manager/home-manager:210-232,668-671` (flake name resolution + `activationPackage` build), `templates/standalone/flake.nix` (official template shape), `docs/manual/nix-flakes/standalone.md` (release-26.05 branch named in docs). [VERIFIED: read this session]
- **Live probe flake** `/tmp/opencode/phase-probe/flake.nix` (+ `/tmp/opencode/hm-probe`): full phase-shaped flake; `nix flake check` green (exit 0, built `home-manager-generation`), negative control (unformatted file → exit 1), `nix fmt` (2 files formatted, exit 0), aarch64 eval (`checks.aarch64-linux.fmt.drvPath`), single-nixpkgs lock (criterion #3), read-only-tree nixfmt failure capture. [VERIFIED: this session, exact logs captured]
- **Nix Reference Manual 2.35.2** (`nix.dev/manual/nix/latest`, fetched 2026-09-24): `nix3-flake-check` (checks must be derivations; `--all-systems`, `--no-build`), `nix3-fmt` (formatter invocation; example `formatter.x86_64-linux = nixpkgs.legacyPackages.${system}.nixfmt-tree`). [CITED — manual version is newer than installed Nix 2.29.0; documented semantics stable and empirically confirmed]
- **nixpkgs 26.05 source** (store `/nix/store/qxgsnh9zj19dffnj2cnkc5iniy3nj99c-gsyv2ay8fc48l7vp1gspmk5pk65hrn5w-source`): `pkgs/by-name/ni/nixfmt-tree/package.nix` (treefmt wrapper; default formatter.nixfmt config), `nixfmt` 1.5.0 package (RFC-style; `-c/--check`; directory-arg deprecation message; `nixfmt-rfc-style` alias warning). [VERIFIED: package eval this session]

### Secondary (MEDIUM confidence)
- `.planning/research/STACK.md` — settled stack notes (single 26.05 pin rationale, HM release pairing, flake-utils discouragement, per-host dir convention, `useGlobalPkgs` notes). [CITED: project doc]
- `.planning/research/PITFALLS.md` — local CLI version drift (Pitfall 8), sops `keyFile` string-type hazard (Phase 5 relevance noted). [CITED: project doc]
- AGENTS.md Installation section — registry-in-`hosts/default.nix` one-line pattern; `default.nix / home.nix / secrets.yaml` per host dir. [CITED: project doc]

### Tertiary (LOW confidence)
- None material — all implementation-critical claims were verified at the HIGH tier this session; anything not verified is explicitly flagged `[ASSUMED]` in the Assumptions Log.

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — every version/rev verified against real fetched sources (nix flake metadata, lock file, package eval); no training-data versions used.
- Architecture: **HIGH** — the recommended flake shape is probe code that passed `nix flake check` (green + negative control) this session; corrections to D-08/STATE.md attribute paths are eval-proven.
- Pitfalls: **HIGH** — all pitfalls observed first-hand (failed builds, assertion errors, read-only-tree failure, negative-control gate failure) with exact error text captured.

**Research date:** 2026-09-24
**Valid until:** ~2026-10-24 (fast-moving: HM release branch revs and nixpkgs 26.05 revs move with `nix flake update`; the structural findings — signatures, attribute paths, gate semantics — are stable across the 26.05 line; re-verify before the 26.11 upgrade).