"""Group C: 足太阳膀胱经 BL1–BL67 (骨度分寸 from landmarks).

Views: BL1–BL7 front (face / frontal scalp), BL8–BL61 back, BL62–BL67 front (lateral foot border, toes visible).
"""
from pts import *
from pts import _CUR, _lat_sign
import numpy as np
import lm as _lm
import os

_MASKS = {}


def _mask():
    im = _CUR['image']
    if im not in _MASKS:
        _MASKS[im] = _lm._mask(im)
    return _MASKS[im]


def _ok(p, r):
    m = _mask()
    H, W = m.shape
    for dx, dy in ((0, 0), (r, 0), (-r, 0), (0, r), (0, -r)):
        x, y = int(round(p[0] + dx)), int(round(p[1] + dy))
        if not (0 <= x < W and 0 <= y < H and m[y, x]):
            return False
    return True


def _inside(p, d, r=4, maxlen=80):
    """push p along direction d until it sits inside the body mask with margin r"""
    p = A(p, float); d = A(d, float); d = d / np.linalg.norm(d)
    for i in range(maxlen):
        q = p + d * i
        if _ok(q, r):
            return q
    return p


def _edge_x(y, x0, s, maxlen=150):
    """walk from (x0, y) toward the subject's lateral side s; last inside x (silhouette edge)"""
    m = _mask(); sg = _lat_sign(s)
    x = x0; last = x0
    for i in range(maxlen):
        xi = int(round(x0 + sg * i))
        if 0 <= xi < m.shape[1] and m[int(round(y)), xi]:
            last = xi
        elif i > 3:
            break
    return float(last)


# ---------------- units ----------------
def hx():
    """head horizontal cun. back: ears ≈ mastoids (两完骨之间 9寸);
    front: 两额角发际 9寸, the hair corners sit ≈0.9 of the temple width."""
    if view() == 'front':
        return dist(L('temple', 'R'), L('temple', 'L')) * 0.9 / 9
    return dist(L('ear', 'R'), L('ear', 'L')) / 9


_GRAY = {}


def _hairline_y():
    """visible front hairline on the midline (the hairline_front landmark is the top of the
    face mesh, ~10 px below the real hairline): scan up from the glabella for the hair edge."""
    im = _CUR['image']
    if im not in _GRAY:
        from PIL import Image
        _GRAY[im] = np.asarray(Image.open(os.path.join(_lm.HERE, im + '.png')).convert('L')).astype(float)
    g = _GRAY[im]
    x = int(round(_head_mid_x())); y0 = int(L('glabella')[1]) - 15
    skin = g[y0, x - 4:x + 5].mean()
    for y in range(y0, int(L('vertex')[1]), -1):
        if g[y, x - 4:x + 5].mean() < 0.6 * skin:
            return float(y)
    return L('hairline_front')[1]


def bx():
    return U('back_x')


def below(v):
    """level just below the spinous process of vertebra v (midway to the next one)"""
    order = ['C7'] + [f'T{i}' for i in range(1, 13)] + [f'L{i}' for i in range(1, 6)] + ['S1']
    i = order.index(v)
    return mid(L('spine_' + v), L('spine_' + order[i + 1]))


def shu(v, cun, s):
    return at_x_from_mid(below(v), cun, bx(), s)


# ---------------- head (front) ----------------
def _front_scalp_y(c):
    """y of the scalp midline c cun behind the front hairline (front view; foreshortened toward vertex).
    vertex (GV20) at 5 cun; the slope at the hairline ≈ 1 cun of forehead (head_y)."""
    yv, yh = L('vertex')[1], _hairline_y()
    t = max(0.0, 1 - c / 5)
    return yv + (yh - yv) * (2 * t * t - t ** 3)


def _head_mid_x():
    """facial midline (the head is not exactly on the body's mid_x)"""
    return (L('hairline_front')[0] + L('glabella')[0] + L('nose_root')[0]) / 3


def _top_y(x):
    m = _mask(); col = np.where(m[:, int(round(x))])[0]
    return float(col.min()) if len(col) else L('vertex')[1]


def _front_scalp(c, cun, s):
    """off-midline scalp point: add the coronal drop of the skull at that x (full near the vertex,
    none at the near-vertical forehead hairline)"""
    x = _head_mid_x() + _lat_sign(s) * cun * hx()
    yv, yh = L('vertex')[1], _hairline_y()
    y = _front_scalp_y(c)
    w = 1 - (y - yv) / (yh - yv)
    y += max(0.0, _top_y(x) - yv) * w
    return _inside(A([x, y]), (0, 1), 3)


@point('BL1', 'front')
def _(s):
    p = L('eye_in', s)
    return lat(up(p, 0.1, U('head_y')), -0.1, hx(), s)


@point('BL2', 'front')
def _(s):
    return L('brow_in', s)


@point('BL3', 'front')
def _(s):
    # 攒竹 directly above (额切迹), ≈0.75 cun off the midline
    x = _head_mid_x() + _lat_sign(s) * max(abs(L('brow_in', s)[0] - _head_mid_x()), 0.75 * hx())
    p = A([x, _front_scalp_y(0.5)])
    return _inside(p, (0, 1), 3)


@point('BL4', 'front')
def _(s):
    return _front_scalp(0.5, 1.5, s)


@point('BL5', 'front')
def _(s):
    return _front_scalp(1.0, 1.5, s)


@point('BL6', 'front')
def _(s):
    return _front_scalp(2.5, 1.5, s)


@point('BL7', 'front')
def _(s):
    return _front_scalp(4.0, 1.5, s)


# ---------------- head / neck (back) ----------------
def _back_scalp_y(c):
    """y of the posterior scalp midline c cun above the back hairline (back view).
    hairline -> EOP (occiput, ≈2.5 cun, 脑户) linear, EOP -> GV20 (7 cun) foreshortened.
    GV20 sits a little below the silhouette top because the crown is seen slightly from above."""
    yh, yo = L('hairline_back')[1], L('occiput')[1]
    top = max(L('vertex')[1], _top_y(L('mid_x')[0]))   # silhouette top (hair) at the midline
    yv = top + 0.25 * (yo - top)
    if c <= 2.5:
        return yh + (yo - yh) * c / 2.5
    t = (7 - c) / 4.5
    return yv + (yo - yv) * (2 * t * t - t ** 3)


@point('BL8', 'back')
def _(s):
    p = A([L('mid_x')[0] + _lat_sign(s) * 1.5 * hx(), _back_scalp_y(6.5)])
    return _inside(p, (0, 1), 3)


@point('BL9', 'back')
def _(s):
    return at_x_from_mid(L('occiput'), 1.3, hx(), s)


@point('BL10', 'back')
def _(s):
    p = up(L('hairline_back'), 0.5, U('head_yb'))
    return at_x_from_mid(p, 1.3, hx(), s)


# ---------------- back: 1.5 cun line ----------------
for _code, _v in [('BL11', 'T1'), ('BL12', 'T2'), ('BL13', 'T3'), ('BL14', 'T4'), ('BL15', 'T5'),
                  ('BL16', 'T6'), ('BL17', 'T7'), ('BL18', 'T9'), ('BL19', 'T10'), ('BL20', 'T11'),
                  ('BL21', 'T12'), ('BL22', 'L1'), ('BL23', 'L2'), ('BL24', 'L3'), ('BL25', 'L4'),
                  ('BL26', 'L5')]:
    point(_code, 'back')(lambda s, v=_v: shu(v, 1.5, s))

# ---------------- sacrum ----------------
for _code, _n in [('BL27', 1), ('BL28', 2), ('BL29', 3), ('BL30', 4)]:
    point(_code, 'back')(lambda s, n=_n: at_x_from_mid(L(f'spine_S{n}'), 1.5, bx(), s))

# 八髎: in the posterior sacral foramina, which converge downward (≈0.9 -> 0.6 cun from the crest)
for _code, _n, _c in [('BL31', 1, 0.9), ('BL32', 2, 0.8), ('BL33', 3, 0.7), ('BL34', 4, 0.6)]:
    point(_code, 'back')(lambda s, n=_n, c=_c: at_x_from_mid(L(f'spine_S{n}'), c, bx(), s))


@point('BL35', 'back')
def _(s):
    return at_x_from_mid(L('coccyx'), 0.5, bx(), s)


# ---------------- thigh / popliteal ----------------
def _bl36(s):
    return L('gluteal_fold', s)


def _bl40(s):
    return L('popliteal', s)


def _thigh_u(s):
    """臀横纹至腘横纹 14寸"""
    return dist(_bl36(s), _bl40(s)) / 14


def _bl39(s):
    return lerp(_bl40(s), L('knee_lat', s), 0.62)


@point('BL36', 'back')
def _(s):
    return _bl36(s)


@point('BL37', 'back')
def _(s):
    return seg(_bl36(s), _bl40(s), 14, 6)


@point('BL38', 'back')
def _(s):
    p = up(_bl39(s), 1, _thigh_u(s))
    return lat(p, -0.15, _thigh_u(s), s)


@point('BL39', 'back')
def _(s):
    return _bl39(s)


@point('BL40', 'back')
def _(s):
    return _bl40(s)


# ---------------- back: 3 cun line ----------------
for _code, _v in [('BL41', 'T2'), ('BL42', 'T3'), ('BL43', 'T4'), ('BL44', 'T5'), ('BL45', 'T6'),
                  ('BL46', 'T7'), ('BL47', 'T9'), ('BL48', 'T10'), ('BL49', 'T11'), ('BL50', 'T12'),
                  ('BL51', 'L1'), ('BL52', 'L2')]:
    point(_code, 'back')(lambda s, v=_v: shu(v, 3, s))


@point('BL53', 'back')
def _(s):
    return at_x_from_mid(L('spine_S2'), 3, bx(), s)


@point('BL54', 'back')
def _(s):
    return at_x_from_mid(L('spine_S4'), 3, bx(), s)


# ---------------- lower leg (back) ----------------
def _achilles(s, y=None):
    """posterior midline of the leg at ankle level (Achilles tendon)"""
    p = mid(L('malleolus_lat', s), L('malleolus_med', s))
    return p if y is None else A([p[0], y])


def _calf(s, cun):
    """point on the posterior midline of the leg, `cun` below the popliteal crease (腘横纹-外踝尖 16寸)"""
    a = _bl40(s); b = _achilles(s, L('malleolus_lat', s)[1])
    return seg(a, b, 16, cun)


@point('BL55', 'back')
def _(s):
    return _calf(s, 2)


@point('BL56', 'back')
def _(s):
    return _calf(s, 5)


@point('BL57', 'back')
def _(s):
    return _calf(s, 8)


@point('BL58', 'back')
def _(s):
    p = _calf(s, 9)          # 外踝尖上7寸
    return lat(p, 1.0, U('leg', s), s)


def _bl60(s):
    ml = L('malleolus_lat', s)
    return lerp(_achilles(s, ml[1]), ml, 0.55)


@point('BL59', 'back')
def _(s):
    y = L('malleolus_lat', s)[1] - 3 * U('leg', s)
    ach = _achilles(s, y)
    ex = _edge_x(y, ach[0], s)
    return A([lerp(ach[0], ex, 0.55), y])


@point('BL60', 'back')
def _(s):
    return _bl60(s)


@point('BL61', 'back')
def _(s):
    p = _bl60(s)
    q = A([p[0], lerp(p[1], L('heel', s)[1], 0.6)])
    return _inside(q, (-_lat_sign(s), 0), 3)


# ---------------- lateral foot border (front view) ----------------
def _foot_edge(s):
    """lateral foot border in the front view: list of (x, y) from below the lateral malleolus
    down to the little-toe tip (the most lateral/lowest foot point)."""
    m = _mask(); sg = _lat_sign(s)
    ml = L('malleolus_lat', s); mm = L('malleolus_med', s)
    cx = mid(ml, mm)[0]
    pts_ = []
    y0 = int(ml[1] + 1.0 * U('leg', s))   # the malleolus landmark sits ~1 cun above the visible tip
    for y in range(y0, m.shape[0]):
        row = m[y]
        xs = np.where(row)[0]
        # restrict to this foot: within 70 px of the ankle centre
        xs = xs[np.abs(xs - cx) < 70]
        if len(xs) == 0:
            break
        x = xs.max() if sg > 0 else xs.min()
        pts_.append(A([float(x), float(y)]))
    # the toe tip = the point furthest along (lateral + down)
    score = [sg * (p[0] - ml[0]) + 0.6 * (p[1] - ml[1]) for p in pts_]
    k = int(np.argmax(score))
    return pts_[:k + 1]


def _along(s, f, inset=4):
    e = _foot_edge(s)
    seglen = [0.0] + [dist(e[i], e[i + 1]) for i in range(len(e) - 1)]
    cum = np.cumsum(seglen); tgt = f * cum[-1]
    i = int(np.searchsorted(cum, tgt))
    i = min(max(i, 1), len(e) - 1)
    t = (tgt - cum[i - 1]) / max(seglen[i], 1e-6)
    p = lerp(e[i - 1], e[i], t)
    return _inside(p, (-_lat_sign(s), -0.3), inset)


@point('BL62', 'front')
def _(s):
    return _along(s, 0.10)


@point('BL63', 'front')
def _(s):
    return _along(s, 0.30)


@point('BL64', 'front')
def _(s):
    return _along(s, 0.50)


@point('BL65', 'front')
def _(s):
    return _along(s, 0.70)


@point('BL66', 'front')
def _(s):
    return _along(s, 0.83)


@point('BL67', 'front')
def _(s):
    return _along(s, 0.97, 3)
