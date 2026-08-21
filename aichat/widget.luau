local status = noctalia.state.get("aichat.status") or "idle"

-- The idle glyph is the user's `glyph` setting; the busy states override it.
local function idleGlyph()
  local configured = noctalia.getConfig("glyph")
  if type(configured) == "string" and configured ~= "" then return configured end
  return "message-chatbot"
end

local glyphs = {
  thinking = "loader",
  tool = "terminal-2",
  error = "alert-circle",
}

local colors = {
  idle = "on_surface",
  thinking = "primary",
  tool = "tertiary",
  error = "error",
}

function update()
  status = noctalia.state.get("aichat.status") or "idle"
  barWidget.setGlyph(glyphs[status] or idleGlyph())
  barWidget.setGlyphColor(colors[status] or "on_surface")
  local tooltip = status == "idle" and "AI Chat — Ready" or "AI Chat — " .. status
  barWidget.setTooltip(tooltip)
end

function onClick()
  noctalia.togglePanel("hieunm3103/aichat:chat")
end

noctalia.state.watch("aichat.status", function(newStatus)
  status = newStatus or "idle"
  barWidget.setGlyph(glyphs[status] or idleGlyph())
  barWidget.setGlyphColor(colors[status] or "on_surface")
  local tooltip = status == "idle" and "AI Chat — Ready" or "AI Chat — " .. status
  barWidget.setTooltip(tooltip)
end)
