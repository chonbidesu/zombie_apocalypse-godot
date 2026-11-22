# Windows release verification — 16 November 2026

Godot .NET 4.7.2, the installed .NET SDK 11.0.100, and the project's Windows `net11.0` target passed build, planner, export and packaged-runtime verification. The new self-contained release bundles Microsoft.NETCore.App 11.0.0. The original user-created export is unchanged.

## Runtime choice

The original project targeted .NET 8, so installing SDK 11 had still produced a .NET 8.0.34 export. The Windows target is now explicitly .NET 11. Godot's versioned documentation permits .NET 8 or later; the installed Godot SDK references its net8.0 GodotSharp API assembly successfully from this net11.0 project. Both Debug and ExportRelease compiled successfully. This verifies this particular Windows project and engine combination, not every Godot plugin or platform.

Microsoft lists both .NET 10 LTS and .NET 11 STS as supported through 14 November 2028. Version 11 is already installed, is current, and passed these checks. No comparison against .NET 10 was performed, and no throughput improvement is claimed. Android retains the pre-existing net9.0 override and was not tested; this deliverable is Windows x86-64 only.

Sources: [Godot C# prerequisites](https://docs.godotengine.org/en/4.7/tutorials/scripting/c_sharp/c_sharp_basics.html), [Microsoft support policy](https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core).

## Planner and recovery checks on .NET 11

| Suite | Checks | Failures |
| --- | ---: | ---: |
| Managed planner / reference equivalence | 972 | 0 |
| Managed spatial queries | 404 | 0 |
| Directed route cache | 1,536 | 0 |
| Ordered planner with serial, single-worker, four-worker and automatic limits | 29 | 0 |
| Threaded sleep, rest and Wake/Escape | 24 | 0 |
| Rendered title screen, after audio-exit change | 91 | 0 |

Each ordered-planner configuration matched 8,993 actions and 1,031 routes. Threaded sleep matched 26,947 NPC actions and the reference final state, including RNG and recovery boundaries. Tests retain CPU-dependent fallback behavior; the framework update introduces no mandatory planner thread count.

## Export findings and fixes

The original `windows-beta/` folder contains 188 files, 695,003,624 bytes, and an 830-entry Godot 4.7.2 PCK. All PCK entry hashes passed. Its kernel, world generation, resources, save/load and sleep/Wake passed 373 smoke checks in an isolated package copy, but it lacks the new save migration and bundles the retired .NET 8 runtime. Use the replacement for distribution.

The replacement `windows-beta-net11/` folder contains 201 files and an 826-entry PCK. All entry hashes passed. Its seven raw JSON/CSV tables/maps exactly match the intended runtime data. Tests, tools, reports, docs, old block art, generated source art, translation imports, project/solution files and debug symbols are excluded. Six additional development JSON metadata files were explicitly excluded: the corrected-atlas manifest and verification report, mast-import input, search coverage and provenance reports, and terminal generation prompts. All runtime artwork families remain available.

The exporter initially failed to fetch .NET 11 runtime packs while network access was restricted. After a successful NuGet restore, export and publish logs were checked for errors, not just the command exit code: Godot can emit an EXE/PCK and return zero despite a failed .NET publish. The final package includes the complete runtime directory and the correct net11.0 runtime configuration.

A title-audio shutdown warning was reproduced during launch/exit testing. The title now stops and releases its MP3 before the Quit button or window-close handler exits, allowing the audio thread to release playback. The final rendered smoke test exited through the real title Quit callback with no warnings or errors. Forcibly ending the engine with `--quit-after` bypasses that orderly close and may still report the active MP3 as leaked; it is not the normal Quit path.

## Packaged smoke method and results

Official release templates disable the external `--script` override. `tools/verify_export.py` therefore creates a **separate diagnostic copy**, changes only the main-scene setting in `project.binary`, and adds two harness files. Every production resource payload, the EXE and the entire .NET runtime are verified identical to the distribution folder. The diagnostic entry point is not present in the distributed ZIP.

The final rendered diagnostic run passed **376 checks**, including loading packaged textures, fonts, audio and scenes; constructing the original 10,000-block city with 2,000 human and 2,000 zombie NPCs; random-city generation; raw CSV/JSON availability; save/load; C# kernel instantiation and planner activation; sleep's worker and hidden perception; waking naturally at 50 AP; manual Wake and Escape; title music; save/settings migration before settings load; and clean normal Quit. Deterministic description caches are populated before comparing complete saved/loaded block dictionaries.

Tests use isolated APPDATA directories. Runtime probes use an empty DOTNET_ROOT, disable multilevel lookup, and omit dotnet from PATH. The host trace confirms the packaged `data_.../coreclr.dll` and .NET 11.0.0 were loaded. This is strong bundled-runtime verification on the development PC, not a substitute for a fresh Windows machine without SDKs or lower-spec hardware.

The ZIP is fully extracted and its files compared byte-for-byte with the verified distribution folder. Its executable also passes a direct, unmodified title-startup probe. The previous user export is checked against its original SHA-256 manifest and remains unchanged.

## Artifacts and reproduction

- Distribution: `.runtime/releases/windows-beta-net11/`.
- Archive: `.runtime/releases/MaltonReborn-0.1.0-windows-x64-net11.zip`.
- Evidence: `.runtime/release-verification/`, including original/final PCK audits, planner logs, publish logs, host trace, rendered dashboard, and `final-package.json` with the final ZIP SHA-256.
- Audit: `python tools/verify_export.py .runtime/releases/windows-beta-net11` from `godot/`.
- Diagnostic copy: add `--instrument .runtime/release-verification/new-diagnostic-folder` to that command, then run the copied EXE with isolated APPDATA. Add `--headless` for a non-rendered run. The harness and tooling remain excluded from release exports.

The desktop app's direct window-capture approval timed out. Rendered verification instead used the release engine's own viewport capture and automated UI callbacks, as described above. No clean-machine certification, minimum-hardware validation, new multi-day balance soak, or new 32× throughput benchmark is implied by this release check.
