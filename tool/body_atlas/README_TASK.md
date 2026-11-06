# Placing acupoints on the figure images (骨度分寸)

Working dir: /workspace/projects/3ee1b4d6-2bfb-4863-8306-89f5139ae3c6/work/bodyimg
Images (848x1264 px): male_front.png, male_back.png, female_front.png, female_back.png
(standing anatomical position, palms forward; front view: subject RIGHT is on IMAGE LEFT; back view: subject RIGHT is on IMAGE RIGHT).

- Landmarks: lm.py builds them; list in LANDMARKS.md; see them drawn in lm_<image>.jpg (2x scale).
- DSL: read pts.py docstrings (point, L, U, seg, lat, at_x_from_mid, up, down, toward, perp, mid, lerp).
- Your points: tasks/<GROUP>.txt (code \t name \t textbook location text). Use the location text + standard WHO/国标 定位 (骨度分寸) to define each point.
- Write ONLY defs/<GROUP>.py. Do NOT edit lm.py, pts.py, render.py, or other groups' files.
  If you need a landmark that does not exist, derive it inside your own file (local helper functions using L()/U()/geometry).
- Each point gets exactly ONE view ('front' or 'back') = where it is best visible in these two views.
  Points on the lateral side of trunk/leg/head: put them near the silhouette edge in the view that shows them best.
  Hand dorsum / posterior forearm points -> 'back' (backs of hands face the camera in the back view); palm / anterior forearm -> 'front'.
  Midline points use mid=True. Bilateral points return the point for side s.
- Check: `python3 render.py <GROUP>` writes check_<GROUP>_<image>_full.jpg (2x); `python3 render.py <GROUP> x0 y0 x1 y1` writes a 3x crop.
  Look at the renders with read_file and fix until every point sits on the right anatomical spot on BOTH male and female images,
  points of one meridian are in the right order along the channel, and render prints no errors (outside-mask warnings must be fixed).
- Positions are learning illustrations (approximate); do not invent points that are not in your task file. Every code in your task file must be defined.
