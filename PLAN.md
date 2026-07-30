# GitStart Lite Implementation Plan

Version: 0.4.0
Date: 2026-07-29
Status: Active

## 1. Repository inspection

Current HEAD on `main` (at plan time): application version `0.3.1` at plan start; release target `0.4.0`
(`GS_APP_VERSION` in `src/10_constants.sh`).

Current project documents:

- `SRS.md` — product requirements
- `AGENTS.md` — architecture, decisions, and MVP tracker
- `CURSOR.md` — agent work method
- `PLAN.md` — this phase plan
- `GLOSSARY.md` — approved terms
- `README.md` — student and maintainer entry

MVP modules in `AGENTS.md` §1 are Done. This plan covers Phase 7:
classroom hardening and efficiency. Do not rewrite Git history.

No specification contradiction blocks the work. Small SRS updates are
required for identity scope and remote-error classification (see §5).

## 2. Phase map

| Phase | Goal | Primary requirement IDs |
|-------|------|-------------------------|
| 1 | Inspect and plan | Traceability rule (SRS §17) |
| 2 | Foundation | FR-020–FR-031, FR-040–FR-048, FR-050–FR-055, FR-100–FR-113, FR-120–FR-130, NFR-020–NFR-025, NFR-040–NFR-045, NFR-080–NFR-086, NFR-100–NFR-104, NFR-120–NFR-125 |
| 3 | Directory picker | FR-060–FR-088, NFR-060–NFR-063 |
| 4 | Git lessons | FR-140–FR-184, FR-200–FR-211, FR-220–FR-227, FR-240–FR-248, FR-260–FR-264, FR-280–FR-286, FR-300–FR-310 |
| 5 | Distribution | FR-001–FR-012, NFR-084–NFR-085 |
| 6 | Tests | NFR-122, SRS §13 acceptance criteria |
| 7 | Classroom hardening | See task table below |

## 3. Source module plan

Build order and module status live in `AGENTS.md` §1 and §3.

## 4. Phase 7 task breakdown

Status values: `Not started` | `In progress` | `Done` | `Blocked`

| ID | Task | Requirement IDs | Decision / note | Status |
|----|------|-----------------|-----------------|--------|
| P7-01 | Update plan and product decisions | SRS §17 | D-011, D-013, D-017, D-018 | Done |
| P7-02 | Bootstrap temp-dir cleanup without `exec` | FR-005, FR-008, FR-009, D-005 | Preserve exit status; EXIT trap runs | Done |
| P7-03 | Windows TLS fallback order + stderr warnings | FR-004, FR-006, GS-BOOT-* | Normal TLS before `--ssl-no-revoke` | Done |
| P7-04 | Identity check after `git init` in selected repo | FR-130*, FR-164–FR-166, D-008 | Remove pending-identity state | Done |
| P7-05 | Conservative remote Git error classifier | FR-283–FR-287*, FR-280–FR-282 | Categories; UNKNOWN fallback | Done |
| P7-06 | Picker indexed records; no list-from-start scans | FR-060–FR-075, NFR-060 | Bash 3.2 arrays only | Done |
| P7-07 | Compact adaptive picker preview + cache | FR-080–FR-085, D-009 | Wide/medium/narrow; key on narrow | Done |
| P7-08 | Fuzzy matcher fewer external commands | FR-068–FR-070 | Bash substring; one lowercase pass | Done |
| P7-09 | Targeted Git state helpers for lessons | FR-120–FR-128 | Keep full inspect for Diagnose | Done |
| P7-10 | Windows CI matrix (Git Bash) | NFR-122, SRS §6.1 | Noninteractive only | Done |
| P7-11 | Manual TTY release gate docs | D-017, NFR-122 | No new PTY dependency | Done |
| P7-12 | Student-first README | NFR-125, D-015 | Launch before developer build | Done |
| P7-13 | Static site opening copy | FR-012, D-018 | No framework or scripts | Done |
| P7-14 | Version bump per D-016 + release artifacts | D-016 | One bump after implementation | Done |

\* SRS text updates in §5.

### Locked behavior (do not redesign)

- Lesson board screen redraws (D-011).
- Mandatory pause before a finished stage leaves the screen (D-013).
- Interactive TTY checks stay manual (D-017).
- Public site stays one small static page (D-018).
- Full future product may use Go, larger TUI, GUI, or website (D-018).

### Out of scope for Phase 7

Go, Python/Node runtimes, JS frameworks, GUI, integrated terminal,
recursive filesystem index, telemetry, plugins, new student dependencies,
required new developer dependencies, `expect`/PTY automation.

## 5. SRS updates required for Phase 7

| ID | Change |
|----|--------|
| FR-130 | Check effective Git author identity in the selected repository before the first commit. Prefer local config (D-008). Do not treat launch-directory local config as sufficient for another repository. |
| FR-287 | Classify failed remote Git operations conservatively (NETWORK, TLS, AUTHENTICATION, PERMISSION, REMOTE_NOT_FOUND, NON_FAST_FORWARD, DIVERGED, UNKNOWN). Do not label every failure as offline. |

## 6. Deferred work

Future lessons and platform features remain in `SRS.md` §14 and §15.
Keep them disabled in the MVP.

## 7. Build and test commands

```bash
bash build.sh
bash -n dist/gitstart.sh
bash tests/run_tests.sh
shellcheck dist/gitstart.sh   # when available
bash gitstart.sh              # local run after build copy or via dist
```

## 8. Completion checklist

- [x] All MVP lessons implemented
- [x] One-file release built
- [x] Bootstrap available at `site/run`
- [x] Phase 7 classroom hardening complete
- [x] Automated tests pass on Ubuntu, macOS, and Windows CI (local Windows Git Bash verified; Ubuntu/macOS via CI matrix)
- [x] ShellCheck reviewed when available
- [x] STE text reviewed for new user-facing strings
- [x] `AGENTS.md` tracker and decisions updated
- [x] Version bump and release artifacts aligned (D-016)
- [x] Completion report delivered
- [x] History not rewritten
