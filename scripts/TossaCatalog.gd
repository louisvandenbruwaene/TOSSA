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


const PROPS := [
	{"name": "Ball", "weight": 1, "cost": 20, "stam": 1, "spins": false, "pwin": 0, "trait": "the honest baseline - cheapest, lightest on the arms, and the count is all yours"},
	{"name": "Egg", "weight": 1, "cost": 1, "stam": 2, "spins": false, "pwin": 0, "trait": "a gamble - nearly free and worth a touch more, but ONE drop and it is gone for good"},
	{"name": "Ring", "weight": 2, "cost": 200, "stam": 2, "spins": false, "pwin": 0, "trait": "low stamina for their weight - the endurance prop, built for the longest sets"},
	{"name": "Club", "weight": 3, "cost": 500, "stam": 4, "spins": true, "pwin": 1, "trait": "one extra frame on every catch - the forgiving prop, and the only one that gives timing back"},
	{"name": "Knife", "weight": 4, "cost": 1000, "stam": 5, "spins": true, "pwin": 0, "trait": "danger the room can see - a knife act holds a crowd's patience far longer"},
	{"name": "Torch", "weight": 5, "cost": 2000, "stam": 6, "spins": true, "pwin": 0, "trait": "self-lit and thrilling - they hold a crowd like knives AND they shine when the stage goes dark"},
	{"name": "Chainsaw", "weight": 6, "cost": 9000, "stam": 8, "spins": true, "pwin": -1, "trait": "one frame less on every catch - the hardest timing in the game, and the biggest number"},
]

const PROP_SIG := [1.0, 1.2, 1.4, 1.6, 2.0, 3.0, 5.0]


const TRICKS := [
	{"id": "btb", "name": "Behind the Back", "kind": "toggle", "lvl": 3, "acc": 25, "perf": 5, "min_air": 0, "diff": 1.20, "cascade_only": true, "shout": "BEHIND THE BACK!", "desc": "Toggle: every throw loops behind the back. Cascade only - no other pattern survives it. Every catch under it multiplies the run."},
	{"id": "high", "name": "High Toss", "kind": "toggle", "lvl": 5, "str": 75, "perf": 10, "min_air": 0, "diff": 1.10, "cascade_only": false, "shout": "HIGH TOSS!", "desc": "Toggle: every throw flies sky high - hold it and it climbs clean out of the frame. Easy, so it pays least - but the airtime it buys is what makes a Spin survivable."},
	{"id": "spin", "name": "Spin", "kind": "live", "lvl": 8, "spd": 75, "perf": 18, "min_air": 1, "diff": 2.00, "cascade_only": false, "shout": "SPIN!", "desc": "You turn on the spot - and while you turn you can neither throw nor catch. The biggest multiplier in the game, paid for in airtime you have to buy first."},
]
