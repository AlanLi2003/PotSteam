from pathlib import Path
from html import escape
import json

ROOT = Path(__file__).resolve().parents[1]
ICONS = {
    'egg': ('Eggs', '鸡蛋', '<path d="M18.5 14c0 4-2.9 7-6.5 7s-6.5-3-6.5-7S9 3 12 3s6.5 7 6.5 11Z"/>'),
    'tomato': ('Tomatoes', '番茄', '<path d="M8 7C3 7 2 11 3 15c1 4 4 6 9 6s8-2 9-6c1-4 0-8-5-8"/><path d="m12 8-4-3 4 1 2-4v4l5-1-4 3 2 3-5-2-4 2 2-3M12 6V3"/>'),
    'scallions': ('Scallions', '葱', '<path d="M7 17 16 3c1 5-3 11-7 15M11 19l9-13c1 5-2 11-7 14"/><path d="M7 17c-2-1-4 2-3 3s3 0 5-2M11 19c-2-1-4 1-3 2s3 1 5-1M4 20l-2 1m3 0-1 2m4-2-1 2"/>'),
    'oil': ('Cooking oil', '食用油', '<path d="M10 2h4v5l3 4v10H7V11l3-4V2ZM10 5h4"/><path d="M12 12s-2 2.4-2 3.5a2 2 0 0 0 4 0c0-1.1-2-3.5-2-3.5Z"/>'),
    'salt': ('Salt', '盐', '<path d="M7 8h10l2 11a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2L7 8ZM7 8V5a5 3 0 0 1 10 0v3"/><path d="M9 5h.1M12 4.5h.1M15 5h.1M9 13h.1M14 14h.1M11 17h.1"/>'),
    'pepper': ('White pepper', '白胡椒 仅对应实际食材', '<path d="M7 3h10v4H7zM8 7l-2 3v11h12V10l-2-3"/><circle cx="9" cy="13" r=".6"/><circle cx="14.5" cy="12" r=".6"/><circle cx="12" cy="16" r=".6"/><circle cx="15" cy="19" r=".6"/><circle cx="8.5" cy="18" r=".6"/>'),
    'pan': ('Cooking pan', '平底锅', '<ellipse cx="9" cy="12" rx="7" ry="3"/><path d="M2 12v3c0 2 3 4 7 4s7-2 7-4v-3m0-1 5-4 2 2-7 5"/>'),
    'utensils': ('Cooking utensils', '锅铲与筷子', '<path d="m3 3 6 1-1 7-5-1V3ZM6 11l-1 10M13 3l2 18M18 3l3 18M5 6l1 .2M5 8l1 .2"/>'),
}

out = ROOT / 'assets/icons'
out.mkdir(parents=True, exist_ok=True)
base = 'xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"'
for key, (label, cn, paths) in ICONS.items():
    (out / f'{key}.svg').write_text(f'<svg {base} role="img" aria-label="{label}">{paths}</svg>\n')

cards=[]
for n, (key, (label, cn, paths)) in enumerate(ICONS.items()):
    x, y = 30+(n%4)*290, 125+(n//4)*185
    cards.append(f'<rect x="{x}" y="{y}" width="270" height="164" rx="16" fill="#FFFFFF" stroke="#EAE9E3"/><g transform="translate({x+105} {y+20}) scale(2.5)" fill="none" stroke="#567B61" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">{paths}</g><text x="{x+135}" y="{y+110}" text-anchor="middle" font-size="18" font-weight="600">{escape(label)}</text><text x="{x+135}" y="{y+139}" text-anchor="middle" font-size="14" fill="#62695F">{escape(cn)}</text>')
sheet=f'''<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="560" viewBox="0 0 1200 560"><rect width="1200" height="560" fill="#FAF9F6"/><g fill="#272B27" font-family="-apple-system,BlinkMacSystemFont,PingFang SC,Arial,sans-serif"><text x="30" y="48" font-size="30" font-weight="700">CNrecipe 食品与设备图标修正版</text><text x="30" y="82" font-size="17" fill="#62695F">24 × 24 viewBox · 1.7 stroke · 单色线性图标 · 名称始终可见</text>{''.join(cards)}<text x="30" y="529" font-size="16" fill="#62695F">实现时使用本组 SVG 原稿；图标不承担勾选状态，不新增食材，不替代设备名称。</text></g></svg>'''
(ROOT / 'assets/icon-corrections.svg').write_text(sheet)
(out / 'mapping.json').write_text(json.dumps({k:{'label':v[0], 'description':v[1], 'file':f'{k}.svg'} for k,v in ICONS.items()},ensure_ascii=False,indent=2))
print(f'Created {len(ICONS)} SVG icons and correction sheet')
