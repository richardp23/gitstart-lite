# Manual terminal checks

These checks need a real interactive terminal. The automated suite does not test `/dev/tty`, `stty`, or arrow-key input.

Do not add `expect`, `script`, or another PTY tool as a project dependency unless the project owner chooses to collect development dependencies.

## Environment

Run each check in:

1. Git Bash on Windows
2. Terminal on macOS when available

Build first:

```bash
bash build.sh
bash dist/gitstart.sh --plain
```

Also repeat selected checks with color enabled:

```bash
bash dist/gitstart.sh
```

## TTY and input

| ID | Check | Requirement IDs | Pass condition |
|----|-------|-----------------|----------------|
| MT-001 | Line input | FR-103 | Typed text is accepted for a Learn-mode command |
| MT-002 | Prompt visible | FR-100 | The `>` prompt appears in the terminal |
| MT-003 | Ctrl+C cleanup | FR-030, FR-031, NFR-100, NFR-101 | Cursor and echo return to normal after interrupt |
| MT-004 | Yes/no confirm | FR-053, FR-111 | `y` and `n` work in Assisted mode |
| MT-005 | Numbered menu | FR-075 | With `--plain`, directory selection works by number |
| MT-006 | Extra Enter | D-009 | After a typed command, an early Enter does not hang; pause still advances |

## Directory picker

| ID | Check | Requirement IDs | Pass condition |
|----|-------|-----------------|----------------|
| MT-010 | Arrow navigation | FR-064, FR-065 | Up and Down move the highlight on macOS Bash 3.2 and Git Bash |
| MT-011 | Enter opens directory | FR-065 | Enter on a `name/` row opens that folder |
| MT-012 | Select current | FR-062, FR-066 | Highlight `.  (use this folder)` and press Enter |
| MT-013 | Parent navigation | FR-063 | Highlight `..` or press Left to move up |
| MT-014 | Local search | FR-068–FR-070 | `/` filters the visible list |
| MT-015 | Hidden toggle | FR-072 | `.` shows or hides hidden directories |
| MT-016 | Manual path | FR-067, FR-073 | `m` accepts a path that contains spaces |
| MT-017 | Help and cancel | SRS §10.2 | `?` shows help. `q` or Esc cancels |
| MT-018 | Narrow terminal | NFR-022 | A narrow window remains usable |
| MT-019 | One frame | D-009 | Arrow movement does not stack duplicate lists |

## Mode and display

| ID | Check | Requirement IDs | Pass condition |
|----|-------|-----------------|----------------|
| MT-020 | Learn mode typing | FR-050, FR-051 | Student must type the teaching command |
| MT-021 | Assisted confirm | FR-052, FR-053 | Student confirms instead of typing |
| MT-022 | `--no-color` | FR-024, NFR-021 | Status labels remain without color |
| MT-023 | `--ascii` | FR-026, FR-043 | ASCII banner appears |
| MT-024 | No alternate screen | FR-047, FR-048 | Prior terminal output remains visible |

## Record results

Copy this block into a pull request or release note:

```text
Manual terminal checks
- Git Bash: pass / fail / not run
- macOS Terminal: pass / fail / not run
- Failed IDs:
- Notes:
```
