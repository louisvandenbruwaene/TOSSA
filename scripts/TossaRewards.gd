## Pure progress rules for earned gameplay rewards.
##
## The live game owns clocks, popups, and sound. This seam owns only the counter rule so a
## merely Good catch can never quietly bring back the old all-or-nothing Perfect chain.
class_name TossaRewards
extends RefCounted


const PERFECTS_PER_BURST := 50


static func record_catch(progress: int, quality: int, eligible: bool = true) -> Dictionary:
	# quality follows the live scoring contract: 0 Perfect, 1 Good, 2 Late. Off-Perfect
	# catches deliberately preserve the tally; they are not a hidden chain break.
	if not eligible or quality != 0:
		return {"progress": maxi(0, progress), "triggered": false}
	var next := maxi(0, progress) + 1
	if next >= PERFECTS_PER_BURST:
		return {"progress": next - PERFECTS_PER_BURST, "triggered": true}
	return {"progress": next, "triggered": false}


static func reset_on_drop() -> int:
	return 0
