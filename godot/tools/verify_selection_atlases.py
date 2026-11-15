"""Independent pixel invariants for the repaired selection PNGs (Pillow only)."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageChops, ImageStat

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/character_creation'
OUT = ART / 'corrected'
PAIRS = [
    ('private_male','private_female'), ('medic_female','medic_male'),
    ('scout_female','scout_male'), ('doctor_female','doctor_male'),
    ('necro_male','necro_female'), ('consumer_female','consumer_male'),
    ('police_male','police_female'),
    ('firefighter_female','firefighter_male'), ('corpse',),
]
# Independently inspected visible rigid geometry. Check whole areas, including
# transparent gaps and antialiased silhouettes, not just a few anchor pixels.
FIXED = [
    [(0,246,362,362),(297,95,362,362),(0,185,159,362)],
    [(0,256,362,362),(0,210,65,256),(207,210,362,256),
     (0,115,30,362),(226,145,250,162),(266,163,362,223)],
    [(0,244,362,362),(0,227,195,244),(285,95,362,362)],
    [(0,253,362,362),(251,143,362,253),(205,165,240,253),(270,0,362,143)],
    [(0,192,362,362),(78,163,155,213),(216,178,282,213),(282,177,362,362)],
    [(0,220,362,362),(0,151,37,216),(48,132,104,141),(285,0,362,145),
     (349,151,362,216),(117,218,280,227)],
    [(0,258,183,362),(0,190,68,362),(342,183,362,362)],
    [(0,254,362,362)],
    [(0,215,362,362),(310,161,362,362),(313,160,362,161)],
]
IDLE_BODY_START = [190,209,201,137,192,220,234,254]
# Interior cloth below the neck must retain the source's breathing and shifts.
IDLE_TORSO = {0:(181,98,233,161), 1:(108,116,149,166),
              2:(182,115,237,159), 6:(139,116,219,163),
              7:(162,117,211,170)}
# Additional rigid details beside the moving upper bodies (within each sex).
IDLE_FURNITURE = {
    0:[(275,112,296,180),(268,190,281,215)],
    1:[(44,128,60,154),(216,145,253,181),(186,184,318,226)],
    2:[(275,126,293,179),(283,101,301,135)],
    6:[(54,139,76,173),(50,195,91,260),(282,189,316,223)],
    7:[],
}
checks = 0
failures = []


def check(condition, message):
    global checks
    checks += 1
    if not condition:
        failures.append(message)


def cells(name):
    im = Image.open(OUT/(name+'.png')).convert('RGBA')
    check(im.size == (1448,1086), name+' dimensions')
    return [im.crop((i%4*362,i//4*362,(i%4+1)*362,(i//4+1)*362)) for i in range(12)]


def same(a,b,box):
    # Comparing bytes also detects RGB changes behind alpha zero.
    return a.crop(box).tobytes() == b.crop(box).tobytes()


def source_frames(name):
    # Original exports contain effectively invisible alpha 1-3 specks which
    # the atlas writer clears. Compare normalized RGBA, including empty space.
    with Image.open(ART/(name+'.png')) as sheet:
        sheet = sheet.convert('RGBA')
    empty = sheet.getchannel('A').point(lambda a: 255 if a <= 3 else 0)
    sheet.paste((0,0,0,0), (0,0,*sheet.size), empty)
    return [sheet.crop((i%4*362,i//4*362,(i%4+1)*362,(i//4+1)*362)) for i in range(12)]


def verify_repairs(job, name, sequence):
    original = source_frames('doctor_portrait' if name == 'doctor_female' else name)
    doctor_boot = source_frames('doctor_portrait')[0] if job == 3 else None
    if name == 'doctor_male':
        scrubs = source_frames('frames/doctor_male_flat_chest')
        with Image.open(ART/'frames/doctor_male_upturned_eyes.png') as eyes:
            original[1].paste(eyes, (155,23))
    if job == 5:
        with Image.open(ART/'frames/consumer_table_pockets.png') as donor:
            pockets = donor.convert('RGBA')
    if job == 1:
        with Image.open(ART/'frames'/(name+'_cards.png')) as artwork:
            cards = artwork.convert('RGBA')
    for i, frame in enumerate(sequence):
        def native(box, detail, donor=i):
            check(same(frame,original[donor],box), f'{name} frame {i}: original {detail}')
        if name in ('doctor_male','private_female'):
            file, box = (('doctor_male_trousers',(92,124,208,352)) if name == 'doctor_male'
                         else ('private_female_shirt',(166,91,237,157)))
            width, height = box[2]-box[0], box[3]-box[1]
            x, y = i%4*width, i//4*height
            with Image.open(ART/'frames'/(file+'.png')) as tailoring:
                check(frame.crop(box).tobytes() == tailoring.crop((x,y,x+width,y+height)).tobytes(),
                      f'{name} frame {i}: registered uniform artwork')
        if name == 'private_female':
            if 0 < i < 4:
                native((237,101,257,140), 'breathing sleeve')
            else:
                native((237,101,271,140), 'sleeve and revealed chair')
        if job == 1:
            x, y = i%4*130, i//4*56
            left, top = (130,108) if i < 5 else (132,156)
            check(frame.crop((left,top,left+130,top+56)).tobytes() ==
                  cards.crop((x,y,x+130,y+56)).tobytes(), f'{name} frame {i}: four-card drawing')
            if i >= 7:
                # Interior of each individual card after both hands withdraw.
                for x, y in [(206,201),(218,200),(231,199),(243,198)]:
                    check(same(frame,sequence[7],(x-3,y-2,x+3,y+2)),
                          f'{name} frame {i}: stationary card face at {x}')
            check(same(frame,sequence[0],(74,236,202,362)),
                  f'{name} frame {i}: planted lower thighs, legs and boots')
            if i >= 8:
                native((85,183,151,194), 'belt and buckle')
                native((87,196,118,208), 'fabric crossing former waist join')
            if name == 'medic_male':
                native((100,225,123,233), 'male cargo pocket', 0)
            if i in (5,6):
                # Check the hands themselves, excluding the newly exposed wood.
                native((185,176,213,182), 'near hand above the spread')
                native((225,182,229,185), 'fingers at mug')
                if i == 6:
                    native((212,196,225,199), 'fingers covering the card faces')
            if i == 11:
                native((53,110,106,160), 'reclining back and chair')
        if job == 2:
            if i == 4:
                with Image.open(ART/'frames'/(name+'_card_turn.png')) as turn:
                    check(frame.tobytes()==turn.tobytes(), name+' retains the card turn')
            if i >= 5:
                native((148,166,245,197), 'waist')
                native((242,113,250,172), 'back')
            donor = 0 if i < 5 else i
            native((235,198,264,217), 'planted hip above seat', donor)
            alpha = frame.getchannel('A')
            for y in range(142,172):
                outer_gap = round(281.3 - (y-142)*0.157)
                check(alpha.getpixel((outer_gap,y)) == 0,
                      f'{name} frame {i}: clear outer spindle opening at row {y}')
                inner_gap = round(262.8 - (y-142)*0.070)
                opacity = alpha.getpixel((inner_gap,y))
                check(opacity == 0 if i >= 5 else opacity > 230,
                      f'{name} frame {i}: shirt covers opening until lean at row {y}')
            check(same(frame,sequence[0],(275,126,293,179)),
                  f'{name} frame {i}: registered outer spindles')
        if name == 'doctor_female':
            alpha = frame.getchannel('A')
            for y, edge in [(257,153),(262,152),(269,150),(275,148),(281,147),
                            (285,145),(290,142),(295,140),(300,138)]:
                check(alpha.crop((124,y,edge,y+1)).getextrema()[1] == 0,
                      f'{name} frame {i}: clear to front trouser at row {y}')
            check(same(frame, doctor_boot, (146,305,178,330)),
                  f'{name} frame {i}: original front cuff and shoe')
        if job == 3:
            native((133,21,205,85), 'face through jaw')
            box = (142,76,178,115)
            if name == 'doctor_male':
                expected = Image.alpha_composite(original[i].crop(box), scrubs[i].crop(box))
                check(frame.crop(box).tobytes() == expected.tobytes(),
                      f'{name} frame {i}: original lapels and stethoscope around revised shirt')
                solid = scrubs[i].getchannel('A').point(lambda a: 255 if a == 255 else 0)
                if i in (0,1,2,3,4,11):
                    # This section now uses the continuous shirt-to-waist drawing.
                    solid.paste(0, (155,125,196,145))
                check(solid.getbbox() is not None and all(
                      channel.getbbox() is None for channel in ImageChops.multiply(
                      ImageChops.difference(frame.convert('RGB'), scrubs[i].convert('RGB')),
                      solid.convert('RGB')).split()), f'{name} frame {i}: baked shirt fabric')
            else:
                native(box, 'lapels and stethoscope')
            if name == 'doctor_female' and i == 3:
                native((108,102,136,145), 'continuous coat across former sleeve seam')
                native((155,115,174,132), 'continuous button edge below lapel')
                # The light coat gives way to the teal shirt along this edge.
                # A splice to frame 0 produced an outward step here.
                edge = [next((x for x in range(152,180)
                              if frame.getpixel((x,y))[0] < frame.getpixel((x,y))[1]), None)
                        for y in range(113,138)]
                check(None not in edge and all(-1 <= b-a <= 0 for a,b in zip(edge,edge[1:])),
                      name+' fourth idle: uninterrupted sloping button edge')
            if i in (7,8,9):
                native((209,146,231,157), 'hand at jukebox')
        if job == 4:
            native((150,53,214,139), 'face, collar and glove')
        if job == 5:
            # Compare the playing surface row by row, including motion blur,
            # shadows, the whole rack and the scattered balls near both rails.
            expected = original[i].copy()
            for box in [(39,159,69,201),(294,158,327,193)]:
                check(same(frame,pockets,box),
                      f'{name} frame {i}: registered authored side pocket {box}')
                expected.paste(pockets.crop(box),box[:2])
            match = all(same(frame, expected,
                        (46+(y-149)*3//4,y,278+(y-149)*7//8,y+1))
                        for y in range(149,211))
            check(match, f'{name} frame {i}: original felt and balls outside authored pockets')
            native((65,4,245,132), 'continuous head, shoulders and arms')
            native((130,118,219,177), 'unspliced bridge hand and cue')
            if i == 9:
                duplicate = frame.getpixel((184,184))
                cue_ball = frame.getpixel((192,194))
                check(duplicate[0] > duplicate[1]*1.4,
                      name+' break: former duplicate ball is red')
                check(min(cue_ball[:3]) > 145 and max(cue_ball[:3])-min(cue_ball[:3]) < 65,
                      name+' break: one retained white cue ball')
        if job == 6 and i < 4:
            native((145,77,210,113), 'moving collar')
        if name == 'police_female':
            native((276,250,320,339), 'chair edge down to boot', 0)
            check(same(frame,sequence[0],(0,258,362,362)),
                  f'{name} frame {i}: planted legs and chair front')
            native((109,162,203,188) if 0 < i < 4 else (103,162,203,193),
                   'sleeves and belt')
            if i < 4:
                native((205,174,222,213), 'entire hanging cloth')
                check(same(frame,sequence[0],(69,150,87,173)),
                      f'{name} idle {i}: chair beside moving sleeve')
            else:
                native((289,201,311,225), 'cloth on right knee', 7)
        if job == 7:
            native((99,167,295,232), 'coat, gloves and complete axe')
        if job == 8:
            # Cross the former motion boundary at each strap, down to the
            # last fabric pixels above the diagonal rail.
            for box in [(118,172,141,196),(211,148,235,176),(287,132,305,160),
                        (55,198,67,211),(155,174,174,189),(245,153,264,169)]:
                native(box, 'moving bag and straps')
            for box in [(46,216,60,220),(122,202,137,208),(212,184,230,190),
                        (286,170,302,176),(10,165,21,175),(345,137,351,145)]:
                native(box, 'stationary gurney rail', 0)


def main():
    manifest = json.loads((OUT/'manifest.json').read_text())
    furniture = manifest['furniture_sources']
    check({entry['source'] for entry in furniture} ==
          {'frames/consumer_table_pockets.png', 'frames/medic_tabletop.png'},
          'Shared consumer and medic table artwork is recorded')
    for entry in furniture:
        check(hashlib.sha256((ART/entry['source']).read_bytes()).hexdigest() == entry['sha256'],
              entry['source']+' furniture matches manifest')
    check(len(manifest['atlases']) == 18, 'All eighteen original atlas files have edited copies')
    for entry in manifest['atlases']:
        check(hashlib.sha256((ART/entry['source']).read_bytes()).hexdigest() == entry['source_sha256'],
              entry['source']+' original unchanged')
        check(hashlib.sha256((OUT/entry['source']).read_bytes()).hexdigest() == entry['output_sha256'],
              entry['source']+' output matches reproducible manifest')
    for job,names in enumerate(PAIRS):
        reference = cells(names[0])[0]
        for name in names:
            sequence = cells(name)
            verify_repairs(job, name, sequence)
            for i,frame in enumerate(sequence):
                if job == 1:
                    check(same(frame, reference, (260,170,301,200)),
                          f'{name} frame {i}: shared coin stack, loose change and wood grain')
                    if i >= 7:
                        check(same(frame,sequence[7],(200,180,312,210)),
                              f'{name} frame {i}: registered table and cards after release')
                for box in FIXED[job]:
                    anchor = sequence[0] if name == 'doctor_male' and box == (0,253,362,362) else reference
                    check(same(anchor,frame,box),f'{name} frame {i}: fixed RGBA area {box}')
                # A frame's occupied content must not touch any cell boundary.
                alpha=frame.getchannel('A')
                for box in [(0,0,362,1),(0,361,362,362),(0,0,1,362),(361,0,362,362)]:
                    check(alpha.crop(box).getextrema()[1] == 0,f'{name} frame {i}: no cell-edge clipping {box}')
            if job < 8:
                for i in range(1,4):
                    lower_start = 178 if name == 'doctor_female' and i == 3 else IDLE_BODY_START[job]
                    check(same(sequence[0],sequence[i],(0,lower_start,362,362)),
                          f'{name} idle {i}: planted lower body and props')
                    if job in IDLE_TORSO:
                        box = (189,157,220,165) if name == 'private_female' else IDLE_TORSO[job]
                        if job == 1 and i == 3:
                            box = (108,116,135,166)  # Stop before the redrawn grip.
                        check(same(sequence[i],source_frames(name)[i],box),
                              f'{name} idle {i}: native upper-body drawing')
                        check(not same(sequence[0],sequence[i],box),
                              f'{name} idle {i}: breathing below the neck')
                        for rigid in IDLE_FURNITURE[job]:
                            check(same(sequence[0],sequence[i],rigid),
                                  f'{name} idle {i}: stationary adjacent furniture {rigid}')
            check(len({f.tobytes() for f in sequence[4:]}) >= 5,name+' retains distinct action drawings')
            if job == 3:
                for i,frame in enumerate(sequence):
                    gap = (151,274,157,308) if name == 'doctor_male' else (125,263,136,299)
                    check(frame.getchannel('A').crop(gap).getextrema()[1] < 10,
                          f'{name} frame {i}: clear space beside calf')
                for i in [9,10,11]:
                    # Every side of the window gets brighter; silhouette stays put.
                    for box in [(208,119,218,133),(228,108,243,123),(252,121,263,135)]:
                        before=ImageStat.Stat(sequence[0].crop(box)).mean
                        after=ImageStat.Stat(sequence[i].crop(box)).mean
                        check(after[0]>before[0]+8 and after[1]>before[1]+4,
                              f'{name} frame {i}: full illuminated window {box}')
                    check(same(sequence[9],sequence[i],(202,104,269,139)),f'{name} frame {i}: light stays registered')
    with Image.open(OUT/'doctor_portrait.png') as portrait, Image.open(OUT/'doctor_female.png') as doctor:
        check(portrait.tobytes()==doctor.tobytes(), 'Both default doctor atlases use the repaired drawing')
    report={'checks':checks,'failures':failures,'atlases':18,'frames':216,
            'scope':'source hashes, fixed RGBA furniture and lower bodies, native idle upper-body motion, cell boundaries, source drawing continuity, scouts, actions, doctor coat, legs and light'}
    (OUT/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'Atlas pixels: {checks} checks, {len(failures)} failures')
    for failure in failures:
        print('FAIL:',failure)
    raise SystemExit(bool(failures))


if __name__ == '__main__':
    main()
