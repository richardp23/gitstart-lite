# GitStart Lite

GitStart Lite is a Bash teaching tool for local Git workflows. A student needs Bash and Git only.

## Build

```bash
bash build.sh
```

Or use Make:

```bash
make build
make test
```

The release file is `dist/gitstart.sh`.

## Run locally

After a build:

```bash
bash dist/gitstart.sh
```

You can also run the built file as `bash gitstart.sh` after you copy it.

Useful options:

- `--help` — show help text
- `--version` — show version
- `--plain` — plain text output without color art

## Launch online

```bash
bash -c "$(curl -fsSL https://richardp23.github.io/gitstart-lite/run)"
```

The bootstrap script downloads a versioned release, verifies SHA-256 when a checksum tool exists, and starts GitStart.

## Download the release

Download `releases/v0.1.1/gitstart.sh` and `gitstart.sh.sha256` from the site. Verify the checksum. Then run:

```bash
bash gitstart.sh
```

GitStart runs on your machine and does not send telemetry. See `site/docs/privacy.html` and `site/docs/offline.html`.

## Versioning

GitStart Lite uses Semantic Versioning (`MAJOR.MINOR.PATCH`) and
stays on major `0` while it remains a transitional Bash teaching
tool. See D-016 in [`AGENTS.md`](AGENTS.md).

## Glossary

Approved product terms are defined in [`GLOSSARY.md`](GLOSSARY.md).

## License

MIT. See `LICENSE`.

## Tests

Automated tests:

```bash
make test
```

Or:

```bash
bash tests/run_tests.sh
```

The automated suite uses stubbed input for lesson logic. It does not open `/dev/tty`. It does not test arrow keys or `stty`.

Interactive terminal checks are manual. See `tests/manual/README.md`.

ShellCheck is optional. Run `make shellcheck` when ShellCheck is installed. Students do not need ShellCheck.
