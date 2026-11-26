#!/usr/bin/env python3
"""Gera theme/wallpaper.png (1280x720, com dithering). So usa a biblioteca padrao."""
import math, pathlib, random, struct, zlib

# ---- fundo: 1280x720 exatos (sem reescala), transicoes suaves e dithering contra faixas
W, Hh = 1280, 720
def rgb(h): return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
def smooth(t): return t * t * (3 - 2 * t)
def ramp(stops, t):
    # interpolacao Catmull-Rom entre as cores: sem quinas visiveis nas paradas
    if t <= stops[0][0]: return stops[0][1]
    if t >= stops[-1][0]: return stops[-1][1]
    for i in range(len(stops) - 1):
        (p0, c0), (p1, c1) = stops[i], stops[i + 1]
        if t <= p1:
            u = (t - p0) / (p1 - p0)
            u = 0.5 * u + 0.5 * smooth(u)
            return tuple(a + (b - a) * u for a, b in zip(c0, c1))
def mix(c, d, a): return [x + (y - x) * a for x, y in zip(c, d)]
SKY = [(0, rgb('1B1D5C')), (.30, rgb('4A2A6E')), (.52, rgb('88366A')), (.68, rgb('D9488F')),
       (.80, rgb('F07A4A')), (.92, rgb('2A1A2E')), (1, rgb('14111F'))]
DARK = rgb('14111F')
left = [(0, (.74,)), (.45, (.34,)), (1, (.05,))]
bottom = [(0, (0,)), (.45, (.62,)), (1, (.94,))]
random.seed(7)
rows = []
for y in range(Hh):
    base = ramp(SKY, y / (Hh - 1))
    ob = ramp(bottom, max(0.0, (y - 340) / 380))[0]
    line = bytearray([0])
    for x in range(W):
        c = list(base)
        d = math.hypot(x - 950, y - 430)
        if d < 230:  # halo
            c = mix(c, rgb('FF8A5C'), .42 * (1 - d / 230) ** 2)
        if d < 130:  # sol
            t = d / 130
            core = ramp([(0, rgb('FFE6AA')), (.45, rgb('FFA556')), (1, rgb('FF4FB8'))], t)
            c = mix(c, core, ramp([(0, (.97,)), (.45, (.62,)), (.72, (.25,)), (1, (0,))], t)[0])
        c = mix(c, DARK, ramp(left, x / (W - 1))[0])
        if ob > 0: c = mix(c, DARK, ob)
        n = random.random() - random.random()  # ruido triangular de +-1 nivel
        line += bytes(max(0, min(255, int(v + n + 0.5))) for v in c)
    rows.append(bytes(line))
def chunk(tag, data): return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)
png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', W, Hh, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(b''.join(rows), 9)) + chunk(b'IEND', b'')
out = pathlib.Path(__file__).resolve().parent.parent / 'theme' / 'wallpaper.png'
out.write_bytes(png)
print(out, len(png) // 1024, 'KB')

