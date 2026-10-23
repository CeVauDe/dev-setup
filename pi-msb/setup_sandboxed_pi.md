# Running Pi in a Microsandbox micro-VM

This documents how to run [Pi](https://pi.dev) inside a [Microsandbox](https://docs.microsandbox.dev) micro-VM, with the OpenRouter API key pulled from [Proton Pass](https://proton.me/pass) at launch time.

Pi and its system dependencies are **pre-built into a local OCI image once**, so each launch boots straight into Pi instead of running `apt-get` and `npm install` every time.

This folder contains:

- `Dockerfile` — builds the `pi-msb` image; accepts an optional `PI_VERSION` build arg (default `1.4.0`).
- `build-msb.sh` — builds `pi-msb:latest` and loads it into the Microsandbox cache.
- `setup_sandboxed_pi.md` — this guide.

## What this sets up

- A locally built `pi-msb:latest` image containing `ca-certificates`, `git`, `ripgrep`, and Pi.
- The host project directory mounted at `/workspace` (read-write).
- Pi's agent directory (`config`, `auth`, and **sessions**) persisted to the host at `~/.pi/msb-agent`.
- The OpenRouter key resolved from Proton Pass on demand, never written to disk, shell history, or the command line.

## Prerequisites

- [`msb`](https://docs.microsandbox.dev) installed and working.
- Docker (or Podman) installed and working.
- [`pass-cli`](https://protonpass.github.io/pass-cli/) installed and logged in (`pass-cli login`).
- An OpenRouter API key stored in a Proton Pass item.

---

## 1. Create the persistent directories

```bash
mkdir -p ~/.pi/msb-agent
chmod 700 ~/.pi/msb-agent

mkdir -p ~/.config/pi
chmod 700 ~/.config/pi
```

## 2. Point Proton Pass at the secret

`pass-cli run` reads a dotenv file whose values are `pass://` references. Only the reference is stored on disk — never the key.

Find the reference:

```bash
pass-cli item list
pass-cli item get <item>     # an API key is usually the item's `password` field
```

Create the reference file (replace the `pass://` path):

```bash
cat > ~/.config/pi/msb.env <<'EOF'
OPENROUTER_API_KEY=pass://<vault>/<item>/<field>
EOF
chmod 600 ~/.config/pi/msb.env
```

Example value: `OPENROUTER_API_KEY=pass://Personal/OpenRouter/password`

## 3. Build and load the Pi image

A ready-to-build `Dockerfile` and a `build-msb.sh` script live next to this document. From this `pi-msb/` folder, run the script. It builds the image, exports it, loads it into the Microsandbox cache under the fixed `pi-msb:latest` tag, and prints `msb images -q`:

```bash
# run this from the folder containing this guide, the Dockerfile, and build-msb.sh
./build-msb.sh
```

The script accepts environment overrides; the defaults build `pi-msb:latest` with Pi `1.4.0`:

```bash
TAG=dev ./build-msb.sh               # load as pi-msb:dev instead
PI_VERSION=1.4.1 ./build-msb.sh      # build a different Pi version
IMAGE=my-pi TAG=latest ./build-msb.sh
```

Because the tag is always `latest`, the launcher never needs updating after a rebuild. If you prefer the manual steps, they are:

```bash
docker build -t pi-msb:latest .
docker save pi-msb:latest -o /tmp/pi-msb.tar
msb load --input /tmp/pi-msb.tar --tag pi-msb:latest
msb images -q
```

Use the default layered root. Do **not** use `--root-disk flat:...` with a locally loaded image: Microsandbox materializes the flat ext4 base by resolving the image manifest against a registry, which fails for an image that only exists in the local cache.

## 4. Install the launcher

Create `~/.local/bin/pi-msb`:

```bash
cat > ~/.local/bin/pi-msb <<'EOF'
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
  pi-msb:latest -- pi --model openrouter/deepseek/deepseek-v4.1-flash
EOF

chmod +x ~/.local/bin/pi-msb
```

Make sure `~/.local/bin` is on your `PATH` (add `export PATH="$HOME/.local/bin:$PATH"` to your shell rc if needed).

## 5. Run it

```bash
cd /path/to/my-project
pi-msb
```

Pi starts inside the sandbox with `/workspace` mapped to your project. Verify with `!pwd`.

## Updating Pi

Bump the version and rebuild, then reload it into the cache:

```bash
PI_VERSION=1.4.1 ./build-msb.sh
```

The `PI_VERSION` build arg replaces the default in the `Dockerfile`, and the new image is loaded over `pi-msb:latest`, so the launcher keeps working unchanged.

## Pick a model once

The key comes from the environment, so Pi has no default model on first run. Run `/model` inside Pi and choose an OpenRouter model; the choice is saved to `/config` and reused on later runs. Or make it deterministic by editing the launcher's last line:

```sh
    pi-msb:latest -- pi --model openrouter/<model-id>
```

## Continue a session

Sessions are persisted under `~/.pi/msb-agent/sessions/`, so they survive `--replace`. To resume:

- In the running TUI: `/resume` opens the session picker, `/new` starts fresh.
- To auto-continue the latest session for `/workspace`, change the launcher's last line to `pi-msb:latest -- pi --continue`.

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
- `--replace` recreates the sandbox on every run, but that is now cheap: no `apt-get` or `npm install` happen again because they are baked into `pi-msb:latest`.
- Delete `--replace` if you prefer to reuse the sandbox and attach with `msb exec -t pi-demo -- pi --continue`.
- The image is loaded locally with no registry involved. Because of that, the default layered root is used (`--root-disk 4G`); the `flat` root disk requires registry access to materialize its base.

## Troubleshooting

**`mount-dir source "...": No such file or directory`**
The host mount source does not exist. Create it (`mkdir -p ~/.pi/msb-agent`); the launcher also does this.

**`msb run` cannot find `pi-msb:latest`**
The image was not loaded. Re-run `./build-msb.sh`.

**`msb pull`, `msb create`, or `msb run` fails with `Not authorized` / a Docker Hub URL**
Something is trying to resolve `pi-msb:latest` against a registry. The image only exists in the local cache, so it must be found there:

1. Check `msb images -q`. If `pi-msb:latest` is not listed, reload it: `./build-msb.sh`.
2. Make sure the launcher uses `--root-disk 4G` (layered). `--root-disk flat:...` needs the registry manifest and will always try to pull.
3. Never run `msb pull pi-msb:latest` — it always resolves against a registry.

**Prefer a flat root anyway**
Push the image to a registry, then pull it with materialization:

```bash
docker tag pi-msb:latest ghcr.io/<you>/pi-msb:latest
docker push ghcr.io/<you>/pi-msb:latest
msb pull ghcr.io/<you>/pi-msb:latest --materialize flat
```

Then use `ghcr.io/<you>/pi-msb:latest` in the launcher and add `--root-disk flat:4G,clone=auto`.

**Install looks frozen / no progress output**
`pass-cli run` masks secrets by buffering stdout/stderr, which breaks progress rendering. This setup already runs `msb` outside the masking filter so output streams normally. For msb's own logging, check `msb run --help` for a verbose/log-level flag.

**`pass-cli` cannot resolve the reference**
Ensure you are logged in (`pass-cli login`) and that the `pass://` path matches an existing vault/item/field (`pass-cli item list`).

**Alternative without an env file**
If your `pass-cli` exposes an item-read command (check `pass-cli item --help`), you can skip `msb.env`:

```sh
OPENROUTER_API_KEY="$(pass-cli item get 'OpenRouter' --field password)"
export OPENROUTER_API_KEY
```
