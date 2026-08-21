--!nonstrict
-- Modern Clock — a three-line desktop clock: day, date, time.
-- Port of the Noctalia v4 QML plugin of the same name.

local TIME_PRESETS = {
  ["24h"] = "- %H:%M -",
  ["12h"] = "- %I:%M %p -",
}

local function conf(key, fallback)
  local value = noctalia.getConfig(key)
  if value == nil then
    return fallback
  end
  return value
end

-- ── Unicode-aware uppercase ──────────────────────────────────────────────────
-- string.upper only touches ASCII, which would mangle a localized "%A" into
-- something like "THứ HAI". These are the case pairs that show up in day and
-- month names: ASCII, Latin-1, Latin Extended-A, and the Vietnamese block.

local function upperCodepoint(cp)
  if cp >= 0x61 and cp <= 0x7A then
    return cp - 0x20
  elseif cp >= 0xE0 and cp <= 0xFE and cp ~= 0xF7 then
    return cp - 0x20
  elseif cp == 0xFF then
    return 0x178
  elseif cp >= 0x100 and cp <= 0x137 then
    return cp % 2 == 1 and cp - 1 or cp
  elseif cp >= 0x139 and cp <= 0x148 then
    return cp % 2 == 0 and cp - 1 or cp
  elseif cp >= 0x14A and cp <= 0x177 then
    return cp % 2 == 1 and cp - 1 or cp
  elseif cp >= 0x179 and cp <= 0x17E then
    return cp % 2 == 0 and cp - 1 or cp
  elseif cp == 0x1A1 then
    return 0x1A0 -- ơ
  elseif cp == 0x1B0 then
    return 0x1AF -- ư
  elseif cp >= 0x1EA0 and cp <= 0x1EF9 then
    return cp % 2 == 1 and cp - 1 or cp
  end
  return cp
end

local function toUpper(text)
  if text == "" then
    return text
  end
  local out = {}
  for _, cp in utf8.codes(text) do
    table.insert(out, utf8.char(upperCodepoint(cp)))
  end
  return table.concat(out)
end

-- ── Custom font files ────────────────────────────────────────────────────────
-- loadFont registers the file with the host and hands back the family name it
-- registered under; cache it so we are not re-registering on every tick.

local fontCache = {}

local function familyFromFile(path)
  if path == nil or path == "" then
    return nil
  end

  local cached = fontCache[path]
  if cached ~= nil then
    return cached or nil
  end

  local family, err = noctalia.loadFont(path)
  if family == nil or family == "" then
    fontCache[path] = false
    noctalia.log("modern-clock: could not load font '" .. path .. "': " .. tostring(err))
    return nil
  end

  fontCache[path] = family
  return family
end

-- ── Clock ────────────────────────────────────────────────────────────────────

local warnedTimezone = nil
local lastSignature = nil

local function resolveTimezone()
  local zone = conf("timezone", "")
  if zone == "" then
    return nil
  end

  if not noctalia.isValidTimezone(zone) then
    if warnedTimezone ~= zone then
      warnedTimezone = zone
      noctalia.notifyError("Modern Clock", noctalia.tr("notify.bad_timezone", { zone = zone }))
    end
    return nil
  end

  warnedTimezone = nil
  return zone
end

local function line(text, size, color, family, opacity)
  return ui.label({
    text = text,
    fontSize = size,
    color = color,
    opacity = opacity,
    fontFamily = family,
    textAlign = "center",
  })
end

function update()
  local zone = resolveTimezone()
  local now = zone ~= nil and os.time() or nil

  local function stamp(pattern)
    return noctalia.formatTime(pattern, now, zone) or ""
  end

  local uppercase = conf("uppercase", true)
  local opacity = conf("opacity", 1.0)
  local defaultFamily = familyFromFile(conf("font_file", ""))

  local function textOf(pattern)
    local text = stamp(pattern)
    return uppercase and toUpper(text) or text
  end

  local function familyOf(key)
    local family = conf(key, "")
    if family ~= "" then
      return family
    end
    return defaultFamily
  end

  local rows = {}

  if conf("show_day", true) then
    table.insert(rows, line(textOf(conf("day_format", "%A")), conf("day_size", 24), conf("day_color", "primary"), familyOf("day_font"), opacity))
  end

  if conf("show_date", true) then
    table.insert(rows, line(textOf(conf("date_format", "%d %b %Y")), conf("date_size", 15), conf("date_color", "secondary"), familyOf("date_font"), opacity))
  end

  local style = conf("time_style", "24h")
  local timePattern = TIME_PRESETS[style] or conf("time_format", TIME_PRESETS["24h"])
  table.insert(rows, line(textOf(timePattern), conf("time_size", 15), conf("time_color", "secondary"), familyOf("time_font"), opacity))

  -- Re-rendering an identical tree just makes the host redo layout, and at a
  -- 1s tick most ticks change nothing. Hash what we are about to draw instead.
  local parts = {}
  for _, row in ipairs(rows) do
    local props = row.props
    table.insert(parts, table.concat({
      props.text,
      tostring(props.fontSize),
      tostring(props.color),
      tostring(props.fontFamily),
      tostring(props.opacity),
    }, "\30"))
  end

  local padding = conf("padding_h", 0)
  local gap = conf("gap", 4)
  local signature = table.concat(parts, "\31") .. "\31" .. tostring(padding) .. "\31" .. tostring(gap)

  if signature == lastSignature then
    return
  end
  lastSignature = signature

  desktopWidget.render(ui.column({
    gap = gap,
    align = "center",
    paddingH = padding,
  }, rows))
end

noctalia.setUpdateInterval(1000)

update()
