--!nonstrict
-- Toolkits — translate [[panel]].
--
-- A Google-Translate-style panel stacked vertically: language bar (plus recent
-- target chips) on top, the source text box in the middle and the translation
-- box below it. Opened from the "Translate" tile of the main panel. Translation
-- runs as you type (after a short pause) or immediately on Ctrl+Enter, through
-- Google Translate's public `translate_a/single` endpoint or DeepL's
-- `v2/translate` endpoint, picked by the "translate-provider" setting (see
-- lib/translator.luau).
--
-- Conveniences: paste / clear / read-aloud on the source box, copy / read-aloud
-- on the translation, dictionary alternatives for short Google queries, recent
-- target languages, retry on error, optional autofill from the selection or the
-- clipboard on open, and Ctrl+Shift+C / S / X for copy, swap and clear.

local translator = require("./lib/translator.luau")

-- Pause after the last keystroke before translating. Counted in onFrameTick,
-- which only runs while a translation is pending (panels get no update() ticks).
local DEBOUNCE_MS = 600
-- Same cap as translate.google.com; longer input is refused, not truncated.
local MAX_CHARS = 5000
local MAX_RECENT = 3
-- Google's TTS endpoint rejects long queries, so speech is sent in chunks.
local TTS_CHUNK = 180
local TTS_TITLE = "toolkits-tts"

local panelOpen = false
local sourceLang = noctalia.state.get("translateSource") or "auto"
local targetLang = noctalia.state.get("translateTarget")
local recentTargets = noctalia.state.get("translateRecent") or {}
local inputText = noctalia.state.get("translateInput") or ""
local lastAutofill = noctalia.state.get("translateAutofill")
local inputKey = 0 -- bumped to re-seed the uncontrolled input (swap / clear / paste)
local output = nil -- { text, source, dict } of the last successful translation
local errorText = nil
local loading = false
local pendingMs = 0
local ticking = false
local requestSeq = 0
local speaking = nil -- "input" / "output" while mpv reads that box aloud
local speakSeq = 0
local cache = {}
local render

-- ── Helpers ────────────────────────────────────────────────────────────────

local function tr(key, subst)
  if subst then return noctalia.tr(key, subst) end
  return noctalia.tr(key)
end

local function charCount(text)
  return utf8.len(text) or #text
end

-- ── Translation flow ───────────────────────────────────────────────────────

local function rerender()
  if panelOpen then render() end
end

local function cancelPending()
  pendingMs = 0
  if ticking then
    ticking = false
    panel.setNeedsFrameTick(false)
  end
end

local function translateNow()
  cancelPending()
  local text = noctalia.string.trim(inputText)
  if text == "" then
    output, errorText, loading = nil, nil, false
    requestSeq += 1
    rerender()
    return
  end
  if charCount(text) > MAX_CHARS then
    requestSeq += 1
    loading, errorText = false, tr("translate.errors.too_long", { max = tostring(MAX_CHARS) })
    rerender()
    return
  end

  local provider = translator.provider()
  local key = `{provider}|{sourceLang}|{targetLang}|{text}`
  if cache[key] then
    requestSeq += 1
    output, errorText, loading = cache[key], nil, false
    rerender()
    return
  end

  requestSeq += 1
  local seq = requestSeq
  loading, errorText = true, nil
  rerender()

  translator.translate(text, sourceLang, targetLang, function(translated, err, detected, dict)
    if seq ~= requestSeq then return end -- a newer request superseded this one
    loading = false
    if translated then
      output = { text = translated, source = detected, dict = dict }
      cache[key] = output
    else
      errorText = err or tr("translate.errors.generic")
    end
    rerender()
  end)
end

local function setInput(text, reseed)
  inputText = text or ""
  noctalia.state.set("translateInput", inputText)
  if reseed then inputKey += 1 end
end

local function setSource(code)
  sourceLang = code
  noctalia.state.set("translateSource", code)
end

-- Every chosen target goes to the front of the recent list, which feeds the chips.
local function setTarget(code)
  targetLang = code
  noctalia.state.set("translateTarget", code)
  local recent = { code }
  for _, c in ipairs(recentTargets) do
    if c ~= code and #recent < MAX_RECENT then table.insert(recent, c) end
  end
  recentTargets = recent
  noctalia.state.set("translateRecent", recent)
end

local function canSwap()
  return sourceLang ~= "auto" or (output ~= nil and output.source ~= nil)
end

-- Google-style swap: languages trade places and the translation becomes the new
-- source text. With "Detect language" as the source, the detected language takes
-- its place.
local function swap()
  if not canSwap() then return end
  local newTarget = if sourceLang == "auto" then output.source else sourceLang
  if newTarget ~= targetLang then
    setSource(targetLang)
    setTarget(newTarget)
  end
  if output and output.text ~= "" then
    setInput(output.text, true)
    output = nil
  end
  translateNow()
end

local function clearInput()
  setInput("", true)
  translateNow()
end

local function fillInput(text)
  setInput(text, true)
  translateNow()
end

local function paste()
  local text = noctalia.clipboardText()
  if type(text) ~= "string" or noctalia.string.trim(text) == "" then
    noctalia.notifyError(tr("translate.clipboard_empty"))
    return
  end
  fillInput(text)
end

local function copyOutput()
  if not output or output.text == "" then return end
  noctalia.copyToClipboard(output.text, "text/plain;charset=utf-8")
  noctalia.notify(tr("plugin_name"), tr("translate.copied"))
end

-- ── Read aloud ─────────────────────────────────────────────────────────────

-- Splits on whitespace into chunks of at most TTS_CHUNK characters.
local function ttsChunks(text)
  local chunks, current = {}, ""
  for word in text:gmatch("%S+") do
    local candidate = if current == "" then word else current .. " " .. word
    if charCount(candidate) > TTS_CHUNK and current ~= "" then
      table.insert(chunks, current)
      current = word
    else
      current = candidate
    end
  end
  if current ~= "" then table.insert(chunks, current) end
  return chunks
end

local function stopSpeaking()
  if speaking then
    speakSeq += 1 -- the killed player's exit callback is now stale
    -- Anchored on the mpv argv so it never matches an unrelated command line.
    noctalia.runAsync({ "pkill", "-f", "^mpv .*--title=" .. TTS_TITLE })
    speaking = nil
  end
end

-- Toggles reading `which` box aloud: a second click on the same box stops it,
-- a click on the other box switches to it.
local function speak(which, text, lang)
  local wasSpeaking = speaking
  stopSpeaking()
  if wasSpeaking == which then
    rerender()
    return
  end
  text = noctalia.string.trim(text or "")
  if text == "" then return end
  if not noctalia.commandExists("mpv") then
    noctalia.notifyError(tr("messages.missing_dep", { dep = "mpv" }))
    return
  end

  local argv = { "mpv", "--no-config", "--no-video", "--really-quiet", "--title=" .. TTS_TITLE }
  for _, chunk in ipairs(ttsChunks(text)) do
    table.insert(argv, `https://translate.googleapis.com/translate_tts?client=gtx&ie=UTF-8&tl={noctalia.string.urlEncode(lang)}&q={noctalia.string.urlEncode(chunk)}`)
  end

  speakSeq += 1
  local seq = speakSeq
  speaking = which
  rerender()
  noctalia.runAsync(argv, function(result)
    if seq ~= speakSeq then return end
    speaking = nil
    if result.exitCode ~= 0 then
      noctalia.notifyError(tr("translate.errors.speech"))
    end
    rerender()
  end)
end

local function speakInput()
  local lang = if sourceLang ~= "auto" then sourceLang else (output and output.source) or "en"
  speak("input", inputText, lang)
end

local function speakOutput()
  if output then speak("output", output.text, targetLang) end
end

-- ── Autofill ───────────────────────────────────────────────────────────────

-- Fills the source box from the primary selection or the clipboard when the
-- panel opens, but only with text not autofilled before, so reopening the panel
-- keeps what the user was working on.
local function autofill()
  local mode = noctalia.getConfig("translate-autofill")
  local function apply(text)
    if type(text) ~= "string" then return end
    text = noctalia.string.trim(text)
    if text == "" or text == lastAutofill or text == noctalia.string.trim(inputText) then return end
    lastAutofill = text
    noctalia.state.set("translateAutofill", text)
    fillInput(text)
  end
  if mode == "clipboard" then
    apply(noctalia.clipboardText())
  elseif mode == "selection" and noctalia.commandExists("wl-paste") then
    noctalia.runAsync({ "wl-paste", "--primary", "--no-newline" }, function(result)
      if result.exitCode == 0 then apply(result.stdout) end
    end)
  end
end

-- ── UI ─────────────────────────────────────────────────────────────────────

local function iconButton(key, glyph, tooltip, onClick, opts)
  opts = opts or {}
  return ui.button({
    key = key, glyph = glyph, variant = opts.variant or "ghost", controlSize = "sm", tooltip = tooltip,
    enabled = opts.enabled ~= false, selected = opts.selected, onClick = onClick,
  })
end

local function langSelect(includeAuto, selected, onPick)
  local options, codes, selectedIndex = {}, {}, 0
  if includeAuto then
    local label = tr("translate.detect")
    if sourceLang == "auto" and output and output.source then
      label = tr("translate.detected", { lang = translator.langName(output.source) })
    end
    table.insert(options, label)
    table.insert(codes, "auto")
  end
  for _, l in ipairs(translator.LANGUAGES) do
    table.insert(options, l.name)
    table.insert(codes, l.code)
  end
  for i, c in ipairs(codes) do
    if c == selected then selectedIndex = i - 1; break end
  end
  return ui.select({
    options = options,
    selectedIndex = selectedIndex,
    controlSize = "sm",
    flexGrow = 1,
    onChange = function(value)
      local code = codes[(tonumber(value) or 0) + 1]
      if code and code ~= selected then
        onPick(code)
        translateNow()
      end
    end,
  })
end

local function header()
  return ui.row({ align = "center", gap = 6 }, {
    ui.glyph({ name = "language", size = 18, color = "primary" }),
    ui.label({ text = tr("translate.title"), flexGrow = 1, fontSize = 16, fontWeight = "bold", color = "on_surface" }),
    ui.button({
      key = "translate-close", glyph = "close", width = 24, height = 24, glyphSize = 12,
      onClick = function() panel.close() end,
    }),
  })
end

local function languageBar()
  return ui.row({ align = "center", gap = 6 }, {
    langSelect(true, sourceLang, setSource),
    iconButton("translate-swap", "arrows-exchange", tr("translate.swap"), swap, { enabled = canSwap() }),
    langSelect(false, targetLang, setTarget),
  })
end

-- One-click switching between the last few target languages.
local function recentChips()
  if #recentTargets < 2 then return nil end
  local chips = { ui.label({ text = tr("translate.recent"), fontSize = 10, color = "on_surface_variant" }) }
  for _, code in ipairs(recentTargets) do
    table.insert(chips, ui.button({
      key = "translate-recent-" .. code, text = translator.langName(code), fontSize = 11, controlSize = "sm",
      variant = if code == targetLang then "secondary" else "ghost", selected = code == targetLang,
      onClick = function()
        if code ~= targetLang then
          setTarget(code)
          translateNow()
        end
      end,
    }))
  end
  return ui.row({ align = "center", gap = 4 }, chips)
end

local function inputCard()
  local count = charCount(inputText)
  local hasText = inputText ~= ""
  return ui.column({ flexGrow = 1, gap = 4, padding = 8, radius = 12, fill = "surface_variant" }, {
    ui.input({
      key = "translate-input-" .. inputKey,
      value = inputText,
      placeholder = tr("translate.placeholder"),
      multiline = true,
      focus = true,
      fontSize = 14,
      flexGrow = 1,
      onChange = function(value)
        setInput(value, false)
        pendingMs = DEBOUNCE_MS
        if not ticking then
          ticking = true
          panel.setNeedsFrameTick(true)
        end
        render()
      end,
      onSubmit = function(value)
        setInput(value, false)
        translateNow()
      end,
    }),
    ui.row({ align = "center", gap = 2 }, {
      iconButton("translate-paste", "clipboard", tr("translate.paste"), paste),
      iconButton("translate-speak-input", if speaking == "input" then "player-stop" else "volume", tr("translate.listen"), speakInput, { enabled = hasText }),
      ui.label({
        text = `{count} / {MAX_CHARS}`, flexGrow = 1, textAlign = "end", fontSize = 10,
        color = if count > MAX_CHARS then "error" else "on_surface_variant",
      }),
      iconButton("translate-clear", "x", tr("translate.clear"), clearInput, { enabled = hasText }),
      iconButton("translate-run", "language", tr("translate.run"), translateNow, { variant = "primary", enabled = hasText }),
    }),
  })
end

local function dictionaryBlock(dict)
  local children = { ui.separator({ spacing = 6 }) }
  for _, group in ipairs(dict) do
    table.insert(children, ui.label({ text = group.pos, fontSize = 11, fontWeight = "bold", color = "primary" }))
    table.insert(children, ui.label({ text = table.concat(group.terms, ", "), fontSize = 12, color = "on_surface_variant" }))
  end
  return ui.column({ gap = 2 }, children)
end

local function outputCard()
  local content
  if errorText then
    content = {
      ui.row({ align = "center", gap = 6 }, {
        ui.glyph({ name = "alert-triangle", size = 16, color = "error" }),
        ui.label({ text = errorText, flexGrow = 1, fontSize = 13, color = "error" }),
        ui.button({ key = "translate-retry", text = tr("translate.retry"), glyph = "refresh", variant = "outline", controlSize = "sm", onClick = translateNow }),
      }),
    }
  elseif output then
    content = {
      ui.label({ text = output.text, fontSize = 14, color = "on_surface", textAlign = if translator.isRTL(targetLang) then "end" else "start" }),
    }
    if output.dict then table.insert(content, dictionaryBlock(output.dict)) end
  else
    content = {
      ui.label({
        text = if loading then tr("translate.translating") else tr("translate.output_placeholder"),
        fontSize = 14, color = "on_surface_variant",
      }),
    }
  end

  local hasOutput = output ~= nil and not errorText
  return ui.column({ flexGrow = 1, gap = 4, padding = 8, radius = 12, fill = "primary/0.08", border = "primary/0.25", borderWidth = 1 }, {
    ui.scroll({ flexGrow = 1, gap = 4, paddingH = 4, paddingV = 4 }, content),
    ui.row({ align = "center", gap = 2 }, {
      iconButton("translate-speak-output", if speaking == "output" then "player-stop" else "volume", tr("translate.listen"), speakOutput, { enabled = hasOutput }),
      ui.label({ text = if loading and output then tr("translate.translating") else "", flexGrow = 1, fontSize = 10, color = "on_surface_variant" }),
      iconButton("translate-copy", "copy", tr("translate.copy"), copyOutput, { enabled = hasOutput }),
    }),
  })
end

render = function()
  local children = { header(), languageBar() }
  local chips = recentChips()
  if chips then table.insert(children, chips) end
  table.insert(children, inputCard())
  table.insert(children, outputCard())
  panel.render(ui.column({ flexGrow = 1, gap = 8 }, children))
end

-- ── Lifecycle ──────────────────────────────────────────────────────────────

function onOpen(_context)
  panelOpen = true
  if not targetLang then setTarget(translator.defaultTarget()) end
  inputKey += 1 -- fresh key so the input grabs focus again
  if inputText ~= "" and not output then translateNow() end
  render()
  autofill()
end

function onClose()
  panelOpen = false
  cancelPending()
  stopSpeaking()
end

function onKey(chord, pressed)
  if not pressed then return end
  if chord == "ctrl+shift+c" then copyOutput()
  elseif chord == "ctrl+shift+s" then swap()
  elseif chord == "ctrl+shift+x" then clearInput() end
end

function onFrameTick(deltaMs)
  if pendingMs <= 0 then return end
  pendingMs -= tonumber(deltaMs) or 0
  if pendingMs <= 0 then translateNow() end
end
