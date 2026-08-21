---
name: new-plugin
description: Create a complete, working Noctalia v5 plugin in this repo — interviews the user for requirements, then writes plugin.toml, the Luau entry scripts, translations/en.json and README.md, rebuilds catalog.toml and runs the validator until it passes. Use when the user wants to build, add, scaffold or start a new plugin here.
---

# Creating a Noctalia plugin

You are writing a plugin into this repo — a personal plugin source whose CI validates every
plugin. The deliverable is a plugin that **runs** and **passes `validate-plugins.py`**, not a
folder of TODOs.

Author for this repo is always `hieunm3103`, so every id is `hieunm3103/<slug>`.

## Reference material

Everything below is the distilled upstream documentation, offline in `references/`. Read the ones
the design actually needs — do not guess API shapes from memory, the API is beta and moves:

| File | Read it when |
| --- | --- |
| `references/manifest.md` | Always — manifest fields, entry kinds, settings schema |
| `references/entries.md` | Always — which callbacks exist per entry kind, `barWidget.*`, `shortcut.*`, `launcher.*`, modules, lifecycle |
| `references/declarative-ui.md` | The plugin has a panel, a desktop widget, or a composite bar widget — full `ui.*` control and prop vocabulary, context menus, keyboard focus, persistent panels, `onKey`, drag & drop |
| `references/runtime-api.md` | Always — every `noctalia.*` capability: config, subprocess, HTTP, filesystem, state, sound, system stats, i18n |
| `references/plugin-api.md` | Always — the API-level table, to pick the lowest `plugin_api` that covers the design |
| `references/workflow.md` | Dev loop, IPC testing, catalog/publishing details |

`noctalia.d.luau` at the repo root (gitignored, fetched per README) is the type definition file — a
second source of truth for exact signatures.

## Step 1 — interview the user

Ask with `AskUserQuestion`, in the user's language, in this order. Do not ask everything at once
and do not ask about things you can derive. Skip any question the user already answered in their
prompt.

1. **Surface** (multi-select) — where does it live?
   - bar widget (`[[widget]]`), desktop widget (`[[desktop_widget]]`), panel (`[[panel]]`),
     control-center tile (`[[shortcut]]`), launcher provider (`[[launcher_provider]]`),
     background service (`[[service]]`).
   - A panel almost always pairs with a bar widget that toggles it. A service is only needed when
     data must be fetched on a schedule independent of any visible surface, or shared between
     entries.
2. **Data source** — where does the content come from? A shell command, an HTTP endpoint, a file
   under `/sys` or `/proc`, `noctalia.systemStats()`, or nothing external (a clock, a timer). This
   decides `dependencies`, whether the work must be async, and whether a service is warranted.
3. **Cadence** — how often does it refresh? Every second, every N seconds, on an event, or only
   while a panel is open. Maps to `noctalia.setUpdateInterval(ms)`, `setWantsSecondTicks(true)`,
   `setNeedsFrameTick(true)`.
4. **Interaction** — what do left / right / middle click and scroll do? Which of those should be
   user-rebindable defaults in `[widget.actions]` versus script callbacks?
5. **Settings** — what should the user be able to configure? Propose a concrete list from the
   design and let them cut it, rather than asking an open question.

## Step 2 — pin the design before writing

Present a compact design table and get a yes: plugin id and directory, entry list with ids and
files, the settings schema, `plugin_api`, `tags`, `dependencies`, and the file layout.

Deriving `plugin_api` is the part most easily got wrong. Walk `references/plugin-api.md` and take
the **lowest level that covers every capability used** — a needlessly high level cuts off every
older Noctalia. Frequent triggers: `string_map` → 6, `dismiss_on_outside_click` → 8, Luau closures
as UI callbacks → 9, `keyboard_focus` → 10, `persistent` → 11, `systemStats`/`cpuCores`/`nowMs` →
12, `capture_keys`/`onKey` → 13, `[widget.actions]` → 14, `openSettings` → 15, per-interface net
rates and disk APIs → 16, `onEnable`/`onExit(signal, reason)` → 17, `panel.setNeedsFrameTick` → 18,
timezone-aware `formatTime` → 19, `noctalia.sound.*` → 20, `ui.markdown`/`submitOnEnter`/
`stickToBottom` → 21, `require("./x.luau")` → 22, `readFileAsync` → 23, argv-form `runAsync` → 24,
wallpaper masks → 25, `getSetting` → 26, `frameVisible` → 27, `panel.openContextMenu` → 28.
Noctalia v5 accepts 3–28 only.

## Step 3 — write the files

Create `<slug>/` at the repo root with:

```
<slug>/
  plugin.toml
  <entry>.luau          # one per entry; lib/*.luau for shared modules (plugin_api = 22)
  translations/en.json
  README.md
  thumbnail.webp        # NOT generated here — see step 5
```

Write real logic, not stubs. Model the code on the existing plugins in this repo (`modern-clock/`
is a settings-heavy desktop widget, `aichat/` is widget + panel + service with HTTP streaming) and
on the patterns in `references/`.

Rules the validator enforces — getting these wrong is the usual reason CI fails:

- **Directory name must equal the part of `id` after the `/`**, lowercase, `[a-z0-9][a-z0-9._-]*`,
  and not one of `license readme index api admin static assets`.
- **`version`** is exactly `MAJOR.MINOR.PATCH`, no suffixes. New plugins start at `1.0.0`.
- **`description`** is at most 120 characters.
- **`tags`** must come from the validator's whitelist. Read `ALLOWED_TAGS` in
  `.github/workflows/scripts/validate-plugins.py` and pick only from it — inventing a tag fails CI.
- **Every `label_key` / `description_key` must resolve** in `translations/en.json`. Literal
  `label` / `description` fields in the manifest are rejected outright.
- **`translations/en.json` keys are nested objects, never dotted strings.** `"settings.foo.label"`
  as a JSON key fails; write `{"settings": {"foo": {"label": "..."}}}`. Each segment is lowercase
  `a-z0-9`, dashes and non-leading underscores.
- **Config is read with `noctalia.getConfig(key)` only.** `barWidget.getConfig`,
  `panel.getConfig`, `desktopWidget.getConfig` and `launcher.getConfig` are rejected by the
  validator. Reading an undeclared key returns `nil` and logs loudly.
- **README** must have: an `# H1` title; an intro of at least 8 words under it; a `## Plugin`
  section containing the plugin id **and every entry id**, each in backticks; a non-empty
  `## Usage`; a `## Requirements` naming every dependency in backticks if `dependencies` is
  non-empty; a `## Settings` section if any settings are declared. **No raw HTML anywhere** — that
  includes `<!-- -->` comments, so strip every comment when starting from `README_TEMPLATE.md`. A
  panel needs the literal line `noctalia msg panel-toggle <id>:<entry-id>` somewhere in the file.
- **Launcher `prefix`** is lowercase letters only and excludes the `/` character itself.
- **Panel geometry** lives in the manifest, not the script: `width`/`height` take a positive number
  or `"fill"`, and `"fill"` requires `placement = "floating"`.

Behavioural traps worth designing around:

- Every bar widget already has a built-in **middle** binding that opens its settings, so
  `onMiddleClick` never fires unless the manifest declares `middle = "none"`.
- A binding in `[widget.actions]` **overrides the matching script callback** for that gesture —
  declaring `right = "..."` kills `onRightClick`.
- `noctalia.state` is process-lifetime and survives a service restart, so any cache stored there
  must be keyed by the config it was fetched for. A service that defines `onConfigChanged()` is
  updated in place instead of being restarted.
- Persist across restarts in `noctalia.pluginDataDir()`, never in `noctalia.pluginDir()` — the
  latter is a runtime copy that gets overwritten on plugin update.
- Use the argv form of `runAsync` (`plugin_api = 24`) whenever settings or user input reach a
  command; the string form goes through `/bin/sh -c` and needs manual quoting.

## Step 4 — validate

```sh
python3 .github/workflows/scripts/update-catalog.py
python3 .github/workflows/scripts/validate-plugins.py
```

Fix every reported error and re-run until clean. `catalog.toml` is generated and **is** committed
in this repo, so regenerate it whenever a manifest changes.

## Step 5 — hand over

Tell the user, concretely:

- **The thumbnail is still missing.** `thumbnail.webp` must be exactly 960×540 and ≤512 KB;
  generate it at <https://assets.noctalia.dev/plugins/thumbnail-generator.html> and drop it into
  the plugin directory. The validator will keep failing on that one file until then — say so
  plainly instead of reporting the plugin as finished.
- How to run it:

  ```sh
  noctalia msg plugins source add dev path ~/Workspace/projects/noctalia-v5-plugins
  noctalia msg plugins enable hieunm3103/<slug>
  ```

  `.luau` edits hot-reload. A `plugin.toml` change needs
  `python3 .github/workflows/scripts/update-catalog.py && noctalia msg config-reload`.
- How to poke its IPC handlers, if it has any:

  ```sh
  noctalia msg plugin hieunm3103/<slug>:<entry-id> all <event> [payload]
  noctalia msg panel-toggle hieunm3103/<slug>:<panel-id>
  ```
- Finally, add the plugin's row to the table in the root `README.md`.
