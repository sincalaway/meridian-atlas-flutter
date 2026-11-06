"""Tiny DSL to place acupoints on the figure images from landmarks + proportional cun (骨度分寸).

A defs file (defs/<group>.py) looks like:

    from pts import *

    @point('LI11', 'front')            # bilateral by default; fn(s) gets s = 'R' or 'L'
    def _(s):
        return seg(L('elbow_lat', s), L('wrist_rad', s), 12, 0)

    @point('CV12', 'front', mid=True)  # midline point: fn() takes no args
    def _():
        return up(L('navel'), 4, U('abd_up'))

Every function returns an np.array([x, y]) in IMAGE PIXELS of the current image.
The same defs are evaluated on all four images (male/female x front/back); only the
defs whose view matches the image's view are evaluated on it.
"""
import importlib.util, glob, os, json, sys
import numpy as np
import lm

A = np.array
_DEFS = []          # (code, view, mid, fn, file)
_CUR = {}           # current image context


def point(code, view, mid=False):
    assert view in ('front', 'back'), view
    def deco(fn):
        _DEFS.append((code, view, mid, fn, _CUR.get('file')))
        return fn
    return deco


# ---------- landmark access ----------
def L(name, s=None):
    """landmark of the current image; sided names take s ('R'/'L')"""
    LM = _CUR['L']
    key = f'{name}_{s}' if s else name
    if key not in LM:
        raise KeyError(f'landmark {key!r} not on {_CUR["image"]}')
    return LM[key].astype(float).copy()


def has(name, s=None):
    return (f'{name}_{s}' if s else name) in _CUR['L']


def view():
    return _CUR['view']


# ---------- geometry ----------
def lerp(a, b, t):
    return a + (b - a) * t


def mid(a, b):
    return (a + b) / 2


def seg(a, b, total_cun, n_cun):
    """point n_cun from a toward b, where a->b spans total_cun (骨度分寸)"""
    return a + (b - a) * (n_cun / total_cun)


def _lat_sign(s):
    # +1 means image +x is lateral for side s
    if _CUR['view'] == 'front':
        return -1.0 if s == 'R' else 1.0
    return 1.0 if s == 'R' else -1.0


def lat(p, cun, unit_px, s):
    """move horizontally `cun` toward the subject's side s (negative = medial)"""
    return p + A([_lat_sign(s) * cun * unit_px, 0.0])


def at_x_from_mid(y_point, cun, unit_px, s):
    """point at the height of y_point, `cun` lateral of the body midline"""
    return A([_CUR['L']['mid_x'][0] + _lat_sign(s) * cun * unit_px, y_point[1]])


def down(p, cun, unit_px):
    return p + A([0.0, cun * unit_px])


def up(p, cun, unit_px):
    return p - A([0.0, cun * unit_px])


def toward(p, q, px):
    v = q - p; n = np.linalg.norm(v)
    return p if n == 0 else p + v / n * px


def perp(p, a, b, px, s):
    """offset p perpendicular to segment a->b by px pixels, toward the subject's lateral side s
    in image terms (negative px = medial)"""
    v = (b - a) / np.linalg.norm(b - a)
    n = A([-v[1], v[0]])
    if n[0] * _lat_sign(s) < 0:
        n = -n
    return p + n * px


def dist(a, b):
    return float(np.linalg.norm(b - a))


# ---------- proportional units (pixels per cun) ----------
def U(name, s=None):
    """pixels per 1 cun for a body region. Available:
    front: chest_x (两乳头间 8寸), chest_y (胸骨上窝-胸剑联合 9寸), abd_up (胸剑联合-脐 8寸),
           abd_lo (脐-耻骨联合上缘 5寸), head_y (眉间-前发际 3寸), head_x (两额角发际 9寸, approx via temples)
    back:  back_x (肩峰端-后正中线 8寸), back_y (one vertebra spacing T1..L5 ≈ distance used for 'one vertebra',
           NOT a cun), head_yb (后发际-大椎 3寸), head_xb (两乳突间 9寸)
    both (sided, give s): upper_arm (腋前/后纹头-肘横纹 9寸), forearm (肘横纹-腕横纹 12寸),
           thigh (股骨大转子-腘横纹/膝中 19寸), leg (膝中-外踝尖 16寸), leg_med (胫骨内侧髁下缘-内踝尖 13寸)
    """
    Lm = _CUR['L']; g = lambda k: Lm[k]
    v = _CUR['view']
    if name == 'chest_x':
        return dist(g('nipple_R'), g('nipple_L')) / 8 if v == 'front' else dist(g('acromion_R'), g('acromion_L')) / 16
    if name == 'chest_y':
        return (g('xiphoid')[1] - g('sternal_notch')[1]) / 9
    if name == 'abd_up':
        return (g('navel')[1] - g('xiphoid')[1]) / 8
    if name == 'abd_lo':
        return (g('pubis')[1] - g('navel')[1]) / 5
    if name == 'head_y':
        return dist(g('glabella'), g('hairline_front')) / 3
    if name == 'head_x':
        return dist(g('temple_R'), g('temple_L')) / 9
    if name == 'back_x':
        return dist(g('acromion_R'), g('acromion_L')) / 16
    if name == 'back_y':
        return (g('spine_L5')[1] - g('spine_T1')[1]) / 16
    if name == 'head_yb':
        return (g('c7')[1] - g('hairline_back')[1]) / 3
    if name == 'head_xb':
        return dist(g('mastoid_R'), g('mastoid_L')) / 9
    if name == 'upper_arm':
        return dist(g('axilla_' + s), mid(g('elbow_lat_' + s), g('elbow_med_' + s))) / 9
    if name == 'forearm':
        return dist(mid(g('elbow_lat_' + s), g('elbow_med_' + s)), mid(g('wrist_rad_' + s), g('wrist_uln_' + s))) / 12
    if name == 'thigh':
        return (g('knee_' + s)[1] - g('trochanter_' + s)[1]) / 19
    if name == 'leg':
        return (g('malleolus_lat_' + s)[1] - g('knee_' + s)[1]) / 16
    if name == 'leg_med':
        return (g('malleolus_med_' + s)[1] - g('knee_med_' + s)[1]) / 13
    raise KeyError(name)


# ---------- evaluation ----------
def load_defs(pattern='defs/*.py'):
    _DEFS.clear()
    for f in sorted(glob.glob(os.path.join(lm.HERE, pattern))):
        _CUR['file'] = os.path.basename(f)
        spec = importlib.util.spec_from_file_location('d_' + os.path.basename(f)[:-3], f)
        mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
    _CUR.pop('file', None)
    return list(_DEFS)


def evaluate(image, only_file=None):
    L, v = lm.ALL[image]
    _CUR.update(L=L, view=v, image=image)
    mask = lm._mask(image)
    out, errors = {}, []
    for code, view_, is_mid, fn, f in _DEFS:
        if view_ != v or (only_file and f != only_file):
            continue
        try:
            pts = [fn()] if is_mid else [fn('R'), fn('L')]
            pts = [A(p, float) for p in pts]
            for p in pts:
                x, y = int(round(p[0])), int(round(p[1]))
                if not (0 <= y < mask.shape[0] and 0 <= x < mask.shape[1] and mask[y, x]):
                    errors.append(f'{image}: {code} at ({x},{y}) is outside the body mask')
            out[code] = pts
        except Exception as e:
            errors.append(f'{image}: {code} failed: {e!r}')
    return out, errors
