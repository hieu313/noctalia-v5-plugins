-- Fall back to the English text when the host has no translation table for the
-- key (older Noctalia builds, or a language file without it).
local function tr(key, fallback, subst)
  if type(noctalia.tr) ~= "function" then return fallback end
  local ok, text = pcall(noctalia.tr, key, subst)
  if ok and type(text) == "string" and text ~= "" and text ~= key then return text end
  return fallback
end

-- The idle glyph is the user's `glyph` setting; the busy states override it.
local function idleGlyph()
  local configured = noctalia.getConfig("glyph")
  if type(configured) == "string" and configured ~= "" then return configured end
  return "message-chatbot"
end

-- Keys must match the statuses the service publishes in `aichat.status`.
local glyphs = {
  thinking = "loader",
  running_tool = "terminal-2",
  searching = "search",
  fetching = "download",
  error = "alert-circle",
}

local colors = {
  idle = "on_surface",
  thinking = "primary",
  running_tool = "tertiary",
  searching = "tertiary",
  fetching = "tertiary",
  error = "error",
}

local statusText = {
  idle = function() return tr("status_idle", "Ready") end,
  thinking = function() return tr("status_thinking", "Thinking...") end,
  running_tool = function() return tr("status_running_tool", "Running command...") end,
  searching = function() return tr("status_searching", "Searching web...") end,
  fetching = function() return tr("status_fetching", "Fetching page...") end,
  error = function() return tr("status_error", "Error") end,
}

local function apply(status)
  status = status or "idle"
  barWidget.setGlyph(glyphs[status] or idleGlyph())
  barWidget.setGlyphColor(colors[status] or "on_surface")
  local text = (statusText[status] or statusText.idle)()
  barWidget.setTooltip(tr("tooltip", "AI Chat — " .. text, { status = text }))
end

function update()
  apply(noctalia.state.get("aichat.status"))
end

function onClick()
  noctalia.togglePanel("hieunm3103/aichat:chat")
end

noctalia.state.watch("aichat.status", apply)

apply(noctalia.state.get("aichat.status"))
