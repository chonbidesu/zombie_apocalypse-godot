extends RefCounted
## Presentation only: never delays simulation, damage, or player feedback.
var last_seen: int = 0
var rows: Array = []
var pending: Array = []
var timer: float = 0.0
const INTERVAL = 0.8
const MAX_PENDING = 24
const SPEECH_ACTIONS = ["speech","say","broadcast","phone","request"]

func reset(history: Array = []) -> void:
 last_seen = 0
 rows.clear()
 pending.clear()
 timer = 0.0
 # Loading doesn't replay an entire previous session as new notifications.
 for event in history:
  last_seen = maxi(last_seen,int(event.id))
 for event in history.slice(maxi(0,history.size()-40)):
  _append(event)

func ingest(history: Array) -> bool:
 var changed = false
 for event in history:
  if event.id <= last_seen: continue
  last_seen = int(event.id)
  if event.category in ["PLAYER","ALERT","WORLD"] or event.urgent or event.action in SPEECH_ACTIONS or event.action == "breach_noise":
   # Summarize earlier routine work before inserting an important event, preserving order.
   if not pending.is_empty(): _flush_summary(); changed = true
   _append(event)
   changed = true
  else:
   pending.append(event.duplicate(true))
   if pending.size() >= MAX_PENDING:
    _flush_summary()
    changed = true
 return changed

func update(delta: float) -> bool:
 timer += delta
 if pending.is_empty():
  timer = 0.0
  return false
 if timer < INTERVAL: return false
 timer = 0.0
 if pending.size() >= 4:
  _flush_summary()
 else:
  _append(pending.pop_front())
 return true

func _flush_summary() -> void:
 # A short summary retains category and count; full details stay in simulation history.
 var counts = {"ALLY":0,"ENEMY":0}
 for event in pending: counts[event.category] = counts.get(event.category,0)+1
 var summary = pending.back().duplicate(true)
 summary.category = "ENEMY" if counts.ENEMY > 0 else "ALLY"
 summary.text = "Nearby activity: %d friendly / %d hostile actions. Details in History." % [counts.ALLY,counts.ENEMY]
 summary.action = "summary"
 _append(summary)
 pending.clear()

func _append(event: Dictionary) -> void:
 var row = event.duplicate(true)
 row.count = 1
 if not rows.is_empty() and not row.urgent and row.category in ["ALLY","ENEMY"]:
  var previous = rows.back()
  if previous.text == row.text and previous.category == row.category and previous.actor == row.actor and row.step-previous.step <= 100:
   previous.count += 1
   previous.step = row.step
   previous.minute = row.minute
   return
 rows.append(row)
 while rows.size() > 150: rows.pop_front()

func format_rows(source: Array, filter_name: String = "All") -> String:
 var lines = PackedStringArray()
 for event in source:
  if filter_name == "You" and event.category != "PLAYER": continue
  if filter_name == "Allies" and event.category != "ALLY": continue
  if filter_name == "Hostiles" and event.category not in ["ENEMY","ALERT"]: continue
  var colour = {"PLAYER":"f3ce7b","ALLY":"a9ceba","ENEMY":"ed9a87","ALERT":"ffb392","WORLD":"b4bec3"}.get(event.category,"eeeeee")
  if event.category in ["ENEMY","ALERT"] and event.action in ["attack","bite"]:
   # Older saves only recorded the outcome in the combat narration.
   if event.get("attack_hit",str(event.text).contains(" for ") and str(event.text).contains(" damage.")):
    colour = "d77e74"
  var stamp = "D%d %02d:%02d" % [int(event.minute)/1440+1,(int(event.minute)%1440)/60,int(event.minute)%60]
  var message = str(event.text).replace("[","[lb]")
  if event.action in SPEECH_ACTIONS:
   var split = message.find(": ")
   if split >= 0:
    message = "%s[color=#e5d5ed][i]“%s”[/i][/color]" % [message.left(split+2),message.substr(split+2)]
  var repeated = " (×%d)" % event.get("count",1) if event.get("count",1)>1 else ""
  lines.append("[color=%s][%s] %s  %s%s[/color]" % [colour,stamp,event.category,message,repeated])
 return "\n".join(lines)
