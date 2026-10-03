# Toolkits

A personal toolbox for Noctalia v5. It starts from screen utilities — color picking, OCR,
QR/barcode scanning, palette extraction, Google Lens search, annotation, pixel measuring,
screen recording and image sharing — and is meant to grow beyond screen-only tools.

This is a personal fork of
[Screen Toolkit](https://github.com/noctalia-dev/community-plugins/tree/main/screen-toolkit)
by Alexander (upstream commit `01c3ad4`).

## Attribution

Screen Toolkit was originally created for Noctalia v4 by the author(s) of the
[legacy screen-toolkit plugin](https://github.com/noctalia-dev/legacy-v4-plugins/tree/main/screen-toolkit).
This repository is an independent Noctalia v5 remake/port by `alexander`; it is
not the original implementation.

## Plugin

| Field | Value |
| --- | --- |
| ID | `hieunm3103/toolkits` |
| Entries | Bar widget: `widget`; control-center shortcut: `toggle`; panels: `panel` (standard tools), `panel-legacy` (legacy layout), `result` (result view), `translate` (translator); service: `service` |

## Requirements

Install the tools used by the features you want on `PATH`. Missing tools are
reported when that feature is started.

- **`slurp`** — region selection
- **`grim`** — screen capture
- **`hyprpicker`** — pixel color picking
- **`tesseract`** — OCR engine (plus your language packs, e.g. `tesseract-data-eng`)
- **`imagemagick`** — image processing
- **`zbar`** — QR / barcode scanning (`zbarimg`)
- **`curl`** + **`jq`** — image uploads (uguu.se / x02.me) and Google Lens
- **`ffmpeg`** + **`ffprobe`** — recording / GIF conversion and thumbnail generation
- **`bc`** — GIF duration and frame-rate calculations
- **`stat`** — recording file size
- **`pkill`** — stopping active recording backends
- **`xdg-open`** — opening URLs, OCR search results, and shared-link targets
- **`mpv`** — open recording preview in legacy mode subpanel; Translate read-aloud
- **`wl-paste`** (wl-clipboard) — Translate autofill from the selection
- **`pactl`** — resolve the default audio source for single-source wf-recorder / wl-screenrec recording

Recording requires at least one backend:

- **`gpu-screen-recorder`** — recommended for fullscreen recording, especially on NVIDIA (NVENC)
- **`wl-screenrec`** — preferred for region recording and microphone audio
- **`wf-recorder`** — fallback recorder for region and fullscreen capture

Optional:

- **`swappy`** / **`satty`** / **`tensaku`** — annotation editor (Markup tool)
- **`gimp`** — fallback annotation editor when swappy/satty/tensaku are missing
- **hyprctl** — annotate the focused window (Hyprland)
- **`niri`** — annotate the focused window (Niri)

Compositor support: region tools, measure, annotate and recording work on any
Wayland compositor with `wlroots` protocols. `Annotate Window` requires Hyprland
(`hyprctl`) or Niri (`niri msg`).

## Usage

Add the `Toolkits` widget to a bar, and/or the shortcut tile in
Settings → Control Center shortcuts. Left-click either one opens the main panel
(or stops a recording); right-clicking the bar widget quick-picks a color. While
a recording is active, the widget and shortcut show a pulsing red dot.

The main panel has two layouts, selected by the `panel-mode` setting (default:
**Standard**):

- **Standard** — a dense grid grouped into tinted sections (`panel`, 380×260).
- **Legacy** — recreates the Noctalia-v4 layout (`panel-legacy`, 380×350): a 4-column grid that wraps onto new rows as tools are added.

### Legacy mode
Legacy mode recreates the original Noctalia v4 screen-toolkit layout:

> **Note:** The features below are exclusive to the **Legacy** layout.

- Dedicated Markup and Recording subpanels.
- Preview and one-click access to the most recent screenshot or recording.
- Quick microphone and system audio toggles in the `Record` subpanel.

The widget and shortcut open the panel matching the `panel-mode` setting; the
panel footnote under Settings → Plugins shows placement/position options.

Toggle the tools panel (opens the panel matching `panel-mode`):

```sh
noctalia msg plugin hieunm3103/toolkits:service all toggle
```

For example, bind it to `SUPER+P` in Hyprland:

```ini
bind = SUPER, P, exec, noctalia msg plugin hieunm3103/toolkits:service all toggle
```

Open the standard tools panel:

```sh
noctalia msg panel-toggle hieunm3103/toolkits:panel
```

Open the legacy tools panel (the 4-column grid with subpanels):

```sh
noctalia msg panel-toggle hieunm3103/toolkits:panel-legacy
```

Open the result panel (shows the last capture/recording output):

```sh
noctalia msg panel-toggle hieunm3103/toolkits:result
```

Open the Translate panel directly (e.g. from a compositor keybind):

```sh
noctalia msg panel-toggle hieunm3103/toolkits:translate
```

The tools panel contains the capture actions. When a capture tool finishes, a
**result panel** opens with the output and its actions; close it to return to
the tools panel.

Region tools (Color, OCR, QR, Palette, Lens, Measure, GIF/MP4 record, Markup)
draw a `slurp` crosshair — drag to select a region, then release. Recording
starts immediately and the bar widget shows the pulsing dot; click the dot, the
widget, the shortcut, or the panel's **Stop** button to end it. Unless "Skip
Save Confirmation" is on, the panel then offers **Save MP4**, **Save GIF**,
**Copy**, and **Discard**.

The `hide-cursor` setting excludes the cursor from **recordings and screenshots**
(default: hidden). Grim excludes the cursor by default; when the setting is
disabled, the plugin passes grim's `-c` flag to include it. gpu-screen-recorder
and wl-screenrec receive their corresponding cursor options. wf-recorder does
not expose a portable cursor flag, so its behavior depends on the compositor.

- **Markup** captures the region and opens it in `swappy` (`satty` or `tensaku`). Saving
  happens in that editor; satty saves to your screenshot path automatically.
  **Markup Window** shows a crosshair — click the window you want to annotate
  and it captures that window (Hyprland). On Niri it captures the focused
  window directly.
- **Measure** reports the region's pixel size and copies it to the clipboard.
- **OCR** extracts text and copies it to the clipboard. The result includes the
  capture preview and an editable multiline text area, so you can correct, trim,
  or extend the OCR output before copying, searching, translating, or sharing
  it. Detected URLs can be opened directly and detected email addresses can
  open a mail composer.
- **QR** decodes a code and copies the text to the clipboard.
- **Palette** copies the extracted hex colors (one per line) to the clipboard.
- **Share** uploads the current capture and copies the link (uguu.se by default,
  or up.x02.me with an API key).

Results are delivered to the clipboard with a notification — the panel itself
only holds the tools. Results persist across restarts in the plugin's data
directory; the capture previews live in `/tmp` and are only kept for the
session.

### Translate

The **Translate** tile opens a Google-Translate-style panel
(`hieunm3103/toolkits:translate`), stacked vertically instead of side by side:

- a language bar — source (`Detect language` or a fixed language), a swap
  button, and the target language, plus chips for the last few target
  languages;
- the source text box — translation runs automatically once you stop typing,
  or immediately with Ctrl+Enter / the translate button. Below it: paste from
  the clipboard, read aloud, a `n / 5000` character counter and clear;
- the translation box — read aloud and copy, a retry button when a request
  fails, and dictionary alternatives grouped by part of speech for short
  queries (Google only).

Swap trades the two languages and moves the translation into the source box;
with `Detect language` the detected language takes the target's place. The
source text and language choices are kept while Noctalia runs.

Keyboard shortcuts inside the panel: Ctrl+Enter translates now, Ctrl+Shift+C
copies the translation, Ctrl+Shift+S swaps, Ctrl+Shift+X clears and Escape
closes.

With `translate-autofill` set to `selection` (via `wl-paste --primary`) or
`clipboard`, opening the panel fills the source box with that text and
translates it — handy with a compositor keybind on
`noctalia msg panel-toggle hieunm3103/toolkits:translate`. Text that was
already autofilled once is not filled again, so reopening the panel keeps your
work.

Read aloud plays Google Translate's speech endpoint through `mpv`.

Translation goes through Google Translate (`translate.googleapis.com`) or DeepL
(`api.deepl.com` / `api-free.deepl.com`; free-tier keys end in `:fx` and pick
the free endpoint automatically), per `translate-provider`. The HTTP layer is
ported from
[noctalia/translator](https://github.com/noctalia-dev/official-plugins/tree/main/translator).

## Settings

All settings live in Settings → Plugins (gear on the plugin's row).

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `screenshot-path` | `folder` | `~/Pictures/Screenshots` | Where satty saves annotations. |
| `video-path` | `folder` | `~/Videos` | Where recordings are saved. |
| `filename-format` | `string` | `%Y-%m-%d_%H-%M-%S` | Filename template; the extension is added automatically. |
| `selected-ocr-lang` | `string` | `eng` | Tesseract language code; combine with `+` (e.g. `eng+fra`). |
| `search-engine-url` | `string` | *(Google)* | Search URL prefix, or a URL containing `{text}`. The OCR text is URL-encoded. |
| `x02-api-key` | `string` | *(empty)* | up.x02.me key for longer-lived, larger uploads. |
| `x02-expiry` | `select` | `7d` | Link lifetime when an x02 key is set: `1h`, `1d`, `7d`, `30d`, or `permanent`. |
| `share-skip-popover` | `bool` | `false` | Compatibility setting retained from v4. The v5 result panel copies share links directly. |
| `record-audio-out` | `bool` | `false` | Record the desktop's audio output. |
| `record-audio-in` | `bool` | `false` | Record the default microphone. |
| `hide-cursor` | `bool` | `true` | Exclude the cursor from recordings and screenshots. On Hyprland, screenshots briefly move the pointer off-screen during capture. |
| `record-codec` | `select` | `h264` | Codec for `gpu-screen-recorder` fullscreen capture: `h264`, `hevc`, or `av1`. `h264` is the safest NVIDIA NVENC default; `av1` needs a recent GPU. |
| `record-fps` | `int` | `60` | Frame rate for `gpu-screen-recorder` fullscreen capture (15–240). |
| `record-skip-confirmation` | `bool` | `false` | Save automatically when a recording ends, skipping the save dialog. |
| `record-copy-to-clipboard` | `bool` | `false` | Finalize to MP4 and copy the file URI when recording ends. |
| `gif-max-seconds` | `int` | `30` | Cap for GIF recordings (1–600 s). |
| `panel-mode` | `select` | `standard` | Main panel layout: `standard` (dense grid, 380×260) or `legacy` (4-column wrapping grid, 380×350). |
| `translate-target-lang` | `string` | `en` | Target language preselected the first time the Translate panel opens. |
| `translate-provider` | `select` | `google` | Translation service for the Translate panel and OCR translation: `google` or `deepl`. |
| `translate-deepl-api-key` | `string` | *(empty)* | DeepL API key (only needed when `translate-provider` is `deepl`). |
| `translate-autofill` | `select` | `off` | Fill the Translate panel on open from the `selection` (primary selection) or the `clipboard`. |

## IPC

The service is a singleton with no output, so the IPC target is `all`:

```sh
noctalia msg plugin hieunm3103/toolkits:service all toggle
noctalia msg plugin hieunm3103/toolkits:service all colorPicker
noctalia msg plugin hieunm3103/toolkits:service all ocr
noctalia msg plugin hieunm3103/toolkits:service all qr
noctalia msg plugin hieunm3103/toolkits:service all palette
noctalia msg plugin hieunm3103/toolkits:service all lens
noctalia msg plugin hieunm3103/toolkits:service all measure
noctalia msg plugin hieunm3103/toolkits:service all annotate
noctalia msg plugin hieunm3103/toolkits:service all annotateFullscreen
noctalia msg plugin hieunm3103/toolkits:service all annotateWindow
noctalia msg plugin hieunm3103/toolkits:service all record
noctalia msg plugin hieunm3103/toolkits:service all recordMp4
noctalia msg plugin hieunm3103/toolkits:service all recordFullscreen
noctalia msg plugin hieunm3103/toolkits:service all recordFullscreenMp4
noctalia msg plugin hieunm3103/toolkits:service all recordStop
noctalia msg plugin hieunm3103/toolkits:service all recordSave
noctalia msg plugin hieunm3103/toolkits:service all recordCopy
noctalia msg plugin hieunm3103/toolkits:service all recordDiscard
noctalia msg plugin hieunm3103/toolkits:service all ocrSearch
noctalia msg plugin hieunm3103/toolkits:service all clearResult
noctalia msg plugin hieunm3103/toolkits:service all clearHistory
```

`toggle` opens the panel matching the `panel-mode` setting. The bar widget and
control-center shortcut use the same logic.

Commands that take a payload:

```sh
# Translate the current OCR text into a language (language code payload)
noctalia msg plugin hieunm3103/toolkits:service all ocrTranslate en
# Search the current OCR text (or a payload.text) with the configured engine
noctalia msg plugin hieunm3103/toolkits:service all ocrSearch
# Share a file on disk (absolute path payload)
noctalia msg plugin hieunm3103/toolkits:service all share /path/to/image.png
# Save the finished recording (payload format: "gif" or "mp4")
noctalia msg plugin hieunm3103/toolkits:service all recordSave mp4
# Show or hide the cursor in captures (payload: "true" or "false")
noctalia msg plugin hieunm3103/toolkits:service all setCursorHidden true
```

Summary of every service command:

| Command | Payload | Action |
| --- | --- | --- |
| `toggle` | — | Open/close the tools panel (matches `panel-mode`) |
| `colorPicker` | — | Pick a color from the screen (region crosshair) |
| `ocr` | — | Extract text from a region |
| `qr` | — | Decode a QR / barcode from a region |
| `palette` | — | Extract hex colors from a region |
| `lens` | — | Google Lens search on a region |
| `measure` | — | Report a region's pixel size |
| `annotate` | — | Open a region in the annotation editor |
| `annotateFullscreen` | — | Annotate the full screen |
| `annotateWindow` | — | Annotate the focused window (Hyprland / Niri) |
| `record` | — | Record a region as GIF |
| `recordMp4` | — | Record a region as MP4 |
| `recordFullscreen` | — | Record the full screen as GIF |
| `recordFullscreenMp4` | — | Record the full screen as MP4 |
| `recordStop` | — | Stop the active recording |
| `recordSave` | `"gif"` / `"mp4"` | Save the finished recording |
| `recordCopy` | — | Finalize to MP4 and copy the file URI |
| `recordDiscard` | — | Discard the finished recording |
| `ocrSearch` | optional `{text}` | Search OCR text with the configured engine |
| `ocrTranslate` | language code | Translate OCR text (via `translate-provider`) |
| `share` | file path | Upload a file and copy the link |
| `clearResult` | — | Clear the current result panel state |
| `clearHistory` | — | Clear the color history |
| `setCursorHidden` | `"true"` / `"false"` | Include/exclude the cursor in captures |

## Notes

- **Two panel entries, one layout setting.** Panel size is host-owned: the host
  sizes each `[[panel]]` entry from its `width`/`height`, and there is no runtime
  resize. So the two layouts are two entries sharing `panel.luau`:
  `panel` (380×260, the standard grid) and `panel-legacy` (380×350, the legacy grid).
  The `panel-mode` setting picks which one `toggle` opens; changing the setting
  only affects which panel opens next time; an already-open panel keeps its
  current size until closed.
- This is a port of the legacy v4
  [screen-toolkit](https://github.com/noctalia-dev/legacy-v4-plugins/tree/main/screen-toolkit)
  plugin. Tools that relied on freeform v4 QML overlays are adapted: region
  selection uses `slurp`, annotation hands off to `swappy`/`satty`/`tensaku`, and measure
  reports region dimensions instead of drawing a line overlay. **Pin** (floating
  screen overlays) and **Webcam Mirror** could not be ported — the v5 plugin UI
  has no canvas or always-on-top surfaces — so they are not included.
- Recording auto-detects its backend: **fullscreen** uses `gpu-screen-recorder`
  when installed (NVENC hardware encoding — the best option on NVIDIA GPUs,
  where wl-screenrec's VAAPI path is unreliable), falling back to
  `wl-screenrec` then `wf-recorder`. **Region** capture uses `wl-screenrec` then
  `wf-recorder`, because `gpu-screen-recorder` cannot record an arbitrary
  sub-region. Microphone audio is only supported by `wl-screenrec`; with
  `wf-recorder` only a single audio source (system *or* microphone) is available, and gpu-screen-recorder's audio
  follows its own source selection.
- Region coordinates are captured in physical pixels; `recordFullscreen`
  multiplies the focused output's logical geometry by its scale.
- Files are written to your configured screenshot/video directories and the
  plugin's persistent data directory (state, color history). Captures in `/tmp`
  are transient.
- Network calls: Google Lens upload (uguu.se), share uploads (uguu.se or
  up.x02.me), and `xdg-open` for search/URL results.

## License

This remake is released under the MIT license. It is an independent v5 port of
the original legacy plugin; see [Attribution](#attribution) for the original
project and source.
