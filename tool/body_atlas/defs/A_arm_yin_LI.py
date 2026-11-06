"""Group A: LU (手太阴肺经), LI (手阳明大肠经), HT (手少阴心经), PC (手厥阴心包经).
Placed from landmarks with 骨度分寸:
  upper arm 腋前/后纹头-肘横纹 9寸 (U('upper_arm')), forearm 肘横纹-腕横纹 12寸 (U('forearm')),
  chest 两乳头间 8寸 (U('chest_x')), 胸骨上窝-胸剑联合 9寸 (U('chest_y')).
View choice: palm / anterior arm / chest / face / neck -> front;
hand dorsum, posterior forearm, lateral arm (LI5-LI14) and top of shoulder (LI16) -> back.
"""
from pts import *
from pts import _lat_sign, _CUR
import numpy as np
import lm


# ---------------- local helpers ----------------
def _mask():
    return lm._mask(_CUR['image'])


def _lat_edge_x(y, s, x_guess):
    """x of the lateral silhouette edge of the arm at row y (scan outward from x_guess)."""
    m = _mask(); y = int(round(y)); x = int(round(x_guess))
    d = int(np.sign(lat(A([0.0, 0.0]), 1, 1, s)[0]))
    while 0 < x < m.shape[1] - 1 and m[y, x]:
        x += d
    return float(x - d)


def _elbow_crease(s, t):
    """point on the elbow crease, t=0 lateral end (radial), t=1 medial end (ulnar)"""
    return lerp(L('elbow_lat', s), L('elbow_med', s), t)


def _wrist_crease(s, t):
    """point on the wrist crease, t=0 radial end, t=1 ulnar end"""
    return lerp(L('wrist_rad', s), L('wrist_uln', s), t)


def _upper_arm(s, cun_below_axilla, frac_from_lat):
    """point on the upper arm: cun_below_axilla below the axillary fold (9 cun to the elbow crease),
    frac_from_lat across the arm from the lateral silhouette edge (0) to the medial edge (1).
    The medial edge is the line axilla -> elbow_med (arm and trunk merge in the mask)."""
    ax = L('axilla', s); em = L('elbow_med', s)
    ec = mid(L('elbow_lat', s), em)
    t = cun_below_axilla / 9.0
    y = lerp(ax, ec, t)[1]
    med_x = lerp(ax, em, t)[0]
    lat_x = _lat_edge_x(y, s, med_x + _lat_sign(s) * 12)
    return A([lerp(lat_x, med_x, frac_from_lat), y])


def _upper_arm_from_elbow(s, cun_above, frac_from_lat):
    return _upper_arm(s, 9.0 - cun_above, frac_from_lat)


def _finger(name, s, t, side_px):
    """point on a finger between its dip (t=0) and tip (t=1), offset side_px toward the radial
    (anatomically lateral) side"""
    a = L(f'hand_{name}_dip', s); b = L(f'hand_{name}_tip', s)
    return perp(lerp(a, b, t), a, b, side_px, s)


def _clav_y(x):
    """clavicle height at image x (between clavicle_mid and acromion of that side)"""
    s = 'R' if (x < L('mid_x')[0]) == (view() == 'front') else 'L'
    a = L('clavicle_mid', s); b = L('acromion', s)
    t = np.clip((x - a[0]) / (b[0] - a[0]), 0, 1)
    return lerp(a, b, t)[1]


# ======================= 手太阴肺经 LU =======================
@point('LU2', 'front')
def _(s):
    p = at_x_from_mid(L('sternal_notch'), 6, U('chest_x'), s)
    return A([p[0], _clav_y(p[0]) + 0.8 * U('chest_y')])


@point('LU1', 'front')
def _(s):
    p = at_x_from_mid(L('sternal_notch'), 6, U('chest_x'), s)
    return A([p[0], _clav_y(p[0]) + 1.8 * U('chest_y')])   # 云门下1寸, 平第1肋间


@point('LU3', 'front')
def _(s):
    return _upper_arm(s, 3, 0.30)


@point('LU4', 'front')
def _(s):
    return _upper_arm(s, 4, 0.30)


def _LU5(s):
    return _elbow_crease(s, 0.33)


def _LU9(s):
    return _wrist_crease(s, 0.15)


@point('LU5', 'front')
def _(s):
    return _LU5(s)


@point('LU6', 'front')
def _(s):
    return seg(_LU9(s), _LU5(s), 12, 7)


@point('LU7', 'front')
def _(s):
    # above the radial styloid, on the radial edge, 1.5 cun above the crease
    return seg(_wrist_crease(s, 0.06), _elbow_crease(s, 0.12), 12, 1.5)


@point('LU8', 'front')
def _(s):
    return seg(_LU9(s), _LU5(s), 12, 1)


@point('LU9', 'front')
def _(s):
    return _LU9(s)


@point('LU10', 'front')
def _(s):
    a = L('hand_thumb_cmc', s); b = L('hand_thumb_mcp', s)
    return perp(mid(a, b), a, b, 6.0, s)


@point('LU11', 'front')
def _(s):
    a = L('hand_thumb_ip', s); b = L('hand_thumb_tip', s)
    return perp(lerp(a, b, 0.8), a, b, 4.0, s)


# ======================= 手阳明大肠经 LI =======================
@point('LI1', 'back')
def _(s):
    return _finger('index', s, 0.7, 3.5)


@point('LI2', 'back')
def _(s):
    a = L('hand_index_mcp', s); b = L('hand_index_pip', s)
    return perp(lerp(a, b, 0.4), a, b, 4.0, s)


@point('LI3', 'back')
def _(s):
    a = L('hand_index_mcp', s); w = _wrist_crease(s, 0.3)
    return perp(lerp(a, w, 0.15), a, w, 5.0, s)


@point('LI4', 'back')
def _(s):
    a = L('hand_index_mcp', s); w = _wrist_crease(s, 0.3)
    base = lerp(w, a, 0.25)                     # base of the 2nd metacarpal
    return perp(mid(base, a), a, w, 7.0, s)


def _LI5(s):
    # anatomical snuffbox: radial end of the dorsal wrist crease
    return toward(_wrist_crease(s, 0.15), L('hand_thumb_cmc', s), 3.0)


def _LI11(s):
    return _elbow_crease(s, 0.12)


@point('LI5', 'back')
def _(s):
    return _LI5(s)


@point('LI6', 'back')
def _(s):
    return seg(_LI5(s), _LI11(s), 12, 3)


@point('LI7', 'back')
def _(s):
    return seg(_LI5(s), _LI11(s), 12, 5)


@point('LI8', 'back')
def _(s):
    return seg(_LI11(s), _LI5(s), 12, 4)


@point('LI9', 'back')
def _(s):
    return seg(_LI11(s), _LI5(s), 12, 3)


@point('LI10', 'back')
def _(s):
    return seg(_LI11(s), _LI5(s), 12, 2)


@point('LI11', 'back')
def _(s):
    return _LI11(s)


@point('LI12', 'back')
def _(s):
    return _upper_arm_from_elbow(s, 1, 0.06)


@point('LI13', 'back')
def _(s):
    return _upper_arm_from_elbow(s, 3, 0.10)


@point('LI14', 'back')
def _(s):
    return _upper_arm_from_elbow(s, 7, 0.12)


@point('LI15', 'front')
def _(s):
    a = L('acromion', s)
    return down(lat(a, -0.25, U('chest_x'), s), 0.9, U('chest_y'))


@point('LI16', 'back')
def _(s):
    a = L('acromion', s)
    return down(lat(a, -1.3, U('back_x'), s), 0.3, U('back_x'))


def _neck_half():
    """half-width of the neck at its narrowest row between chin and throat"""
    m = _mask(); x0 = int(round(L('mid_x')[0])); best = 1e9
    for y in range(int(L('chin')[1]) + 4, int(L('throat')[1]) + 1):
        x = x0
        while m[y, x]:
            x -= 1
        best = min(best, x0 - x)
    return best


@point('LI18', 'front')
def _(s):
    th = L('throat')   # laryngeal prominence level; 3 cun lateral ~ middle of SCM
    return A([L('mid_x')[0] + _lat_sign(s) * 0.62 * _neck_half(), th[1]])


@point('LI17', 'front')
def _(s):
    y = L('throat')[1] + 1.0 * U('chest_y')   # 1 cun below LI18, posterior border of SCM
    return A([L('mid_x')[0] + _lat_sign(s) * 0.80 * _neck_half(), y])


@point('LI19', 'front')
def _(s):
    x = lerp(L('nose_tip')[0], L('ala', s)[0], 0.75)
    y = lerp(L('nose_tip'), L('mouth_R') * 0.5 + L('mouth_L') * 0.5, 0.4)[1]
    return A([x, y])


@point('LI20', 'front')
def _(s):
    return lat(L('ala', s), 0.35, U('head_x'), s)


# ======================= 手少阴心经 HT =======================
@point('HT1', 'front')
def _(s):
    return up(lat(L('axilla', s), 0.3, U('chest_x'), s), 0.3, U('chest_y'))


@point('HT2', 'front')
def _(s):
    return _upper_arm_from_elbow(s, 3, 0.80)


def _HT3(s):
    return _elbow_crease(s, 0.9)


def _HT7(s):
    return _wrist_crease(s, 0.85)


@point('HT3', 'front')
def _(s):
    return _HT3(s)


@point('HT4', 'front')
def _(s):
    return seg(_HT7(s), _HT3(s), 12, 1.5)


@point('HT5', 'front')
def _(s):
    return seg(_HT7(s), _HT3(s), 12, 1)


@point('HT6', 'front')
def _(s):
    return seg(_HT7(s), _HT3(s), 12, 0.5)


@point('HT7', 'front')
def _(s):
    return _HT7(s)


@point('HT8', 'front')
def _(s):
    a = mid(L('hand_ring_mcp', s), L('hand_pinky_mcp', s))
    return lerp(a, _wrist_crease(s, 0.85), 0.3)


@point('HT9', 'front')
def _(s):
    return _finger('pinky', s, 0.7, 3.0)


# ======================= 手厥阴心包经 PC =======================
@point('PC1', 'front')
def _(s):
    return lat(L('nipple', s), 1, U('chest_x'), s)


@point('PC2', 'front')
def _(s):
    return _upper_arm(s, 2, 0.50)


def _PC3(s):
    return _elbow_crease(s, 0.5)


def _PC7(s):
    return _wrist_crease(s, 0.5)


@point('PC3', 'front')
def _(s):
    return _PC3(s)


@point('PC4', 'front')
def _(s):
    return seg(_PC7(s), _PC3(s), 12, 5)


@point('PC5', 'front')
def _(s):
    return seg(_PC7(s), _PC3(s), 12, 3)


@point('PC6', 'front')
def _(s):
    return seg(_PC7(s), _PC3(s), 12, 2)


@point('PC7', 'front')
def _(s):
    return _PC7(s)


@point('PC8', 'front')
def _(s):
    a = lerp(L('hand_index_mcp', s), L('hand_middle_mcp', s), 0.4)
    return lerp(a, _wrist_crease(s, 0.25), 0.3)


@point('PC9', 'front')
def _(s):
    return _finger('middle', s, 0.95, 0)
