# TEMAN Flutter App — Agent Rules & Project Memory

**Single source of truth for every AI agent (Claude Code, Antigravity, Cursor, etc.) working on this repo.**
Read this file first; everything else (CLAUDE.md, `.agents/rules/*`, RTK.md) is loaded into the same agent context.

---

## 🛡️ Hard rules (NEVER violate)

1. **Multi-agent compatibility** — This repo is touched by Antigravity, Claude, and others. **Never restructure, reformat, or "clean up" code that you didn't author**. Preserve existing comments, blank lines, brace style, and import order. Other agents grep for landmarks; rewriting them quietly breaks their workflows.
2. **Edit, don't rewrite** — Prefer `Edit`/patch operations over full file rewrites. If you must rewrite, justify it in a comment block at the top of the diff.
3. **Optional-only signature changes** — When adding parameters to functions/methods/widgets, make them **optional named parameters** so existing call sites compile unchanged.
4. **Never commit secrets** — `service-account-key.json`, `.p8` APNs keys, `.env`, anything under `scripts/*service-account*`. The `.gitignore` matches multiple variants on purpose; do not loosen it.
5. **No git pushes / destructive ops without explicit ask** — `git push --force`, `git reset --hard`, `git clean -fd`, `firebase deploy --force`. Always confirm.

---

## 📦 Project at a glance

- **Stack**: Flutter (Dart) mobile app + Firebase (Auth, Firestore, Storage, FCM, Functions extensions)
- **Auth methods**: Google sign-in (works), Phone (in setup — needs APNs key on iOS, Play Integrity on Android, SHA fingerprints in Firebase)
- **Search**: Algolia via `firestore-algolia-search` extension (5 indices: `posts`, `meetups`, `questions`, `jobs`, `marketplace`). University board posts live in `universities/{uniId}/posts` subcollection and are **searched client-side** (see `university_search_screen.dart`).
- **Cost plan**: Blaze (paid).
- **OS / shell**: Windows 11 + PowerShell 5.1 + git-bash. **No WSL** at the moment.

### Boards
| Board | Storage | Notes |
|---|---|---|
| Main posts (general / events / qna) | `posts/{id}` | post_detail_screen.dart |
| Meetups | `meetups/{id}` (+ `comments` subcoll, `conversations/{meetupId}` for chat) | meetup_*.dart |
| Jobs | `jobs/{id}` | jobs_screen.dart |
| Marketplace | `marketplace/{id}` | marketplace_*.dart |
| University posts | `universities/{uniId}/posts/{id}` (+ `comments` subcoll) | university_feed_screen.dart |
| University Q&A | `universities/{uniId}/questions/{id}` (+ `answers` subcoll) | university_qna_detail_screen.dart |

### Comment system invariants (apply to every board)
- Soft-delete when a comment has replies (`isDeleted: true`, content cleared) → render `DeletedCommentPlaceholder` from `lib/widgets/comment_helpers.dart`
- Anonymous comments: thread-scoped `anonymousIndex` ("Anonymous 1", "Anonymous 2"), university badge **stays visible** even when anonymous, profile-tap is **blocked** for anonymous-by-others
- Long-press a comment → emoji reactions + Reply + Delete sheet (mirrors `post_detail_screen._showReactionReplySheet`)
- Always use `showConfirmDeleteCommentDialog()` from `comment_helpers.dart` before deleting

### Feed invariants
- **Past meetups** (`dateTime < now`) are filtered out of `getMeetups()` and don't count toward the 1-active limit in `addMeetup`/`joinMeetup`. They live on as records in profile only.
- **Engagement counts** (`likes`, `scrapCount`, `shareCount`) are mirrored on the post document in transactions — never display a stale derived count.
- **Map presence**: users with `locationUpdatedAt` older than 180 s are filtered out (`user_service._isUserPresent`). Map heartbeat is 30 s.

---

## 🧰 Tooling (already wired up)

### 1. RTK (Rust Token Killer) — terminal output compression
- Binary: `C:\Users\user\.local\bin\rtk.exe` (v0.39.x)
- Hook: `~/.claude/settings.json` → `PreToolUse.Bash` runs `rtk hook claude`
- Project antigravity rules: `.agents/rules/antigravity-rtk-rules.md`
- Reference doc: `~/.claude/RTK.md` (loaded into every Claude session via `~/.claude/CLAUDE.md`)
- **Use it**: `rtk gain` to see savings; `rtk discover` to find missed opportunities; `rtk proxy <cmd>` to bypass filtering for debugging.

### 2. Serena (LSP MCP) — symbol-precise code search
- Server config: `.mcp.json` (project root) → `uvx --from git+https://github.com/oraios/serena serena start-mcp-server …`
- Context: `ide-assistant`
- **Use it before reading whole files**: `find_symbol`, `find_referencing_symbols`, `get_symbols_overview` save dramatically more tokens than `Read` for any non-trivial code lookup.

### 3. OMC (oh-my-claudecode) — multi-agent orchestration
- Install (one-time, run inside Claude Code):
  ```
  /plugin marketplace add https://github.com/Yeachan-Heo/oh-my-claudecode
  /plugin install oh-my-claudecode
  /oh-my-claudecode:omc-setup
  ```
- After setup: use `/team` for multi-agent jobs, magic keywords `ralph` / `ulw` / `ralplan` for ultrawork mode.

---

## 🧭 Workflow strategy (default play for any task)

1. **Read this file + recent chapter context.** Don't re-derive what's already documented.
2. **Tool selection** for code lookup (in order of preference):
   - Serena (`find_symbol`, `find_referencing_symbols`) — symbol-aware, cheapest
   - `Grep` — text search when symbol name unknown
   - `Read` with offset/limit — only when you already know the exact range
   - **Avoid full-file `Read` of files > 200 lines** unless absolutely needed
3. **Tool selection** for shell commands: just write the normal command (`git status`, `flutter analyze`, …). RTK rewrites it transparently to a compressed-output form.
4. **Edits**: always `Edit` (patch) over `Write` (full rewrite), in line with rule #2 above.
5. **After edits**: run `flutter analyze --no-pub | rg -i error` (RTK will compress) and report only error/warning counts.
6. **Big tasks**: write a Plan first, get user approval, then execute. Use `TodoWrite` to track multi-step work.

---

## 🔗 Memory pointers

- Cross-project memory (different apps): `C:\Users\user\.claude\projects\…\memory\MEMORY.md`
- Per-task feedback notes: keep them short and link them from the relevant section of this file rather than scattering.

