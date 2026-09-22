# Pitfalls Research

**Domain:** Multi-host Nix flake configuration (NixOS + standalone Home Manager) — secrets, vim flavors, dual host kinds
**Researched:** 2026-09-22
**Confidence:** MEDIUM (HIGH where marked)

## Executive Summary

The pitfalls that can actually sink this project cluster into five groups: (1) **sops-nix/age secrets** — a wrong option shape puts a private key into the world-readable store, and the new-host onboarding is a chicken-and-egg sequence that must be scripted, not improvised; (2) **vim flavor packaging** — `vim-full.customize` silently ignores `~/.vimrc` *and* resets Vim's default configuration, and three flavors sharing one home directory will collide on viminfo/swap/undo state unless redirected; (3) **HM↔NixOS sharing** — `useGlobalPkgs`/`useUserPackages` exist only in the NixOS-module wrapper and silently disable whole option families, which is exactly how a shared `home/` tree breaks one host kind; (4) **flake evaluation** — IFD and eval-time secret handling are pure-eval killers, and `nix flake check` evaluates *every* host config, so host count and module count are an eval budget; (5) **version drift** — the PROJECT.md nixpkgs pin (25.05) is EOL, and a mismatched HM release branch / locally-installed CLI version produces confusing breakage.

The single most security-critical finding (HIGH): **`sops.age.keyFile` must be a string path; a Nix path literal copies the private key into the store.** Everything else is mitigation-shaped; this one is a hard invariant to enforce in the secrets phase.

## Critical Pitfalls

### Pitfall 1: `sops.age.keyFile` as a Nix path literal → private key in world-readable store

**What goes wrong:**
Writing `sops.age.keyFile = ./keys.txt;` (a Nix path) copies `keys.txt` — the age **private key** — into `/nix/store/...`, world-readable on every machine that evaluates the flake. Anyone with read access to the store (all local users, the binary cache host if the closure is ever substituted, anyone with the repo) can decrypt every secret.

**Why it happens:**
Paths get copied to the store as part of the module tree. The sops-nix docs state the option is `type: str | null` and "must not reside in the Nix store," but a path literal type-checks into a string at runtime — no error is raised, so the mistake is silent. [HIGH, sops-nix autodocs + README]

**How to avoid:**
- Always write `sops.age.keyFile` as a **string**: `"/home/tim/.config/sops/age/keys.txt"` (standalone HM) or `"/var/lib/sops-nix/key.txt"` (NixOS system module).
- Same rule for `sops.defaultSopsFile` if you don't want even the encrypted file in the store, and for `age.identityPaths` in agenix-style configs.
- Add a review gate: grep the config for `keyFile\s*=\s*\./` and for `=/nix/store/` paths pointing at key files.
- Harden the store check into the secrets phase's tests: `ls -l /nix/store/ | grep -i key` on a fresh activation should return nothing.

**Warning signs:**
`/nix/store/*-source/keys.txt` (or similar) present on disk; an age private key file whose path starts with `/nix/store`.

**Phase to address:** Secrets phase (NIX-08/09) — enforce in the shared `home/secrets.nix` module and document in the add-secret manual.

---

### Pitfall 2: Two-pass onboarding — new host has no age key, so secrets can't decrypt on first boot

**What goes wrong:**
`sops.age.generateKey = true` creates the host key *during first activation*. But the secrets in the repo are encrypted for recipients registered in `.sops.yaml` — and a key that doesn't exist yet can't be a recipient. First `home-manager switch` on a fresh machine fails to decrypt `secrets.yaml` (or worse, fails silently and the config is incomplete). This breaks the NIX-17 "< 1 h, < 10 steps" promise if it isn't a planned step.

**Why it happens:**
It's a genuine chicken-and-egg: the key must exist before sops can decrypt; sops-nix only creates the key as part of the decrypt-time activation. [MEDIUM, MULTIPLE community guides converge: frankper, HALLway, pvv, unmovedcentre]

**How to avoid:**
Script the two-pass sequence (frankper's `sec-onboard-host` and HALLway's deployment docs are the reference shapes):

1. First deploy with secrets disabled or encrypted for **admin-only** (`sops updatekeys` later re-encrypts).
2. Generate the host age key **on the target** (`age-keygen -o ~/.config/sops/age/keys.txt`, chmod 600; parent dir must exist — `age-keygen` won't create it). For NixOS hosts, `ssh-to-age` from `/etc/ssh/ssh_host_ed25519_key` works and needs no key file at all.
3. Extract the public key, add `&host` anchor under `keys:` **and** to the host's `creation_rules` in `.sops.yaml`.
4. Run `sops updatekeys hosts/<name>/secrets.yaml` from a machine holding the **admin** key (re-encrypts for the new recipient).
5. Commit, redeploy. Secrets now decrypt.

For NixOS hosts, deriving from the SSH host key means registration can happen *before* first rebuild (nicolkrit999/HALLway pattern) — a one-pass path.

**Warning signs:**
`sops-install-secrets: failed to decrypt ... Error getting data key: 0 successful groups required` on a new host = key not registered, not in `creation_rules`, or secrets not rekeyed (in that order of likelihood).

**Phase to address:** Bootstrap phase (NIX-17) — `scripts/setup.sh` must implement this; document in `docs/add-host.md`.

---

### Pitfall 3: `.sops.yaml` structure mistakes — Shamir semantics, missing escape hatch, stale rules

**What goes wrong:**
Three distinct failure modes, all silent until a decrypt fails on a machine that needs the secret:
1. **key_groups semantics:** if a key type under `key_groups` is a YAML **scalar** instead of a hyphen-prefixed list (e.g. `age: *admin` instead of `age: [*admin]` or `age:\n  - *admin`), sops treats the group as *Shamir secret sharing* and requires **all** listed keys to decrypt. Age recipients must be dash-listed. [HIGH, sops-nix README + pvv guide]
2. **Missing admin/recovery key:** a rule that lists only the host key means a lost host key permanently locks you out of that file's secrets.
3. **Stale rules:** after decommissioning/deleting a host, leftover anchors and rules multiply; worse, a host's secrets stay encrypted to a key you've revoked.

**Why it happens:**
`.sops.yaml` is a hand-edited YAML file with subtle semantics (anchors, path_regex, group lists), and nothing validates it at apply time — `sops updatekeys` only touches files it's pointed at.

**How to avoid:**
- Keep the **admin key in every rule** (anchored, e.g. `*admin`) — it is the escape hatch when any host key is lost.
- Use the standard shape from the sops-nix README: `path_regex: hosts/([^/]+)/secrets\.yaml$` with `key_groups:\n- age:\n  - *admin\n  - *<host>`.
- Order rules most-specific-first (first matching `path_regex` wins).
- After every host add/remove: `sops updatekeys` on the affected files, then commit the diffs so ciphertext matches the rules.
- Consider a pre-commit validation like frankper's (anchors referenced, path_regex resolves, no dead anchors).

**Warning signs:**
A secrets file can't be decrypted with the key that *should* be a recipient; `sops updatekeys` shows "no changes" when you added a host; CI/eval passes but activation fails.

**Phase to address:** Secrets phase (NIX-08/09).

---

### Pitfall 4: Losing a host age key = permanent loss of that host's secrets

**What goes wrong:**
Age has **no recovery mechanism**. `~/.config/sops/age/keys.txt` is lost (disk death, reinstall without backup, deleted `$HOME`), and every secret encrypted only for that host key is gone — unless an admin key was also a recipient.

**Why it happens:**
The private key lives on the machine by design (NIX-08: "one age key per host, never in the repo"), so the machine *is* the backup. Single-user personal projects skip backup steps.

**How to avoid:**
- Admin key in every `creation_rules` entry (Pitfall 3) — the primary recovery path.
- Back up the **admin** key offline (encrypted volume / paper, e.g. BIP-39-style backup via `age-keygen-det`-like tooling) — "the seed is the backup" pattern.
- On NixOS hosts, prefer SSH-host-key-derived age keys (`sshKeyPaths`/`ssh-to-age`): the key is regenerable from the SSH host key, and SSH host keys survive reinstalls better than `$HOME` (and are themselves the usual reinstall survival artifact). HALLway explicitly saves host keys "so it survives reinstalls".
- Alternative for standalone HM: keep an encrypted `.age` backup of each host key on the admin machine (`rage -p -o privkey.age privkey`, from the agenix-rekey README).

**Warning signs:**
You cannot answer "what happens if this laptop dies tomorrow?" for each host's secrets. If the answer is "gone", the host is one error away from data loss.

**Phase to address:** Secrets phase (NIX-08) + `docs/rotate-key.md`.

---

### Pitfall 5: `vim-full.customize` silently ignores `~/.vimrc` **and** resets Vim defaults

**What goes wrong:**
Two related traps:
1. A customized vim **silently ignores any vimrc in your home directory** — all config must live in `vimrcConfig.customRC`. Users keep editing `~/.vimrc` and nothing changes. [HIGH, NixOS wiki]
2. `vimrcConfig.customRC` **replaces** Vim's default config, it does not add to it — syntax highlighting and other defaults are lost unless you re-source them (`NixOS/nixpkgs#301790`, 2024: "breaks syntax highlighting, completely resets default vim configuration"). [MEDIUM, nixpkgs issue + confirmed workaround]

This matters doubled for nixify because there are **three** flavors to keep in sync and `coreRC ++ flavor-tail` composition assumes a single source of truth — but if `coreRC` forgets the defaults re-source, all three flavors silently lose syntax highlighting and the user's muscle memory ("why is my vim dumb now?") blames the whole migration.

**Why it happens:**
`customize` wraps vim with a generated vimrc containing only `customRC` content; `defaults.vim`, normally auto-sourced by Vim when no vimrc exists, is bypassed. And the docs only say "use customRC", not "customRC replaces everything".

**How to avoid:**
- Put `source $VIMRUNTIME/defaults.vim` (or `source ${pkgs.vim-full}/share/vim/vim*/defaults.vim`) **at the top of `coreRC`**, before any flavor tail.
- Migrate the user's existing `~/.vimrc` into `coreRC` deliberately — a documented migration step, not an assumption (FEATURES research flags this too).
- Test: open a `.cpp` and a `.py` file in each flavor and confirm syntax highlighting + `filetype plugin indent on` survive.
- Use `vimrcConfig.beforePlugins` for anything that must run before plugin load (`set nocompatible`), and keep `coreRC` additive-by-construction by never duplicating directives across flavor tails.

**Warning signs:**
Flavor vim shows no syntax highlighting / no defaults out of the box; `~/.vimrc` edits have no effect; a nixpkgs bump suddenly "resets" editor behavior.

**Phase to address:** Vim flavor phase (NIX-05/06/07).

---

### Pitfall 6: Shared vim state across the three flavors (viminfo, swap, undo, backup)

**What goes wrong:**
`vim-full.customize` separates *plugins* (per-flavor derivation), but viminfo/swap/undo/backup state defaults to per-user shared locations (`~/.viminfo`, `~/.cache/vim/*`). Running `vim-cpp` and then plain `vim` mixes jump history, undo trees, and — worse for debugging work — swap files can trigger "Swap file already exists" prompts and session confusion between flavors. Violates the NIX-06 "no shared plugin state" spirit extended to state files.

**Why it happens:**
Vim's XDG support is partial and opt-in (vim/vim#19399 — `.viminfo` etc. stay in `$HOME` unless configured); the ecosystem docs don't cover multi-flavor state. [MEDIUM, vim docs + first principles]

**How to avoid:**
Per-flavor redirection in the flavor-specific `customRC` tail (Architecture research Pattern 4):

```vim
set viminfofile=$XDG_STATE_HOME/vim-cpp/viminfo
set directory=$XDG_STATE_HOME/vim-cpp/swap//
set backupdir=$XDG_STATE_HOME/vim-cpp/backup//
set undodir=$XDG_STATE_HOME/vim-cpp/undo//
autocmd VimEnter * call mkdir($XDG_STATE_HOME.'/vim-cpp/{swap,undo,backup}', 'p')
```

Substitute the flavor name per flavor; keep the same block in all three tails.

**Warning signs:**
Swap-file prompts when opening the same file in a different flavor; undo history appearing across flavors; viminfo sharing.

**Phase to address:** Vim flavor phase (NIX-06/07) — validate during the phase, per Architecture research "What might I have missed".

---

### Pitfall 7: HM↔NixOS sharing — `useGlobalPkgs`/`useUserPackages` silently disable option families and are wrapper-only options

**What goes wrong:**
1. With `home-manager.useGlobalPkgs = true`, **HM's `nixpkgs.*` options (overlays, `allowUnfree`, config) are disabled/ignored** — the HM FAQ explicitly says to put overlays at the system level. An overlay declared in the shared `home/` tree silently stops applying on NixOS hosts but *keeps working* on the standalone host (different pkgs instance) → the two host kinds diverge in exactly the way NIX-02 forbids.
2. `useUserPackages = true` installs `home.packages` via `users.users.<name>.packages` into `/etc/profiles/...` instead of `~/.nix-profile`; HM then needs a different `hm-session-vars.sh` sourcing path in shells, and the manual warns this changes build-vm and env behavior. [HIGH, HM manual + FAQ]
3. **Both options exist only in the NixOS-module wrapper**, not in standalone `homeManagerConfiguration`. A shared `home/` module that sets `home-manager.useGlobalPkgs` (or reads `osConfig` unguarded) evaluates fine on NixOS and **fails to evaluate on the standalone host** — the first host is standalone (Pop!_OS)! [MEDIUM, HM source structure + Discourse]

**Why it happens:**
These are *integration* switches owned by the `nixosModules.home-manager` wrapper (`lib/build.nix`), not HM module options; people put them in `home.nix` out of habit and the dual-eval setup multiplies the blast radius.

**How to avoid:**
- Set `useGlobalPkgs`/`useUserPackages` **only in the NixOS wrapper module in `flake.nix`**, never in the shared `home/` tree.
- Put overlays/config **at the system level** (`nixpkgs.overlays` in `modules/`), and replicate the same overlays in the standalone builder (`pkgs = nixpkgs.legacyPackages.<s>.extend (...)`) or accept the divergence consciously.
- In the shared tree, gate any host-kind-specific need behind the `isNixOS` specialArg (Architecture research Pattern 1) — never reference `osConfig`/`home-manager.*` wrapper options directly.
- If the shell env breaks after enabling `useUserPackages`, re-point the sourced vars file: `~/.nix-profile/etc/profile.d/hm-session-vars.sh` → `/etc/profiles/per-user/<name>/etc/profile.d/hm-session-vars.sh`.

**Warning signs:**
An overlay or `allowUnfree` works on one host kind and not the other; "option `home-manager.useGlobalPkgs' does not exist" eval error on standalone; shell `PATH`/prompt differences after switching a host to the NixOS module.

**Phase to address:** Skeleton/registry phase (NIX-01/02/03) — the wrapper discipline is established there; both later host kinds inherit it.

---

### Pitfall 8: nixpkgs/HM version mismatch — EOL pin and release-branch pairing

**What goes wrong:**
1. **PROJECT.md pins `nixos-25.05` — EOL 2025-12-31.** As of 2026-09 it receives no security updates; a fresh config built on it ships known-vulnerable packages (the STACK research headline). [HIGH, nixos.org release blog]
2. HM release branch must match the nixpkgs branch: HM `master` tracks `nixpkgs-unstable`; `release-26.05` pairs with `nixos-26.05`. A mismatch (e.g. current HM `25.11-pre` CLI/worktree vs pinned nixpkgs 25.05) triggers the explicit warning *"Using mismatched versions is likely to cause errors and unexpected behavior"* — and can genuinely break on options that assume a newer nixpkgs. Do **not** silence it with `home.enableNixpkgsReleaseCheck = false` as routine. [HIGH, HM upgrading docs]
3. The locally installed standalone HM on Pop!_OS is `25.11-pre` — a deployment-repo flake pinned to HM `release-26.05` is a **different HM**; invoking the old CLI (`home-manager switch --flake .#<host>`) mixes CLI version (25.11-pre) with flake module version (26.05), producing confusing warnings/behavior.

**Why it happens:**
EOL branches linger because "it was stable when I pinned it"; HM's branch pairing isn't obvious; the local HM install predates the flake.

**How to avoid:**
- Update Key Decision NIX-12 to `nixos-26.05` + HM `release-26.05` (STACK recommendation); track EOL (`26.05` ends 2026-12-31) and plan the 26.11 bump on a calendar reminder.
- Keep `home-manager.inputs.nixpkgs.follows = "nixpkgs"` so there is exactly one nixpkgs in the lock (also fixes most HM-mismatch warnings).
- Bootstrap via `nix run home-manager/release-26.05 -- switch --flake .#<host>` (NIX-17) so the repo pins which HM runs — never depend on the locally installed CLI.
- When bumping nixpkgs/HM, do it as one commit, run `nix flake check`, and keep the version matrix in STACK.md current.

**Warning signs:**
The HM version-mismatch `trace: warning` prints during eval; `home-manager --version` disagrees with the flake's pinned HM; nixpkgs branch gets no updates on `nix flake lock --update-input nixpkgs`.

**Phase to address:** Skeleton phase (NIX-12) + every phase that runs `nix flake check` (NIX-10).

---

### Pitfall 9: Flake eval pitfalls — IFD, eval-time secrets, and eval budget

**What goes wrong:**
1. **IFD:** passing a *derivation-produced* store path to `import`/`readFile`/`readDir`/`pathExists`/etc. pauses evaluation and realizes the derivation **sequentially** (the evaluator is single-threaded) — much slower than parallel realization, and it hard-fails under `allow-import-from-derivation = false`. [HIGH, nix manual]
2. **Eval-time secrets:** decrypting a secret during evaluation (e.g. `readFile` a decrypted file, or `import` a generated file) puts plaintext into the store *and* breaks `nix flake check` on any machine lacking the key. sops-nix decrypts at **activation** — keep the Nix side referencing only the encrypted file path. [HIGH, sops-nix README]
3. **Eval budget:** `nix flake check` evaluates **all** flake outputs (every `nixosConfiguration`/`homeConfiguration`, regardless of system) but builds only `checks.<currentSystem>`. Each host config is a full module-system evaluation; host count + module count are an eval-time/memory budget. Auto-discovery (`readDir` over `hosts/`), `builtins.fetch*`, and a second nixpkgs instance all inflate eval. [MEDIUM, nix manual + Discourse + jade.fyi]

**Why it happens:**
IFD is easy to trip accidentally when composing helpers; the "decrypt at eval to bake in" habit comes from pre-sops setups; and multi-host growth sneaks up on eval time.

**How to avoid:**
- Import only repo source paths; never `import`/`readFile` a derivation output.
- No secret decryption in Nix code — activation-time only (enforce via code review; the secrets module should only pass the encrypted file path).
- Use the explicit `hosts/registry.nix` (no `readDir`), one nixpkgs via `follows` + `useGlobalPkgs`, and per-system `checks` so `--all-systems` is the only cross-arch eval.
- If eval slows down later: profile with `--trace-function-calls`, consider `flake-parts` at ~50+ modules.

**Warning signs:**
Build output showing "1/2/3 built" progressing during *evaluation* (jade.fyi signature of IFD); `nix flake check` takes minutes on one host; warn-level eval errors from machines without the host's key.

**Phase to address:** Skeleton phase (NIX-10, pure-eval rule) — the discipline is cheapest to establish before hosts accumulate.

---

### Pitfall 10: ssh-to-age derived keys — passphrase bypass and SSH-key-rotation coupling

**What goes wrong:**
Deriving the age key from a passphrase-protected SSH key is convenient, but:
1. If the derived key is written **unencrypted** to `~/.config/sops/age/keys.txt` (the sops-nix default workflow), anyone with read access to that file decrypts every secret **without the SSH passphrase** — the passphrase protection is bypassed for decryption purposes. [HIGH, ssh-to-age README]
2. Rotating the SSH key (or a reinstall generating a new host SSH key) makes the derived age key useless; all secrets must be rekeyed. [HIGH]
3. The derived age key does **not** grant SSH authentication and the SSH key can't be recovered from the age key — one-way.

**Why it happens:**
ssh-to-age is the recommended onboarding path in most guides; the subtle downgrade (passphrase no longer protects decryption) isn't obvious because SSH auth still looks protected.

**How to avoid:**
- Accept the tradeoff consciously for host-level keys (host SSH keys are typically unencrypted anyway — no added exposure; this is the standard NixOS pattern) — or generate a dedicated age key if the machine's SSH key is passphrase-protected and you want that protection.
- On standalone HM where the user SSH key *is* passphrase-protected: prefer a dedicated `age-keygen` key generated on the target, and back it up per Pitfall 4 — don't derive from the personal SSH key.
- If you ever rotate an SSH key that seed-derived age keys: add the new recipient to `.sops.yaml`, `sops updatekeys` **before** removing the old key, then decommission the old annotation.

**Warning signs:**
`~/.config/sops/age/keys.txt` exists and the corresponding SSH key is passphrase-protected (silent downgrade); secrets become undecryptable right after an SSH key rotation/reinstall.

**Phase to address:** Secrets phase (NIX-08) + `docs/rotate-key.md`.

---

### Pitfall 11: vimspector — runtime gadget downloads and missing python3

**What goes wrong:**
1. Default vimspector usage (`:VimspectorInstall`, `g:vimspector_install_gadgets`) **downloads debug adapters from the internet at runtime** into `~/.vimspector/` — exactly the NIX-06 runtime-fetch anti-pattern, and it breaks offline/CI and version-pins nothing.
2. vimspector refuses to load in a vim without python3 support — the plain `vim` package disables python3; flavors must derive from `vim-full`. [HIGH, vimspector README + STACK research]
3. Per-project `.vimspector.json` (debug configurations) is user-side; forgetting to ship the sample configs declaratively (via `home.file`) means debugging "works" only on the host where the user hand-crafted them — a reproducibility leak.

**Why it happens:**
Every vimspector guide assumes interactive gadget install; the python3 requirement is easy to miss because the plugin loads but fails at debug time.

**How to avoid:**
- Adapters from the nix store: define `g:vimspector_adapters` pointing `command` at store binaries (CodeLLDB from `vscode-extensions.vadimcn.vscode-lldb`, debugpy from `python3Packages.debugpy`) and set `g:vimspector_install_gadgets = []` (STACK research pattern).
- Build all three flavors from `vim-full` (never `vim`), per NIX-14.
- Ship per-project `.vimspector.json` via `home.file` in the repo (declarative, identical across hosts).

**Warning signs:**
`~/.vimspector/` directories with downloaded adapters appear after using flavors; debug session errors like "vimspector requires vim with python3"; only one machine can debug.

**Phase to address:** vimspector phase (NIX-14).

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Plaintext secrets in a private repo / unencrypted at rest locally | Setup speed | Massive leak surface; violates constraint NIX-08 | Never |
| Turning off `sops.validateSopsFiles` "to make eval faster" | Faster eval | Broken/plaintext secret files go undetected to activation | Never |
| Silencing HM version-mismatch warning (`home.enableNixpkgsReleaseCheck = false`) | Quiet logs | Hides real branch drift until an option breaks | Never as routine; only during a deliberate 1-release transition |
| Copying a second `home.nix` for the NixOS host instead of dual-eval | Quick first NixOS host | Drift destroys NIX-02 ("identical by construction") | Never — the shared entry is the whole point |
| Two nixpkgs inputs (stable + unstable overlay) | Access to new packages | Breaks single-input decision, two pkgs sets to reason about | Only for a specific pinned exception, documented |
| `readDir` auto-discovery of hosts/ | "No registry to maintain" | Eval unpredictability, hidden eval cost, breaks NIX-04 explicitness | Never at 1-15 hosts |
| Not versioning `.sops.yaml` changes with the ciphertext | Fewer commits | Rogue ciphertext/rekey drift; keys can't be audited | Never |
| Letting the local `home-manager` CLI (25.11-pre) remain the bootstrap path | Zero install work | Version mismatch against repo-pinned HM | Never — use `nix run home-manager/release-26.05 --` |
| Deriving age keys from a passphrase-protected personal SSH key | One key to manage | Passphrase bypass for decryption + rotation coupling | Only with a conscious threat model (see Pitfall 10) |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| sops-nix HM module | `sops.age.keyFile` as a path literal | String path outside the store (Pitfall 1) |
| sops-nix HM module | Wrong key path per platform (NixOS `/var/lib/sops-nix/key.txt` vs standalone `~/.config/sops/age/keys.txt`) | Per-platform keyFile; HM-module path for user-level secrets on both kinds (v1) |
| sops-nix + new host | Adding host key to `keys:` but not to `creation_rules` (or not rekeying) | Anchor **and** rule **and** `sops updatekeys`; verify with the "0 successful groups" checklist |
| sops-nix + .sops.yaml | `age:`/`pgp:` written as scalars (Shamir) | Dash-prefixed lists within one group for OR-semantics (Pitfall 3) |
| sops-nix + HM on both kinds | Deploying secrets encrypted for a key that doesn't exist yet | Two-pass onboarding (Pitfall 2) |
| HM as NixOS module | Importing the HM nixos module more than once | Import once; "option `home-manager.users' already declared" = duplicate import |
| HM as NixOS module | Setting `useGlobalPkgs`/`useUserPackages` inside shared `home/` modules | Wrapper-only options → set in `flake.nix` (Pitfall 7) |
| HM `useGlobalPkgs` | Overlays in `home-manager.users.<u>.nixpkgs.overlays` silently ignored | System-level `nixpkgs.overlays` on NixOS; `.extend` in standalone builder |
| HM `useUserPackages` | Shell env sourcing `~/.nix-profile` vars file after packages moved to `/etc/profiles` | Source `/etc/profiles/per-user/<name>/etc/profile.d/hm-session-vars.sh` (or via `programs.bash.enable`) |
| HM standalone on Pop!_OS | No `targets.genericLinux.enable` | Set it — XDG_DATA_DIRS for nix-installed GUI apps depends on it |
| vim flavors | `~/.vimrc` edited by hand (silently ignored) | All config in `coreRC` per flavor; migrate existing vimrc |
| vim flavors | Same state files across flavors | Per-flavor `viminfofile`/`directory`/`backupdir`/`undodir` (Pitfall 6) |
| vimspector | `:VimspectorInstall` at runtime | `g:vimspector_adapters` from store binaries, `install_gadgets = []` |
| `nix flake check` | Assuming HM configs are auto-checked (they're not) | Wire explicit `checks` building each HM `activationPackage` + NixOS toplevel (STACK skeleton) |
| `nix flake check` | Forgetting `--all-systems` exists, or running it casually | Per-system checks by default; `--all-systems` only for deliberate cross-arch eval |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| IFD in the flake (import/readFile of a derivation output) | "1/2/3 built" ticking up during evaluation; slow `nix flake check` | Pure imports of repo paths only; `allow-import-from-derivation=false` as a sanity flag | First use — it's always slower, not at scale |
| Eval-time secret decryption | Eval requires the host's key; failures on other machines | Activation-time decryption only (sops-nix default) | Any machine without the key / any CI |
| Many hosts × many modules in one flake | `nix flake check` minutes; RAM spikes (full module-system eval per host) | Registry-driven thin hosts; keep `home/` flat; per-system checks | ~5+ hosts with deep module trees; measure, don't guess |
| `readDir`/auto-discovery of hosts | Eval time varies with repo layout; surprises | Explicit `hosts/registry.nix` | Immediately (unpredictable), worse with NixOS auto-generated dirs |
| Two nixpkgs instances (HM private pkgs + system pkgs) | Double eval on every host build | `useGlobalPkgs = true` + `follows` | Every NixOS-host build |
| `builtins.fetch*` calls in modules | Eval blocks on network serially | nixpkgs fetchers / flake inputs | First uncached fetch |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| `sops.age.keyFile` path literal (or any private key path that resolves into the store) | Private key world-readable in `/nix/store` → every secret exposed | String paths only; review gate (Pitfall 1) [HIGH] |
| No admin/recovery key in `creation_rules` | Host key loss = permanent secret loss | Admin anchor in every rule; offline admin key backup (Pitfall 4) [HIGH] |
| Deriving age keys from a passphrase-protected SSH key, then storing unencrypted | Passphrase bypass for all decryption (ssh-to-age README) | Dedicated age key, or conscious acceptance for unencrypted host SSH keys (Pitfall 10) [HIGH] |
| Committing plaintext anywhere (even temporarily, e.g. `.dec.yaml` adds) | Secret exfiltration via git history | `sops` edits only; gitignore plaintext artifacts; history is permanent |
| Encrypting very sensitive secrets to a repo-committed ciphertext without rotation | age is not post-quantum-safe → harvest-now-decrypt-later (FiloSottile/age#578) | Rotate high-value secrets periodically; keep the most sensitive out of the repo |
| World-readable decrypted secret targets (`sops.secrets.<n>.mode`) | Other users read secrets on multi-user hosts | Explicit `mode`/`owner`/`group` per secret (defaults can be too open) |
| Sharing the whole host-key store across machines (copying `keys.txt` around) | Every machine holds every host's private keys | "The keys can only decrypt" is true but enlarges blast radius — keep per-host keys on the host (frankper note) |
| Reusing the sops data key rotation (`sops -r`) as "recipient rotation" | Recipients unchanged; false sense of rotation | `sops updatekeys` for recipients; `-r` only for data-key rotation |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Two-pass secrets onboarding not scripted | Fresh machine fails at first switch with an opaque sops error; the "< 1 h" promise dies | `scripts/setup.sh` walks the two-pass sequence with clear prompts (Pitfall 2) |
| Flavor vim loses syntax highlighting after customizing | "Migrating to nixify broke my vim" — trust in the whole project drops | `source $VIMRUNTIME/defaults.vim` in `coreRC`; test each flavor (Pitfall 5) |
| Shared vim state across flavors | Swap-file prompts, cross-flavor undo/jump history confusion during debugging | Per-flavor state dirs (Pitfall 6) |
| `.vimrc` ignored by all three flavors | Edits silently do nothing; user thinks config is broken | Document "all vim config lives in the flake"; migrate `~/.vimrc` once into `coreRC` |
| HM env vars not sourced in shell after module switch | Commands/editors on PATH missing; "where did my tools go" | `programs.bash.enable = true` (sources `hm-session-vars.sh`); verify per `useUserPackages` path |
| GNOME "Show Applications" missing nix-installed GUI apps | Apps installed but unreachable from the UI | `targets.genericLinux.enable` + optional desktop-session `XDG_DATA_DIRS` export (STACK research) |
| Debugging "works on my machine" only | vimspector broken on the second host | Ship `.vimspector.json` via `home.file`; adapters from the store on all hosts (Pitfall 11) |
| EOL nixpkgs pin with no calendar follow-up | Silent security drift; binary-cache gaps appear at the worst time | Track EOL (26.05 ends 2026-12-31); schedule the 26.11 bump |

## "Looks Done But Isn't" Checklist

- [ ] **Secrets:** Secrets decrypt on the *first* activation of a *fresh* machine — verify by wiping `~/.config/sops/age/keys.txt` + `$XDG_RUNTIME_DIR` secrets on a test host and re-running setup (two-pass actually works; not just "it works on my laptop")
- [ ] **Secrets:** `sops.age.keyFile` is a string path and `grep -r "keyFile\s*=\s*\." .` returns nothing (no private key can enter the store)
- [ ] **Secrets:** Each `creation_rules` includes the admin key AND the host key; `sops updatekeys` produces non-empty diffs when a host is added
- [ ] **Secrets:** A documented, *tested* admin-key recovery path exists (offline backup of the admin key + steps to decrypt a dead host's file from another machine)
- [ ] **Vim flavors:** All three flavors show syntax highlighting with defaults intact (customRC replacement trap)
- [ ] **Vim flavors:** No `~/.vimrc`/`~/.vim` content needed for correct behavior; user's old vimrc already migrated into `coreRC`
- [ ] **Vim flavors:** No `~/.vimspector` downloads happen on any flavor; adapters resolve to store paths (`g:vimspector_install_gadgets = []`)
- [ ] **Vim flavors:** `vim-cpp`/`vim-py` state is isolated (`~/.local/state/vim-cpp` vs `vim-py` vs `vim` verified by running all three)
- [ ] **Host kinds:** The same `hosts/<name>/home.nix` evaluates through both paths with zero NixOS-only options in `home/` (standalone host first proves it)
- [ ] **Host kinds:** A NixOS-only option accidentally added to `home/` fails at `nix flake check` (checks actually catch it — verified by deliberately breaking it once)
- [ ] **Eval:** `nix flake check` completes without any IFD ("1/2/3 built" during eval) and without network fetches
- [ ] **Versioning:** `nixpkgs` is on a supported branch (26.05); HM `release-26.05` follows; no version-mismatch warnings in eval output
- [ ] **Bootstrap:** `nix run home-manager/release-26.05 -- switch --flake .#<host>` works on a machine with no HM installed (not the locally-installed 25.11-pre)

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Private key leaked into store (Pitfall 1) | MEDIUM (all secrets + all hosts) | Rotate every secret: re-encrypt each file for fresh keys (`sops` new data key + new recipients, commit); delete the store copy isn't enough — the key material is compromised, not just exposed |
| Host key lost (Pitfall 4) | LOW if admin key exists, HIGH without | Admin key: `sops` decrypt file on admin machine, re-encrypt for replacement host key (`sops updatekeys` after registering the new key). Without admin key: secrets are gone — restore from backups of `keys.txt` or accept loss |
| First-boot decrypt failure on new host (Pitfall 2) | LOW | Follow the two-pass sequence: register host pubkey → `sops updatekeys` → redeploy; the on-disk state is intact |
| `.sops.yaml` Shamir semantics lockup (Pitfall 3) | LOW | Fix the list syntax, then `sops updatekeys` from a machine holding any currently-valid recipient key |
| Flavor vim "dumb" / no defaults (Pitfall 5) | LOW | Add `source $VIMRUNTIME/defaults.vim` to `coreRC`, rebuild, re-test all three |
| Cross-flavor state collision (Pitfall 6) | LOW | Delete the shared `~/.viminfo`/`~/.cache/vim` once, redirect per flavor; no data loss beyond editor history |
| HM version mismatch breaking eval (Pitfall 8) | LOW-MEDIUM | Align `release-26.05` + `follows`; if modules moved, fix options per upgrade notes; never wait on EOL branches for security fixes |
| SSH key rotation orphaned age keys (Pitfall 10) | MEDIUM (all that host's secrets) | Pre-register new derived key + `sops updatekeys` before rotating; afterwards, recover via admin key and rekey for the new host key |
| `g:vimspector` points at a store path removed by nixpkgs bump (Pitfall 11) | LOW | Adapter paths are store paths — a nixpkgs bump changes them; rebuild incl. vim flavors; validate once per bump (STACK version matrix) |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| keyFile path literal → store leak | Secrets phase (NIX-08/09) | String-path code review + store grep on fresh activation |
| Two-pass onboarding chicken-and-egg | Bootstrap phase (NIX-17) | Fresh-machine test per "Looks Done" checklist |
| `.sops.yaml` structure mistakes | Secrets phase (NIX-08) | Add host → `sops updatekeys` diff non-empty; decrypt on the new host |
| Host/admin key loss | Secrets phase + docs/rotate-key | Documented + tested admin-key recovery drill |
| `customize` ignores `~/.vimrc` / resets defaults | Vim flavor phase (NIX-05/06/07) | All three flavors pass the syntax-highlight test |
| Vim state collision across flavors | Vim flavor phase (NIX-06/07) | Isolated `$XDG_STATE_HOME/vim-<flavor>` dirs verified |
| Wrapper-only HM options leaking into shared tree | Skeleton phase (NIX-01/02/03) | Standalone host evaluates the shared `home.nix` unchanged |
| HM/nixpkgs version mismatch (EOL 25.05) | Skeleton phase (NIX-12) | `nix flake check` shows no mismatch warnings; branch on supported 26.05 |
| IFD / eval-time secrets / eval budget | Skeleton phase (NIX-10) | `nix flake check` with `allow-import-from-derivation=false` succeeds |
| ssh-to-age passphrase bypass / rotation coupling | Secrets phase (NIX-08) + rotate-key doc | Threat-model note in docs; SSH rotation drill |
| vimspector runtime downloads / python3 | vimspector phase (NIX-14) | No `~/.vimspector` writes; adapters resolve to store paths |

## Sources

- Mic92/sops-nix README + `_autodocs` (NixOS/HM module API refs) — keyFile-is-string rule "must not reside in the Nix store", `generateKey`, `updatekeys`, key_groups hyphen pitfall, `defaultSopsFile` store note, `validateSopsFiles`. [HIGH for docs claims]
- Home Manager manual (`installation/nixos.html`, FAQ `change-package-module`, `unstable`), `docs/manual/usage/upgrading.md`; nix-community/home-manager issues #2516 (duplicate module import), #5453/#5931/#5682 + Discourse (version-mismatch warning), PR #6622 (`users.users.<name>.packages` recursion). [HIGH for manual; MEDIUM for issue reports]
- Nix reference manual "Import From Derivation" (2.32/2.33/2.34) + NixOS/nix PR #5253 (IFD disabled in flake show/search/hydraJobs) + Discourse #60857 (paths vs derivations) + jade.fyi "Stopping evaluation from blocking in Nix" (fetch* anti-patterns). [HIGH]
- nixos.org blog releases: 25.05/25.11/26.05 announcements — EOL timeline (25.05 EOL 2025-12-31; 25.11 EOL 2026-06-30; 26.05 → 2026-12-31). [HIGH]
- nixpkgs `doc/languages-frameworks/vim.section.md` + NixOS wiki Vim page — `customize`, "silently ignore any vimrc in your home directory", `vim_configurable` deprecation, `vim` vs `vim-full`. NixOS/nixpkgs#301790 — customRC replaces defaults, syntax highlighting reset. [HIGH for docs; MEDIUM for issue]
- vim/vim#19399 — partial XDG support for state files (`.viminfo` remains home-bound unless configured). [MEDIUM]
- ssh-to-age README — deterministic Ed25519→X25519 derivation, one-way, passphrase bypass caveat, cipher support limits. FiloSottile/age README + #578 — age not PQ-safe, harvest-now-decrypt-later. agenix README — `age.identityPaths` store-string rule, rekeying randomness, PQ note. [HIGH]
- frankper/the-one-nix `readme/setting-up-sops-keys-ssh-gpg.md` — per-platform key paths, two-pass onboarding, `sec-onboard-host` automation, "0 successful groups" checklist, reuse-key note. [MEDIUM]
- MarkusBitterman/HALLway `docs/secrets.md` + pvv-nixos-config `docs/secret-management.md` + unmovedcentre.com NixOS Secrets Management — admin-key escape hatch, ssh-derived host keys, `sops -r` vs `updatekeys`, dash-prefixed key lists. [MEDIUM]
- Sibling research (this project): STACK.md (26.05 pin, vim flavor packaging, sops HM module, version matrix), ARCHITECTURE.md (Pattern 4 state redirection, Pattern 5 secret architecture, IFD section), FEATURES.md (two-pass bootstrap dependency, competitor analysis). [MEDIUM]

**Confidence:** version/EOL, keyFile-string rule, customRC-replaces-defaults, IFD semantics, and ssh-to-age caveats are HIGH (official docs/READMEs + primary sources). Two-pass onboarding, `.sops.yaml` anchor patterns, per-platform key paths, and recovery sequences are MEDIUM (multiple independent community guides converging with the README). Vim-state isolation is MEDIUM (vim first-principles; validate empirically in the vim phase). What might be missing: whether sops-nix's newer releases auto-create the `keys.txt` parent directory on the HM module (manual creation is the documented pattern); exact opt-in behavior of `sops.validateSopsFiles` on the HM module in current master.

---
*Pitfalls research for: nixify — multi-host Nix flake (NixOS + standalone Home Manager), secrets + vim flavors*
*Researched: 2026-09-22*