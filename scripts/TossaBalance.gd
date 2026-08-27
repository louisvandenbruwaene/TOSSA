## Pure goal-ladder rules shared by the live act and balance tests.
class_name TossaBalance
extends RefCounted


const SCORE_CEIL := 1.0e300
const PERFECT_CATCHES := [80.0, 120.0, 160.0, 200.0, 260.0, 330.0, 400.0]
# THE THREE GOALS ARE EVEN THIRDS OF THE ACT (2026-08-19, Louis: "the subgoals should be
# linearly spread: one at 1/3, 2/3 and 3/3 of the final goal - the last one being the big
# flower of course"). Score is LINEAR in weighted catches (see score_for: the count is the
# only exponent and it applies to the base, not to the catches), so thirds of the catch
# target are thirds of the score target, and the goal stem's three flowers sit at even
# intervals up the stalk. The old 0.50 / 0.72 put the first goal half way up the whole act
# and then crowded the second and third into the top quarter, which is why the meter's two
# subgoal flowers were bunched near the bottom and the last stretch had nothing in it.
const GOAL_STEPS := [1.0 / 3.0, 2.0 / 3.0, 1.0]
const RUN_SHARE := 0.75
const BASE_STAMINA := 200.0
const STAMINA_PER_ENDURANCE := 8.0
# THE TRICK FACTOR'S TWO NUMBERS, AND WHY BOTH ARE SET BY THE LADDER RATHER THAN BY TASTE.
#
# The pillar the venue ladder is built on is that the SKILL AXIS IS THE LOAD - how many
# objects you can hold up - and a flourish is upside on top of that. So the whole trick
# factor has to be worth less than one step UP the ladder, or a player would be better off
# staying in the room they can already juggle in and pressing the trick key.
#
# The tightest step in the game is the first one: the Backyard's final goal is 1,920 (three
# balls) and the Street Corner's is 8,433 (four), a ratio of 4.39. Every step above it is
# far wider. So 4.0 is the cap: comfortably inside the narrowest rung, and worth about two
# of the three goal steps within one act (the goals sit at 0.50 / 0.72 / 1.0 of the target
# catch count, and the streak is linear, so 2x of score is roughly a goal).
const TRICK_FACTOR_CAP := 4.0
# ...and the GAIN shapes the curve so the cap is a backstop rather than the balance. At gain
# 1.0 every trick landed fifty times reaches 13.9x and the cap would be doing all the work -
# a cap that is always hit is not a limit, it is the formula. At 0.6 the same extreme act
# reaches 4.9 and only the very top of the range is clipped: one Spin is 1.7x, ten are 2.3x,
# all three tricks ten times each is 3.3x.
const TRICK_GAIN := 0.6


static func trick_factor_log10(landings: Dictionary) -> float:
	# log10 of `F`, the act's ONE trick multiplier. `landings` maps a trick's difficulty
	# (TRICKS' `diff`) to how many times it landed in this act.
	#
	#     F = PRODUCT over tricks j of  t_j ^ (TRICK_GAIN * (1 + log10(1 + m_j))),  capped
	#
	# It is a MULTIPLIER on the finished score and never an exponent on anything, which is
	# the whole correction of 2026-08-19: the shape it replaces raised the entire sum to the
	# power of (1 + the number of distinct tricks), so three tricks turned a Backyard act
	# into a bigger number than the last venue in the game. Landing one more of a trick
	# always pays and always pays less; the cap stops the total dead however TRICKS grows.
	var lg := 0.0
	for diff in landings:
		var m := float(landings[diff])
		var t := float(diff)
		if m <= 0.0 or t <= 1.0:
			continue
		lg += TRICK_GAIN * (1.0 + log(1.0 + m) / log(10.0)) * (log(t) / log(10.0))
	return minf(lg, log(TRICK_FACTOR_CAP) / log(10.0))


static func trick_factor(landings: Dictionary) -> float:
	return pow(10.0, trick_factor_log10(landings))


static func weighted_goal(venue: int, goal_index: int, perfect_weight: float,
		ante_scale: float = 1.0, encore_scale: float = 1.0) -> float:
	var base := float(PERFECT_CATCHES[clampi(venue, 0, PERFECT_CATCHES.size() - 1)])
	var step := float(GOAL_STEPS[clampi(goal_index, 0, GOAL_STEPS.size() - 1)])
	return base * perfect_weight * step * ante_scale * encore_scale


static func score_for(weighted_catches: float, object_count: int, signature: float,
		pattern: float, strength_unit: float) -> float:
	if weighted_catches <= 0.0:
		return 0.0
	var base := signature * pattern * strength_unit + 1.0
	var score_log := log(weighted_catches) / log(10.0) \
		+ float(object_count) * log(maxf(base, 1.0e-300)) / log(10.0)
	if score_log >= 300.0:
		return SCORE_CEIL
	return pow(10.0, score_log)


static func run_required(weighted_goal_catches: float) -> float:
	return maxf(0.0, weighted_goal_catches) * RUN_SHARE


static func run_ready(best_weighted_run: float, weighted_goal_catches: float) -> bool:
	return best_weighted_run >= run_required(weighted_goal_catches)


static func goal_ready(score: float, target: float, clock_open: bool,
		best_weighted_run: float, weighted_goal_catches: float) -> bool:
	return score >= target and clock_open and run_ready(best_weighted_run, weighted_goal_catches)


static func stamina_capacity(endurance: int) -> float:
	return BASE_STAMINA + STAMINA_PER_ENDURANCE * float(maxi(0, endurance))


static func migrate_legacy_stamina(saved_stamina: float, endurance: int) -> float:
	var old_capacity := 100.0 + 9.0 * float(maxi(0, endurance))
	return clampf(saved_stamina / old_capacity, 0.0, 1.0) * stamina_capacity(endurance)
