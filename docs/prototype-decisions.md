# Confirmed design and first prototype

Recorded 2026-11-03 after the legacy investigation.

- Every NPC is a persistent individual. Human and zombie names are alternate presentations of the same identity (Scott Dilkens / Slimy Scott).
- Human and zombie skills are retained separately, becoming active in the matching form. Both trees can be bought from one XP pool regardless of current form. Combat damage and kills earn XP.
- Inventory survives transitions. Undead can drop possessions but cannot use them.
- Death is not the end of the player. Humans become zombies; killed zombies rise again; revival returns them to human life. Tower jumping provides a deliberate route back to undead play.
- Rest advances simulated time visibly. The user has committed to continuous real time; the turn-based alternative is removed. AP is energy, while individual recovery periods pace actions. See urban-dead-research.md for the design rationale.
- The eventual city simulation should have persistent local losses and recoveries, cross-neighbourhood movement, human reconstruction after zombie dispersal, and renewed zombie attraction. Zombie pressure has a slight natural advantage because deaths are easier than syringe-supported revival. Player interventions should matter to the eventual outcome.
- Brain Rot prevents ordinary revival; a powered NecroTech building is required. The prototype also requires the reviver's NecroNet skill, matching the legacy skill description.
- Occupation-driven human assistance should make keeping people alive and reviving them strategically valuable: healing, defence, supplies, shelter maintenance and science.

The authorized first implementation is a single-neighbourhood UI, input, action-economy and interaction prototype. It lives in `godot/`. Cross-neighbourhood migration and the eventual campaign outcome remain future work.

See `godot/README.md` for implemented behavior, provisional tuning, controls, testing and known limitations. This document supersedes the unresolved NPC-persistence question in the earlier investigation.
