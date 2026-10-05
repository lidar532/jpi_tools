# jpi_tools

Helper to bootstrap a fresh **Pi** + **Herdr** installation and configure it
using the `.pi` directory stored in this repository.

## Usage

```bash
./setup_pi.sh          # install and configure
./setup_pi.sh -d       # dry run: print commands only
./setup_pi.sh --help   # usage
```

The script:

1. Installs the latest Pi from `https://pi.dev`.
2. Installs Herdr.
3. Backs up any existing `~/.pi` to `~/.pi.bak.<timestamp>`.
4. Copies this repository's `.pi` into `~/.pi`.
5. Installs every model listed in `.pi/agent/models.json`.
6. Runs `pi config apply`.

## Repository layout

```
jpi_tools/
├── README.md
├── setup_pi.sh
└── .pi/
    └── agent/
        ├── models.json              # providers + model definitions
        ├── models-store.json
        ├── settings.json
        └── extensions/
            └── herdr-agent-state.ts
```

## Secrets

**No API keys are stored in this repository.**

- `~/.pi/agent/auth.json` is excluded and git-ignored.
- `~/.pi/agent/sessions/` is excluded and git-ignored (transcripts can
  contain pasted secrets).
- `~/.pi/agent/install/` and `~/.pi/agent/bin/` are excluded: they are the
  installed Pi program and platform-specific binaries, and `setup_pi.sh`
  installs them fresh.

`models.json` only references credentials via environment variables, e.g.
`"apiKey": "$OLLAMA_API_KEY"`. Set the relevant variables (or run Pi's auth
flow) on the target machine before running the script.

The included `.gitignore` prevents accidentally committing key material.
