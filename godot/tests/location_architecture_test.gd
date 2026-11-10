extends SceneTree
const Architecture = preload("res://scripts/location_architecture.gd")
const Art = preload("res://scripts/minimap_art.gd")
const Sim = preload("res://scripts/simulation.gd")
const C = preload("res://scripts/catalog.gd")
var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)

func _initialize() -> void:
 run.call_deferred()

func run() -> void:
 var sim = Sim.new()
 check(sim.start(1729,"Volunteer",{"mode":"malton","survivors":0,"zombies":0}) == "","Original city loads")
 var before = sim.rng.state
 var same = 0
 var comparisons = 0
 var counts = [0,0,0]
 var changed = 0
 var samples = {}
 for y in range(100):
  for x in range(100):
   var block = {"type":"office","x":x,"y":y}
   var style = Architecture.variant_for(sim,block)
   counts[style] += 1
   samples[style] = block
   if x < 99:
    comparisons += 1
    if style == Architecture.variant_for(sim,{"type":"office","x":x+1,"y":y}): same += 1
   if y < 99:
    comparisons += 1
    if style == Architecture.variant_for(sim,{"type":"office","x":x,"y":y+1}): same += 1
   if Architecture.district_style(1729,x,y) != Architecture.district_style(1730,x,y): changed += 1
 check(float(same)/comparisons > 0.65,"Adjacent blocks predominantly share architectural families")
 for count in counts: check(count > 1800 and count < 4800,"Every architectural family has substantial city coverage")
 check(changed > 4000,"Changing the seed changes neighbourhood layouts")
 for kind in C.NORMAL_BUILDINGS:
  if kind == "mall": continue
  check(Architecture.eligible({"type":kind}),"Repeatable building covered: "+kind)
 for kind in ["mall","cathedral","mansion","power_station","stadium","gatehouse","aquarium"]:
  check(not Architecture.eligible({"type":kind}),"Landmark excluded: "+kind)
 for property in ["fort","zoo","complex"]:
  var b = {"type":"hospital",property:"Unique property"}
  check(not Architecture.eligible(b),"Property membership excludes neighbourhood variants: "+property)
 var locations = Architecture.new()
 for group in Architecture.GROUPS:
  for kind in group:
   var art = Art.new()
   var hashes = {}
   for variant in range(3):
    var b: Dictionary = samples[variant].duplicate()
    b.type = kind
    for inside in [false,true]:
     if inside and kind in Architecture.OPEN_GROUND: continue
     var setting = locations.setting_for(sim,b,inside)
     check(setting != null,"Setting exists: %s/%d/%s" % [kind,variant,inside])
     if setting is AtlasTexture:
      check(setting.region.end.x <= setting.atlas.get_width() and setting.region.end.y <= setting.atlas.get_height()+0.01,"Setting region stays inside sheet")
    for status in range(4):
     var texture = art.model(kind,status,variant)
     check(texture != null,"Map state exists: %s/%d/%d" % [kind,variant,status])
     if texture == null: continue
     var digest = hash(texture.get_image().get_data())
     if kind not in Architecture.OPEN_GROUND and kind != "junkyard":
      check(not hashes.has(digest),"Map design/state has distinct pixels: %s/%d/%d" % [kind,variant,status])
      hashes[digest] = true
   if kind in Architecture.OPEN_GROUND or kind == "junkyard":
    for variant in range(3):
     check(art.model(kind,0,variant) == art.model(kind,1,variant) and art.model(kind,0,variant) == art.model(kind,3,variant),"Open land/junkyards never select powered art: "+kind)
   art = null
 for variant in range(3):
  var office: Dictionary = samples[variant].duplicate()
  office.type = "office"
  var lab = office.duplicate()
  lab.type = "necrotech_lab"
  check(locations.setting_for(sim,office,false) == locations.setting_for(sim,lab,false),"NecroTech exterior preserves office disguise")
  check(locations.setting_for(sim,office,true) != locations.setting_for(sim,lab,true),"NecroTech has a laboratory interior")
 var actual = sim.blocks.filter(func(b): return Architecture.eligible(b) and b.type == "hospital")[0]
 var style_before = Architecture.variant_for(sim,actual)
 var map = Art.new()
 actual.ruin = 0
 actual.generator = false
 check(Art.state(sim,actual) == 0,"Repaired unlit state")
 actual.generator = true
 actual.fuel_until = sim.minute+100
 check(Art.state(sim,actual) == 1,"Repaired lit state")
 actual.ruin = 3
 check(Art.state(sim,actual) == 3,"Powered ruin is a separate state")
 actual.generator = false
 check(Art.state(sim,actual) == 2,"Unlit ruin state")
 check(Architecture.variant_for(sim,actual) == style_before,"Repair/power never reroll architecture")
 var selected: AtlasTexture = map.texture_for(sim,actual)
 var source: Texture2D = map.model(actual.type,2,style_before)
 check(selected.atlas == source,"Minimap uses the shared location style")
 check(sim.rng.state == before,"Art consumes no gameplay randomness")
 check(sim.save_to("user://architecture-test.json") == OK,"Architecture test save succeeds")
 var restored = Sim.new()
 check(restored.load_from("user://architecture-test.json") == "","Architecture test save restores")
 check(Architecture.variant_for(restored,restored.block_at(actual.x,actual.y)) == style_before,"Save/load keeps the same architecture without schema changes")
 DirAccess.remove_absolute(ProjectSettings.globalize_path("user://architecture-test.json"))
 print("Architecture: %d checks, %d failures; adjacent similarity %.1f%%, distribution %s" % [checks,failures,100.0*same/comparisons,str(counts)])
 quit(1 if failures else 0)
