# Running Pi in a Microsandbox micro-VM

This documents how to run [Pi](https://pi.dev) inside a [Microsandbox](https://docs.microsandbox.dev) micro-VM, with the OpenRouter API key pulled from [Proton Pass](https://proton.me/pass) at launch time.

## What this sets up

- Pi installed globally in an isolated `node:24-bookworm-slim` micro-VM via npm.
- The host project directory mounted at `/workspace` (read-write).
- Pi's agent directory (`config`, `auth`, and **sessions**) persisted to the host at `~/.pi/msb-agent`.
- The OpenRouter key resolved from Proton Pass on demand, never written to disk, shell history, or the command line.

## Prerequisites

- [`msb`](https://docs.microsandbox.dev) installed and working.
- [`pass-cli`](https://protonpass.github.io/pass-cli/) installed and logged in (`pass-cli login`).
- An OpenRouter API key stored in a Proton Pass item.

## 1. Create the persistent directories

`msb` requires mount source directories to exist before starting:

```bash
mkdir -p ~/.pi/msb-agent
chmod 700 ~/.pi/msb-agent

mkdir -p ~/.config/pi
chmod 700 ~/.config/pi
```

## 2. Point Proton Pass at the secret

`pass-cli run` reads a dotenv file whose values are `pass://` references. Only the reference is stored on disk — never the key.

Find the reference first:

```bash
pass-cli item list
pass-cli item get <item>     # an API key is usually the item's `password` field
```

Then create the reference file:

```bash
cat > ~/.config/pi/msb.env <<'EOF'
OPENROUTER_API_KEY=pass://<vault>/<item>/<field>
EOF
chmod 600 ~/.config/pi/msb.env
```

Example: `OPENROUTER_API_KEY=pass://Personal/OpenRouter/password`

## 3. Install the launcher

Create `~/.local/bin/pi-msb`:

```sh
#!/bin/sh
set -eu

mkdir -p "$HOME/.pi/msb-agent"

# Resolve the key via Proton Pass. `--no-masking` is required so the command
# substitution captures the real value instead of the redacted one.
OPENROUTER_API_KEY="$(pass-cli run --no-masking \
  --env-file "$HOME/.config/pi/msb.env" -- \
  sh -c 'printf %s "$OPENROUTER_API_KEY"')"
export OPENROUTER_API_KEY
[ -n "$OPENROUTER_API_KEY" ] || { echo "No OpenRouter key from pass-cli" >&2; exit 1; }

# Run Pi directly (outside pass-cli's masking filter) so progress logs stream.
exec msb run -t --name pi-demo --replace \
  --cpus 2 --memory 2G --root-disk 4G \
  --mount-dir "$PWD:/workspace:rw" \
  --mount-dir "$HOME/.pi/msb-agent:/config" \
  --workdir /workspace \
  -e OPENROUTER_API_KEY \
  -e PI_CODING_AGENT_DIR=/config \
  node:24-bookworm-slim -- sh -lc '
    apt-get update &&
    apt-get install -y --no-install-recommends ca-certificates git ripgrep &&
    npm install -g --ignore-scripts @earendil-works/pi-coding-agent@1.1.0 &&
    exec pi
  '
```

Make it executable:

```bash
chmod +x ~/.local/bin/pi-msb
```

## 4. Run it

```bash
cd /path/to/my-project
pi-msb
```

Pi starts inside the sandbox with `/workspace` mapped to your project. Verify with `!pwd`.

## Pick a model once

The key comes from the environment, so Pi has no default model on first run. Run `/model` inside Pi and choose an OpenRouter model; the choice is saved to `/config` and reused on later runs. Or make it deterministic by editing the launcher's last line:

```sh
    exec pi --model openrouter/<model-id>
```

## Continue a session

Sessions are persisted under `~/.pi/msb-agent/sessions/`, so they survive `--replace`. To resume:

- In the running TUI: `/resume` opens the session picker, `/new` starts fresh.
- To auto-continue the latest session for `/workspace`, change the launcher to `exec pi --continue`.

## How the secret flows

```
Proton Pass (unlocked)
  -> pass-cli run resolves pass:// reference
  -> OPENROUTER_API_KEY in the launcher process env
  -> msb forwards it by name (-e OPENROUTER_API_KEY)
  -> Pi reads it from the container environment
```

The key is never in the image, the command line, `ps`, shell history, or `auth.json`. Do **not** run `/login` for OpenRouter inside Pi, or a copy will be written to `~/.pi/msb-agent/auth.json` on the host.

## Security notes

- `~/.config/pi/msb.env` contains only a `pass://` reference; it is useless without your unlocked vault. Keep it `0600`.
- `~/.pi/msb-agent` can contain credentials and session transcripts. Keep it `0700` and out of version control.
- Keep the launcher `0700`; avoid `set -x`.
- Give the OpenRouter key a spend limit and rotate it if a session transcript is ever shared.
- `--replace` recreates the sandbox on every run, so `apt-get` and `npm install` run each time. Drop `--replace` to reuse the sandbox and instead attach with `msb exec pi-demo -- pi --continue` (confirm the exact command with `msb --help`).

## Troubleshooting

**`mount-dir source "...": No such file or directory`**
The host mount source does not exist. Create it (`mkdir -p ~/.pi/msb-agent`); the launcher also does this.

**Install looks frozen / no progress output**
`pass-cli run` masks secrets by buffering stdout/stderr, which breaks `apt`/`npm` progress rendering. This setup already runs `msb` outside the masking filter so output streams normally. For msb's own logging, check `msb run --help` for a verbose/log-level flag.

**`pass-cli` cannot resolve the reference**
Ensure you are logged in (`pass-cli login`) and that the `pass://` path matches an existing vault/item/field (`pass-cli item list`).

**Alternative without an env file**
If your `pass-cli` exposes an item-read command (check `pass-cli item --help`), you can skip `msb.env`:

```sh
OPENROUTER_API_KEY="$(pass-cli item get 'OpenRouter' --field password)"
export OPENROUTER_API_KEY
```
