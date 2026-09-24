---
phase: "01"
slug: "flake-skeleton-host-registry"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-09-24"
---

# Phase 01 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Nix flake checks: `checks.x86_64-linux.{home-razer-blade, fmt}` + `formatter.x86_64-linux` (nixfmt-tree 2.6.0) |
| **Config file** | None — gates live in `flake.nix` outputs |
| **Quick run command** | `nix flake check` |
| **Full suite command** | `nix flake check --all-systems` (adds aarch64 eval/build) |
| **Estimated runtime** | ~seconds warm cache; first run builds HM generation + nixfmt-tree |

---

## Sampling Rate

- **After every task commit:** Run `nix flake check` (after `git add -A` — RESEARCH Pitfall 4) + `nix fmt`
- **After every plan wave:** Run `nix flake check && nix fmt && git diff --exit-code`
- **Before `/gsd-verify-work`:** Full suite `nix flake check --all-systems` must be green
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| T1 (tracer) | 01-01 | 1 | NIX-03, NIX-10, NIX-12 | T-1 / T-2 / T-3 | composer orders Base→Roles→Host; identity flows from registry (never hardcoded `/home`); flake purity (no IFD) | build + structure | `nix build .#homeConfigurations.razer-blade.activationPackage` then `nix flake check` | ✅ in-phase (W0) | ⬜ pending |
| T2 | 01-01 | 1 | NIX-10, NIX-11, NIX-13 | T-2 / T-3 | fmt gate fails on unformatted `.nix`; formatter is store-safe (`$TMPDIR` copy) | negative build + tool | `printf 'let x = 1; in x\n' > bad.nix && git add bad.nix && nix flake check; # expect exit 1` + `nix eval .#checks.aarch64-linux.fmt.drvPath` | ✅ in-phase (W0) | ⬜ pending |
| T3 | 01-01 | 1 | NIX-04, NIX-12, NIX-13 | T-2 / T-3 | host-add probe touches only `hosts/<name>/` + registry line; flake.nix untouched; no credential-shaped strings in authored files | static (lock) + integration + hygiene | `jq '[.nodes.nixpkgs, (.nodes.home-manager.inputs.nixpkgs // "follows"), (.nodes.sops-nix.inputs.nixpkgs // "follows")] | unique | length' flake.lock` → `1`; temp `hosts/test-x86/` + `nix flake check`; `rg -n -i 'secret|password|private|token|keyFile' flake.nix hosts lib modules; test $? -eq 1` | ✅ in-phase (W0) | ⬜ pending |
| T1 (decision) | 01-02 | 2 | NIX-10 | — | live switch never runs without user confirmation (touches live profile state) | manual/integration (optional, A2) | `grep -q '^option-a$' 01-02-SUMMARY.md || grep -q '^option-b$' 01-02-SUMMARY.md` | N/A — records the decision | ⬜ pending |
| T1 (switch) | 01-03 | 3 | NIX-04, NIX-10 | T-2 | switch goes through pinned `nix run home-manager/release-26.05 --` (never the local 25.11-pre CLI); must be pure state change | integration (optional, gated by 01-02) | `nix run home-manager/release-26.05 -- switch --flake .#razer-blade` + `test -x "$HOME/.local/state/nix/profiles/home-manager/bin/hello"` | ✅ in-phase | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `lib/composer.nix` — the composition helper (Wave 0 of the phase; gates depend on it)
- [ ] `modules/base/default.nix`, `hosts/razer-blade/{default.nix,home.nix}`, `hosts/default.nix` — structure the gates evaluate
- [ ] The two `checks` + `formatter` outputs in `flake.nix` — the actual test infrastructure
- [ ] flake.lock with the verified 3-input topology (needs `nix flake lock` after first eval)

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Add-host ergonomics (`hosts/<name>/` + one registry line; flake.nix untouched) | NIX-04 | Opt-in acceptance touching the live dev machine (A2); the composer/eval proof is automated, the live switch is user-confirmed | Create `hosts/test-x86/` + one registry line, `nix flake check` green, remove; optionally run `nix run home-manager/release-26.05 -- switch --flake .#razer-blade` after explicit approval |

*If none: "All phase behaviors have automated verification."*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending