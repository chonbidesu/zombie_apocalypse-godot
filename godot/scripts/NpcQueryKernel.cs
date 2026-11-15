using System;
using System.Collections.Generic;
using Godot;

/// <summary>Read-only spatial queries over a compact mirror of the simulation.</summary>
[GlobalClass]
public partial class NpcQueryKernel : RefCounted
{
    private const int Stride = 13;
    private const int Building = 1;
    private const int Lab = 2;
    private const int Generator = 4;
    private const int ClosedDoors = 8;
    private const int RevivePoint = 16;

    internal struct Cell
    {
        public int Flags;
        public int Barricade;
        public int Ruin;
        public int Fort;
        public int FuelUntil;
        public int HumansInside;
        public int ZombiesInside;
        public int HostilesOutside;
        public int FirstHuman;
        public int FirstHumanInside;
        public int FirstHumanOutside;
        public bool Staffed;
    }

    private int _width;
    private int _height;
    private Cell[] _cells = Array.Empty<Cell>();
    private readonly SortedSet<int> _labs = new();
    private readonly SortedSet<int> _revivePoints = new();
    private NpcPlannerScoring _planner;

    internal ref readonly Cell PlannerCell(int id) => ref _cells[id];

    public void InitializePlanner(int actorCount) => _planner = new NpcPlannerScoring(this, _width, _height, actorCount);
    public void UpdatePlannerActors(int[] rows) => _planner.Update(rows);
    public void UpdatePlannerSites(int[] rows) => _planner.UpdateSites(rows);
    public double[] PlanHumans(int[] ids, int minute, int workers) => _planner.Batch(ids, minute, workers);
    public double[] PlanHuman(int id, int minute) => _planner.Batch(new[] { id }, minute, 1);

    public void Initialize(int width, int height, int[] rows)
    {
        if (width <= 0 || height <= 0 || rows.Length != checked(width * height * Stride))
            throw new ArgumentException("Expected one complete record per map cell.");

        _width = width;
        _height = height;
        if (_cells.Length != width * height)
            _cells = new Cell[width * height];
        else
            Array.Clear(_cells);

        _labs.Clear();
        _revivePoints.Clear();
        UpdateCells(rows);
    }

    public void UpdateCells(int[] rows)
    {
        if (rows.Length % Stride != 0)
            throw new ArgumentException("Incomplete spatial record.");

        for (int offset = 0; offset < rows.Length; offset += Stride)
        {
            int id = rows[offset];
            if ((uint)id >= (uint)_cells.Length)
                throw new ArgumentOutOfRangeException(nameof(rows));

            ref Cell cell = ref _cells[id];
            int flags = rows[offset + 1];
            UpdateLandmark(_labs, id, cell.Flags, flags, Lab);
            UpdateLandmark(_revivePoints, id, cell.Flags, flags, RevivePoint);
            cell.Flags = flags;
            cell.Barricade = rows[offset + 2];
            cell.Ruin = rows[offset + 3];
            cell.Fort = rows[offset + 4];
            cell.FuelUntil = rows[offset + 5];
            cell.HumansInside = rows[offset + 6];
            cell.ZombiesInside = rows[offset + 7];
            cell.HostilesOutside = rows[offset + 8];
            cell.FirstHuman = rows[offset + 9];
            cell.FirstHumanInside = rows[offset + 10];
            cell.FirstHumanOutside = rows[offset + 11];
            cell.Staffed = rows[offset + 12] != 0;
        }
    }

    private static void UpdateLandmark(SortedSet<int> sites, int id, int oldFlags, int flags, int mask)
    {
        if (((oldFlags ^ flags) & mask) == 0)
            return;
        if ((flags & mask) != 0)
            sites.Add(id);
        else
            sites.Remove(id);
    }

    private int Distance(int origin, int target)
    {
        return Math.Max(Math.Abs(origin % _width - target % _width), Math.Abs(origin / _width - target / _width));
    }

    public int VisibleHuman(int origin, bool inside)
    {
        int ox = origin % _width;
        int oy = origin / _width;
        for (int y = Math.Max(0, oy - 1); y < Math.Min(_height, oy + 2); y++)
        {
            for (int x = Math.Max(0, ox - 1); x < Math.Min(_width, ox + 2); x++)
            {
                int id = y * _width + x;
                ref readonly Cell cell = ref _cells[id];
                int human;
                if (id == origin)
                {
                    bool open = cell.Barricade == 0 && (cell.Flags & ClosedDoors) == 0;
                    human = open ? cell.FirstHuman : inside ? cell.FirstHumanInside : cell.FirstHumanOutside;
                }
                else
                {
                    human = inside ? -1 : cell.FirstHumanOutside;
                }
                if (human >= 0)
                    return human;
            }
        }
        return -1;
    }

    public int NearbyLight(int origin, int minute)
    {
        int ox = origin % _width;
        int oy = origin / _width;
        int best = -1;
        int nearest = 4;
        for (int y = Math.Max(0, oy - 3); y < Math.Min(_height, oy + 4); y++)
        {
            for (int x = Math.Max(0, ox - 3); x < Math.Min(_width, ox + 4); x++)
            {
                int id = y * _width + x;
                ref readonly Cell cell = ref _cells[id];
                int distance = Math.Max(Math.Abs(x - ox), Math.Abs(y - oy));
                if (distance < nearest && (cell.Flags & Generator) != 0 && cell.FuelUntil > minute)
                {
                    nearest = distance;
                    best = id;
                }
            }
        }
        return best;
    }

    public int GroupTarget(int origin)
    {
        int ox = origin % _width;
        int oy = origin / _width;
        int best = -1;
        int bestDistance = 8;
        int fort = _cells[origin].Fort;
        for (int y = Math.Max(0, oy - 5); y < Math.Min(_height, oy + 6); y++)
        {
            for (int x = Math.Max(0, ox - 5); x < Math.Min(_width, ox + 6); x++)
            {
                int id = y * _width + x;
                ref readonly Cell cell = ref _cells[id];
                int distance = Math.Max(Math.Abs(x - ox), Math.Abs(y - oy));
                if (id == origin || cell.Fort != fort || cell.Ruin > 0 || cell.Barricade < 2 || cell.Barricade > 4 || distance >= bestDistance)
                    continue;
                if (cell.HostilesOutside > 0 || cell.ZombiesInside > 0 || cell.HumansInside < 2 || cell.HumansInside > 5)
                    continue;
                best = id;
                bestDistance = distance;
            }
        }
        return best;
    }

    public int RetreatTarget(int origin, int ap, int home, int[] rememberedSites, double[] rememberedShelter)
    {
        int ox = origin % _width;
        int oy = origin / _width;
        int fort = _cells[origin].Fort;
        int radius = Math.Min(8, Math.Max(1, ap - 1));
        int best = -1;
        double bestScore = double.PositiveInfinity;
        for (int y = Math.Max(0, oy - radius); y < Math.Min(_height, oy + radius + 1); y++)
        {
            for (int x = Math.Max(0, ox - radius); x < Math.Min(_width, ox + radius + 1); x++)
            {
                int id = y * _width + x;
                ref readonly Cell cell = ref _cells[id];
                if (id == origin || (cell.Flags & Building) == 0 || cell.Ruin > 0 || cell.Barricade > 4 || cell.Fort != fort || cell.ZombiesInside > 0 || cell.HostilesOutside > 0)
                    continue;
                double score = Math.Max(Math.Abs(x - ox), Math.Abs(y - oy)) + (cell.HumansInside == 0 ? 4 : 0) + (cell.Barricade < 2 ? 4 : 0);
                if (id == home)
                    score -= 2;
                for (int index = 0; index < rememberedSites.Length; index++)
                {
                    if (rememberedSites[index] != id)
                        continue;
                    score -= 2.0 * rememberedShelter[index];
                    break;
                }
                if (score < bestScore)
                {
                    bestScore = score;
                    best = id;
                }
            }
        }
        return best;
    }

    public bool IsStaffed(int site) => _cells[site].Staffed;

    public int RevivalTarget(int origin, bool rot, int avoid, int minute)
    {
        int best = -1;
        int distance = 9999;
        foreach (int id in _labs)
        {
            ref readonly Cell cell = ref _cells[id];
            if (id == avoid || (rot && ((cell.Flags & Generator) == 0 || cell.FuelUntil <= minute)))
                continue;
            int d = Distance(origin, id);
            if (d >= distance)
                continue;
            int cost = d + (cell.Staffed ? 0 : 22);
            if (cost < distance)
            {
                distance = cost;
                best = id;
            }
        }
        if (rot)
            return best;

        int ox = origin % _width;
        int oy = origin / _width;
        for (int y = Math.Max(0, oy - 8); y < Math.Min(_height, oy + 9); y++)
        {
            for (int x = Math.Max(0, ox - 8); x < Math.Min(_width, ox + 9); x++)
            {
                int id = y * _width + x;
                ref readonly Cell cell = ref _cells[id];
                int d = Math.Max(Math.Abs(x - ox), Math.Abs(y - oy)) + 2;
                if (d >= distance || id == avoid || cell.Barricade > 4 || !cell.Staffed)
                    continue;
                best = id;
                distance = d;
            }
        }
        foreach (int id in _revivePoints)
        {
            int d = Distance(origin, id);
            if (id == avoid || d >= distance)
                continue;
            best = id;
            distance = d;
        }
        return best;
    }
    public int LocalNearbyLight(int origin, int minute)
    {
        int ox = origin % _width;
        int oy = origin / _width;
        int best = -1;
        int nearest = 2;
        for (int y = Math.Max(0, oy - 1); y < Math.Min(_height, oy + 2); y++)
        {
            for (int x = Math.Max(0, ox - 1); x < Math.Min(_width, ox + 2); x++)
            {
                int id = y * _width + x;
                ref readonly Cell cell = ref _cells[id];
                int distance = Math.Max(Math.Abs(x - ox), Math.Abs(y - oy));
                if (distance < nearest && (cell.Flags & Generator) != 0 && cell.FuelUntil > minute)
                {
                    nearest = distance;
                    best = id;
                }
            }
        }
        return best;
    }

    public int LocalRetreatTarget(int origin, int ap, int home, int[] rememberedSites, double[] rememberedShelter)
    {
        int ox = origin % _width;
        int oy = origin / _width;
        int fort = _cells[origin].Fort;
        int radius = Math.Min(1, Math.Max(1, ap - 1));
        int best = -1;
        double bestScore = double.PositiveInfinity;
        for (int y = Math.Max(0, oy - radius); y < Math.Min(_height, oy + radius + 1); y++)
        {
            for (int x = Math.Max(0, ox - radius); x < Math.Min(_width, ox + radius + 1); x++)
            {
                int id = y * _width + x;
                ref readonly Cell cell = ref _cells[id];
                if (id == origin || (cell.Flags & Building) == 0 || cell.Ruin > 0 || cell.Barricade > 4 || cell.Fort != fort || cell.HostilesOutside > 0)
                    continue;
                double score = Math.Max(Math.Abs(x - ox), Math.Abs(y - oy)) + 4 + (cell.Barricade < 2 ? 4 : 0);
                if (id == home)
                    score -= 2;
                for (int index = 0; index < rememberedSites.Length; index++)
                {
                    if (rememberedSites[index] != id)
                        continue;
                    score -= 2.0 * rememberedShelter[index];
                    break;
                }
                if (score < bestScore)
                {
                    bestScore = score;
                    best = id;
                }
            }
        }
        return best;
    }

}
