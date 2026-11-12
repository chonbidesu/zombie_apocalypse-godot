extends Node
## Legacy action effects; independent of world RNG and game timing.
var rng := RandomNumberGenerator.new()
var streams: Dictionary = {}
const PATHS = {
 "footsteps":"footsteps.wav", "door_open":"door_open.wav", "door_close":"door_close.wav",
 "reload":"reload.mp3", "gun_shot":"gun_shot.mp3", "decade":"decade.wav",
 "ransack":"ransack.wav", "human_death":"human_death.wav", "zombie_death":"zombie_death.wav",
 "zombie_sounds":"zombie_sounds.wav"
}

func _ready() -> void:
 rng.randomize()

func play_effect(effect: String) -> void:
 var path: String = PATHS.get(effect,"")
 match effect:
  "break": path = "hit/break_%d.wav" % rng.randi_range(1,8)
  "search": path = "search/search_%d.wav" % rng.randi_range(1,3)
  "barricade": path = "barricade/barricade_%d.wav" % rng.randi_range(1,2)
 if path.is_empty() or get_child_count() >= 12: return
 if not streams.has(path): streams[path] = load("res://assets/sfx/"+path)
 if streams[path] == null: return
 var player = AudioStreamPlayer.new()
 player.bus = &"SFX"
 player.stream = streams[path]
 player.volume_db = -7.0
 add_child(player)
 player.finished.connect(player.queue_free)
 player.play()
