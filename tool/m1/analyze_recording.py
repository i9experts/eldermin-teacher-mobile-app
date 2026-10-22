#!/usr/bin/env python3
"""Frame-by-frame look at an M1 splash recording (dev tool, needs numpy + pillow).

  analyze_recording.py VIDEO FRAMES_DIR [--no-extract] [--stills OUT_PREFIX] [--quiet]

Extracts every frame (variable frame rate, pts kept), then prints per frame:
pts, how much of the screen is the native navy (#18457A), the background
sample at the screen edge, the logo's centre of mass, and how many pixels in the
logo box changed since the previous frame. Use it around the native -> Flutter
hand-off to look for a jump or a flash.
"""
import subprocess, sys, os, glob
import numpy as np
from PIL import Image

NAVY = np.array([0x18, 0x45, 0x7A])

def main():
    video, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    if '--no-extract' not in sys.argv:
        for f in glob.glob(out + '/*.png'): os.remove(f)
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', video, '-vf', 'setpts=N', '-fps_mode', 'passthrough', out + '/%04d.png'], check=True)
    pts = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'frame=pts_time', '-of', 'csv=p=0', video],
                         capture_output=True, text=True).stdout.replace(',', ' ').split()
    files = sorted(glob.glob(out + '/*.png'))
    prev = None
    rows = []
    print('idx   pts    navy%  edge-bg(r,g,b)  logo-centroid(x,y)  logo-changed-px  frame-changed%')
    for i, f in enumerate(files):
        im = np.asarray(Image.open(f).convert('RGB')).astype(int)
        h, w, _ = im.shape
        body = im[int(h * 0.08):int(h * 0.97)]
        navy = (np.abs(body - NAVY).sum(axis=2) < 12).mean() * 100
        edge = im[int(h * 0.3), int(w * 0.03)]
        # logo box: centre +-18% of width
        cx, cy = w // 2, h // 2
        r = int(w * 0.18)
        box = im[cy - r:cy + r, cx - r:cx + r]
        bright = box.sum(axis=2) > 600  # the white hubs
        ys, xs = np.nonzero(bright)
        cen = (f'{xs.mean() + cx - r:7.1f},{ys.mean() + cy - r:7.1f}' if len(xs) > 50 else '   -   ,   -   ')
        if prev is not None:
            d = np.abs(box - prev[0]).sum(axis=2) > 48
            dn = d.sum()
            fr = (np.abs(body - prev[1]).sum(axis=2) > 48).mean() * 100
        else:
            dn, fr = 0, 0
        prev = (box, body)
        rows.append(dict(i=i, pts=float(pts[i]), edge=int(edge[0]), navy=navy, logo=int(dn), fr=fr, cen=cen))
        if '--quiet' not in sys.argv:
          print(f'{i + 1:04d} {float(pts[i]):6.3f} {navy:6.1f}  ({edge[0]:3d},{edge[1]:3d},{edge[2]:3d})   {cen}     {dn:7d}        {fr:6.2f}')

    report(files, rows)

def report(files, rows):
    # native/static stretch: navy screen, nothing changing
    # (skips the OS app-launch zoom: needs 10 quiet frames in a row)
    quiet = [r['navy'] > 98 and r['fr'] < 0.05 and r['logo'] < 60 for r in rows]
    s0 = next((k for k in range(len(rows) - 10) if all(quiet[k:k + 10])), None)
    if s0 is None:
        print('\nno static navy stretch found (the app may not have shown a native splash)'); return
    j = next((r['i'] for r in rows if r['i'] > s0 and not quiet[r['i']]), None)
    if j is None:
        print('\nno motion after the static stretch'); return
    s0 = s0 + 8  # let the OS launch zoom (rounded corners, status bar) finish
    ref = np.asarray(Image.open(files[s0]).convert('RGB')).astype(int)  # the native splash, settled
    h, w = ref.shape[:2]
    y0, y1, x0, x1 = int(h * .12), int(h * .92), int(w * .05), int(w * .95)  # inside the OS chrome

    def vs_native(k):
        im = np.asarray(Image.open(files[k]).convert('RGB')).astype(int)
        return im, np.abs(im[y0:y1, x0:x1] - ref[y0:y1, x0:x1]).max(axis=2)

    # first frame that is visibly not the native splash = the Flutter first frame (or the first one painted after it)
    k = next((r['i'] for r in rows if r['i'] > s0 and (vs_native(r['i'])[1] > 8).sum() > 200), j)
    print(f"\nnative splash settled at frame {s0 + 1} (pts {rows[s0]['pts']:.3f}, region inside the OS chrome); first frame that differs from it: {k + 1} (pts {rows[k]['pts']:.3f}); first logo motion: {j + 1} (pts {rows[j]['pts']:.3f})")
    for n in (k - 1, k, k + 1, k + 2):
        im, d = vs_native(n)
        bg = im[int(h * .3), int(im.shape[1] * .03)]
        ys, xs = np.nonzero(d > 8)
        box = f'x {xs.min() + x0}-{xs.max() + x0} y {ys.min() + y0}-{ys.max() + y0}' if len(xs) else '-'
        print(f'  frame {n + 1}: pixels differing from the native frame: >0: {(d > 0).sum():7d}  >8: {(d > 8).sum():6d}  >32: {(d > 32).sum():6d}  max {d.max():3d}  where {box}  edge bg {tuple(int(x) for x in bg)}')
    # stills
    if '--stills' in sys.argv:
        pre = sys.argv[sys.argv.index('--stills') + 1]
        # exit = the navy starts to lift (edge colour leaves #18457A); the flight picture is the frame after that
        exit0 = next((r['i'] for r in rows if r['i'] > j and r['edge'] > 40), rows[-1]['i'])
        mid = max((r for r in rows if j < r['i'] < exit0 - 8), key=lambda r: r['logo'], default=rows[j])['i']
        fly = min(exit0 + 1, rows[-1]['i'])
        picks = [('1_first', k), ('2_mid_motion', mid), ('3_exit_mid_flight', fly), ('4_landed', rows[-1]['i'])]
        for name, k in picks:
            im = Image.open(files[k]).convert('RGB')
            im = im.resize((im.width // 2, im.height // 2), Image.LANCZOS)
            im.save(f'{pre}_{name}.png')
            print(f'  still {name}: frame {k + 1} pts {rows[k]["pts"]:.3f}')

main()
