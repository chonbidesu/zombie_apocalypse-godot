extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const C = preload("res://scripts/catalog.gd")
var checks = 0
var failures = 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func isolated():
 var s = Sim.new()
 s.start(991)
 for a in s.actors:
  if a.id != 0: a.down = true; a.next_think = 1000000
 s.player().ap = 10
 s.player().busy_until = s.now()
 return s
func _initialize() -> void:
 var s = isolated()
 var p = s.player()
 var b = s.current_block(p)
 check(s.begin_sleep().is_empty() and s.sleeping and s.resting and s.rest_target == 50,"Sleep starts with a full recovery target")
 check(s.time_speed() == C.SLEEP_SPEED and C.SLEEP_SPEED > C.REST_SPEED,"Sleep fast-forwards much faster than ordinary rest")
 s.elapse(1.0)
 check(s.minute == 608 and p.ap == 14,"Sleep speeds the world while preserving normal AP regeneration")
 check(not s.act("search").ok,"Actions blocked while sleeping")
 s.stop_rest("You wake up.")
 check(not s.sleeping and not s.resting and s.time_speed() == 1.0,"Manual wake restores normal time")
 p.ap = -2
 check(s.begin_sleep().is_empty(),"Sleep accepts AP debt")
 s.advance(52*30)
 check(p.ap == 50 and not s.sleeping and s.last_rest_notice.contains("awaken"),"Sleep repays debt and wakes naturally at fifty AP")
 p.ap = 10
 var z = s.actors[15]
 z.human = false; z.down = false; z.hp = 50; z.x = p.x; z.y = p.y; z.inside = p.inside
 s.reindex()
 check(s.threats() and s.begin_sleep().is_empty(),"A nearby threat does not itself prevent or interrupt sleep")
 z.ap = 50
 s.execute(z,"say",-1,{"text":"Graaagh"})
 check(s.sleeping,"Ordinary danger and speech do not wake the sleeper")
 # Deterministically obtain one successful attack, then a second within ten minutes.
 z.zombie_skills = ["vigour_mortis","death_grip","rend_flesh"]
 p.hp = 50
 for i in range(100):
  s.execute(z,"attack",0,{"unarmed":true})
  if p.hp < 50: break
 check(s.sleeping and s.sleep_damage_hits == 1,"One injury does not wake the sleeper")
 var hp = p.hp
 for i in range(100):
  s.execute(z,"attack",0,{"unarmed":true})
  if p.hp < hp: break
 check(not s.sleeping and s.last_rest_notice.contains("Sustained"),"Two injuries in a sustained attack wake the sleeper")
 p.busy_until = s.now(); p.ap = 10; p.hp = 50
 s.begin_sleep()
 s.sleep_damage_hits = 1; s.sleep_last_damage_at = s.now()-11
 for i in range(100):
  s.execute(z,"attack",0,{"unarmed":true})
  if p.hp < 50: break
 check(s.sleeping and s.sleep_damage_hits == 1,"An isolated old injury does not count as sustained damage")
 s.stop_rest(); p.ap = 10
 z.inside = false; p.inside = true
 s.set_barricade_strength(b,2)
 s.reindex(); s.begin_sleep()
 for i in range(200):
  s.execute(z,"break",-1,{"unarmed":true})
  if s.barricade_strength(b) == 1: break
 check(s.sleeping,"Pounding and partial barricade damage do not wake the sleeper")
 for i in range(200):
  s.execute(z,"break",-1,{"unarmed":true})
  if s.barricade_strength(b) == 0: break
 check(not s.sleeping and s.last_rest_notice.contains("crash"),"The final collapsing barricade wakes the sleeper")
 s = isolated(); p = s.player()
 p.ap = 49; s.clock_step = 5099; s.minute = 509
 s.begin_sleep()
 s.elapse(0.05)
 check(not s.sleeping and s.minute == 510 and s.clock_step == 5100,"Wake-up discards pending fast-forward steps immediately")
 print("SLEEP CHECKS: ",checks," FAILURES: ",failures)
 quit(0 if failures == 0 else 1)
