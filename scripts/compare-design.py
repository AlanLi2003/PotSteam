"""Compose actual supplied boards and Simulator captures; no pixel-match score."""
from PIL import Image, ImageDraw
from pathlib import Path
import json

root = Path(__file__).resolve().parent.parent
evidence = root / 'artifacts/architecture-migration-20261031'
boards = root / 'docs/design-handoff-2026-10-31/assets'
out = evidence / 'comparisons'
out.mkdir(exist_ok=True)
targets = [
 ('home', 'preview-a-discover.png', (42,12,426,826)),
 ('kitchen-tracked-dates', 'preview-a-discover.png', (868,12,1252,826)),
 ('shopping-checked', 'preview-a-discover.png', (1281,12,1665,826)),
 ('native-detail', 'preview-b-cook-corrected.png', (31,89,358,975)),
 ('native-prep', 'preview-b-cook-corrected.png', (384,91,674,908)),
 ('timer-paused', 'preview-b-cook-corrected.png', (895,91,1188,908)),
 ('completion-saved', 'preview-b-cook-corrected.png', (1211,91,1511,908)),
 ('settings-native-top', 'preview-c-support.png', (433,127,760,793)),
 ('ingredient-keyboard', 'preview-c-support.png', (800,127,1115,793)),
 ('ingredient-drawer-paused', 'preview-c-support.png', (1157,127,1481,793)),
 ('favorites-native', 'preview-c-support.png', (60,127,391,754)),
 ('history-native', 'preview-c-support.png', (60,127,391,754)),
]
metadata = []
for name, board, box in targets:
    path = evidence / 'screens' / (name + '.png')
    if not path.exists():
        raise RuntimeError('Missing actual rendered screen: ' + str(path))
    source = Image.open(boards / board).convert('RGB').crop(box)
    rendered = Image.open(path).convert('RGB')
    original = rendered.size
    # Native capture is ~3x. Remove real status/home safe areas for comparison;
    # preserve each board panel's own aspect ratio, never stretch it vertically.
    rendered = rendered.resize((393,852), Image.Resampling.LANCZOS).crop((0,59,393,818))
    source = source.resize((393, round(source.height*393/source.width)), Image.Resampling.LANCZOS)
    canvas = Image.new('RGB', (826, max(source.height,rendered.height)+55), '#deded8')
    draw = ImageDraw.Draw(canvas)
    draw.text((12,12), 'SUPPLIED BOARD (state may differ)', fill='#272B27')
    draw.text((421,12), 'ACTUAL iPhone 16 QA 100', fill='#272B27')
    canvas.paste(source,(12,40));canvas.paste(rendered,(421,40))
    canvas.save(out/(name+'.png'))
    metadata.append(dict(screen=name,source=board,sourceBoardPixels=Image.open(boards/board).size,
                         sourceCrop=box,renderedPixels=original,normalizedNativePixels=[393,852],
                         nativeContentCrop=[0,59,393,818],sourceAspectPreserved=True))

# Focused typography/progress and original supplied icon usage, with explicit
# state differences (running vs paused, sample recipe amounts vs real quotes).
for name, board, box, shot, crop in [
 ('focus-timer', 'preview-b-cook-corrected.png', (924,486,1164,710), 'timer-paused', (94,475,299,680)),
 ('focus-food-icons', 'preview-b-cook-corrected.png', (398,347,670,650), 'native-prep', (26,293,367,590)),
 ('focus-history', 'preview-c-support.png', (20,812,207,980), 'history-native', (22,375,371,493)),
]:
    source=Image.open(boards/board).convert('RGB').crop(box)
    actual=Image.open(evidence/'screens'/(shot+'.png')).convert('RGB').resize((393,852)).crop(crop)
    images=[im.resize((360,round(im.height*360/im.width)),Image.Resampling.LANCZOS) for im in (source,actual)]
    canvas=Image.new('RGB',(756,max(im.height for im in images)+50),'#deded8')
    d=ImageDraw.Draw(canvas);d.text((12,12),'SUPPLIED / sample state',fill='#272B27');d.text((390,12),'ACTUAL / verified state',fill='#272B27')
    for x,im in zip([12,390],images):canvas.paste(im,(x,38))
    canvas.save(out/(name+'.png'))
(out/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
print(f'Wrote {len(targets)} full-view and 3 focused source/render comparisons.')
