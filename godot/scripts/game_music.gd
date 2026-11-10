extends AudioStreamPlayer

const MUSIC_FOLDER := "res://assets/music/"
const TITLE_TRACK := "summoning.mp3"
const AUDIO_EXTENSIONS: Array[String] = ["mp3", "ogg", "wav"]

var _tracks: Array[String] = []
var _next_index: int = 0

func _ready() -> void:
 volume_db = linear_to_db(0.3)
 finished.connect(_play_next)

func restart_playlist() -> void:
 _tracks.clear()
 for file in ResourceLoader.list_directory(MUSIC_FOLDER):
  if file.to_lower() != TITLE_TRACK and file.get_extension().to_lower() in AUDIO_EXTENSIONS:
   _tracks.append(MUSIC_FOLDER + file)
 _shuffle()
 _play_next()

func _shuffle() -> void:
 _tracks.shuffle()
 _next_index = 0
 # Avoid an immediate repeat across shuffle boundaries when another track exists.
 if _tracks.size() > 1 and stream and _tracks[0] == stream.resource_path:
  var previous := _tracks[0]
  _tracks[0] = _tracks[-1]
  _tracks[-1] = previous

func _play_next() -> void:
 if _tracks.is_empty():
  stop()
  stream = null
  return
 if _next_index == _tracks.size(): _shuffle()
 var next_track := load(_tracks[_next_index]) as AudioStream
 _next_index += 1
 stream = next_track
 if stream: play()
