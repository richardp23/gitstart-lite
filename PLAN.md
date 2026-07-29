# GitStart Lite Implementation Plan

Version: 0.3.1
Date: 2026-07-28  
Status: Active

## 1. Repository inspection

Current project documents:

- `SRS.md` — product requirements
- `AGENTS.md` — architecture, decisions, and MVP tracker
- `CURSOR.md` — agent work method
- `PLAN.md` — this phase plan

Missing items for the MVP are tracked in `AGENTS.md` §1.

No specification contradiction was found. Implementation follows `SRS.md`, then `AGENTS.md`, then `CURSOR.md`.

## 2. Phase map

| Phase | Goal | Primary requirement IDs |
|-------|------|-------------------------|
| 1 | Inspect and plan | Traceability rule (SRS §17) |
| 2 | Foundation | FR-020–FR-031, FR-040–FR-048, FR-050–FR-055, FR-100–FR-113, FR-120–FR-130, NFR-020–NFR-025, NFR-040–NFR-045, NFR-080–NFR-086, NFR-100–NFR-104, NFR-120–NFR-125 |
| 3 | Directory picker | FR-060–FR-088, NFR-060–NFR-063 |
| 4 | Git lessons | FR-140–FR-184, FR-200–FR-211, FR-220–FR-227, FR-240–FR-248, FR-260–FR-264, FR-280–FR-286, FR-300–FR-310 |
| 5 | Distribution | FR-001–FR-012, NFR-084–NFR-085 |
| 6 | Tests | NFR-122, SRS §13 acceptance criteria |

## 3. Source module plan

Build order and module status live in `AGENTS.md` §1 and §3.

## 4. Task breakdown by phase

### Phase 2: Foundation

1. Create header, constants, terminal, text, and input modules.
2. Create Git execution and Git state modules.
3. Create safety and lesson-engine modules.
4. Create main entry with argument parsing and menu.
5. Add glossary and diagnostic-code list.

### Phase 3: Directory picker

1. Implement directory enumeration without `ls` parsing.
2. Implement keyboard navigation and plain numbered fallback.
3. Implement fuzzy filter, preview, manual path, hidden toggle.
4. Implement dangerous-directory warnings and `cd` teaching.

### Phase 4: Lessons

1. Implement initialize lesson end-to-end for local commit.
2. Implement remote add and first push with safety stops.
3. Implement commit-and-push for existing repositories.
4. Implement fast-forward update lesson.
5. Implement fork sync lesson.
6. Implement diagnosis lesson.
7. Implement offline detection and resume-from-state behavior.

### Phase 5: Distribution

1. Create `build.sh` and optional `Makefile`.
2. Produce `dist/gitstart.sh` and SHA-256 file.
3. Create `site/run`, Pages index, offline docs, `.nojekyll`.
4. Create GitHub Actions workflows for test and Pages.
5. Create `README.md` and `LICENSE`.

### Phase 6: Tests

1. Add unit tests for fuzzy, sanitize, classify, secrets, normalize.
2. Add integration tests with temporary repositories.
3. Add interrupt cleanup and mode tests.
4. Run `bash -n`, test suite, and ShellCheck when available.

## 5. Decisions

Design decisions are recorded in `AGENTS.md` §9.

## 6. Deferred work

Future lessons and platform features remain in `SRS.md` §14 and §15. Keep them disabled in the MVP.

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
- [x] Automated tests pass
- [ ] ShellCheck reviewed when available
- [ ] STE text reviewed for user-facing strings
- [x] `AGENTS.md` tracker updated
- [x] Completion report delivered
