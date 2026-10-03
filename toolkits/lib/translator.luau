--!nonstrict
-- Toolkits — shared translation client and language list, used by the
-- Translate panel, the OCR result panel and the service's OCR translate.
--
-- `translate(text, source, target, onDone)` calls Google Translate's public
-- `translate_a/single` endpoint or DeepL's `v2/translate` endpoint, picked by
-- the "translate-provider" setting, and calls
-- `onDone(translated, err, detected, dict)` once: `translated` is nil on
-- failure with a user-facing `err`; `detected` is the detected source code;
-- `dict` holds Google's dictionary alternatives for short queries. `source`
-- may be "auto". Ported from noctalia/translator.

local M = {}

-- Languages offered in the translate pickers, in display order. DeepL accepts
-- a subset; an unsupported pick surfaces as the provider's error message.
M.LANGUAGES = {
  { code = "en", name = "English" },
  { code = "vi", name = "Tiếng Việt" },
  { code = "zh", name = "中文" },
  { code = "ja", name = "日本語" },
  { code = "ko", name = "한국어" },
  { code = "fr", name = "Français" },
  { code = "de", name = "Deutsch" },
  { code = "es", name = "Español" },
  { code = "pt", name = "Português" },
  { code = "it", name = "Italiano" },
  { code = "ru", name = "Русский" },
  { code = "uk", name = "Українська" },
  { code = "pl", name = "Polski" },
  { code = "nl", name = "Nederlands" },
  { code = "sv", name = "Svenska" },
  { code = "da", name = "Dansk" },
  { code = "no", name = "Norsk" },
  { code = "fi", name = "Suomi" },
  { code = "cs", name = "Čeština" },
  { code = "sk", name = "Slovenčina" },
  { code = "hu", name = "Magyar" },
  { code = "ro", name = "Română" },
  { code = "bg", name = "Български" },
  { code = "el", name = "Ελληνικά" },
  { code = "tr", name = "Türkçe" },
  { code = "ar", name = "العربية" },
  { code = "he", name = "עברית" },
  { code = "fa", name = "فارسی" },
  { code = "ur", name = "اردو" },
  { code = "hi", name = "हिन्दी" },
  { code = "th", name = "ไทย" },
  { code = "id", name = "Bahasa Indonesia" },
}

local RTL = { ar = true, he = true, fa = true, ur = true }

function M.langName(code)
  for _, l in ipairs(M.LANGUAGES) do
    if l.code == code then return l.name end
  end
  return code
end

function M.isRTL(code)
  return RTL[code] == true
end

-- The "translate-target-lang" setting, lowercased; "en" when unset.
function M.defaultTarget()
  local v = noctalia.getConfig("translate-target-lang")
  return if type(v) == "string" and v ~= "" then v:lower() else "en"
end

local DICT_MAX_GROUPS = 4
local DICT_MAX_TERMS = 8

local function tr(key, subst)
  if subst then return noctalia.tr(key, subst) end
  return noctalia.tr(key)
end


-- Google's `dt=bd` block: { { "noun", { "term", ... }, ... }, ... }.
local function parseDictionary(block)
  if type(block) ~= "table" then return nil end
  local groups = {}
  for _, entry in block do
    if #groups >= DICT_MAX_GROUPS then break end
    if type(entry) == "table" and type(entry[1]) == "string" and type(entry[2]) == "table" then
      local terms = {}
      for _, term in entry[2] do
        if #terms >= DICT_MAX_TERMS then break end
        if type(term) == "string" then table.insert(terms, term) end
      end
      if #terms > 0 then table.insert(groups, { pos = entry[1], terms = terms }) end
    end
  end
  return if #groups > 0 then groups else nil
end

-- Google returns [[[ "segment", "orig", ... ], ...], dictionary, "detected"]; the
-- translation is the concatenation of segment[1] across the first array.
local function parseGoogle(body)
  local decoded = noctalia.json.decode(body)
  if type(decoded) ~= "table" or type(decoded[1]) ~= "table" then return nil end
  local parts = {}
  for _, segment in decoded[1] do
    if type(segment) == "table" and type(segment[1]) == "string" then
      table.insert(parts, segment[1])
    end
  end
  if #parts == 0 then return nil end
  local source = if type(decoded[3]) == "string" then decoded[3]:lower() else nil
  return table.concat(parts), source, parseDictionary(decoded[2])
end

-- Maps a failed response to a user-facing message. `extra` holds provider-specific keys.
local function httpError(res, extra)
  if not res.ok or res.status == 0 then return tr("translate.errors.connection") end
  if extra and extra[res.status] then return tr(extra[res.status]) end
  if res.status == 400 then return tr("translate.errors.invalid_target")
  elseif res.status == 429 then return tr("translate.errors.rate_limit")
  elseif res.status >= 500 then return tr("translate.errors.server") end
  return tr("translate.errors.generic")
end

-- POST keeps long text out of the URL, which Google caps well below MAX_CHARS.
local function fetchGoogle(text, source, target, onDone)
  noctalia.http({
    method = "POST",
    url = `https://translate.googleapis.com/translate_a/single?client=dict-chrome-ex&sl={noctalia.string.urlEncode(source)}&tl={noctalia.string.urlEncode(target)}&dt=t&dt=bd`,
    headers = { "Content-Type: application/x-www-form-urlencoded;charset=utf-8" },
    body = "q=" .. noctalia.string.urlEncode(text),
  }, function(res)
    if not res.ok or res.status >= 400 then
      onDone(nil, httpError(res))
      return
    end
    local translated, detected, dict = parseGoogle(res.body)
    if translated then onDone(translated, nil, detected, dict)
    else onDone(nil, tr("translate.errors.generic")) end
  end)
end

local DEEPL_ERRORS = {
  [403] = "translate.errors.deepl_auth",
  [456] = "translate.errors.deepl_quota",
}

-- DeepL uses NB for Norwegian Bokmål and does not accept NO.
local function deeplCode(code)
  local upper = code:upper()
  return if upper == "NO" then "NB" else upper
end

local function fetchDeepL(text, source, target, onDone)
  -- Trim: a pasted key often carries trailing whitespace, which would break both the
  -- free-tier suffix test below and the Authorization header.
  local configured = noctalia.getConfig("translate-deepl-api-key")
  local apiKey = if type(configured) == "string" then noctalia.string.trim(configured) else ""
  if apiKey == "" then
    onDone(nil, tr("translate.errors.deepl_no_key"))
    return
  end

  -- Free-tier keys end in ":fx" and are only valid against the free endpoint.
  local url = if apiKey:match(":fx$")
    then "https://api-free.deepl.com/v2/translate"
    else "https://api.deepl.com/v2/translate"

  local request = { text = { text }, target_lang = deeplCode(target) }
  if source ~= "auto" then request.source_lang = deeplCode(source) end

  noctalia.http({
    method = "POST",
    url = url,
    headers = { `Authorization: DeepL-Auth-Key {apiKey}`, "Content-Type: application/json" },
    body = noctalia.json.encode(request),
  }, function(res)
    if not res.ok or res.status >= 400 then
      onDone(nil, httpError(res, DEEPL_ERRORS))
      return
    end
    local decoded = noctalia.json.decode(res.body)
    local first = type(decoded) == "table" and type(decoded.translations) == "table" and decoded.translations[1]
    if type(first) == "table" and type(first.text) == "string" then
      local detected = first.detected_source_language
      onDone(first.text, nil, if type(detected) == "string" then detected:lower() else nil)
    else
      onDone(nil, tr("translate.errors.generic"))
    end
  end)
end

function M.provider()
  local provider = noctalia.getConfig("translate-provider")
  return if provider == "deepl" then "deepl" else "google"
end

function M.translate(text, source, target, onDone)
  local fetch = if M.provider() == "deepl" then fetchDeepL else fetchGoogle
  fetch(text, source or "auto", target, onDone)
end

return M
