# Ideas / backlog

Not yet built, not yet decided to build. Unlike CLAUDE.md this file records things that
were *tried and parked*, not things that shipped - so an entry here needs the same "why"
discipline or it is useless to whoever picks it up next.

## A real arm pose for Behind the Back (2026-08-28)

Today's fix for "the hand looks bad, something jitters" (see CLAUDE.md) kept BTB working by
hiding the prop behind the torso while the arm plays an ordinary same-side pose from the
existing bank - the bank only has same-side reach poses (one clean source frame, cut once,
rigged), so there was never an option to paint the arm actually reaching behind the back.
That's a real gap, not just a rough edge: the arm doesn't look like it's doing the trick, it
just doesn't glitch any more.

**Explored via `create_character_state` on the Showman character (8961b1b8-...), three
tries:**
  1. "arm behind the back, hand peeking past the opposite hip" -> both arms vanished into the
     sleeves, symmetrically. Not what was asked; the model defaults to a symmetric "hands
     tucked away" read of "behind the back".
  2. Same ask, much more forceful about asymmetry ("ONLY the right arm changes, the left
     stays exactly as pictured") -> reverted to the default pose, right arm unchanged. Ignored
     the edit.
  3. Reframed as a VISIBLE cross-body reach instead of a hidden one ("the right arm crosses
     diagonally in front, forearm low across the waist, hand out past the left hip, staying
     clearly visible") -> got a real result: left arm untouched, right arm crosses toward
     centre. Reach only goes to about belt/belly height, not all the way to the far hip.

This matches the project's own documented pattern (`build_arm_bank.py`'s history, the "hands
tucked at hip height" refusals) - asking the model for a pose where a hand is HIDDEN or
SELF-OCCLUDED is unreliable across multiple phrasings. Asking for the same visual idea as a
VISIBLE reach works. Attempt 3's result was accepted as "good enough to build from" but not
implemented - Louis wants PixelLab generation prioritized over Claude-side engineering for
now, and integrating it means real code work: cutting the crossing arm out of that state,
building a second small rig/lookup entry alongside the existing reach-indexed bank (see
`scripts/build_arm_rig.py`), and wiring `fig_arm_pick` to reach for it during BTB's
high-hand carry instead of (or in addition to) the current hide-the-ball approach.

**If this gets picked up:** start from character id `4fde47ea-684b-4817-9fac-9421cf697ef5`
(state "Cross Reach", group `ef11be8d-e6fd-4246-bc2a-a4370e5cd7c5`), rotation `south`. Either
regenerate once more pushing the reach further toward the opposite hip (expect another 1-2
tries, same failure mode as above if pushed toward "hidden" language again), or just build
the rig from what exists - a cross-to-centre pose already reads as a cross-body throw at this
sprite size, which may be enough without chasing the literal "hidden behind the back" image.
