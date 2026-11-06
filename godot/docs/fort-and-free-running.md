# Fort traversal and ruined-roof Free Running

These rules apply equally to the player and NPC transactions in original Malton, generated cities and saved maps. `tests/fort_rules_test.gd` and `tests/free_running_test.gd` cover them, and both are included in `launch.ps1 -Test`.

## Entry and internal movement

Outside characters can approach the gatehouse exterior, then use Enter. The gatehouse exterior does not grant access to the compound. No ordinary movement or Free Running may enter through another perimeter square. Free Running from an outside building into the gatehouse is rejected without spending AP; the character must approach at ground level. Human exterior gatehouse entry works through VSB (strength 10), while zombies still need the exterior barricades removed.

Moving from the compound to its gatehouse puts either form inside it, even when its exterior barricades are EHB. Moving from the gatehouse into the compound puts the character outside the destination building. Other internal building-to-building movement preserves the interior only for human Free Runners entering intact buildings. The Armoury always requires a ground entrance; Free Running out of it is allowed.

## Exits and the no-trapping rule

The user explicitly selected **one-way map exits from every perimeter square**. Every adjacent exterior destination is accessible on foot, from either an internal building or the grounds. Such exits land at street level. The navigation graph has directed edges: the legal exit does not become a legal entry across the same wall.

Survivors inside the gatehouse with Free Running can enter an adjacent intact building outside the fort when the gatehouse is VSB or lower. Heavy through EHB gatehouse barricades block this roof-to-roof route. A normal map click still exits, landing outside the destination; an explicitly requested Free Run is rejected without AP loss. Zombies always use ground exits. Internal gatehouse access remains available to them even at EHB.

The Leave button reports that the main doors are blocked at Heavy or greater and spends no AP. Either form can use the main doors through VSB. The player cannot be trapped by barricades, and NPCs use the same map-exit fallback.

## Fort body dumping

A survivor may dump a body sharing their current interior or fort grounds square. This costs exactly **5 AP**, without a scouting discount, moves the survivor inside the fort's gatehouse, and places the body outside the gatehouse at that square. Dormancy is preserved. Failed actions relocate neither actor. A player with positive AP may overdraw for the five-AP dump; NPCs normally require the full amount. Dumping bodies in ordinary buildings keeps the original cost and behavior.

## Ruins

An attempted Free Run to a different ruined building consumes the normal human movement AP and places the character outside that destination. It logs the supplied collapsed-wall message. A 20% roll causes five HP damage and the supplied fall-injury message; HP is clamped to at least one, without death or transformation from the fall. Infection remains a separate action consequence. Ground movement, non-runners and undead do not roll for roof falls.

The starting building may be ruined: Free Running out into an intact neighbor is safe. Movement within one large building envelope (mall, cathedral, mansion, power station or stadium) stays inside even across ruined sections, without a fall roll and without requiring Free Running. Identically typed buildings with different complex identities are separate envelopes. Fort Armoury/gatehouse restrictions are checked before ruin crossing rules; a blocked roof route is not treated as a jump.

Ruin and barricades are independent. An indoor zombie may ransack to full ruin with EHB barricades still intact, and loading/normalization does not remove those barricades.

## Artwork and source interpretation

Creedy's east-facing passage is hidden in this projection. Its north and south jamb towers overlap in depth, and the perimeter turns into them; no visible east-facing arch is drawn. Perryn's south-facing arch remains visible. Built-in image-generation provenance and the exact correction prompt are in `assets/generated/fort-gatehouse-profile-manifest.json`.

References consulted: [Building Types — Forts](https://wiki.urbandead.com/index.php/Building_Types#Forts), [Barricades — Exiting](https://wiki.urbandead.com/index.php/Barricades#Exiting_Barricaded_Buildings), plus the user's supplied [Free Running](https://wiki.urbandead.com/index.php/Free_Running) and [Ruin](https://wiki.urbandead.com/index.php/Ruin) excerpts. The first two pages conflict over heavily barricaded gate exits. The explicit project choices take precedence: no trapping, gatehouse-only entry, one-way ground exits across any perimeter square, and gatehouse roof exits only through VSB.
