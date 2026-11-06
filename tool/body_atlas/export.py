"""Evaluate all defs on the four images and write the app's assets:
  assets/body/<figure>_<view>.jpg  and  assets/data/body_positions.json
usage: python3 export.py <repo_dir>"""
import json, os, sys
from PIL import Image
import pts, lm

repo = sys.argv[1]
pts.load_defs()
os.makedirs(os.path.join(repo, 'assets/body'), exist_ok=True)
figures, points, problems = {}, {}, []
for image in lm.IMAGES:
    figure, view = image.split('_')
    im = Image.open(image + '.png').convert('RGB')
    rel = f'assets/body/{figure}_{view}.jpg'
    # 高清底图：优先用 Real-ESRGAN x4 超分结果（upscale.py），缩到 3 倍（2544×3792）导出；
    # 坐标仍以原图尺寸（848×1264）为坐标系，App 按比例铺满。
    hd = image + '_x4.png'
    out_im = Image.open(hd).convert('RGB') if os.path.exists(hd) else im
    if out_im is not im:
        out_im = out_im.resize((im.width * 3, im.height * 3), Image.LANCZOS)
    out_im.save(os.path.join(repo, rel), quality=86, optimize=True, progressive=True)
    figures.setdefault(figure, {})[view] = {'image': rel, 'width': im.width, 'height': im.height}
    out, errs = pts.evaluate(image)
    problems += errs
    for code, ps in out.items():
        e = points.setdefault(code, {'view': view})
        e[figure] = [[round(float(p[0]), 1), round(float(p[1]), 1)] for p in ps]
codes = {p['code'] for p in json.load(open(os.path.join(repo, 'assets/data/acupoints.json')))}
missing = sorted(codes - set(points))
incomplete = sorted(c for c, e in points.items() if not ('male' in e and 'female' in e))
doc = {
    'version': 1,
    'note': '人体底图为 AI 生成的写实示意图（无真人肖像）。穴位位置按骨度分寸由体表标志（MediaPipe 关键点 + 身体比例）'
            '推算，属学习示意，非精确体表定位。生成工具见 tool/body_atlas/。',
    'figures': figures,
    'points': {c: points[c] for c in sorted(points)},
}
json.dump(doc, open(os.path.join(repo, 'assets/data/body_positions.json'), 'w'), ensure_ascii=False, separators=(',', ':'))
print('points', len(points), 'missing', len(missing), missing[:20], 'incomplete', incomplete[:10])
for p in problems:
    print('WARN', p)
