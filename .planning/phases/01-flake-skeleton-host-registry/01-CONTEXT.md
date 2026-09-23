# Phase 1: Flake Skeleton & Host Registry - Context

**Gathered:** 2026-09-23
**Status:** Ready for planning

<domain>
## Phase Boundary

A minimal but complete Nix flake that hosts the first Pop!_OS configuration behind dual-eval builders, gated by `nix flake check` and a formatter. Specifically: single-nixpkgs pin (26.05) with follows, a host registry data structure, the standalone Home Manager path fully wired (NixOS path deferred), a tiny functional home config, and a `checks` + `formatter` surface. Real user modules (git, tmux, bash, plain vim) are Phase 2; vim flavors Phase 3; vimspector Phase 4; sops-nix Phase 5; bootstrap capstone Phase 6; NixOS second host Phase 7.

</domain>

<decisions>
## Implementation Decisions

### Registry entry shape
- **D-01:** Host registry lives in `hosts/default.nix` as an attrset keyed by host name; each entry is a **full attrset**: `{ system, kind, username, roles }`. Everything downstream (`homeConfigurations`, `checks`, later `nixosConfigurations`) derives from it via map/genAttrs — flake.nix stays untouched when adding hosts (NIX-04). — **Reversibility:** costly — adding/renaming fields later touches every host entry plus the composer signature.
- **D-02:** First host is named **`razer-blade`** — chosen from hardware (Razer Blade laptop, from DMI/SMBIOS product name), NOT the OS's default hostname `pop-os`. Rationale: the host name identifies the *machine*, and the OS may change over time; distro identity is carried by `kind = "standalone"` separately.
- **D-03:** `kind` field explicitly models `"standalone"` (Home Manager on non-NixOS) vs `"nixos"` — present and filled now (`kind = "standalone"` for razer-blade) even though the NixOS path is not implemented until Phase 7, so no registry redesign is needed later.

### Skeleton module tree
- **D-04:** Phase 1 implements a **tiny functional baseline**, not an empty placeholder chain. The standalone `homeManagerConfiguration` (via `home-manager.lib.homeManagerConfiguration`, explicit `pkgs = nixpkgs.legacyPackages.${system}`) is wired end-to-end and is real — activation must install something on the live machine.
- **D-05:** The baseline consists of `targets.genericLinux.enable = true` (the mandatory, non-negotiable standalone HM env baseline per stack guidance — XDG_DATA_DIRS etc., "non-negotiable on GNOME/Pop!_OS") plus a `home.packages` marker such as `hello` to prove activation actually installs.
- **D-06:** User-facing module tree shape: `modules/base`, `modules/roles`, shared via `hosts/<name>/home.nix`. But in Phase 1 no real modules are imported — razer-blade's module list is `roles = []` (see D-08). Full-shaped env (sessionVariables, home.file) is deferred to Phase 2.

### Dual-eval scope (standalone only)
- **D-07:** Phase 1 wires **only the standalone path**. No NixOS module wiring (`home-manager.nixosModules`, `extraSpecialArgs`, `home-manager.users`) and no NixOS host/stub until a real NixOS host exists in Phase 7 — avoids speculative system code now. "Dual-eval" in the phase goal is honored structurally (registry + composer design keeps both paths buildable later), not by placing NixOS binding now.

### Check surface
- **D-08:** `checks.x86_64-linux` = exactly two gates, matching roadmap success criterion #1: (a) build the home configuration's **activation package** (`config.system.build.activationPackage`) for razer-blade/x86_64-linux, and (b) a **fmt gate** — a cheap check that fails `nix flake check` when any `.nix` file is not formatted (nixfmt `--check`), wired to the `nix fmt` formatter.
- **D-09:** The flake parametrizes over **both systems** (`x86_64-linux` AND `aarch64-linux`) — aarch64 `homeConfigurations` exist and evaluate (NIX-13, criterion #5) — but only x86_64 is **check-built**. No aarch64 eval-check and no both-arch builds; keep the gate fast. No NixOS stub check.

### Role wiring
- **D-10:** Roles attach to hosts **through the registry entry** (`roles = [ "desktop" ]` style lists) — the registry hosting the full attrset is the single source of truth; role modules live centrally under `modules/roles/<name>`. NOT per-host direct imports inside `hosts/` files.
- **D-11:** A shared **role-composer helper** (small pure-Nix `lib` function, ~10 lines) maps `roles` names → `modules/roles/<name>` module paths and composes the final module list for `homeManagerConfiguration`. Base → Roles ordering is expressed as list order inside this one helper; the same composer will be reused by the NixOS `home-manager` module path in Phase 7 (enables NIX-02 "identical config by construction"). Import resolution fails fast at eval time on a missing role dir.
- **D-12:** Build the composer **now but with `roles = []`** for razer-blade in Phase 1 (precedent set, structure exercised by the checks). No placeholder/example role in Phase 1 — the first real role arrives in Phase 2.

### Agent's Discretion
- Formatter package explicitly pinned as `nixfmt-rfc-style` (already settled in roadmap/project docs) — exact derivation shape for the fmt gate left to planner.
- Marker package choice (`hello` vs alternative smoke-test) is open, though `hello` was the discussed default.
- `hosts/razer-blade/home.nix` vs `default.nix` internal filename split left to planner (must ultimately be imported by the standalone home entry; NixOS side will reuse the same entry in Phase 7).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project requirements & roadmap
- `.planning/ROADMAP.md` — Phase 1 goal, success criteria, % requirements mapping. (NIX-03, NIX-04, NIX-10, NIX-11, NIX-12, NIX-13; criterion #1 = activation pkg + fmt gate, #3 = single 26.05 nixpkgs with HM+sops-nix follows, #4 = host = dir + registry line, flake.nix untouched, #5 = Base→Roles→Host precedence + aarch64 parametrization.)
- `.planning/REQUIREMENTS.md` — NIX-03/04/10/11/12/13 full text (v1 infra), traceability table.
- `.planning/PROJECT.md` — Constraints section: flakes-only, single nixpkgs (26.05), HM integration both kinds, secrets, vim constraints. Key Decisions table (26.05 pin).
- `.planning/STATE.md` — Decisions/blockers: dual-eval single entry (`hosts/<name>/home.nix` imported by both NixOS HM module and standalone), standalone-first order, standalone checks design depends on `config.system.build.activationPackage` (verify on release-26.05), verify single-nixpkgs via `follows` in `nix flake check`.

### Stack / research
- `.planning/research/STACK.md` — Recommended stack: nixpkgs 26.05, HM release-26.05 (with `home-manager.inputs.nixpkgs.follows`), sops-nix follows; `homeManagerConfiguration` lib usage with explicit pkgs + extraSpecialArgs; `targets.genericLinux.enable` mandatory on standalone; flake skeleton pattern (`mkHost`/`genAttrs`, no flake-utils — officially discouraged).
- `.planning/research/ARCHITECTURE.md` — Layering model Base→Roles→Host; dual-eval entrypoint details.
- `.planning/research/PITFALLS.md` — Known pitfalls relevant to flake/eval wiring (foo of note: multi-host eval, follows, checks per-system).
- `AGENTS.md` — Installation section: flake.nix skeleton description, host registry one-line pattern, "adding a host = `hosts/<name>/` + one line in `hosts/default.nix`, no flake.nix edits", HM `useGlobalPkgs=true` on NixOS, vim nurture notes (defer — Phase 3).
- `GSD-BRIEF.md` — Layering model (Base/Roles/Host precedence, host = one directory), same-unix-username-on-every-machine assumption, standalone apply via `home-manager switch --flake .#<user>@<host>` (accept `.#<host>` variant per current stack guidance).

</canonical_refs>

<code_context>
## Existing Code Insights

Greenfield repo — no `.nix` source files exist yet (only `.planning/`, `.opencode/`, docs). No reusable Nix assets to import; the phase defines the foundational structure.

### Reusable Assets
- `.planning/research/STACK.md` — the flake skeleton guidance (multi-host `mkHost` pattern, `genAttrs`, `homeManagerConfiguration` invocation shape) is the closest thing to an implementation blueprint; planner should follow it.
- `AGENTS.md` §Installation — pre-committed skeleton conventions (registry in `hosts/default.nix`, one line per host, flake.nix generation).

### Established Patterns
- No code patterns exist. Constraints that shape new code: flakes-only/pure (no channels, no nix-env), single nixpkgs input with HM+sops-nix `follows`, no flake-utils/flake-parts (plain helpers + `genAttrs`), checks are per-system.

### Integration Points
- Nothing existing to connect to — the flake.nix, `hosts/`, `modules/`, and `lib/` roots introduced here become the integration anchors for every later phase (home modules Phase 2, vim flavors 3, sops-nix 5, NixOS path 7).

</code_context>

<specifics>
## Specific Ideas

- Host naming rationale (D-02) is a stated preference: name hosts after the hardware/vendor-model, never the OS, because the OS can change over time. Downstream phases should default to the same convention for new hosts.
- Same Unix username on every machine (per GSD-BRIEF.md) — single-user project; the per-host `username` field tolerates variation but every machine is expected to share it.
- The discussion surfaced (but did not resolve) that `home-manager switch --flake .#<host>` (bare host) is the current apply form per stack guidance, alongside GSD-BRIEF's `.#<user>@<host>` — planner may verify the exact standalone flake output naming during research.

</specifics>

<deferred>
## Deferred Ideas

- **NixOS binding of shared `home.nix`** (D-07) — wiring `home-manager.nixosModules`, `extraSpecialArgs`, and `home-manager.users` is deliberately deferred to Phase 7 when a real NixOS host exists.
- **Example/placeholder role** to structurally exercise role lookup at check time — deferred; first real role arrives in Phase 2.
- **aarch64 eval-check / both-arch checks** — deferred for speed; revisit if a second machine arch arrives.

None — discussion stayed within phase scope beyond the above noted items.

</deferred>

---
*Phase: 1-Flake Skeleton & Host Registry*
*Context gathered: 2026-09-23*