"""Summarize full-city cohort trials without changing the historical balance reports."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import statistics
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEXT_COLUMNS = {"name", "job", "cohort", "current_form", "human_skills", "zombie_skills"}


def distribution(values: list[int]) -> dict:
    ordered = sorted(values)
    return {
        "total": sum(values), "mean": statistics.mean(values),
        "median": statistics.median(values),
        "p95": ordered[max(0, math.ceil(len(values) * .95) - 1)],
        "max": max(values), "zero_count": values.count(0),
    }


def npc_summary(rows: list[dict]) -> dict:
    result = {"count": len(rows), "ever_active": sum(not r["dormant"] for r in rows)}
    for field in ["earned_xp", "unspent_xp", "peak_unspent_xp", "spent_xp", "purchases", "owned_skills",
                  "initial_skills", "human_skill_purchases", "zombie_skill_purchases", "deaths",
                  "combat_deaths", "suicides", "infection_deaths", "revives_received", "revives_performed", "kills", "actions"]:
        result[field] = distribution([r[field] for r in rows])
    result["never_died"] = sum(r["deaths"] == 0 for r in rows)
    result["ever_revived"] = sum(r["revives_received"] > 0 for r in rows)
    result["purchasers"] = sum(r["purchases"] > 0 for r in rows)
    result["ending_human_form"] = sum(r["current_form"] == "human" for r in rows)
    result["maxima"] = {}
    for field in ["earned_xp", "peak_unspent_xp", "owned_skills", "purchases", "deaths", "combat_deaths", "revives_received", "revives_performed"]:
        maximum = result[field]["max"]
        result["maxima"][field] = [
            {key: r[key] for key in ["seed", "opening", "id", "name", "job", "cohort", "current_form", field]}
            for r in rows if r[field] == maximum
        ][:10]
    return result


def load_run(path: Path) -> tuple[dict, list[dict]]:
    run = json.loads(path.read_text(encoding="utf-8-sig"))
    if not run["complete"] or len(run["days"]) != run["requested_days"] or run["audit_errors"]:
        raise ValueError(f"Incomplete or failed trial: {path.name}")
    csv_path = path.with_name(path.stem + "-npcs.csv")
    with csv_path.open(encoding="utf-8-sig", newline="") as handle:
        rows = [{k: v if k in TEXT_COLUMNS else int(v) for k, v in r.items()} for r in csv.DictReader(handle)]
    assert len(rows) == run["population"]
    assert len({r["id"] for r in rows}) == len(rows)
    for r in rows:
        assert r["initial_xp"] + r["earned_xp"] - r["spent_xp"] == r["unspent_xp"]
        assert r["initial_skills"] + r["purchases"] == r["owned_skills"]
        assert r["human_skill_purchases"] + r["zombie_skill_purchases"] == r["purchases"]
        assert r["combat_deaths"] + r["suicides"] + r["infection_deaths"] <= r["deaths"]
        r.update(seed=run["seed"], opening=run["opening"])
    end = run["days"][-1]
    assert sum(r["deaths"] for r in rows) == end["deaths"]
    assert sum(r["revives_performed"] for r in rows) == end["revivals"]
    assert sum(r["revives_received"] for r in rows) == end["revivals"]
    assert sum(r["actions"] + r["purchases"] for r in rows) == end["npc_actions"]
    assert sum(sum(side.values()) for side in run["xp_sources"].values()) == sum(r["earned_xp"] for r in rows)
    assert sum(run["learned_skills"].values()) == sum(r["purchases"] for r in rows)
    assert end["human_form"] + end["zombie_form"] == len(rows)
    for cohort, group in end["cohorts"].items():
        cohort_rows = [r for r in rows if r["cohort"] == cohort]
        for key in ["earned_xp", "spent_xp", "purchases", "deaths", "combat_deaths", "suicides", "infection_deaths", "revives_performed", "revives_received", "kills"]:
            assert sum(r[key] for r in cohort_rows) == group[key], (path.name, cohort, key)
    run["report_name"] = path.name
    return run, rows


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reports", type=Path, default=ROOT / "reports/balance-2026-11-14")
    parser.add_argument("--output", type=Path, default=ROOT / "docs/balance-2026-11-14.md")
    parser.add_argument("--expected-runs", type=int, default=6)
    args = parser.parse_args()
    loaded = [load_run(p) for p in sorted(args.reports.glob("malton-*.json"))]
    if len(loaded) != args.expected_runs:
        raise ValueError(f"Expected {args.expected_runs} completed trials, found {len(loaded)}")
    runs = [run for run, _ in loaded]
    all_rows = [row for _, rows in loaded for row in rows]
    assert len({json.dumps(r["source_files"], sort_keys=True) for r in runs}) == 1, "Mixed simulation sources"
    assert len({r["requested_days"] for r in runs}) == 1, "Mixed trial durations"
    groups: dict = {}
    for opening in ["natural", "awake"]:
        subset = [r for r in runs if r["opening"] == opening]
        ends = [r["days"][-1] for r in subset]
        group = {"runs": len(subset), "seeds": [r["seed"] for r in subset], "cohorts": {}}
        for key in ["human_form", "standing_humans", "standing_zombies", "hostile_zombies", "awaiting_revival", "dormant", "down", "recovering", "deaths", "revivals", "powered", "ruined", "npc_actions"]:
            group[key] = {"mean": statistics.mean(e[key] for e in ends), "min": min(e[key] for e in ends), "max": max(e[key] for e in ends)}
        group["initial_human_mean"] = statistics.mean(r["initial"]["human_form"] for r in subset)
        group["human_net_change_pct"] = 100 * (group["human_form"]["mean"] / group["initial_human_mean"] - 1)
        for cohort in ["human", "zombie"]:
            group["cohorts"][cohort] = npc_summary([r for r in all_rows if r["opening"] == opening and r["cohort"] == cohort])
        groups[opening] = group
    summary = {"complete_runs": len(runs), "city_days": sum(len(r["days"]) for r in runs),
               "npc_observations": len(all_rows), "by_opening": groups,
               "source_files": runs[0]["source_files"], "validation": "All daily and final ledgers reconcile."}
    (args.reports / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    with (args.reports / "summary.csv").open("w", newline="", encoding="utf-8") as handle:
        columns = ["opening", "seed", "days", "human_form", "standing_humans", "standing_zombies", "hostile_zombies", "awaiting_revival", "dormant", "deaths", "revivals", "powered", "ruined", "human_mean_purchases", "zombie_mean_purchases", "human_mean_earned_xp", "zombie_mean_earned_xp", "max_owned_skills", "max_earned_xp", "max_peak_unspent_xp", "max_deaths"]
        writer = csv.DictWriter(handle, fieldnames=columns)
        writer.writeheader()
        for run, rows in loaded:
            end = run["days"][-1]
            row = {k: end[k] for k in columns if k in end}
            row.update(opening=run["opening"], seed=run["seed"], days=len(run["days"]))
            for cohort in ["human", "zombie"]:
                selected = [r for r in rows if r["cohort"] == cohort]
                for key in ["purchases", "earned_xp"]: row[f"{cohort}_mean_{key}"] = statistics.mean(r[key] for r in selected)
            for key in ["owned_skills", "earned_xp", "peak_unspent_xp", "deaths"]: row["max_" + key] = max(r[key] for r in rows)
            writer.writerow(row)
    days = runs[0]["requested_days"]
    lines = ["# Full-city NPC balance — 14 November 2026", "",
             f"{len(runs)} trials × {days} days = {summary['city_days']} simulated city-days. Each trial uses the original 100×100 Malton map with 2,000 humans and 2,000 zombies. Seeds 23, 307 and 997 are paired between natural and all-awake openings. The player is inactive, untargetable and excluded. No player help, prebuilt shelter, extra light, equipment or clinic staff is added.", "",
             "The live fixed-step scheduler runs every tick with full 50 AP recovery, local awareness and turn-time decisions. The recovery spatial query kernel is available; rendering and wall-time speed limits are absent. These are balance measurements, not rendered throughput benchmarks. Daily samples occur every 24 simulated hours after the initial 08:00.", "",
             "## Faction outcomes", "", "Human counts include revived original zombies. Standing zombies include former humans seeking revival; hostile zombies excludes that queue. Undead combat deaths are reversible, so kill totals alone cannot establish the stronger side.", "",
             "| Opening | Seed | Humans, day 10 | Standing zombies | Hostile zombies | Awaiting revival | Dormant | Deaths | Revivals | Powered / ruined |",
             "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"]
    for run in runs:
        e = run["days"][-1]
        lines.append(f"| {run['opening']} | {run['seed']} | {e['human_form']:,} | {e['standing_zombies']:,} | {e['hostile_zombies']:,} | {e['awaiting_revival']:,} | {e['dormant']:,} | {e['deaths']:,} | {e['revivals']:,} | {e['powered']} / {e['ruined']} |")
    lines += ["", "### Population trend (mean across three seeds)", "", "| Opening | Day | Human forms | Hostile zombies | Awaiting revival | Dormant zombies | Cumulative revivals |", "| --- | ---: | ---: | ---: | ---: | ---: | ---: |"]
    for opening in groups:
        selected = [r for r in runs if r["opening"] == opening]
        for day in [0, 1, 3, 5, 7, days]:
            samples = [r["initial"] if day == 0 else r["days"][day - 1] for r in selected]
            means = [statistics.mean(s[k] for s in samples) for k in ["human_form", "hostile_zombies", "awaiting_revival", "dormant", "revivals"]]
            lines.append(f"| {opening} | {day} | " + " | ".join(f"{v:,.1f}" for v in means) + " |")
    lines += ["", "## Progression by starting cohort", "", "Averages include every NPC in the starting cohort, including dormant and zero-XP NPCs. Each opening/cohort group contains 6,000 NPC observations (2,000 × three seeds). XP earned is cumulative income before purchases, unspent XP is the ending balance, and peak XP is the highest unspent balance seen after any action. Owned skills includes starting skills in both trees; purchases counts only new skills bought during the trial.", "",
              "| Opening | Started as | Mean skills bought | Purchasers | Mean XP earned | Median / p95 XP earned | Max XP earned | Mean unspent XP | Max peak XP | Max skills owned / bought |",
              "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"]
    for opening, group in groups.items():
        for cohort, c in group["cohorts"].items():
            lines.append(f"| {opening} | {cohort} | {c['purchases']['mean']:.3f} | {100*c['purchasers']/c['count']:.1f}% | {c['earned_xp']['mean']:.2f} | {c['earned_xp']['median']:g} / {c['earned_xp']['p95']} | {c['earned_xp']['max']:,} | {c['unspent_xp']['mean']:.2f} | {c['peak_unspent_xp']['max']:,} | {c['owned_skills']['max']} / {c['purchases']['max']} |")
    lines += ["", "## Deaths and revival by starting cohort", "", "Death averages include repeats. Combat deaths, infection deaths and voluntary window jumps are separate. Maximum deaths counts all causes. A revive recipient can appear more than once in event totals.", "",
              "| Opening | Started as | Mean deaths | Max deaths / combat deaths | Never died | Combat deaths | Infection deaths | Voluntary jumps | Revives received | Max received / performed |",
              "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"]
    for opening, group in groups.items():
        for cohort, c in group["cohorts"].items():
            lines.append(f"| {opening} | {cohort} | {c['deaths']['mean']:.3f} | {c['deaths']['max']} / {c['combat_deaths']['max']} | {100*c['never_died']/c['count']:.1f}% | {c['combat_deaths']['total']:,} | {c['infection_deaths']['total']:,} | {c['suicides']['total']:,} | {c['revives_received']['total']:,} | {c['revives_received']['max']} / {c['revives_performed']['max']} |")
    lines += ["", "## Individual maxima", "", "The examples below identify one NPC at each maximum; ties and up to ten examples are retained in `summary.json`.", "",
              "| Opening | Metric | Maximum | Seed / NPC ID | Ending name | Starting role |", "| --- | --- | ---: | --- | --- | --- |"]
    for opening in groups:
        rows = [r for r in all_rows if r["opening"] == opening]
        for key in ["earned_xp", "peak_unspent_xp", "owned_skills", "purchases", "deaths", "revives_performed"]:
            r = max(rows, key=lambda a: a[key])
            lines.append(f"| {opening} | {key} | {r[key]:,} | {r['seed']} / {r['id']} | {r['name']} | {r['job']} |")
    lines += ["", "## Skills and XP sources", "", "| Opening | Most-purchased skills (total over three runs) | Human-form XP sources | Zombie-form XP sources |", "| --- | --- | --- | --- |"]
    for opening in groups:
        skills, human_xp, zombie_xp = Counter(), Counter(), Counter()
        for r in runs:
            if r["opening"] != opening: continue
            skills.update(r["learned_skills"])
            human_xp.update(r["xp_sources"]["human_form"])
            zombie_xp.update(r["xp_sources"]["zombie_form"])
        render = lambda c: ", ".join(f"{k}: {v:,}" for k, v in c.most_common(8)) or "none"
        lines.append(f"| {opening} | {render(skills)} | {render(human_xp)} | {render(zombie_xp)} |")
    lines += ["", "## Verification, limits and reproduction", "",
              "The focused metric regression verifies XP income/spending/peak balances, purchases, kill/death attribution, cohort persistence after revival, and voluntary deaths. Each simulated day audits every NPC: starting XP + earned − spent equals remaining XP, starting skills + purchases equals owned skills, and per-NPC totals match simulation actions, deaths and revivals. The summarizer independently rechecks those ledgers against the exported actor CSVs and requires identical source hashes across runs. Gameplay code was not tuned during these trials.", "",
              "Three paired seeds and ten days can establish the direction of attrition in these fixtures, not long-term equilibrium or a universal win probability. Natural openings contain initially dormant zombies; all-awake openings isolate that initial activity advantage. The cohorts follow starting faction even after conversion. No active player intervention is represented.", "", "```powershell",
              "godot --headless --path godot --script res://tests/balance_cohort_runs.gd -- --seed=23 --days=10 --opening=natural",
              "godot --headless --path godot --script res://tests/balance_cohort_runs.gd -- --seed=23 --days=10 --opening=awake",
              "godot --headless --path godot --script res://tests/balance_cohort_metrics_test.gd",
              "python godot/tools/summarize_cohort_balance.py", "```", "",
              "Raw daily JSON and individual NPC CSVs: [report folder](../reports/balance-2026-11-14/). [Compact per-run CSV](../reports/balance-2026-11-14/summary.csv), [cohort aggregates and tied maxima](../reports/balance-2026-11-14/summary.json). Run the .NET build to use the same query backend. Repeat seeds 307 and 997 for the remaining paired trials."]
    args.output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    manifest = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(args.reports.iterdir()) if p.suffix in {".json", ".csv"} and p.name != "manifest.json"}
    (args.reports / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Verified {len(runs)} trials, {summary['city_days']} city-days, {len(all_rows):,} NPC observations. Wrote {args.output}")
    for opening, group in groups.items():
        print(opening, json.dumps({key: group[key] for key in ["human_form", "human_net_change_pct", "revivals", "deaths"]}))


if __name__ == "__main__":
    main()
