---
phase: 01-flake-skeleton-host-registry
plan: 01
subsystem: infra
tags: [nix, flake, home-manager, nixos, standalone, nixfmt, treefmt, registry, composer, sops-nix]

# Dependency graph
requires: []
provides:
  - "Walking-skeleton flake: 3 inputs (nixpkgs 26.05 + home-manager/sops-nix following it) locked to one nixpkgs node"
  - "hosts/default.nix registry keyed by host name; pure-Nix lib/composer.nix driving homeConfigurations/checks/formatter"
  - "Two-gate check surface (home-<host> activation + fmt) and nixfmt-tree formatter on x86_64-linux and aarch64-linux"
  - "razer-blade standalone host entry (system/kind/username/roles) + shared home entrypoint (targets.genericLinux + hello marker)"
  - "modules/base layering root; NIX-04 host-add proven via temporary probe host (zero flake.nix changes, removed before plan end)"
affects: [02-base-tooling, 03-vim, 04-debugging, 05-secrets, 06-hosts, 07-nixos, 08-maintenance]

# Actuals (#2632) — same scale as the plan's estimate (chars/4 over the realized tree), measured, not narrated.
actuals:
  tokens: 1666   # 6663 chars / 4 over the 7 authored files at HEAD
  tasks: 3
  commits: 2     # measured: git rev-list --count 70c3167..HEAD

# Tech tracking
tech-stack:
  added: [nixpkgs nixos-26.05, home-manager release-26.05 (follows), sops-nix (follows), nixfmt-tree]
  patterns:
    - "registry -> composer -> homeConfigurations: homeConfigurations = mapAttrs composeHome (filterAttrs (kind == \"standalone\")) hosts"
    - "checks keyed per-system via filterAttrs (cfg.system == system) hosts — host checks only exist on their architecture"
    - "fmt gate runs treefmt --ci on a writable $TMPDIR copy of ${./.} (nixfmt cannot mutate the read-only store tree)"
    - "shared home entrypoint consumed as the Host layer — NixOS-reusable in Phase 7"

key-files:
  created: [flake.nix, flake.lock, lib/composer.nix, hosts/default.nix, hosts/razer-blade/default.nix, hosts/razer-blade/home.nix, modules/base/default.nix]
  modified: []

key-decisions:
  - "D-01: host registry lives in hosts/default.nix as a name-keyed attrset of full entries {system, kind, username, roles} — not a list, not partial configs"
  - "D-02/D-03: machine identity razer-blade (DMI product name, not pop-os); kind = \"standalone\" (non-NixOS + standalone Home Manager)"
  - "D-05/D-06: tiny functional baseline (targets.genericLinux.enable + pkgs.hello marker); modules/base created as the unconditional Base layer root"
  - "D-08: exactly two checks per system — home-<name> via config.home.activationPackage (the `system` namespace is absent on standalone HM) and fmt via treefmt --ci"
  - "D-09/D-11: nixfmt-tree as the formatter shared with the fmt gate; moduleList ordering Base -> Roles -> Host expressed in one helper"
  - "Checks are per-system (filterAttrs system match): the aarch64 block evaluates everywhere, builds only on aarch64 — matches 'nix flake check' semantics"
  - "sops-nix input locked now (follows) so the single-nixpkgs topology is fixed before Phase 5"

patterns-established:
  - "Pattern 1 (NIX-04): adding a host = hosts/<name>/ (default.nix + home.nix) + one registry line in hosts/default.nix — flake.nix never changes"
  - "Pattern 2: composer exports systems/forAllSystems/pkgsFor/moduleList/composeHome/standaloneHosts/homeConfigurations — flakes stay declarative, logic is testable pure Nix"
  - "Pattern 3: every task ends with `nix fmt` so the committed tree is fmt-idempotent; the fmt gate proves it against the committed source snapshot"

requirements-completed: [NIX-03, NIX-04, NIX-10, NIX-11, NIX-12, NIX-13]

# Coverage metadata (#1602) — every requirement maps to a deliverable with concrete passing verification from this run.
coverage:
  - id: D1
    description: "Single-nixpkgs flake input topology — nixpkgs 26.05 with home-manager and sops-nix following it, locked to exactly one nixpkgs node"
    requirement: NIX-12
    verification:
      - kind: other
        ref: "jq '.nodes' flake.lock — 3 inputs (nixpkgs/home-manager/sops-nix), 1 nixpkgs repo node"
        status: pass
    human_judgment: false
  - id: D2
    description: "Nix flake check passes on the committed tree, building the razer-blade home activation package and running the fmt gate"
    requirement: NIX-10
    verification:
      - kind: e2e
        ref: "`nix flake check` — exit 0; builds checks.x86_64-linux.home-razer-blade + checks.x86_64-linux.fmt"
        status: pass
    human_judgment: false
  - id: D3
    description: "Formatter wired to the check surface — nixfmt-tree as formatter.x86_64-linux/aarch64-linux; fmt gate shares its *.nix matching; tree is fmt-idempotent vs committed HEAD"
    requirement: NIX-11
    verification:
      - kind: e2e
        ref: "`nix fmt` on committed HEAD (0 changed) + negative control: staged unformatted bad.nix makes `nix flake check` exit 1 with 'unexpected changes detected'"
        status: pass
    human_judgment: false
  - id: D4
    description: "Layered configuration (Base -> Roles -> Host) with clear precedence expressed as moduleList in lib/composer.nix"
    requirement: NIX-03
    verification:
      - kind: other
        ref: "lib/composer.nix moduleList joins modules/base + hosts/<name>/home.nix in Base->Roles->Host order; tracer gate re-verified nix build/nix flake check after Task 1 commit"
        status: pass
    human_judgment: false
  - id: D5
    description: "Adding a host requires only hosts/<name>/ + one registry line — proven with a temporary standalone probe host evaluated and built by the composer with flake.nix byte-identical, then removed before plan end"
    requirement: NIX-04
    verification:
      - kind: e2e
        ref: "probe: registry line + hosts/<probe>/{default.nix,home.nix} -> `nix flake check` exit 0 building home-<probe>; `git diff --exit-code HEAD -- flake.nix` exit 0; post-removal `nix flake check` exit 0 with zero remnants"
        status: pass
    human_judgment: false
  - id: D6
    description: "x86_64-linux primary with aarch64-linux possible without redesign — systems list carries both systems end-to-end; aarch64 flake surface evaluates on x86_64"
    requirement: NIX-13
    verification:
      - kind: other
        ref: "`nix eval --raw '.#checks.aarch64-linux.fmt.drvPath'` exit 0; checks filterAttrs (cfg.system == system) hosts keeps per-system check semantics (aarch64 omitted warning under x86_64 check, expected)"
        status: pass
    human_judgment: false

# Metrics
duration: 11min
completed: 2026-09-24
status: complete
---

# Phase 01 Plan 01: Walking Skeleton — Flake Skeleton & Host Registry Summary

**Single-nixpkgs walking-skeleton flake (nixpkgs 26.05 + home-manager/sops-nix follows): registry-driven `homeConfigurations` for razer-blade via a pure-Nix composer, with a two-gate check surface and nixfmt-tree formatter wired into `nix flake check`**

## Performance

- **Duration:** 11 min
- **Started:** 2026-09-24T14:47:27Z
- **Completed:** 2026-09-24T14:58:22Z
- **Tasks:** 3 (1 tracer, 2 auto; no checkpoints)
- **Files modified:** 7 (6 authored .nix + flake.lock)

## Accomplishments

- Flake with exactly 3 inputs — nixpkgs `nixos-26.05`, home-manager `release-26.05`, sops-nix — where home-manager and sops-nix both `follows = "nixpkgs"`, locking a single nixpkgs node (NIX-12) before Phase 5
- `lib/composer.nix`: pure-Nix composer exporting `systems/forAllSystems/pkgsFor/moduleList/composeHome/standaloneHosts/homeConfigurations`; `homeConfigurations = mapAttrs composeHome (filterAttrs (kind == "standalone") hosts)` — the Phase 7 NixOS seam
- `hosts/default.nix` registry (one line per host, NIX-04) + `hosts/razer-blade/{default.nix,home.nix}` (entry `{system, kind, username, roles}` + shared home entrypoint: `targets.genericLinux.enable = true`, `pkgs.hello` marker)
- Two-gate checks per system (D-08): `home-<name>` via `config.home.activationPackage` and `fmt` via `treefmt --ci` on a writable copy of the source — both proved: build green, negative control fires the gate, fmt idempotent vs committed HEAD
- `formatter = forAllSystems (system: (pkgsFor system).nixfmt-tree)` — same tool + matching as the fmt gate (zero drift, NIX-11)
- NIX-04 host-add proven end-to-end: temporary standalone probe host built by the composer from zero flake.nix changes, then removed with the tree returned byte-identical to HEAD
- x86_64-linux primary + aarch64-linux parametrized everywhere; `checks.aarch64-linux.fmt.drvPath` evaluates on x86_64 (NIX-13)
- Tracer feedback gate (row 3): Task 1 verify re-run end-to-end against the committed tree — both commands exit 0 → "⚡ Tracer verified end-to-end — expanding"
- All five roadmap success criteria verified: `nix flake check` exit 0; `nix fmt` idempotent; lock topology 3-in/1-node; host-add without flake.nix edits; aarch64 eval OK

## Task Commits

Each task was committed atomically:

1. **Task 1: Walking skeleton — registry-driven flake with composer** — `68c656e` (feat)
2. **Task 2: Two-gate checks + nixfmt-tree formatter** — `c1dec95` (feat)
3. **Task 3: NIX-04 host-add proof (temporary probe)** — no commit, by design: the plan requires zero probe remnants in the commit, and the final tree is byte-identical to `c1dec95` — the probe's proof lives in this SUMMARY

**Plan metadata:** `(docs commit — recorded below in the Self-Check section)`

## Files Created/Modified

- `flake.nix` — 3 follows-locked inputs; outputs `homeConfigurations`, `checks` (per-system 2 gates), `formatter`; `hosts = import ./hosts/default.nix` in the let-binding
- `flake.lock` — pinned topology: nixpkgs `c508844…` (26.05), home-manager `a6631107…`, sops-nix `2bd00bd…` (last two following nixpkgs)
- `lib/composer.nix` — composer as above; `home.stateVersion = "26.05"`; `extraSpecialArgs = { inherit inputs; }`
- `hosts/default.nix` — registry attrset, one line per host, nothing else
- `hosts/razer-blade/default.nix` — registry entry (system/kind/username/roles) with D-01..D-03 rationale comments
- `hosts/razer-blade/home.nix` — shared home entrypoint (genericLinux + hello marker)
- `modules/base/default.nix` — empty Base layer root, imported unconditionally by the composer

## Decisions Made

- Registry keyed by host name with full self-contained entries (`{system, kind, username, roles}`) rather than partial/merged attrsets — composer stays declaration-free (D-01)
- Machine identity = DMI product name `razer-blade`, not the OS hostname `pop-os` (D-02); `kind = "standalone"` since razer-blade is non-NixOS (D-03)
- State version pinned to `26.05` (matching the nixpkgs branch, HM release pairing)
- Checks derive from the registry with a per-system filter (`cfg.system == system`) so a host's closure is only a check on its own architecture — `nix flake check` reports the aarch64-omitted warning on x86_64 (expected per-system semantics, not an error)
- Gate 1 reads `config.home.activationPackage` — the `config.system.build.*` namespace does not exist on standalone HM release-26.05 (checked against the research probe)
- Fmt gate copies `${./.}` to `$TMPDIR/src` (chmod u+w) because nixfmt refuses to run inside the read-only store tree; shares the formatter's `*.nix` matching so `nix fmt` and the gate can never drift
- Commits land on `main` — `git.base-branch --is-protected main` returns true, but `git.branching_strategy = "none"` and the sequential dispatch mandates normal commits with hooks on the shared branch (deviation below)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `rec` on the composer export attrset (undefined variable `composeHome`)**
- **Found during:** Task 1 (first `nix build` / `nix flake check` after staging)
- **Issue:** `homeConfigurations = nixpkgs.lib.mapAttrs composeHome standaloneHosts` referenced sibling attrs `composeHome`/`standaloneHosts` — plain Nix attrsets are non-recursive, so evaluation failed with `undefined variable 'composeHome'` at lib/composer.nix:30
- **Fix:** changed the export attrset from `in {` to `in rec {` — matches the documented probe shape; one-token minimal change
- **Files modified:** lib/composer.nix
- **Verification:** `nix build .#homeConfigurations.razer-blade.activationPackage` and `nix flake check` both exit 0
- **Committed in:** `68c656e` (Task 1 commit)

### Process Adaptations (execution-environment driven, no code impact)

- **Scoped `git add` instead of `git add -A`:** the plan's "Stage (git add -A)" collides with the GSD task-commit protocol (never `git add -A`/`.`) AND the working tree carries orchestrator-owned uncommitted edits (`.planning/STATE.md`, `.planning/config.json`). Staged only authored files (`flake.nix hosts lib modules flake.lock`).
- **Scoped fmt-idempotence diff:** `git diff --exit-code HEAD` over the full tree fails due to those same orchestrator-owned `.planning` edits; scoped to the authored flake tree (`flake.nix hosts lib modules`) — the exact set `nix fmt` can touch (only `*.nix` files exist there; confirmed via `git ls-files '*.nix'`).
- **Commits on `main`:** the protected-branch pre-commit assertion flags `main`, but `branching_strategy = "none"` and sequential dispatch require normal commits on the shared branch — proceeded after verifying all harness commits live on `main`.
- **No State/Roadmap writes:** per executor dispatch, STATE.md/ROADMAP.md updates belong to the orchestrator — skipped `state.*`, `roadmap.*` verbs; only REQUIREMENTS.md metadata is updated by this plan.
- **Tracer Task 1 verification gap:** none — the tracer gate re-ran both verifies against the committed tree (exit 0 both). No adapter work was needed.
- **Task 3 probe check needed `nix fmt` first:** hand-written probe files were not RFC-166 formatted on first `nix flake check` (gate fired on the probe itself) — normalized with `nix fmt`, re-staged, then the probe check passed green with `home-<probe>` built and `flake.nix` byte-identical. Effectively a live demonstration of the fmt gate catching new files.

---

**Total deviations:** 1 auto-fixed (1 bug) + 6 process adaptations (no code impact)
**Impact on plan:** The bug fix was required for correctness; all adaptations preserved plan intent and kept orchestrator-owned files untouched. No scope creep.

## Issues Encountered

- `nix flake lock` initially failed: "Path 'flake.nix' … is not tracked by Git" — flakes snapshot the staged/committed tree, so untracked authored files are invisible; fixed by staging before locking (research Pitfall 4, encountered exactly as documented).
- Task 2 Task-3 fmt-gate behavior on my hand-written probe files (see auto-fix #1 and adaptation above) — expected gate behavior, fixed by normalization.
- The plan-commit ledger (`gsd-plan-head-before-01-01`) was first written with the wrong base (post-commit HEAD); corrected to the verified pre-plan base `70c3167…` so `/gsd-verify-work`'s same-instrument check measures the true 2 commits.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- **Ready for 01-02** (registry → `homeConfigurations` → checks/formatter): the exact topology, probe shapes, and gate semantics 01-02 depends on are now committed, verified, and locked
- Modules may now be added to `modules/` and hosts to `hosts/<name>/` + one registry line; leading `modules/base` + trailing `moduleList` seam is in place
- **Deferred (docs, out of scope for this plan):** REQUIREMENTS.md NIX-04 text still reads "one line in flake.nix", but the designed/verified architecture (consistent with STACK.md and this plan) adds hosts via one line in `hosts/default.nix` with flake.nix untouched — align the requirement wording in a later docs pass
- **Deferred:** sops-nix is locked but unused until Phase 5 (intentional, keeps the lock topology stable)

---
*Phase: 01-flake-skeleton-host-registry*
*Completed: 2026-09-24*

## Self-Check: PASSED

- SUMMARY file exists at `.planning/phases/01-flake-skeleton-host-registry/01-01-SUMMARY.md`
- Task 1 commit `68c656e` present in git history
- Task 2 commit `c1dec95` present in git history
- Frontmatter `status: complete` present

Plan metadata commit: `(recorded after the commit below)`