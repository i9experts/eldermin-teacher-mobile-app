#!/usr/bin/env python3
"""Dev-only: counts inline style literals per Dart file (the D6+ restyle metric).
  fontSize   `fontSize: <number>`
  insets     every `EdgeInsets.<ctor>(...)` / `EdgeInsetsDirectional.<ctor>(...)` whose arguments contain a number literal other than 0
  radius     every `BorderRadius.<ctor>(...)` / `Radius.circular(...)` whose arguments contain a number literal other than 0
Usage: tool/dev/style_literals.py <file-or-dir>...   (prints one row per file and a total)"""
import re, sys, pathlib

def calls(src, pat):
    n = 0
    for m in re.finditer(pat, src):
        i, d = m.end() - 1, 0
        j = i
        while j < len(src):
            c = src[j]
            if c == '(':
                d += 1
            elif c == ')':
                d -= 1
                if d == 0:
                    break
            j += 1
        args = src[i:j + 1]
        if re.search(r'(?<![A-Za-z_.])(?:[1-9]\d*(?:\.\d+)?|0\.\d*[1-9]\d*)', args):
            n += 1
    return n

def count(path):
    s = pathlib.Path(path).read_text()
    s = re.sub(r'//[^\n]*', '', s)
    return (
        len(re.findall(r'fontSize:\s*\d', s)),
        calls(s, r'EdgeInsets(?:Directional)?\.\w+\('),
        calls(s, r'(?:BorderRadius\.\w+|Radius\.circular)\('),
    )

files = []
for a in sys.argv[1:]:
    p = pathlib.Path(a)
    files += sorted(p.rglob('*.dart')) if p.is_dir() else [p]
tot = [0, 0, 0]
print(f"{'file':<80} {'fontSize':>8} {'insets':>7} {'radius':>7}")
for f in files:
    c = count(f)
    tot = [x + y for x, y in zip(tot, c)]
    print(f"{str(f):<80} {c[0]:>8} {c[1]:>7} {c[2]:>7}")
print(f"{'TOTAL':<80} {tot[0]:>8} {tot[1]:>7} {tot[2]:>7}")
