import sys, torch, numpy as np
from PIL import Image
from spandrel import ModelLoader
torch.set_num_threads(8)
m = ModelLoader().load_from_file('RealESRGAN_x4plus.pth').model.eval()
for n in sys.argv[1:]:
    im = np.asarray(Image.open(n + '.png').convert('RGB')).astype(np.float32) / 255
    H, W, _ = im.shape; T = 256; P = 16
    out = np.zeros((H * 4, W * 4, 3), np.float32)
    for y in range(0, H, T):
        for x in range(0, W, T):
            y0, x0 = max(0, y - P), max(0, x - P); y1, x1 = min(H, y + T + P), min(W, x + T + P)
            t = torch.from_numpy(im[y0:y1, x0:x1].transpose(2, 0, 1))[None]
            with torch.no_grad():
                r = m(t)[0].numpy().transpose(1, 2, 0)
            oy, ox = (y - y0) * 4, (x - x0) * 4
            h, w = min(T, H - y) * 4, min(T, W - x) * 4
            out[y * 4:y * 4 + h, x * 4:x * 4 + w] = r[oy:oy + h, ox:ox + w]
    Image.fromarray((out.clip(0, 1) * 255).round().astype(np.uint8)).save(n + '_x4.png')
    print(n, 'done', flush=True)
