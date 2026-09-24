---
phase: 01-flake-skeleton-host-registry
verified: 2026-09-24T16:37:22Z
status: passed
score: 7/7 must-haves verified
covered_files:
  - ".planning/REQUIREMENTS.md"
  - ".planning/phases/01-flake-skeleton-host-registry/01-01-PLAN.md"
  - ".planning/phases/01-flake-skeleton-host-registry/01-01-SUMMARY.md"
  - ".planning/phases/01-flake-skeleton-host-registry/01-02-PLAN.md"
  - ".planning/phases/01-flake-skeleton-host-registry/01-02-SUMMARY.md"
  - ".planning/phases/01-flake-skeleton-host-registry/01-03-PLAN.md"
  - "flake.lock"
  - "flake.nix"
  - "hosts/default.nix"
  - "hosts/razer-blade/default.nix"
  - "hosts/razer-blade/home.nix"
  - "lib/composer.nix"
  - "modules/base/default.nix"
covered_digest: "v1:sha256:be016527a1ab0f44cea067e60d4966850ecc4f82ec08d1885d5b9e3634afadd6"
behavior_unverified: 0
overrides_applied: 0
---

# Phase 01: Flake Skeleton & Host Registry Verification Report

**Phase Goal:** A minimal but complete flake skeleton hosts the first Pop!_OS configuration behind dual-eval builders, gated by checks and a formatter
**Verified:** 2026-09-24T16:37:22Z
**Status:** passed
**Re-verification:** No — initial verification

**Methodology note (MVP mode):** ROADMAP.md marks Phase 1 `mode: mvp`, but the phase goal is a technical goal, not a User Story (`user-story.validate` → `false`). Per the developer's direct instruction, this verification was run as standard goal-backward verification against the ROADMAP Success Criteria. No User Flow Coverage table is emitted; the criteria themselves are the outcome contract and each was verified behaviorally.

## Goal Achievement

### Observable Truths

All truths from 01-01-PLAN.md and 01-02-PLAN.md must_haves plus the 5 ROADMAP Success Criteria were re-verified **by direct command execution in this session** — SUMMARY.md claims were treated as unproven until reproduced.

| #   | Truth                                                                                                         | Status     | Evidence |
| --- | ------------------------------------------------------------------------------------------------------------- | ---------- | -------- |
| 1   | `nix flake check` exits 0 on the committed tree, building the razer-blade home activation package and running the fmt gate | ✓ VERIFIED | Ran `nix flake check`: exit 0; built `checks.x86_64-linux.home-razer-blade` (`home-manager-generation.drv`) and `checks.x86_64-linux.fmt` (`fmt-check.drv`); both derivations executed |
| 2   | fmt gate fails on unformatted .nix files (ROADMAP SC #1 clause)                                                | ✓ VERIFIED | Negative control: staged unformatted `bad.nix` → `nix flake check` exit 1 with `Error: unexpected changes detected, --fail-on-change is enabled`; file fully reverted after |
| 3   | `nix fmt` makes no changes to an already-formatted tree (idempotent)                                            | ✓ VERIFIED | Ran `nix fmt`: exit 0, `formatted 0 files (0 changed)`; `git diff --name-only HEAD -- '*.nix'` (outside `.planning/`) empty |
| 4   | flake.lock contains exactly one nixpkgs node (26.05) with home-manager and sops-nix following it                | ✓ VERIFIED | `jq '[.nodes[] \| select(.original.repo == "nixpkgs")] \| length'` → `1`; `nixpkgs.original.ref` = `nixos-26.05`; `.nodes["home-manager"].inputs.nixpkgs` = `["nixpkgs"]`, `.nodes["sops-nix"].inputs.nixpkgs` = `["nixpkgs"]` (lockfile-v7 `follows` encoding); 4 nodes total: root, nixpkgs, home-manager, sops-nix |
| 5   | Adding a temporary standalone host via hosts/<name>/ + one registry line passes nix flake check with flake.nix untouched | ✓ VERIFIED | Live probe (this session): created `hosts/test-x86/{default.nix,home.nix}` + one registry line → `nix flake check` evaluated `checks.x86_64-linux.home-test-x86`; `git diff --exit-code HEAD -- flake.nix` exit 0 (byte-identical); zero remnants after removal (`git ls-files` has no test-x86, `hosts/default.nix` identical to HEAD) |
| 6   | Module imports follow Base → Roles → Host ordering (composer moduleList)                                        | ✓ VERIFIED | `lib/composer.nix:21-25`: `moduleList = [ ../modules/base ] ++ map (role: ../modules/roles/${role}) cfg.roles ++ [ ../hosts/${name}/home.nix ]` — Host last. Behavioral merge check: `config.home.packages` contains `hello-2.12.3.drv` and `targets.genericLinux.enable` = true — Host-layer content provably flows through moduleList into the composed config. Conflict-level override semantics rest on documented Nix module system behavior (later modules win); no conflict exists in Phase 1 because `modules/base` is intentionally empty (D-06) — see Honest-Verifier Notes |
| 7   | `nix eval .#checks.aarch64-linux.fmt.drvPath` succeeds (aarch64 parametrization evaluates)                      | ✓ VERIFIED | Exit 0 → `/nix/store/zzh0a2fbkyd5ll83pyg67f6473m9xr5b-fmt-check.drv`; `nix flake show` lists `checks.aarch64-linux.fmt` and `formatter.aarch64-linux` as outputs |
| 8   | The user decides, with full context, whether razer-blade gets a live HM switch now or only in Phase 6 (01-02)   | ✓ VERIFIED | `01-02-SUMMARY.md` line 43 is exactly `option-b` (blocking-human checkpoint decision recorded verbatim) |
| 9   | Plan 01-03's precondition (which option won) is recorded in the decision outcome (01-02)                        | ✓ VERIFIED | `^option-b$` line present → 01-03's precondition asserts `option-a` → plan halts. No `01-03-SUMMARY.md` exists — consistent with the by-design skip |

**Score:** 7/7 applicable truths verified (rows 1–7 from 01-01 + SC battery, rows 8–9 from 01-02; 0 present-but-behavior-unverified)

**01-03 (live switch) — skipped by design, not a gap.** The recorded `option-b` decision defers the optional live `home-manager switch` to Phase 6's bootstrap capstone. 01-03's three must-have truths (pinned-CLI switch succeeds, hello marker executable in live profile, pinned CLI used) are **N/A — precondition halt by explicit user decision**. The phase goal does not include the live apply: ROADMAP SC #1's pass criterion is `nix flake check` (D-08), and the activation package was built and its derivation executed by that check. Zero machine state was mutated in Phase 1, exactly as option-b intends.

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `flake.nix` | 3 follows-locked inputs + `homeConfigurations`/`checks`/`formatter` outputs | ✓ VERIFIED | 67 lines; contains `nixos-26.05`, both `follows = "nixpkgs"`; outputs wire composer exports; contains zero host names |
| `flake.lock` | Pinned 3-input topology, single nixpkgs node | ✓ VERIFIED | 4 nodes (root + 3); nixpkgs pinned `nixos-26.05` rev `c508844…` |
| `lib/composer.nix` | composeHome + moduleList + exports | ✓ VERIFIED | 50 lines; exports `systems/forAllSystems/pkgsFor/moduleList/composeHome/standaloneHosts/homeConfigurations`; `rec` attrset; `stateVersion = "26.05"` |
| `hosts/default.nix` | Registry attrset, one line per host | ✓ VERIFIED | Contains `razer-blade` line only |
| `hosts/razer-blade/default.nix` | Registry entry {system, kind, username, roles} | ✓ VERIFIED | `system = "x86_64-linux"`, `kind = "standalone"`, `username = "timbernwald"`, `roles = [ ]` |
| `hosts/razer-blade/home.nix` | Host-layer home module | ✓ VERIFIED | `targets.genericLinux.enable = true`; `home.packages = [ pkgs.hello ]` — content flows into config (Level 4 below) |
| `modules/base/default.nix` | Base layer root (empty by design) | ✓ VERIFIED | Intentionally empty module `{ config, lib, ... }: { }` — required to exist because the composer imports it unconditionally; NOT a stub (documented D-06/A5 design, Phase 2 fills it) |
| `.planning/.../01-02-SUMMARY.md` | Recorded decision outcome | ✓ VERIFIED | Contains verbatim `option-b` line |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `flake.nix` | `lib/composer.nix` | `import ./lib/composer.nix { inherit self nixpkgs home-manager inputs; }` | ✓ WIRED | flake.nix:23-30 |
| `lib/composer.nix` | `hosts/default.nix` | `import ../hosts/default.nix` — registry drives homeConfigurations via mapAttrs | ✓ WIRED | composer.nix:18, 48-49 |
| `lib/composer.nix` | modules/base + hosts/<name>/home.nix | `moduleList` — Base → Roles → Host in one helper | ✓ WIRED | composer.nix:21-25; merge proven by config spot-checks |
| `checks.<sys>.home-<name>` | `homeConfigurations.<name>` | `config.home.activationPackage` | ✓ WIRED | flake.nix:51; check built as `home-manager-generation.drv` |
| `formatter` | `checks.<sys>.fmt` | same `nixfmt-tree` tool + `*.nix` matching | ✓ WIRED | flake.nix:41 (`nixfmt-tree`) and 58 (`nativeBuildInputs = [ pkgs.nixfmt-tree ]` + `treefmt --ci`) |
| 01-02 decision outcome | 01-03 precondition | verbatim `option-b` line in 01-02-SUMMARY.md | ✓ WIRED | Option-b → 01-03's `option-a` precondition halts — the designed skip |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| `hosts/razer-blade/default.nix` | username/homeDirectory/stateVersion | registry entry → composer identity injection | `nix eval config.home.username` → `timbernwald`; `homeDirectory` → `/home/timbernwald`; `stateVersion` → `26.05` | ✓ FLOWING |
| `hosts/razer-blade/home.nix` | home.packages / genericLinux | Host layer via moduleList merge | `config.home.packages` includes `hello-2.12.3.drv`; `config.targets.genericLinux.enable` → `true` | ✓ FLOWING |
| `checks.<sys>.home-razer-blade` | activationPackage | `config.home.activationPackage` from composed HM config | derivation `home-manager-generation.drv` built by `nix flake check` | ✓ FLOWING |

No static returns, hardcoded literals, or hollow props anywhere in the authored tree.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| nix flake check passes, builds both gates | `nix flake check` | exit 0; `home-manager-generation.drv` + `fmt-check.drv` built; `formatter.x86_64-linux` = `nixfmt-tree-2.6.0.drv` | ✓ PASS |
| fmt gate fails on unformatted .nix | stage `bad.nix` + `nix flake check` | exit 1; `Error: unexpected changes detected, --fail-on-change is enabled` | ✓ PASS |
| nix fmt idempotent | `nix fmt` + `.nix` diff vs HEAD | exit 0; `formatted 0 files (0 changed)`; no diffs | ✓ PASS |
| Single-nixpkgs lock topology | `jq` assertions on flake.lock | 1 nixpkgs node, ref `nixos-26.05`, both follows encoded `["nixpkgs"]` | ✓ PASS |
| Host-add without flake.nix changes | registry-line probe + `nix flake check` | `home-test-x86` check evaluated; `git diff --exit-code HEAD -- flake.nix` = 0 | ✓ PASS |
| aarch64 parametrization evaluates | `nix eval .#checks.aarch64-linux.fmt.drvPath` | exit 0 → store path | ✓ PASS |
| Registry → composer → config flow | `nix eval` username/stateVersion/homeDirectory/packages/genericLinux | all match authored values incl. hello | ✓ PASS |

Note: the two mutation-bearing checks (negative control, host-add probe) were transient — files were created, staged, checked, then fully removed; post-check `git status` is byte-identical to the pre-check state (only orchestrator-owned `.planning/` edits remain, as noted in 01-01-SUMMARY process adaptations).

### Probe Execution

| Probe | Command | Result | Status |
| ----- | ------- | ------ | ------ |
| (none declared) | `find scripts -path '*/tests/probe-*.sh'` | no files found | SKIPPED — no probe scripts exist in the repo and no PLAN declares one; the RESEARCH "probes" were session-scoped evaluation experiments, not repo scripts |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| NIX-03 | 01-01 | Layered configuration (Base → Roles → Host) with clear precedence | ✓ SATISFIED | `moduleList` ordering in composer.nix (single point, D-11); Host content merged into config (spot-checks) |
| NIX-04 | 01-01 | Adding hosts by touching only hosts/<name>/ and one registry line | ✓ SATISFIED | Live probe: home-test-x86 evaluated, flake.nix byte-identical; flake.nix/composer contain zero host names |
| NIX-10 | 01-01, 01-02, 01-03 | Pass nix flake check building all host closures and HM configs | ✓ SATISFIED | `nix flake check` exit 0 building `home-razer-blade` activation + fmt gate; live-apply aspect deferred to Phase 6 per recorded user decision (option-b) |
| NIX-11 | 01-01 | Formatter wired to nix flake check | ✓ SATISFIED | `formatter` = nixfmt-tree per system; fmt gate shares the tool and `.nix` matching; negative control fired |
| NIX-12 | 01-01 | Single nixpkgs input (26.05 stable) with HM following | ✓ SATISFIED | flake.lock: 1 nixpkgs node (`nixos-26.05`), home-manager + sops-nix both follow |
| NIX-13 | 01-01 | x86_64-linux with aarch64-linux possible without redesign | ✓ SATISFIED | `systems = [x86_64-linux aarch64-linux]`; aarch64 fmt check + formatter evaluate (`drvPath` eval OK) |

All six phase requirement IDs appear in PLAN frontmatter and map to Phase 1 `Complete` in REQUIREMENTS.md traceability. **No orphaned requirements** — the traceability table lists exactly these six for Phase 1.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| (none) | — | no debt markers (TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER), no credential-shaped content, no stubs | — | — |

Repo hygiene: `grep -r -i 'secret\|password\|private\|token\|keyFile' flake.nix hosts lib modules` → no matches.

### Human Verification Required

None. Every truth was verified by direct command execution in this session — no behavior-dependent truth was left unexercised, and no visual/real-time/external-service surface exists in this phase. The only human decision of the phase (live-switch timing, assumption A2) was already made at the 01-02 blocking-human checkpoint and is recorded verbatim (`option-b`).

### Gaps Summary

No gaps. All five ROADMAP Success Criteria hold on the committed tree, verified behaviorally:

1. `nix flake check` exit 0 building the activation package + fmt gate; gate demonstrated failing on an unformatted file (exit 1, `unexpected changes detected`).
2. `nix fmt` idempotent on the committed tree (0 files changed, no diff vs HEAD) via nixfmt-tree, whose `.nix` formatter is the RFC-style nixfmt (the literal `nixfmt-rfc-style` attr is a warned alias on 26.05 — D-09 rationale; roadmap's parenthetical intent satisfied).
3. flake.lock holds exactly one nixpkgs node (`nixos-26.05`) with home-manager and sops-nix following (lockfile-v7 `follows` arrays).
4. Host-add proven live: `hosts/<name>/` + one registry line evaluated through the composer with flake.nix byte-identical; zero probe remnants.
5. Base → Roles → Host ordering lives in one place (`moduleList`); aarch64-linux evaluates end-to-end without redesign.

### Honest-Verifier Notes (informational, non-blocking)

- **Precedence semantics (truth #6):** the merged-config spot checks behaviorally prove moduleList composition (Host content lands in the config). The conflict-level "host overrides base" semantics rest on the documented Nix module system guarantee (later modules win); Phase 1's base is intentionally empty (D-06), so no conflicting-definition case exists to exercise yet. The mechanism that will govern future precedence is correct by construction and pinned to a single helper — the natural place for a Phase 2+ assertion if desired.
- **NIX-04 wording debt (docs, pre-flagged):** REQUIREMENTS.md still reads NIX-04 as "one line in flake.nix", while the designed-and-verified architecture adds hosts via one line in `hosts/default.nix` with flake.nix untouched — which is what ROADMAP SC #4 (the phase contract) requires. 01-01-SUMMARY already flags this for a later docs pass. Not a gap for this phase.
- **Orchestrator-owned working-tree edits:** `.planning/STATE.md`, `.planning/config.json` (modified) and `.gsd/`, `.opencode/`, `.planning/milestone.lock`, `.planning/state.json` (untracked) predate this verification, are outside the phase's authored set, and are excluded from fmt/diff assertions exactly as documented in 01-01-SUMMARY process adaptations.
- **Original plan jq assertion inapplicable verbatim:** the plan's jq expression was written for lockfile-v6 (string follows); flake.lock here is v7 (array follows). Semantics verified equivalent via corrected assertions (see truth #4).

---

_Verified: 2026-09-24T16:37:22Z_
_Verifier: the agent (gsd-verifier)_
