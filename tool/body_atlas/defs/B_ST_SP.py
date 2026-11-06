"""Group B: Stomach (ST1-45) and Spleen (SP1-21) meridians — all on the FRONT view.

Placement uses 骨度分寸 from landmarks:
  head: head_y (眉间-前发际 3寸), head_x (两额角 9寸)
  chest: 两乳头间 8寸 (chest_x) horizontally; intercostal spaces stepped from the nipple (4th ICS)
  abdomen: 胸剑联合-脐 8寸 (abd_up), 脐-耻骨联合上缘 5寸 (abd_lo); lateral via chest_x
  thigh: 耻骨联合上缘-髌底 18寸; leg: 膝中-外踝尖 16寸 (leg), 胫骨内侧髁下缘-内踝尖 13寸
Silhouette edges (medial leg, lateral chest, neck, medial foot) are read from the body mask.
"""
from pts import *
import pts as _pts
import lm as _lm

_MASKS = {}


def _mask():
    im = _pts._CUR['image']
    if im not in _MASKS:
        _MASKS[im] = _lm._mask(im)
    return _MASKS[im]


def _edge_from(p, dx, maxlen=250):
    """walk horizontally from p in image direction dx (+1/-1) until leaving the mask; last inside point"""
    m = _mask()
    x0, y = p[0], int(round(p[1]))
    last = A([x0, p[1]])
    for i in range(1, maxlen):
        x = int(round(x0 + dx * i))
        if x < 0 or x >= m.shape[1] or not m[y, x]:
            break
        last = A([float(x), p[1]])
    return last


def _ls(s):
    """image x direction that is lateral for side s (front view)"""
    return -1.0 if s == 'R' else 1.0


def _lat_edge(p, s, inset):
    e = _edge_from(p, _ls(s))
    return e - A([_ls(s) * inset, 0.0])


def _med_edge(p, s, inset):
    e = _edge_from(p, -_ls(s))
    return e + A([_ls(s) * inset, 0.0])


# ---------------- derived landmarks ----------------
def _cx():
    return U('chest_x')


def _ics(k):
    """y of the k-th intercostal space near the mid-clavicular line (4th ICS = nipple level, male)"""
    ny = (L('nipple', 'R')[1] + L('nipple', 'L')[1]) / 2
    return ny - (4 - k) * 1.5 * U('chest_y')


def _knee_w(s):
    return dist(L('knee_lat', s), L('knee_med', s))


def _patbase_y(s):
    return L('knee', s)[1] - 2.8 * U('thigh', s)


def _patbase_lat(s):
    return A([L('knee', s)[0] + _ls(s) * 0.22 * _knee_w(s), _patbase_y(s)])


def _patbase_med(s):
    return A([L('knee', s)[0] - _ls(s) * 0.22 * _knee_w(s), _patbase_y(s)])


def _u18(s):
    """thigh cun: 耻骨联合上缘 - 髌底 = 18寸"""
    return (_patbase_y(s) - L('pubis')[1]) / 18


def _on_line_above(a, b, y):
    """point on line a->b at height y"""
    t = (y - a[1]) / (b[1] - a[1])
    return lerp(a, b, t)


def _st35(s):
    return A([L('knee', s)[0] + _ls(s) * 0.2 * _knee_w(s), L('knee', s)[1] + 1.1 * U('thigh', s)])


def _ankle_front(s):
    return mid(L('malleolus_lat', s), L('malleolus_med', s)) + A([0.0, 0.6 * U('leg', s)])


def _crest_x(s, y):
    """x of the anterior tibial crest at height y (line from below the tibial tuberosity to ankle front)"""
    top = A([L('knee', s)[0] + _ls(s) * 0.03 * _knee_w(s), L('knee', s)[1] + 2 * U('leg', s)])
    return _on_line_above(top, _ankle_front(s), y)[0]


def _stleg(s, cun_below_st35, cun_lat):
    y = _st35(s)[1] + cun_below_st35 * U('leg', s)
    return A([_crest_x(s, y) + _ls(s) * cun_lat * U('leg', s), y])


def _cond_y(s):
    """lower border of the medial tibial condyle"""
    return L('knee', s)[1] + 2.5 * U('leg', s)


def _umed(s):
    return (L('malleolus_med', s)[1] - _cond_y(s)) / 13


def _leg_center(s, y):
    k, a = L('knee', s), mid(L('malleolus_lat', s), L('malleolus_med', s))
    return _on_line_above(k, a, y)


def _medleg(s, y, inset=3.5):
    return _med_edge(_leg_center(s, y), s, inset)


def _bigtoe(s):
    return L('foot', s)


def _foot_h(s):
    return _bigtoe(s)[1] - L('malleolus_med', s)[1]


def _footmed(s, frac, inset):
    """medial edge of the foot at fraction frac of medial malleolus -> big-toe height"""
    y = L('malleolus_med', s)[1] + frac * _foot_h(s)
    c = A([lerp(_ankle_front(s), _bigtoe(s), frac)[0], y])
    return _med_edge(c, s, inset)


def _toe(s, frac, dy_cun):
    """point across the toe row: frac 0 = medial edge of the foot (big toe), 1 = lateral edge (little toe)"""
    y = _bigtoe(s)[1] - 0.3 * U('leg', s)
    c = A([_bigtoe(s)[0], y])
    med = _edge_from(c, -_ls(s))
    latp = _edge_from(c, _ls(s))
    p = lerp(med, latp, frac)
    return p + A([0.0, dy_cun * U('leg', s)])


def _st44(s):
    # web between 2nd and 3rd toes
    return _toe(s, 0.62, -0.4)


def _neck_half(y):
    p = A([L('mid_x')[0], y])
    a, b = _edge_from(p, -1), _edge_from(p, 1)
    return (b[0] - a[0]) / 2


# ================= STOMACH: face =================
@point('ST1', 'front')
def _(s):
    p = L('pupil', s)
    return A([p[0], L('eye_low', s)[1] + 0.4 * U('head_y')])


@point('ST2', 'front')
def _(s):
    p = L('pupil', s)
    return A([p[0], L('eye_low', s)[1] + 1.15 * U('head_y')])


@point('ST3', 'front')
def _(s):
    return A([L('pupil', s)[0], L('ala', s)[1] + 0.2 * U('head_y')])


@point('ST4', 'front')
def _(s):
    return lat(L('mouth', s), 0.4, U('head_x'), s)


@point('ST5', 'front')
def _(s):
    # mandible lower border, anterior to the masseter (~1.3 cun in front of the angle)
    return lerp(L('jaw_angle', s), L('chin'), 0.28) + A([0, -0.1 * U('head_y')])


@point('ST6', 'front')
def _(s):
    # one finger antero-superior to the mandibular angle
    return lat(up(L('jaw_angle', s), 0.9, U('head_y')), -0.35, U('head_x'), s)


@point('ST7', 'front')
def _(s):
    # below the zygomatic arch, in front of the condyle (just medial to the face contour)
    return lat(down(L('zygoma', s), 0.3, U('head_y')), -0.6, U('head_x'), s)


@point('ST8', 'front')
def _(s):
    # frontal hair corner lies above the lateral brow end, ~1.5 cun below the mid hairline; +0.5 cun up
    x = lat(L('brow_out', s), 0.3, U('head_x'), s)[0]
    return A([x, L('brow_mid', s)[1] - 1.6 * U('head_y')])


# ================= STOMACH: neck =================
def _st9(s):
    y = L('throat')[1]
    return at_x_from_mid(A([0, y]), 1.0, 0.55 * _neck_half(y), s)


@point('ST9', 'front')
def _(s):
    return _st9(s)


def _st11(s):
    y = L('sternal_notch')[1] - 0.25 * U('chest_y')
    return A([_st9(s)[0], y])


@point('ST10', 'front')
def _(s):
    return mid(_st9(s), _st11(s))


@point('ST11', 'front')
def _(s):
    return _st11(s)


# ================= STOMACH: chest (4 cun lateral) =================
@point('ST12', 'front')
def _(s):
    return at_x_from_mid(up(L('clavicle_mid', s), 0.55, U('chest_y')), 4, _cx(), s)


@point('ST13', 'front')
def _(s):
    return at_x_from_mid(down(L('clavicle_mid', s), 0.35, U('chest_y')), 4, _cx(), s)


@point('ST14', 'front')
def _(s):
    return at_x_from_mid(A([0, _ics(1)]), 4, _cx(), s)


@point('ST15', 'front')
def _(s):
    return at_x_from_mid(A([0, _ics(2)]), 4, _cx(), s)


@point('ST16', 'front')
def _(s):
    return at_x_from_mid(A([0, _ics(3)]), 4, _cx(), s)


@point('ST17', 'front')
def _(s):
    return L('nipple', s)


@point('ST18', 'front')
def _(s):
    y = _ics(5)
    if 'female' in _pts._CUR['image']:   # 女性在乳房下皱襞中点
        y += 0.6 * U('chest_y')
    return at_x_from_mid(A([0, y]), 4, _cx(), s)


# ================= STOMACH: abdomen (2 cun lateral) =================
def _abd(s, cun_from_navel, cun_lat):
    """cun_from_navel > 0 = above navel"""
    n = L('navel')
    if cun_from_navel >= 0:
        p = up(n, cun_from_navel, U('abd_up'))
    else:
        p = down(n, -cun_from_navel, U('abd_lo'))
    return at_x_from_mid(p, cun_lat, _cx(), s)


for _code, _c in [('ST19', 6), ('ST20', 5), ('ST21', 4), ('ST22', 3), ('ST23', 2), ('ST24', 1),
                  ('ST25', 0), ('ST26', -1), ('ST27', -2), ('ST28', -3), ('ST29', -4), ('ST30', -5)]:
    point(_code, 'front')(lambda s, c=_c: _abd(s, c, 2))


# ================= STOMACH: thigh =================
def _thigh_line(s, cun_above_patbase):
    a, b = L('asis', s), _patbase_lat(s)
    y = b[1] - cun_above_patbase * _u18(s)
    return _on_line_above(a, b, y)


@point('ST31', 'front')
def _(s):
    return _thigh_line(s, 12)


@point('ST32', 'front')
def _(s):
    return _thigh_line(s, 6)


@point('ST33', 'front')
def _(s):
    return _thigh_line(s, 3)


@point('ST34', 'front')
def _(s):
    return _thigh_line(s, 2)


# ================= STOMACH: leg =================
@point('ST35', 'front')
def _(s):
    return _st35(s)


@point('ST36', 'front')
def _(s):
    return _stleg(s, 3, 1)


@point('ST37', 'front')
def _(s):
    return _stleg(s, 6, 1)


@point('ST38', 'front')
def _(s):
    return _stleg(s, 8, 1)


@point('ST39', 'front')
def _(s):
    return _stleg(s, 9, 1)


@point('ST40', 'front')
def _(s):
    return _stleg(s, 8, 2)


# ================= STOMACH: foot =================
@point('ST41', 'front')
def _(s):
    return _ankle_front(s)


@point('ST42', 'front')
def _(s):
    return lerp(_ankle_front(s), _st44(s), 0.3)


@point('ST43', 'front')
def _(s):
    return lerp(_ankle_front(s), _st44(s), 0.72)


@point('ST44', 'front')
def _(s):
    return _st44(s)


@point('ST45', 'front')
def _(s):
    # lateral nail corner of the 2nd toe
    return _toe(s, 0.59, 0.35)


# ================= SPLEEN: foot =================
@point('SP1', 'front')
def _(s):
    return _toe(s, 0.08, 0.1)


@point('SP2', 'front')
def _(s):
    return _footmed(s, 0.86, 3.5)


@point('SP3', 'front')
def _(s):
    return _footmed(s, 0.74, 3.5)


@point('SP4', 'front')
def _(s):
    return _footmed(s, 0.52, 3.5)


@point('SP5', 'front')
def _(s):
    m = L('malleolus_med', s)
    return lat(down(m, 0.9, U('leg', s)), 0.4, U('leg', s), s)


# ================= SPLEEN: leg (medial border of tibia) =================
@point('SP6', 'front')
def _(s):
    return _medleg(s, L('malleolus_med', s)[1] - 3 * _umed(s))


@point('SP7', 'front')
def _(s):
    return _medleg(s, L('malleolus_med', s)[1] - 6 * _umed(s))


@point('SP8', 'front')
def _(s):
    return _medleg(s, _cond_y(s) + 3 * _umed(s))


@point('SP9', 'front')
def _(s):
    return _medleg(s, _cond_y(s), 4)


# ================= SPLEEN: thigh =================
def _sp10(s):
    b = _patbase_med(s)
    y = b[1] - 2 * _u18(s)
    e = _med_edge(A([b[0], y]), s, 0)
    return A([lerp(b, e, 0.55)[0], y])


@point('SP10', 'front')
def _(s):
    return _sp10(s)


def _sp12(s):
    return at_x_from_mid(L('pubis'), 3.5, _cx(), s)


@point('SP11', 'front')
def _(s):
    # upper 1/3 of the line 冲门 -> medial patella base; sits between sartorius and adductor longus,
    # i.e. on the antero-medial thigh, so nudge 0.5 cun medially off the straight line
    return lat(lerp(_sp12(s), _patbase_med(s), 1 / 3), -0.5, _cx(), s)


@point('SP12', 'front')
def _(s):
    return _sp12(s)


# ================= SPLEEN: abdomen (4 cun lateral) =================
for _code, _c in [('SP13', -4.3), ('SP14', -1.3), ('SP15', 0), ('SP16', 3)]:
    point(_code, 'front')(lambda s, c=_c: _abd(s, c, 4))


# ================= SPLEEN: chest (6 cun lateral) =================
def _torso_half(s, y):
    """distance from midline to the lateral trunk silhouette on side s at height y.
    Above the level where arm and trunk separate, extrapolate from the first separated row."""
    mx = L('mid_x')[0]
    nip_off = abs(L('nipple', s)[0] - mx)
    y0 = int(round(L('nipple', s)[1]))
    for yy in range(y0, y0 + 200):
        d = abs(_edge_from(A([mx, float(yy)]), _ls(s))[0] - mx)
        if d < 1.6 * nip_off:
            break
    if y >= yy:
        d = abs(_edge_from(A([mx, y]), _ls(s))[0] - mx)
        return d
    return d + 0.1 * (yy - y)


def _sp_chest(s, k):
    y = _ics(k)
    d = min(6 * _cx(), _torso_half(s, y) - 0.5 * _cx())
    return A([L('mid_x')[0] + _ls(s) * d, y])


for _code, _k in [('SP17', 5), ('SP18', 4), ('SP19', 3), ('SP20', 2)]:
    point(_code, 'front')(lambda s, k=_k: _sp_chest(s, k))


@point('SP21', 'front')
def _(s):
    y = _ics(6)
    d = _torso_half(s, y) - 0.25 * _cx()
    return A([L('mid_x')[0] + _ls(s) * d, y])
