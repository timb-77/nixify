---
phase: "01"
slug: "flake-skeleton-host-registry"
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: "2026-09-24"
---

# Phase 01 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| user decision → profile mutation | The human is the trust anchor: only option-a would authorize mutating the live home profile outside the repo (01-02 checkpoint) | none in this phase — option-b recorded, no switch ran |
| which-HM-CLI boundary | Activation must use the repo-pinned `nix run home-manager/release-26.05 --`, never the local 25.11-pre binary | none in this phase — no activation executed (01-03 retired) |
| authored tree → /nix/store | Flake source becomes world-readable store paths; credential material must never enter | identity only (username from registry), no secrets |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-01-01 | Tampering | flake inputs (nixpkgs, home-manager, sops-nix) | high | mitigate | flake.lock pins all three to canonical GitHub revisions resolved this session (package-legitimacy audit in RESEARCH.md, all OK); `inputs.nixpkgs.follows` on HM + sops-nix forces exactly one nixpkgs node | closed |
| T-01-02 | Information Disclosure | authored tree → /nix/store (credential material) | high | mitigate | Phase 1 ships zero secrets by construction (marker = hello; identity = username from registry); grep tripwire for credential-shaped strings in flake.nix/hosts/lib/modules is clean; no key-file or age material planned until Phase 5 | closed |
| T-01-03 | Tampering | build-time evaluation (arbitrary code surface) | medium | mitigate | Pure eval only: static module paths, no IFD, no `builtins.fetchTarball`/`fetchurl`, no channel state (C1 constraint); `nix flake check` runs gates in the sandbox exercising this purity | closed |
| T-01-04 | Tampering | activation CLI version drift | medium | mitigate | Local `home-manager` CLI is 25.11-pre and MUST NOT be used; activation only via `nix run home-manager/release-26.05 --` | closed |
| T-01-SC | Tampering | package installs (npm/pip/cargo) | low | mitigate | No ecosystem-registry packages installed; the three flake inputs audited (RESEARCH.md Package Legitimacy Audit — OK/pinned, none [ASSUMED]/[SUS]) | closed |
| T-01-02-01 | Spoofing | decision checkpoint | medium | mitigate | Blocking-human gate never auto-approved (gate attribute enforced regardless of auto_advance); options presented neutrally; auto-mode was false during execution | closed |
| T-01-02-02 | Tampering | activation CLI version drift | high | mitigate | 01-03's switch is specified verbatim as `nix run home-manager/release-26.05 -- switch --flake .#razer-blade` — can never resolve to the local 25.11-pre CLI | closed |
| T-01-02-SC | Tampering | package installs (npm/pip/cargo) | low | mitigate | No registry packages installed this plan; HM release-26.05 resolved via nix run is the pinned flake input evaluated this session | closed |
| T-01-03-01 | Tampering | CLI version drift (local 25.11-pre home-manager on PATH) | high | mitigate | Plan retired (option-b): only sanctioned invocation `nix run home-manager/release-26.05 -- switch --flake .#razer-blade`; bare `home-manager` PATH invocation forbidden | closed |
| T-01-03-02 | Repudiation | silent switch failure or partial apply | medium | mitigate | Plan retired — no switch ran; dual verify (switch exit status + out-of-band marker check) deferred to Phase 6 with the activation | closed |
| T-01-03-03 | Information Disclosure | switch writing into tracked repo paths | low | mitigate | Plan retired — no switch ran; `git status --porcelain` empty verify deferred to Phase 6 with the activation | closed |
| T-01-03-SC | Tampering | package installs (npm/pip/cargo) | low | mitigate | Plan retired — no registry packages; home-manager/release-26.05 is the flake input pinned in flake.lock (legitimacy OK in RESEARCH.md); hello from pinned nixpkgs | closed |

*Status: open · closed · open — below {block_on} threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|

No accepted risks.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-24 | 12 | 12 | 0 | gsd-security-auditor (L1, plan-time register) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-09-24