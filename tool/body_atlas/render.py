"""Render placed points for checking.
usage: python3 render.py <defs_file_basename|all> [crop x0 y0 x1 y1] 
writes check_<group>_<image>.jpg (2x scale, or the crop at 3x) and prints errors."""
import sys, json
from PIL import Image, ImageDraw, ImageFont
import pts, lm

group = sys.argv[1]
crop = list(map(int, sys.argv[2:6])) if len(sys.argv) >= 6 else None
pts.load_defs()
NAMES = {p['code']: p['nameZh'] for p in json.load(open('../meridian-atlas-flutter/assets/data/acupoints.json'))}
try:
    font = ImageFont.truetype('/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc', 14)
except Exception:
    font = None
for f in ['/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc', '/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc']:
    try:
        font = ImageFont.truetype(f, 14); break
    except Exception:
        pass
for image in lm.IMAGES:
    out, errs = pts.evaluate(image, None if group == 'all' else group + '.py')
    for e in errs:
        print(e)
    if not out:
        continue
    im = Image.open(image + '.png').convert('RGB')
    S = 3 if crop else 2
    if crop:
        im = im.crop(crop)
    ox, oy = (crop[0], crop[1]) if crop else (0, 0)
    im = im.resize((im.width * S, im.height * S))
    d = ImageDraw.Draw(im)
    for code, ps in out.items():
        for p in ps:
            x, y = (p[0] - ox) * S, (p[1] - oy) * S
            d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=(255, 60, 60), outline=(255, 255, 255))
            d.text((x + 6, y - 8), code, fill=(255, 255, 0), font=font)
    tag = 'crop' if crop else 'full'
    fn = f'check_{group}_{image}_{tag}.jpg'
    im.save(fn, quality=85)
    print('wrote', fn, len(out), 'points')
