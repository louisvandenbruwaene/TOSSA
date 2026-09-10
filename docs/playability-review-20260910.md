# TOSSA playability pass — 10 September 2026

Implemented on `codex/improvements`. Existing art/card work was checkpointed first at
`5758126`, tagged `tossa-before-playability-20260910`. The nested vector archive was left alone.

## What changed

- **Stage clarity:** stronger HUD hierarchy, explicit goal/cash-in status, larger flower reward
  marks, separate stamina/crowd/drop risks, and a quieter central backdrop. Narrow dangerous
  props have a subtle silhouette edge. Stage paintings and their static veil are cached.
- **Predictable timing:** Perfect, Good and edge catches within the allowed window are secure.
  Edge catches instead cost 1–3 additional stamina, moderated by Accuracy and chosen height.
  Explicit Perfect-only challenges and exhaustion still apply. Left/right catch pitches differ;
  misses identify the hand and timing mistake. `--legacy-catches` allows temporary comparison.
- **Learning:** shorter opening rhythm instructions; contextual throw/watch/catch keys and an
  arrival rail in practice/free tutorial play. Cues fade over 12 catches and return after a miss.
  Practice visibly explains Enter to return to the career.
- **Preparation/results:** shop cards show prop traits and actual usable quantity, with portraits
  fitted around their labels. Results emphasise achievement, coaching and undiscovered skills;
  retry, focused practice and career actions support keyboard, controller and clicking. Practice
  retains the routine, uses available props, costs a normal day segment, and grants no stamina.
  Special endings cannot be bypassed through retry or practice.
- **Skill ceiling:** after Spin is owned, compatible patterns show an optional sequence:
  six clean catches → deliberately higher throw → all-props-airborne Spin while that throw is
  still aloft → six clean recovery catches → controlled finish. Edges/misses reset the sequence.
  Rewards cap at 20 XP per run and never multiply score. Venue rivals/preferences are visible.
- **Animation:** Behind the Back briefly folds the empty arm behind the torso, using the existing
  painted atlas. Its hidden skill-preview carry has the same gesture. Release endpoints, held
  props and imminent catches keep their normal contact poses; simulation targets never move.
- **Performance/diagnostics:** static scenery invalidates on venue, texture or viewport changes.
  `--fps` now reports wall-clock frame p95/max as well as CPU draw/physics cost. Muted/headless
  sessions skip audio resource creation, eliminating the observed MP3 playback leaks on exit;
  audio export still explicitly generates its sounds.

## Review and validation

Local captures: [stage](../artifacts/review_20260910/stage-final.png),
[shop](../artifacts/review_20260910/shop-final.png),
[results](../artifacts/review_20260910/results-final.png), and
[busy stage](../artifacts/review_20260910/busy-stage-final.png).
These are ignored generated artifacts. Open the Godot project normally to play the changes;
the development captures use a separate demo save.

The full validation covers real booked/daily acts, the demo ending, introductory and intermediate
lessons, dangerous-prop drops, collision sweeps, full-hand parking, rendered screenshots,
fullscreen aspect ratio and font quantisation. Added tests cover catch grades, practice costs and
ending guards, sequence ordering/reward caps and pose contact guards.

Pre-existing validation fixtures were repaired: the demo-ceiling setup now survives a
venue override and a failed act's reputation loss; stage screenshots pin `--encore none` so an
unrelated rolled challenge cannot end the act before its capture. Collision cases now use the
named pattern IDs the game accepts, instead of silently retaining the saved pattern.

The named-pattern sweep measured drawn clearance of +2.2 px for four-knife Half Shower,
+115.1 px for four-ball Cascade and −13.3 px for six-ring Columns. Columns therefore retains
a visual overlap. Migration-related save-key differences and heuristic uncalled functions also
remain advisory findings; this pass does not claim to resolve them. All verification was muted; audible mix quality and human judgments of
fun, opening difficulty and long-session balance still need playtesting.

### Measured load

On the Apple M5 / Godot 4.7 Compatibility renderer, five chainsaws in Circus/Cascade with
trained stats and the 20% slow-time assist remained in play throughout the capture. After warm-up: about 120 FPS,
1.9 ms CPU draw time, 51–58 μs per physics tick, wall-clock frame p95 12.15–12.46 ms.
The first sample had a 21.26 ms maximum. This is one local load sample, not a hardware-wide
benchmark. The wall-clock numbers supersede the earlier delta-based p95 estimate.

The normal full `make validate` passed. The corrected named-pattern cases also passed
individually with a fixed 120 Hz simulation timestep; the final full suite rerun passed using the same
accelerated headless timestep while windowed rendering checks remained real-time.

## Reversibility

To inspect the exact pre-pass checkpoint on a separate branch:

```sh
git switch -c review/before-playability tossa-before-playability-20260910
```

To undo the pass while retaining history, inspect
`git log --oneline tossa-before-playability-20260910..codex/improvements` and use `git revert`
on the improvement commits from newest to oldest. Avoid resetting a tree containing other work.
Neither approach removes the existing art/card work preserved by the checkpoint. Nothing was pushed.
