## Locks the fifty-Perfect reward to a drop-free run rather than the deleted chain system.
extends SceneTree

const TOSSA_REWARDS = preload("res://scripts/TossaRewards.gd")


func _init() -> void:
	var failed := 0
	var progress := 0
	for i in TOSSA_REWARDS.PERFECTS_PER_BURST - 1:
		var step := TOSSA_REWARDS.record_catch(progress, 0)
		progress = int(step["progress"])
		if bool(step["triggered"]):
			push_error("The burst must not trigger before the fiftieth Perfect.")
			failed += 1
	var good := TOSSA_REWARDS.record_catch(progress, 1)
	var late := TOSSA_REWARDS.record_catch(progress, 2)
	if int(good["progress"]) != progress or bool(good["triggered"]) \
			or int(late["progress"]) != progress or bool(late["triggered"]):
		push_error("Good and Late catches must preserve Perfect progress.")
		failed += 1
	var final := TOSSA_REWARDS.record_catch(progress, 0)
	if not bool(final["triggered"]) or int(final["progress"]) != 0:
		push_error("The fiftieth Perfect must trigger once and begin a fresh tally.")
		failed += 1
	var ineligible := TOSSA_REWARDS.record_catch(17, 0, false)
	if bool(ineligible["triggered"]) or int(ineligible["progress"]) != 17:
		push_error("A load below three props must neither earn nor erase progress.")
		failed += 1
	if TOSSA_REWARDS.reset_on_drop() != 0:
		push_error("A drop must clear the drop-free Perfect tally.")
		failed += 1
	if failed == 0:
		print("TossaRewards: drop-free Perfect reward verified")
	quit(failed)
