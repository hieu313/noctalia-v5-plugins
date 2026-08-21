# Noctalia plugins

<p align="center">
  <img src="https://assets.noctalia.dev/noctalia-logo.svg?v=2" alt="Noctalia Logo" style="width: 192px" />
</p>

---

A personal plugin source for [Noctalia](https://github.com/noctalia-dev/noctalia) v5. Add it as a
source and the plugins below show up in the shell's plugin store alongside the official and
community ones.

```sh
noctalia msg plugins source add hieu313 git https://github.com/hieu313/noctalia-v5-plugins
noctalia msg plugins enable hieunm3103/modern-clock
```

## Plugins

| Plugin | ID | What it does |
| --- | --- | --- |
| [Modern Clock](modern-clock/) | `hieunm3103/modern-clock` | Three-line desktop clock — weekday, date, time — with per-line format, size, colour and font. |

## Layout

Each plugin is one top-level directory, named after the part of its id that follows the `/`:

```
modern-clock/
  plugin.toml             # manifest: id, metadata, entries, settings
  widget.luau             # entry scripts
  README.md               # the plugin's page
  thumbnail.webp          # 960x540 card image
  translations/
    en.json               # every label_key / description_key the manifest references
```

`catalog.toml` at the repo root indexes every plugin — it is what the shell reads to list this
source, so unlike upstream **it is committed here**. It is generated, never hand-edited:

```sh
python3 .github/workflows/scripts/update-catalog.py
```

`.github/workflows/on-push.yml` re-runs that on every push to `main` and commits the result, so a
forgotten regeneration fixes itself. Everything else under `.github/` is upstream's community
automation, left in place but gated on the upstream repository name, so none of it fires here.

## Developing

Point a `path` source at your checkout instead of the git one and the shell reads it straight off
disk:

```sh
noctalia msg plugins source add dev path ~/Workspace/projects/noctalia-v5-plugins
```

`.luau` edits hot-reload. A `plugin.toml` edit — or adding a plugin — needs the catalog rebuilt and
the config reloaded:

```sh
python3 .github/workflows/scripts/update-catalog.py && noctalia msg config-reload
```

Before pushing, run the same validator CI uses. It checks the manifest schema, translation keys,
thumbnail dimensions and README structure:

```sh
python3 .github/workflows/scripts/validate-plugins.py
```

For autocomplete and typo diagnostics, fetch the API type definitions into the repo root, where
they are gitignored:

```sh
curl -O https://raw.githubusercontent.com/noctalia-dev/official-plugins/main/noctalia.d.luau
```

## Reference

- [Plugin development docs](https://docs.noctalia.dev/noctalia/plugins/development/) —
  [manifest](https://docs.noctalia.dev/noctalia/plugins/development/manifest/),
  [entry types](https://docs.noctalia.dev/noctalia/plugins/development/entries/),
  [declarative UI](https://docs.noctalia.dev/noctalia/plugins/development/declarative-ui/),
  [runtime API](https://docs.noctalia.dev/noctalia/plugins/development/runtime-api/)
- [official-plugins](https://github.com/noctalia-dev/official-plugins) — the `example` plugin
  exercises every entry type in one place
- [community-plugins](https://github.com/noctalia-dev/community-plugins) — this repo's upstream
