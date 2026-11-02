"""Build review-only contact sheets; generated deliverables are not altered."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps
import json
root=Path(__file__).resolve().parents[1];titles=json.loads((root/'docs/content/first-50/editorial/english-titles.json').read_text());out=root/'artifacts/recipe-media-fix';out.mkdir(parents=True,exist_ok=True)
recipes=json.loads((root/'backend/seeds/catalog.json').read_text())['recipes']
font=ImageFont.truetype('/System/Library/Fonts/HelveticaNeue.ttc',15)
for first,last in [(1,25),(26,50)]:
 rows=5;canvas=Image.new('RGB',(1400,1100),'white');draw=ImageDraw.Draw(canvas)
 for n in range(first,last+1):
  cell=n-first;x=(cell%5)*280;y=(cell//5)*220;p=root/'ios/CNrecipe/Web/assets'/recipes[n-1]['bundledImage']
  if '-photo-' not in p.name:p=root/f'ios/CNrecipe/Web/assets/classic-{n:02}-photo.jpg'
  if p.exists():
   with Image.open(p) as im:thumb=ImageOps.contain(im.convert('RGB'),(268,192));canvas.paste(thumb,(x+(280-thumb.width)//2,y+(192-thumb.height)//2))
  draw.text((x+5,y+196),f'{n:02} {titles[n-1][:29]}',font=font,fill='black')
 path=out/f'photos-{first:02}-{last:02}.jpg';canvas.save(path,quality=90)
print('Contact sheets saved; generated source images unchanged.')
