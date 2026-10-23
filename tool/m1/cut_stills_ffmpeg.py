#!/usr/bin/env python3
"""Same job as cut_stills.py, with only python3 + ffmpeg (no numpy / Pillow).

  cut_stills_ffmpeg.py RAW.mov TEST_LOG OUT_PREFIX

Aligns the recording on the magenta `flash` clapper, then writes OUT_PREFIX_<nn>_<name>.png (half size) for every
MARK, OUT_PREFIX.mp4 (trimmed, half size) and OUT_PREFIX_marks.txt.
"""
import os, re, subprocess, sys

raw, log, prefix = sys.argv[1:4]
marks = [(m.group(1), int(m.group(2))) for m in (re.search(r'MARK:([A-Za-z0-9_]+):(\d+)', l) for l in open(log, errors='ignore')) if m]
mark_ms = dict(marks)
flash_ms = mark_ms['flash']

fps, w, h = 30, 24, 48
p = subprocess.run(['ffmpeg', '-v', 'error', '-i', raw, '-vf', f'fps={fps},scale={w}:{h}', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'], capture_output=True)
buf, size = p.stdout, w * h * 3
mag = []
for i in range(len(buf) // size):
    f = buf[i * size:(i + 1) * size]
    r = sum(f[0::3]) / (w * h); g = sum(f[1::3]) / (w * h); b = sum(f[2::3]) / (w * h)
    if r > 200 and g < 70 and b > 200:
        mag.append(i)
if not mag:
    sys.exit('no flash frame found in the recording')
runs = []
for i in mag:
    if runs and i - runs[-1][1] <= fps // 2:
        runs[-1][1] = i
    else:
        runs.append([i, i])
n_frames = len(buf) // size
t_flash = (runs[0][1] + 1) / fps
scale = 1.0
if len(runs) > 1 and 'flash_end' in mark_ms:
    s2 = ((runs[-1][1] + 1) / fps - t_flash) / ((mark_ms['flash_end'] - flash_ms) / 1000.0)
    if 0.8 < s2 < 1.25:  # a closing flash that does not fit the run is a stray magenta frame: ignore it
        scale = s2
elif len(runs) == 1 and 'flash_end' in mark_ms and (runs[0][1] + 1) / fps > n_frames / fps - 4:
    # only the closing flash was seen (the opening one fell in the slow first frames): anchor on it
    t_flash = (runs[0][1] + 1) / fps - (mark_ms['flash_end'] - flash_ms) / 1000.0
print(f'flash off at {t_flash:.2f}s, wall-clock -> video scale {scale:.4f}')

def video_time(ms):
    return t_flash + (ms - flash_ms) / 1000.0 * scale

out, n = [], 0
for name, ms in marks:
    if name in ('flash', 'flash_end', 'end'):
        continue
    t = video_time(ms)
    n += 1
    png = f'{prefix}_{n:02d}_{name}.png'
    cmd = ['ffmpeg', '-v', 'error', '-y', '-ss', f'{t:.3f}', '-i', raw, '-frames:v', '1', '-vf', 'scale=iw/2:-2', png]
    subprocess.run(cmd, check=True)
    if not os.path.exists(png):  # past the last frame: take the last one
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-sseof', '-0.2', '-i', raw, '-frames:v', '1', '-vf', 'scale=iw/2:-2', png], check=True)
    out.append(f'{n:02d} {name} {t:.2f}s')
end = mark_ms.get('end')
t_end = video_time(end) + 1.0 if end else None
cmd = ['ffmpeg', '-v', 'error', '-y', '-ss', f'{t_flash + 0.15:.3f}', '-i', raw]
if t_end:
    cmd += ['-t', f'{t_end - t_flash - 0.15:.3f}']
cmd += ['-vf', 'scale=trunc(iw/4)*2:trunc(ih/4)*2', '-c:v', 'libx264', '-crf', '28', '-pix_fmt', 'yuv420p', f'{prefix}.mp4']
subprocess.run(cmd, check=True)
open(f'{prefix}_marks.txt', 'w').write('\n'.join(out) + '\n')
print('\n'.join(out))
