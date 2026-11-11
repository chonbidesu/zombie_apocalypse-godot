"""Independent pixel invariants for the repaired selection PNGs (Pillow only)."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageChops, ImageStat

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/character_creation'
OUT = ART / 'corrected'
PAIRS = [
    ('private','private_female'), ('medic-refined','medic_male'),
    ('scout','scout_male'), ('doctor-refined','doctor_male'),
    ('lab-face-refined','necro_female'), ('consumer-full-redraw','consumer_male'),
    ('police-full-redraw','police_female'),
    ('firefighter-size-matched','firefighter_male'), ('corpse-refined',),
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
    [(0,215,362,362),(310,160,362,362)],
]
IDLE_BODY_START = [92,117,118,137,192,220,138,101]
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
    original = source_frames('doctor-portrait' if name == 'doctor-refined' else name)
    doctor_boot = source_frames('doctor-portrait')[0] if job == 3 else None
    for i, frame in enumerate(sequence):
        def native(box, detail, donor=i):
            check(same(frame,original[donor],box), f'{name} frame {i}: original {detail}')
        if name == 'private_female':
            native((226,101,271,140), 'sleeve and revealed chair', 0 if i < 4 else i)
        if job == 1:
            check(same(frame,sequence[0],(74,236,202,362)),
                  f'{name} frame {i}: planted lower thighs, legs and boots')
            if i >= 8:
                native((85,183,151,194), 'belt and buckle')
                native((87,196,118,208), 'fabric crossing former waist join')
            if name == 'medic_male':
                native((100,225,123,233), 'male cargo pocket', 0)
            if i in (5,6):
                native((184,175,224,196), 'near hand')
                native((224,185,249,197), 'fingers at mug')
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
        if job == 3:
            alpha = frame.getchannel('A')
            for y, edge in [(257,153),(262,152),(269,150),(275,148),(281,147),
                            (285,145),(290,142),(295,140),(300,138)]:
                check(alpha.crop((124,y,edge,y+1)).getextrema()[1] == 0,
                      f'{name} frame {i}: clear to front trouser at row {y}')
            check(same(frame, doctor_boot, (146,305,178,330)),
                  f'{name} frame {i}: original front cuff and shoe')
            native((133,21,205,85), 'face through jaw')
            native((142,76,178,115), 'lapels and stethoscope')
            if i in (7,8,9):
                native((209,146,231,157), 'hand at jukebox')
        if job == 4:
            native((150,53,214,139), 'face, collar and glove')
        if job == 5:
            # Compare the playing surface row by row, including motion blur,
            # shadows, the whole rack and the scattered balls near both rails.
            match = all(same(frame, original[i],
                        (46+(y-149)*3//4,y,278+(y-149)*7//8,y+1))
                        for y in range(149,211))
            check(match, f'{name} frame {i}: original felt and balls')
        if job == 6 and i < 4:
            native((145,77,210,113), 'moving collar')
        if name == 'police_female':
            native((276,250,320,339), 'chair edge down to boot', 0)
            check(same(frame,sequence[0],(0,258,362,362)),
                  f'{name} frame {i}: planted legs and chair front')
            native((103,162,203,193), 'sleeves and belt', 0 if i < 4 else i)
            if i < 4:
                native((205,174,222,213), 'entire hanging cloth', 0)
                native((87,150,104,180), 'chair beside sleeve', 0)
            else:
                native((289,201,311,225), 'cloth on right knee', 7)
        if job == 7:
            native((99,167,295,232), 'coat, gloves and complete axe', 0 if i < 4 else i)


def main():
    manifest = json.loads((OUT/'manifest.json').read_text())
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
                for box in FIXED[job]:
                    check(same(reference,frame,box),f'{name} frame {i}: fixed RGBA area {box}')
                # A frame's occupied content must not touch any cell boundary.
                alpha=frame.getchannel('A')
                for box in [(0,0,362,1),(0,361,362,362),(0,0,1,362),(361,0,362,362)]:
                    check(alpha.crop(box).getextrema()[1] == 0,f'{name} frame {i}: no cell-edge clipping {box}')
            if job < 8:
                for i in range(1,4):
                    check(same(sequence[0],sequence[i],(0,IDLE_BODY_START[job],362,362)),
                          f'{name} idle {i}: stationary body and props')
            check(len({f.tobytes() for f in sequence[4:]}) >= 5,name+' retains distinct action drawings')
            if job == 3:
                for i,frame in enumerate(sequence):
                    check(frame.getchannel('A').crop((125,263,136,299)).getextrema()[1] == 0,
                          f'{name} frame {i}: third calf removed')
                for i in [9,10,11]:
                    # Every side of the window gets brighter; silhouette stays put.
                    for box in [(208,119,218,133),(228,108,243,123),(252,121,263,135)]:
                        before=ImageStat.Stat(sequence[0].crop(box)).mean
                        after=ImageStat.Stat(sequence[i].crop(box)).mean
                        check(after[0]>before[0]+8 and after[1]>before[1]+4,
                              f'{name} frame {i}: full illuminated window {box}')
                    check(same(sequence[9],sequence[i],(202,104,269,139)),f'{name} frame {i}: light stays registered')
    with Image.open(OUT/'doctor-portrait.png') as portrait, Image.open(OUT/'doctor-refined.png') as doctor:
        check(portrait.tobytes()==doctor.tobytes(), 'Both default doctor atlases use the repaired drawing')
    report={'checks':checks,'failures':failures,'atlases':18,'frames':216,
            'scope':'source hashes, complete fixed RGBA regions across frames/genders, idle body, cell boundaries, source drawing continuity, scouts, actions, doctor legs and light'}
    (OUT/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'Atlas pixels: {checks} checks, {len(failures)} failures')
    for failure in failures:
        print('FAIL:',failure)
    raise SystemExit(bool(failures))


if __name__ == '__main__':
    main()
