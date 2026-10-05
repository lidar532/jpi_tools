# jpi_tools

Install pi, tmux, and other command line tools in a Jupyter session.

This repo also contains a helper that bootstraps a fresh **Pi** + **Herdr**
installation and configures it using the `.pi` directory stored here.

## Contents

```
jpi_tools/
├── Jpi_tools.ipynb      # Colab notebook for Jupyter sessions
├── LICENSE
├── README.md
├── setup_pi.sh          # bootstrap Pi/Herdr + apply repo .pi config
└── .pi/
    └── agent/
        ├── models.json              # Ollama.com provider + model definitions
        ├── models-store.json
        ├── settings.json
        └── extensions/
            └── herdr-agent-state.ts
```

## Usage

### 1. Clone the repository

```bash
git clone https://github.com/lidar532/jpi_tools.git
cd jpi_tools
```

### 2. Export your Ollama.com API key (optional, required for hosted models)

```bash
export OLLAMA_API_KEY=...
```

### 3. Run the setup script

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

## Providers

`.pi/agent/models.json` defines one provider, **Ollama.com**, pointing at the
online endpoint `https://ollama.com/v1` (not localhost), with 17 hosted models.
The provider id is `ollama.com` and it is authenticated through the
`OLLAMA_API_KEY` environment variable.

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
