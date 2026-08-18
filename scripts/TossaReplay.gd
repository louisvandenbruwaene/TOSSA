## Versioned, engine-independent recording format for future ghost performances.
##
## This intentionally knows nothing about Nodes, input devices, or live physics. Game.gd will
## translate its accepted player actions into these events; a ghost reader can then feed the
## same ordered actions back into a deterministic simulation. Keeping this boundary pure makes
## format changes reviewable and lets saves reject a bad replay instead of half-playing it.
class_name TossaReplay
extends RefCounted


const VERSION := 1
const ROUTE_VERSION := 1


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


static func new_route(seed: int) -> Dictionary:
	return {"version": ROUTE_VERSION, "seed": seed, "total_ms": -1, "stages": []}


static func append_stage(route: Dictionary, record: Dictionary) -> bool:
	if not route.has("stages") or not route["stages"] is Array or not is_valid(record):
		return false
	var stages: Array = route["stages"]
	if not stages.is_empty() and int(record["venue"]) <= int(stages.back().get("venue", -1)):
		return false
	stages.append(record.duplicate(true))
	return true


static func finish_route(route: Dictionary, total_ms: int) -> bool:
	if total_ms < 0 or not route.has("stages") or (route["stages"] as Array).is_empty():
		return false
	route["total_ms"] = total_ms
	return true


static func is_valid_route(route: Dictionary) -> bool:
	if int(route.get("version", -1)) != ROUTE_VERSION or int(route.get("seed", -1)) < 0:
		return false
	if int(route.get("total_ms", -1)) < 0 or not route.get("stages", null) is Array:
		return false
	var last_venue := -1
	for stage in route["stages"]:
		if not stage is Dictionary or not is_valid(stage) or int(stage["venue"]) <= last_venue:
			return false
		last_venue = int(stage["venue"])
	return last_venue >= 0


static func stage_for_venue(route: Dictionary, venue: int) -> Dictionary:
	if not is_valid_route(route):
		return {}
	for stage in route["stages"]:
		if int(stage["venue"]) == venue:
			return (stage as Dictionary).duplicate(true)
	return {}


static func actions_at_tick(record: Dictionary, tick: int, cursor: int) -> Dictionary:
	# A monotonic cursor makes live playback O(events), while returning it keeps this
	# helper pure and leaves ownership of playback state with the caller.
	var actions: Array[String] = []
	var next := maxi(0, cursor)
	if not is_valid(record):
		return {"actions": actions, "cursor": next}
	var events: Array = record["events"]
	while next < events.size() and int(events[next]["tick"]) < tick:
		next += 1
	while next < events.size() and int(events[next]["tick"]) == tick:
		actions.append(String(events[next]["action"]))
		next += 1
	return {"actions": actions, "cursor": next}
