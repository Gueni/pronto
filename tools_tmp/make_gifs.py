"""Turns the PNG frames recorded by capture.gd into README GIFs.

usage: py make_gifs.py <root with frames/<shot>/> <out dir> <width> <frame step> shot[:max seconds[:first frame]] ...
"""
import sys, os
from PIL import Image, ImageStat
root, out, width, step = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
for spec in sys.argv[5:]:
    shot, maxs, first = (spec.split(":") + ["", ""])[:3]
    d = os.path.join(root, 'frames', shot)
    fs = sorted(f for f in os.listdir(d) if f.endswith('.png'))
    start = 0
    for i, f in enumerate(fs):   # skip the blank / fading-in opening
        st = ImageStat.Stat(Image.open(os.path.join(d, f)).convert('L'))
        if st.stddev[0] > 20 and st.mean[0] > 30:
            start = max(i, int(first or 0)); break
    fs = fs[start::step]
    if maxs: fs = fs[:int(float(maxs) * 30 / step)]
    frames = []
    for f in fs:
        im = Image.open(os.path.join(d, f)).convert('RGB')
        h = round(im.height * width / im.width)
        frames.append(im.resize((width, h), Image.LANCZOS).quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
    p = os.path.join(out, shot + '.gif')
    frames[0].save(p, save_all=True, append_images=frames[1:], duration=int(1000 * step / 30), loop=0, optimize=True, disposal=1)
    print(f'{shot}: {len(frames)} frames, {os.path.getsize(p)/1e6:.1f} MB')
