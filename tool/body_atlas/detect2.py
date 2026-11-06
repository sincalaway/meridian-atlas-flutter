"""Run MediaPipe pose(+segmentation), hands, face on each figure image.
Outputs mp2.json: per image {pose:{name:[x,y]}, hands:[{name:[x,y]}...], face:[[x,y]...]} and mask_<img>.png"""
import json, sys
import numpy as np
import mediapipe as mp
from mediapipe.tasks import python as mpt
from mediapipe.tasks.python import vision
from PIL import Image

POSE = ['nose','l_eye_in','l_eye','l_eye_out','r_eye_in','r_eye','r_eye_out','l_ear','r_ear','mouth_l','mouth_r',
        'l_shoulder','r_shoulder','l_elbow','r_elbow','l_wrist','r_wrist','l_pinky','r_pinky','l_index','r_index',
        'l_thumb','r_thumb','l_hip','r_hip','l_knee','r_knee','l_ankle','r_ankle','l_heel','r_heel','l_foot','r_foot']
HAND = ['wrist','thumb_cmc','thumb_mcp','thumb_ip','thumb_tip','index_mcp','index_pip','index_dip','index_tip',
        'middle_mcp','middle_pip','middle_dip','middle_tip','ring_mcp','ring_pip','ring_dip','ring_tip',
        'pinky_mcp','pinky_pip','pinky_dip','pinky_tip']
pl = vision.PoseLandmarker.create_from_options(vision.PoseLandmarkerOptions(
    base_options=mpt.BaseOptions(model_asset_path='pose_landmarker_heavy.task'), output_segmentation_masks=True))
hl = vision.HandLandmarker.create_from_options(vision.HandLandmarkerOptions(
    base_options=mpt.BaseOptions(model_asset_path='hand_landmarker.task'), num_hands=2,
    min_hand_detection_confidence=0.2))
fl = vision.FaceLandmarker.create_from_options(vision.FaceLandmarkerOptions(
    base_options=mpt.BaseOptions(model_asset_path='face_landmarker.task'), min_face_detection_confidence=0.2))
out = {}
for name in sys.argv[1:]:
    img = mp.Image.create_from_file(name + '.png')
    W, H = img.width, img.height
    r = pl.detect(img)
    pose = {n: [lm.x * W, lm.y * H] for n, lm in zip(POSE, r.pose_landmarks[0])}
    m = r.segmentation_masks[0].numpy_view()
    m = (np.squeeze(m) > 0.5).astype(np.uint8) * 255
    # union with brightness threshold (skin/shorts), helps thin fingers
    a = np.asarray(Image.open(name + '.png').convert('L')).astype(int)
    m = np.maximum(m, ((a > 55) * 255).astype(np.uint8))
    Image.fromarray(m).save('mask_' + name + '.png')
    hands = []
    for hand in hl.detect(img).hand_landmarks:
        hands.append({n: [lm.x * W, lm.y * H] for n, lm in zip(HAND, hand)})
    face = []
    fr = fl.detect(img)
    if fr.face_landmarks:
        face = [[lm.x * W, lm.y * H] for lm in fr.face_landmarks[0]]
    out[name] = {'size': [W, H], 'pose': pose, 'hands': hands, 'face': face}
    print(name, len(hands), len(face))
import os
prev = json.load(open('mp2.json')) if os.path.exists('mp2.json') else {}
prev.update(out)
json.dump(prev, open('mp2.json', 'w'))
