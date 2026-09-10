## A bounded sequence challenge. No flight, score, RNG, or save dependencies.
extends RefCounted
const CLEAN_CATCHES := 6
static func fresh() -> Dictionary:
	return {"phase": 0, "clean": 0}
static func advance(state: Dictionary, event: String) -> Dictionary:
	var out := state.duplicate()
	var phase := int(out.get("phase", 0))
	if event == "miss" or event == "edge":
		return fresh()
	if event == "catch" and phase in [0, 3]:
		out["clean"] = mini(CLEAN_CATCHES, int(out.get("clean", 0)) + 1)
		if out["clean"] == CLEAN_CATCHES:
			out["phase"] = phase + 1
			out["clean"] = 0
	elif event == "height" and phase == 1:
		out["phase"] = 2
	elif event == "spin" and phase == 2:
		out["phase"] = 3
	elif event == "finish" and phase == 4:
		out["phase"] = 5
	return out
static func prompt(state: Dictionary) -> String:
	match int(state.get("phase", 0)):
		0: return "Find the rhythm: %d / 6 clean catches" % int(state.get("clean", 0))
		1: return "Hold a throw to create more airtime"
		2: return "Put every prop up, then Spin"
		3: return "Recover cleanly: %d / 6 catches" % int(state.get("clean", 0))
		4: return "Sequence landed. Finish in control"
		_: return "A complete routine, cleanly finished"
