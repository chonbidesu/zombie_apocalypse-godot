# Windows beta packaging

Verified on 16 November 2026 with Godot .NET 4.7.2 and the .NET 11.0.100 SDK. The Windows project now targets `net11.0`; the self-contained export bundles .NET 11.0.0. Matching export templates and Windows runtime packs are installed. Use the freshly verified `.runtime/releases/windows-beta-net11/` output or its ZIP, rather than the older `.runtime/releases/windows-beta/` export, which still contains .NET 8 and predates save migration. See [the verification report](release-verification-2026-11-16.md) for exact checks and limits.

Microsoft currently supports both .NET 10 LTS and .NET 11 STS through 14 November 2028. .NET 11 is the installed version and passed this project's Windows build, planner and packaged-runtime tests; this is not a claim that it is faster than .NET 10. An SDK upgrade alone does not retarget a project. Keep the bundled runtime patched by rebuilding and redistributing exports. [Microsoft runtime support policy](https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core).

## Requirements to publish provisionally

The measured machine uses an i5-13400F, RTX 4060 and Godot's Compatibility renderer. A rendered 4,000-NPC, six-hour sleep capture peaked at 496.6 MiB working set and 651.3 MiB private memory. It used the editor executable to run gameplay, rather than an exported release. Intro, character selection, extended campaigns and integrated graphics have not been measured as minimum-hardware tests.

| Item | Provisional Windows beta target |
| --- | --- |
| OS | Windows 10/11, 64-bit; prefer Windows 11 |
| CPU | x86-64 with SSE4.2; no fixed planner thread count. Recommend a modern four-core CPU for the full city. |
| RAM | 8 GB as a conservative beta target; lower capacities need testing. |
| Graphics | OpenGL 3.3 support and a working vendor driver. Integrated graphics are a test candidate, not a verified performance minimum. |
| Storage | Initially allow 2 GB free; replace this estimate with the installed export size plus save/log headroom after building. |
| Display/input | Test at 1280×720 and 1920×1080; keyboard and mouse. 1080p is preferable for text. |

These are project estimates, not certified minimums or a promise of 32× achieved sleep. Godot's simple-project baseline is lower and does not account for this simulation. See [Godot 4.7 system requirements](https://docs.godotengine.org/en/4.7/about/system_requirements.html). Players should receive the complete .NET export and need neither the editor nor the .NET SDK; see [C# prerequisites](https://docs.godotengine.org/en/4.7/tutorials/scripting/c_sharp/c_sharp_basics.html).

## Export in the editor

1. Open this project's `project.godot` in **Godot .NET**, not standard Godot. Keep the solution and project files in the development copy. Press **Build** and resolve any errors.
2. Choose **Editor → Manage Export Templates**. Install the templates matching **4.7.2 stable .NET/Mono** exactly. The editor and matching templates must agree on version and C# support.
3. Select `assets/tables/block_names.csv` in the FileSystem dock. In **Import**, choose **Keep File** and reimport. It is runtime CSV data, not a translation table. Its current translation importer generates unused `.translation` files. The preset explicitly includes the raw CSV and excludes those generated translations.
4. Choose **Project → Export → Windows Beta**. Confirm Windows Desktop, **x86_64**, Compatibility rendering in Project Settings, and the intended beta version under Application. Add a game icon if desired. Player data now uses the fixed custom user directory `Malton Reborn`, independently of the application display name. On first launch, the game copies the three prototype save slots and settings from the former Godot folder, leaving originals and existing destination files untouched.
5. Under **Resources**, retain **Export all resources** plus the supplied filters. Do not switch to selected-scenes-only: this game loads art, music, intro audio, scenes and its C# query script by constructed paths. The preset explicitly includes seven runtime JSON/CSV files and excludes six development JSON metadata files; the verified PCK contains exactly those seven runtime tables/maps. Do not replace that list with `*.json` or `*.csv`, which can accidentally package development saves and reports.
6. Keep **Embed PCK** off, **Include Scripts Content** off and **Include Debug Symbols** off for the distributable. These .NET options are handled by [Godot's exporter](https://github.com/godotengine/godot/blob/4.7.2-stable/modules/mono/editor/GodotTools/GodotTools/Export/ExportPlugin.cs). Do not remove C# script resource paths with a blanket `*.cs` exclusion: the dynamically loaded kernel still needs its resource descriptor. The seven raw-data inclusions alone do not exclude other JSON resources under Export all resources; retain the explicit metadata exclusions as well.
7. Click **Export Project**, choose an empty output directory and **untick Export With Debug**. The default path is `.runtime/releases/windows-beta/MaltonReborn.exe`; create the directory first. This hidden development output is excluded from future resource exports. You can instead choose an empty release folder outside the project. The editor may download runtime packs during the first C# export.
8. Keep the entire output together: the EXE, PCK, `data_...` .NET directory and any other exporter-generated libraries/data. Do not hand-delete DLLs or runtime notice files. Zip the output folder, not the development project. Test after fully extracting the ZIP into a separate directory.

The relevant official workflow is [Exporting projects](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html) and [Exporting for Windows](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_windows.html).

After templates and runtime packs are installed, the equivalent command from the repository root is:

```powershell
$godotDotNet = 'C:\Program Files (x86)\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'
New-Item -ItemType Directory -Force 'godot/.runtime/releases/windows-beta' | Out-Null
& $godotDotNet --headless --path godot --export-release 'Windows Beta'
```

Check the exit code and export log. The preset alone is not proof that a release was produced successfully.

## What the preset omits

- Tests, preview images, reports, tools, documentation, test saves, source project/solution files and debug symbols.
- Generation/provenance JSON under `assets/generated/`.
- Legacy `assets/blocks/` art. The live map uses `assets/minimap/` and `assets/architecture/`.
- Source layers under `assets/character_creation/frames/` and the superseded character sheets directly under `assets/character_creation/`. The background and live `corrected/` sheets remain.
- Hidden development folders such as `.runtime` and editor caches are not bulk-copied as source content. Godot still adds required imported resources, script metadata and .NET runtime output to the exported package.

The reviewed legacy/source PNG exclusions cover 74 images totaling 142.8 MiB in the working project. That is source size, not a measured ZIP saving. No artwork was deleted. Other runtime art families are deliberately retained until an exported-build audit proves a file unused; a static unused-file scan cannot fully resolve arbitrary path construction. In particular, do not exclude active settings, architecture, intro, music, item or character assets merely because they are not directly referenced by a scene.

## Verify the extracted beta

- Start the title screen and create male/female characters across the occupations, including Corpse. Play or skip the introductions and check music, narration and sound effects.
- Create the full Malton city and a random city. Check map/building art, portraits, inventory icons and DNA skill-report links. Missing raw tables can break world generation even when the title screen opens.
- Save, exit and load. Verify Settings persist. Saves and settings now go under `%APPDATA%\Malton Reborn\`. The folder name stays fixed when the display name changes. Check first-launch migration from `%APPDATA%\Godot\app_userdata\Malton • Neighbourhood Prototype\`: only the three player slots and `settings.cfg` are copied, existing destination files are preserved, and prototype originals remain. A completion marker prevents later launches from resurrecting deleted slots. Do not delete that marker as routine cleanup.
- Exercise rest, sleep, Wake and Escape with the full population. Check logs for a missing C# query script/assembly, not just successful title startup. Test on a computer without Godot or an installed .NET SDK to verify the runtime bundle.
- Check UI legibility on a lower-resolution laptop and collect CPU/GPU/RAM, population, frame behavior and sleep completion times from testers. That evidence should determine the final minimum requirements.
- Include a player README, beta version, known issues and applicable engine/font/runtime credits with the ZIP. Keep private debug symbols separately if needed for investigation.

The failing test suites were reconciled on 15 November 2026. NPC-balance fixtures now explicitly assign the intended maintainer/builder training and home; survival fixtures explicitly set engineer/doctor roles, supplies and homes. Opening-population checks reflect distributed positions rather than obsolete mandatory two-to-three-person groups. Environment checks use current single-sentence prose and description version 7. Player-facing location descriptions now show visible exterior ruins/ransacking, indoor structural limits and darkness, and unpowered generator damage without revealing indoor equipment outside. See the fresh validation results below. The rendered sleep capture still exceeded its 20 ms worst-frame limit on wake; this work does not resolve that performance limitation.

Fresh targeted validation: NPC balance 99/99; survival 65/65; environment 430/430; simulation 235/235; ruin/AP debt 126/126; sleep 15/15; threaded sleep 24/24 (26,947 ordered actions); save migration 16/16; rendered interface 282/282; rendered start screen 91/91. The save-slot suite also passed. Migration coverage includes all three slots and settings, preserving originals and existing destination files, ignoring development saves, absent legacy data, retry after failure, and not restoring deleted slots on later launches. These checks do not replace the extracted-release and clean-machine checks above.
