"""Group D: Kidney (KI1-27), Liver (LR1-14), Conception Vessel (CV1-24).
Placed with 骨度分寸 from landmarks; limb/foot points use the body-mask silhouette at a given height.
"""
from pts import *
import pts as _P
import lm as _lm
import numpy as np

_MASKS = {}


def _mask():
    im = _P._CUR['image']
    if im not in _MASKS:
        _MASKS[im] = _lm._mask(im)
    return _MASKS[im]


def _inside(x, y):
    m = _mask()
    x, y = int(round(x)), int(round(y))
    return 0 <= y < m.shape[0] and 0 <= x < m.shape[1] and m[y, x]


def _scan(x0, y, dx, maxlen=200):
    """walk horizontally from x0 in direction dx (+1/-1) until leaving the mask; last inside x"""
    m = _mask(); y = int(round(y)); x = int(round(x0))
    last = x
    for i in range(1, maxlen):
        xx = x + dx * i
        if xx < 0 or xx >= m.shape[1] or not m[y, xx]:
            break
        last = xx
    return float(last)


def _medsign(s):
    """image x direction that is MEDIAL for side s"""
    return -_P._lat_sign(s)


def _axis_x(s, y):
    """x of the limb axis (hip-knee-ankle) at height y"""
    pts_ = [L('hip', s), L('knee', s), L('ankle', s)]
    ys = [p[1] for p in pts_]; xs = [p[0] for p in pts_]
    return float(np.interp(y, ys, xs))


def _limb(s, y, f):
    """point on the leg cross-section at height y: f=0 medial edge, f=1 lateral edge"""
    ax = _axis_x(s, y)
    ms = _medsign(s)
    xm = _scan(ax, y, int(ms))
    xl = _scan(ax, y, int(-ms))
    return A([xm + (xl - xm) * f, y])


def _limb_edges(s, y):
    ax = _axis_x(s, y)
    ms = _medsign(s)
    return _scan(ax, y, int(ms)), _scan(ax, y, int(-ms))


def _ank_pt(s, dy_cun, f):
    """back/front ankle region: medial edge at height mall+dy_cun, moved inward by f * ankle width
    (ankle width measured at the malleolus level, so the spreading heel/foot does not distort it)"""
    m0 = _mall(s)
    xm0, xl0 = _limb_edges(s, m0[1])
    w = abs(xl0 - xm0)
    y = m0[1] + dy_cun * _cun_leg(s)
    xm, xl = _limb_edges(s, y)
    return A([xm - _medsign(s) * f * w, y])


def _cun_leg(s):
    return U('leg', s)


def _mall(s):
    return L('malleolus_med', s)


# ---------------- front-view foot frame ----------------
def _foot_front(s):
    """returns (medial edge x at forefoot, forefoot width, toe bottom y, medial sign)"""
    m = _mask()
    ax = L('ankle', s)[0]
    x0, x1 = int(ax - 70), int(ax + 70)
    yb = None
    for y in range(int(L('ankle', s)[1]), m.shape[0]):
        if m[y, x0:x1].any():
            yb = y
    yr = yb - 5   # row through the toes
    xs = np.where(m[yr, x0:x1])[0] + x0
    ms = _medsign(s)
    xm = float(xs.max() if ms > 0 else xs.min())
    W = float(xs.max() - xs.min())
    return xm, W, float(yb), ms


def _foot_pt(s, fx, fy):
    """fx: fraction of forefoot width from the medial edge; fy: fraction of width above toe bottom"""
    xm, W, yb, ms = _foot_front(s)
    return A([xm - ms * fx * W, yb - fy * W])


# ---------------- chest intercostal levels ----------------
def _chest_c():
    """cun scale on the sternum chosen so the 4th ICS falls at nipple level (ICS4 = 6.8 cun below notch)"""
    ny = (L('nipple', 'R')[1] + L('nipple', 'L')[1]) / 2
    return (ny - L('sternal_notch')[1]) / 6.8


def _ics(k):
    """y of the k-th intercostal space: 2 cun below the notch for ICS1, then 1.6 cun each"""
    return L('sternal_notch')[1] + _chest_c() * (2.0 + 1.6 * (k - 1))


def _ycol(y):
    return A([L('mid_x')[0], y])


# ====================== KIDNEY ======================
@point('KI1', 'back')
def _(s):
    # sole: only the plantar edge of the forefoot is visible (back view, toes point outward)
    m = _mask()
    an = L('ankle', s)
    ls = int(_P._lat_sign(s))
    x0, x1 = int(an[0] - 80), int(an[0] + 80)
    # heel bottom
    col = np.where(m[:, int(an[0])])[0]
    heel = A([an[0], float(col.max())])
    # lateral-most toe point
    best = None
    for y in range(int(an[1] + 15), int(heel[1])):
        xs = np.where(m[y, x0:x1])[0] + x0
        if len(xs) == 0:
            continue
        x = xs.max() if ls > 0 else xs.min()
        if best is None or (x - best[0]) * ls > 0:
            best = A([float(x), float(y)])
    x = heel[0] + (best[0] - heel[0]) * 0.6
    ys = np.where(m[:, int(round(x))])[0]
    ys = ys[ys > an[1]]
    return A([x, float(ys.max()) - 3])


@point('KI2', 'front')
def _(s):
    return _ank_pt(s, 2.4, 0.1)


@point('KI3', 'back')
def _(s):
    return _ank_pt(s, 0, 0.22)


@point('KI4', 'back')
def _(s):
    return _ank_pt(s, 0.6, 0.3)


@point('KI5', 'back')
def _(s):
    return _ank_pt(s, 1.0, 0.2)


@point('KI6', 'front')
def _(s):
    return _ank_pt(s, 1.0, 0.05)


@point('KI7', 'back')
def _(s):
    y = _mall(s)[1] - 2.0 * _cun_leg(s)
    xm, xl = _limb_edges(s, y)
    return A([xm + (xl - xm) * 0.22, y])


@point('KI8', 'front')
def _(s):
    y = _mall(s)[1] - 2.0 * _cun_leg(s)
    xm, xl = _limb_edges(s, y)
    return A([xm + (xl - xm) * 0.08, y])


@point('KI9', 'back')
def _(s):
    y = _mall(s)[1] - 5.0 * _cun_leg(s)
    xm, xl = _limb_edges(s, y)
    return A([xm + (xl - xm) * 0.22, y])


@point('KI10', 'back')
def _(s):
    y = L('popliteal', s)[1]
    xm, xl = _limb_edges(s, y)
    return A([xm + (xl - xm) * 0.18, y])


def _abd_ki(s, cun_from_navel):
    """0.5 cun lateral of midline; cun_from_navel >0 = above"""
    n = L('navel')
    if cun_from_navel >= 0:
        y = n[1] - cun_from_navel * U('abd_up')
    else:
        y = n[1] - cun_from_navel * U('abd_lo')
    return at_x_from_mid(A([0, y]), 0.5, U('chest_x'), s)


for _code, _c in [('KI11', -5), ('KI12', -4), ('KI13', -3), ('KI14', -2), ('KI15', -1), ('KI16', 0),
                  ('KI17', 2), ('KI18', 3), ('KI19', 4), ('KI20', 5), ('KI21', 6)]:
    point(_code, 'front')(lambda s, _c=_c: _abd_ki(s, _c))


@point('KI27', 'front')
def _(s):
    # just below the clavicle (between clavicle and 1st rib)
    return at_x_from_mid(A([0, L('sternal_notch')[1] + 0.9 * _chest_c()]), 2, U('chest_x'), s)


for _code, _k in [('KI26', 1), ('KI25', 2), ('KI24', 3), ('KI23', 4), ('KI22', 5)]:
    point(_code, 'front')(lambda s, _k=_k: at_x_from_mid(A([0, _ics(_k)]), 2, U('chest_x'), s))


# ====================== LIVER ======================
@point('LR1', 'front')
def _(s):
    return _foot_pt(s, 0.47, 0.30)


@point('LR2', 'front')
def _(s):
    return _foot_pt(s, 0.55, 0.47)


@point('LR3', 'front')
def _(s):
    return _foot_pt(s, 0.47, 0.80)


@point('LR4', 'front')
def _(s):
    return _ank_pt(s, 0.3, 0.3)


@point('LR5', 'front')
def _(s):
    y = _mall(s)[1] - 5 * _cun_leg(s)
    xm, xl = _limb_edges(s, y)
    return A([xm + (xl - xm) * 0.22, y])


@point('LR6', 'front')
def _(s):
    y = _mall(s)[1] - 7 * _cun_leg(s)
    xm, xl = _limb_edges(s, y)
    return A([xm + (xl - xm) * 0.20, y])


@point('LR7', 'front')
def _(s):
    # below medial tibial condyle, 1 cun posterior to SP9 -> close to the medial silhouette
    y = L('knee', s)[1] + 2.3 * _cun_leg(s)
    xm, xl = _limb_edges(s, y)
    return A([xm + (xl - xm) * 0.05, y])


@point('LR8', 'front')
def _(s):
    y = L('knee', s)[1] + 0.2 * _cun_leg(s)
    xm, xl = _limb_edges(s, y)
    return A([xm + (xl - xm) * 0.06, y])


@point('LR9', 'front')
def _(s):
    # 4 cun above the patellar base (base ~1.5 cun above knee centre)
    y = L('knee', s)[1] - 5.5 * U('thigh', s)
    xm, xl = _limb_edges(s, y)
    return A([xm + (xl - xm) * 0.14, y])


def _st30(s):
    return at_x_from_mid(L('pubis'), 2, U('chest_x'), s)


@point('LR10', 'front')
def _(s):
    return down(_st30(s), 3, U('thigh', s))


@point('LR11', 'front')
def _(s):
    return down(_st30(s), 2, U('thigh', s))


@point('LR12', 'front')
def _(s):
    return at_x_from_mid(L('pubis'), 2.5, U('chest_x'), s)


@point('LR13', 'front')
def _(s):
    # free end of 11th rib: lateral abdomen, ~2 cun above navel level, just inside the trunk silhouette
    y = L('navel')[1] - 2.0 * U('abd_up')
    xe = _scan(L('mid_x')[0], y, int(_P._lat_sign(s)), 300)
    return A([xe - _P._lat_sign(s) * 0.06 * L('_SW')[0], y])


@point('LR14', 'front')
def _(s):
    return A([L('nipple', s)[0], _ics(6)])


# ====================== CONCEPTION VESSEL ======================
@point('CV1', 'back', mid=True)
def _():
    # perineum: apex of the crotch between the buttocks, seen from behind (~0.4 of coccyx -> gluteal fold;
    # the body mask is unreliable in the dark gap between the thighs)
    gy = (L('gluteal_fold', 'R')[1] + L('gluteal_fold', 'L')[1]) / 2
    return A([L('mid_x')[0], L('coccyx')[1] + 0.40 * (gy - L('coccyx')[1])])


@point('CV2', 'front', mid=True)
def _():
    return _ycol(L('pubis')[1])


for _code, _c in [('CV3', 4), ('CV4', 3), ('CV5', 2), ('CV6', 1.5), ('CV7', 1)]:
    point(_code, 'front', mid=True)(lambda _c=_c: _ycol(L('navel')[1] + _c * U('abd_lo')))


@point('CV8', 'front', mid=True)
def _():
    return _ycol(L('navel')[1])


for _code, _c in [('CV9', 1), ('CV10', 2), ('CV11', 3), ('CV12', 4), ('CV13', 5), ('CV14', 6), ('CV15', 7)]:
    point(_code, 'front', mid=True)(lambda _c=_c: _ycol(L('navel')[1] - _c * U('abd_up')))


@point('CV16', 'front', mid=True)
def _():
    return _ycol(L('xiphoid')[1])


@point('CV17', 'front', mid=True)
def _():
    return _ycol((L('nipple', 'R')[1] + L('nipple', 'L')[1]) / 2)


for _code, _k in [('CV18', 3), ('CV19', 2), ('CV20', 1)]:
    point(_code, 'front', mid=True)(lambda _k=_k: _ycol(_ics(_k)))


@point('CV21', 'front', mid=True)
def _():
    return _ycol(L('sternal_notch')[1] + 1.0 * _chest_c())


@point('CV22', 'front', mid=True)
def _():
    return _ycol(L('sternal_notch')[1])


@point('CV23', 'front', mid=True)
def _():
    c, t = L('chin'), L('throat')
    return A([L('mid_x')[0], c[1] + (t[1] - c[1]) * 0.45])


@point('CV24', 'front', mid=True)
def _():
    lg, c = L('lip_lower_groove'), L('chin')
    return lerp(lg, c, 0.25)
