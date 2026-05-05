# contextlm

A tool for packaging repository source files into a single XML context document,
suitable for pasting into an LLM prompt.

Each selected file is wrapped in a tagged block:

```xml
<contextlm path="src/Main.hs">
...file contents...
</contextlm>
```

## Installing and running

The project ships a `flake.nix` built on
[haskell.nix](https://github.com/input-output-hk/haskell.nix).

### Prerequisites

Nix with flakes enabled. Add to `~/.config/nix/nix.conf` (or `/etc/nix/nix.conf`):

```
experimental-features = nix-command flakes
allow-import-from-derivation = true
```

The flake uses the IOG binary cache (`cache.iog.io`) to avoid rebuilding GHC. If
your Nix instance treats the per-flake `nixConfig` as untrusted, also add:

```
trusted-substituters = https://cache.iog.io
trusted-public-keys  = hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=
```

### Run without installing

```sh
nix run github:adithyaov/contextlm -- --action serve
```

Or from a local checkout:

```sh
nix run . -- --action serve
nix run . -- --action create-context --dir ./myproject --include "**/*.hs"
```

### Development shell

```sh
nix develop
```

Drops you into a shell with GHC, `cabal`, HLS, `hlint`, and `git` on
`PATH`. From there use `cabal` as normal:

```sh
cabal build
cabal run contextlm -- --action serve
```

### Build the binary

```sh
nix build
./result/bin/contextlm --action serve
```

## Modes

### `create-context` — CLI output

Recursively walks a directory, filters files by glob rules, and writes the
context document to stdout.

```
contextlm --action create-context \
          --dir <directory> \
          [--include <glob> | --exclude <glob>] ...
```

Filter rules are applied in order, last match wins. Files are excluded by
default when any include rule is present.

**Examples:**

```sh
# All Haskell files
contextlm --action create-context --dir ./myproject --include "**/*.hs" > context.xml

# Everything except build artifacts
contextlm --action create-context --dir ./myproject --exclude "dist-newstyle/**" > context.xml
```

---

### `clone` — Clone a repository locally

Clones a git repository into the specified directory.

```
contextlm --action clone \
          --url <git-url> \
          --dir <destination>
```

---

### `serve` — Web UI

Starts a local HTTP server with a browser UI for interactively selecting files
and downloading context.

```
contextlm --action serve \
          [--port <port>]           (default: 3000)
          [--repos-dir <directory>] (default: repos)
```

Then open `http://localhost:3000` in your browser.

The server clones repositories into `--repos-dir` on demand. If the destination
already exists, the clone step is skipped.
