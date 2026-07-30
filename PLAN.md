# GitStart Lite Implementation Plan

Version: 0.5.0
Date: 2026-07-30
Status: Active

## 1. Repository inspection

Current application version: `0.5.0`
(`GS_APP_VERSION` in `src/10_constants.sh`). Phase 8 teaching-flow and
reliability pass complete. Version follows D-016 (minor bump for
student-facing teaching-flow change while major stays `0`).

Current project documents:

- `SRS.md` — product requirements
- `AGENTS.md` — architecture, decisions, and MVP tracker
- `CURSOR.md` — agent work method
- `PLAN.md` — this phase plan
- `GLOSSARY.md` — approved terms
- `README.md` — student and maintainer entry

MVP modules in `AGENTS.md` §1 are Done. Phase 7 classroom hardening is
Done. This plan covers Phase 8: teaching-flow and reliability pass.

Do not rewrite Git history. Do not create `CODE.md`.

No specification contradiction blocks the work. SRS updates for conditional
`cd`, structured help, and related items are listed in §5.

## 2. Phase map

| Phase | Goal | Primary requirement IDs |
|-------|------|-------------------------|
| 1–6 | Foundation through tests | See prior plans |
| 7 | Classroom hardening | Done (0.4.0) |
| 8 | Teaching-flow and reliability | See task table below |

## 3. Source module plan

Build order and module status live in `AGENTS.md` §1 and §3.

## 4. Phase 8 task breakdown

Status values: `Not started` | `In progress` | `Done` | `Blocked`

| ID | Task | Requirement IDs | Decision / note | Status |
|----|------|-----------------|-----------------|--------|
| P8-01 | Update plan and product decisions | SRS §17 | D-019 (conditional cd) | Done |
| P8-02 | Record `GS_SESSION_START_DIR` at startup | FR-116* | Resolved path; immutable | Done |
| P8-03 | Conditional cd teaching; remove no-op runner | FR-087*, FR-105–FR-107, D-019 | Same-dir skip; different-dir teach | Done |
| P8-04 | Safe cd command formatter (`~/` unquoted) | FR-089*, FR-073, FR-088 | `printf %q` after HOME strip | Done |
| P8-05 | Exact/safe cd validation; child Bash test | FR-104–FR-105, NFR-080 | No eval; no weak matcher | Done |
| P8-06 | pwd as verify step after folder select | FR-160–FR-162 | Match selected path | Done |
| P8-07 | Improve ls explanation; detailed help for depth | FR-101–FR-102, FR-110* | Keep normal screen short | Done |
| P8-08 | Conceptual stage board + substeps | FR-115*, D-011, D-013 | Reusable engine | Done |
| P8-09 | Structured GOAL/CONCEPT/TYPE/LOOK FOR | FR-114*, FR-100–FR-102 | Plain and no-color usable | Done |
| P8-10 | Detailed `?` help callback | FR-110*, FR-111 | Return to same unfinished step | Done |
| P8-11 | Improve explanations in all active lessons | FR-101–FR-102 | Initialize, commit/push, update, fork, diagnose | Done |
| P8-12 | Show staged file names after `git add` | FR-171 | Status substep; names not count only | Done |
| P8-13 | Child-shell note on completion when dirs differ | FR-118*, D-019 | Short; same formatter | Done |
| P8-14 | `GIT_TERMINAL_PROMPT=0` on network Git | FR-280–FR-282, FR-288* | Auth class; no retry | Done |
| P8-15 | Remote-reference preflight (`ls-remote`) | FR-181, FR-182 | Empty continue; refs stop | Done |
| P8-16 | Remove silent `v0.1.0` bootstrap fallback | FR-004, FR-013* | Fail clear; clean temp | Done |
| P8-17 | Picker refresh dirty flag | FR-060–FR-075, NFR-060–NFR-061 | Up/Down no re-enumerate | Done |
| P8-18 | Refine remote permission classification | FR-287 | Conservative AUTH vs PERMISSION | Done |
| P8-19 | Remove `eval` from bootstrap test stub | NFR-080 | while/shift parse | Done |
| P8-20 | Tests for Phase 8 acceptance criteria | NFR-122, SRS §13 | No new dependency | Done |
| P8-21 | Manual TTY checklist updates | D-017 | Conditional cd; detailed help | Done |
| P8-22 | Version bump to 0.5.0 + release artifacts | D-016 | After implementation and tests | Done |

\* SRS text updates in §5.

### Locked behavior (do not redesign)

- Directory picker student experience (keys, preview, numbered fallback).
- Lesson board screen redraws (D-011).
- Mandatory pause before a finished stage leaves the screen (D-013).
- Interactive TTY checks stay manual (D-017).
- Public site stays one small static page (D-018). Do not redesign the site.
- Full future product may use Go, larger TUI, GUI, or website (D-018).

### Out of scope for Phase 8

Go, Python/Node runtimes, JS frameworks, GUI, integrated terminal,
recursive filesystem index, telemetry, plugins, new student dependencies,
required new developer dependencies, `expect`/PTY automation, website
redesign.

## 5. SRS updates required for Phase 8

| ID | Change |
|----|--------|
| FR-087 | Teach `cd` only when the selected directory differs from the current application working directory. When they match, explain that `cd` is not necessary and continue to verification. Do not decide from `GS_SESSION_START_DIR` alone. |
| FR-110 | `?` shall open a detailed help screen for the current command or substep, then return to the same unfinished step without running the command. |
| FR-114 | Normal command screens shall use short GOAL, CONCEPT, TYPE, and LOOK FOR sections when teaching data is available. |
| FR-115 | The lesson board shall support conceptual stages with current substeps. Completed stages stay visible. Mandatory pause applies when leaving a finished stage. |
| FR-116 | At startup the application shall record the resolved working directory once (`GS_SESSION_START_DIR`) and shall not change that value during the session. |
| FR-117 | Displayed `cd` commands shall be valid Bash forms: `cd -- ~` for HOME; `~/` plus escaped remainder under HOME; escaped absolute path otherwise. Reject unsupported control characters. |
| FR-118 | When the lesson used a directory other than the session start directory, the completion screen shall explain the child-shell limitation and show a safe return `cd` command. |
| FR-013 | When `stable.txt` cannot be downloaded, the bootstrap shall fail with a clear error and shall not fall back to an obsolete version. |
| FR-288 | Network Git operations that can prompt for credentials shall set `GIT_TERMINAL_PROMPT=0` in the Git execution layer. |

Also refine FR-287 classifier wording for AUTHENTICATION versus PERMISSION versus UNKNOWN (conservative).

## 6. Deferred work

Future lessons and platform features remain in `SRS.md` §14 and §15.
Keep them disabled in the MVP. Full-product Go/TUI/GUI/website work stays
out of Lite (D-018).

## 7. Build and test commands

```bash
git diff --check
bash build.sh
bash -n dist/gitstart.sh
bash tests/run_tests.sh
shellcheck dist/gitstart.sh   # when available
```

Verify `dist/gitstart.sh.sha256` and `site/releases/v0.5.0/` checksums after
the version bump.

## 8. Completion checklist

- [x] Phase 8 teaching-flow and reliability tasks complete
- [x] Automated tests pass (local; CI matrix Ubuntu/macOS/Windows)
- [x] Manual TTY checks documented (conditional cd, detailed help)
- [x] STE text reviewed for new user-facing strings
- [x] `AGENTS.md` tracker and D-019 updated
- [x] Version 0.5.0 and release artifacts aligned (D-016)
- [x] Completion report delivered
- [x] History not rewritten
- [x] `CODE.md` not created
- [x] No new required dependency
