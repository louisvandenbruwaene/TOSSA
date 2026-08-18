## Versioned, engine-independent recording format for future ghost performances.
##
## This intentionally knows nothing about Nodes, input devices, or live physics. Game.gd will
## translate its accepted player actions into these events; a ghost reader can then feed the
## same ordered actions back into a deterministic simulation. Keeping this boundary pure makes
## format changes reviewable and lets saves reject a bad replay instead of half-playing it.
class_name TossaReplay
extends RefCounted


const VERSION := 1


static func new_record(seed: int, venue: int, prop: int, pattern: int, ball_count: int) -> Dictionary:
	return {
		"version": VERSION,
		"seed": seed,
		"venue": venue,
		"prop": prop,
		"pattern": pattern,
		"ball_count": ball_count,
		"events": [],
	}


static func append_event(record: Dictionary, tick: int, action: String) -> bool:
	# Equal-tick actions retain insertion order; a backwards tick makes playback ambiguous.
	if action.is_empty() or tick < 0 or not record.has("events"):
		return false
	var events: Array = record["events"]
	if not events.is_empty() and tick < int(events.back().get("tick", -1)):
		return false
	events.append({"tick": tick, "action": action})
	return true


static func is_valid(record: Dictionary) -> bool:
	if int(record.get("version", -1)) != VERSION:
		return false
	for key in ["seed", "venue", "prop", "pattern", "ball_count", "events"]:
		if not record.has(key):
			return false
	if int(record["venue"]) < 0 or int(record["prop"]) < 0 or int(record["pattern"]) < 0 or int(record["ball_count"]) < 1:
		return false
	if not record["events"] is Array:
		return false
	var last_tick := -1
	for event in record["events"]:
		if not event is Dictionary or not event.has("tick") or not event.has("action"):
			return false
		var event_tick := int(event["tick"])
		if event_tick < last_tick or event_tick < 0 or String(event["action"]).is_empty():
			return false
		last_tick = event_tick
	return true
