# Plugin API Versions

Every plugin declares the oldest API level it requires with `plugin_api` in `plugin.toml`. API levels are cumulative:
use the oldest level that includes every capability your plugin needs to keep it compatible with as many Noctalia
versions as possible.

| Plugin API | Noctalia version | Introduced |
| --- | --- | --- |
| `3` | `v5.0.0-beta.3` | Mandatory `plugin_api` compatibility declaration, replacing `min_noctalia`. |
| `4` | `v5.0.0-beta.4` | `noctalia.httpStream()` for streaming HTTP responses. |
| `5` | `v5.0.0-beta.4` | `ui.dragSource()` and `ui.dropZone()` for declarative panel drag and drop. |
| `6` | `v5.0.0-beta.4` | The `string_map` plugin setting type. |
| `7` | `v5.0.0-beta.4` | The `allow_insecure_tls` HTTP request option. |
| `8` | `v5.0.0-beta.4` | The `dismiss_on_outside_click` panel entry option. |
| `9` | `v5.0.0-beta.5` | Luau closures directly in UI tree callback props. |
| `10` | `v5.0.0-beta.5` | The `keyboard_focus` panel entry option. |
| `11` | `v5.0.0-beta.5` | The `persistent` panel entry option. |
| `12` | `v5.0.0-beta.5` | `noctalia.systemStats()`, `noctalia.cpuCores()`, and `noctalia.nowMs()`. |
| `13` | `v5.0.0-beta.5` | The `capture_keys` panel entry option and the `onKey` callback. |
| `14` | `v5.0.0-beta.5` | The `[widget.actions]` entry table, declaring bar gesture defaults. |
| `15` | `v5.0.0-beta.6` | `noctalia.openSettings()`, opening the settings window at the plugin's own settings. |
| `16` | `v5.0.0-beta.6` | Per-interface network rates, sample timestamps, and disk mount/stat APIs. |
| `17` | `v5.0.0-beta.7` | Service entries start when the plugin is enabled instead of only at launch, and `onExit(signal, reason)` reports `reload`, `disable`, `uninstall`, or `shutdown`. |
| `18` | `v5.0.0-beta.7` | `panel.setNeedsFrameTick(bool)`, delivering `onFrameTick(deltaMs)` to an open panel. |
| `19` | `v5.0.0-beta.7` | Timezone support on `noctalia.formatTime`, `noctalia.isValidTimezone(name)`, and `noctalia.timeFormat()` / `noctalia.dateFormat()` mirroring `[shell].time_format` / `date_format`. |
| `20` | `v5.0.0-beta.7` | `noctalia.sound.load()` and `noctalia.sound.play()` for plugin audio. |
| `21` | `v5.0.0-beta.8` | The `ui.markdown` node, `submitOnEnter` on `ui.input`, and `stickToBottom` / `onScroll` / `scrollToBottomRev` on `ui.scroll`. |
| `22` | `v5.0.0-beta.8` | `require("./path.luau")` loads relative `.luau` modules with entry-local caches and hot reload for loaded modules. |
| `23` | `v5.0.0-beta.8` | `noctalia.readFileAsync(path, callback)` for bounded filesystem reads outside plugin VM workers. |
| `24` | Unreleased | Argument-array form of `noctalia.runAsync()` for direct process execution without shell parsing. |
| `25` | Unreleased | `noctalia.wallpaperPath(connector)` and `noctalia.setWallpaperMask(connector, mask)` for source-aligned desktop-widget occlusion masks. |
| `26` | Unreleased | `noctalia.getSetting(path)` for reading any effective shell config value by TOML dotted path. |
| `27` | Unreleased | `frameVisible` on `ui.input` for hiding the native input background and border. |
| `28` | Unreleased | `panel.openContextMenu(request)` for native context menus in regular and persistent plugin panels. |

Noctalia currently supports plugin API levels 3 through 28. A plugin version declaring a level outside that range
cannot run.

Raising a plugin’s level therefore drops it from every Noctalia below it. A source repo can keep those users covered by
publishing older revisions in its catalog: Noctalia then installs the newest revision of the plugin its own API range
allows, labels it in the store as an older version, and moves the user up to the newest one once they upgrade Noctalia.
See keeping older Noctalia versions supported.
