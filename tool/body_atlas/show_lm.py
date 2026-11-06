import sys
from PIL import Image, ImageDraw
import lm
for name in sys.argv[1:] or lm.IMAGES:
    L, view = lm.ALL[name]
    im = Image.open(name + '.png').convert('RGB')
    S = 2
    im = im.resize((im.width * S, im.height * S))
    d = ImageDraw.Draw(im)
    for k, v in L.items():
        if k.startswith('_') or k == 'mid_x' or k.startswith('hand_'):
            continue
        x, y = v[0] * S, v[1] * S
        d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=(255, 50, 50))
        d.text((x + 6, y - 6), k, fill=(255, 255, 0))
    for k, v in L.items():
        if k.startswith('hand_'):
            x, y = v[0] * S, v[1] * S
            d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(80, 200, 255))
    im.save(f'lm_{name}.jpg', quality=85)
