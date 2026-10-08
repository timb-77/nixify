---
phase: "2"
slug: "base-user-environment"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-08"
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Nix flake `checks` + `nix eval` content assertions (no Jest/pytest — declarative config repo) |
| **Config file** | `flake.nix` (`checks.${system}."home-razer-blade"` + `fmt`) — unchanged from Phase 1 |
| **Quick run command** | `git add <new modules> && nix flake check` |
| **Full suite command** | `nix flake check --all-systems` and `nix build .#homeConfigurations.razer-blade.activationPackage` |
| **Estimated runtime** | ~60–180 seconds (eval + build of the activation package) |

---

## Sampling Rate

- **After every task commit:** Run `git add <new modules> && nix flake check` + `nix fmt`
- **After every plan wave:** Run `nix flake check --all-systems`
- **Before `/gsd-verify-work`:** Full flake check green + activation package builds; D-14 manual UAT on razer-blade
- **Max feedback latency:** ~180 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | NIX-05 | T-02-01 | git settings rendered; no plaintext credential committed | eval+build | `nix eval --json .#homeConfigurations.razer-blade.config.programs.git.settings` | ✅ | ⬜ pending |
| 02-01-02 | 01 | 1 | NIX-05 | T-02-02 | tmux vi mode in generated conf; no runtime plugins | eval | `nix eval --raw '.#homeConfigurations.razer-blade.config.xdg.configFile."tmux/tmux.conf".text'` (grep `mode-keys vi`) | ✅ | ⬜ pending |
| 02-01-03 | 01 | 1 | NIX-15 | T-02-03 | bash rc/profile managed by HM; session vars package present | eval+build | `nix eval --json .#homeConfigurations.razer-blade.config.programs.bash.enable` | ✅ | ⬜ pending |
| 02-01-04 | 01 | 1 | NIX-07 | T-02-04 | plain `pkgs.vim`; **zero** plugins (no runtime fetch) | eval | `nix eval --json .#homeConfigurations.razer-blade.config.programs.vim.plugins` → `[]`; `…programs.vim.packageConfigurable.name` → `"vim"` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] None strictly required — Phase 1 already provides `checks."home-razer-blade"` (activation package) and the `fmt` check. New modules are exercised automatically once imported.
- [ ] Ensure every new `modules/base/*.nix` file is `git add`-ed before `nix flake check` (flakes snapshot the staged tree).

*Existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Nix-provided binaries after activation | D-14 | Requires a live `home-manager switch` on the host (deferred to Phase 6 by design) | After switch: `git --version; tmux -V; bash --version; vim --version` all report Nix store paths; `vim` loads core settings |
| Stale dotfiles do not shadow managed config | A4/A5 | Host-state dependent (`~/.gitconfig`, `~/.tmux.conf`) | `test -e ~/.tmux.conf` before switch; remove/rename stale files if present |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 180s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
