# JUGGLE: handoff tasks that need a human, an account, or a stronger session

Written 2026-07-11, after a review pass fixed everything self-contained and
verifiable in one sitting (see git log around this date). These two items were
deliberately left undone: not because they are technically hard in the "write
better code" sense, but because each is blocked on something no coding
session, however capable, can supply by itself. Read each entry before
starting; the "why not now" is load-bearing, not boilerplate.

---

## 1. Steamworks integration (achievements, cloud saves, Purist leaderboards)

### Why this is a real blocker, not just unstarted work
Steamworks needs a Steam **App ID**, which needs a **Steamworks Partner
account**, which needs Louis to pay Valve's one-time $100 fee and accept the
distribution agreement himself. No AI session can create that account or pay
that fee. Everything below is dead until Louis has done this and can hand over
an App ID.

### What it actually is
"Steamworks" is Valve's SDK and backend that a game talks to for anything
that lives on Steam's servers rather than in your own save file: unlocking
achievements, syncing saves across machines (Steam Cloud), and posting scores
to a shared leaderboard. Godot does not talk to Steamworks natively; the
standard bridge is **GodotSteam**, a community-maintained GDExtension that
wraps Valve's C++ SDK and exposes it to GDScript as a singleton (`Steam.*`).

### Concrete first steps, once Louis has an App ID
1. Register the app on the Steamworks partner site, note the App ID.
2. Download GodotSteam from https://godotsteam.com (matching the 4.7 GDExtension
   build) and drop it into the project per its install instructions. This adds
   binary files per platform, which is the one place this project's
   code-only-art rule doesn't apply (it's engine plumbing, not game content).
3. Steam requires a `steam_appid.txt` file (containing just the App ID) next
   to the executable for local testing before the app is live on Steam, and
   the Steam client must be running in the background for `Steam.steamInit()`
   to succeed. This is why it cannot be tested headlessly or in CI: it needs
   a real, logged-in Steam client on the machine doing the test.
4. Map the existing systems onto Steam features rather than inventing new
   ones:
   - **Cloud saves**: the three slot files (`juggle_slot0.cfg` etc.) already
     live under `user://`, which is exactly what Steam Cloud syncs by default
     once enabled in the Steamworks app settings — this may need close to zero
     code change.
   - **Leaderboards**: `best_scores_purist` (Game.gd, `rec_table()`) is
     already the pure-skill board with stat mitigation stripped out. That is
     the natural leaderboard to publish per venue; the assisted
     `best_scores` board is a reasonable second leaderboard but a lower
     priority.
   - **Achievements**: natural hooks already exist as named events in the
     code rather than needing new tracking — `results_record` (a new venue
     best), the `STORY_REP` milestones (rival/record/finale beats), Purist
     completions, and `career` ledger totals (perfs, tricks, best_streak) are
     all already-computed numbers an achievement check can read directly.
5. Achievements and leaderboards must be configured in the Steamworks web
   dashboard (names, icons, sort order) before the game can post to them —
   this is manual setup on Valve's site, not something a build script can
   automate.

### Suggested split
Partner account + App ID + store page skeleton: Louis, first, before any of
this is worth scheduling. GodotSteam integration + wiring the three features
to the systems above: a dedicated session once the App ID exists, budget a
full session, not a quick pass, since testing requires the real Steam client
and can't be scripted the way this session's export-preset check was.

---

## 2. Steam capsule and library art

### Why this needs Louis's eye, not just more code
The game's whole art identity is "gorgeous by substance, not flash" (ART_AND_MUSIC.md),
built from procedural draw calls with zero imported illustration. That
approach cannot produce a Steam capsule the way it produces gameplay, because
Steam's capsule slots are graded on a completely different job: winning a
half-second glance in a scrolling storefront grid next to hundreds of other
thumbnails, most of which lean on saturated character art or bold typography.
That is a genuinely different design problem from "read the juggling
instantly," and it's a taste call, not an engineering one.

### What Steam actually requires (current sizes, verify against Steamworks
docs before finalizing since Valve revises these occasionally)
- **Header capsule**: 460 x 215 px — shown in search results and category
  pages, arguably the single highest-traffic slot.
- **Small capsule**: 231 x 87 px — wishlists, related-games rows.
- **Main capsule (store page hero)**: 616 x 353 px.
- **Vertical/library capsule**: 600 x 900 px — the grid view in the Steam
  client library.
- **Library hero**: 3840 x 1240 px — the big banner behind the library
  detail page.
- **Library logo**: a transparent-background wordmark/logo overlaid on the
  hero, size varies with placement.
- All must be under Steam's per-asset file-size caps and avoid excessive
  text per Valve's marketing-asset guidelines (a title lockup is fine, dense
  copy is not).

### A starting idea worth trying before commissioning anything
Because the game already renders its own escalating, lit, warm-theatrical
stage entirely in code, the cheapest first draft is not new art but a real
**in-engine capture**: run the game at a high internal resolution, pose the
juggler mid-cascade at the World Arena tier (the grandest built palette), and
crop that render into each required aspect ratio. The `--shot <path>` and
`--establish <n>` dev flags already exist for exactly this kind of capture.
This keeps the capsule visually honest to what buyers actually get, which
cuts both ways: it may look sparse next to illustration-heavy neighbors, but
it never over-promises. Whether that reads as strong enough for the header
capsule specifically (the highest-traffic, most competitive slot) is the one
judgment call in this whole list that's genuinely Louis's to make, ideally by
looking at a few captures side by side against current Steam front-page
neighbors in the arcade/skill genre.

### Suggested split
A future session (any capability level) can generate a batch of high-res
in-engine captures at several venues/moments and crop them to every required
size — that part is mechanical. Whether any of them are good enough to ship,
or whether this needs actual commissioned art layered on top, is Louis's
call once he's looking at the actual images next to real Steam storefront
neighbors.

---

## 3. Two cutscene shots stage the wrong (or no) character for their dialogue

Found during a full read-through of Game.gd on 2026-07-11 (every function has
now been read at least once; nothing else turned up a correctness bug). Not
blocked on an account or Louis's taste, just left undone because fixing a
figure's pose blind, without the windowed screenshot loop this project always
uses to verify character staging, risks producing something that reads worse
than the placeholder it replaces — every prior pose fix in this file's history
took a few iterate-and-screenshot passes to land.

### The two shots
1. **`cutscene_script("rival")`, third shot** (Game.gd, `cutscene_script`
   around the `"rival"` case): `"who": "Silvio"`, and the caption has him
   physically stopping Milo on the way out to say "She really never dropped,
   did she." The shot plays on `scene_champ(s, 2)`. `scene_champ` (Game.gd)
   has explicit cases for stage 0, 1, and 3, but no case 2 — it falls through
   to the `_:` wildcard, which draws `milo_pal(4)` alone with no second figure
   at all. Silvio is speaking a line on an empty stage.
2. **`cutscene_script("finale")`, fourth shot**: Bruna's caption describes her
   physically pressing the three balls back into Milo's hands ("in the yard
   where it started"). The shot plays on `scene_backyard(s, 3)`, which has no
   explicit case 3 either and falls to the same `_:` wildcard used at the
   close of the `"intro"` beat: Milo demo-juggling while Bruna watches from
   the side. It's a fine shot for "Bruna proudly watching," which is what the
   intro needed, but it does not stage the handoff the finale's line describes.

### Why this slipped past the earlier audit
ROADMAP item 9's cutscene pass audited shots for motion quality (arm angles,
ball placement, cadence) by looking at each tableau on its own. Both of these
tableaux look fine in isolation — the bug only shows up when you cross-check
the shot's `"who"`/caption against which characters are actually drawn, which
a visual-only pass naturally skips.

### Suggested fix
Give `scene_champ` an explicit `2:` case that stages Silvio (use the
`silvio_pal()` + a `reach_hand`-style pose already used in `scene_champ`
stage 1 and `scene_theatre` stage 1 as reference) actually facing Milo, mood
-1 or a tired/resigned expression rather than his usual smug one. For the
finale, give `scene_backyard` an explicit `3:` case where Bruna's hand
extends toward Milo's with the three balls between them (the intro's stage 0
"offering" pose, with `bruna_pal()` and the cradled-ball drawing from that
same shot, is the closest existing reference — this is closing the same
gesture the story opened with).

Verify with the project's own established loop, windowed (not headless,
which cannot grab the framebuffer): `godot --path . --cutscene rival --csn 2
--shotat 200 --shot /tmp/rival2.png` and `godot --path . --cutscene finale
--csn 3 --shotat 200 --shot /tmp/finale3.png`, then look at the PNGs before
committing.
