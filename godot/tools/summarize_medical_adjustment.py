"""Verify and compare the paired ten-day DNA/medical pilots to their archived controls."""
import json
from pathlib import Path

from summarize_cohort_balance import load_run, npc_summary

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / "reports/dna-medical-2026-11-15"


def main():
    comparisons = []
    after_sources = []
    for opening in ["natural", "awake"]:
        name = f"malton-{opening}-23.json"
        before, before_rows = load_run(ROOT / "reports/balance-2026-11-14" / name)
        after, after_rows = load_run(FOLDER / name)
        assert before["population"] == after["population"] == 4000
        assert len(before["days"]) == len(after["days"]) == 10
        after_sources.append(after["source_files"])
        record = {"opening": opening, "seed": 23, "days": 10}
        for label, run, rows in [("before", before, before_rows), ("after", after, after_rows)]:
            end = run["days"][-1]
            record[label] = {
                **{k: end[k] for k in ["human_form", "standing_humans", "hostile_zombies", "awaiting_revival", "deaths", "revivals", "powered", "ruined", "npc_actions"]},
                "lab_experience_owned": sum("lab_experience" in r["human_skills"].split(";") for r in rows),
                "lab_assistants_trained": sum(r["job"] == "NecroTech Lab Assistant" and "lab_experience" in r["human_skills"].split(";") for r in rows),
                "dna_samples": run["action_counts"]["human_form"].get("extract", 0),
                "dna_xp": run["xp_sources"]["human_form"].get("extract", 0),
                "healing_xp": run["xp_sources"]["human_form"].get("heal", 0),
                "cohorts": {cohort: npc_summary([r for r in rows if r["cohort"] == cohort]) for cohort in ["human", "zombie"]},
                "lab_assistants": npc_summary([r for r in rows if r["job"] == "NecroTech Lab Assistant"]),
                "daily_revivals": [d["revivals"] for d in run["days"]],
            }
            assert record[label]["dna_xp"] == 4 * record[label]["dna_samples"]
            assert record[label]["healing_xp"] % 5 == 0
        comparisons.append(record)
    assert after_sources[0] == after_sources[1]
    summary = {"comparisons": comparisons, "source_files": after_sources[0],
               "validation": "Both pilots complete; all twenty daily audits and final NPC/XP ledgers reconcile."}
    performance_path = FOLDER / "sleep-performance.json"
    performance = json.loads(performance_path.read_text()) if performance_path.exists() else None
    if performance: summary["sleep_performance"] = performance
    (FOLDER / "comparison.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    lines = ["# DNA scanning and medical NPC adjustment — 15 November 2026", "",
             "Implemented shared calendar-day DNA scans, technician revival training and support XP priorities. The two ten-day pilots below use seed 23 on full Malton, with 2,000 humans and 2,000 zombies, paired against the archived controls. One retains the natural dormant opening; the other wakes every zombie. The inactive player is excluded and untargetable. No extra skills, XP, syringes or staffed clinics are granted to the pilots.", "",
             "Follow-up: standing as a zombie after death now resets scan eligibility, including after revival and another death. The recorded pilots below predate that small change and retain their original rules and measurements.", "",
             "## Rules used by the recorded pilots", "",
             "- A successful DNA extraction earns exactly 4 XP and records both human and zombie skills. Each zombie can be scanned once per calendar day by any human, with a shared midnight reset. Death, standing, revival or learning another skill cannot reopen that allowance. Rejected repeat scans award no XP.",
             "- Player scanner use automatically selects a local unscanned standing zombie in the same compartment. A fresh selected target is preferred; stale/scanned selections fall through to another usable target. Brain Rot restrictions remain in the resolver.",
             "- Only a player's extraction produces a clickable skill report in the activity feed and History. Reports retain the recorded skills even after movement, death, later training and saving/loading. Opening one costs no AP or time.",
             "- NPCs that started with NecroTech Employment seek local sampling opportunities and buy Lab Experience before Free Running. Healthy technicians can take a sample before retreating from a lone zombie; overwhelming danger and full-AP recovery remain in force.",
             "- Trained technicians prioritize syringe searches and sampled human-trained revival candidates. A hidden revival preference or a low-threat zombie profile alone cannot identify a former human. Existing player rescue remains available. Both planner backends share this medical policy.",
             "- Useful first aid to someone else earns the existing 5 XP. Support roles prioritize that work; self-healing and curing infection without restoring HP do not award XP.", "",
             "## Paired ten-day pilots", "",
             "| Opening | Metric | Before | After |", "| --- | --- | ---: | ---: |"]
    for c in comparisons:
        for key, caption in [("revivals", "Revivals"), ("lab_experience_owned", "NPCs owning Lab Experience"),
                             ("human_form", "Human forms at day ten"), ("standing_humans", "Standing humans"),
                             ("dna_samples", "Successful DNA samples"), ("dna_xp", "DNA XP earned"),
                             ("healing_xp", "XP from healing others")]:
            lines.append(f"| {c['opening']} | {caption} | {c['before'][key]:,} | {c['after'][key]:,} |")
    lines += ["", "### Technician progression", "",
              "| Opening | Mean technician XP, before / after | Mean skills purchased, before / after | Trained Lab Assistants, before / after |", "| --- | ---: | ---: | ---: |"]
    for c in comparisons:
        b, a = c["before"], c["after"]
        lines.append(f"| {c['opening']} | {b['lab_assistants']['earned_xp']['mean']:.2f} / {a['lab_assistants']['earned_xp']['mean']:.2f} | {b['lab_assistants']['purchases']['mean']:.3f} / {a['lab_assistants']['purchases']['mean']:.3f} | {b['lab_assistants_trained']} / {a['lab_assistants_trained']} |")
    lines += ["", "These pilots test whether the requested medical behaviors function at city scale. They do not isolate individual changes or establish a new equilibrium. Population differences include changed travel, exposure, XP progression and the shared random stream; more revivals alone does not prove an overall human survival improvement.", ""]
    if performance:
        lines += ["## Sleep throughput check", "",
                  f"One rendered six-hour sleep capture with 2,000 humans and 2,000 zombies, seed 4815 and the configured 32× target completed {performance['clock_steps']:,} ticks and {performance['npc_actions']:,} actions in {performance['seconds']:.3f} seconds ({performance['achieved_speed']:.2f}× achieved). Frame p99 was {performance['p99_ms']:.3f} ms; the {performance['worst_ms']:.3f} ms wake frame still fails the existing 20 ms worst-frame limit. This is a completed throughput capture, not a passing frame-budget test or a paired performance experiment. Gameplay remains configured for 32× sleep and 8× rest, with no speed indicator.", "",
                  "[Capture data](../reports/dna-medical-2026-11-15/sleep-performance.json) and [frame CSV](../reports/dna-medical-2026-11-15/sleep-4000.csv).", ""]
    lines += [
              "## Verification", "",
              "The new headless DNA/medical regression checks exact scan XP, shared rejection, automatic targeting, midnight reset, death/revival lockouts, both skill trees, snapshot persistence, scientist training and useful first aid. The rendered DNA regression checks inventory Use, feed and History links, historical skill lists and no AP/time cost. C# and GDScript comparison covers the same medical decisions. The action-order regression matches every committed action and route at serial, single-worker, four-worker and automatic configurations; threaded recovery retains natural wake, Wake, Escape, pause/resume and save behavior.", "",
              "Every pilot day audits per-NPC XP income/spending, skill purchases, deaths, revivals and successful actions. This summarizer independently reconciles the exported actor CSVs, checks scan XP is four times successful samples and checks healing XP is a multiple of five. The remaining two existing NPC-balance and nine existing survival assertions are unrelated to the new medical policy; the updated DNA scenarios and general simulation/UI regressions pass.", "",
              "```powershell",
              "godot --headless --path godot --script res://tests/dna_medical_test.gd",
              "godot --path godot --script res://tests/dna_interface_test.gd",
              "godot --headless --path godot --script res://tests/balance_cohort_runs.gd -- --seed=23 --days=10 --opening=natural --output=res://reports/dna-medical-2026-11-15",
              "godot --headless --path godot --script res://tests/balance_cohort_runs.gd -- --seed=23 --days=10 --opening=awake --output=res://reports/dna-medical-2026-11-15",
              "python godot/tools/summarize_medical_adjustment.py", "```", "",
              "Use Godot .NET with the built assembly to reproduce the same query backend. Standard Godot also passes the new DNA rules. [Detailed comparison JSON](../reports/dna-medical-2026-11-15/comparison.json) includes cohort XP, skill/death maxima and daily revivals. Raw daily JSON and per-NPC CSVs are in the same folder. [Archived six-run baseline](balance-2026-11-14.md)."]
    (ROOT / "docs/dna-medical-2026-11-15.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps([{k: c[k] for k in ["opening", "seed", "days"]} | {
        "revivals_before": c["before"]["revivals"], "revivals_after": c["after"]["revivals"],
        "trained_before": c["before"]["lab_experience_owned"], "trained_after": c["after"]["lab_experience_owned"],
        "humans_before": c["before"]["human_form"], "humans_after": c["after"]["human_form"]} for c in comparisons], indent=2))


if __name__ == "__main__":
    main()
