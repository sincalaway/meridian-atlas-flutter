"""Group E: 手太阳小肠经 (SI1-SI19), 手少阳三焦经 (TE1-TE23), 督脉 (GV1-GV28).

View choice
  back : hand dorsum / ulnar hand border (SI1-SI5, TE1-TE4), posterior forearm & arm (SI6-SI8, TE5-TE14),
         scapula / upper back (SI9-SI15, TE15), retro-auricular & nape (TE16-TE20),
         spine and posterior scalp (GV1-GV19)
  front: face, pre-auricular, lateral neck (SI16-SI19, TE21-TE23), front scalp & vertex (GV20-GV24), face midline (GV25-GV28)
"""
from pts import *
from pts import _CUR
import numpy as np
import lm

_MASKS = {}


def _mask():
    im = _CUR['image']
    if im not in _MASKS:
        _MASKS[im] = lm._mask(im)
    return _MASKS[im]


def _inside(p, s, margin=2):
    """if p is outside (or within `margin` px of the edge of) the body mask, slide it horizontally
    (nearest direction) until it is `margin` px inside"""
    m = _mask()
    p = A(p, float)

    def ok(q):
        for k in range(-margin, margin + 1):
            x, y = int(round(q[0] + k)), int(round(q[1]))
            if not m[y, x]:
                return False
        return True
    for i in range(0, 40):
        for sg in ((1, -1) if i else (1,)):
            q = p + A([sg * i, 0.0])
            if ok(q):
                return q
    return p


def _edge_x(y, s, start=None):
    """outermost mask x on side s at row y, walking out from the midline (or from `start`)"""
    m = _mask()
    x0 = L('mid_x')[0] if start is None else start
    p = A([x0, float(y)])
    last = p
    for i in range(1, 200):
        q = lat(p, i, 1.0, s)
        if not m[int(round(q[1])), int(round(q[0]))]:
            break
        last = q
    return last


def _unit(v):
    v = A(v, float)
    return v / np.linalg.norm(v)


def _below(a, b):
    """'below the spinous process' depression: between two successive spinous processes"""
    return lerp(L('spine_' + a), L('spine_' + b), 0.5)


# ======================================================================
# hand (back view: dorsum faces the camera; ulnar side = medial)
# ======================================================================
def _ulnar(s):
    """unit vector toward the ulnar border of the hand (away from the ring finger) and half finger width"""
    pm, rm = L('hand_pinky_mcp', s), L('hand_ring_mcp', s)
    u = _unit(pm - rm)
    w = 0.45 * dist(pm, rm)
    return u, w


def _hand_edge_mcp(s):
    """ulnar border of the hand at the level of the 5th MCP joint"""
    u, w = _ulnar(s)
    return L('hand_pinky_mcp', s) + u * w * 1.6


@point('SI1', 'back')
def _(s):
    u, w = _ulnar(s)
    return _inside(lerp(L('hand_pinky_dip', s), L('hand_pinky_tip', s), 0.45) + u * w * 0.9, s, 1)


@point('SI2', 'back')
def _(s):
    u, w = _ulnar(s)
    return _inside(lerp(L('hand_pinky_mcp', s), L('hand_pinky_pip', s), 0.35) + u * w * 1.05, s, 1)


@point('SI3', 'back')
def _(s):
    em, ew = _hand_edge_mcp(s), L('wrist_uln', s)
    return _inside(lerp(em, ew, 0.15), s, 2)


@point('SI4', 'back')
def _(s):
    em, ew = _hand_edge_mcp(s), L('wrist_uln', s)
    return _inside(lerp(ew, em, 0.25), s, 2)


@point('SI5', 'back')
def _(s):
    return _inside(lat(L('wrist_uln', s), -2, 1.0, s), s, 2)


# ======================================================================
# forearm / arm (back view)
# ======================================================================
def _elbow_mid(s):
    return mid(L('elbow_lat', s), L('elbow_med', s))


def _wrist_mid(s):
    return mid(L('wrist_rad', s), L('wrist_uln', s))


def _olecranon(s):
    """elbow tip: pose elbow joint, which in the back view sits on the olecranon"""
    return L('elbow', s)


@point('SI6', 'back')
def _(s):
    # 1 cun above the wrist crease on the ulnar border, radial side of the ulnar styloid
    f = U('forearm', s)
    a = L('wrist_uln', s); b = L('elbow_med', s)
    p = toward(a, b, 1.0 * f)
    return perp(p, a, b, 0.35 * f, s)


@point('SI7', 'back')
def _(s):
    # on the line SI5 -> SI8, 5 cun above the wrist crease
    f = U('forearm', s)
    a = L('wrist_uln', s); b = _si8(s)
    p = toward(a, b, 5.0 * f)
    return perp(p, a, b, 0.25 * f, s)


def _si8(s):
    # between olecranon and medial epicondyle (ulnar groove)
    return lerp(L('elbow_med', s), _olecranon(s), 0.3)


@point('SI8', 'back')
def _(s):
    return _si8(s)


def _te4(s):
    return lerp(L('wrist_uln', s), L('wrist_rad', s), 0.42)


def _te_line(s, cun):
    """point `cun` above the dorsal wrist crease on the line TE4 -> olecranon (between radius and ulna)"""
    a, b = _te4(s), _olecranon(s)
    tot = dist(a, b)
    f = U('forearm', s)
    return toward(a, b, min(cun * f, tot))


@point('TE4', 'back')
def _(s):
    return _te4(s)


@point('TE5', 'back')
def _(s):
    return _te_line(s, 2)


@point('TE6', 'back')
def _(s):
    return _te_line(s, 3)


@point('TE7', 'back')
def _(s):
    # ulnar side of TE6, radial border of the ulna
    f = U('forearm', s)
    return perp(_te_line(s, 3), _te4(s), _olecranon(s), -0.7 * f, s)


@point('TE8', 'back')
def _(s):
    return _te_line(s, 4)


@point('TE9', 'back')
def _(s):
    # 5 cun below the elbow tip
    a, b = _olecranon(s), _te4(s)
    return toward(a, b, 5 * U('forearm', s))


def _arm_up(s, cun):
    """on the line olecranon -> acromion angle, `cun` above the olecranon"""
    a, b = _olecranon(s), L('acromion', s)
    return toward(a, b, cun * U('upper_arm', s))


@point('TE10', 'back')
def _(s):
    return _arm_up(s, 1)


@point('TE11', 'back')
def _(s):
    return _arm_up(s, 2)


@point('TE12', 'back')
def _(s):
    return _arm_up(s, 5)


@point('TE13', 'back')
def _(s):
    # 3 cun below the acromion angle, posterior-inferior border of deltoid
    a, b = L('acromion', s), _olecranon(s)
    p = toward(a, b, 3 * U('upper_arm', s))
    return perp(p, a, b, -0.3 * U('upper_arm', s), s)


@point('TE14', 'back')
def _(s):
    # depression posterior-inferior to the acromion
    p = lat(L('acromion', s), -0.3, U('back_x'), s)
    p = down(p, 1.0, U('back_x'))
    return _inside(p, s, 3)


# ---- hand TE (back view) ----
def _ring_ulnar(s):
    """unit vector from ring finger toward little finger, and half ring-finger width"""
    rm, pm = L('hand_ring_mcp', s), L('hand_pinky_mcp', s)
    return _unit(pm - rm), 0.45 * dist(pm, rm)


@point('TE1', 'back')
def _(s):
    u, w = _ring_ulnar(s)
    return lerp(L('hand_ring_dip', s), L('hand_ring_tip', s), 0.45) + u * w * 0.85


@point('TE2', 'back')
def _(s):
    # web margin between 4th and 5th fingers
    rm, pm = L('hand_ring_mcp', s), L('hand_pinky_mcp', s)
    rp, pp = L('hand_ring_pip', s), L('hand_pinky_pip', s)
    return lerp(mid(rm, pm), mid(rp, pp), 0.3)


@point('TE3', 'back')
def _(s):
    # between 4th and 5th metacarpals, proximal to the 4th MCP joint
    rm, pm = L('hand_ring_mcp', s), L('hand_pinky_mcp', s)
    m = mid(rm, pm)
    return lerp(m, _te4(s), 0.2)


# ======================================================================
# scapula / upper back (back view)
# ======================================================================
def _spine_scap_mid(s):
    return mid(L('scap_med', s), L('acromion', s))


def _post_axillary_fold(s):
    """top of the posterior axillary fold (arm/trunk crease seen from behind); the axilla landmark sits on the arm"""
    return lat(L('axilla', s), -0.85, U('back_x'), s)


def _si10(s):
    # directly above the posterior axillary fold, lower border of the scapular spine
    ax = _post_axillary_fold(s)
    a, b = L('scap_med', s), L('acromion', s)
    t = (ax[0] - a[0]) / (b[0] - a[0])
    y = a[1] + (b[1] - a[1]) * t
    return A([ax[0], y + 0.8 * U('back_x')])


@point('SI9', 'back')
def _(s):
    return up(_post_axillary_fold(s), 1, U('back_x'))


@point('SI10', 'back')
def _(s):
    return _si10(s)


@point('SI11', 'back')
def _(s):
    top = down(_spine_scap_mid(s), 0.3, U('back_x'))
    return lerp(top, L('scap_inf', s), 1 / 3)


@point('SI12', 'back')
def _(s):
    return up(_spine_scap_mid(s), 0.8, U('back_x'))


def _si13(s):
    return mid(_si10(s), L('spine_T2'))


@point('SI13', 'back')
def _(s):
    return _si13(s)


@point('SI14', 'back')
def _(s):
    return at_x_from_mid(_below('T1', 'T2'), 3, U('back_x'), s)


@point('SI15', 'back')
def _(s):
    return at_x_from_mid(_below('C7', 'T1'), 2, U('back_x'), s)


@point('TE15', 'back')
def _(s):
    gb21 = mid(L('c7'), L('acromion', s))
    return mid(gb21, _si13(s))


# ======================================================================
# neck / ear
# ======================================================================
def _ear_back(s):
    """back view: (ear-root x at the ear apex, apex y, lobe y)"""
    span = L('c7')[1] - L('vertex')[1]
    ya = L('mastoid', s)[1] - 0.13 * span
    yl = ya + 0.19 * span
    xr = _edge_x(ya + 3, s)[0] - _lat_sign_(s) * 10
    return xr, ya, yl


def _lat_sign_(s):
    if _CUR['view'] == 'front':
        return -1.0 if s == 'R' else 1.0
    return 1.0 if s == 'R' else -1.0


def _te17(s):
    xr, ya, yl = _ear_back(s)
    return A([xr - _lat_sign_(s) * 2, ya + 0.8 * (yl - ya)])


def _te20(s):
    xr, ya, yl = _ear_back(s)
    return A([xr + _lat_sign_(s) * 1, ya - 4])


def _retro_auricular(s, t):
    """along the helix-shaped line behind the ear from TE17 (t=0) to TE20 (t=1)"""
    a, b = _te17(s), _te20(s)
    p = lerp(a, b, t)
    bulge = np.sin(np.pi * t) * 3      # follows the curve of the helix root, bowing backward (medially here)
    return lat(p, -bulge, 1.0, s)


@point('TE16', 'back')
def _(s):
    # level with the mandibular angle, posterior border of SCM
    y = L('hairline_back')[1] - 2
    e = _edge_x(y, s)
    return lat(e, -6, 1.0, s)


@point('TE17', 'back')
def _(s):
    return _te17(s)


@point('TE18', 'back')
def _(s):
    return _retro_auricular(s, 1 / 3)


@point('TE19', 'back')
def _(s):
    return _retro_auricular(s, 2 / 3)


@point('TE20', 'back')
def _(s):
    return _inside(_te20(s), s, 2)


def _preauricular(s):
    """front view: tragus front, where the ear joins the face"""
    e, z = L('ear', s), L('zygoma', s)
    return A([(e[0] + z[0]) / 2, e[1]])


@point('SI19', 'front')
def _(s):
    return _preauricular(s)


@point('TE21', 'front')
def _(s):
    return up(_preauricular(s), 0.65, U('head_x'))


@point('TE22', 'front')
def _(s):
    p = up(_preauricular(s), 1.6, U('head_x'))
    return lat(p, -1, 1.0, s)


@point('TE23', 'front')
def _(s):
    return lat(L('brow_out', s), 1, 1.0, s)


@point('SI18', 'front')
def _(s):
    return A([L('eye_out', s)[0], L('ala', s)[1] + 2])


@point('SI17', 'front')
def _(s):
    p = down(L('jaw_angle', s), 5, 1.0)
    return _inside(p, s, 2)


@point('SI16', 'front')
def _(s):
    # posterior border of SCM, level with the upper border of the thyroid cartilage
    y = L('throat')[1] - 0.25 * (L('throat')[1] - L('chin')[1])
    e = _edge_x(y, s)
    return lat(e, -5, 1.0, s)


# ======================================================================
# GV - spine (back view)
# ======================================================================
@point('GV1', 'back', mid=True)
def _():
    return down(L('coccyx'), 0.6, U('back_y'))


@point('GV2', 'back', mid=True)
def _():
    return L('sacral_hiatus')


for _code, _a, _b in [('GV3', 'L4', 'L5'), ('GV4', 'L2', 'L3'), ('GV5', 'L1', 'L2'), ('GV6', 'T11', 'T12'),
                      ('GV7', 'T10', 'T11'), ('GV8', 'T9', 'T10'), ('GV9', 'T7', 'T8'), ('GV10', 'T6', 'T7'),
                      ('GV11', 'T5', 'T6'), ('GV12', 'T3', 'T4'), ('GV13', 'T1', 'T2'), ('GV14', 'C7', 'T1')]:
    point(_code, 'back', mid=True)((lambda a, b: (lambda: _below(a, b)))(_a, _b))


# ---- posterior scalp (back view) ----
def _scalp_back(cun):
    """`cun` above the posterior hairline along the midline, GV20 (7 cun) just under the vertex silhouette"""
    yh = L('hairline_back')[1]
    yt = L('vertex')[1] + 6
    return A([L('mid_x')[0], yh - (yh - yt) * cun / 7.0])


@point('GV15', 'back', mid=True)
def _():
    return _scalp_back(0.5)


@point('GV16', 'back', mid=True)
def _():
    return _scalp_back(1.0)


@point('GV17', 'back', mid=True)
def _():
    return _scalp_back(2.5)


@point('GV18', 'back', mid=True)
def _():
    return _scalp_back(4.0)


@point('GV19', 'back', mid=True)
def _():
    return _scalp_back(5.5)


# ---- anterior scalp & face (front view) ----
def _scalp_front(cun):
    """`cun` above the anterior hairline; the top of the head foreshortens, GV20 (5 cun) sits just under the vertex"""
    h = L('hairline_front')
    yt = L('vertex')[1] + 5
    y = h[1] - (h[1] - yt) * (cun / 5.0) ** 0.8
    return A([h[0], y])


@point('GV20', 'front', mid=True)
def _():
    return _scalp_front(5)


@point('GV21', 'front', mid=True)
def _():
    return _scalp_front(3.5)


@point('GV22', 'front', mid=True)
def _():
    return _scalp_front(2)


@point('GV23', 'front', mid=True)
def _():
    return _scalp_front(1)


@point('GV24', 'front', mid=True)
def _():
    return _scalp_front(0.5)


@point('GV24+', 'front', mid=True)   # 印堂: GB/T 12346-2021 归督脉, 两眉毛内侧端中间 (左右攒竹连线中点)
def _():
    return lerp(L('brow_in_R'), L('brow_in_L'), 0.5)


@point('GV25', 'front', mid=True)
def _():
    return up(L('nose_tip'), 1, 1.0)


def _subnasale():
    return lerp(L('nose_tip'), L('philtrum'), 0.35)


@point('GV26', 'front', mid=True)
def _():
    return lerp(_subnasale(), L('philtrum'), 1 / 3)


@point('GV27', 'front', mid=True)
def _():
    return down(L('philtrum'), 2, 1.0)


@point('GV28', 'front', mid=True)
def _():
    # inside the upper lip (frenulum / gum junction): drawn just above the mouth line
    mouth_y = (L('mouth_R')[1] + L('mouth_L')[1]) / 2
    return A([L('philtrum')[0], lerp(L('philtrum')[1] + 2, mouth_y, 0.6)])
