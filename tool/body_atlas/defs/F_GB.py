"""Gallbladder meridian (足少阳胆经) GB1-GB44, placed with 骨度分寸 from landmarks.
Lateral head / trunk / thigh / leg points are put just inside the silhouette edge of the view that
shows them best (edge found by walking the body mask)."""
import numpy as np
from pts import *
from pts import _CUR, _lat_sign
import lm

_MASKS = {}


def _mask():
    im = _CUR['image']
    if im not in _MASKS:
        _MASKS[im] = lm._mask(im)
    return _MASKS[im]


def edge_x(y, s, x_start):
    """x of the last mask pixel walking laterally (side s) from x_start on row y"""
    m = _mask(); y = int(round(y)); sg = _lat_sign(s)
    x = int(round(x_start))
    last = x
    for i in range(1, 400):
        xx = x + int(sg * i)
        if xx < 0 or xx >= m.shape[1] or not m[y, xx]:
            break
        last = xx
    return float(last)


def inside_edge(y, s, x_start, inset):
    """point on row y, `inset` px medial of the lateral silhouette edge"""
    return A([edge_x(y, s, x_start) - _lat_sign(s) * inset, float(y)])


def bez(a, c, b, t):
    """quadratic bezier a -> b with control c (arc lines on the head)"""
    return (1 - t) ** 2 * a + 2 * (1 - t) * t * c + t ** 2 * b


# ---------------- head unit helpers ----------------
def hy():           # front head: px per cun (眉间-前发际 3寸)
    return U('head_y')


def hxb():          # back head: px per cun (两乳突 9寸)
    return U('head_xb')


# ---------------- face / temporal (front view) ----------------
@point('GB1', 'front')        # 瞳子髎: 目外眦旁0.5寸
def _(s):
    return lat(L('eye_out', s), 0.7, hy(), s)   # 0.5寸 + orbital rim; 0.5 cun alone landed on the canthus


def _ear_apex_y():
    # ear apex (耳尖) sits at about the outer-canthus height on these figures (checked visually)
    return (L('eye_out', 'R')[1] + L('eye_out', 'L')[1]) / 2 + 0.5


def _sideburn(s):
    """GB7 曲鬓: sideburn posterior-edge vertical x ear-apex horizontal; just in front of the ear root,
    the sideburn lies ~3 px lateral of the temple landmark (face edge)"""
    return A([lat(L('temple', s), 3, 1.0, s)[0], _ear_apex_y()])


def _st8(s):
    """头维 ST8: 额角发际上0.5寸, 正中线旁开4.5寸"""
    x = at_x_from_mid(L('hairline_front'), 4.5, U('head_x'), s)[0]
    y = L('hairline_front')[1] + 0.9 * hy()   # frontal angle hairline sits lower than midline hairline
    p = A([x, y])
    return inside_edge(y, s, L('mid_x')[0], 3) if abs(edge_x(y, s, L('mid_x')[0]) - x) < 3 else p


def _temporal(s, t):
    a, b = _st8(s), _sideburn(s)
    c = lat(mid(a, b), 0.15, hy(), s)     # slight lateral bow over the temporal scalp
    p = bez(a, c, b, t)
    ex = edge_x(p[1], s, L('mid_x')[0])
    # keep clearly inside the silhouette (率谷 GB8 owns the very edge above the ear)
    if (p[0] - ex) * _lat_sign(s) > -7:
        p[0] = ex - _lat_sign(s) * 7
    return p


@point('GB2', 'front')        # 听会: 耳屏间切迹前, 下颌髁突后缘 -> in front of ear, tragus-notch level
def _(s):
    z = L('zygoma', s)     # zygoma landmark = face edge just in front of the ear
    return A([lat(z, -2, 1.0, s)[0], z[1] + 0.6 * hy()])


@point('GB3', 'front')        # 上关: 颧弓中点上缘凹陷, ST7直上
def _(s):
    z = L('zygoma', s)
    return A([lat(z, -3, 1.0, s)[0], z[1] - 0.5 * hy()])


@point('GB4', 'front')        # 颔厌: 头维-曲鬓弧线上1/4
def _(s):
    return _temporal(s, 0.25)


@point('GB5', 'front')        # 悬颅: 中点
def _(s):
    return _temporal(s, 0.5)


@point('GB6', 'front')        # 悬厘: 下1/4
def _(s):
    return _temporal(s, 0.75)


@point('GB7', 'front')        # 曲鬓
def _(s):
    return _sideburn(s)


@point('GB8', 'front')        # 率谷: 耳尖直上入发际1.5寸 (side of head, near silhouette edge)
def _(s):
    y = _ear_apex_y() - 1.6 * hy()
    return inside_edge(y, s, L('mid_x')[0], 1.5)


# ---------------- behind the ear / occiput (back view) ----------------
def _ear_top_y_back():
    # ear apex ~ 1.6 cun (mastoid-scale) above mastoid landmark
    return (L('mastoid', 'R')[1] + L('mastoid', 'L')[1]) / 2 - 3.9 * hxb()


def _gb9(s):
    y = _ear_top_y_back() - 2.0 * hxb()
    return inside_edge(y, s, L('mid_x')[0], 4)


def _gb12(s):
    # 完骨: 乳突后下方凹陷 -> just medial and inferior to the mastoid landmark
    p = L('mastoid', s)
    return down(lat(p, 0.8, hxb(), s), 0.9, hxb())


def _behind_ear(s, t):
    a, b = _gb9(s), _gb12(s)
    c = lat(mid(a, b), 0.6, hxb(), s)     # arc around the back of the auricle
    p = bez(a, c, b, t)
    ex = edge_x(p[1], s, L('mid_x')[0])
    if (p[0] - ex) * _lat_sign(s) > -3:
        p[0] = ex - _lat_sign(s) * 3
    return p


@point('GB9', 'back')         # 天冲: 耳根后缘直上入发际2寸
def _(s):
    return _gb9(s)


@point('GB10', 'back')        # 浮白: 天冲-完骨弧线上1/3
def _(s):
    return _behind_ear(s, 1 / 3)


@point('GB11', 'back')        # 头窍阴: 上2/3
def _(s):
    return _behind_ear(s, 2 / 3)


@point('GB12', 'back')        # 完骨
def _(s):
    return _gb12(s)


# ---------------- forehead / vertex lines (front view) ----------------
def _scalp_y(n_cun):
    """y of a point n_cun behind the front hairline (projected; skull curves away toward vertex).
    front hairline -> 百会 = 5 cun, 百会 ~ top of the silhouette."""
    h = L('hairline_front')[1]; v = L('vertex')[1] + 0.6 * hy()   # scalp top under the hair
    return h - (h - v) * np.sin(min(n_cun, 5) / 5 * np.pi / 2)


def _pupil_line(s, n_cun):
    y = _scalp_y(n_cun)
    p = A([L('pupil', s)[0], y])
    # head narrows toward vertex: scale lateral offset with silhouette half-width
    mx = L('mid_x')[0]
    w_here = abs(edge_x(y, s, mx) - mx)
    w_ref = abs(edge_x(L('hairline_front')[1], s, mx) - mx)
    p[0] = mx + (p[0] - mx) * max(0.6, min(1.0, w_here / w_ref))
    return p


@point('GB13', 'front')       # 本神: 前发际上0.5寸, 旁开3寸
def _(s):
    x = at_x_from_mid(L('hairline_front'), 3, U('head_x'), s)[0]
    return A([x, _scalp_y(0.5)])


@point('GB14', 'front')       # 阳白: 瞳孔直上, 眉上1寸
def _(s):
    return A([L('pupil', s)[0], L('brow_mid', s)[1] - 1.0 * hy()])


@point('GB15', 'front')       # 头临泣: 前发际上0.5寸, 瞳孔直上
def _(s):
    p = _pupil_line(s, 0.5)
    return p


@point('GB16', 'front')       # 目窗: 前发际上1.5寸
def _(s):
    return _pupil_line(s, 1.5)


@point('GB17', 'front')       # 正营: 前发际上2.5寸
def _(s):
    return _pupil_line(s, 2.5)


@point('GB18', 'front')       # 承灵: 前发际上4寸
def _(s):
    return _pupil_line(s, 4.0)


def _gb20(s):
    # 风池: 横平风府(后发际上1寸), 胸锁乳突肌与斜方肌之间 -> ~0.55 of the way midline->mastoid
    y = L('hairline_back')[1] - 1.0 * U('head_yb')
    x = lerp(L('mid_x'), L('mastoid', s), 0.6)[0]
    return A([x, y])


@point('GB19', 'back')        # 脑空: 横平枕外隆凸上缘(脑户), 风池直上
def _(s):
    y = L('hairline_back')[1] - 2.5 * U('head_yb')
    return A([_gb20(s)[0], y])


@point('GB20', 'back')        # 风池
def _(s):
    return _gb20(s)


# ---------------- shoulder / trunk ----------------
@point('GB21', 'back')        # 肩井: 大椎(C7下)与肩峰端连线中点
def _(s):
    # midpoint of the C7-acromion chord, lifted onto the trapezius ridge (top of shoulder):
    # walk up to the silhouette top at that x and sit a few px below it
    p = mid(L('c7'), L('acromion', s))
    m = _mask(); x = int(round(p[0])); y = int(round(p[1]))
    while y > 0 and m[y - 1, x]:
        y -= 1
    return A([p[0], max(float(y) + 5, min(p[1], float(y) + 5))])


def _trunk_edge(y, s, inset):
    """lateral trunk edge on row y. Below the armpit the mask merges arm and trunk for a while,
    so above the first row where they separate, interpolate axilla -> first separated trunk edge."""
    m = _mask(); mx = int(L('mid_x')[0]); sg = _lat_sign(s)
    ax = L('axilla', s)
    y0 = int(ax[1]) + 2
    sep = None
    for yy in range(y0, y0 + 250):
        x = mx; first_out = None
        for i in range(1, 400):
            xx = mx + int(sg * i)
            if not m[yy, xx]:
                first_out = xx; break
        if first_out is None:
            continue
        # separated if mask resumes (the arm) further out
        rest = m[yy, first_out::int(sg)] if sg > 0 else m[yy, first_out::-1]
        if rest[:120].any():
            sep = (yy, first_out - sg)
            break
    if sep is None or y >= sep[0]:
        return inside_edge(y, s, mx, inset)
    t = (y - ax[1]) / (sep[0] - ax[1])
    x = ax[0] + (sep[1] - ax[0]) * t
    return A([x - sg * inset, float(y)])


@point('GB22', 'front')       # 渊腋: 腋中线, 第4肋间隙 (male: nipple level)
def _(s):
    y = L('sternal_notch')[1] + 6.8 * U('chest_y')     # 4th ICS (膻中 level)
    return _trunk_edge(y, s, 0.25 * U('chest_x'))


@point('GB23', 'front')       # 辄筋: 渊腋前1寸, 第4肋间隙
def _(s):
    y = L('sternal_notch')[1] + 6.8 * U('chest_y')
    return lat(_trunk_edge(y, s, 0.25 * U('chest_x')), -1.0, U('chest_x'), s)


@point('GB24', 'front')       # 日月: 乳头直下, 第7肋间隙, 前正中线旁开4寸
def _(s):
    y = L('sternal_notch')[1] + 11.6 * U('chest_y')    # 4th ICS 6.8 cun + 3 x 1.6 cun
    return at_x_from_mid(A([0, y]), 4, U('chest_x'), s)


@point('GB25', 'back')        # 京门: 第12肋游离端下际 (posterolateral flank, ~L2 level)
def _(s):
    y = L('spine_L2')[1] + 0.3 * (L('spine_L3')[1] - L('spine_L2')[1])
    return inside_edge(y, s, L('mid_x')[0], 0.5 * U('back_x'))


@point('GB26', 'front')       # 带脉: 第11肋游离端直下与脐水平线交点 (lateral abdomen)
def _(s):
    y = L('navel')[1]
    return _trunk_edge(y, s, 0.6 * U('chest_x'))


@point('GB27', 'front')       # 五枢: 脐下3寸, 髂前上棘内侧
def _(s):
    y = L('navel')[1] + 3 * U('abd_lo')
    return A([lat(L('asis', s), -0.3, U('chest_x'), s)[0], y])


@point('GB28', 'front')       # 维道: 五枢内下0.5寸
def _(s):
    y = L('navel')[1] + 3.5 * U('abd_lo')
    return A([lat(L('asis', s), -0.8, U('chest_x'), s)[0], y])


@point('GB29', 'front')       # 居髎: 髂前上棘与股骨大转子连线中点
def _(s):
    return mid(L('asis', s), L('trochanter', s))


@point('GB30', 'back')        # 环跳: 大转子高点与骶管裂孔连线外1/3
def _(s):
    return lerp(L('trochanter', s), L('sacral_hiatus'), 1 / 3)


# ---------------- thigh / knee (front view, lateral edge) ----------------
def _thigh_edge(s, cun_above_knee, inset_cun=0.5):
    y = L('knee', s)[1] - cun_above_knee * U('thigh', s)
    xs = lerp(L('trochanter', s), L('knee', s), 0.7)[0]
    xs = lerp(A([xs, 0]), L('knee', s), 0.0)[0]
    return inside_edge(y, s, L('knee', s)[0], inset_cun * U('thigh', s))


@point('GB31', 'front')       # 风市: 大腿外侧正中, 腘横纹上7寸
def _(s):
    return _thigh_edge(s, 7, 0.45)


@point('GB32', 'front')       # 中渎: 腘横纹上5寸, 髂胫束后缘 (WHO 5寸; task text repeats 7寸)
def _(s):
    return _thigh_edge(s, 5, 0.45)


def _gb34(s):
    # 阳陵泉: 腓骨头前下方凹陷 ~ 膝中下2寸, slightly in from lateral edge
    y = L('knee', s)[1] + 2.0 * U('leg', s)
    return inside_edge(y, s, L('knee', s)[0], 0.8 * U('leg', s))


@point('GB33', 'front')       # 膝阳关: 阳陵泉上3寸, 股骨外上髁上方凹陷
def _(s):
    y = _gb34(s)[1] - 3 * U('leg', s)
    return inside_edge(y, s, L('knee', s)[0], 0.4 * U('leg', s))


@point('GB34', 'front')       # 阳陵泉
def _(s):
    return _gb34(s)


# ---------------- lower leg ----------------
def _leg_pt(s, cun_above_mall, inset_cun):
    y = L('malleolus_lat', s)[1] - cun_above_mall * U('leg', s)
    xs = lerp(L('knee', s), L('ankle', s), 0.5)[0]
    return inside_edge(y, s, xs, inset_cun * U('leg', s))


@point('GB35', 'back')        # 阳交: 外踝尖上7寸, 腓骨后缘
def _(s):
    return _leg_pt(s, 7, 0.45)


@point('GB36', 'front')       # 外丘: 外踝尖上7寸, 腓骨前缘
def _(s):
    return _leg_pt(s, 7, 0.75)


@point('GB37', 'front')       # 光明: 外踝尖上5寸, 腓骨前缘
def _(s):
    return _leg_pt(s, 5, 0.75)


@point('GB38', 'front')       # 阳辅: 外踝尖上4寸, 腓骨前缘
def _(s):
    return _leg_pt(s, 4, 0.7)


@point('GB39', 'front')       # 悬钟: 外踝尖上3寸, 腓骨前缘
def _(s):
    return _leg_pt(s, 3, 0.65)


# ---------------- foot (front view; local frame lateral malleolus -> foot landmark) ----------------
def _foot(s, along, lateral):
    """along: fraction of malleolus_lat->foot; lateral: fraction of that length toward the lateral side"""
    M, F = L('malleolus_lat', s), L('foot', s)
    u = F - M
    n = np.linalg.norm(u)
    return M + u * along + A([_lat_sign(s) * lateral * n, 0.0])


@point('GB40', 'front')       # 丘墟: 外踝前下方, 趾长伸肌腱外侧凹陷
def _(s):
    return _foot(s, 0.32, -0.05)


@point('GB41', 'front')       # 足临泣: 第4、5跖骨底结合部前方凹陷
def _(s):
    return _foot(s, 0.62, 0.12)


@point('GB42', 'front')       # 地五会: 第4、5跖骨间, 第4跖趾关节近端
def _(s):
    return _foot(s, 0.78, 0.22)


@point('GB43', 'front')       # 侠溪: 第4、5趾间, 趾蹼缘后方赤白肉际
def _(s):
    return _foot(s, 0.91, 0.36)


@point('GB44', 'front')       # 足窍阴: 第4趾外侧趾甲根角旁0.1寸
def _(s):
    return _foot(s, 1.0, 0.35)
