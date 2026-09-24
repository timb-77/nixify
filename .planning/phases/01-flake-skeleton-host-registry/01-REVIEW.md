---
phase: 01-flake-skeleton-host-registry
reviewed: 2026-09-24T18:35:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - flake.nix
  - lib/composer.nix
  - hosts/default.nix
  - hosts/razer-blade/default.nix
  - hosts/razer-blade/home.nix
  - modules/base/default.nix
  - flake.lock
findings:
  critical: 0
  warning: 2
  info: 4
  total: 6
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-09-24T18:35:00Z
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Reviewed the walking-skeleton flake: multi-host registry (`hosts/default.nix`), composition helper (`lib/composer.nix`), standalone razer-blade host, base-module root, and the generated `flake.lock`.

**Empirical verification performed during review (not just static reading):**
- `nix flake check` — **green**, both gates (`home-razer-blade` activation package + `fmt`) build and pass.
- The `fmt` gate genuinely works: build log shows `treefmt` traversing the copied source, emitting exactly the 6 authored `.nix` files, `formatted 6 files (0 changed)`. The `pkgs.nixfmt-tree` package is a treefmt wrapper with a store-baked `treefmt.toml` whose formatter backend is nixfmt 1.5.0 (RFC-style engine) — so my initial suspicion that `treefmt` was missing from `nativeBuildInputs` and that no formatter config existed was **disproven by the build log**; the gate is functional and hermetic.
- `flake.lock` verified clean against the single-nixpkgs goal: exactly one `nixpkgs` node; both `home-manager.inputs.nixpkgs` and `sops-nix.inputs.nixpkgs` are follows refs (`["nixpkgs"]`). No duplicate nodes, no anomalies.
- Security/purity scans clean: no secret-shaped strings in `flake.nix`, `hosts/`, `lib/`, `modules/`; no `builtins.fetchTarball/fetchGit/fetchurl/exec`, no `<nixpkgs>` channel refs, no absolute-path or `~` references, no IFD. `home.homeDirectory` is derived from the registry (`/home/${cfg.username}`), never the environment.

Key concern: the `checks` generator does not filter by host `kind`, which will make `nix flake check` fail across the board at the documented Phase-7 seam (adding a NixOS host). Secondary: the phase's own verification loop prescribes `git add -A` while the repo has no `.gitignore`, and an untracked `/nix/store` symlink (`result`) sits at the repo root ready to be committed.

## Warnings

### WR-01: `checks` host filter ignores `kind` — guaranteed eval breakage at the Phase-7 seam

**File:** `flake.nix:48-52`
**Issue:** The check generator filters hosts with `(name: cfg: cfg.system == system)` only. `lib/composer.nix:47-49` deliberately keeps NixOS-kind hosts out of `homeConfigurations` ("Phase 7 seam: NixOS entries (kind = 'nixos') stay out of homeConfigurations"), so the first NixOS host added in Phase 7 will match the filter but `self.homeConfigurations.${name}` (flake.nix:51) will throw an attribute-missing **eval error for the entire `checks.<system>` attrset** — taking down the `fmt` gate with it and making `nix flake check` red on every machine where that host's system is the current one. The two files encode contradictory assumptions about the same registry.
**Fix:**
```nix
hostChecks = nixpkgs.lib.mapAttrs' (
  name: cfg:
  nixpkgs.lib.nameValuePair "home-${name}"
    self.homeConfigurations.${name}.config.home.activationPackage
) (nixpkgs.lib.filterAttrs (name: cfg: cfg.system == system && cfg.kind == "standalone") hosts);
```

### WR-02: No `.gitignore`; untracked `result` symlink into /nix/store invites `git add -A` contamination

**File:** repo root `/home/timbernwald/prj/nixify/` (affects `flake.nix` flake-source membership)
**Issue:** The repo has no `.gitignore`. `git status` shows an untracked `result` symlink pointing at `/nix/store/1wnq9...-home-manager-generation` (left by a previous `nix build`), plus `.gsd/`, `.opencode/`, `.planning/state.json`, `.planning/milestone.lock`. The phase's own sampling loop (01-VALIDATION.md §Sampling Rate: "Run `nix flake check` (after `git add -A` ...)") makes committing these artifacts likely. If `result` is committed it becomes part of the flake source: a machine-specific /nix/store path embedded in the repo, dangling the moment that store path is GC'd, and copied into every `fmt` gate build. Untracked files are currently excluded from the flake source, so no active bug — but the prescribed workflow is a foot-gun.
**Fix:**
```gitignore
# .gitignore
result
result-*
.planning/state.json
.planning/milestone.lock
.gsd/
```
(Do not blanket-ignore `.opencode/` — it contains the project's skills and is referenced by AGENTS.md; commit it deliberately.)

## Info

### IN-01: Dead binding `self` in composer.nix

**File:** `lib/composer.nix:6` (passed from `flake.nix:24-25`)
**Issue:** `self` is bound in the pattern and explicitly passed by the flake, but never referenced in the body. Also `inputs` is bound but unused in `hosts/razer-blade/default.nix:3`.
**Fix:** Drop `self` from the composer function pattern and from the `inherit` list in flake.nix; drop the unused `inputs` binding in the registry entry.

### IN-02: Formatter attr/name drifts from documented decision NIX-11

**File:** `flake.nix:41`
**Issue:** STACK.md/AGENTS.md (NIX-11) document `nixfmt-rfc-style` as the formatter ("pin nixfmt-rfc-style explicitly for clarity") and the What-Not-To-Use table lists `nixfmt-classic`. The flake instead uses `pkgs.nixfmt-tree` — verified to be a treefmt wrapper (binary named `treefmt`) that invokes nixfmt 1.5.0 (RFC-style engine) via a baked config. The formatting *engine* matches the decision, but the docs, the `formatter` attr, and the actual binary name now disagree, and `nix fmt` behavior is coupled to the internal defaults of that package across nixpkgs bumps.
**Fix:** Either update STACK.md to record the `nixfmt-tree` decision, or switch the flake to `pkgs.nixfmt-rfc-style` with an explicit `treefmt.toml` so the gate config is visible in-repo.

### IN-03: Host registry imported in two places

**File:** `flake.nix:37` and `lib/composer.nix:18`
**Issue:** Both files independently `import ../hosts/default.nix { inherit inputs; }`. Harmless today (pure evaluation yields the same value), but the registry's call interface is now coupled at two sites; a future signature change (e.g. extra args for roles) must be applied twice.
**Fix:** Import once in flake.nix and pass the result into composer (or into `extraSpecialArgs`), leaving `hosts/default.nix` importable from exactly one module.

### IN-04: sops-nix input is dead weight in Phase 1

**File:** `flake.nix:9-12`
**Issue:** `sops-nix` is declared, follows nixpkgs (correctly — verified in flake.lock), and is threaded through `inputs` everywhere, but nothing imports or consumes it until Phase 5. Every `nix flake update` will churn the sops-nix lock entry (it tracks `master`) while providing zero value this phase. The lock topology it pins is correct, so this is intentional but worth flagging: consider deferring the input to Phase 5 unless the topology lock is a hard requirement.
**Fix:** Keep as-is if the topology-lock rationale stands; otherwise remove until Phase 5.

---

_Reviewed: 2026-09-24T18:35:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_