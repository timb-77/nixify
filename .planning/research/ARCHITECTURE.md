# Architecture Research

**Domain:** Nix flake multi-host configuration (NixOS + standalone Home Manager)
**Researched:** 2026-09-22
**Confidence:** MEDIUM (HIGH where marked)

## Verdict on the Proposed Layout (GSD-BRIEF)

The GSD-BRIEF proposed:

```
flake.nix / flake.lock
hosts/<hostname>/          # per-host config; hardware-configuration.nix for NixOS hosts
modules/nixos/             # shared NixOS modules
modules/home/              # shared Home Manager modules
roles/                     # optional opt-in bundles
users/<username>/          # user identity and user-level entry points
pkgs/                      # custom derivations, incl. the two vim flavors
secrets/                   # sops-encrypted files + .sops.yaml
scripts/                   # bootstrap helpers
docs/                      # how to add a host, rotate a key, etc.
```

**Overall verdict: the shape is right; four adjustments.** It matches the ecosystem idiom (hosts/ per machine, shared module tree, roles as opt-in bundles) with three naming/scope fixes and one deletion. The single most important architectural decision — *one `home.nix` entry imported by both the NixOS-module path and the standalone builder* — is already implied by the brief and is exactly what mature multi-host flakes do (dsestu multi-host guide, Misterio77 starter configs, lovesegfault `modules/{nixos,home,shared}` split). [MEDIUM, multi-repo concordance]

| Proposed | Verdict | Adjustment / Rationale |
|----------|---------|------------------------|
| `hosts/<hostname>/` | ✅ keep | The right granularity. Keep host entries **thin**: `default.nix` (NixOS system entry), `hardware.nix` (NixOS only, generated), `home.nix` (the one user entry for *both* host kinds), `secrets.yaml` (per-host sops file). All heavy lifting in `home/` + `modules/`. |
| `modules/nixos/` + `modules/home/` | ⚠️ restructure | The user layer is *not* "NixOS modules" — it is a Home Manager module tree evaluated by **both** host kinds. Rename to `modules/` (NixOS system layer only) + `home/` (shared HM user layer). This matches STACK.md and avoids the false symmetry that pushes people into duplicating config. If a NixOS-only home-ish option is needed later, guard with an `isNixOS` specialArg rather than creating a parallel tree. |
| `roles/` | ✅ keep | Opt-in bundles composed of `home/` imports and (for NixOS) `modules/` imports. Start with **zero** concrete roles; create one only when a second machine needs a different bundle (anti-premature-abstraction, FEATURES.md). |
| `users/<username>/` | ❌ drop | Single user with the same Unix username on every machine (brief). A `users/` tree is structure with no informational content for one user. Fold identity into `lib/defaults.nix` (`user = "tim"; home = "/home/tim"`) and pass via `specialArgs`/`extraSpecialArgs`. Re-add only if a second user appears. |
| `pkgs/` | ✅ keep | Home of the three vim flavors as real derivations. This is the one part of the ecosystem most repos *haven't* got (they ship one editor) — a small `pkgs/` for `vim`, `vim-cpp`, `vim-py` (`vim-full.customize` with `name = ...`) keeps them buildable stand-alone (`nix build .#packages.x86_64-linux.vim-cpp`) and testable in isolation. |
| `secrets/` | ⚠️ shrink | `.sops.yaml` lives at repo root. Per-host secrets get **colocated** in `hosts/<name>/secrets.yaml` (community norm — frankper, HALLway, nicolkrit999; path_regex maps host dir → host key). Keep a `secrets/` dir only if a shared secret file appears later. |
| `scripts/` + `docs/` | ✅ keep | Bootstrap (NIX-17) and the key-rotation/host-add manual (single maintainer, years of maintenance). |

## Standard Architecture

### System Overview

```
┌────────────────────────────────────────────────────────────────────────┐
│                       flake.nix  (registration only)                    │
│  inputs: nixpkgs(nixos-26.05) · home-manager(release-26.05, follows)   │
│          sops-nix(follows)                                              │
│  helpers from lib/: mkNixos · mkHome · hosts/default.nix registry      │
│  outputs: nixosConfigurations · homeConfigurations · checks · formatter│
└───────────────┬────────────────────────────────────┬───────────────────┘
                │                                    │
    nixosSystem (kind = "nixos")          homeManagerConfiguration
                │                           (kind = "home", non-NixOS)
┌───────────────▼────────────────┐   ┌───────────────▼─────────────────┐
│  hosts/<name>/default.nix      │   │  hosts/<name>/home.nix         │
│    imports: hardware.nix,      │   │    imports: home/ modules,      │
│    modules/ base+roles,        │   │    roles/ home parts            │
│    home-manager module wiring  │   │  home-manager.lib...:           │
│  home-manager.users.<user> =   │   │    targets.genericLinux.enable  │
│    hosts/<name>/home.nix  ─────┼──▶│    modules = [ .../home.nix ]   │
└───────────────┬────────────────┘   └───────────────┬─────────────────┘
                │                                    │
                └───────────────┬────────────────────┘
                                ▼
         home/ module tree  (ONE source, TWO eval paths)
         git · tmux · bash · vim, vim-cpp, vim-py · sops user secrets
                                │
                                ▼
        pkgs/ → vim-full.customize (vim · vim-cpp · vim-py)
        hosts/<name>/secrets.yaml ──decrypt at activation──▶ $HOME (user)
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| `flake.nix` | Declare inputs (single nixpkgs, HM `follows`, sops-nix `follows`); map host registry → outputs; wire checks + formatter | `mkNixos`/`mkHome` helpers in `lib/`; **hosts/registry.nix** attrset is the only file edited for a new host (NIX-04) |
| `lib/defaults.nix` | Identity constants: `user`, `home`, `systems`, mkHost helpers | Plain Nix attrs: `user = "tim";` passed via `specialArgs`/`extraSpecialArgs` |
| `hosts/<name>/default.nix` | NixOS entry: imports hardware + system modules/roles; host-specific `hostName`, services, overrides | Thin file; precedence: `home/` core < `roles/` < `hosts/<name>/` (NIX-03) |
| `hosts/<name>/home.nix` | **The single user entry for both host kinds**: imports `home/` base + role bundles + host overrides | Identical file imported by `home-manager.users.<user>` (NixOS) and `homeManagerConfiguration` (standalone) |
| `hosts/<name>/secrets.yaml` | Per-host sops-encrypted secret values | Encrypted in repo; decrypted only on the target at activation (NIX-08) |
| `home/` | User-layer modules (git, tmux, bash, vim flavors, secrets) — **pure HM options only** | HM modules imported by `home.nix`; must never touch NixOS-only options |
| `modules/` | NixOS system layer (base system config, roles' system parts) | Imported only inside `nixosSystem` modules list |
| `roles/` | Opt-in bundles debounced until needed | `roles/<name>/home.nix` (+ `roles/<name>/system.nix` for NixOS) that a host imports |
| `pkgs/` | Custom derivations: `vim`, `vim-cpp`, `vim-py` | `vim-full.customize { name = ...; vimrcConfig... }` per flavor |
| `scripts/` | Bootstrap + onboarding (`setup.sh`, two-pass sops handling) | NIX-17: <10 manual steps, <1 h |
| `docs/` | Add-host, add-secret, rotate-key, backup-key manuals | The single-maintainer survival kit |

## Recommended Project Structure

```
.
├── flake.nix                  # inputs + outputs only (no per-host logic)
├── flake.lock
├── .sops.yaml                 # creation_rules: hosts/<name>/secrets.yaml → host key
├── lib/
│   ├── defaults.nix           # user, home, systems, (host list)
│   └── mkHost.nix / mkHome.nix# the two small builders (or one file)
├── hosts/
│   ├── registry.nix           # name -> { kind = "nixos"|"home"; system; user }
│   └── <hostname>/
│       ├── default.nix        # NixOS entry (absent for standalone hosts)
│       ├── hardware.nix       # NixOS only, generated by nixos-generate-config
│       ├── home.nix           # ← THE shared user entry (both host kinds)
│       └── secrets.yaml       # sops-encrypted, per-host
├── home/                      # shared Home Manager modules (user layer)
│   ├── base.nix               # git, tmux, bash, vim flavors (NIX-05/15)
│   ├── vim.nix                # builds+installs vim, vim-cpp, vim-py (NIX-06/07)
│   ├── secrets.nix            # sops-nix HM module import (NIX-08/09)
│   └── ...                    # one file per concern; flat, not deep
├── modules/                   # NixOS system layer (host-kind shared base, roles' system parts)
│   └── ...
├── roles/                     # empty until a 2nd machine needs a different bundle
├── pkgs/
│   ├── default.nix            # callPackage entry: vim, vim-cpp, vim-py
│   └── vim/flavors.nix        # shared coreRC + flavor wrappers
├── secrets/                   # only if a shared secret appears later
├── scripts/
│   └── setup.sh               # non-NixOS bootstrap; two-pass sops onboarding
└── docs/
    ├── add-host.md
    ├── add-secret.md
    └── rotate-key.md
```

### Structure Rationale

- **`home/nix` as the single entry (not `hosts/<name>/home.nix` duplicated, not a `users/` tree):** "identical user config by construction" (NIX-02) is achieved by *evaluating the same file through two module-system entry points*, not by copying. The file is per-host only because hosts may override; the *shared* content lives in `home/`.
- **`hosts/<name>/` colocated secrets:** the `.sops.yaml` path_regex `hosts/([^/]+)/secrets\.yaml$` maps each secrets file to that host's age key — one `sops updatekeys` per new host, nothing to search for.
- **Flat `home/`, shallow imports:** each file is one concern; modules import only other files via `home.nix`'s `imports = [ ... ]` list. No dynamic directory walking, no module framework (FEATURES.md anti-pattern: `features`/`profiles` frameworks are over-engineering at 1-2 hosts).
- **`pkgs/` keeps vim flavors as packages, not inline `home.packages` expressions:** testable with `nix build .#packages.<system>.vim-cpp`, reusable, and keeps `home/vim.nix` a two-line install.
- **Registry over auto-discovery:** `hosts/registry.nix` (attrset, one line per host) beats `builtins.readDir` auto-discovery — explicit, ordered, documented, and NIX-04 "add one line" is a literal edit of one file.

## Architectural Patterns

### Pattern 1: Dual-Eval Single Entry (the core of NIX-01/NIX-02)

**What:** One `hosts/<name>/home.nix` module is imported by two different module-system entry points: the NixOS `home-manager.users.<user>` path and the standalone `homeManagerConfiguration` path. Everything user-level is declared once.
**When to use:** Always — this is the project's defining structure.
**Trade-offs:** Cost is a *discipline* (the shared tree must stay pure-HM) rather than infrastructure. If a NixOS-only home need appears (e.g. a service touching system state), express it in `modules/` or gate with an `isNixOS` specialArg — never by forking the tree.

**Example:**
```nix
# flake.nix (abridged — see STACK.md for the full skeleton)
mkNixos = name: cfg: nixpkgs.lib.nixosSystem {
  inherit (cfg) system;
  specialArgs = { inherit inputs; isNixOS = true; };
  modules = [
    ./modules
    (./hosts + "/${name}/default.nix")
    home-manager.nixosModules.home-manager
    {
      home-manager = {
        useGlobalPkgs = true;          # one nixpkgs instance → faster eval
        useUserPackages = true;
        extraSpecialArgs = { inherit inputs; isNixOS = true; };
        users.${cfg.user} = import (./hosts + "/${name}/home.nix");
      };
    }
  ];
};

mkHome = name: cfg: home-manager.lib.homeManagerConfiguration {
  pkgs = nixpkgs.legacyPackages.${cfg.system};
  extraSpecialArgs = { inherit inputs; isNixOS = false; };
  modules = [
    { targets.genericLinux.enable = true; }   # mandatory for non-NixOS (STACK.md)
    (import (./hosts + "/${name}/home.nix"))
  ];
};
```
Cross-checked against the official HM manual (`nix-flakes/nixos.md`, `nix-flakes/standalone.md`): `home-manager.extraSpecialArgs` / `extraSpecialArgs` is the documented mechanism for passing flake inputs to both, and both paths accept `./home.nix` directly. [MEDIUM, official docs]

### Pattern 2: Registry-Driven Host Composition

**What:** `hosts/registry.nix` is an attrset `{ <name> = { kind = "nixos" | "home"; system; user; }; }`; `flake.nix` maps over it with `filterAttrs` into `nixosConfigurations` / `homeConfigurations` and into `checks`.
**When to use:** 2+ hosts. For the first (Pop!_OS) host, standing up registry + builders now is cheap and makes host #2 (NixOS) a one-line addition — this *is* NIX-04.
**Trade-offs:** More indirection than writing two explicit configurations in `flake.nix`, but the registry makes "what machines exist" a reviewable fact and keeps `flake.nix` stable for years.
**Example:** (kind-based builders as in Pattern 1; the checks map in Pattern 3.)

### Pattern 3: Checks as the Safety Net (NIX-10)

**What:** `nix flake check` *evaluates* `nixosConfigurations`/`homeConfigurations` but *builds only* the `checks.<system>` output. So the flake must expose checks that build every host's closure (NixOS) and activation package (standalone), plus a formatter gate.
**When to use:** Always. This is what makes "add a host = touch two files" safe from *any* machine.
**Example:**
```nix
checks = forAllSystems (system: let
  pkgs = pkgsFor system;
  hostChecks = nixpkgs.lib.mapAttrs' (name: cfg:
    nixpkgs.lib.nameValuePair "host-${name}"
      (if cfg.kind == "nixos"
       then self.nixosConfigurations.${name}.config.system.build.toplevel
       else self.homeConfigurations.${name}.config.system.build.activationPackage))
    (nixpkgs.lib.filterAttrs (name: cfg: cfg.system == system) hosts.registry);
in hostChecks // { fmt = /* nixfmt-rfc-style --check over all .nix */; });
```
Note: `nix flake check` builds `checks.<currentSystem>`; cross-system eval uses `--all-systems` (builds only eval, which is what aarch64 readiness wants — NIX-13). Sources: nix manual `nix3-flake-check`; nix.dev flakes concept. [MEDIUM]

### Pattern 4: Vim Flavors as Wrapped Packages + Redirected State (NIX-06/07)

**What:** Three `vim-full.customize` derivations (`name = "vim" | "vim-cpp" | "vim-py"`), each with its own `vimrcConfig.packages.<pkg>.start` plugin list built from `pkgs.vimPlugins` and its own `customRC`. Because `name` sets the executable *and* package name, all three can be installed side by side with disjoint plugin sets and **no** shared plugin state — no plugin manager, no runtime fetching (constraint).
**When to use:** Always, as specified.
**Trade-offs:** Cost is 3× plugin set declarations (managed by `corePlugins ++ [ ... ]` composition — one source of truth) and the residual *state-file* redirection below.
**Important gap the ecosystem docs leave open:** `customize` separates *plugins* (derivation-owned) but **not user state files**. `~/.viminfo`, swap/undo/backup dirs, netrw bookmarks, plugin data (gutentags tag DBs, vimspector configs) default to shared locations and will collide across flavors. [MEDIUM, first-principles from vim docs] Redirect per flavor in `customRC`:
```nix
# home/vim.nix (each flavor gets its own name substituted)
vim-full.customize {
  name = "vim-cpp";
  vimrcConfig.packages.cpp = { start = corePlugins ++ cppPlugins; opt = [ ]; };
  vimrcConfig.customRC = coreRC + ''
    " — state redirection so vim-cpp never touches vim/vim-py state —
    set viminfofile=$XDG_STATE_HOME/vim-cpp/viminfo
    set directory=$XDG_STATE_HOME/vim-cpp/swap//
    set undodir=$XDG_STATE_HOME/vim-cpp/undo//
    set backupdir=$XDG_STATE_HOME/vim-cpp/backup//
    autocmd VimEnter * call mkdir($XDG_STATE_HOME.'/vim-cpp/{swap,undo,backup}', 'p')
  '';
}
```
(Every flavor reads the same `coreRC`; only the flavor-specific tail differs. Customized vim silently ignores `~/.vimrc` — so *all* config lives in `customRC`, which is the desired single source of truth. [HIGH, NixOS wiki + nixpkgs vim docs])

### Pattern 5: Per-Host Sops Secrets with an Admin Escape Hatch (NIX-08/09)

**What:** One `.sops.yaml` at repo root. `keys:` anchors hold the admin key (you, every rule) and per-host keys. `creation_rules` with `path_regex: hosts/<name>/secrets\.yaml$` → `key_groups: [{ age: [*admin, *<host>] }]`. Encrypted files are committed; decryption happens only on the target at activation.
**When to use:** Always (NIX-08/09). V1 uses only the **HM module** (`homeManagerModules.sops`) on both host kinds — user-level secrets need nothing more. The NixOS system module (`nixosModules.sops`, `/run/secrets`) is deferred until a NixOS *service* needs a boot-time secret.
**Trade-offs:** per-host key files mean each host's rekey (`sops updatekeys hosts/<name>/secrets.yaml`) is a different target — documented in docs/rotate-key.md. The admin key in every rule is the escape hatch that keeps a broken host from locking you out of its own secrets.
**Key-file pitfall (HIGH, sops-nix README + community):** `sops.age.keyFile` must be a **string** path (`"/home/tim/.config/sops/age/keys.txt"`). A Nix path literal (`./keys.txt`) copies the private key into the world-readable store. `age.generateKey = true` creates the key at first activation.

## Data Flow

### Bootstrap of a Fresh Machine

```
[NIX] installer  →  clone repo  →  provision host age key  →  apply
   │                  │                    │                       │
   nix run hm --      │                    │   home-manager switch --flake .#<host>
   switch --flake     │                    │               │
   .#<host> ──────────┴────────────────────┴───────────────┘
        eval module tree (home.nix → home/ modules)
        sops: decrypt hosts/<name>/secrets.yaml at activation
        → files symlinked into $HOME (XDCG_CONFIG_HOME etc.)
        → vim flavors & tools on PATH via hm-session-vars
```

### Secret Create/Edit Flow

```
sops hosts/<name>/secrets.yaml   (plaintext in editor only)
   → encrypted YAML committed (admin + host keys)
   → hosts/<name>/home.nix declares sops.secrets.<name>
   → on switch, sops-nix decrypts into XDG_RUNTIME_DIR, symlinks to path
   → app reads symlink target; plaintext never in repo, never in store
```

### State Management

- The **only** runtime state is on the machine: age keys (`~/.config/sops/age/keys.txt`), HM-managed symlinks, and `home-*` profiles. The repo holds desired state; activation reconciles.
- Per-flavor vim state lives under `$XDG_STATE_HOME/vim-<flavor>/` (Pattern 4) so switching flavors cannot clobber history/undo/swap.

### Key Data Flows

1. **Host add (NIX-04):** new `hosts/<name>/` + 1 line in `hosts/registry.nix` → `nix flake check` builds/evals it before any machine is touched → `sops updatekeys` on first activation pass (two-pass onboarding, FEATURES.md).
2. **Config change:** edit `home/…` → `nix flake check` locally → `home-manager switch --flake .#<host>` (standalone) or `nixos-rebuild switch --flake .#<host>` (NixOS) → both paths evaluate the same `home.nix`.
3. **Secret change:** `sops hosts/<name>/secrets.yaml` → declare in `home.nix` → switch.

## Evaluation Purity & Performance (NIX-12 constraint, flakes-only)

**Rule:** evaluation must never depend on a *built* artifact.

- **IFD list (nix manual, HIGH):** any of `import`, `readFile`, `readFileType`, `readDir`, `pathExists`, `path`, `hashFile` given an expression that evaluates to a store path pauses evaluation, realizes the derivation *sequentially*, then resumes — dramatically slower than parallel realization, and disabled entirely under `allow-import-from-derivation = false`.
- **For nixify, stay pure by:** importing only repo source paths (`.nix` files, literal relative paths); never decrypting secrets at eval (sops runs at activation, not evaluation); never using `builtins.getFlake` against a machine-local flake; treating `sops` output as build-time input only.
- **Eval-speed levers (MEDIUM/HIGH):**
  1. **One nixpkgs instance:** `home-manager.useGlobalPkgs = true` makes HM reuse the enclosing system's pkgs instead of evaluating its own — official documented benefit: "improves consistency, reduces evaluation time" (HM manual). Consequence: HM `nixpkgs.*` options are ignored; overlays belong at the system level (STACK.md).
  2. **Lazy outputs:** don't force all hosts when examining one. Per-`system` `checks` mean `nix flake check` on an aarch64 machine doesn't evaluate x86_64 closures; `nix flake check --all-systems` is the deliberate cross-arch eval.
  3. **No `readDir` walking:** `hosts/registry.nix` avoids auto-discovery and keeps eval predictable.
  4. **`follows` everywhere:** HM and sops-nix follow nixpkgs, so the lock has one nixpkgs node and one cacheable package set.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1 host (now) | Today's structure is complete: registry + builders + checks pay for themselves on host #2. Do **not** add roles/flake-parts/CI yet. |
| 2–5 hosts | Add concrete `roles/` bundles the moment a second machine differs (e.g. `roles/desktop` vs `roles/headless`). Watch for hosts that only override one option — that's pressure to promote it to a role or a shared default. |
| 5–15 hosts | If `checks`/`perSystem` boilerplate in `flake.nix` grows, migrate to `flake-parts` (STACK.md: re-evaluate at ~50+ modules); if hosts need behavioral differences beyond packages (e.g. rotating key per role), secret rules grow — keep docs/rotate-key.md current. |
| 20+ hosts | Revisit: per-system eval cost (`nix flake check --all-systems`), a remote/fleet deployer (currently out of scope), and whether per-host `secrets.yaml` should become per-role shared files. |

### Scaling Priorities

1. **First bottleneck — eval drift between host kinds:** the shared `home/` tree accumulates a NixOS-only option and the standalone host silently breaks at eval/check time. Mitigation: `nix flake check` gating + the `isNixOS` specialArg contract + docs rule "home/ = HM options only".
2. **Second bottleneck — secret/key sprawl:** every new host adds a key, a rule, and a rekey. Mitigation: one `.sops.yaml` with anchored admin key; per-host files; `sops updatekeys` documented; admin key as the recovery path.

## Anti-Patterns

### Anti-Pattern 1: Leaking NixOS-only options into the shared `home/` tree

**What people do:** "it's one config, NixOS and standalone" — then someone adds `programs.sway.enable = true` or a `systemd.user` service gated on NixOS-only `cfg`, and the standalone eval breaks.
**Why it's wrong:** The standalone host (Pop!_OS, today's only host!) evaluates the same file; a NixOS-only module is undefined there.
**Do this instead:** `home/` contains pure HM options, period. NixOS-only needs go in `modules/` (system layer) or behind the `isNixOS` specialArg gate, and even then only for genuine host-kind divergence.

### Anti-Pattern 2: Two `home.nix` files that drift (NixOS one vs standalone one)

**What people do:** copy the working standalone config into `home-manager.users.<user>` for the first NixOS host, then fix things in one place and forget the other.
**Why it's wrong:** Destroys NIX-02 ("identical by construction") — the exact property this project sells.
**Do this instead:** the dual-eval single-entry pattern (Pattern 1): the *same file path* in both `home-manager.users.<user>` and `homeManagerConfiguration.modules`. Divergence is then impossible by construction; the only divergence is per-host overrides in `hosts/<name>/home.nix`, which is intended.

### Anti-Pattern 3: IFD / eval-time secret handling

**What people do:** `readFile` a decrypted secret into the module tree, or `import` a file generated by a derivation, to bake secrets into config.
**Why it's wrong:** IFD makes eval slow and sequential; decrypting at eval puts plaintext in the store build inputs (violates NIX-08); breaks `nix flake check` on machines without the key.
**Do this instead:** sops-nix decrypts at **activation** into runtime dirs; the Nix side only ever references the encrypted file path. (sops-nix README: "secrets are decrypted from sops files during activation time".) [HIGH]

### Anti-Pattern 4: Shared vim state across flavors

**What people do:** three `vim-full.customize` flavors, then wonder why `vim-cpp`'s undo history, swap files, or vimspector session state shows up in plain `vim` — because viminfo/undo/swap defaults are shared per-user.
**Why it's wrong:** Actually a *state collision* — the exact "no plugin state sharing" constraint (NIX-06) extended to state files.
**Do this instead:** per-flavor redirect of `viminfofile`/`directory`/`undodir`/`backupdir` (Pattern 4) and keep per-flavor data under `$XDG_STATE_HOME/vim-<flavor>/`. Validate in the vim phase.

### Anti-Pattern 5: `users/` + `hosts/` + `profiles/` + home duplication for a single user

**What people do:** copy a big multi-user repo's `users/<name>/` layout "for future-proofing".
**Why it's wrong:** every layer costs maintenance; a single maintainer with one username gets zero benefit and pays search/indirection costs for years. (FEATURES.md: custom module frameworks are over-engineering at 1-2 hosts.)
**Do this instead:** `lib/defaults.nix` constants + the thin `hosts/<name>/` + shared `home/`. Reintroduce a `users/` layer only when a second human appears.

### Anti-Pattern 6: Host directories as deep import trees

**What people do:** `hosts/pop/desktop/gui/wm/default.nix`… — nesting host config by category.
**Why it's wrong:** spreads one machine's config over many files, breaking the "one host = one directory" mental model (NIX-04) and the registry's thin-host contract.
**Do this instead:** flat `hosts/<name>/` (`default.nix`, `hardware.nix`, `home.nix`, `secrets.yaml`). Categorization belongs in shared `home/`/`modules/`, not in the host dir.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| nixpkgs `nixos-26.05` | single flake input; HM + sops-nix `follows` (NIX-12) | Never a second nixpkgs; bump via `nix flake update` on your cadence. ⚠️ 25.05 is EOL (STACK.md headline). |
| Home Manager `release-26.05` | `nixosModules.home-manager` (NixOS) / `lib.homeManagerConfiguration` (standalone), `extraSpecialArgs = { inherit inputs; isNixOS; }` | Release branch must match nixpkgs branch (STACK.md version matrix). [HIGH] |
| sops-nix | HM module in v1 (`home/secrets.nix`); NixOS module deferred | `age.keyFile` as **string** path; `age.generateKey`; `sops updatekeys` after adding hosts. |
| nixfmt-rfc-style | `formatter.<system>` + `checks.fmt` gate | RFC 166 style; wire to `nix fmt` (NIX-11). |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `flake.nix` ↔ `hosts/registry.nix` | direct import (attrset) | Registry is the only mutable flake-facing fact; builders stay generic. |
| `home/` ↔ `modules/` | **never import each other** | `home/` is pure HM; `modules/` is pure NixOS. Roles compose both, hosts select roles. This is the discipline that keeps dual-eval working. |
| `hosts/<name>/home.nix` ↔ `home/` | `imports = [ ... ]` (module list) | Precedence: home core < roles < host overrides (NIX-03). |
| `pkgs/` vim flavors ↔ `home/vim.nix` | `callPackage`/`pkgs.…` | Flavors built as packages; `home/vim.nix` only installs them + ships `.vimspector.json` via `home.file`. |
| `home/secrets.nix` ↔ `hosts/<name>/secrets.yaml` | `sops.defaultSopsFile` | One sops file per host; rule in `.sops.yaml` guarantees host key is a recipient. |

## Sources

- Home Manager manual `nix-flakes/{nixos,standalone,flake-parts}.md`, `installation/nix-darwin.md` (useGlobalPkgs/useUserPackages), options docs — via Context7 (official docs). [MEDIUM]
- nixpkgs `doc/languages-frameworks/vim.section.md` — `vim-full.customize`, `name` semantics, native vim packages vs vim-plug, `vim_configurable` deprecation; NixOS wiki Vim page ("customized vim silently ignores ~/.vimrc"). [HIGH for docs-verified claims]
- sops-nix README + module autodocs (Mic92/sops-nix) — HM + NixOS modules, `age.keyFile`/`generateKey`, key_groups dash pitfall, `updatekeys`; getsops.io age identities (lookup default `~/.config/sops/age/keys.txt`, 2026-05-15). [MEDIUM]
- nix reference manual, "Import From Derivation" (nix.dev + releases.nixos.org, v2.19–2.35) — IFD trigger list, `allow-import-from-derivation`, sequential realization. [HIGH]
- nix manual `nix3-flake-check`; nix.dev flakes concept — checks semantics: builds `checks.<system>` only, evaluates other outputs. [MEDIUM]
- zemdregon.github.io/nix-docs "NixOS with Home Manager" (2026-08-29) — host-dir layout, `home-manager.users` wiring, `nixos-26.05`/`release-26.05` pairing. [LOW → corroborated by HM official docs]
- dsestu.github.io "Multi-host flake" — portable `home.nix`, `mkHost` one-liners, `networking.hostName` in flake not host file. [LOW]
- lovesegfault/nix-config, viraj-sh/nix-conf, chadac/nix-config-modules (GitHub) — `modules/{nixos,darwin,home,shared}` split, host dir conventions. [LOW]
- STACK.md / FEATURES.md (sibling research, this project) — version pin, skeleton, vim flavor packaging, secrets workflow, two-pass onboarding, ecosystem repo survey. [MEDIUM]

**Confidence:** layout idioms and module-sharing patterns MEDIUM (official docs + multi-repo concordance); vim `customize` mechanics HIGH (nixpkgs docs); per-flavor state redirection MEDIUM (first-principles from vim docs, validate in vim phase); sops per-host architecture MEDIUM (README + community guides); IFD semantics HIGH (official manual). LOW-confidence items (repo-specific org choices) called out inline.

**What might I have missed:** whether `vim-full.customize` swallows `~/.vim` runtime dir loading for scripts not under plugin `start/opt` (affects the state-redirection advice); NixOS system-level sops (`/run/secrets`, `neededForUsers`) details deferred to when a NixOS service needs a secret; whether HM `homeConfigurations` gets a `config.system.build.activationPackage` on current release-26.05 (STACK.md asserts it; verify against the pinned HM revision during the skeleton phase).

---
*Architecture research for: nixify — multi-host Nix flake (NixOS + standalone Home Manager)*
*Researched: 2026-09-22*