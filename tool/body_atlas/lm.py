"""Anatomical landmarks for each figure image, in image pixels.

Naming: sided landmarks end in _R / _L = the SUBJECT's right / left.
  front view: subject right is on the IMAGE LEFT.  back view: subject right is on the IMAGE RIGHT.
Derived from MediaPipe pose/hand/face (mp2.json), the body mask, and fixed body proportions
(checked visually). Override any landmark in manual.json {image: {name: [x, y]}}.
"""
import json, os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
MP = json.load(open(os.path.join(HERE, 'mp2.json')))
MANUAL = json.load(open(os.path.join(HERE, 'manual.json'))) if os.path.exists(os.path.join(HERE, 'manual.json')) else {}

A = np.array


def _mask(name):
    return np.asarray(Image.open(os.path.join(HERE, f'mask_{name}.png'))) > 127


def _edge(mask, p, d, maxlen=200):
    """walk from p along unit dir d until leaving the mask; return last inside point"""
    p = A(p, float); d = A(d, float); d /= np.linalg.norm(d)
    last = p.copy()
    for i in range(1, maxlen):
        q = p + d * i
        x, y = int(round(q[0])), int(round(q[1]))
        if y < 0 or y >= mask.shape[0] or x < 0 or x >= mask.shape[1] or not mask[y, x]:
            break
        last = q
    return last


def _perp_edges(mask, p, a, b):
    """edges of the limb through p perpendicular to segment a->b: returns (edge toward image-left, toward image-right)"""
    v = A(b, float) - A(a, float); v /= np.linalg.norm(v)
    n = A([-v[1], v[0]])
    e1, e2 = _edge(mask, p, n), _edge(mask, p, -n)
    return (e1, e2) if e1[0] < e2[0] else (e2, e1)


def build(name):
    view = 'front' if name.endswith('front') else 'back'
    d = MP[name]; P = {k: A(v, float) for k, v in d['pose'].items()}
    mask = _mask(name)
    L = {}
    # image-left / image-right pose joints regardless of mediapipe's labelling
    def pair(j):
        a, b = P['l_' + j], P['r_' + j]
        il, ir = (a, b) if a[0] < b[0] else (b, a)
        # front: image-left = subject R ; back: image-left = subject L
        return (il, ir) if view == 'front' else (ir, il)
    for j in ['shoulder', 'elbow', 'wrist', 'hip', 'knee', 'ankle', 'heel', 'foot', 'ear', 'eye']:
        R, Lf = pair(j)
        L[j + '_R'], L[j + '_L'] = R, Lf
    sh_mid = (L['shoulder_R'] + L['shoulder_L']) / 2
    hip_mid = (L['hip_R'] + L['hip_L']) / 2
    mx = (sh_mid[0] + hip_mid[0]) / 2
    Ys, Yh = sh_mid[1], hip_mid[1]; D = Yh - Ys
    SW = abs(L['shoulder_R'][0] - L['shoulder_L'][0])
    L['mid_x'] = A([mx, 0.0])
    def m(fr):  # midline point at fraction of shoulder->hip
        return A([mx, Ys + fr * D])
    def side_x(s, off):  # x offset toward subject side s
        sign = (-1 if s == 'R' else 1) * (1 if view == 'front' else -1)
        return sign * off
    # vertex = topmost mask pixel near midline
    ys = np.where(mask[:, int(mx) - 15:int(mx) + 15].any(axis=1))[0]
    L['vertex'] = A([mx, float(ys.min())])
    # acromion: lateral mask edge slightly above shoulder joint
    for s in 'RL':
        p = L['shoulder_' + s] + A([0, -0.06 * D])
        out = A([side_x(s, 1), 0.0])
        L['acromion_' + s] = _edge(mask, p, out) - out * 4
    # arm edges (elbow / wrist), image-outer = lateral in anatomical position
    for s in 'RL':
        sh, el, wr = L['shoulder_' + s], L['elbow_' + s], L['wrist_' + s]
        el_l, el_r = _perp_edges(mask, el, sh, el)
        wr_l, wr_r = _perp_edges(mask, wr, el, wr - (wr - el) * 0.0)
        outer_is_left = side_x(s, 1) < 0
        L['elbow_lat_' + s], L['elbow_med_' + s] = (el_l, el_r) if outer_is_left else (el_r, el_l)
        L['wrist_lat_' + s], L['wrist_med_' + s] = (wr_l, wr_r) if outer_is_left else (wr_r, wr_l)
        # anatomical names (palms forward): lateral = radial(thumb), medial = ulnar(little finger)
        L['wrist_rad_' + s], L['wrist_uln_' + s] = L['wrist_lat_' + s], L['wrist_med_' + s]
        # axillary fold: where arm separates from trunk (scan down inner arm edge)
        inner = A([-side_x(s, 1), 0.0])
        best = None
        for t in np.linspace(0.05, 0.6, 60):
            q = sh + (el - sh) * t
            lim = int(0.22 * SW)
            e = _edge(mask, q, inner, lim)
            if np.linalg.norm(e - q) < lim - 3:
                best = e; break
        L['axilla_' + s] = best if best is not None else sh + (el - sh) * 0.25
    # legs
    for s in 'RL':
        hp, kn, an = L['hip_' + s], L['knee_' + s], L['ankle_' + s]
        k_l, k_r = _perp_edges(mask, kn, hp, kn)
        a_l, a_r = _perp_edges(mask, an + A([0, -0.01 * D]), kn, an)
        outer_is_left = side_x(s, 1) < 0
        L['knee_lat_' + s], L['knee_med_' + s] = (k_l, k_r) if outer_is_left else (k_r, k_l)
        L['malleolus_lat_' + s], L['malleolus_med_' + s] = (a_l, a_r) if outer_is_left else (a_r, a_l)
        g_l, g_r = _perp_edges(mask, hp + A([0, 0.05 * D]), hp, kn)
        L['trochanter_' + s] = g_l if outer_is_left else g_r
    # hands: assign by nearest wrist
    for h in d['hands']:
        w = A(h['wrist'])
        s = 'R' if np.linalg.norm(w - L['wrist_R']) < np.linalg.norm(w - L['wrist_L']) else 'L'
        for k, v in h.items():
            L[f'hand_{k}_{s}'] = A(v)
    # trunk & spine by proportion of shoulder(Ys)->hip(Yh) distance D (fitted on male images)
    if view == 'front':
        L['sternal_notch'] = m(-0.11)
        L['xiphoid'] = m(0.39)
        L['navel'] = m(0.70)
        L['pubis'] = m(0.89)
        pass
        for s in 'RL':
            L['nipple_' + s] = A([mx + side_x(s, 0.316 * SW), Ys + 0.24 * D])
            L['clavicle_mid_' + s] = A([mx + side_x(s, 0.316 * SW), Ys - 0.07 * D])
            L['asis_' + s] = A([mx + side_x(s, 0.26 * SW), Ys + 0.86 * D])
            L['coracoid_' + s] = A([mx + side_x(s, 0.43 * SW), Ys - 0.02 * D])
    else:
        L['c7'] = m(-0.156)
        lv = {'T3': 0.0, 'T7': 0.25, 'L4': 0.75}
        # interpolate vertebrae: C7 -> T3 -> T7 -> L4 linear between anchors, L4->S hiatus
        names = ['C7'] + [f'T{i}' for i in range(1, 13)] + [f'L{i}' for i in range(1, 6)]
        anchors = {'C7': -0.156, 'T3': 0.0, 'T7': 0.25, 'L4': 0.75}
        idx = {n: i for i, n in enumerate(names)}
        keys = sorted(anchors, key=lambda n: idx[n])
        for n in names:
            i = idx[n]
            for a, b in zip(keys, keys[1:]):
                if idx[a] <= i <= idx[b]:
                    fr = anchors[a] + (anchors[b] - anchors[a]) * (i - idx[a]) / (idx[b] - idx[a])
            if i > idx['L4']:
                fr = 0.75 + 0.075 * (i - idx['L4'])
            L['spine_' + n] = m(fr)
        # sacral foramina levels S1..S4 and sacral hiatus / coccyx
        for i in range(1, 5):
            L[f'spine_S{i}'] = m(0.825 + 0.045 * i)
        L['sacral_hiatus'] = m(1.03)
        L['coccyx'] = m(1.08)
        for s in 'RL':
            L['scap_med_' + s] = A([mx + side_x(s, 0.19 * SW), Ys + 0.05 * D])  # medial border at T4/5 level
            L['scap_inf_' + s] = A([mx + side_x(s, 0.20 * SW), Ys + 0.25 * D])
            L['gluteal_fold_' + s] = A([mx + side_x(s, 0.24 * SW), Ys + 1.28 * D])
            L['popliteal_' + s] = (L['knee_lat_' + s] + L['knee_med_' + s]) / 2
    # head
    if view == 'front' and d['face']:
        F = [A(p) for p in d['face']]
        fi = lambda i: F[i]
        L['glabella'] = (fi(55) + fi(285)) / 2
        L['forehead'] = fi(10)
        L['nose_tip'] = fi(1)
        L['nose_root'] = fi(168)
        L['philtrum'] = (fi(164) + fi(0)) / 2
        L['lip_lower_groove'] = fi(18)
        L['chin'] = fi(152)
        # mediapipe face: 'right' indices are the subject's right
        sided = {'brow_in': (55, 285), 'brow_mid': (105, 334), 'brow_out': (46, 276),
                 'eye_in': (133, 362), 'eye_out': (33, 263), 'eye_up': (159, 386), 'eye_low': (145, 374),
                 'pupil': (468, 473), 'ala': (129, 358), 'mouth': (61, 291), 'zygoma': (234, 454),
                 'jaw_angle': (172, 397), 'cheek': (50, 280), 'temple': (127, 356)}
        for k, (r, l) in sided.items():
            L[k + '_R'], L[k + '_L'] = fi(r), fi(l)
        # anterior hairline: forehead landmark sits close to it; nudge up a little
        L['hairline_front'] = L['forehead'] + (L['forehead'] - L['glabella']) * 0.05
        L['throat'] = L['chin'] + (L['sternal_notch'] - L['chin']) * 0.35  # laryngeal prominence (approx)
    if view == 'back':
        ear_y = (L['ear_R'][1] + L['ear_L'][1]) / 2
        L['occiput'] = A([mx, ear_y - 0.02 * D])
        L['hairline_back'] = A([mx, ear_y + (L['c7'][1] - ear_y) * 0.45])
        for s in 'RL':
            L['mastoid_' + s] = A([L['ear_' + s][0] - side_x(s, 0.02 * SW), ear_y + 0.05 * D])
    L['_D'] = A([D, 0.0]); L['_SW'] = A([SW, 0.0])
    for k, v in MANUAL.get(name, {}).items():
        L[k] = A(v, float)
    return L, view


IMAGES = ['male_front', 'male_back', 'female_front', 'female_back']
ALL = {n: build(n) for n in IMAGES}
