# AI Chat

An AI companion for Noctalia that brings LLM-powered chat and terminal command execution directly
into your desktop. It talks to any OpenAI-compatible endpoint — hosted providers, a local Ollama, or
anything else that speaks `/chat/completions` — and lets you name the model yourself.

This is a personal fork of [Mimir](https://github.com/noctalia-dev/community-plugins/tree/main/mimir)
by Alexander, with custom-model support added.

## Plugin

| Field | Value |
| --- | --- |
| ID | `hieunm3103/aichat` |
| Entries | Bar widget: `status`; panel: `chat`; service: `agent` |

## Requirements

- A [Noctalia](https://noctalia.app) build supporting `plugin_api >= 16`.
- An **OpenAI-compatible API endpoint** with a `/chat/completions` route (`/models` is optional).
- An API key (for hosted providers) or leave empty for local servers (e.g. Ollama).
- `curl` and `python3` on `PATH` for the web search and page-fetch features.
- An internet connection for the no-setup web search feature.

If you use [OpenCode Go](https://opencode.ai/go) with the default OpenCode endpoint, the API key is
auto-detected from `~/.local/share/opencode/auth.json` — no manual setup needed.

## Usage

1. Add the plugin directory as a path source in Noctalia settings.
2. Enable `hieunm3103/aichat` in **Settings → Plugins**.
3. Add the bar widget `hieunm3103/aichat:status` to your bar.

Click the bar icon or toggle the panel from a terminal:

```sh
noctalia msg panel-toggle hieunm3103/aichat:chat
```

The bar icon doubles as a status light: your configured `glyph` when idle, then a spinner while the
model is thinking, a terminal icon while a command runs, a magnifier while searching the web, a
download icon while fetching a page, and an alert icon on error. Hovering shows the same status as a
tooltip.

Type a message and press Enter. Replies render as formatted text — code blocks land in shaded boxes.
Click the copy icon on any message to open its content in a selectable field, then copy the text
manually.

When the model wants to run a terminal command in `ask` permission mode, the panel shows the command
with **Approve** / **Deny** buttons.

## Choosing a model

The row above the chat is the model picker. It lists, in order: the ids from `custom_models`, the
model currently selected, and whatever the endpoint's `/models` route reports.

- **Refresh** (left) re-reads `/models` from the endpoint, sending your API key.
- **Pencil** (right) swaps the picker for a text field: type any model id, press Enter, and it is
  selected and added to the list. Use this for endpoints that do not expose `/models`, or for a
  model the endpoint does not advertise.
- `custom_models` in the settings pins ids permanently — they survive restarts and show up even when
  `/models` is missing or the request fails.
- `default_model` is what gets used before you pick anything.

The selection is kept in memory for the session; `default_model` is what comes back after a restart.

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `api_endpoint` | `string` | `https://opencode.ai/zen/go/v1` | Base URL for the API. Change to `http://localhost:11434/v1` for Ollama. |
| `api_key` | `string` | (auto-detect) | API key. If empty and using the trusted OpenCode endpoint, reads from `~/.local/share/opencode/auth.json`. |
| `default_model` | `string` | `deepseek-v4-flash` | Model used until another one is picked in the panel. |
| `custom_models` | `string` | (empty) | Comma-separated model ids always offered in the picker. |
| `tool_permission` | `enum` | `ask` | `ask` — prompt before commands; `allow` — run automatically; `off` — disable tools. |
| `tool_blocklist` | `string` | `sudo,su,passwd,rm,...` | Comma-separated commands rejected before execution. |
| `web_search_enabled` | `bool` | `true` | Enable or disable web search and public-page fetching. |
| `show_commands` | `bool` | `true` | Show executed commands in the chat. |
| `max_history` | `int` | `50` | Max messages kept in context. |
| `glyph` | `glyph` | `message-chatbot` | Bar icon when idle (per-widget setting). |

## IPC

Send a message without opening the panel:

```sh
noctalia msg plugin hieunm3103/aichat:agent all input "your message"
```

## Notes

- Conversation is ephemeral (in-memory only). Restarting clears it.
- API key auto-detection reads OpenCode Go's auth file at runtime only — never stored or logged.
- Web search uses DuckDuckGo's public HTML endpoint (no key or account). Search queries are sent to DuckDuckGo; results are cached in memory for five minutes and requests time out after 15 seconds. The model treats search results and fetched pages as untrusted data, not instructions.
- Web requests run through a `curl | python3` subprocess (with the bundled `webparse.py`) rather than inside the Luau VM, because Noctalia enforces small per-callback CPU budgets.
- For best results, use a model with tool-calling support.
- Panel and tooltip strings come from `translations/<lang>.json` and fall back to English when a key
  or a language file is missing. Setting labels use the `label_key` entries in the same file.

### Security

This is a trusted desktop plugin that runs the model's shell commands and makes outbound web
requests. This is the security model:

- **API key handling** — the key is read at runtime only and never written to disk, state, or logs. Auto-detection from `~/.local/share/opencode/auth.json` happens only when the endpoint is exactly `https://opencode.ai` on port 443/absent. The key is sent to your configured endpoint (`/chat/completions` and `/models`) and nowhere else — never to DuckDuckGo or fetched pages, which carry only a browser User-Agent and an Accept-Language header.
- **Command execution** — `ask` mode shows every command for approval; `allow` runs non-blocked commands automatically; `off` disables tools. The blocklist rejects destructive, interpreter, and network tools (`sudo`, `rm`, `sh`, `python`, `curl`, `ssh`, `git`, cloud CLIs, and more) as well as shell composition (`;` `|` `&` `>` `<` `` ` `` `$` `\` and newlines). The blocklist is a safety guardrail, not a security boundary — raw shell execution in `allow` mode carries inherent risk.
- **Web fetch** — only accepts `https://` URLs, rejects credentials, private/loopback/link-local IPv4 and IPv6 addresses, `localhost`, `.local` hosts, and numeric/IP obfuscations. Requests verify TLS, follow no redirects, and are restricted to HTTPS. Parser input and output are size- and length-limited and control characters are stripped.
- **Residual risks** — DNS rebinding cannot be fully prevented (Noctalia exposes no DNS resolution API), so `web_fetch` is only for well-known public URLs. Plugins run as trusted code, so a malicious model output combined with `allow` mode can still run commands the blocklist does not cover — review commands in `ask` mode for sensitive work.
