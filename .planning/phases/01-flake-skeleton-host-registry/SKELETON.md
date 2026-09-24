# Walking Skeleton — nixify

**Phase:** 1
**Generated:** 2026-09-24

## Capability Proven End-to-End

> One sentence: the smallest user-visible capability that exercises the full stack.

"A developer can check out this flake, add a host entry (`hosts/<name>/` directory + one line in `hosts/default.nix`), and run `nix flake check` and `nix fmt` to see the host's Home Manager configuration evaluate, gate, and format cleanly — with `home-manager switch --flake .#razer-blade` (optional, user-confirmed) as the real activation proof on the live machine."

## Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Flake framework | Plain `flake.nix` + `nixpkgs.lib.{genAttrs,mapAttrs,filterAttrs,mapAttrs'}` — no flake-parts, no flake-utils | NixOS wiki discourages flake-utils; per-host count is small; helpers keep eval explicit (C6, STACK.md) |
| Package set / pin | Single nixpkgs input `github:NixOS/nixpkgs/nixos-26.05` (one lock node); `home-manager` `release-26.05` and `sops-nix` both declare `inputs.nixpkgs.follows = "nixpkgs"` (NIX-12, criterion #3) | 25.05 is EOL 2025-12-31; single-node topology is a locked requirement and locks the supply chain once |
| Eval topology | Dual-eval composer: `lib/composer.nix` maps the host registry → `homeManagerConfiguration` (standalone path now; the identical module-list helper serves the NixOS `home-manager` module path in Phase 7 → NIX-02 by construction) (D-07, D-11) | "Adding a host = data, not code"; one composer signature to maintain |
| Host registry | `hosts/default.nix` attrset keyed by machine name; each entry `{ system, kind, username, roles }` (D-01); first host `razer-blade` = `{ system = "x86_64-linux"; kind = "standalone"; username = "timbernwald"; roles = []; }` (D-02, D-03, D-12) | Host keys the machine (OS may change); `kind` routes to standalone now, NixOS in Phase 7; flake.nix never lists hosts (NIX-04) |
| Module layering | `modules/base` → `modules/roles/<name>` → `hosts/<name>/home.nix`, expressed as one ordered module list inside the composer (Base → Roles → Host precedence, D-11); `roles = []` in Phase 1 (D-12) | Clear precedence; missing role dir fails fast at eval; Phase 2 fills roles |
| Identity injection | `home.username`, `home.homeDirectory`, `home.stateVersion = "26.05"` injected as modules by the composer from the registry entry | `homeManagerConfiguration` has no username/homeDir args and the options have no default for stateVersion ≥ 20.09 (verified `lib/default.nix:5-38`, `home-environment.nix:186-231`) |
| Activation path | `homeConfigurations.<name>.activationPackage` (equals `config.home.activationPackage`) — **not** `config.system.build.*` (absent on standalone HM release-26.05, verified) | The HM CLI reads the top-level `activationPackage` verbatim for `switch --flake .#<name>` (home-manager:668-671); registry key ≡ CLI name |
| Gates | `checks.x86_64-linux` = exactly two derivations: `home-razer-blade` (activation package) + `fmt` (treefmt `--ci` on a writable copy of the source) (D-08) | Matches roadmap success criterion #1; read-only store tree breaks nixfmt (verified) |
| Formatter | `formatter.<system> = pkgs.nixfmt-tree` (2.6.0) for `x86_64-linux` and `aarch64-linux`; wired to `nix fmt` + the fmt gate (same tool → zero drift) | The Nix manual's own `nix fmt` example; `nixfmt-rfc-style` is a warned alias of `pkgs.nixfmt` 1.5.0 on 26.05 |
| Apply / bootstrap | `nix run home-manager/release-26.05 -- switch --flake .#razer-blade` — never the locally installed CLI (25.11-pre on this machine) | Local CLI drifts from the repo-pinned HM (Pitfall 8); repo pins which HM runs |
| Directory layout | `flake.nix` at root; `hosts/<name>/{default.nix,home.nix}`; `lib/composer.nix`; `modules/base/`, `modules/roles/` | Matches AGENTS.md/STACK.md per-host convention (`default.nix / home.nix / secrets.yaml`); Phase 7 adds `hardware.nix` beside the same `home.nix` (NIX-02) |

## Stack Touched in Phase 1

- [x] **Project scaffold** — `flake.nix` (3 inputs + follows) + `flake.lock` (single nixpkgs node, verified)
- [x] **Routing (config-repo equivalent: registry)** — `hosts/default.nix` registry + `hosts/razer-blade/{default.nix,home.nix}` entry, one line per host
- [x] **Database (config-repo equivalent: module tree)** — `lib/composer.nix` composition (Base → Roles → Host) + `modules/base/default.nix` root; the "read/write" is real Home Manager evaluation producing a buildable activation package
- [x] **UI (config-repo equivalent: gates)** — `checks.x86_64-linux.{home-razer-blade,fmt}` real derivations, including a verified negative control (unformatted file fails the check)
- [x] **Deployment** — `home-manager switch --flake .#razer-blade` documented + planned as an optional, user-confirmed activation run (Plans 01-02/01-03); `nix run home-manager/release-26.05 --` bootstrap form

## Out of Scope (Deferred to Later Slices)

- NixOS binding of the shared `home.nix` (`home-manager.nixosModules`, `extraSpecialArgs` for `osConfig`, `home-manager.users`) — Phase 7, when a real NixOS host exists (D-07)
- Real base modules and role bundles (`modules/roles/*`) — Phase 2
- Vim flavors / vimspector / plugins — Phases 3-4
- Secrets, sops-nix usage, age keys, `.sops.yaml` — Phase 5 (the sops-nix input is pinned now only to lock the single-nixpkgs topology)
- aarch64 eval-checks / both-arch builds — deferred for speed (D-09); aarch64 is proven structurally via `forAllSystems` + `nix eval .#checks.aarch64-linux.fmt.drvPath`
- Live `home-manager switch` — optional in Phase 1 (Plans 01-02/01-03, user-confirmed); guaranteed real first switch is the Phase 6 bootstrap capstone
- GUI apps, desktop entries, `xdg.*` — Phase 7
- `flake-parts` — re-evaluate at ~50+ modules

## Subsequent Slice Plan

Each later phase adds one vertical slice on top of this skeleton without altering its architectural decisions:

- Phase 2: real user modules (git, tmux, bash, plain vim) applied end-to-end on standalone razer-blade
- Phase 3: vim-cpp / vim-py flavors side-by-side, shared core, plugins pinned in Nix
- Phase 4: vimspector debugging with store-resolved adapters, zero runtime downloads
- Phase 5: sops-nix secrets on both host kinds (encrypted in repo, decrypted on target)
- Phase 6: fresh-machine bootstrap in under 1 hour, <10 manual steps
- Phase 7: NixOS host joins via the same registry + `home.nix`; GUI apps managed on non-NixOS