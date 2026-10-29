# gentoo-overlay

Personal Gentoo overlay (`miikkak`), OpenRC-oriented.

| Package                                 | Description                                   |
| --------------------------------------- | --------------------------------------------- |
| `net-analyzer/beszel-agent`             | [Beszel](https://beszel.dev) monitoring agent |
| `net-analyzer/beszel-hub`               | Beszel hub (web UI and API)                   |
| `acct-user/beszel`, `acct-group/beszel` | Service user and group for the hub            |

## Usage

`/etc/portage/repos.conf/miikkak.conf`:

```ini
[miikkak]
location = /var/db/repos/miikkak
sync-type = git
sync-uri = https://github.com/miikkak/gentoo-overlay.git
auto-sync = yes
```

The packages are keyworded `amd64`/`arm64` (not `~arch`): this is a personal overlay, upstream releases are followed
through reviewed bump PRs, and only packages that are meant to be installed live here. No `package.accept_keywords`
entries are needed.

Then `emerge --sync miikkak` and `emerge -av net-analyzer/beszel-agent`.

The init scripts keep the service names `beszel` (hub) and `beszel-agent`. The Go binaries are compiled by Portage on
your machine, so `GOAMD64`, `GOARM64` and similar variables from `make.conf` apply.

## How the Beszel packages are built

Upstream ships no source-form assets that Portage can use offline, so each release has two extra distfiles, built by
[`scripts/beszel-build-distfiles.sh`](scripts/beszel-build-distfiles.sh) and attached to the overlay release
`beszel-<version>`:

- `beszel-<version>-deps.tar.xz`: the `go mod vendor` tree (agent and hub).
- `beszel-<version>-web.tar.xz`: the built web UI (`internal/site/dist`), which is architecture-independent text that
  upstream embeds in the hub binary. Hub only.

Only the Go compile is done by Portage; nothing else is prebuilt. The `Manifest` pins the hashes of both tarballs.

## Version bumps

`.github/workflows/beszel-bump.yml` runs daily (and on demand). When upstream has a newer release it builds and uploads
the distfiles, renames the ebuilds, regenerates both Manifests and opens a draft PR. Locally:

```bash
scripts/beszel-bump.sh [--no-upload] [version]
```

An existing `beszel-<version>` release is reused rather than rebuilt, so published hashes never change.
