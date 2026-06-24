# MCP server for the admin area

## Context

The caregiver currently manages users/tasks/task definitions/reminder definitions only through the `/admin` web UI. The goal is to let a caregiver drive the same actions from the Claude app via a remote MCP server, so they can manage chores conversationally instead of clicking through admin pages. This needs:

1. An MCP server (JSON-RPC over Streamable HTTP) exposing the 11 requested actions + 2 added for parity (delete on task/reminder definitions).
2. OAuth 2.1 + Dynamic Client Registration (RFC 7591) so Claude's remote-MCP connector can self-register and obtain a token, since this app has no per-user accounts to plug into a library's resource-owner model.
3. Per the user's own design: the OAuth authorize step, after the existing admin password login, also asks the caregiver to pick **which household member** the resulting token represents. Tools default to that user when `user_id` is omitted (supports "my tasks"-style usage), but every tool still accepts an explicit `user_id` to act on any user, matching full admin scope.

Decisions already made with the user: hand-roll OAuth (no Doorkeeper — it has no DCR support and no resource-owner concept that fits this app), auto-approve consent after login (single admin, no scope picking), and add `delete_task_definition`/`delete_reminder_definition` for parity even though not explicitly requested.

## OAuth design (stateless, signed tokens — no token/grant DB tables)

Confirmed via the `mcp` gem's own README that the Rails integration pattern is exactly: build a fresh `MCP::Server` + `MCP::Server::Transports::StreamableHTTPTransport.new(server, stateless: true, enable_json_response: true)` per request inside a normal controller action, passing `server_context: {...}` for per-request data, then:
```ruby
status, headers, body = transport.handle_request(request)
render(json: body.first, status: status, headers: headers)
```
This is the load-bearing fact that makes per-user-scoped tokens easy: each MCP request builds its own server with `server_context: { current_user: @mcp_user }`.

Only **one** new DB table is needed — registered OAuth clients (so revocation is possible by deleting a row). Authorization codes, access tokens, and refresh tokens are all `ActiveSupport::MessageVerifier`-signed payloads (via `Rails.application.message_verifier(:mcp_oauth)`, keyed off `SECRET_KEY_BASE` — same mechanism Rails already uses for session cookies, so no new secret to manage). `MessageVerifier#generate(payload, expires_in:, purpose:)` gives built-in expiry and purpose-tagging for free, and `#verify` raises `ActiveSupport::MessageVerifier::InvalidSignature` for both tampering and expiry. All clients are treated as public clients (`token_endpoint_auth_method: "none"`) using PKCE (S256) — no client_secret stored or checked, which keeps DCR trivial and matches OAuth 2.1's recommended practice for this kind of client.

- **`Oauth::Client`** (`app/models/oauth/client.rb`) — new model/table: `client_id` (string, unique), `client_name` (string), `redirect_uris` (`string`, array: true). Migration: `db/migrate/..._create_oauth_clients.rb`.
- **`POST /oauth/register`** (`Oauth::ClientsController#create`, public, outside `/admin`) — RFC 7591 DCR: reads `redirect_uris`/`client_name` from the JSON body, creates an `Oauth::Client` with `client_id: SecureRandom.hex(16)`, responds with the registration JSON (`client_id`, `client_id_issued_at`, `redirect_uris`, `token_endpoint_auth_method: "none"`, `grant_types: ["authorization_code", "refresh_token"]`, `response_types: ["code"]`).
- **`GET /.well-known/oauth-authorization-server`** and **`GET /.well-known/oauth-protected-resource`** (`WellKnownController`, public) — static JSON discovery metadata (RFC 8414 / RFC 9728): issuer/endpoints/`code_challenge_methods_supported: ["S256"]` for the first, `resource` (the `/mcp` URL) + `authorization_servers` for the second. The protected-resource one is what `Mcp::ServerController`'s 401 `WWW-Authenticate` header points clients at when they probe `/mcp` with no token — this is how Claude's connector bootstraps the whole flow.
- **`GET/POST /oauth/authorize`** (`Oauth::AuthorizationsController`, public route but requires the *existing* admin session) — validates `client_id`/`redirect_uri` against the registered `Oauth::Client`. If not logged in, stash `request.fullpath` and redirect to `login_path`; extend `SessionsController#create` to redirect back there afterward (store as `session[:return_to_after_login]`, only honored if it starts with `/oauth/authorize`, cleared after use). Once authenticated, `GET` renders `Views::Oauth::Authorize` — a form listing every `User` as a radio button (caregiver picks which household member this token acts as) plus hidden fields for all the OAuth params. `POST` builds the authorization code: `message_verifier.generate({client_id:, redirect_uri:, code_challenge:, user_gid: user.to_gid.to_s}, expires_in: 2.minutes, purpose: :oauth_code)`, then redirects to `redirect_uri` with `code`/`state`.
- **`POST /oauth/token`** (`Oauth::TokensController#create`, public) —
  - `grant_type=authorization_code`: verify the code (purpose `:oauth_code`), check `client_id`/`redirect_uri` match, check PKCE (`Digest::SHA256.base64digest(code_verifier)` discards padding/converts to URL-safe form to match `code_challenge`), then mint `access_token` (`purpose: :oauth_access_token`, `expires_in: 1.hour`, payload `{client_id:, user_gid:}`) and `refresh_token` (`purpose: :oauth_refresh_token`, `expires_in: 90.days`, same payload). Respond with the standard token JSON.
  - `grant_type=refresh_token`: verify the refresh token, re-check `Oauth::Client.exists?(client_id:)` (so deleting the client immediately revokes it), mint a fresh access token.
- **Revocation UI**: `Admin::OauthClientsController` (index + destroy), under the existing `/admin` namespace/auth gate, listing registered clients with a "Revoke" button — without this there'd be no way to cut off a connected Claude account short of a DB shell. Add a nav link in `app/views/layouts/nav.rb`.

## MCP server design

- **`Mcp::ServerController#endpoint`** (`app/controllers/mcp/server_controller.rb`), routed via `match "/mcp", to: "mcp/server#endpoint", via: [:get, :post, :delete]`, outside `/admin` (own auth mechanism), `skip_forgery_protection` (no session/CSRF token, same reasoning as the Twilio webhook).
  - `before_action :authenticate!`: pull `Authorization: Bearer <token>`, verify with `message_verifier.verify(token, purpose: :oauth_access_token)`; on any failure (missing header, bad signature, expired) or `Oauth::Client.exists?(client_id:)` returning false or the `User` from `user_gid` no longer existing, respond 401 with `WWW-Authenticate: Bearer resource_metadata="<oauth-protected-resource URL>"` per RFC 9728.
  - Action body: `server = MCP::Server.new(name: "chore_reminder", tools: Mcp::TOOL_REGISTRY, server_context: { current_user: @mcp_user })`, `transport = MCP::Server::Transports::StreamableHTTPTransport.new(server, stateless: true, enable_json_response: true)`, `status, headers, body = transport.handle_request(request)`, `render(json: body.first, status: status, headers: headers)` — the exact pattern from the gem's README.
- **Tools** live under `app/mcp/tools/*.rb` (new `app/mcp` dir, auto-added to Zeitwerk autoload paths like every other `app/*` dir), one `MCP::Tool` subclass per action, namespaced `Mcp::Tools::*`. A small shared helper (`Mcp::Tools::ResolvesUser`, a module to `extend` into each tool) resolves the target `User` from an optional `user_id` input arg (numeric id or username, via `User.find_by_param!`) defaulting to `server_context[:current_user]`.
  - `list_users` — no input; lists all users (id, username, name, phone_number, time_zone).
  - `list_tasks` (`user_id?`, `done?` bool) — mirrors `Admin::TasksController#tasks_for_filter`.
  - `toggle_task` (`user_id?`, `task_id!`) — mirrors `#toggle_done`: capture `Task.next_for(user)&.id`, `task.update!(done: !task.done)`, enqueue `NotifyNextTaskChangedJob`.
  - `move_task` (`user_id?`, `task_id!`, `direction!` enum `higher`/`lower`) — mirrors `#move_higher`/`#move_lower` + the same notify.
  - `delete_task` (`user_id?`, `task_id!`) — mirrors `#destroy` + notify.
  - `list_task_definitions` (`user_id?`) — id/slug/name/description/time_of_day/recurrence_days.
  - `create_task_definition` / `update_task_definition` (`user_id?`, plus `name`/`description`/`time_of_day`/`recurrence_days`, required on create) — same permitted fields as `Admin::TaskDefinitionsController#task_definition_params` (no `images`; file upload isn't meaningful over MCP).
  - `delete_task_definition` (`user_id?`, `task_definition_id!`).
  - `list_reminder_definitions` / `create_reminder_definition` / `update_reminder_definition` (`user_id?`, `time_of_day`) — mirrors `Admin::ReminderDefinitionsController`.
  - `delete_reminder_definition` (`user_id?`, `reminder_definition_id!`).
  - Each tool rescues `ActiveRecord::RecordNotFound`/failed `.save` and returns `MCP::Tool::Response.new([{type: "text", text: "..."}], error: true)` rather than raising, so the model gets an actionable error instead of a generic JSON-RPC failure.

## Gemfile

Add `gem "mcp"` (official Ruby MCP SDK, confirmed on rubygems, brings in `rack` for the Streamable HTTP transport — already present transitively via Rails). No new gem needed for OAuth (hand-rolled) or signing (`ActiveSupport::MessageVerifier`/`GlobalID`, both already part of Rails).

## Testing

- `test/models/oauth/client_test.rb` — validations.
- `test/controllers/oauth/clients_controller_test.rb` — DCR happy path + malformed body.
- `test/controllers/oauth/authorizations_controller_test.rb` — not-logged-in redirects to `/login` and back (using the `delete logout_path` pattern from `test/controllers/sessions_controller_test.rb` to defeat the test helper's auto-login), unknown `client_id`/mismatched `redirect_uri` rejected, successful flow redirects to `redirect_uri` with a `code`.
- `test/controllers/oauth/tokens_controller_test.rb` — full code+PKCE exchange, wrong `code_verifier` rejected, expired/tampered code rejected, refresh grant, refresh fails after the client is deleted.
- `test/controllers/mcp/server_controller_test.rb` — 401 with no token and with a token whose client was deleted (check `WWW-Authenticate` header), then `tools/list` and `tools/call` for a representative few tools (`list_users`, `toggle_task`, a definition create) against a token minted via the real flow (or directly via `Rails.application.message_verifier(:mcp_oauth).generate(...)` to keep tests focused).
- `test/controllers/well_known_controller_test.rb` — metadata shape.
- One end-to-end integration test driving DCR → authorize (incl. picking a fixture user) → token → an actual `tools/call` over `/mcp`, to prove the whole loop works together, not just each piece in isolation.
- Manual verification: register a client via `curl` against `/oauth/register`, walk `/oauth/authorize` in a browser logged into the running dev server, exchange the code via `curl` against `/oauth/token` (PKCE verifier computed by hand or a small script), then call `/mcp` with `tools/list`/`tools/call` via `curl` to confirm the JSON-RPC responses look right before trying the real Claude app connector.
