"""Summarize completed Godot balance trials; uses only the Python standard library."""
import csv
import json
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "reports"


def read(label):
    return json.loads((REPORTS / f"balance-{label}.json").read_text(encoding="utf-8"))


def last(run):
    return run["days"][-1]


def mean(runs, field):
    return statistics.mean(last(run)[field] for run in runs)


def main():
    baseline, selected, holdout = (read(label) for label in ("baseline", "shelter", "holdout"))
    rows = []
    for report in (baseline, selected, holdout):
        for run in report["runs"]:
            end = last(run)
            rows.append({
                "version": report["label"], "mode": run["mode"], "seed": run["seed"],
                "days": len(run["days"]), "starting_humans": run["initial"]["human_form"],
                "ending_humans": end["human_form"], "standing_humans": end["survivors"],
                "standing_zombies": end["active_zombies"], "revivals": end["revivals"],
                "powered": end["powered"], "ruined": end["ruined"],
                "failed_moves": end["blocked_moves"],
            })
    with (REPORTS / "balance-summary.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    all_reports = [json.loads(path.read_text(encoding="utf-8")) for path in REPORTS.glob("balance-*.json") if "diagnostic" not in path.name]
    completed = sum(len(report["runs"]) for report in all_reports)
    game_days = sum(len(run["days"]) for report in all_reports for run in report["runs"])
    lines = [
        "# AI balance results — 4 November 2026", "",
        f"{completed} completed scenario/seed trials across iterative versions, totaling {game_days} simulated game days. Intermediate reports are retained, including completed scenarios from interrupted tuning suites. The diagnostic trace is excluded. The selected `shelter` version has {len(selected['runs'])} completed scenarios; `holdout` has {len(holdout['runs'])}.", "",
        "## Method", "",
        "The headless harness advances the actual simulation, not a simplified combat model. The player is down and inactive at (0,0), contributes no actions, and is excluded from NPC population totals. Day zero is 08:00; daily samples are 24-hour intervals. NPCs obey the same AP, item, skill, search, movement and combat validation as the player.", "",
        "The baseline captures the pre-change behavior. The selected version combines navigation/retreat fixes, supply AP reserves, shared-home constructors, lab staffing, revival-seeking former humans, combat choices, groan policies and the rule corrections listed in the audit. These are combined-system comparisons, not an isolated experiment on one AI parameter. Same map seeds and population sizes are used; deliberate specialist/home initialization changes can change starting positions and random sequences.", "",
        "### Paired scenario means", "",
        "Humans means standing human-form NPCs at the final sample. It is not original-cohort survival: reviving an original zombie can increase the count beyond the starting human population. Revivals are cumulative events and may include the same person more than once.", "",
        "| Scenario | Days | Seeds | Starting humans / zombies | Baseline humans | Selected humans | Baseline / selected revivals | Failed move reduction |",
        "|---|---:|---|---|---:|---:|---:|---:|",
    ]
    for mode, days, population in (("sandbox",7,"14 / 18"),("random",7,"45 / 90"),("siege",5,"14 / 18"),("malton",7,"300 / 600")):
        new = [run for run in selected["runs"] if run["mode"] == mode]
        seeds = [run["seed"] for run in new]
        old = [run for run in baseline["runs"] if run["mode"] == mode and run["seed"] in seeds]
        if not new:
            continue
        reduction = 100*(1-mean(new,"blocked_moves")/max(1,mean(old,"blocked_moves")))
        lines.append(f"| {mode} | {days} | {', '.join(map(str,seeds))} | {population} | {mean(old,'survivors'):.1f} | {mean(new,'survivors'):.1f} | {mean(old,'revivals'):.1f} / {mean(new,'revivals'):.1f} | {reduction:.1f}% |")
    lines += ["", "The random city is 30×30. Malton is the original 100×100 map. The siege deliberately puts all fourteen survivors inside one hospital and eighteen awake zombies immediately outside; most zombies start dormant in the other scenarios. This is a horde stress case, not a normal opening.", "", "### Selected results by seed", "", "| Scenario | Seed | Days | Human forms | Standing humans | Standing zombies | Revivals | Powered buildings | Failed moves |", "|---|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for report in (selected, holdout):
        for run in report["runs"]:
            end = last(run)
            name = run['mode'] + (' (holdout)' if report['label'] == 'holdout' else '')
            lines.append(f"| {name} | {run['seed']} | {len(run['days'])} | {end['human_form']} | {end['survivors']} | {end['active_zombies']} | {end['revivals']} | {end['powered']} | {end['blocked_moves']} |")
    lines += [
        "", "## What changed and why", "",
        "The largest actionable bug was exhausted humans repeatedly walking away from a safe, enterable local building to find another refuge. They spent each regenerated AP outside until killed. Local entry now takes priority. Resource trips also end before return AP is exhausted. Temporary route failures have cooldowns instead of repeated illegal movement attempts, and fort routes use the gatehouse.", "",
        "Shared homes retain a constructor while other members fetch resources. Heavy barricading takes companions outside into account. Working laboratories provide a revival service; some former survivor NPCs queue outside for treatment instead of becoming permanent hunters. Human recovery now competes with zombie growth without free healing, automatic revivals, item grants during play or faction-specific AP discounts.", "",
        "Zombies retain pressure through valid pursuit, light attraction, target selection, grasp/bite choices, feeding, occasional reinforcement calls, generator destruction and subsequent ruin. An experimental opening in which every sixth zombie already knew Feeding Groan produced early collapses; it was rejected. Zombies can still learn that skill normally.", "",
        "## Limits and interpretation", "",
        "These runs support a much more functional offline ecology, not a guarantee of perpetual equilibrium. There are few seeds, the player provides no help, and no original server-wide population targets are claimed. Ending human counts include newly revived original zombies; death/revival remains reversible. End-of-day powered counts miss generators that ran and were destroyed between samples; action histories retain installation/fueling/destruction counts.", "",
        "The fourteen-day seeds were not used for tuning. They test whether the improvement extends beyond the three development seeds. Horde stress runs should still cause losses and relocation. Longer campaigns, unusual building-count parameters, all-zombie starts and active player interventions remain useful playtest cases.", "",
        "Reproduce the selected tests with `./launch.ps1 -Balance shelter` and `./launch.ps1 -Balance holdout`. Raw JSON contains every daily sample and cumulative action count. `reports/balance-summary.csv` is a compact export. The baseline is an archived measurement of the earlier implementation, not a mode that restores old code. Reports record the simulation source SHA; the holdout report additionally records all four gameplay source hashes. `tools/summarize_balance.py` rebuilds this report from completed records.", "",
        "## Verification and artwork", "",
        "652 checks passed across simulation, survival, NPC/rule regressions, loot/trust, content, encumbrance, world and rendered UI suites. The new NPC suite specifically checks local safe entry, AP reserves, fuel conservation, legal fort paths, revival health, pipe barricades and XP accounting. Art checks verify all 24 zombie frames, rendered crowd/corpse placement and the exact original street tile. See the [rules audit](urban-dead-rules-audit.md) and `tests/zombie-animation-preview.png`.",
    ]
    (ROOT / "docs/ai-balance-results.md").write_text("\n".join(lines)+"\n", encoding="utf-8")
    print(f"Wrote report: {completed} trials / {game_days} game days; selected {len(selected['runs'])}, holdout {len(holdout['runs'])}")


if __name__ == "__main__":
    main()
