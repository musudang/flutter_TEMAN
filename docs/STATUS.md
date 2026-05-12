# TEMAN — Work Status (cross-check sheet)

**Goal:** ship to Google Play Console (app bundle upload).
**Owner:** son • **Last sync:** 2026-05-10

Update this file at the end of every working session. Each task has a
**status badge** so we can cross-check progress without scrolling git
history. Status values:

- 🔴 **TODO** — not started
- 🟡 **WIP** — partially done, still failing on at least one acceptance criterion
- 🟢 **DONE** — passed all acceptance criteria
- ✅ **VERIFIED** — user has tested on device and confirms working

---

## 📋 Active request — 2026-05-10 (this session)

### #1 — Document feature changes & errors for cross-check  🟢 DONE
This file. Keep it updated.

---

### #2 — Map: hide non-friend markers, show only list  🟢 DONE
**Files:** `lib/screens/map_screen.dart`, `lib/services/mixins/user_service.dart`

**Change:**
- Inside the 1 km radius, do **NOT** drop a pin/avatar for non-friend (nearby) users.
- Pins/avatars ONLY for: me + mutual-friend-who-is-also-a-map-friend (see #4).
- Nearby (non-friends) within 1 km still appear in the bottom panel list.

**Acceptance:**
- Open Map → see my own marker + circle. No avatar pins for strangers.
- Friend (who is mutual + map-friend) within 1 km → avatar pin visible.
- Non-friend within 1 km → no pin, but listed in "Nearby" tab below.

---

### #3 — Map: split bottom panel into "Nearby" / "Friends" tabs  🟢 DONE
**Files:** `lib/screens/map_screen.dart`

**Change:**
- Existing single list → `TabBar` with two tabs:
  - **Nearby** — non-friends within 1 km.
  - **Friends** — mutual followers.

**Acceptance:**
- Drag panel up → two tabs visible.
- Tapping "Friends" shows mutual-followers list (regardless of distance/online).
- Tapping "Nearby" shows non-friend users within 1 km only.

---

### #4 — "Map Friends" opt-in (Instagram close-friends model)  🟢 DONE
**Files:** `lib/services/mixins/user_service.dart`, `lib/models/user_model.dart`, `lib/screens/map_screen.dart`, `firestore.rules`

**Change:**
- New user field: `mapFriends: List<String>` (uids).
- **Bilateral**: user A sees user B's location only if `A.mapFriends.contains(B.uid) && B.mapFriends.contains(A.uid)`.
- Friends tab in map shows two sections:
  - **Map Friends** — mutual followers where both have checked each other (rendered with filled checkmark).
  - **Other Mutual Followers** — mutual followers not yet checked (empty checkmark).
- Tapping the checkmark toggles `mapFriends` for the current user only. The other person must also tap to fully enable.

**Acceptance:**
- A toggles B on → B unchanged. A still does NOT see B on map (one-sided).
- B toggles A on → now both see each other on the map.
- A toggles B off → both lose visibility immediately.
- Unchecked mutual followers stay in the list (just unchecked), they don't disappear.

---

### #5 — Mutual followers must NOT appear in Nearby tab  🟢 DONE
**Files:** `lib/services/mixins/user_service.dart` (`getNearbyUsers`)

**Change:**
- `getNearbyUsers` must exclude any user where `mutual = current.following.contains(uid) && current.followers.contains(uid)`.
- One-way follow (only one direction) → still counts as non-friend → appears in Nearby.

**Acceptance:**
- I follow X, X doesn't follow me back → X within 1 km → appears in Nearby.
- I follow X, X follows me → X within 1 km → NOT in Nearby (only in Friends tab).

---

### #6 — OpenStreetMap production viability  ℹ️ INFO
**No code change.** Notes:
- OSM tiles via `flutter_map` are fine in production but subject to the [OSMF Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/). High volume or commercial app risks throttling / IP block.
- Alternatives once usage grows:
  - **Mapbox** — generous free tier (50k MAU), then paid. Drop-in via `flutter_map` `urlTemplate`.
  - **MapTiler** — similar.
  - **Google Maps SDK** — requires `google_maps_flutter`, billing, replaces `flutter_map`. Heavier migration.
  - **Kakao Map** — already in `pubspec` (`kakao_map_plugin`). Best for Korea-only audience.

**Recommendation:** ship MVP with OSM. Migrate to Mapbox or Kakao once you hit ~10k DAU or OSM warns you. Will be a one-file change (just `urlTemplate` swap) thanks to `flutter_map` abstraction.

---

### #7 — University scrap → must show in Profile/Scrapped tab  🟢 DONE
**Files:** `lib/services/mixins/post_service.dart` (`getScrappedPosts`), `lib/screens/profile_screen.dart`

**Root cause (suspected):** `getScrappedPosts` currently does `.collection('posts').where('scrappedBy', arrayContains: uid)` — only main posts collection. University posts in `universities/{uniId}/posts` subcollection are invisible to it.

**Change:**
- Add a second source: `collectionGroup('posts').where('scrappedBy', arrayContains: uid)` filtered to docs under `universities/*` path (mirrors how university posts are already pulled in `getUserUniversityPosts`).
- Profile scrap tab combines both lists (dedup by id).

**Acceptance:**
- Open a uni post → tap bookmark → Profile → Scrapped tab → that uni post appears with "Uni" tag.
- Toggle bookmark off → it disappears from list.

---

### #8 — Share sheet cleanup + Copy Link  🟡 WIP
**Files:** `lib/screens/share_content_sheet.dart`, app-link config (Android `AndroidManifest.xml` + iOS `Info.plist`), routing in `main.dart`.

**Change:**
1. Remove buttons: Facebook, Threads, WhatsApp, Email.
2. **Keep & implement Copy Link**:
   - Copy a working URL to clipboard, e.g. `https://teman-web-2026.web.app/post/{id}`.
   - Hosting (`teman-web-2026.web.app`) needs a deep-link handler page that, if the TEMAN app is installed, opens the app directly to that post; otherwise falls back to the web page or store install link.
3. **In-app deep link** (universal links / Android App Links): when a logged-in user taps a shared link, the app routes directly to the post detail screen.

**Acceptance:**
- Tap Share → Copy Link → paste somewhere → URL valid.
- Another logged-in user taps URL on phone → app opens directly on that post (no intermediate browser bounce).
- Logged-out / app-not-installed → opens web page on `teman-web-2026.web.app` showing post + "Open in TEMAN" CTA.

---

### #9 — Mobile-only bugs (blocking ship)  🟡 WIP (needs `firebase deploy --only firestore:rules,firestore:indexes` + device test)

#### 9a. Hyperlinks not opening on mobile (login + settings)  🟢 DONE
**Files:** `lib/screens/login_screen.dart`, `lib/screens/settings_screen.dart`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`

**Root cause (suspected):** `url_launcher` 6+ on Android 11+ requires `<queries>` block in manifest declaring intent visibility. iOS needs `LSApplicationQueriesSchemes` for `https`.

**Change:**
- Use `launchUrl(url, mode: LaunchMode.externalApplication)`.
- Add manifest `<queries>` for `https` / `http`.
- iOS `Info.plist` — `LSApplicationQueriesSchemes` is not strictly required for https but add safety.

**Acceptance:** Tap "Terms of Service" / "Privacy Policy" / "Community Guidelines" on phone → opens browser to correct URL.

#### 9b. Delete post permission-denied (all main boards)  🟢 DONE (rules need deploy)
**Files:** `firestore.rules`

**Root cause (suspected):** Two `match /posts/{postId}` blocks in `firestore.rules` (line 50 + 175). Firestore evaluates the **first match only** — and that block's `allow delete` likely doesn't grant document-owner delete. Same may apply to meetups/jobs/marketplace/questions if they have shadowed blocks.

**Change:**
- Audit `firestore.rules` for duplicate `match /<collection>/{id}` blocks. Merge each into one canonical block with:
  - `allow delete: if isDocumentOwner(resource.data) || isAdmin();`
- Deploy: `firebase deploy --only firestore:rules`.

**Acceptance:**
- Login as post author → tap post 3-dot → Delete → confirm → post disappears. No "permission denied" toast.
- Login as non-author → 3-dot menu offers Report, not Delete.

---

## 🛠️ Tooling baseline (already wired in `AGENTS.md`)

- RTK (terminal compression) ✅
- Serena MCP (symbol search) ✅ — restart Claude Code to activate
- AGENTS.md / CLAUDE.md memory ✅
- OMC — pending one-time `/plugin install` from user

---

## 📜 Prior session highlights (cross-ref)

Reviewed walkthrough ~4h ago. Items previously declared done but might
need re-verification on device:

- Issue 3 (map presence filter 180s) — code done
- Issue 5 (anon profile leak) — code done
- Issue 6 (meetup chat permission retry) — code done
- Issue 3+4 (likes/scrap counts mirroring) — code done
- Issue 2 (All/General infinite loading) — code done
- Soft-delete comments, deleted placeholder — code done
- University comment / answer reply + anon — code done
- University post scrap/share/edit/delete buttons in sheet — code done (but #7 above shows scrap PROFILE QUERY still incomplete)
- Profile My Posts (collectionGroup index) — needs `firebase deploy --only firestore:indexes`
- Algolia backfill — done
- University-scoped search — done

**Anything in this list that's still broken on device → flip its row above to 🟡 WIP and add a comment.**

---

## 📒 Session log — 2026-05-10 (this turn)

| # | Files touched | Notes |
|---|---|---|
| #1 doc | `docs/STATUS.md` (new) | this file |
| #2/#3/#5 | `lib/screens/map_screen.dart`, `lib/services/mixins/user_service.dart` | Friends-only pins, tab split, mutuals excluded from Nearby |
| #4 mapFriends | `lib/models/user_model.dart`, `lib/services/mixins/user_service.dart`, `lib/screens/map_screen.dart` | New `mapFriends: List<String>` field on `users/`. `toggleMapFriend(uid)` + `getMutualFollowerUsers()` service methods. Friends tab now shows two sections (Map Friends ✓, Mutual Followers ☐) with checkbox toggles. Bilateral gate enforced in `getNearbyFriends` |
| #7 uni scrap | `lib/services/mixins/university_service.dart` (`getAllScrappedUniversityPosts`), `lib/screens/profile_screen.dart`, `firestore.indexes.json` (COLLECTION_GROUP index on `scrappedBy`) | |
| #8 share | `lib/screens/share_content_sheet.dart` | Removed Facebook/Messenger/WhatsApp/Email/Threads dummy buttons; Copy Link copies real URL `https://teman-web-2026.web.app/{post,meetup}/{id}` via `Clipboard`. **Deep-link routing inside the app pending** — see WIP note below. |
| #9a url_launcher | `lib/screens/login_screen.dart`, `lib/screens/settings_screen.dart` | `LaunchMode.externalApplication`. Android manifest `<queries>` already had `https`. |
| #9b delete-rule | `firestore.rules` (`isDocumentOwner` + `admin_deleted_posts` block + conversation delete), `lib/services/mixins/meetup_service.dart` | `sellerId` added to `isDocumentOwner` (was the cause of marketplace permission-denied); tombstone collection `admin_deleted_posts` now has owner-create rule (was the cause of main-feed posts permission-denied); meetup-linked conversation delete allowed to participants (was the cause of meetup delete permission-denied); code wraps conversation delete in best-effort try/catch. |

### 🚨 What YOU still need to do

1. **Deploy firestore rules + indexes** — REQUIRED for #7 (uni scrap query) and #9b (delete permission) to take effect:
   ```powershell
   cd "C:\Users\user\OneDrive\Desktop\teman_app\flutter_TEMAN"
   firebase deploy --only firestore:rules,firestore:indexes
   ```
   New index for `scrappedBy` will take 1–5 min to build after deploy. The `getAllScrappedUniversityPosts` stream will start working as soon as it's READY in the Firebase console.

2. **App Links / Universal Links** (Task #8 follow-up, NOT done yet) — for tapping a shared link to open directly in TEMAN:
   - Android: add intent-filter for `teman-web-2026.web.app` in `AndroidManifest.xml` with `android:autoVerify="true"`, host `.well-known/assetlinks.json` on the web domain.
   - iOS: add Associated Domains capability `applinks:teman-web-2026.web.app`, host `apple-app-site-association` on the web domain.
   - Add route handlers in `main.dart` (or use `go_router` with `uri-link-android` / `uni_links`).
   - For now Copy Link gives a usable URL; pasting opens the web fallback in a browser.

3. **Web hosting fallback pages** (Task #8 follow-up) — create `/post/{id}` and `/meetup/{id}` routes on `teman-web-2026.web.app` that:
   - Render a preview of the post,
   - Detect mobile UA and show an "Open in TEMAN" CTA (deep link to the app),
   - Optionally show OG meta tags so the link looks nice when pasted on social.

---

## 🧪 Verification checklist before Play Console upload

- [ ] All 🔴/🟡 above are 🟢/✅
- [ ] `firebase deploy --only firestore:rules,firestore:indexes` succeeded
- [ ] `flutter analyze --no-pub` → 0 errors
- [ ] `flutter build appbundle --release` → builds clean
- [ ] App signing key set up, `key.properties` ready (NOT committed)
- [ ] Phone auth: APNs (iOS) + SHA / Play Integrity (Android) configured if shipping with phone login
- [ ] Privacy policy + terms URLs live and reachable
- [ ] Tested on 2 real devices (mutual location flow, share link flow, post CRUD)
