# AGENTS.md — Project Constitution

This repository is a **bash-first utility suite** that turns an **ultra-minimal host** (minimal CentOS / FCOS bootc-style images with just container engines) into a **cloud-native desktop** by orchestrating:

- **distrobox** for *interactive workspaces* (human-facing shells, dev envs, GUI apps)
- **podman** for *services* (daemonized components: portals, sync, indexers, tool servers)
- **systemd (user)** and/or **quadlet** for *persistent lifecycle management*
- optional “cloud-native” primitives (networks, volumes, secrets patterns) in a host-minimal way

This file defines the project’s invariants, conventions, and how our agents collaborate.

---

## Core invariants (non-negotiable)

### Rootless-first
- Default to **rootless** podman/distrobox and **systemd --user**.
- If root is required, it must be:
  - explicit (a flag like `--as-root` / `--system`)
  - justified (why root is necessary)
  - minimized (smallest scope possible)

### Idempotency
Running the same command twice should be safe:
- “create” becomes “create-or-update”
- “apply” becomes reconciliation (desired → actual)
- “remove” is safe if already absent

### Minimal-host assumptions
Assume the host has:
- container engine(s) (podman)
- basic shell utils + systemd/journald (often)
- **not** much else (`jq`, `python`, `yq`, etc. may be missing)

If optional dependencies exist, features must:
- detect them
- provide actionable guidance
- degrade gracefully

### Clear state model
All state must be:
- **discoverable** (one place, predictable layout)
- **versioned** (schema version)
- **migratable** (upgrade/downgrade strategy)
- **cleanable** (remove/uninstall doesn’t leave mystery)

### Safe defaults
- No ports exposed to `0.0.0.0` by default.
- No privileged containers by default.
- No wide host mounts by default.
- Dangerous modes must be explicit and loudly documented.

---

## Mental model

We manage two categories of containers:

### 1) Workspaces (distrobox)
“Where the user *works*”
- interactive shells
- dev toolchains
- GUI apps
- per-distro personality

### 2) Services (podman + systemd/quadlet)
“Desktop infrastructure”
- background services (user-scoped)
- stable volumes/networks
- journald logging
- start/stop/status semantics

**Rule of thumb:** if it needs to survive reboots and be managed like a daemon → service.  
If it’s an interactive environment → workspace.

---

## UX contract (CLI behavior)

All primary commands must:
- support `--help`
- print human-readable output to stdout
- print errors to stderr
- return consistent exit codes
- be scriptable via `--json` **only if** we can do so without heavy deps  
  (otherwise provide `--porcelain` line-oriented output)

### Standard flags (preferred)
- `--dry-run` : show what would change
- `--verbose` : increase logging verbosity
- `--quiet` : reduce non-essential output
- `--force` : bypass prompts / destructive confirmation (must warn)
- `--json` or `--porcelain` : machine-friendly output (optional, documented)
- `--root` / `--system` / `--user` : explicit scope where relevant

### Standard verbs (preferred)
- `init` / `bootstrap`
- `apply` (reconcile desired state)
- `status`
- `doctor` (self-check + remediation suggestions)
- `logs` (routing to journald/podman logs)
- `update`
- `rollback`
- `remove` / `destroy` (must be explicit about what gets deleted)

---

## State & filesystem conventions

### XDG-first
Unless there’s a strong reason otherwise:

- Config: `${XDG_CONFIG_HOME:-$HOME/.config}/<tool>/`
- State:  `${XDG_STATE_HOME:-$HOME/.local/state}/<tool>/`
- Cache:  `${XDG_CACHE_HOME:-$HOME/.cache}/<tool>/`

### Suggested canonical layout
- `${STATE}/stacks/` : resolved stack state + last-apply records
- `${STATE}/objects/` : tracked podman objects (labels/IDs)
- `${STATE}/migrations/` : migration markers + schema version
- `${CONFIG}/stacks.d/` : user manifests
- `${CONFIG}/defaults/` : images, networks, service defaults

### Labels for podman objects
Everything created must be label-identifiable:
- `com.<org>.<tool>.managed=true`
- `com.<org>.<tool>.stack=<name>`
- `com.<org>.<tool>.role=workspace|service`
- `com.<org>.<tool>.version=<tool version>`

This enables safe reconciliation and clean removal.

---

## systemd / quadlet conventions

### Default: user scope
Prefer:
- `systemctl --user`
- `journalctl --user`
- user-level quadlet directories (when used)

### Logging
All services must have predictable logs:
- `tool logs --stack <name> [--service <svc>]`
- internally routes to `journalctl --user -u …` or `podman logs …`

### Service naming (suggested)
- `<tool>-<stack>-<service>.service`
- quadlet: `<tool>-<stack>-<service>.container`

### Networking default
- create stack-scoped podman networks
- bind exposed ports to `127.0.0.1` unless explicitly configured otherwise

---

## Security baseline

- Prefer **least privilege**:
  - no `--privileged`
  - avoid broad `--device`
  - avoid mounting `/` or `/var` or host sockets unless explicitly needed
- SELinux-aware patterns:
  - document when relabeling is required and why
  - prefer designs that don’t require fragile relabel hacks
- Secrets:
  - never committed
  - configurable via environment, files under `${CONFIG}`, or podman secret patterns if supported
  - `doctor` must warn if secrets appear in plain logs/config

---

## Testing & CI contract

We expect 3 layers:

1) **Static**
- `shellcheck` on all bash
- `shfmt` (if adopted)

2) **Unit-ish**
- `bats` (recommended) for:
  - argument parsing
  - idempotency rules
  - output contracts (`--help`, `--dry-run`, error messages)

3) **Integration**
A “minimal host simulation” flow that proves:
- rootless podman works
- distrobox workspace lifecycle works
- service install/start/stop via systemd user or quadlet works
- `status` and `doctor` behave consistently

### Contributor-friendly commands (recommended)
Provide a single entrypoint script or Makefile targets, e.g.:
- `./hack/lint`
- `./hack/test`
- `./hack/integ`
- `./hack/doctor`

(These can wrap the real tools; the goal is “one obvious way to run checks.”)

---

## Release & compatibility rules

- Semantic versioning is recommended (or document your scheme).
- Every release must document:
  - new features
  - breaking changes
  - migrations required
  - rollback steps
- The tool should support:
  - `update` (or `self-update` if applicable)
  - `rollback` to the previous known-good version *when feasible*
- State schema versions must be explicit and migratable.

---

## Stack manifests (recommended direction)

The “platform” should support declarative stacks.

Minimum manifest capabilities:
- stack name + version
- workspace definitions (distrobox image/name/mounts/env)
- service definitions (image/command/env/volumes/networks/ports)
- shared resources (volumes/networks)
- overrides (host-specific, user-specific)

The `apply` command should:
- validate manifest
- produce a “plan”
- reconcile (create/update/remove as needed)
- record last-applied state

The `status` command should:
- show desired vs actual deltas
- show health signals (service active, container running, last errors)

The `doctor` command should:
- check prerequisites (podman rootless, linger, distrobox availability)
- check SELinux mode hints
- detect common footguns
- propose concrete next steps

---

## Agent responsibilities (who owns what)

These are defined by `.github/agents/*.agent.md`. Use them as roles:

- **Platform Architect**: overall design, CLI contracts, state model, lifecycle semantics.
- **Bash Steward**: bash implementation quality, safety, consistency, tests.
- **Distrobox Specialist**: workspace flows, GUI/GPU/mount patterns, cross-distro gotchas.
- **Service Orchestrator**: systemd/quadlet + podman services layer, networks/volumes, observability.
- **QA & CI Engineer**: test strategy + CI wiring, minimal-host simulations.
- **Security Hardener**: least privilege, SELinux/supply chain, safe defaults.
- **Docs & UX Writer**: documentation, tutorials, troubleshooting.
- **Release & Packaging Engineer**: versioning, artifacts, upgrade/rollback.

### Collaboration rule
If a change touches multiple domains, the owning agent must request review from the relevant specialists.

---

## Contribution rules (PR checklist)

Every PR must include:
- what changed and why
- how to test locally
- any state/schema changes + migration notes
- updated docs for user-facing changes
- updated tests where feasible

Prefer small PRs that:
- implement one feature or fix
- include tests
- include docs

---

## Decision records (recommended)
For major design choices, add a short ADR:
- `docs/adr/NNNN-title.md`
Include context, decision, alternatives, consequences.

---

## “If it hurts, add a doctor check”
Whenever you learn a failure mode:
- add a `doctor` check or improve error messages
- add a regression test if possible
- document the fix in troubleshooting
