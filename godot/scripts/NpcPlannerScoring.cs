using System;
using System.Collections.Generic;
using System.Threading.Tasks;

// Pure planner work: typed snapshots in, ordered candidates out. No Godot calls.
internal sealed class NpcPlannerScoring
{
    // Actor rows: id, site, flags, hp, maxHp, ap, tagged threat, tag expiry,
    // doubled base hit chance, damage, weapon flags, skill bits, kind, grasp.
    private const int ActorStride = 14;
    private const int Human = 1, Inside = 2, Down = 4, WantsRevive = 8, Construction = 16;
    private const int ScentBlood = 32, Infected = 64, PrefersUndead = 128, Diagnosis = 256;
    private const int LabExperience = 512, FirstAid = 1024, Syringe = 2048, Extractor = 4096;
    private const int Doctor = 8192, Protected = 16384, FuelSoaked = 32768, Clinician = 65536;

    private struct Actor
    {
        public int Id, Site, Flags, Hp, MaxHp, Ap, Tagged, TaggedUntil;
        public double Hit;
        public int Damage, WeaponFlags, Skills, WeaponKind, GraspedBy;
        public bool Has(int flag) => (Flags & flag) != 0;
    }

    private readonly record struct Candidate(int Command, int Target, double Score);

    private sealed class Plan
    {
        public readonly List<Candidate> Candidates = new(8);
        public int Id, Opponent, Enemies, Allies, Builders, Outside, Wall;
        public double Breach, Danger, Flee, Efficiency;
        public bool Emergency;
    }

    private readonly NpcQueryKernel _world;
    private readonly int _width, _height;
    private readonly Actor[] _actors;
    private readonly List<int>[] _occupants;
    private readonly int[] _walls;
    private readonly Plan[] _plans;

    public NpcPlannerScoring(NpcQueryKernel world, int width, int height, int actorCount)
    {
        _world = world;
        _width = width;
        _height = height;
        _actors = new Actor[actorCount];
        _plans = new Plan[actorCount];
        _occupants = new List<int>[width * height];
        _walls = new int[width * height];
    }

    public void Update(int[] rows)
    {
        for (int offset = 0; offset < rows.Length; offset += ActorStride)
        {
            int id = rows[offset];
            _actors[id] = new Actor
            {
                Id = id, Site = rows[offset + 1], Flags = rows[offset + 2], Hp = rows[offset + 3],
                MaxHp = rows[offset + 4], Ap = rows[offset + 5], Tagged = rows[offset + 6],
                TaggedUntil = rows[offset + 7], Hit = rows[offset + 8] / 2.0,
                Damage = rows[offset + 9], WeaponFlags = rows[offset + 10], Skills = rows[offset + 11],
                WeaponKind = rows[offset + 12], GraspedBy = rows[offset + 13]
            };
        }
    }

    public void UpdateSites(int[] rows)
    {
        for (int offset = 0; offset < rows.Length;)
        {
            int site = rows[offset++];
            _walls[site] = rows[offset++];
            int count = rows[offset++];
            var occupants = _occupants[site] ??= new List<int>(count);
            occupants.Clear();
            for (int index = 0; index < count; index++) occupants.Add(rows[offset++]);
        }
    }

    public double[] Batch(int[] ids, int minute, int requestedWorkers)
    {
        int capacity = Math.Max(1, Environment.ProcessorCount - 2);
        int workers = ids.Length < 128 ? 1 : Math.Min(capacity, Math.Max(1, ids.Length / 32));
        if (requestedWorkers >= 0) workers = Math.Min(workers, Math.Max(1, requestedWorkers));
        if (workers > 1)
            Parallel.For(0, ids.Length, new ParallelOptions { MaxDegreeOfParallelism = workers }, index => Prepare(ids[index], minute));
        else
            foreach (int id in ids) Prepare(id, minute);
        int length = 1;
        foreach (int id in ids) length += 16 + 3 * _plans[id].Candidates.Count;
        var output = new double[length];
        output[0] = workers;
        int offset = 1;
        foreach (int id in ids)
        {
            Plan plan = _plans[id];
            output[offset++] = 16 + 3 * plan.Candidates.Count;
            output[offset++] = id;
            output[offset++] = plan.Opponent;
            output[offset++] = plan.Enemies;
            output[offset++] = plan.Allies;
            output[offset++] = plan.Outside;
            output[offset++] = plan.Wall;
            output[offset++] = plan.Breach;
            output[offset++] = plan.Danger;
            output[offset++] = plan.Flee;
            output[offset++] = plan.Efficiency;
            output[offset++] = plan.Emergency ? 1 : 0;
            output[offset++] = plan.Builders;
            output[offset++] = 0;
            output[offset++] = 0;
            output[offset++] = plan.Candidates.Count;
            foreach (Candidate candidate in plan.Candidates)
            {
                output[offset++] = candidate.Command;
                output[offset++] = candidate.Target;
                output[offset++] = candidate.Score;
            }
        }
        return output;
    }

    private static double Unit(double value) => Math.Clamp(value, 0, 1);
    private static double Smooth(double value) { double x = Unit(value); return x * x * (3 - 2 * x); }
    private static double Danger(double distance, int enemies, int allies, double breach) =>
        Math.Max(Unit(breach), 1.0 / (1.0 + 0.65 * distance * distance) * Unit((enemies / Math.Max(0.65, allies) - 0.5) / 2));
    private static int Threat(Actor actor, int minute) => actor.TaggedUntil <= minute ? -1 : actor.Tagged;

    private double Efficiency(Actor actor, Actor opponent, int minute)
    {
        if ((actor.WeaponFlags & 8) != 0) return 0; // Empty firearm.
        double hit = actor.Hit;
        bool ranged = (actor.WeaponFlags & 1) != 0;
        bool newspaper = actor.WeaponKind == 6;
        if (ranged)
        {
            if ((actor.Skills & 1) != 0) hit += actor.WeaponKind == 5 ? 12.5 : 15;
            if (actor.WeaponKind == 1) hit += ((actor.Skills & 2) != 0 ? 25 : 0) + ((actor.Skills & 4) != 0 ? 10 : 0);
            if (actor.WeaponKind == 2) hit += ((actor.Skills & 8) != 0 ? 25 : 0) + ((actor.Skills & 16) != 0 ? 10 : 0);
        }
        else
        {
            if ((actor.Skills & 32) != 0 && !newspaper) hit += 15;
            if (actor.WeaponKind == 3 && (actor.Skills & 64) != 0) hit += 25;
            if (actor.WeaponKind == 4 && (actor.Skills & 128) != 0) hit = Math.Min(40, hit + 30);
        }
        if (actor.GraspedBy >= 0) hit -= 10;
        // Light expires in simulation time without changing weapon metadata.
        ref readonly var cell = ref _world.PlannerCell(actor.Site);
        if (actor.Has(Inside) && (cell.Flags & 32) != 0 && ((cell.Flags & 4) == 0 || cell.FuelUntil <= minute))
            hit = actor.WeaponKind == 5 ? hit * 0.5 : Math.Floor(hit * 0.5);
        hit = Math.Clamp(hit, 0, newspaper ? 100 : 95);
        int damage = actor.Damage * (actor.WeaponKind == 5 && opponent.Has(FuelSoaked) ? 2 : 1);
        if (ranged && opponent.Has(Protected)) damage = (int)Math.Floor(damage * 0.8);
        return hit / 100.0 * Math.Min(opponent.Hp, damage);
    }

    private void Prepare(int id, int minute)
    {
        Actor actor = _actors[id];
        Plan plan = _plans[id] ??= new Plan();
        plan.Candidates.Clear();
        plan.Id = id;
        plan.Opponent = -1;
        plan.Enemies = plan.Allies = plan.Builders = 0;
        List<int> present = _occupants[actor.Site];
        foreach (int otherId in present)
        {
            Actor other = _actors[otherId];
            if (other.Has(Down) || other.Has(Inside) != actor.Has(Inside)) continue;
            if (other.Has(Human))
            {
                plan.Allies++;
                if (other.Ap > 0 && other.Has(Construction)) plan.Builders++;
            }
            else if (!other.Has(WantsRevive))
            {
                plan.Enemies++;
                if (plan.Opponent < 0 || Threat(other, minute) > Threat(_actors[plan.Opponent], minute)
                    || (actor.Has(ScentBlood) && other.Hp < _actors[plan.Opponent].Hp)) plan.Opponent = otherId;
            }
        }
        plan.Outside = actor.Has(Inside) ? _world.PlannerCell(actor.Site).HostilesOutside : plan.Enemies;
        plan.Wall = _walls[actor.Site];
        plan.Breach = actor.Has(Inside) && plan.Outside > 0 ? Unit((plan.Outside * 1.8 - plan.Wall * 0.75 - 1.5 * plan.Builders) / 8) : 0;
        plan.Danger = Danger(0, plan.Enemies, plan.Allies, plan.Breach);
        if (!actor.Has(Inside) && plan.Enemies == 0)
        {
            int ox = actor.Site % _width, oy = actor.Site / _width;
            for (int y = Math.Max(0, oy - 1); y < Math.Min(_height, oy + 2); y++)
                for (int x = Math.Max(0, ox - 1); x < Math.Min(_width, ox + 2); x++)
                    plan.Danger = Math.Max(plan.Danger, Danger(1, _world.PlannerCell(y * _width + x).HostilesOutside, plan.Allies, 0));
        }
        plan.Flee = Unit(plan.Danger) * (0.72 + 0.18 * (1 - Unit((double)actor.Hp / actor.MaxHp)) + 0.10 * (1 - Smooth(actor.Ap / 16.0)));
        plan.Efficiency = plan.Opponent < 0 ? 0 : Efficiency(actor, _actors[plan.Opponent], minute);
        bool exposed = !actor.Has(Inside) && plan.Enemies > 0 && plan.Enemies >= plan.Allies && plan.Efficiency < 1;
        bool shortOnAp = actor.Ap <= 7 && (!actor.Has(Inside) || plan.Enemies >= plan.Allies || plan.Wall < 3);
        plan.Emergency = exposed || plan.Enemies >= 2.5 * plan.Allies || plan.Breach >= 0.85 || (plan.Enemies > 0 && (actor.Hp <= 22 || shortOnAp));
        if (plan.Opponent >= 0)
        {
            double defense = 0.49 + 0.5 * (plan.Efficiency / (plan.Efficiency + 2) * (1 - 0.65 * Unit(plan.Danger)));
            plan.Candidates.Add(new(1, plan.Opponent, defense));
            plan.Candidates.Add(new(2, -1, defense - 0.03));
            if (actor.Ap >= 15 && actor.Hp > 30 && _actors[plan.Opponent].TaggedUntil <= minute)
                plan.Candidates.Add(new(3, plan.Opponent, actor.Has(Clinician) ? 0.54 : 0.43));
        }
        if (actor.Has(FirstAid))
            foreach (int otherId in present)
            {
                Actor other = _actors[otherId];
                if (!other.Has(Human) || other.Has(Down) || other.Has(Inside) != actor.Has(Inside) || (other.Hp > other.MaxHp - 8 && !other.Has(Infected))) continue;
                if (otherId != id && !actor.Has(Diagnosis) && other.Hp > 40 && !other.Has(Infected)) continue;
                double heal = Math.Max(Smooth((1 - Unit((double)other.Hp / other.MaxHp)) / 0.70), other.Has(Infected) ? 0.95 : 0);
                plan.Candidates.Add(new(4, otherId, 0.20 + 0.57 * heal + (actor.Has(Doctor) && otherId != id ? 0.25 : 0)));
            }
        if (actor.Has(LabExperience) && actor.Has(Syringe))
            foreach (int otherId in present)
            {
                Actor other = _actors[otherId];
                if (other.Has(Inside) != actor.Has(Inside)) continue;
                bool triage = (_world.PlannerCell(actor.Site).Flags & 16) != 0 || ((_world.PlannerCell(actor.Site).Flags & 2) != 0 && actor.Has(Inside));
                int profile = Threat(other, minute);
                bool lowRisk = !other.Has(PrefersUndead) && plan.Enemies <= 1 && (other.Has(Down) || (triage && (profile == 0 || (profile < 0 && actor.Has(Extractor)))));
                if (!other.Has(Human) && (other.Has(WantsRevive) || otherId == 0 || lowRisk)) plan.Candidates.Add(new(5, otherId, 0.92));
            }
    }
}
