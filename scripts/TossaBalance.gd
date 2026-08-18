## Pure goal-ladder rules shared by the live act and balance tests.
class_name TossaBalance
extends RefCounted


const SCORE_CEIL := 1.0e300
const PERFECT_CATCHES := [80.0, 120.0, 160.0, 200.0, 260.0, 330.0, 400.0]
const GOAL_STEPS := [0.50, 0.72, 1.0]
const RUN_SHARE := 0.75


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
