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
	{"id": "btb", "name": "Behind the Back", "kind": "toggle", "lvl": 3, "acc": 25, "perf": 5, "min_air": 0, "diff": 1.20, "cascade_only": true, "shout": "BEHIND THE BACK!", "desc": "Toggle: every throw loops behind the back. Cascade, Shower or Half Shower only - and in the two showers it is the high hand alone that goes behind, the low pass staying in front. Every catch under it multiplies the run."},
	{"id": "high", "name": "High Toss", "kind": "toggle", "lvl": 5, "str": 75, "perf": 10, "min_air": 0, "diff": 1.10, "cascade_only": false, "shout": "HIGH TOSS!", "desc": "Toggle: every throw flies sky high - hold it and it climbs clean out of the frame. Easy, so it pays least - but the airtime it buys is what makes a Spin survivable."},
	{"id": "spin", "name": "Spin", "kind": "live", "lvl": 8, "spd": 75, "perf": 18, "min_air": 1, "diff": 2.00, "cascade_only": false, "shout": "SPIN!", "desc": "You turn on the spot - and while you turn you can neither throw nor catch. The biggest multiplier in the game, paid for in airtime you have to buy first."},
]


# Booking conditions have stable string IDs used by saves, daily seeds, and dev flags.
# Their order is not persisted, but the contract test protects accidental removals/renames.
const ENCORES := [
	{"id": "hecklers", "name": "The Hecklers", "desc": "The crowd is impatient. Their attention drains twice as fast."},
	{"id": "fright", "name": "Stage Fright", "desc": "The lights are in your eyes. No landing markers."},
	{"id": "gale", "name": "The Gale", "desc": "A hard wind sweeps the stage. Only a clean Perfect catch survives it."},
	{"id": "blackout", "name": "Blackout", "desc": "The house lights are out. An ordinary prop is barely visible in the hand and ALMOST GONE in the air. Glow-in-the-dark props shine, and a torch is a flame with no handle under it."},
	{"id": "cold", "name": "Cold Hands", "desc": "Every catch window is one tick tighter."},
	{"id": "long", "name": "The Long Set", "desc": "The final goal asks for a longer run, but the crowd is patient. An endurance test."},
	{"id": "understudy", "name": "The Understudy", "desc": "One drop and it is over."},
	{"id": "fire", "name": "For the Danger", "desc": "This crowd came for danger. Only clubs, knives, torches and chainsaws score."},
	{"id": "scared", "name": "A Scared Audience", "desc": "Blades and flames frighten this room. Only balls, eggs and rings score."},
	{"id": "fancy", "name": "A Fancy Audience", "desc": "A dress-circle crowd, and eggs are a busker's gag. Eggs score nothing tonight."},
	{"id": "study", "name": "The Study", "desc": "The house booked a Cascade. Only Cascade routines score tonight."},
	{"id": "lines", "name": "The Lines", "desc": "The house wants strict vertical control. Only Columns routines score tonight."},
	{"id": "overhand", "name": "Over the Top", "desc": "This crowd wants an overhand pattern: Half Shower, Shower, Reverse Cascade, or Tennis."},
	{"id": "critic", "name": "The Critic", "desc": "A late catch breaks the spell: your run starts over from nothing. It costs you nothing else."},
	{"id": "critic_hard", "name": "The Critic, Twice", "desc": "Anything short of a Perfect breaks the spell and your run starts over from nothing."},
	{"id": "purist_acc", "name": "Purist: Hands", "desc": "Your trained Accuracy counts for nothing tonight. Raw hands."},
	{"id": "purist_str", "name": "Purist: Arms", "desc": "Your Strength counts for nothing tonight: three of the lightest thing you own."},
	{"id": "purist_end", "name": "Purist: Wind", "desc": "Your Endurance counts for nothing tonight. A beginner's stamina."},
	{"id": "purist_spd", "name": "Purist: Nerve", "desc": "Your Speed counts for nothing tonight. No slow motion at all."},
]

# Only hand timing and time assistance may be stripped. Strength gates what can be
# fielded and Endurance gates how long an act can physically last, so neither belongs
# in a booking condition.
const PURIST_IDS := ["purist_acc", "purist_spd"]


# Named rivals advertise these exact deterministic applause preferences on the venue card.
const VENUE_FLAVOUR := [
	{"rival": "Mara Bell", "taste": "clean catches and a steady first show", "trigger": "perfect"},
	{"rival": "The Lark", "taste": "bold height over safe little throws", "trigger": "height"},
	{"rival": "Viktor Vale", "taste": "a composed Cascade under bright lights", "trigger": "cascade"},
	{"rival": "Rosa Ribbons", "taste": "showmanship and dangerous props", "trigger": "danger"},
	{"rival": "Kai Mercury", "taste": "clean patterns and nerve", "trigger": "pattern"},
	{"rival": "Aurelia Voss", "taste": "a record-load routine worth travelling for", "trigger": "record"},
	{"rival": "Nocturne", "taste": "control when the room goes dark", "trigger": "dark"},
]
