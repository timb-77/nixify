# Phase 1: Flake Skeleton & Host Registry - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-23
**Phase:** 1-Flake Skeleton & Host Registry
**Areas discussed:** Skeleton module tree, Registry entry shape, Check surface, Role wiring

---

## Skeleton module tree

### Q: How much substance should the skeleton carry in Phase 1?

| Option | Description | Selected |
|--------|-------------|----------|
| Empty placeholder chain | modules/ exist as evaluation-proof placeholders (mostly `{}`), host home.nix near-empty | |
| Tiny functional baseline | home.nix wires targets.genericLinux.enable, a home.packages marker, shared module list — so switch installs something real | ✓ |
| No module tree yet | Skeleton is only flake.nix + hosts/default.nix + hosts/pop/home.nix | |
| Baseline + stubbed layers | Baseline plus placeholder slots for modules/base and modules/roles | |

**User's choice:** Tiny functional baseline

### Q: What exactly makes up the 'tiny functional baseline'?

| Option | Description | Selected |
|--------|-------------|----------|
| genericLinux + hello marker | targets.genericLinux.enable = true + home.packages marker like hello; module list composed by shared lib helper | ✓ |
| Full-shaped baseline | Also home.sessionVariables and home.file/.config scaffolding | |
| Baseline + stubbed layers | Wire placeholder module list NOW with empty bodies | |
| Other | Drop/swap marker or different smoke-test | |

**User's choice:** genericLinux + hello marker
**Notes:** User first asked "what is genericLinux?" — explained it's a Home Manager option for non-NixOS hosts (sets XDG_DATA_DIRS etc., injects Nix profile), mandatory on standalone Pop!_OS per stack guidance.

### Q: Phase 1 goal says 'dual-eval flake'. How far does the NixOS side get wired before a real NixOS host exists?

| Option | Description | Selected |
|--------|-------------|----------|
| Placeholder NixOS host now | Wire home-manager.nixosModules + extraSpecialArgs for a placeholder host | |
| Standalone-only Phase 1 | Only build the standalone homeManagerConfiguration path; NixOS wiring arrives in Phase 7 | ✓ |
| Helpers both, host only standalone | Wire lib helpers for both paths but only create the standalone host | |

**User's choice:** Standalone-only Phase 1

---

## Registry entry shape

### Q: What should each entry in the host registry carry?

| Option | Description | Selected |
|--------|-------------|----------|
| Full attrset | { system, username, kind, roles } — one line per host, everything derives from it | ✓ |
| Minimal + host files | { system } only; username/roles declared in hosts/<name>/ files | |
| System + roles | { system, roles }; username in shared constants | |

**User's choice:** Full attrset

### Q: What do we name the first host (and its hosts/<name>/ directory)?

| Option | Description | Selected |
|--------|-------------|----------|
| Real hostname | Name after the actual machine hostname | ✓ (later revised) |
| Distro-based name | e.g. pop / popos | |
| Personal alias | Neutral/meaningful personal name | |

**User's choice:** Real hostname
**Notes:** Machine reports `pop-os` (default). User then said: "I'd rather like to use the Vendor-Model name of the laptop than using the OS name, since the OS could actually change over time" — DMI read: Razer "Blade".

### Q: Lock in a model-based host name?

| Option | Description | Selected |
|--------|-------------|----------|
| razer-blade | hosts/razer-blade/, --flake .#razer-blade — identifies hardware, independent of OS | ✓ |
| Custom variant | blade, rblade, razer, personal alias | |

**User's choice:** razer-blade

---

## Check surface

### Q: Which gates should `nix flake check` run in Phase 1?

| Option | Description | Selected |
|--------|-------------|----------|
| Minimum | Activation package build (x86_64) + fmt gate | ✓ |
| Minimum + aarch64 eval | Plus eval-only check for aarch64 output | |
| Both-arch builds | Build both x86_64 and aarch64 home activations | |
| Minimum + NixOS stub | Plus NixOS toplevel stub check | |

**User's choice:** Minimum
**Notes:** User first asked "what does 'fmt' mean in 'fmt gate'?" — explained: a check derivation running `nixfmt --check` over the source tree that fails `nix flake check` on any unformatted .nix file (lint only, doesn't reformat).

### Q: How do we treat aarch64 within the 'minimum' check surface?

| Option | Description | Selected |
|--------|-------------|----------|
| Parametrized, gate only x86_64 | Both systems in flake.nix, aarch64 evaluable, only x86_64 check-built | ✓ |
| Parametrized + aarch64 eval check | Explicit aarch64 eval-only check in nix flake check | |

**User's choice:** Parametrized, gate only x86_64
**Notes:** Meets success criterion #5 structurally without slow gates.

---

## Role wiring

### Q: How should roles attach to a host?

| Option | Description | Selected |
|--------|-------------|----------|
| Named in registry | roles = [ ... ] in registry entry; shared lib helper maps names → modules/roles/<name> | ✓ |
| Imported in host files | hosts/<name>/home.nix directly imports ../../modules/roles/... | |

**User's choice:** Named in registry
**Notes:** User first asked "can you please explain what the registry is?" — explained hosts/default.nix as the machine list from which all flake outputs derive (NIX-04 promise). Choice aligns with the earlier Full-attrset decision.

### Q: Do we build the role-composer now, or defer it?

| Option | Description | Selected |
|--------|-------------|----------|
| Helper now, roles empty | Composer built now (shared lib), razer-blade starts roles = []; first real role in Phase 2 | ✓ |
| Helper + example role | Placeholder role so mapping is exercised by a check from day one | |
| Defer composer | Phase 1 wires flake directly to home.nix; roles introduced with first real role | |

**User's choice:** Helper now, roles empty
**Notes:** User first asked "tell me more about the composer" — explained it as ~10-line pure-Nix helper composing base + role modules into the module list for homeManagerConfiguration, reusable by the future NixOS path, failing fast on missing role dirs.

---

## Agent's Discretion
- Exact fmt gate derivation shape (nixfmt-rfc-style invocation, file list)
- Marker package choice (hello was default discussed)
- hosts/razer-blade internal filename split (home.nix vs default.nix)
- Exact standalone flake output naming (`.#<host>` vs `.#<user>@<host>`)

## Deferred Ideas
- NixOS binding of shared home.nix → Phase 7
- Example/placeholder role to exercise role lookup → Phase 2 (first real role)
- aarch64 eval-check / both-arch checks → revisit when a second arch machine arrives