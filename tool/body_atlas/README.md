# 底图穴位定位工具

生成 `assets/data/body_positions.json` 与 `assets/body/*.jpg`。

1. 原图 `male_front.png` 等（848×1264，AI 生成）放在本目录；MediaPipe 模型（pose_landmarker_heavy / hand_landmarker / face_landmarker .task）从 storage.googleapis.com/mediapipe-models 下载到本目录。
2. `pip install mediapipe==0.10.18 pillow numpy`；`python3 detect2.py male_front male_back female_front female_back && python3 face.py`（已生成的 `mp2.json`、`mask_*.png` 已提交，可跳过）。
3. 体表标志：`lm.py`；骨度分寸 DSL：`pts.py`；各经定义：`defs/*.py`；`python3 render.py <组名|all>` 出核对图。
4. `python3 export.py ../..` 写入 App 资源。

位置为学习示意，非精确体表定位。


## 高清底图

`python3 upscale.py male_front male_back female_front female_back` 用 Real-ESRGAN x4plus（BSD-3-Clause，需 torch 与 spandrel，权重从 xinntao/Real-ESRGAN 发布页下载 RealESRGAN_x4plus.pth）把原图放大 4 倍，生成 `*_x4.png`；`export.py` 检测到后缩至 3 倍（2544×3792）导出。穴位坐标仍以 848×1264 为坐标系。
