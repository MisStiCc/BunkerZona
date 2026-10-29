# -*- coding: utf-8 -*-
# ЗАДАЧА 29: ориентиры ЧАЭС (процедурные low-poly GLB с фасетными
# вершинными цветами). Origin в основании, +Z фронт, метры.
import json
import math
import os
import random
import struct

OUT = r'E:\StalkerRevert\StalkerRevert\inbox\chaes_landmarks\models'

# ---- мини GLB-райтер: фасетные нормали + вершинные цвета ----


class MeshBuilder:
    def __init__(self):
        self.pos = []
        self.nrm = []
        self.col = []
        self.idx = []

    def tri(self, a, b, c, color, jitter=0.0, rnd=None):
        """Треугольник с фасетной нормалью и лёгкой вариацией цвета."""
        ux, uy, uz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
        vx, vy, vz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
        nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
        ln = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
        nx, ny, nz = nx / ln, ny / ln, nz / ln
        sh = 1.0
        if jitter > 0 and rnd:
            sh = 1.0 + rnd.uniform(-jitter, jitter)
        col = tuple(min(1.0, max(0.0, v * sh)) for v in color)
        base = len(self.pos)
        for p in (a, b, c):
            self.pos.append(p)
            self.nrm.append((nx, ny, nz))
            self.col.append(col)
        self.idx += (base, base + 1, base + 2)

    def quad(self, a, b, c, dd, color, jitter=0.0, rnd=None):
        self.tri(a, b, c, color, jitter, rnd)
        self.tri(a, c, dd, color, jitter, rnd)

    def box(self, cx, cz, y0, w, d, h, color, jitter=0.04, rnd=None):
        x0, x1 = cx - w / 2, cx + w / 2
        z0, z1 = cz - d / 2, cz + d / 2
        y1 = y0 + h
        p = lambda x, y, z: (x, y, z)
        self.quad(p(x0, y0, z1), p(x1, y0, z1), p(x1, y1, z1), p(x0, y1, z1), color, jitter, rnd)  # +Z
        self.quad(p(x1, y0, z0), p(x0, y0, z0), p(x0, y1, z0), p(x1, y1, z0), color, jitter, rnd)  # -Z
        self.quad(p(x1, y0, z1), p(x1, y0, z0), p(x1, y1, z0), p(x1, y1, z1), color, jitter, rnd)  # +X
        self.quad(p(x0, y0, z0), p(x0, y0, z1), p(x0, y1, z1), p(x0, y1, z0), color, jitter, rnd)  # -X
        self.quad(p(x0, y1, z1), p(x1, y1, z1), p(x1, y1, z0), p(x0, y1, z0), color, jitter, rnd)  # верх

    def tube(self, profile, z0, z1, color, jitter=0.05, rnd=None, cap_start=False, cap_end=False,
             cap_color=None):
        """Лента по профилю [(r,y)...] вдоль Z; нормали наружу (от оси X=0)."""
        nseg = len(profile) - 1
        ring0 = [(profile[i][0], profile[i][1], z0) for i in range(nseg + 1)]
        ring1 = [(profile[i][0], profile[i][1], z1) for i in range(nseg + 1)]
        for i in range(nseg):
            a = (ring0[i][0], ring0[i][1], z0)
            b = (ring1[i][0], ring1[i][1], z1)
            c = (ring1[i + 1][0], ring1[i + 1][1], z1)
            dd = (ring0[i + 1][0], ring0[i + 1][1], z0)
            # нормаль должна смотреть от оси: если смотрит внутрь — разворачиваем
            ux, uy, uz = b[0] - a[0], b[1] - a[1], 0.0
            vx, vy, vz = c[0] - a[0], c[1] - a[1], 0.0
            nx = uy * 0 - uz * vy
            ny = uz * vx - ux * 0
            nz = 0.0
            mid_x = (a[0] + c[0]) / 2
            if nx * mid_x < 0:
                self.tri(a, c, b, color, jitter, rnd)
                self.tri(a, dd, c, color, jitter, rnd)
            else:
                self.tri(a, b, c, color, jitter, rnd)
                self.tri(a, c, dd, color, jitter, rnd)
        if cap_start:
            self._cap(profile, z0, -1.0, cap_color or color, rnd)
        if cap_end:
            self._cap(profile, z1, 1.0, cap_color or color, rnd)

    def _cap(self, profile, z, sign, color, rnd):
        cx = sum(p[0] for p in profile) / len(profile)
        cy = sum(p[1] for p in profile) / len(profile)
        c = (cx, cy, z)
        for i in range(len(profile) - 1):
            self.tri(c, (profile[i][0], profile[i][1], z),
                     (profile[i + 1][0], profile[i + 1][1], z), color, 0.03, rnd)

    def to_glb(self, path, name):
        pos_f = [v for p in self.pos for v in p]
        nrm_f = [v for p in self.nrm for v in p]
        col_f = [v for p in self.col for v in p]
        idx = self.idx
        minp = [min(p[i] for p in self.pos) for i in range(3)]
        maxp = [max(p[i] for p in self.pos) for i in range(3)]

        def view(data, target):
            off = len(data)
            while off % 4:
                off += 1
            return off, data

        blob = b''
        views = []

        def add(data, ctype, count, target=None):
            nonlocal blob
            while len(blob) % 4:
                blob += b'\0'
            views.append({
                'buffer': 0, 'byteOffset': len(blob), 'byteLength': len(data),
                **({'target': target} if target else {})
            })
            blob += data
            return len(views) - 1

        v_pos = add(b''.join(struct.pack('<3f', *p) for p in self.pos), 'VEC3', len(self.pos), 34962)
        v_nrm = add(b''.join(struct.pack('<3f', *p) for p in self.nrm), 'VEC3', len(self.nrm), 34962)
        v_col = add(b''.join(struct.pack('<3f', *p) for p in self.col), 'VEC3', len(self.col), 34962)
        v_idx = add(b''.join(struct.pack('<I', i) for i in idx), 'SCALAR', len(idx), 34963)

        gltf = {
            'asset': {'version': '2.0', 'generator': 'StalkerRevert preparer (procedural)'},
            'scene': 0,
            'scenes': [{'nodes': [0]}],
            'nodes': [{'name': name, 'mesh': 0}],
            'meshes': [{'primitives': [{'attributes': {'POSITION': 0, 'NORMAL': 1, 'COLOR_0': 2},
                                        'indices': 3, 'material': 0, 'mode': 4}]}],
            'materials': [{'name': 'vertex_colored', 'doubleSided': True,
                           'pbrMetallicRoughness': {'baseColorFactor': [1, 1, 1, 1],
                                                    'metallicFactor': 0.0, 'roughnessFactor': 0.9}}],
            'buffers': [{'byteLength': len(blob)}],
            'bufferViews': views,
            'accessors': [
                {'bufferView': v_pos, 'componentType': 5126, 'count': len(self.pos), 'type': 'VEC3',
                 'min': minp, 'max': maxp},
                {'bufferView': v_nrm, 'componentType': 5126, 'count': len(self.nrm), 'type': 'VEC3'},
                {'bufferView': v_col, 'componentType': 5126, 'count': len(self.col), 'type': 'VEC3'},
                {'bufferView': v_idx, 'componentType': 5125, 'count': len(idx), 'type': 'SCALAR'},
            ],
        }
        js = json.dumps(gltf, separators=(',', ':')).encode('utf-8')
        while len(js) % 4:
            js += b' '
        while len(blob) % 4:
            blob += b'\0'
        out = b'glTF' + struct.pack('<II', 2, 12 + 8 + len(js) + 8 + len(blob))
        out += struct.pack('<I', len(js)) + b'JSON' + js
        out += struct.pack('<I', len(blob)) + b'BIN\x00' + blob
        open(path, 'wb').write(out)
        tris = len(idx) // 3
        print(f"{os.path.basename(path):22} {tris:5} трис, габариты "
              f"{maxp[0]-minp[0]:.1f} x {maxp[1]-minp[1]:.1f} x {maxp[2]-minp[2]:.1f} м, {len(out)//1024} КБ")


rnd = random.Random(29)

# ============ 1. НБК: арка Укрытие-2 (ширина 250, высота 108, глубина 150) ============
m = MeshBuilder()
SEG = 16
A, B = 125.0, 108.0
profile = []
for i in range(SEG + 1):
    th = math.pi * i / SEG
    profile.append((A * math.cos(th), B * math.sin(th)))
z0, z1 = -75.0, 75.0
m.tube(profile, z0, z1, (0.70, 0.73, 0.76), jitter=0.05, rnd=rnd)
# торцы (вертикальные): тёмнее, чуть внутрь
cap = [(p[0] * 0.99, p[1], z0) for p in profile]
m._cap(cap, z0 + 0.3, -1.0, (0.42, 0.45, 0.47), rnd)
cap1 = [(p[0] * 0.99, p[1], z1) for p in profile]
m._cap(cap1, z1 - 0.3, 1.0, (0.42, 0.45, 0.47), rnd)
m.to_glb(os.path.join(OUT, 'nbc_arch.glb'), 'NBC_Arch')

# ============ 2. Прометей (общая высота ~9 м, тёмная бронза) ============
m = MeshBuilder()
BRONZE = (0.36, 0.23, 0.13)
DARK_BR = (0.28, 0.18, 0.10)
STONE = (0.34, 0.32, 0.28)
# постамент
m.box(0, 0, 0.0, 3.6, 3.6, 0.9, STONE, rnd=rnd)
m.box(0, 0, 0.9, 2.6, 2.6, 1.0, STONE, rnd=rnd)
# фигура: ноги
m.box(-0.28, 0, 1.9, 0.42, 0.5, 2.3, BRONZE, rnd=rnd)
m.box(0.28, 0, 1.9, 0.42, 0.5, 2.3, BRONZE, rnd=rnd)
# тороР: усечённый конус руками через tube по кругу? проще — бокс-торс со скосом
m.box(0, 0, 4.2, 1.15, 0.8, 1.9, BRONZE, rnd=rnd)
m.box(0, 0, 6.1, 0.85, 0.6, 0.6, DARK_BR, rnd=rnd)
# голова
hx, hy = 0, 6.95
for i in range(6):
    m.tri((hx + 0.26 * math.cos(i * math.tau / 6), hy + 0.26 * math.sin(i * math.tau / 6), 0),
          (hx + 0.26 * math.cos((i + 1) * math.tau / 6), hy + 0.26 * math.sin((i + 1) * math.tau / 6), 0),
          (hx, hy, 0.26), DARK_BR, 0.05, rnd)
    m.tri((hx + 0.26 * math.cos(i * math.tau / 6), hy + 0.26 * math.sin(i * math.tau / 6), 0),
          (hx + 0.26 * math.cos((i + 1) * math.tau / 6), hy + 0.26 * math.sin((i + 1) * math.tau / 6), 0),
          (hx, hy, -0.26), DARK_BR, 0.05, rnd)
# рука, поднятая с факелом (вперёд-вверх, +Z)
m.box(0.15, 0.2, 6.7, 0.22, 0.22, 1.0, BRONZE, rnd=rnd)
m.box(0.15, 0.35, 7.7, 0.2, 0.5, 0.65, BRONZE, rnd=rnd)
# факел-огонь (яркая вершина)
for k, rr in enumerate((0.30, 0.20, 0.11)):
    ybase = 8.35 + k * 0.15
    for i in range(6):
        a = i * math.tau / 6
        p0 = (0.15 + math.cos(a) * rr, ybase, 0.35 + math.sin(a) * rr * 0.8)
        p1 = (0.15 + math.cos(a + math.tau / 6) * rr, ybase, 0.35 + math.sin(a + math.tau / 6) * rr * 0.8)
        m.tri(p0, p1, (0.15, 8.95, 0.35), (1.0, 0.85 - k * 0.1, 0.35), 0.06, rnd)
m.to_glb(os.path.join(OUT, 'prometheus.glb'), 'Prometheus')

# ============ 3. Градирня (H=150, низ D=110, верх D=70, полость) ============
m = MeshBuilder()
SEG = 18
HB, HT = 150.0, 150.0
RB, RT = 55.0, 35.0
WALL = 1.8
outer = []
inner = []
for i in range(SEG + 1):
    k = i / SEG
    r = RB + (RT - RB) * k
    outer.append((r, HB * k))
    inner.append((max(1.0, r - WALL), HB * k + 0.01))
m2 = MeshBuilder()
for i in range(SEG):
    a0 = math.tau * i / SEG
    a1 = math.tau * (i + 1) / SEG
    y0, y1 = 0.0, HT
    r0o, r1o = RB, RT
    r0i, r1i = RB - WALL, RT - WALL
    c_out = (0.60, 0.60, 0.57)
    c_in = (0.40, 0.40, 0.38)
    # внешняя стена
    m2.quad((r0o * math.cos(a0), y0, r0o * math.sin(a0)),
            (r0o * math.cos(a1), y0, r0o * math.sin(a1)),
            (r1o * math.cos(a1), y1, r1o * math.sin(a1)),
            (r1o * math.cos(a0), y1, r1o * math.sin(a0)), c_out, 0.05, rnd)
    # внутренняя стена (нормаль внутрь — обратный порядок)
    m2.quad((r1i * math.cos(a1), y0, r1i * math.sin(a1)),
            (r1i * math.cos(a0), y0, r1i * math.sin(a0)),
            (r0i * math.cos(a0), y1, r0i * math.sin(a0)),
            (r0i * math.cos(a1), y1, r1i * math.sin(a1)), c_in, 0.05, rnd)
    # верхний обод
    m2.quad((r0i * math.cos(a0), y1, r0i * math.sin(a0)),
            (r0i * math.cos(a1), y1, r0i * math.sin(a1)),
            (r1o * math.cos(a1), y1, r1o * math.sin(a1)),
            (r1o * math.cos(a0), y1, r1o * math.sin(a0)), (0.5, 0.5, 0.47), 0.05, rnd)
m2.to_glb(os.path.join(OUT, 'cooling_tower.glb'), 'CoolingTower')
print('готово')
