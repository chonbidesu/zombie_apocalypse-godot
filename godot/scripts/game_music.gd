extends AudioStreamPlayer
## Cycle through the original gameplay tracks without repeating the last one.
const TRACKS: Array[String] = [
 "res://assets/music/road_runner.mp3",
 "res://assets/music/forward_motion.mp3"
]
var track_index: int = -1

func _ready() -> void:
 volume_db = linear_to_db(0.3)
 finished.connect(next_track)
 next_track()

func next_track() -> void:
 var next_index := randi_range(0,TRACKS.size()-1)
 if TRACKS.size() > 1 and next_index == track_index:
  next_index = (next_index+1)%TRACKS.size()
 track_index = next_index
 stream = load(TRACKS[track_index])
 play()
