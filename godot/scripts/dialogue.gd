extends RefCounted

const ROLES = {
 "Doctor":["Check the dressings before we move.","Clean dressings are worth their weight in gold.","If you find medical supplies, bring them back."],
 "Medic":["Keep pressure on it. I am coming.","Save a bandage for the next person.","Stay behind me if you are hurt."],
 "Scientist":["A working lab gives us another chance.","Keep the samples sealed, whatever you do.","There has to be something of them left."],
 "NecroTech Lab Assistant":["Do not touch the needle with bare hands.","I should have read the evacuation memo.","We need the lab equipment intact."],
 "Engineer":["Pass me that brace. This joint is slipping.","Nothing stays fixed in this city.","A toolbox and a little time. That is all I need."],
 "Guard":["Watch the doorway. I will cover you.","Keep a clear route to the exit.","Make every round count."],
 "Private":["Check your corners. Then check them again.","Save your ammunition for a clear shot.","Nobody wanders off alone."],
 "Scout":["Always know your next way out.","The rooftops might still be clear.","I will check the route before we move."],
 "Police Officer":["Stay together. Keep the entrance clear.","I used to complain about night shifts.","Keep your hands where I can see them."],
 "Firefighter":["Leave a clear path to the doorway.","The axe is still good. That is something.","We used to run towards trouble, too."],
 "Consumer":["I knew where everything was in this place.","I would give anything for a hot meal.","Check the back shelves. People miss those."]
}

static func choices(a: Dictionary, b: Dictionary, context: Dictionary) -> Array:
 if not a.human:
  var sounds: Array = ["Grrrhh...","Mrrrraah...","Hrrrngh...","*a wet, rattling moan*","*drools onto the ground*","*low, hungry growling*"]
  if context.enemy: sounds.append_array(["GRAAAGH!","*snarls and bares broken teeth*"])
  if "death_rattle" in a.zombie_skills:
   sounds.append("BARHAH! HARMANZ!" if context.enemy else "Mrh? Graaagh.")
  if context.lit: sounds.append("*squints into the light and groans*")
  return sounds
 var lines: Array = ROLES.get(a.job,["We get through this together.","Check the corners before you settle in.","I wonder who is still out there."]).duplicate()
 if context.enemy: return ["Keep back! There is one right here!","Stay together! Do not let it corner you!","Watch its hands!"]
 if a.hp < 25: return ["I could use a hand over here.","That is more blood than I like to see.","A dressing. Please tell me someone has one."]
 if context.pounding: lines.append_array(["Something is hammering on the barricades.","Hold those boards steady. They are still outside."])
 if context.bodies and a.inside: lines.append_array(["We should get those bodies outside.","I do not like leaving bodies in our shelter."])
 if a.inside and context.building and not context.lit: lines.append_array(["Mind the debris. It is hard to see in here.","I wish we had a working light."])
 if a.inside and b.generator and b.generator_hp < 6: lines.append_array(["That generator casing has taken a beating.","We should fix the generator before adding fuel."])
 if a.inside and b.ruin > 0: lines.append("This place needs more than a quick patch job.")
 if context.injured_ally and a.job in ["Doctor","Medic"]: return ["Hold still. I will take a look.","Save the clean bandages for that wound.","We should treat that before it gets worse."]
 return lines
