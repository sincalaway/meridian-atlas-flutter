import json, numpy as np, mediapipe as mp
from mediapipe.tasks import python as mpt
from mediapipe.tasks.python import vision
from PIL import Image
fl = vision.FaceLandmarker.create_from_options(vision.FaceLandmarkerOptions(
    base_options=mpt.BaseOptions(model_asset_path='face_landmarker.task'), min_face_detection_confidence=0.1))
d=json.load(open('mp2.json'))
for n in ['male_front','female_front']:
    nose=d[n]['pose']['nose']; x0,y0=int(nose[0]-130),int(max(0,nose[1]-150)); S=4
    im=Image.open(n+'.png').convert('RGB').crop((x0,y0,x0+260,y0+260)).resize((1040,1040),Image.LANCZOS)
    r=fl.detect(mp.Image(image_format=mp.ImageFormat.SRGB,data=np.asarray(im).copy()))
    d[n]['face']=[[x0+l.x*260,y0+l.y*260] for l in r.face_landmarks[0]] if r.face_landmarks else []
    print(n,len(d[n]['face']))
json.dump(d,open('mp2.json','w'))
