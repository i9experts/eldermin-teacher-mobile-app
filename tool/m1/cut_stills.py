#!/usr/bin/env python3
"""Cut stills and a trimmed video out of a walkthrough recording (dev tool, needs numpy + pillow).

  cut_stills.py RAW.mov TEST_LOG OUT_PREFIX

TEST_LOG holds the `MARK:<name>:<epoch ms>` lines of integration_test/m2m3_walk_test.dart. The recording is
aligned on the first magenta frame (the `flash` clapper, visible for 250 ms before the flash MARK is printed);
every other mark becomes OUT_PREFIX_<nn>_<name>.png (half size), the video is trimmed to OUT_PREFIX.mp4
(from just after the flash to one second after the `end` mark) and OUT_PREFIX_marks.txt lists name -> video time.
"""
import re, subprocess, sys
import numpy as np
from PIL import Image

raw, log, prefix = sys.argv[1:4]
marks = [(m.group(1), int(m.group(2))) for m in (re.search(r'MARK:([A-Za-z0-9_]+):(\d+)', l) for l in open(log, errors='ignore')) if m]
flash_ms = dict(marks)['flash']

# first magenta frame, scanned at 30 fps on a tiny version of the video
fps = 30
p = subprocess.run(['ffmpeg', '-v', 'error', '-i', raw, '-vf', f'fps={fps},scale=24:48', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'], capture_output=True)
frames = np.frombuffer(p.stdout, np.uint8).reshape(-1, 48, 24, 3).astype(int)
mag = [i for i, f in enumerate(frames) if f[..., 0].mean() > 200 and f[..., 1].mean() < 70 and f[..., 2].mean() > 200]
if not mag:
    sys.exit('no flash frame found in the recording')
# the opening flash and the closing one. The flash MARK is printed when the flash is switched OFF, so the
# last magenta frame of each run is what lines up with it (the flash itself lasts a little longer than 250 ms under load).
runs = []  # (first, last) magenta frame of each run
for i in mag:
    if runs and i - runs[-1][1] <= fps // 2:
        runs[-1][1] = i
    else:
        runs.append([i, i])
t_flash = (runs[0][1] + 1) / fps
mark_ms = dict(marks)
if len(runs) > 1 and 'flash_end' in mark_ms:
    t_flash_end = (runs[-1][1] + 1) / fps
    scale = (t_flash_end - t_flash) / ((mark_ms['flash_end'] - flash_ms) / 1000.0)
else:
    scale = 1.0
print(f'flash off at {t_flash:.2f}s (visible {(runs[0][1] - runs[0][0] + 1) / fps:.2f}s), closing flash off at {"%.2fs" % ((runs[-1][1] + 1) / fps) if len(runs) > 1 else "n/a"}, wall-clock -> video scale {scale:.4f}')

def video_time(ms):
    return t_flash + (ms - flash_ms) / 1000.0 * scale

out = []
n = 0
for name, ms in marks:
    if name in ('flash', 'flash_end', 'end'):
        continue
    t = video_time(ms)
    n += 1
    png = f'{prefix}_{n:02d}_{name}.png'
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', f'{t:.3f}', '-i', raw, '-frames:v', '1', png], check=True)
    if not __import__('os').path.exists(png):  # past the last frame (the recorder writes frames only while the screen changes): the last one
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-sseof', '-0.2', '-i', raw, '-frames:v', '1', png], check=True)
    im = Image.open(png).convert('RGB')
    im.resize((im.width // 2, im.height // 2), Image.LANCZOS).save(png)
    out.append(f'{n:02d} {name} {t:.2f}s')
end = dict(marks).get('end')
t_end = video_time(end) + 1.0 if end else None
cmd = ['ffmpeg', '-v', 'error', '-y', '-ss', f'{t_flash + 0.15:.3f}', '-i', raw]
if t_end:
    cmd += ['-t', f'{t_end - t_flash - 0.15:.3f}']
cmd += ['-vf', 'scale=iw/2:-2', '-c:v', 'libx264', '-crf', '28', '-pix_fmt', 'yuv420p', f'{prefix}.mp4']
subprocess.run(cmd, check=True)
open(f'{prefix}_marks.txt', 'w').write('\n'.join(out) + '\n')
print('\n'.join(out))
