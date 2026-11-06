"""按 GB/T 12346-2021《经穴名称与定位》修订 acupoints.json（在两个 import 脚本之后运行，可重复执行）。

- 印堂归入督脉，编号 GV24+，位于神庭（GV24）与素髎（GV25）之间：新增。
- 风市（GB31）：腘横纹上 9 寸（2006 版为 7 寸）；改定位文字。
- 鸠尾（CV15）：剑胸结合下 1 寸；原数据写「剑突下 0.5 寸」，改定位文字。
只改定位，不新增或改动功效、主治。
"""
import json, os, re

P = os.path.join(os.path.dirname(__file__), '..', 'assets', 'data', 'acupoints.json')
GB = 'GB/T 12346-2021《经穴名称与定位》'
pts = json.load(open(P, encoding='utf-8'))
by = {p['code']: p for p in pts}

def patch(code, loc, sec):
    p = by[code]
    p['location'] = loc
    note = f'定位按 {GB} {sec} 修订。'
    src = re.sub(r'定位按 GB/T 12346-2021《经穴名称与定位》 [\d.]+ 修订。', '', p['source'])
    p['source'] = src.rstrip('。') + '。' + note

patch('GB31', '股外侧，腘横纹上9寸，髂胫束后缘；直立垂手、掌心贴于大腿时，中指尖所指凹陷中', '5.11.31')
patch('CV15', '上腹部，前正中线上，剑胸结合下1寸', '5.14.15')

# 2026-11-07 逐条核对解剖标志后，标志与国标不同的定位文字（寸数原本一致或原文缺寸数）
SEC = {'LU': 1, 'LI': 2, 'ST': 3, 'SP': 4, 'HT': 5, 'SI': 6, 'BL': 7, 'KI': 8, 'PC': 9,
       'TE': 10, 'GB': 11, 'LR': 12, 'GV': 13, 'CV': 14}
FIX = {
    'LI12': '肘后外侧，肱骨外上髁上缘，髁上嵴的前缘',
    'LI14': '臂外侧，曲池（LI11）与肩髃（LI15）连线上，三角肌前缘处，约曲池上7寸',
    'LI17': '颈前部，横平环状软骨，胸锁乳突肌后缘；扶突（LI18）直下',
    'ST40': '小腿外侧，外踝尖上8寸，胫骨前肌外缘；条口（ST38）外侧一横指',
    'SI4': '腕后内侧，第5掌骨底与三角骨之间的赤白肉际凹陷中',
    'SI6': '前臂后侧，腕背横纹上1寸，尺骨头桡侧凹陷中',
    'SI11': '肩胛区，肩胛冈中点与肩胛骨下角连线的上1/3与下2/3交点凹陷中',
    'BL10': '颈后部，横平第2颈椎棘突上际，斜方肌外缘凹陷中',
    'BL54': '臀部，横平第4骶后孔，骶正中嵴旁开3寸',
    'KI1': '足底，屈足卷趾时足心最凹陷处',
    'KI6': '足内侧，内踝尖下1寸，内踝下缘边际凹陷中',
    'KI10': '膝后内侧，腘横纹上，半腱肌肌腱外侧缘',
    'TE13': '臂后侧，尺骨鹰嘴尖与肩峰角连线上，与三角肌后缘相交处',
    'TE20': '头部，耳尖正对发际处',
    'GB26': '侧腹部，第11肋骨游离端垂线与脐水平线的交点',
    'GB33': '膝外侧，股骨外上髁后上缘，股二头肌腱与髂胫束之间的凹陷中',
    'LR8': '膝内侧，腘横纹内侧端，半腱肌肌腱内缘凹陷中',
    'GV15': '颈后部，后正中线上，第2颈椎棘突上际凹陷中；后发际正中直上0.5寸',
}
import re
for code, loc in FIX.items():
    m = re.match(r'([A-Z]+)(\d+)', code)
    patch(code, loc, f'5.{SEC[m.group(1)]}.{m.group(2)}')

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
