"""Deterministic Pillow assembly of selection art and authored replacement frames.

Run from any directory: python godot/tools/repair_selection_atlases.py
Original PNGs are never overwritten. Each is copied to corrected/ before editing.
All edits operate on RGBA pixels in a 362 x 362 cell at build time.
The renderer only displays the resulting twelve complete drawings.
"""
from pathlib import Path
import hashlib
import json
import math
import shutil
import time
from functools import lru_cache
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/character_creation'
OUT = ART / 'corrected'
REVIEW = ROOT / 'tools/atlas_review'
CELL = 362
PAIRS = [
    ('private', 'private_female'), ('medic-refined', 'medic_male'),
    ('scout', 'scout_male'), ('doctor-refined', 'doctor_male'),
    ('lab-face-refined', 'necro_female'),
    ('consumer-full-redraw', 'consumer_male'),
    ('police-full-redraw', 'police_female'),
    ('firefighter-size-matched', 'firefighter_male'), ('corpse-refined',),
]


def rectangle(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def spans(outline):
    """Pixel-centre scan conversion; produces integer edit spans, not a bitmap."""
    for y in range(max(0, min(p[1] for p in outline)), min(CELL, max(p[1] for p in outline))):
        intersections = []
        for a, b in zip(outline, outline[1:] + outline[:1]):
            if min(a[1], b[1]) <= y + .5 < max(a[1], b[1]):
                intersections.append(a[0] + (y + .5 - a[1]) * (b[0] - a[0]) / (b[1] - a[1]))
        intersections.sort()
        for left, right in zip(intersections[::2], intersections[1::2]):
            yield y, max(0, math.ceil(left - .5)), min(CELL, math.ceil(right - .5))


def replace_pixels(dest, source, outline):
    for y, left, right in spans(outline):
        dest.paste(source.crop((left, y, right, y + 1)), (left, y))


def erase_pixels(dest, outline):
    for y, left, right in spans(outline):
        dest.paste((0, 0, 0, 0), (left, y, right, y + 1))


@lru_cache(maxsize=None)
def frames(name):
    with Image.open(ART / (name + '.png')) as im:
        assert im.size == (1448, 1086), name
        im = im.convert('RGBA')
        return [im.crop((i % 4 * CELL, i // 4 * CELL,
                         (i % 4 + 1) * CELL, (i // 4 + 1) * CELL)) for i in range(12)]


# Anatomical boundaries end in fabric folds or behind foreground furniture.
# Idle changes are confined to existing facial expressions, not whole-body sway.
HEADS = [
    [(148,0),(230,0),(230,62),(216,85),(194,92),(168,71),(148,66)],
    [(89,0),(181,0),(181,95),(159,116),(137,113),(112,94),(89,85)],
    [(124,0),(258,0),(258,93),(225,107),(194,117),(163,100),(124,83)],
    [(120,0),(205,0),(205,50),(185,62),(178,82),(159,76),(145,62),(120,72)],
    [(143,0),(229,0),(229,73),(207,102),(182,103),(163,83),(143,78)],
    [(117,23),(192,23),(214,88),(211,120),(183,136),(139,129),(121,98)],
    [(129,0),(210,0),(210,81),(193,101),(159,95),(133,80)],
    [(140,0),(219,0),(219,57),(212,81),(185,100),(161,85),(140,67)],
]
MOTION = [
    [(0,0),(265,0),(265,155),(239,169),(171,166),(102,154),(0,154)],
    [(32,0),(228,0),(228,161),(216,181),(163,195),(153,207),(78,207),(74,155),(68,125),(66,115),(32,115)],
    [(88,0),(258,0),(258,95),(267,144),(254,189),(190,195),(130,185),(88,175)],
    [(87,58),(147,58),(179,80),(193,87),(193,132),(195,154),(192,183),(189,209),(202,242),(150,252),(96,240),(87,145)],
    [(97,0),(278,0),(281,169),(254,174),(217,174),(212,191),(156,188),(153,163),(97,163)],
    [(65,0),(239,0),(239,132),(211,142),(192,161),(169,166),(145,151),(130,136),(65,132)],
    [(85,0),(283,0),(283,123),(273,183),(229,190),(201,209),(122,209),(89,186),(85,133)],
    rectangle(98,0,302,200),
    [(9,0),(350,0),(350,130),(330,142),(271,157),(190,176),(105,196),(39,210),(20,181)],
]

def fix_doctor_legs(base):
    # Follow the surviving diagonal trouser to its own cuff. The shader-era
    # two-leg drawing is the silhouette reference; the portrait's coat and
    # boot sit slightly lower, so keep their actual hem and heel pixels.
    outside = [(112,243),(122,246),(130,248.3),(137,250.4),(145,252.3),
               (149.4,253.6),(151.2,254.2),(153.4,253.2),(155.1,251.6),
               (154.6,256),(153.0,260.7),(151.9,265.5),(150.1,271.0),
               (149.4,275.7),(147.8,280.7),(146.3,283.3),(144.7,286.1),
               (142.9,289.2),(141.2,293.6),(140.0,297.1),(139.1,300.7),
               (139.5,303.2),(138.4,305.7),(136.4,309.3),(136.1,312.3),
               (135.4,315.1),(119,316),(110,310)]
    base.putalpha(ImageChops.subtract(base.getchannel('A'), smooth_polygon(outside)))


def light_jukebox(frame):
    """Relight the complete arched glass in-place, retaining ribs and alpha."""
    px = frame.load()
    for y in range(104, 142):
        for x in range(202, 269):
            # The opening is an arch, not a rectangle truncated at a shader seam.
            if ((x-235)/33)**2 + ((y-136)/32)**2 > 1 and y < 136:
                continue
            r,g,b,a = px[x,y]
            weight = max(0, 1-(((x-235)/40)**2+((y-130)/43)**2))
            # Dark leaded divisions keep their detail; glass becomes warm amber.
            gain = .8 * weight
            px[x,y] = (min(255, round(r*(1+gain)+22*weight)),
                       min(255, round(g*(1+.65*gain)+12*weight)),
                       min(255, round(b*(1+.12*gain)+2*weight)), a)


def blend_pixels(dest, source, outline, overlap=4):
    """Copy the core verbatim, feathering only the surrounding overlap."""
    mask = Image.new('L', dest.size)
    draw = ImageDraw.Draw(mask)
    draw.polygon(outline, fill=255)
    if overlap:
        # The source must stay opaque over the whole foreground, including
        # antialiased edges. Put the transition on the surrounding material.
        fringe = mask.copy()
        draw = ImageDraw.Draw(fringe)
        draw.line(outline + [outline[0]], fill=255, width=overlap, joint='curve')
        fringe = fringe.filter(ImageFilter.GaussianBlur(overlap / 2))
        mask = ImageChops.lighter(mask, fringe)
    mask = mask.point(lambda a: 0 if a < 4 else 255 if a > 251 else a)
    box = mask.getbbox()
    if not box:
        return
    donor, anchor, weights = source.crop(box), dest.crop(box), mask.crop(box)
    mixed = Image.composite(donor, anchor, weights)
    # RGB from transparent export pixels can leave a bright silhouette fringe.
    # Use premultiplied alpha only there, keeping full-weight RGBA copies exact.
    alpha_change = ImageChops.difference(donor.getchannel('A'), anchor.getchannel('A'))
    silhouette = ImageChops.multiply(alpha_change.point(lambda a: 255 if a > 8 else 0),
                                     weights.point(lambda a: 255 if 0 < a < 255 else 0))
    if silhouette.getbbox():
        edge = Image.composite(donor.convert('RGBa'), anchor.convert('RGBa'), weights)
        mixed.paste(edge.convert('RGBA'), (0,0), silhouette)
    dest.paste(mixed, box)


# Core regions include the old and new silhouettes, so uncovered chair or
# uniform pixels also come from the original drawing. Their outer transitions
# sit in upholstery, felt or trouser fabric beyond the moving details.
PRIVATE_SEATED = [(192,60),(279,60),(281,101),(276,150),(262,183),
                  (239,207),(209,215),(190,232),(169,232),(169,211),
                  (186,192),(202,177),(204,151),(197,136)]
MEDIC_BODY = [(32,0),(219,0),(219,148),(213,178),(177,190),(157,202),
              (85,201),(68,188),(51,173),(47,153),(43,134),(39,119),(32,112)]
# Follow the edge of the card table on the right. The lower join runs through
# the thighs, clear of the fly, waistband and the upper edge of the cargo pocket.
MEDIC_SEATED_THIGHS = [(73,175),(149,175),(154,181),(154,192),(157,202),
             (164,209),(174,215),(190,220),(199,222),(197,239),
             (183,245),(166,247),(146,244),(122,241),(95,237),
             (84,231),(79,219),(77,206),(72,196)]
MEDIC_WAIST = [(72,175),(150,175),(154,181),(154,192),(157,202),
               (164,209),(174,215),(188,221),(183,227),(168,224),
               (154,222),(141,219),(124,215),(112,214),(97,210),
               (83,215),(78,210),(73,201)]


def medic_trousers(pose):
    """Use the male uniform's cloth grain to shape the seated front rise."""
    result = pose.copy()
    # The fold below the fly runs obliquely into the far thigh. Spread the
    # native cloth down and outward along it, with a soft shadow at the tuck.
    pixels = result.load()
    for y in range(194, 221):
        for x in range(119, 158):
            across = (x - 138 - .42*(y-205)) / 10
            along = (y-205) / 7
            fullness = math.exp(-.5*(across*across + along*along))
            # Fade completely before the pocket, belt and edge of the table.
            fade = min(1., (x-119)/4, (157-x)/4, (y-194)/3, (220-y)/4)
            weight = fullness * fade
            sx, sy = x-1.5*weight, y-3.8*weight
            left, top = math.floor(sx), math.floor(sy)
            fx, fy = sx-left, sy-top
            samples = [pose.getpixel((left+dx,top+dy)) for dy in (0,1) for dx in (0,1)]
            light = math.exp(-((across+.48)/.78)**2)
            tuck = math.exp(-((across-1.05)/.49)**2)
            gain = 1 + weight*(.19*light-.33*tuck)
            rgb = []
            for c in range(3):
                upper = samples[0][c]*(1-fx) + samples[1][c]*fx
                lower = samples[2][c]*(1-fx) + samples[3][c]*fx
                rgb.append(min(255, round((upper*(1-fy)+lower*fy)*gain)))
            pixels[x,y] = (*rgb, pose.getpixel((x,y))[3])
    return result


MEDIC_CARDS = [(155,160),(186,140),(201,136),(212,148),(219,159),
               (224,167),(233,171),(239,175),(246,181),(257,187),
               (261,197),(238,202),(214,206),(194,204),(169,200),(154,191)]
SCOUT_LEAN = [(84,0),(266,0),(267,91),(265,117),(263,156),(272,189),
              (272,201),(261,216),(243,216),(221,209),(204,205),
              (177,201),(143,199),(114,200),(86,190)]
DOCTOR_BODY = [(78,0),(242,0),(241,69),(233,86),(217,96),(216,111),
               (207,119),(199,119),(196,124),(195,175),(197,214),
               (200,241),(151,249),(96,240),(83,197)]
DOCTOR_REACH = {
    5: [(131,122),(176,119),(187,124),(187,143),(170,151),(135,146)],
    6: [(150,122),(184,124),(203,123),(226,125),(233,132),(231,143),
        (221,148),(208,147),(177,149),(150,144)],
    7: [(153,126),(185,129),(200,141),(210,144),(228,141),(239,145),
        (247,148),(247,152),(239,158),(234,165),(224,165),(205,158),
        (180,153),(153,147)],
    10: [(116,120),(150,124),(178,129),(192,136),(189,150),(155,152),(115,144)]
}
DOCTOR_REACH[8] = DOCTOR_REACH[7]
DOCTOR_REACH[9] = DOCTOR_REACH[7]

POLICE_COLLAR = [(119,0),(221,0),(219,80),(232,105),(219,121),
                (188,126),(167,124),(143,117),(120,106)]
POLICE_SEATED = [(76,0),(279,0),(279,157),(278,176),(266,186),
                 (241,194),(232,218),(219,224),(204,217),(190,208),
                 (154,207),(124,207),(117,197),(103,194),(91,188),
                 (82,181),(79,166),(78,143)]
POLICE_LAP = [(239,183),(266,178),(289,175),(312,184),(320,205),
              (320,237),(305,244),(297,236),(280,215),(255,210),(237,203)]
# Include both the old elbow footprint and the full drape, including the
# transparent pixels past its hem. Join to the fixed legs below the knee.
POLICE_CONFIRM_SEATED = [(78,0),(323,0),(325,169),(327,245),(312,249),
                         (299,251),(278,250),(245,245),(220,232),
                         (190,228),(157,225),(126,228),(107,218),
                         (92,202),(78,197),(75,177)]
# The sharp upper edge of the cloth is on the armrest. The shirt and arms
# move above it, and the lowered elbow can cover the chair beside the belt.
POLICE_CONFIRM_BODY = [(78,0),(291,0),(290,142),(278,161),(273,177),
                       (267,182),(254,187),(241,191),(229,197),
                       (213,209),(186,216),(152,215),(122,208),
                       (104,199),(88,196),(77,189),(75,176)]
POLICE_REACH = [(219,109),(259,119),(280,143),(305,155),(312,180),
                (304,190),(283,190),(260,180),(225,153)]
# The upholstered front and its row of studs are visible behind her whole
# right trouser leg. Carry the same stationary drawing down through her boot.
POLICE_ARMREST = [(243,167),(329,168),(330,351),(209,351),(199,327),
                  (199,273),(193,250),(192,222),(213,208),(233,201)]
DOCTOR_IDLE = [(107,0),(238,0),(238,72),(213,91),(194,101),(189,123),
               (169,126),(139,119),(113,112),(104,94)]


def firefighter_pose(source):
    # The axe and hem end above row 232 in both sets. Through the short band
    # below them, register the trouser outlines before blending into the fixed
    # legs. A straight crossfade would leave two translucent trouser edges.
    legs = frames(PAIRS[7][0])[5]
    result = legs.copy()
    result.paste(source.crop((0, 0, CELL, 232)), (0, 0))
    for y in range(232, 254):
        weight = (y - 231) / 23
        rows = [im.crop((0, y, CELL, y + 1)) for im in (source, legs)]
        spans = [row.getchannel('A').point(lambda a: 255 if a > 32 else 0).getbbox()
                 for row in rows]
        left, right = [round((1-weight)*spans[0][k] + weight*spans[1][k])
                       for k in (0, 2)]
        strips = [row.crop((span[0]-2, 0, span[2]+2, 1)).resize(
                  (right-left+4, 1), Image.Resampling.NEAREST).convert('RGBa')
                  for row, span in zip(rows, spans)]
        result.paste((0,0,0,0), (0,y,CELL,y+1))
        result.paste(Image.blend(*strips, weight).convert('RGBA'), (left-2,y))
    return result

# The four cushion noses bound the actual felt. The cut passes under the
# shadows of the balls at the foot cushion and through the cue at the rear.
FELT = [(39,146),(278,146),(284,150),(335,205),(334,210),
        (303,211),(238,214),(169,215),(91,216),(84,211)]
CUE_AND_HAND = [(116,119),(186,119),(204,139),(199,165),
                (187,180),(170,180),(151,164),(133,145)]


def smooth_polygon(points):
    scale = 4
    mask = Image.new('L', (CELL*scale, CELL*scale))
    ImageDraw.Draw(mask).polygon([(round(x*scale),round(y*scale)) for x,y in points], fill=255)
    return mask.resize((CELL,CELL), Image.Resampling.BOX)


@lru_cache(maxsize=1)
def scout_chair():
    # The leaned pose exposes the full lengths of the turned wooden spindles.
    # Keep the outer post and seat registered to the planted chair. Clear the
    # translucent, shirt-coloured matte between the spindles all the way to
    # the underside of the curved top rail.
    chair = frames('scout')[0].copy()
    exposed = frames('scout_male')[7]
    blend_pixels(chair, exposed, [(248,108),(265,116),(285,124),(288,136),
                 (277,193),(269,187),(250,177),(247,145)], 2)
    openings = [
        [(253,113),(258,115),(257,133),(252,174),(248,175),(249,145)],
        [(263.2,116.6),(267.1,118.3),(265.6,137),(262.2,177.4),
         (258,184),(259.1,161),(261.5,137)],
        [(272.1,120.2),(276.1,121.8),(274.6,139.5),(268.0,187.8),
         (264.7,184.9),(270.1,141)],
        [(282.2,125.2),(285.2,127.2),(283.1,144),(274.1,196.4),
         (270.8,189.5),(279.7,143.2)],
    ]
    for opening in openings:
        chair.putalpha(ImageChops.subtract(chair.getchannel('A'), smooth_polygon(opening)))
    return chair


def scout_seat(frame, pose, index):
    # Recover the complete hip, including its contact with the seat. The old
    # motion region stopped inside this fold and left two different poses.
    blend_pixels(frame, pose, [(215,99),(269,99),(279,127),(282,195),
                 (279,221),(261,230),(232,235),(209,235),(204,225),
                 (218,209),(221,185)], 3)
    # Trace the occluding shirt from shoulder to waistband. The chair underneath
    # is identical across poses; the narrower back exposes more of each gap.
    if index <= 4:
        back = [(257,101),(258.5,110),(261,116),(264,124),(265.5,137),
                (268,147),(269,156),(268.6,162),(266.3,169),(266,174)]
    elif index == 5:
        back = [(257,101),(258,111),(258.3,123),(257.2,140),
                (256.6,156),(256,165),(257.3,172),(262,179)]
    else:
        back = [(254,100),(255.5,109),(255.3,122),(253.6,138),
                (252.6,155),(252.8,166),(254.4,172),(260.5,179)]
    hip = [(266.8,183),(270.0,189),(272.2,195),(274,202),
           (273.3,209),(271.4,215),(268.7,219),(263.5,222.5),
           (255,225.3),(245,228),(235,231)]
    boundary = back + hip + [(234,241),(303,241),(305,96),(272,96)]
    frame.paste(scout_chair(), (0,0), smooth_polygon(boundary))


def build_base(job, source, shared=None):
    base = source[0].copy() if shared is None else shared.copy()
    if shared is not None:
        replace_pixels(base, source[0], MOTION[job])
        if job == 0:
            blend_pixels(base, source[0], PRIVATE_SEATED, 6)
        elif job == 1:
            blend_pixels(base, source[0], MEDIC_BODY)
            blend_pixels(base, medic_trousers(source[0]), MEDIC_SEATED_THIGHS, 4)
        elif job == 3:
            blend_pixels(base, source[0], DOCTOR_BODY)
        elif job == 6:
            # Keep her complete cloth, belt, arms and the newly exposed chair.
            blend_pixels(base, source[0], POLICE_ARMREST, 6)
            blend_pixels(base, source[0], POLICE_SEATED, 8)
    if job == 7:
        base = firefighter_pose(source[0])

    seated_officer = None
    if job == 6 and shared is None:
        seated_officer = base.copy()
        blend_pixels(seated_officer, source[11], POLICE_CONFIRM_SEATED, 4)

    reference = frames('doctor-portrait' if job == 3 else PAIRS[job][0])[0]
    result = []
    for i in range(12):
        frame = base.copy()
        if job < 8:
            replace_pixels(frame, source[i], HEADS[job])
        if i >= 4 or job == 8:
            replace_pixels(frame, source[i], MOTION[job])
        if job == 0 and shared is not None and i >= 4:
            # The lower arm rests on the knee. Only update the turning shoulder.
            blend_pixels(frame, source[i], [(202,61),(280,61),(281,116),
                         (270,154),(258,171),(222,168),(204,140)], 5)
        if job == 1 and i >= 4:
            blend_pixels(frame, source[i], MEDIC_BODY)
        if job == 1 and (i >= 8 or (shared is not None and i >= 4)):
            # The source waist follows the torso while the pockets and knees
            # stay planted. The join sits below the diagonal compression fold.
            lap = medic_trousers(source[i]) if shared is not None else source[i]
            blend_pixels(frame, lap, MEDIC_WAIST, 4)
        if job == 2:
            if i >= 5:
                blend_pixels(frame, source[i], SCOUT_LEAN, 5)
            scout_seat(frame, source[0 if i <= 4 else i], i)
        if job == 3:
            blend_pixels(frame, source[i], DOCTOR_IDLE if i < 4 else DOCTOR_BODY)
            lamp = (202,104,269,142)
            frame.paste(reference.crop(lamp), lamp)
            frame.paste(reference.crop((0,253,CELL,CELL)), (0,253))
            if i >= 9:
                light_jukebox(frame)
            if i in DOCTOR_REACH:
                blend_pixels(frame, source[i], DOCTOR_REACH[i], 2)
        if job == 4 and i < 4:
            # The glove rises with the vial, alongside the moving lapels.
            replace_pixels(frame, source[i], MOTION[job])
        if job == 5:
            if i >= 4:
                blend_pixels(frame, source[i], CUE_AND_HAND, 2)
            blend_pixels(frame, source[i], FELT, 1)
        if job == 6 and i < 4:
            blend_pixels(frame, source[i], POLICE_COLLAR)
        if job == 6 and shared is not None and i >= 4:
            # Frame 7 has the cloth resting on the knee and a clear armrest.
            blend_pixels(frame, source[7], POLICE_LAP, 4)
            blend_pixels(frame, source[i], POLICE_SEATED, 7)
            if i == 4:
                blend_pixels(frame, source[i], POLICE_REACH, 3)
        if seated_officer is not None and i >= 4:
            if i == 4:
                # The fingers still touch the fabric in the placement pose.
                frame = base.copy()
                blend_pixels(frame, source[i], POLICE_CONFIRM_SEATED, 4)
            else:
                frame = seated_officer.copy()
                blend_pixels(frame, source[i], POLICE_CONFIRM_BODY, 2)
        if job == 7 and i >= 4:
            frame = firefighter_pose(source[i])
        # Resolve foreground/furniture boundaries in the actual stored pixels.
        # These small rigid objects must never inherit a nearby arm's drift.
        if job == 1:
            replace_pixels(frame, reference, rectangle(222,145,252,183))
            if i >= 5:
                replace_pixels(frame, source[i], [(166,185),(205,182),(234,188),
                               (238,201),(191,204),(164,197)])
            if i in (5, 6):
                # Restore the fingers in front of the registered mug.
                blend_pixels(frame, source[i], MEDIC_CARDS, 2)
        if job == 3:
            if i not in (7, 8, 9):
                replace_pixels(frame, reference, rectangle(240,143,362,253))
            replace_pixels(frame, reference, rectangle(205,165,240,253))
        if job == 4:
            replace_pixels(frame, reference, rectangle(78,163,155,213))
            replace_pixels(frame, reference, rectangle(216,178,282,213))
        if job == 5:
            replace_pixels(frame, reference, [(65,132),(129,132),(133,138),(65,143)])
        if job == 3:
            fix_doctor_legs(frame)
        # Transparent RGB is normalized too, so equality means all four channels.
        pixels = frame.load()
        for y in range(CELL):
            for x in range(CELL):
                # Original exports contain alpha 1-3 speckles on cell edges.
                # Remove that invisible export noise rather than retaining it.
                if pixels[x,y][3] <= 3:
                    pixels[x,y] = (0,0,0,0)
                elif y < 4:
                    # Fade existing export-edge hair wisps and the syringe mist
                    # to transparency inside the cell, without moving the actor.
                    r,g,b,a = pixels[x,y]
                    a = round(a*y/4)
                    pixels[x,y] = (r,g,b,a) if a else (0,0,0,0)
                elif x in (0,CELL-1) or y == CELL-1:
                    # Only isolated near-transparent export noise reaches these
                    # borders; all solid silhouettes have been inspected inside.
                    assert pixels[x,y][3] < 10
                    pixels[x,y] = (0,0,0,0)
        result.append(frame)
    return result


def save(name, cells):
    target = OUT / (name + '.png')
    if name in ('scout', 'scout_male'):
        with Image.open(ART / 'frames' / (name + '_card_turn.png')) as turn:
            if turn.mode != 'RGBA' or turn.size != (CELL, CELL):
                raise ValueError(f'Invalid card-turn frame for {name}')
            cells = list(cells)
            cells[4] = turn.copy()
    # Work on a literal copy, then publish atomically so an open Godot editor
    # cannot import a half-written PNG or hold our output open during saving.
    temporary = REVIEW / (name + '.working.png')
    shutil.copy2(ART / (name + '.png'), temporary)
    with Image.open(temporary) as copied:
        sheet = copied.convert('RGBA')
    for i, frame in enumerate(cells):
        sheet.paste(frame, (i % 4 * CELL, i // 4 * CELL))
    sheet.save(temporary, optimize=True)
    for attempt in range(20):
        try:
            temporary.replace(target)
            break
        except PermissionError:
            if attempt == 19:
                raise
            time.sleep(.1)
    # Review image and animation are derived previews, not game assets.
    preview = Image.new('RGBA', sheet.size, (58,62,67,255))
    preview.alpha_composite(sheet)
    d = ImageDraw.Draw(preview)
    for i in range(12):
        d.text((i%4*CELL+5,i//4*CELL+5), str(i), fill='white')
    preview.convert('RGB').save(REVIEW / (name+'-corrected.jpg'))
    return {'source': name+'.png', 'source_sha256': hashlib.sha256((ART/(name+'.png')).read_bytes()).hexdigest(),
            'output_sha256': hashlib.sha256(target.read_bytes()).hexdigest()}


def main():
    OUT.mkdir(exist_ok=True)
    REVIEW.mkdir(exist_ok=True)
    (REVIEW/'.gdignore').touch()
    (REVIEW/'.gitignore').write_text('*\n')
    manifest = []
    for job, names in enumerate(PAIRS):
        # The complete existing portrait atlas already has the desired face.
        # Use its pixels directly; there is no runtime face replacement.
        source = frames('doctor-portrait' if job == 3 else names[0])
        common = build_base(job, source)
        manifest.append(save(names[0], common))
        if len(names) > 1:
            manifest.append(save(names[1], build_base(job, frames(names[1]), common[0])))
        if job == 3:
            manifest.append(save('doctor-portrait', common))
    (OUT/'manifest.json').write_text(json.dumps({'tool':'Pillow pixel edits', 'cell_size':CELL, 'atlases':manifest},indent=2)+'\n')
    print(f'Wrote {len(manifest)} edited atlas copies; original PNGs unchanged.')


if __name__ == '__main__':
    main()
