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

Louis playtest feedback 2026-07-10 (evening) added as items 9 to 11 below.
These are direct player notes, so they outranked the older open items. All
three are BUILT and pushed (same night) and await Louis's next look: the
cutscene pass by eye, the music rework by ear, the trick powerup in hand.
Still open from the older queue: item 2 (content depth), item 5 (audio
breadth, partly reshaped by item 10), and the rest of items 3 and 7 (remap
screen, export presets, capsule art, Steamworks).

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

## 3. Controller support and key remapping - FULLY BUILT 2026-07-10 (remap screen landed same day)

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

## 5. Audio breadth - RESCOPED 2026-07-10: Louis's own track is the music now

Louis produced his own background song (Juggling Game.mp3, in the repo) and the
procedural music generation was removed in its favour. LICENSING: the current
file is a free-tier Suno render, non-commercial only. Louis has decided to
re-render it under a Suno Pro subscription (which grants commercial rights to
songs made while subscribed), ideally at a slightly slower, more relaxed tempo.
Until then the current file is a DEV PLACEHOLDER and must not ship. Swapping
in the re-render is just replacing the file with the same name and reimporting.
What remains of this item: the record-attempt near-silence and the finale
payoff are now simple volume states over the one track, and the gasp and groan
stingers stay as procedural SFX work. Per-venue variety returns if Louis makes
more tracks, a per-venue track table is trivial to add.

The synthesis system is solid but the palette is thin: sine bells over one
shared two-chord loop. Wanted: a distinct motif per venue tier that still
shares one musical family (the ART doc calls it one piece of music growing up),
the record-attempt near-silence with only the count and the crowd, a proper
finale payoff when the full theme returns, and a couple more stingers (gasp on
a risky high throw, groan on a drop). Louis still needs to judge the current
mix by ear before deep retuning.

## 6. Endgame wrap - BUILT 2026-07-10 (slow motion BUILT 2026-07-11: Speed stat,
Uncle Dan's Pie, Amazing! bursts and ten-Perfect chains, stacking per ideas.rtf)

The three endgame cutscenes exist but nothing follows the finale. Build a
credits screen (code-drawn, same royal style, reachable from the menu after the
finale has been seen), and a small post-finale state so the world acknowledges
the record: a FINALE banner on the save slot, maybe a golden tint on the arena.
Slow motion as the reward state stays deferred.

## 7. Steam packaging - presets and icons BUILT 2026-07-10, Steamworks still open

Landed: export_presets.cfg with macOS, Windows and Linux presets, and real
icons at export sizes (export/icons: 1024 png, .icns, .ico, rendered from
icon.svg). Louis still needs to install the export templates once in the
editor (Editor menu, Manage Export Templates) before the first real export,
since templates are not on this machine. Louis's Suno cover jpeg could seed
the Steam capsule art. Still open: Steamworks (achievements, cloud saves,
leaderboards for the Purist boards).

Export presets for macOS, Windows and Linux. Pause when the window loses
focus. Capsule and library art (this realistically cannot be code-only).
Steamworks later: achievements, cloud saves, leaderboards for the Purist
boards. Start with the parts that need no SDK: presets, focus-loss pause, a
proper app icon at export sizes.

## 8. Dev hygiene: give --demo its own save - BUILT 2026-07-10

The --demo auto-player plays on real save slot 0, so screenshot and test runs
can nudge a genuine career. Point it at a scratch save the way --debug already
uses juggle_debug.cfg.

## 9. Cutscene animation pass (Louis playtest note, 2026-07-10) - BUILT 2026-07-10

The cutscenes read as weirdly animated: the motion is too fast overall, and
some shots show ugly juggling or ugly ball holding. Work to do: slow every
scene's oscillation clocks (the ct multipliers in the scene tableaux and the
demo_juggle cadence when it plays inside a cutscene), then audit each shot for
prop placement so held balls sit convincingly IN the palm (the reach_hand and
hand offset math) and the juggled arcs look like real cascade timing rather
than floaty loops. Check every beat with windowed --cutscene <id> --csn <n>
screenshots, shot by shot. The Ken Burns camera and typewriter captions are
fine, it is the FIGURE motion that needs the pass.

## 10. Music rework: enthusiastic, Balatro-like, less noise (Louis, 2026-07-10) - BUILT 2026-07-10

The current background music has too much white noise in it and feels a bit
too sad. Louis wants an enthusiastic, Balatro-like melody, still tailored per
stage. Concrete direction: hunt down every noise component in the beds (the
crowd murmur bed and any noisy synthesis in the loops) and either remove or
heavily darken them, move the harmony from sparse melancholy bells to an
upbeat major hook with a groove (Balatro's trick is a short catchy loop with
a relaxed swing and a warm bass pulse, energetic without being busy), add a
light rhythmic layer that can fade in with the applause energy, and keep the
per-venue tailoring (root, tempo, brightness per tier) on top of the one
shared hook so the climb still reads as one piece of music growing up. The
adaptive volume-automation architecture stays, only the material changes.

## 11. Trick input redesign: Space as a one-shot powerup (Louis, 2026-07-10) - BUILT 2026-07-10

Replace the permanent arm-trick toggle. Louis wants the trick button to feel
like a POWERUP: pressing Space empowers the throw made at the same moment, so
space plus catch-throw produces exactly one trick shot. C (or the pad's Y)
still cycles WHICH trick is selected, the selection persists after use, but
every single use requires its own Space press. So: press Space, the very next
throw (or the simultaneous one) becomes the selected trick, then the system
disarms itself while remembering the selection. Spin fits the same grammar:
with Spin selected, Space performs the spin. Update the trick HUD, the
trick-unlock banner text, and the tutorialised hints to teach the new model,
and make sure the demo auto-player (--demo --trick) still exercises it.
