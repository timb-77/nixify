# Phase 2: Base User Environment - Context

**Gathered:** 2026-10-07
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers the core user environment modules (git, tmux, bash, plain vim) applied end-to-end on the standalone Pop!_OS host (razer-blade), proving the Base layer composition works with real modules. It does NOT add vim-cpp/vim-py flavors (that's Phase 3) or vimspector (Phase 4) or secrets (Phase 5).

</domain>

<decisions>
## Implementation Decisions

### Module Organization
- **D-01:** Split base modules into separate files (`git.nix`, `tmux.nix`, `bash.nix`, `vim.nix`) imported from `modules/base/default.nix` — keeps modules discoverable and composable while following the Base→Roles→Host layering. — **Reversibility:** reversible — can consolidate later without breaking callers.
- **D-02:** Keep each module self-contained (enable its `programs.*` options, set minimal config). Do not cross-reference between tool modules except via shared paths/config already provided by Home Manager context. — **Reversibility:** reversible

### Git Configuration (NIX-05)
- **D-03:** Enable `programs.git.enable = true` with minimal sensible defaults (user.name, user.email, init.defaultBranch, core.editor, pull.rebase). Keep identity values simple (can be overridden per-host later if needed). Do not enable commit signing by default in Phase 2. — **Reversibility:** reversible — can add signing config in later phase.
- **D-04:** Set `core.editor` to `vim` (ties to the managed vim). Keep aliases minimal (e.g., `status`, `log --oneline`) — avoid heavy alias sets. — **Reversibility:** reversible

### Tmux Configuration (NIX-05)
- **D-05:** Enable `programs.tmux.enable = true` with conservative defaults: vi mode on, mouse off (or configurable), sensible escape-time/history-limit. No external tmux plugins in Phase 2 — keep vanilla managed config. — **Reversibility:** reversible — plugins can be added later if needed.
- **D-06:** Prefix key remains default `Ctrl-b` (Home Manager default). Avoid custom keybindings beyond essentials; prioritize clarity over personalization. — **Reversibility:** reversible

### Bash Management (NIX-15)
- **D-07:** Enable `programs.bash.enable = true` and ensure bash is the managed base shell. Configure minimal, non-invasive `.bashrc` (history settings, PS1 if needed) without overriding system-wide behavior. — **Reversibility:** reversible
- **D-08:** Rely on Home Manager session env via login shells; no aggressive PATH manipulation beyond what HM provides. — **Reversibility:** reversible

### Plain Vim (NIX-07)
- **D-09:** For Phase 2, provide plain vim via `programs.vim.enable = true` with shared core settings only (syntax on, filetype detection, nocompatible baseline, sensible search/indentation, line numbers). This satisfies "plain vim available with common core only" while keeping Phase 2 simple. — **Reversibility:** reversible
- **D-10:** Keep vim package as default from nixpkgs (not vim-full) for plain vim in Phase 2. Flavored vims (vim-cpp/vim-py) will use `vim-full.customize` in Phase 3; the shared core vimrc/config will be extracted/reused so both paths share the same core settings. — **Reversibility:** reversible — structure allows migrating plain vim to customized build in Phase 3 without breaking behavior.
- **D-11:** Do not add any plugins to plain vim in Phase 2. Plugins belong to flavored vims (Phase 3) per the constraint "no runtime fetching" and flavor isolation. — **Reversibility:** reversible

### Integration & Verification
- **D-12:** Wire modules into `modules/base/default.nix` by importing the split tool modules (order: git, tmux, bash, vim — order shouldn't matter functionally). — **Reversibility:** reversible
- **D-13:** Keep existing `targets.genericLinux.enable = true` and the hello marker in the host home entrypoint as-is; Phase 2 adds real modules without removing the marker (can keep or remove later — non-functional). — **Reversibility:** reversible
- **D-14:** Verification: after `home-manager switch --flake .#razer-blade`, `git --version`, `tmux -V`, `bash --version`, `vim --version` all report Nix-provided binaries; plain `vim` loads with core settings. Also `nix flake check` must still pass. — **Reversibility:** N/A (verification)

## the agent's Discretion
- Exact PS1/history values for bash (keep minimal, conventional)
- Exact vim core settings set (sensible defaults; avoid heavy customizations)
- Git identity placeholders (e.g., user.name "User", user.email "user@example.com") are fine if not overridden — Home Manager will manage them; can be refined later

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Artifacts
- `.planning/REQUIREMENTS.md` — NIX-05, NIX-07, NIX-15 definitions and traceability
- `.planning/ROADMAP.md` — Phase 2 goal, success criteria, dependencies
- `.planning/PROJECT.md` — Core value, constraints (flakes-only, single nixpkgs, vim constraints)
- `.planning/research/STACK.md` — Technology stack, vim packaging notes, HM patterns
- `.planning/phases/01-flake-skeleton-host-registry/01-01-SUMMARY.md` — Established patterns (composer, layering, host registry)
- `lib/composer.nix` — How Base→Roles→Host modules are composed
- `modules/base/default.nix` — Base layer entrypoint
- `hosts/razer-blade/home.nix` — Host home entrypoint (standalone)

[No external specs — requirements fully captured in decisions above]

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/composer.nix`: The composition logic that imports `modules/base`, roles, and host home.nix. Any new base modules must be imported from base/default.nix to be picked up.
- `modules/base/default.nix`: Currently empty Base layer — ready to import tool modules.
- `hosts/razer-blade/home.nix`: Standalone HM entrypoint with `targets.genericLinux.enable = true`. Real modules will come from Base layer.

### Established Patterns
- Layering: Base (shared) → Roles → Host (most specific). Tools git/tmux/bash/vim are base-level for all machines.
- Home Manager standalone: `homeConfigurations` built via `home-manager.lib.homeManagerConfiguration` with `pkgs`, `extraSpecialArgs`, and modules list. Identity comes from registry.
- Flakes-only, single nixpkgs (26.05), HM release-26.05. All via `inputs.nixpkgs.follows`.
- No runtime fetching constraint applies to vim plugins (Phase 3) — Phase 2 has no plugins.

### Integration Points
- New `.nix` files in `modules/base/` (git.nix, tmux.nix, bash.nix, vim.nix)
- Update `modules/base/default.nix` to import them
- Existing flake/checks/composer remain unchanged — composition is additive
