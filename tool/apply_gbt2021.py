"""按 GB/T 12346-2021《经穴名称与定位》修订 acupoints.json（在两个 import 脚本之后运行，可重复执行）。

- 印堂归入督脉，编号 GV24+，位于神庭（GV24）与素髎（GV25）之间：新增。
- 风市（GB31）：腘横纹上 9 寸（2006 版为 7 寸）；改定位文字。
- 鸠尾（CV15）：剑胸结合下 1 寸；原数据写「剑突下 0.5 寸」，改定位文字。
只改定位，不新增或改动功效、主治。
"""
import json, os

P = os.path.join(os.path.dirname(__file__), '..', 'assets', 'data', 'acupoints.json')
GB = 'GB/T 12346-2021《经穴名称与定位》'
pts = json.load(open(P, encoding='utf-8'))
by = {p['code']: p for p in pts}

def patch(code, loc, sec):
    p = by[code]
    p['location'] = loc
    note = f'定位按 {GB} {sec} 修订。'
    if note not in p['source']:
        p['source'] = p['source'].rstrip('。') + '。' + note

patch('GB31', '股外侧，腘横纹上9寸，髂胫束后缘；直立垂手、掌心贴于大腿时，中指尖所指凹陷中', '5.11.31')
patch('CV15', '上腹部，前正中线上，剑胸结合下1寸', '5.13.15')

if 'GV24+' not in by:
    gv24 = by['GV24']
    yt = {
        'id': 'GV24+', 'nameZh': '印堂', 'pinyin': 'Yìntáng', 'code': 'GV24+',
        'meridianId': gv24['meridianId'], 'view': 'front',
        'coordinate': dict(gv24['coordinate']),
        'location': '头部，两眉毛内侧端中间的凹陷中，即左右攒竹（BL2）连线的中点',
        'indications': [], 'efficacyTags': [], 'specialCategories': [], 'cautions': '',
        'source': f'定位：{GB} 5.13.25（2021 版将印堂由经外奇穴归入督脉，编号 GV24+）。功效与主治暂未收录。',
    }
    pts.insert(pts.index(gv24) + 1, yt)

json.dump(pts, open(P, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print(len(pts), 'points')
