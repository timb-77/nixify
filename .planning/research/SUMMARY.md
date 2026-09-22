# Project Research Summary

**Project:** nixify
**Domain:** Single-user multi-host Nix flake (NixOS full-system + standalone Home Manager) — personal dotfiles-as-configuration
**Researched:** 2026-09-22
**Confidence:** MEDIUM (HIGH on version/EOL, security invariants, and vim-packaging mechanics; MEDIUM on workflows and repo-organization choices)

## Executive Summary

nixify is a personal declarative-configuration repo, not a software product: one flake that reproduces an identical user environment on every Linux machine, where NixOS hosts apply full system config plus Home Manager (HM) as a system module, and non-NixOS hosts (Pop!_OS first) apply standalone HM only. The ecosystem of mature multi-host flakes (EmergentMind, Misterio77, zekzekus, moons-14, and a dozen more) has converged on a small, repeatable shape: a `flake.nix` that only registers hosts, a per-host directory (`hosts/<name>/`), a shared user-module tree (`home/`), a NixOS system layer (`modules/`), `mkHost`/`mkHome` builders, explicit `checks`, and sops-nix for repo-committable encrypted secrets. The research endorses this shape with four adjustments to the draft layout (see Key Findings) and confirms that the defining architecture is the **dual-eval single entry**: one `hosts/<name>/home.nix` imported by *both* the NixOS `home-manager.users.<user>` path and the standalone `homeManagerConfiguration` path, which makes NIX-02 ("identical user config across host kinds") true by construction rather than by discipline.

Two headline findings change the plan as written. First, **the PROJECT.md nixpkgs pin (25.05) is end-of-life** (EOL 2025-12-31, no security updates since); the only supported stable branch as of September 2026 is **26.05** ("Yarara", supported to 2026-12-31). Key Decision NIX-12 must be updated to `nixos-26.05` with HM `release-26.05` and sops-nix all using `follows = "nixpkgs"` to keep the single-nixpkgs constraint intact. Second, **new-host secrets onboarding has a chicken-and-egg problem** — the host age key is created during first activation, but secrets encrypted for a key that doesn't exist yet cannot decrypt on that first pass — so the bootstrap must script a two-pass sequence (provision with placeholder secrets → generate host key on target → register in `.sops.yaml` → `sops updatekeys` → redeploy). This is the single biggest threat to the core value ("fresh machine provisioned in under an hour") and must be a planned, tested step, not an afterthought.

The project's genuine differentiators are (a) **three side-by-side vim flavors** (`vim`, `vim-cpp`, `vim-py`) sharing one core, built via `vim-full.customize { name = ... }` with plugins from pinned `pkgs.vimPlugins` — no surveyed repo ships multiple vim flavors; and (b) **vimspector debugging with zero runtime downloads** — debug adapters (CodeLLDB, debugpy) resolved from nix-store paths instead of `:VimspectorInstall`. The key risks to mitigate: a `sops.age.keyFile` written as a Nix path literal silently copies the private key into the world-readable store (the single most security-critical finding); `vim-full.customize` silently ignores `~/.vimrc` *and* resets Vim defaults (syntax highlighting lost unless `defaults.vim` is re-sourced in the shared `coreRC`); three flavors sharing one home collide on viminfo/swap/undo state unless redirected per flavor; and HM's `useGlobalPkgs`/`useUserPackages` are wrapper-only options that silently disable whole option families if they leak into the shared tree. Recommended roadmap is six phases plus a validation phase (skeleton → base tools → vim flavors → vimspector → secrets → bootstrap → second-host validation), detailed below with research flags.

## Key Findings

### Recommended Stack

Five flake inputs maximum, all pinned in `flake.lock`, exactly one nixpkgs node. The whole "installation" is the flake skeleton itself; `nix flake check` gates it as a build artifact.

**Core technologies:**
- **nixpkgs `nixos-26.05`**: package set + module system. **25.05 is EOL** (2025-12-31) — pinning it ships known-vulnerable packages; 26.05 is the only supported stable (drops 2026-12-31; schedule the 26.11 bump). [HIGH]
- **Home Manager `release-26.05`** (flake input with `inputs.nixpkgs.follows = "nixpkgs"`): user environment via NixOS module (`home-manager.users.<name>`) or standalone (`lib.homeManagerConfiguration`). Release branches pair with NixOS releases; `follows` keeps one nixpkgs in the lock (NIX-12). [HIGH]
- **sops-nix** (flake input, `inputs.nixpkgs.follows = "nixpkgs"`): secrets (NIX-08/09). Only tool with **both** a NixOS module and an HM module; age-based; encrypted YAML committable to the repo; decrypts only at activation. V1 uses the HM module on both host kinds. [HIGH]
- **`vim-full.customize`** (nixpkgs 26.05; `vim_configurable` is a deprecated alias): the `name` attr produces side-by-side executables with disjoint native-vim plugin sets — the official mechanism for NIX-06/07. Must be `vim-full` (huge + python3) for vimspector. [HIGH]
- **`pkgs.vimPlugins`**: plugins pinned at the nixpkgs revision — satisfies "no runtime fetching" (NIX-06) by construction. Native vim packages (`start`/`opt`), never vim-plug. [HIGH]
- **`pkgs.vscode-extensions.vadimcn.vscode-lldb` (CodeLLDB) + `pkgs.python3Packages.debugpy`**: vimspector adapters resolved from the store via `g:vimspector_adapters`; `g:vimspector_install_gadgets = []` forbids runtime downloads (NIX-14). lldb-vscode is the lighter alternative if LLVM is already accepted.
- **`nixfmt-rfc-style`**: formatter (NIX-11) wired to `formatter.<system>` + a `checks.fmt` gate. RFC 166 style, the emerging nixpkgs standard; alejandra deliberately diverges and is unconfigurable.
- **Nix 2.29 (already installed)**: supports everything needed (flakes, `--all-systems`, `nix fmt`, follows). No action.
- **`targets.genericLinux.enable = true`**: **mandatory** on every standalone HM config — fixes XDG_DATA_DIRS so nix-installed GUI apps/desktop files resolve (NIX-16 enabler, home-manager#1439 caveat).
- **Bootstrap mechanism**: `nix run home-manager/release-26.05 -- switch --flake .#<host>` — the repo pins which HM runs; never depend on the locally installed CLI (currently 25.11-pre, a mismatch source, NIX-17).

**Avoid:** `nixos-25.05` (EOL), `vim_configurable` (deprecated), vim-plug/`:VimspectorInstall` (runtime fetch), plain `vim` for vimspector flavors (no python3), `flake-utils` (officially discouraged), channels/`nix-env` (imperative state), HM `nixpkgs.*` overlays under `useGlobalPkgs` (silently ignored), `builtins.fetchTarball` (unlocked), nix-ld on non-NixOS (v1), devenv/devbox (this is a configuration repo).

**Version compatibility:** nixpkgs 26.05 ↔ HM release-26.05 (supported pairing) · HM follows nixpkgs (standard on stable pairs) · sops-nix master pins via flake.lock · `vim-full` + `vimPlugins.*` same revision only · nixpkgs ≥ 24.11 for nixfmt-rfc-style · Nix ≥ 2.24 (have 2.29).

### Expected Features

The Active requirement set (NIX-01..NIX-18) maps almost exactly onto ecosystem table stakes; the differentiators are vim-flavor multiplicity and no-runtime-fetch rigor.

**Must have (table stakes):**
- Layered Base → Roles → Host structure with precedence (`home/` core < roles < `hosts/<name>/`) — NIX-03
- One-dir-per-host + one-line registry (`hosts/registry.nix`) to add a machine — NIX-04
- Managed git + tmux + bash via HM `programs.*` modules — NIX-05/NIX-15 (`programs.bash.enable` also sources `hm-session-vars.sh`)
- Shared user config from one module tree, evaluated by both host kinds — NIX-02 (dual-eval, not copy)
- sops-nix per-host age keys, encrypted files committed, admin/recovery key in every rule — NIX-08/09
- `nix flake check` builds all host closures + HM activation packages + fmt gate — NIX-10/11 (HM configs are **not** auto-checked; wire explicit `checks`)
- Single pinned nixpkgs (26.05), HM follows — NIX-12
- Per-host `secrets.yaml` colocated in the host dir, mapped by `.sops.yaml` path_regex
- Bootstrap documented + scripted for both host kinds — NIX-17
- `xdg.configFile`/`home.file` for configs without dedicated modules (vim extra config, `.gdbinit`, `.vimspector.json`)
- `targets.genericLinux.enable = true` on standalone hosts — non-negotiable

**Should have (differentiators):**
- Three vim flavors (`vim`, `vim-cpp`, `vim-py`) sharing one `coreRC` — single source of truth for editor config; plugins pinned (NIX-06/07)
- vimspector C++/Python debugging with adapters from the nix store, zero runtime downloads (NIX-14) — no surveyed repo does this without `:VimspectorInstall`
- Identical user config across host kinds *by construction* (same file, two eval paths) — stronger than "kept in sync"
- Add-host as 1 directory + 1 registry line, covered by `checks` — the failure mode fails CI before any machine is touched
- <1 h, <10 manual-step bootstrap with scripted two-pass secrets onboarding (NIX-17) — the core-value promise made concrete

**Defer (v2+ / v1.x):**
- NixOS host joins the flake (validates NIX-01/02 for real — standalone-only until then)
- System-level sops secrets (`nixosModules.sops`, `/run/secrets`) — only when a NixOS *service* needs a boot-time secret
- GUI apps via Nix on non-NixOS (NIX-16) — first critical GUI app; validates the XDG story
- aarch64-linux host (NIX-13) — list both systems now, test later
- nixos-anywhere/disko, flake-parts migration (~50+ modules), concrete `roles/` bundles (defer until a 2nd machine differs), full DE theming, nix-ld, fleet deployers, CI

**Anti-features:** vim-plug/`:VimspectorInstall`/coc extension install (runtime fetch — violates NIX-06), disko/impermanence/secure boot, fleet deployers, DE theming/stylix, nix-ld, private-secrets-repo flake input (adds bootstrap steps that fight NIX-17), multi-nixpkgs/unstable overlays, custom module frameworks (`features`/`profiles` dynamic loading), imperative state (channels/`nix-env`).

### Architecture Approach

The verdict on the GSD-BRIEF layout: **the shape is right, four adjustments** — (1) rename `modules/nixos/` + `modules/home/` to `modules/` (NixOS system layer only) + `home/` (shared HM user layer): the user layer is *not* NixOS modules, and the false symmetry invites duplication; (2) drop `users/` (single user → fold identity into `lib/defaults.nix`); (3) shrink `secrets/` → `.sops.yaml` at root + per-host `hosts/<name>/secrets.yaml` colocation; (4) keep `pkgs/` (vim flavors as buildable derivations), `roles/` (empty until needed), `scripts/` + `docs/`. Flake.nix stays a registration-only file; `hosts/registry.nix` is the only mutable flake-facing fact.

**Major components:**
1. **`flake.nix` + `lib/` builders** — inputs (26.05, HM + sops-nix `follows`), `mkNixos`/`mkHome` dual-eval builders, registry mapping → `nixosConfigurations`/`homeConfigurations`/`checks`/`formatter`. Adding a host never edits flake.nix.
2. **`hosts/<name>/`** — thin per-host entries: `default.nix` (NixOS), `hardware.nix` (NixOS, generated), `home.nix` (**the single user entry for both host kinds**), `secrets.yaml`. Precedence: home core < roles < host (NIX-03).
3. **`home/`** — pure-HM user modules (git, tmux, bash, vim flavors, secrets), flat one-concern-per-file. Must never touch NixOS-only options; host-kind divergence only via `isNixOS` specialArg.
4. **`modules/`** — NixOS system layer; never imported by `home/` and vice versa. This boundary discipline is what keeps dual-eval working.
5. **`pkgs/`** — `vim`, `vim-cpp`, `vim-py` as real derivations (`vim-full.customize`, own `vimrcConfig.packages.<pkg>.start` per flavor), buildable standalone via `nix build .#packages.<system>.vim-cpp`.
6. **`roles/`** — opt-in bundles composing `home/` and `modules/`; zero concrete roles until a second machine needs a different bundle (anti-premature-abstraction).
7. **`scripts/` + `docs/`** — `setup.sh` two-pass onboarding; add-host/add-secret/rotate-key manuals (the single-maintainer survival kit).

**Key patterns:** (1) **Dual-eval single entry** — the core of NIX-01/02; (2) **registry-driven host composition** — `hosts/registry.nix` attrset, `filterAttrs` into both configuration sets; (3) **checks as the safety net** — per-system `checks` build every host closure/activation package + fmt gate so host addition is safe from any machine; (4) **vim flavors + per-flavor state redirection** — `viminfofile`/`directory`/`undodir`/`backupdir` under `$XDG_STATE_HOME/vim-<flavor>/` to prevent cross-flavor collisions; (5) **per-host sops with admin escape hatch** — `.sops.yaml` anchored admin key in every rule + per-host `creation_rules` via `path_regex`.

**Evaluation purity rules (NIX-12 constraint):** no IFD (importing/reading derivation outputs pauses eval and hard-fails under `allow-import-from-derivation=false`); no eval-time secret decryption (sops runs at activation only); no `readDir` auto-discovery (registry keeps eval predictable); one nixpkgs via `follows` + `useGlobalPkgs`; per-`system` checks (cross-arch eval only via deliberate `--all-systems`).

### Critical Pitfalls

1. **`sops.age.keyFile` as a Nix path literal → private key in world-readable `/nix/store`** [HIGH] — a path literal silently type-checks to a string and copies the key into the store; every local user (and the binary cache, if ever substituted) can decrypt all secrets. *Avoid:* always a string path (`"/home/tim/.config/sops/age/keys.txt"` / `"/var/lib/sops-nix/key.txt"`); grep gate `keyFile\s*=\s*\./`; store-scan test on fresh activation.
2. **Two-pass onboarding:** host age key doesn't exist before first activation, so first `switch` fails to decrypt. *Avoid:* script the sequence — admin-only/placeholder secrets → generate key on target (`age-keygen`, chmod 600) or derive from SSH host key on NixOS (`ssh-to-age`, one-pass) → register in `.sops.yaml` → `sops updatekeys` → redeploy. (NIX-17 capstone risk.)
3. **`.sops.yaml` structure errors** [HIGH for semantics]: scalar `age:` entries become Shamir groups requiring *all* keys; missing admin key = permanent lockout on host-key loss; stale rules after host decommission. *Avoid:* dash-listed key arrays with `*admin` anchor in every rule, most-specific-first `path_regex` ordering, `sops updatekeys` + commit on every host add/remove.
4. **Host age key loss = permanent secret loss** (age has no recovery). *Avoid:* admin key in every rule + offline admin-key backup ("the seed is the backup"); prefer SSH-host-key-derived keys on NixOS where keys survive reinstalls.
5. **`vim-full.customize` silently ignores `~/.vimrc` AND resets Vim defaults** [HIGH] — customRC *replaces* config: syntax highlighting disappears unless `source $VIMRUNTIME/defaults.vim` heads `coreRC`; user's existing `~/.vimrc` must be consciously migrated into `coreRC`.
6. **Shared vim state across flavors** — viminfo/swap/undo/backup default to per-user shared locations → swap prompts and cross-flavor history confusion during debugging. *Avoid:* per-flavor redirection + `autocmd VimEnter` mkdir (`$XDG_STATE_HOME/vim-<flavor>/`); validate empirically.
7. **`useGlobalPkgs`/`useUserPackages` are wrapper-only options** — set in shared `home/` they eval-fail on standalone (the *first* host!); `useGlobalPkgs` silently disables HM `nixpkgs.*` overlays (overlays belong at system level). *Avoid:* set them only in the NixOS wrapper module in flake.nix; gate divergence behind `isNixOS` specialArg.
8. **Version mismatch**: PROJECT.md pins EOL 25.05; HM release branch must match nixpkgs branch; local HM CLI (25.11-pre) vs repo-pinned HM (26.05) mixes versions. *Avoid:* update NIX-12 → 26.05, `follows` everywhere, bootstrap via `nix run home-manager/release-26.05 --`, one-commit bumps with `nix flake check`, calendar track of EOL (26.05 ends 2026-12-31).
9. **Flake eval pitfalls** [HIGH for IFD semantics] — IFD, eval-time secrets (breaks check on keyless machines, plaintext into store), and eval budget (host count × module count; `nix flake check` evaluates all hosts, builds only `checks.<currentSystem>`).
10. **ssh-to-age derived keys** — an *unencrypted* derived key bypasses the SSH passphrase for decryption; SSH key rotation orphans derived age keys (rekey before rotating). *Avoid:* dedicated `age-keygen` key on standalone hosts with passphrase-protected SSH keys; on NixOS, host SSH keys are normally unencrypted so derivation is standard.
11. **vimspector runtime gadget downloads + missing python3** [HIGH] — `:VimspectorInstall` fetches adapters at runtime (anti-pattern); plain `vim` package disables python3 → vimspector refuses to load; per-project `.vimspector.json` must ship via `home.file` or debugging is machine-specific.

## Implications for Roadmap

The first host is Pop!_OS standalone (NIX-18), so phases build the **standalone path first** and prove the NixOS path on host #2. Every phase ends gated by `nix flake check`. The 26.05 nixpkgs bump (NIX-12) and the two-pass onboarding design are *preconditions* that shape the skeleton and bootstrap phases respectively.

### Phase 1: Flake Skeleton & Host Registry
**Rationale:** Everything hangs off this; it fixes the EOL pin before any config content exists and establishes the wrapper-only-options discipline before the shared tree grows. Standalone-first: the Pop!_OS host is wired with an empty-ish `home.nix` through the dual-eval builder so the standalone path is proven first.
**Delivers:** flake.nix (nixpkgs 26.05 + HM/sops-nix follows — **updates Key Decision NIX-12**), `lib/` builders (mkNixos/mkHome), `hosts/registry.nix` + `hosts/pop/` (+ placeholder NixOS host entry if cheap), `home/` + `modules/` + `roles/` + `pkgs/` skeleton dirs, `checks` (host closure + HM activationPackage + fmt gate), `formatter` (nixfmt-rfc-style — **resolves NIX-11 choice**).
**Addresses:** NIX-01/02/03/04/10/11/12/13/18 (structure + gating); NIX-14 constraint pre-wire (26.05).
**Avoids:** Pitfall 7 (wrapper options in flake.nix only), Pitfall 8 (26.05 + follows), Pitfall 9 (pure eval: no IFD, registry not readDir).
**Research flag:** LOW — standard, well-documented patterns (Misterio77, HM manual). One verification: HM `config.system.build.activationPackage` exists on release-26.05 (ARCHITECTURE flagged it) — verify against the pinned HM revision during planning/execution, not via separate research.

### Phase 2: Base User Environment
**Rationale:** Lowest-cost highest-value content; delivers the table-stakes experience and proves the standalone eval path end to end on real modules.
**Delivers:** `home/base.nix` — `programs.git`, `programs.tmux`, `programs.bash` (NIX-05/15), plain `vim` core flavor (NIX-07) built as `pkgs/vim-flavors`, `targets.genericLinux.enable`, xdg config scaffolding; `hosts/pop/home.nix` imports base. First real `nix flake check` pass on Pop!_OS.
**Addresses:** NIX-05/07/15 + partial NIX-18.
**Avoids:** Pitfall 8 (version alignment), Pitfall 7 (keep wrapper options out of `home/`).
**Research flag:** NONE — HM `programs.*` modules are the most documented surface in the ecosystem; skip research-phase.

### Phase 3: Vim Flavors (vim-cpp, vim-py)
**Rationale:** The first differentiator; depends on the `pkgs/` skeleton from Phase 1. Highest user-visible risk cluster (customize defaults trap + state collisions), so it gets its own phase where both pitfalls can be validated empirically.
**Delivers:** `pkgs/vim-flavors` — three `vim-full.customize` derivations with one shared `coreRC` (headed by `source $VIMRUNTIME/defaults.vim`) + `corePlugins` list; per-flavor plugin sets from `pkgs.vimPlugins`; per-flavor state redirection (`viminfofile`/`directory`/`backupdir`/`undodir` under `$XDG_STATE_HOME/vim-<flavor>/`); user's existing `~/.vimrc` migrated into `coreRC`.
**Addresses:** NIX-06/07 (+ NIX-14 prerequisite: vim-full python3 builds).
**Avoids:** Pitfall 5 (defaults re-source + vimrc migration — test syntax highlighting in all three), Pitfall 6 (state isolation — run all three and verify no swap/history leakage).
**Research flag:** MEDIUM — customize mechanics are HIGH (nixpkgs docs), but state redirection and `~/.vim` runtime-dir interaction are first-principles (ARCHITECTURE "what might I have missed"). Use `/gsd-plan-phase --research-phase` for the vim phase; also resolve the C++ LSP choice (coc.nvim vs clangd direct) flagged by FEATURES.

### Phase 4: vimspector Debugging (C++, Python)
**Rationale:** The second differentiator and highest-complexity feature (HIGH cost); independent of secrets, so order after flavors (its hard dependency) and before bootstrap (so the promise includes debugging).
**Delivers:** `g:vimspector_adapters` in vimrc pointing at store binaries — CodeLLDB (`vscode-extensions.vadimcn.vscode-lldb`) + debugpy (`python3Packages.debugpy`); `g:vimspector_install_gadgets = []`; per-project `.vimspector.json` samples shipped via `home.file`; C++ and Python debug smoke tests.
**Addresses:** NIX-14.
**Avoids:** Pitfall 11 (no `~/.vimspector` writes; adapters resolve to store paths; flavors from vim-full).
**Research flag:** HIGH — the adapter-in-Nix end-to-end pattern is MEDIUM confidence, assembled from a nixvim discourse example + vimspector docs (STACK flagged "validate during the vim phase"). Adapter-path details and CodeLLDB version drift per nixpkgs bump need plan-time research.

### Phase 5: Secrets (sops-nix, user-level)
**Rationale:** Independent of vim work; must precede bootstrap (the script orchestrates the two-pass sequence). Highest security stakes — the invariants (string keyFile, admin anchor, per-host rules) are locked in here while only one host exists and rekey blast radius is minimal.
**Delivers:** `.sops.yaml` (anchored admin key + `path_regex: hosts/([^/]+)/secrets\.yaml$` per-host rules); `home/secrets.nix` importing `sops-nix.homeManagerModules.sops` with `age.keyFile` as a **string** + `age.generateKey = true`; per-host `hosts/pop/secrets.yaml`; `sops updatekeys` workflow; admin-key offline backup; `docs/rotate-key.md` + threat-model note (SSH-derived-key decision for future NixOS hosts).
**Addresses:** NIX-08/09 (HM module only for v1; NixOS system module deferred).
**Avoids:** Pitfall 1 (string path + grep gate + store scan), Pitfall 3 (dash-listed keys, admin escape hatch, rules hygiene), Pitfall 4 (admin backup/recovery drill), Pitfall 10 (dedicated age key on standalone).
**Research flag:** MEDIUM — invariants are HIGH (sops-nix README/autodocs), the workflow is MEDIUM (5+ converging community guides). Standard enough to plan from research; verify two open items at execution: whether current sops-nix auto-creates the `keys.txt` parent dir, and `sops.validateSopsFiles` opt-in behavior.

### Phase 6: Bootstrap & Fresh-Machine Validation
**Rationale:** Capstone validating the core value ("<1 h, <10 steps"). Depends on every prior phase existing so the promise is real. The two-pass onboarding design comes from FEATURES/ARCHITECTURE research; this phase implements and *tests* it.
**Delivers:** `scripts/setup.sh` — install Nix (non-NixOS) → clone repo → `nix run home-manager/release-26.05 -- switch --flake .#<host>`; two-pass secrets sequence with clear prompts (placeholder/config toggle → keygen on target → register → `sops updatekeys` → redeploy); `docs/add-host.md`, `docs/add-secret.md`; **fresh-machine test** — wipe `keys.txt` + runtime dir on a test host, re-run, verify first-activation decrypt (per "Looks Done But Isn't" checklist); first-host <1h timing run.
**Addresses:** NIX-17 (+ completes NIX-18 MVP: fresh Pop!_OS → identical environment).
**Avoids:** Pitfall 2 (scripted two-pass), Pitfall 8 (repo-pinned HM via `nix run`).
**Research flag:** LOW — patterns well-documented (frankper `sec-onboard-host`, HALLway, treffynnon); design from FEATURES dependencies; skip research-phase.

### Phase 7+: Second-Host & Post-V1 Validation (v1.x)
**Rationale:** Deliberately after the standalone MVP. Adding a NixOS host is what actually proves NIX-01/02 (dual-eval on the system-module path) and the NixOS system-level sops path if a boot-time secret appears. GUI apps (NIX-16) validate the XDG story with something the user actually uses.
**Delivers:** First NixOS host via the *same* `home.nix` (proves "identical by construction"); optionally system sops (`/run/secrets`); first critical GUI app via `home.packages` + `xdg.desktopEntries` + the documented GNOME `XDG_DATA_DIRS` desktop-session export; aarch64 host when one appears (eval-only via `--all-systems`).
**Addresses:** NIX-01/02 (real validation), NIX-16, NIX-13 (exercise), NIX-09 (system module path).
**Avoids:** Anti-pattern 2 (never copy a second `home.nix`), Pitfall 10 (SSH-derived keys: rekey before rotating).
**Research flag:** MEDIUM for the NixOS+sops system-module path (deferred details); skip research for GUI apps (documented HM/XDG patterns).

### Phase Ordering Rationale
- **Dependencies first:** skeleton (all phases depend on builders/checks/registry) → base tools (proves eval path) → vim flavors (vimspector's hard dependency) → vimspector → secrets (bootstrap's orchestration dependency) → bootstrap capstone.
- **Risk before volume:** the EVOL-pin fix, wrapper-option discipline, and pure-eval rules (Pitfalls 7/8/9) are established in Phase 1 while the tree is empty — cheapest place to set invariants. Secrets invariants (Pitfalls 1/3/4) are locked in at Phase 5 while one host exists.
- **Differentiator-first vs. completeness-first:** vim work (Phases 3–4) precedes secrets (Phase 5) because flavors are the project's unique value and their risks need empirical validation early; secrets are lower-risk to defer since their design is fully researched.
- **Standalone path first:** the only host at v1 is Pop!_OS standalone — the NixOS path is built (Phase 1) but validated by host #2 (Phase 7), which also avoids the two-`home.nix` drift anti-pattern by construction.
- **Capstone last:** the <1h promise (NIX-17) is only meaningful once the environment it provisions is complete.

### Requirements Map (NIX-01..NIX-18)

| Requirement | Phase(s) | Notes |
|-------------|----------|-------|
| NIX-01 (both host kinds) | 1 (build), 7 (validate) | NixOS path proven by host #2 |
| NIX-02 (identical user config) | 1, 7 | Dual-eval single entry; by construction |
| NIX-03 (layered config) | 1 | Base → Roles → Host precedence |
| NIX-04 (add host: dir + 1 line) | 1 | Registry; gated by checks |
| NIX-05/06/07 (vim suite) | 2, 3 | Plain vim (2); flavors (3) |
| NIX-08/09 (secrets) | 5 (+7 system module) | HM module both kinds v1 |
| NIX-10 (flake check) | 1 | Explicit checks wiring |
| NIX-11 (formatter) | 1 | nixfmt-rfc-style; gate in checks |
| NIX-12 (single nixpkgs) | 1 | **Decision update: 25.05 → 26.05** |
| NIX-13 (aarch64-capable) | 1 (list), 7 (exercise) | Per-system checks |
| NIX-14 (vimspector) | 4 | Store adapters, no runtime fetch |
| NIX-15 (bash base shell) | 2 | programs.bash + session vars |
| NIX-16 (GUI apps) | 7 | XDG story, targets.genericLinux |
| NIX-17 (bootstrap <1h/<10 steps) | 6 | Two-pass onboarding; capstone test |
| NIX-18 (first host Pop!_OS) | 1–6 | Standalone MVP on Pop!_OS |

### Research Flags Summary
- **Needs `/gsd-plan-phase --research-phase`:** Phase 3 (vim flavors — state redirection, runtime-dir interaction, LSP choice), Phase 4 (vimspector — adapter store paths, CodeLLDB drift, end-to-end pattern).
- **Standard patterns, skip research-phase:** Phase 1 (verify activationPackage at execution), Phase 2 (HM programs modules), Phase 5 (sops workflows — standard), Phase 6 (bootstrap — design from research).
- **Execution-time verifications (not research):** HM `activationPackage` on release-26.05; sops-nix parent-dir auto-creation; GNOME desktop-session XDG_DATA_DIRS on Pop!_OS.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM (HIGH on versions) | Version/EOL claims HIGH (official release blogs + nixpkgs/HM docs); vim/sops/flake patterns MEDIUM (docs + community consensus); vimspector adapter-in-Nix end-to-end MEDIUM (assembled, validate in Phase 4) |
| Features | MEDIUM | Heavy multi-repo concordance + official docs; vim flavor mechanism HIGH (nixpkgs docs); secrets workflow MEDIUM (README + 5 converging guides); bootstrap patterns MEDIUM (varies by taste) |
| Architecture | MEDIUM | Layout idioms/dual-eval MEDIUM (official HM manual + multi-repo); vim customize mechanics HIGH; state redirection MEDIUM (first-principles, validate); sops per-host MEDIUM; IFD semantics HIGH |
| Pitfalls | MEDIUM (HIGH on invariants) | keyFile-string, EOL, customRC-replaces-defaults, IFD, ssh-to-age caveats HIGH (primary sources); onboarding/anchor patterns/recovery MEDIUM (converging guides); vim-state isolation MEDIUM (validate empirically) |

**Overall confidence:** MEDIUM — all four research streams agree with each other and the ecosystem on the core shape; the MEDIUM rating reflects two genuinely unverified seams (vim flavor state isolation, vimspector store-adapter wiring) that are explicitly flagged for phase-level empirical validation, plus personal-repo organizational choices where taste dominates.

### Gaps to Address

- **HM `config.system.build.activationPackage` on release-26.05** (ARCHITECTURE): STACK asserts it; verify against the pinned HM revision during Phase 1 — the entire checks design for standalone hosts depends on it.
- **`vim-full.customize` × `~/.vim` runtime dir**: whether non-`start/opt` scripts load for customized vim (affects the state-redirection advice); resolve empirically in Phase 3.
- **Per-flavor vim state isolation**: first-principles, not yet proven; the Phase 3 "run all three and verify" test decides whether Pattern 4's redirection is complete.
- **vimspector adapter path stability**: store paths change on every nixpkgs bump; add "validate once per bump" to the version matrix (STACK) and rebuild incl. flavors.
- **User's existing `~/.vimrc`**: content unknown until the user provides it; Phase 3 must include a deliberate migration step (customize silently ignores it — nothing carries over automatically).
- **C++ LSP choice in vim**: coc.nvim (Node runtime) vs clangd direct integration — explicit decision needed in Phase 3 planning; research only flags the fork, doesn't resolve it.
- **sops-nix open questions**: whether current sops-nix auto-creates the `~/.config/sops/age` parent dir (documented pattern says create manually, chmod 600); `sops.validateSopsFiles` opt-in behavior on the HM module in current master.
- **GNOME "Show Applications" on Pop!_OS**: `targets.genericLinux` covers login shells; a desktop-session-level `XDG_DATA_DIRS` export may be a one-time manual step per machine (home-manager#1439) — document it in Phase 6/7, don't assume it away.
- **NIX-12 decision update**: PROJECT.md still records 25.05; update the Key Decisions table to `nixos-26.05` at the next project-doc transition (start of roadmap/requirements work).
- **Vim plugin versions drift per nixpkgs bump** (FEATURES): validate the pinned plugin set once per upgrade; `vimPlugins.vimspector` confirmed present on 26.05.

## Sources

### Primary (HIGH confidence)
- nixos.org release announcements 25.05/25.11/26.05 — EOL timeline (STACK headline; PITFALLS 8). [HIGH]
- nixpkgs `doc/languages-frameworks/vim.section.md` + NixOS wiki Vim page — `vim-full.customize`, `name` semantics, native packages vs vim-plug, `vim_configurable` deprecation, "silently ignores ~/.vimrc"; nixpkgs issue #301790 (customRC resets defaults). [HIGH]
- Home Manager manual (NixOS module / standalone / flakes chapters, FAQ) + upgrading docs — dual-eval `extraSpecialArgs`, `useGlobalPkgs`/`useUserPackages` semantics, release-branch pairing, version-mismatch warnings. [HIGH]
- Mic92/sops-nix README + module autodocs — both modules, keyFile-as-string rule ("must not reside in the Nix store"), `generateKey`, `updatekeys`, key_groups hyphen pitfall, activation-time decryption. [HIGH]
- Nix reference manual — Import From Derivation semantics, `nix3-flake-check` semantics; nix.dev flakes concept. [HIGH]
- ssh-to-age README; FiloSottile/age README + #578 (PQ note) — derived-key passphrase bypass, rotation coupling, harvest-now-decrypt-later. [HIGH]

### Secondary (MEDIUM confidence)
- Ecosystem repos (EmergentMind, Misterio77, zekzekus, moons-14, treffynnon, MaxWolf-01, frankper "the-one-nix", HALLway, nicolkrit999, cinque.dk, ratachapada, ahmedelgabri, usrrname, rasmus-kirk) — layouts, sops patterns, bootstrap scripts, two-pass onboarding, checks.nix, competitor analysis (FEATURES/ARCHITECTURE). [MEDIUM]
- NixOS wiki (Flake Utils "not recommended", Flake Parts, `targets.genericLinux`, nix-ld, Home Manager page); NixOS Discourse multi-host `mkHost` pattern; nix.dev flakes. [MEDIUM]
- puremourning/vimspector README — adapter resolution order, python3/huge-build requirement, `g:vimspector_install_gadgets`. [MEDIUM]
- vim/vim#19399 — partial XDG state-file support. [MEDIUM]
- nix-community/home-manager issues/Discourse — duplicate module import, version-mismatch warnings, `users.users.<name>.packages` recursion. [MEDIUM]
- unmovedcentre.com, pvv-nixos-config, nicolkrit999 guides; agenix-rekey README — SSH-derived keys, admin-key escape hatch, rekey vs updatekeys, key backups. [MEDIUM]

### Tertiary (LOW confidence, needs validation)
- dsestu.github.io multi-host flake, lovesegfault/viraj-sh/chadac nix-configs — repo-specific organization choices (corroborated by official docs; treated as taste). [LOW]
- zemdregon.github.io nix-docs (2026-08-29) — 26.05/release-26.05 pairing (corroborated by HM official docs + release blogs). [LOW]
- jade.fyi "Stopping evaluation from blocking in Nix" — `fetch*`/IFD symptom signature ("1/2/3 built" during eval), corroborated by the nix manual. [LOW→HIGH via manual]

---
*Research completed: 2026-09-22*
*Ready for roadmap: yes*