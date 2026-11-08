extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const W = preload("res://scripts/world_builder.gd")

class Trial extends Sim:
 var actions: Dictionary = {}
 var blocked_moves = 0
 var travelled: Dictionary = {}
 var initial_humans: Dictionary = {}
 func execute(a: Dictionary,command: String,target_id: int = -1,data: Dictionary = {}) -> void:
  var key = ("human_" if a.human else "zombie_")+command
  actions[key] = int(actions.get(key,0))+1
  super(a,command,target_id,data)
  if a.human and current_block(a).id != a.home: travelled[a.id] = true
 func _try(a: Dictionary,command: String,target_id: int = -1,data: Dictionary = {}) -> bool:
  if command == "move" and not reason(a,command,target_id,data).is_empty(): blocked_moves += 1
  return super._try(a,command,target_id,data)

func snapshot(s) -> Dictionary:
 var humans = 0
 var standing = 0
 var zombies = 0
 var dormant = 0
 var returned = 0
 var hp = 0
 var groups = {}
 for a in s.actors:
  if a.id == 0: continue
  if a.human:
   humans += 1
   if not a.down:
    standing += 1
    hp += a.hp
    var key = "%d/%s" % [s.current_block(a).id,a.inside]
    groups[key] = int(groups.get(key,0))+1
  elif not a.down: zombies += 1
  if a.dormant: dormant += 1
  if s.travelled.has(a.id) and a.human and s.current_block(a).id == a.home: returned += 1
 var grouped = 0
 for n in groups.values():
  if n >= 2: grouped += n
 var world = s.population()
 return {"day":(s.minute-480)/1440,"human_form":humans,"survivors":standing,"mean_human_hp":float(hp)/maxi(1,standing),"active_zombies":zombies,"dormant":dormant,"powered":world.powered,"ruined":world.ruined,"grouped_survivors":grouped,"travelled_survivors":s.travelled.size(),"returned_home":returned,"blocked_moves":s.blocked_moves,"actions":s.actions.duplicate(),"deaths":s.metrics.deaths,"revivals":s.metrics.revivals}

func _initialize() -> void:
 var label = "current"
 var only = "all"
 var population_args = PackedStringArray()
 var args = OS.get_cmdline_user_args()
 for arg in args:
  if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
  if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
  if arg.begins_with("--population="): population_args = arg.trim_prefix("--population=").split(",")
 if not population_args.is_empty():
  if population_args.size() != 5 or population_args[0] not in ["random","malton"] or int(population_args[2]) < 1:
   push_error("Expected --population=MODE,SEED,DAYS,SURVIVORS,ZOMBIES with mode random or malton and at least one day.")
   quit(2)
   return
 var jobs = []
 for seed_value in [23,71,119]:
  jobs.append({"mode":"sandbox","seed":seed_value,"days":7})
  jobs.append({"mode":"random","seed":seed_value,"days":7})
 for seed_value in [23,71]:
  jobs.append({"mode":"siege","seed":seed_value,"days":5})
  jobs.append({"mode":"malton","seed":seed_value,"days":7})
 var report = {"label":label,"source_sha256":FileAccess.get_file_as_string("res://scripts/simulation.gd").sha256_text(),"runs":[]}
 report.source_files = {}
 for path in ["simulation","npc_ai","extended_rules","catalog"]:
  report.source_files[path] = FileAccess.get_file_as_string("res://scripts/"+path+".gd").sha256_text()
 if label == "diagnostic": jobs = [{"mode":"sandbox","seed":23,"days":5}]
 if label == "holdout": jobs = [{"mode":"random","seed":307,"days":14},{"mode":"random","seed":997,"days":14},{"mode":"malton","seed":307,"days":14},{"mode":"siege","seed":307,"days":5}]
 # Population trial arguments are mode, seed, days, survivors, zombies.
 if population_args.size() == 5:
  jobs = [{"mode":population_args[0],"seed":int(population_args[1]),"days":int(population_args[2])}]
 var started = Time.get_ticks_msec()
 for job in jobs:
  if only != "all" and job.mode != only: continue
  var s = Trial.new()
  if job.mode in ["sandbox","siege"]: s.start(job.seed)
  else:
   var config = W.defaults(30,30) if job.mode == "random" else {"mode":"malton","survivors":300,"zombies":600}
   if job.mode == "random":
    config.malls = 2
    config.survivors = 45
    config.zombies = 90
   if population_args.size() == 5:
    config.survivors = int(population_args[3])
    config.zombies = int(population_args[4])
   s.start(job.seed,"Private",config)
  var player = s.player()
  player.down = true
  player.x = 0
  player.y = 0
  player.inside = false
  if job.mode == "siege":
   for a in s.actors:
    if a.id == 0: continue
    a.x = 4
    a.y = 4
    a.home = 44
    a.inside = a.human
    a.down = false
    a.dormant = false
    a.hp = 50
   s.blocks[44].barricade = 4
  s.reindex()
  var run = {"mode":job.mode,"seed":job.seed,"initial":snapshot(s),"days":[]}
  for day in range(job.days):
   s.advance(1440)
   run.days.append(snapshot(s))
   if label == "diagnostic":
    for a in s.actors:
     if a.id > 0 and a.human: print("ACTOR ",a.id," hp=",a.hp," ap=",a.ap," at=",s.current_block(a).id," inside=",a.inside," home=",a.home," goal=",a.supply_goal," need=",a.supply_kind," cades=",s.current_block(a).barricade)
   print("BALANCE ",label," ",job.mode," seed=",job.seed," day=",day+1," humans=",run.days.back().survivors," revives=",s.metrics.revivals," blocks=",s.blocked_moves)
  report.runs.append(run)
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
  var file = FileAccess.open("res://reports/balance-"+label+".json",FileAccess.WRITE)
  report.elapsed_ms = Time.get_ticks_msec()-started
  file.store_string(JSON.stringify(report," "))
  file.close()
 print("BALANCE COMPLETE: ",label," runs=",report.runs.size()," ms=",Time.get_ticks_msec()-started)
 quit()
