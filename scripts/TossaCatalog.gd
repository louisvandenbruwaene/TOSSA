## Immutable gameplay catalogs.
##
## Entries whose index is persisted keep their ordering contract in the matching
## test. Add data here only when it is independent of live Nodes and game state.
class_name TossaCatalog
extends RefCounted


const PATTERNS := [
	{"id": "cascade",    "name": "Cascade",     "lvl": 1, "mult": 1.0, "room": 0.65,
	 "desc": "The weave. Odd counts cross to the other hand; even counts keep each hand's own circle."},
	{"id": "columns",    "name": "Columns",     "lvl": 6, "acc": 50, "perf": 14, "mult": 1.2, "room": 1.0,
	 "desc": "Straight up and down in fixed lanes; an odd count opens a middle lane too. Clean or nothing."},
	{"id": "halfshower", "name": "Half Shower", "lvl": 10, "acc": 150, "ven": 1, "perf": 24, "mult": 2.0, "room": 0.05,
	 "desc": "The right hand throws over the top; the left keeps the weave, but low."},
	{"id": "shower",     "name": "Shower",      "lvl": 1, "ven": 3, "mult": 3.0, "room": 0.7,
	 "desc": "The full circle. Right throws high, left feeds fast and low."},
	{"id": "rcasc",      "name": "Reverse Cascade", "lvl": 1, "ven": 4, "mult": 1.5, "room": 1.0,
	 "desc": "BOTH hands throw over the top, the weave runs backward."},
	{"id": "tennis",     "name": "Tennis",      "lvl": 1, "ven": 5, "mult": 1.5, "room": 0.05,
	 "desc": "One marked ball sails over the top, back and forth across the weave."},
]
