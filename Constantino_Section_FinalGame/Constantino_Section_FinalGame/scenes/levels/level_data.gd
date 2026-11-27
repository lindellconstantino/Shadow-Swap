class_name LevelData
extends RefCounted
## Layout data for every stage. Keeping the numbers here (instead of inside
## level.gd) means a new stage is just a new entry in STAGES.
##
## "realm" values for barriers:  0 = only solid in the MATERIAL realm
##                               1 = only solid in the SHADOW realm

const MATERIAL_REALM := 0
const SHADOW_REALM := 1
const STAGE_COUNT := 3

const STAGES := {
	1: {
		"name": "THE FADING RUINS",
		"intro": "Collect the shards, then reach the Eclipse Gate.",
		"checkpoint": Vector2(96, 350),
		"portal": Vector2(850, 548),
		"shards": [
			Vector2(180, 205),
			Vector2(770, 220),
			Vector2(480, 525),
		],
		"barriers": [
			{"rect": Rect2(220, 170, 28, 150), "realm": 0},
			{"rect": Rect2(350, 300, 170, 26), "realm": 0},
			{"rect": Rect2(585, 160, 28, 145), "realm": 0},
			{"rect": Rect2(675, 390, 125, 26), "realm": 0},
			{"rect": Rect2(300, 390, 28, 130), "realm": 1},
			{"rect": Rect2(430, 175, 150, 26), "realm": 1},
			{"rect": Rect2(690, 260, 28, 95), "realm": 1},
			{"rect": Rect2(120, 455, 110, 26), "realm": 1},
			# Tutorial cage: a Material-only cage around shard 2. Shift to Shadow to slip inside.
			{"rect": Rect2(720, 170, 100, 16), "realm": 0},
			{"rect": Rect2(720, 254, 100, 16), "realm": 0},
			{"rect": Rect2(720, 170, 16, 100), "realm": 0},
			{"rect": Rect2(804, 170, 16, 100), "realm": 0},
		],
		"wisp_cap": 0,
		"wisp_spawns": [],
		"anchors": [],
	},
	2: {
		"name": "THE WHISPERING MAZE",
		"intro": "Shadow Wisps drift here. They only exist in the Shadow Realm.",
		"checkpoint": Vector2(96, 540),
		"portal": Vector2(850, 160),
		"shards": [
			Vector2(185, 205),
			Vector2(490, 235),
			Vector2(680, 505),
			Vector2(840, 455),
		],
		"barriers": [
			{"rect": Rect2(220, 170, 28, 150), "realm": 0},
			{"rect": Rect2(350, 300, 170, 26), "realm": 0},
			{"rect": Rect2(585, 160, 28, 145), "realm": 0},
			{"rect": Rect2(675, 390, 125, 26), "realm": 0},
			{"rect": Rect2(300, 390, 28, 130), "realm": 1},
			{"rect": Rect2(430, 175, 150, 26), "realm": 1},
			{"rect": Rect2(690, 260, 28, 95), "realm": 1},
			{"rect": Rect2(120, 455, 110, 26), "realm": 1},
			{"rect": Rect2(260, 210, 30, 210), "realm": 0},
			{"rect": Rect2(390, 440, 170, 26), "realm": 1},
			{"rect": Rect2(610, 190, 30, 180), "realm": 0},
			{"rect": Rect2(735, 330, 115, 26), "realm": 1},
			# Shadow-only cage around shard 4. Stay in the Material Realm to walk inside.
			{"rect": Rect2(790, 410, 100, 16), "realm": 1},
			{"rect": Rect2(790, 484, 100, 16), "realm": 1},
			{"rect": Rect2(790, 410, 16, 90), "realm": 1},
			{"rect": Rect2(874, 410, 16, 90), "realm": 1},
		],
		"wisp_cap": 2,
		"wisp_spawns": [Vector2(380, 235), Vector2(560, 510), Vector2(740, 220)],
		"anchors": [Vector2(340, 190), Vector2(560, 550), Vector2(820, 260)],
	},
	3: {
		"name": "THE ECLIPSE CORE",
		"intro": "Sealed chambers guard the last shards. Enter one realm, leave through the other.",
		"checkpoint": Vector2(96, 356),
		"portal": Vector2(856, 356),
		"shards": [
			Vector2(480, 205),
			Vector2(720, 475),
			Vector2(150, 190),
			Vector2(150, 540),
			Vector2(840, 200),
		],
		"barriers": [
			# Chamber A (all Material) around shard 1: enter from the Shadow Realm.
			{"rect": Rect2(400, 150, 160, 20), "realm": 0},
			{"rect": Rect2(400, 240, 160, 20), "realm": 0},
			{"rect": Rect2(400, 150, 20, 110), "realm": 0},
			{"rect": Rect2(540, 150, 20, 110), "realm": 0},
			# Chamber B (all Shadow) around shard 2: enter from the Material Realm.
			{"rect": Rect2(640, 420, 160, 20), "realm": 1},
			{"rect": Rect2(640, 510, 160, 20), "realm": 1},
			{"rect": Rect2(640, 420, 20, 110), "realm": 1},
			{"rect": Rect2(780, 420, 20, 110), "realm": 1},
			# Cage C (all Material) around shard 5 in the north-east.
			{"rect": Rect2(790, 150, 100, 16), "realm": 0},
			{"rect": Rect2(790, 234, 100, 16), "realm": 0},
			{"rect": Rect2(790, 150, 16, 100), "realm": 0},
			{"rect": Rect2(874, 150, 16, 100), "realm": 0},
			# Dividers that make the player switch realms to get around.
			{"rect": Rect2(220, 128, 26, 200), "realm": 0},
			{"rect": Rect2(220, 384, 26, 200), "realm": 1},
			{"rect": Rect2(300, 300, 26, 160), "realm": 1},
			{"rect": Rect2(560, 330, 26, 120), "realm": 0},
			{"rect": Rect2(730, 300, 26, 110), "realm": 0},
			{"rect": Rect2(100, 270, 90, 22), "realm": 1},
			{"rect": Rect2(100, 460, 90, 22), "realm": 0},
		],
		"wisp_cap": 3,
		"wisp_spawns": [Vector2(360, 480), Vector2(520, 330), Vector2(690, 300), Vector2(470, 560)],
		"anchors": [Vector2(330, 540), Vector2(620, 220), Vector2(880, 520)],
	},
}

static func get_stage(stage: int) -> Dictionary:
	# Fall back to stage 1 when an invalid number is requested.
	return STAGES.get(stage, STAGES[1])
