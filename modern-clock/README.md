# Modern Clock

A three-line desktop clock — weekday, date, time — of the kind you would set up in Wallpaper Engine.
Every line has its own format, size, colour and font, so it can be anything from a discreet corner
readout to a full-width poster clock.

This is the Noctalia v5 port of the v4 QML plugin by [@screamified](https://github.com/screamified).

## Plugin

| Field | Value |
| --- | --- |
| ID | `hieunm3103/modern-clock` |
| Entries | Desktop widget: `clock` |

## Usage

Enable the plugin, then add **Modern Clock** to your desktop widgets in Settings. The widget is
draggable and resizable like any other desktop widget. It ticks once a second and only redraws when
the rendered text actually changes.

The three lines are:

```
MONDAY            <- day_format,  day_size,  day_color
21 AUG 2026       <- date_format, date_size, date_color
- 18:00 -         <- time_style,  time_size, time_color
```

Day and date can each be switched off; the time line is always drawn.

### Time and date patterns

`day_format`, `date_format` and the custom `time_format` are `strftime` patterns, rendered in the
host's locale:

| Pattern | Result |
| --- | --- |
| `%A` | `Monday` |
| `%a` | `Mon` |
| `%d %b %Y` | `21 Aug 2026` |
| `%H:%M` | `18:00` |
| `%I:%M %p` | `6:00 PM` |
| `%H:%M:%S` | `18:00:42` |

**Time style** covers the common cases without pattern-writing: `24h` renders `- 18:00 -`, `12h`
renders `- 6:00 PM -`, and `custom` hands over to `time_format` (which is where seconds or a
different decoration go).

### Fonts

`font_file` points at a `.ttf`/`.otf` and registers it with the shell — no `fc-cache` step, and no
need to install anything system-wide. The plugin ships **Anurati** (the face in the thumbnail) and
uses it by default.

To use a font you already have installed instead, put its family name in `day_font`, `date_font` or
`time_font`; a per-line family wins over `font_file`.

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `uppercase` | `bool` | `true` | Render every line in capitals (Unicode-aware, so accented weekday names survive). |
| `opacity` | `double` | `1.0` | Opacity applied to all three lines, `0.0`–`1.0`. |
| `padding_h` | `int` | `0` | Extra space on both sides of the clock, in pixels. |
| `gap` | `int` | `4` | Vertical gap between lines, in pixels. |
| `timezone` | `string` | `""` | IANA zone name, e.g. `Asia/Ho_Chi_Minh`. Empty means system local time. |
| `font_file` | `file` | `Anurati-Regular.otf` | Font file used by every line with no family of its own. |
| `show_day` | `bool` | `true` | Draw the weekday line. |
| `day_format` | `string` | `%A` | `strftime` pattern for the weekday line. |
| `day_size` | `int` | `24` | Weekday font size, in pixels. |
| `day_color` | `color` | `primary` | Palette role or hex colour. |
| `day_font` | `string` | `""` | Installed font family for the weekday line. |
| `show_date` | `bool` | `true` | Draw the date line. |
| `date_format` | `string` | `%d %b %Y` | `strftime` pattern for the date line. |
| `date_size` | `int` | `15` | Date font size, in pixels. |
| `date_color` | `color` | `secondary` | Palette role or hex colour. |
| `date_font` | `string` | `""` | Installed font family for the date line. |
| `time_style` | `select` | `24h` | `24h`, `12h`, or `custom` to use `time_format`. |
| `time_format` | `string` | `- %H:%M -` | `strftime` pattern, used when `time_style` is `custom`. |
| `time_size` | `int` | `15` | Time font size, in pixels. |
| `time_color` | `color` | `secondary` | Palette role or hex colour. |
| `time_font` | `string` | `""` | Installed font family for the time line. |

Colour settings take a palette role (`primary`, `secondary`, `on_surface`, …), a role with alpha
(`primary/0.6`), or a hex value (`#rrggbb`, `#rrggbbaa`).

## Notes

- No network access, no spawned processes, no files written. The plugin reads its own settings,
  registers the font file it is pointed at, and renders text.
- An unknown `timezone` raises one notification and falls back to system local time; it does not
  keep nagging while the value stays wrong.

## Changes from the v4 plugin

- The v4 **colour selection method** toggle is gone. A v5 `color` setting already accepts both a
  palette role and a raw hex value, so the two parallel sets of colour settings collapsed into one
  per line.
- Font **scale** multipliers became direct pixel sizes.
- Fonts are registered by the plugin rather than installed into `/usr/share/fonts`.
- New: per-line `strftime` formats, a timezone override, line spacing, and show/hide for the day and
  date lines.
