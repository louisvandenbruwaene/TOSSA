# JUGGLE: Roadmap to a sellable 1.0

Work queue agreed 2026-07-10, ordered by how much each item matters to a ten
dollar Steam release. Each item is meant to be a self-contained session or less.
Strike items through as they land on main.

Status 2026-07-10: items 1, 3, 4, 6 and 8 are BUILT and pushed, plus the
focus-loss pause from item 7. Item 1 landed as the ST_DAY hub (three segments a
day, persistent stamina, eat and sleep, venue choice with tiered pay, busking
floor) and awaits Louis's playtest. Still open: item 2 (content depth), item 5
(audio breadth), and the rest of item 7 (export presets, capsule art,
Steamworks).

## 1. The day/life loop (the big missing piece) - BUILT 2026-07-10

The GDD (Section 4.5) promises a light juggler's life between performances and
none of it exists yet. Gold accumulates with almost nothing to spend it on, so
the career sim half of the game is hollow. Build the day rhythm: a soft day
clock advanced by actions, EAT (spends gold, feeds Strength, stops decay),
SLEEP (ends the day, resets Stamina, inn versus sleeping rough), TRAVEL between
venues, and street busking as the guaranteed income floor so debt is tension
rather than a dead end. Keep it light and forgiving per the GDD guardrails: a
rhythm and a set of stakes, never a spreadsheet chore. This is the one item the
game should not ship without.

## 2. Content depth

Three tricks, six venues, six props: a paying player sees everything in a few
hours. Wanted: more patterns as learnable content (columns, shower, half
shower, Mills Mess as a short learned sequence), the Purist boards from the GDD
(stat mitigation stripped, pure skill ladder), and something that makes records
a live goal, a challenge or daily format built on the per-venue records that
already exist. Reward variety per the GDD economy notes, so farming one tamed
routine is not optimal.

## 3. Controller support and key remapping - BUILT 2026-07-10 (remap screen still open)

Keyboard only today, with hardcoded physical keycodes. Steam buyers expect a
pad and the GDD already sketched the mapping: left catch L1, left throw L2,
right catch R1, right throw R2, trick on a face button. Add gamepad input
alongside the keys, a simple remap screen (or at least a config file), and make
every hint in the HUD show the right glyphs for the active device. This also
matters for Steam Deck visibility.

## 4. A real typeface - BUILT 2026-07-10 (Nunito, OFL)

Everything renders in the engine fallback font. One clean humane sans with good
numerals (a single licensed or OFL .ttf loaded once as the theme default) would
lift every screen more than any single drawing change. The code-only art rule
bends for exactly one font file. Candidates: Nunito Sans, Inter, Outfit.

## 5. Audio breadth

The synthesis system is solid but the palette is thin: sine bells over one
shared two-chord loop. Wanted: a distinct motif per venue tier that still
shares one musical family (the ART doc calls it one piece of music growing up),
the record-attempt near-silence with only the count and the crowd, a proper
finale payoff when the full theme returns, and a couple more stingers (gasp on
a risky high throw, groan on a drop). Louis still needs to judge the current
mix by ear before deep retuning.

## 6. Endgame wrap - BUILT 2026-07-10 (slow motion still deferred)

The three endgame cutscenes exist but nothing follows the finale. Build a
credits screen (code-drawn, same royal style, reachable from the menu after the
finale has been seen), and a small post-finale state so the world acknowledges
the record: a FINALE banner on the save slot, maybe a golden tint on the arena.
Slow motion as the reward state stays deferred.

## 7. Steam packaging - focus-loss pause BUILT, rest open

Export presets for macOS, Windows and Linux. Pause when the window loses
focus. Capsule and library art (this realistically cannot be code-only).
Steamworks later: achievements, cloud saves, leaderboards for the Purist
boards. Start with the parts that need no SDK: presets, focus-loss pause, a
proper app icon at export sizes.

## 8. Dev hygiene: give --demo its own save - BUILT 2026-07-10

The --demo auto-player plays on real save slot 0, so screenshot and test runs
can nudge a genuine career. Point it at a scratch save the way --debug already
uses juggle_debug.cfg.
