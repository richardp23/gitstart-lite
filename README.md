# GitStart Lite

GitStart Lite teaches local Git workflows by guiding you through real Git commands.

## Launch

```bash
bash -c "$(curl -fsSL https://richardp23.github.io/gitstart-lite/run)"
```

## Requirements

You need Bash and Git only.

## What you learn

- Choose a project folder
- Initialize a repository
- Stage files and create a commit
- Connect an HTTPS remote and push
- Update a clone and sync a fork
- Diagnose common Git states

## Local execution and privacy

GitStart runs on your machine. It does not send telemetry. See
[`site/docs/privacy.html`](site/docs/privacy.html).

## Troubleshooting and direct download

If the one-line launch fails on Windows Git Bash with a certificate
revocation error, see
[`site/docs/troubleshooting.html`](site/docs/troubleshooting.html).

Download `releases/v0.5.0/gitstart.sh` and `gitstart.sh.sha256` from the
site. Verify the checksum. Then run:

```bash
bash gitstart.sh
```

More download help: [`site/docs/offline.html`](site/docs/offline.html).

## Developer build and tests

```bash
bash build.sh
bash dist/gitstart.sh
```

Or use Make:

```bash
make build
make test
```

Useful options:

- `--help` — show help text
- `--version` — show version
- `--plain` — plain text output without color art

Automated tests:

```bash
bash tests/run_tests.sh
```

The automated suite uses stubbed input for lesson logic. It does not open
`/dev/tty`. It does not test arrow keys or `stty`.

Interactive terminal checks are manual. See
[`tests/manual/README.md`](tests/manual/README.md).

ShellCheck is optional. Run `make shellcheck` when ShellCheck is installed.
Students do not need ShellCheck.

Versioning follows D-016 in [`AGENTS.md`](AGENTS.md). Approved terms are in
[`GLOSSARY.md`](GLOSSARY.md).

## License

MIT. See `LICENSE`.
