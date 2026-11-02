"""Original typographic recipe covers; no third-party photos or artwork."""
from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import json,re,hashlib
root=Path(__file__).resolve().parents[1];p=root/'docs/content/first-50';out=root/'ios/CNrecipe/Web/assets';out.mkdir(parents=True,exist_ok=True)
titles=json.loads((p/'editorial/english-titles.json').read_text());manifest=[]
font='/System/Library/Fonts/HelveticaNeue.ttc'
for n,title in enumerate(titles,1):
 im=Image.new('RGB',(1200,900),'#f1f0e9');d=ImageDraw.Draw(im)
 d.rounded_rectangle((45,45,1155,855),radius=45,outline='#d5d7cd',width=3)
 d.text((85,85),'CNrecipe',font=ImageFont.truetype(font,42),fill='#b84e34')
 d.text((1015,85),f'{n:02}',font=ImageFont.truetype(font,42),fill='#324136')
 d.arc((450,180,750,400),0,180,fill='#324136',width=13);d.line((445,286,753,286),fill='#324136',width=10);d.line((752,290,835,250),fill='#324136',width=13)
 for x in [540,600,660]:d.arc((x-20,175,x+20,245),80,280,fill='#b84e34',width=5)
 f=ImageFont.truetype(font,64);words=title.split();lines=[];line=''
 for w in words:
  test=(line+' '+w).strip()
  if d.textbbox((0,0),test,font=f)[2]>980:lines.append(line);line=w
  else:line=test
 lines.append(line)
 y=480
 for line in lines:
  box=d.textbbox((0,0),line,font=f);d.text(((1200-box[2])/2,y),line,font=f,fill='#272b27');y+=82
 d.text((85,785),'CHINESE HOME COOKING',font=ImageFont.truetype(font,24),fill='#697067')
 name=f'classic-{n:02}.jpg';path=out/name;im.save(path,quality=91,optimize=True)
 manifest.append({'candidateNumber':n,'file':str(path.relative_to(root)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'creator':'CNrecipe original generated graphic','rights':'Original geometric linework and typesetting; no external photograph, illustration or logo used','format':'JPEG','width':1200,'height':900})
(p/'image-rights.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('Created 50 original JPEG covers and rights manifest.')
