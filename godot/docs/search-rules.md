# Search rules

Searches use two independent rolls: first whether anything is found, then a weighted item selection. The JSON in assets/tables/search_tables.json contains relative loot weights, not percentages per AP. Scaling or adding weights cannot raise the global find rate.

| State | Total find chance |
|---|---|
| Intact, powered indoor building | 30% (NecroTech 28%; mall 26%) |
| Intact, unpowered indoor building | 20% |
| Unpowered dark indoor building, including ruins | 1% (prototype estimate for near-zero searching) |
| Ransacked/ruined building with enough light to search | 10%, overriding powered bonuses and Bargain Hunting |
| Outside any building or on open ground | 5%, without mall bonuses |

Dark search buildings are banks, cinemas, nightclubs, armouries and malls. Every exterior and open-ground type uses the same street grab bag. Newspapers, clothing, books, glass and bottles are common relative to rare tools: axes, crowbars, knives, pipes, bats, shovels, golf clubs, fuel, spray cans, flashlights and binoculars. Syringes, firearms (including flare guns) and ammunition are excluded. Flashlights are inspectable, weigh 2%, and do not change building lighting or search bonuses. No entry is required for an outside search.

Shopping selects a store's distribution inside a mall. Without Shopping, store selections are ignored. Bargain Hunting doubles intact indoor mall find odds: 26% becomes 52% when lit. Gun-store weights give approximately 17% each for magazines and shells with that boost. Targeted hardware searches include fuel, crowbars, axes and rare generators. Drugstores mainly supply first aid, with books and candy as minor supplies; an ordinary unlit hospital is a better FAK source than an ordinary mall drugstore.

An unlit hospital finds FAKs at 17% per search. NT syringe rates are 12.5% unlit and 17.5% lit. Police departments favor ammunition and firearms, with flak jackets and flare guns absent from targeted mall gun stores. Found firearms are empty 25% of the time; otherwise they contain between one round and one less than capacity. Player narration reports their ammunition.

Some approximate per-item percentages supplied in the design add up beyond the global find total. Global totals take precedence; loot weights preserve the requested relative priorities rather than promising incompatible individual rates. The lit NT and mall totals are chosen within the requested 25–33% range to reproduce the syringe and boosted gun-store examples. Total darkness takes precedence at 1%; otherwise ransacking or ruin sets a flat 10%. Standard unlit buildings remain at 20%.

The 100-item hard stop is additional to existing percentage encumbrance. Rejected searches spend no AP, consume no RNG and generate no items. Dropping or using an item restores eligibility if both limits permit collection. Low-level fixture creation and existing overloaded saves remain supported.

Search tests cover state precedence, normalized distributions, seeded frequencies, two-roll RNG use, partial ammunition, targeting, skill scope, outside availability and inventory rejection. NPC supply-trip tests isolate routing from rare generator sampling.

## Coverage audit, 4 November 2026

All **54 catalog items** have reachable search locations, and all **46 location types** resolve to nonempty tables. [search_coverage.json](../assets/tables/search_coverage.json) lists each item and location with calculated unpowered, powered, ruined and powered-ruin per-search rates, plus mall-store rates. Unsupported power/ruin states are null. Every exterior uses the same outdoor grab bag. Regenerate this report with `tests/search_coverage_test.gd`.

The audit added the missing city map to libraries, offices and railway stations. Flashlights already existed in outdoor searches and now also occur rarely in fire stations and warehouses. Both are prototype items with estimated weights. The dead fir tree's old park-only table was unreachable because outdoor searches use the shared grab bag; museum salvage now makes it obtainable. Seasonal decorations remain available year-round.

Additional documented locations were filled for clothing and miscellaneous supplies, including rare pub shotguns, school knives, industrial clothing and warehouse fuel/wine. Existing configured NT syringe rates remain unchanged when adding laboratory clothing. Cinema wine/phones and mall fuel follow the requested prototype behavior.

The [official FAQ](https://www.urbandead.com/faq.html) confirms location, light and disrepair affect searching but publishes no exact item percentages. The [building guide](https://gamefaqs.gamespot.com/webonly/392349-urban-dead/faqs/80292/building-types) and [item guide](https://gamefaqs.gamespot.com/webonly/392349-urban-dead/faqs/80292/weapons-and-items) corroborate locations. The official wiki Search_Odds page was blocked during this audit. **The remaining historical per-item probabilities are unverified; configured weights are estimates, not claimed official rates.** [search_provenance.json](../assets/tables/search_provenance.json) records the sources, additions and deliberate extensions.
