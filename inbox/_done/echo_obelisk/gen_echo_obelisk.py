# -*- coding: utf-8 -*-
# ЗАДАЧА 35: Эхо-обелиск — стела 7 м, тёмный камень, фиолетовые руны
# с эмиссией (второй материал glTF с emissiveFactor). Origin в основании, +Z фронт.
import json
import math
import random
import struct

OUT = r'E:\StalkerRevert\StalkerRevert\inbox\echo_obelisk\echo_obelisk.glb'


class Builder:
    """GLB с несколькими материалами: группы примитивов по mat_idx."""

    def __init__(self):
        self.pos, self.nrm, self.col = [], [], []
        self.groups = {}   # mat_idx -> список индексов

    def _tri(self, a, b, c, mat, color, jitter, rnd):
        ux, uy, uz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
        vx, vy, vz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
        nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
        ln = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
        sh = 1.0 + (rnd.uniform(-jitter, jitter) if rnd else 0.0)
        col = tuple(min(1.0, max(0.0, v * sh)) for v in color)
        base = len(self.pos)
        for p in (a, b, c):
            self.pos.append(p)
            self.nrm.append((nx / ln, ny / ln, nz / ln))
            self.col.append(col)
        self.groups.setdefault(mat, []).extend((base, base + 1, base + 2))

    def quad(self, a, b, c, d, mat, color, jitter=0.04, rnd=None):
        self._tri(a, b, c, mat, color, jitter, rnd)
        self._tri(a, c, d, mat, color, jitter, rnd)

    def box(self, cx, y0, cz, w, d, h, mat, color, jitter=0.04, rnd=None):
        x0, x1 = cx - w / 2, cx + w / 2
        z0, z1 = cz - d / 2, cz + d / 2
        y1 = y0 + h
        self.quad((x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1), mat, color, jitter, rnd)
        self.quad((x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0), mat, color, jitter, rnd)
        self.quad((x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1), mat, color, jitter, rnd)
        self.quad((x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0), mat, color, jitter, rnd)
        self.quad((x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0), mat, color, jitter, rnd)

    def obelisk_body(self, rnd):
        """Стела: сужающийся 4-гранный шпиль на ступенчатом основании. Мат 0 = камень."""
        STONE = (0.16, 0.15, 0.19)
        STONE2 = (0.13, 0.12, 0.16)
        # основание: три ступени
        self.box(0, 0.0, 0, 3.2, 3.2, 0.5, 0, STONE2, rnd=rnd)
        self.box(0, 0.5, 0, 2.5, 2.5, 0.45, 0, STONE, rnd=rnd)
        self.box(0, 0.95, 0, 1.9, 1.9, 0.4, 0, STONE2, rnd=rnd)
        # ствол с сужением (4 грани, ярусами по 0.7 м)
        y = 1.35
        half0 = 0.62
        n_tier = 8
        for i in range(n_tier):
            h = 0.7
            h0 = half0 * (1.0 - i / n_tier * 0.62)
            h1 = half0 * (1.0 - (i + 1) / n_tier * 0.62)
            col = STONE if i % 2 == 0 else STONE2
            z0, z1 = -h0, h0
            z2, z3 = -h1, h1
            yy1 = y + h
            self.quad((-h0, y, z0), (h0, y, z0), (h1, yy1, z2), (-h1, yy1, z2), 0, col, 0.03, rnd)   # -Z
            self.quad((h0, y, z1), (-h0, y, z1), (-h1, yy1, z3), (h1, yy1, z3), 0, col, 0.03, rnd)   # +Z
            self.quad((z1 and h0, y, 0 + z1 * 0 + (-h0) * 0 + h0 * 0 + 0 + (h0)) if False else (h0, y, h0 * 0 + z1),
                      (h0, y, -h0) if False else (h0, y, -h0),
                      (h1, yy1, -h1), (h1, yy1, h1), 0, col, 0.03, rnd)                              # +X
            self.quad((-h0, y, -h0), (-h0, y, h0), (-h1, yy1, h1), (-h1, yy1, -h1), 0, col, 0.03, rnd)  # -X
            y = yy1
        # пирамидальный наконечник
        tip_h = 0.5
        for (ax, az, bx, bz) in ((-h1, -h1, h1, -h1), (h1, -h1, h1, h1), (h1, h1, -h1, h1), (-h1, h1, -h1, -h1)):
            self._tri((ax, y, az), (bx, y, bz), (0, y + tip_h, 0), 0, STONE, 0.03, rnd)
        return y + tip_h

    def runes(self, rnd, top_y):
        """Руны: плоские пластины на гранях ствола, мат 1 = фиолетовая эмиссия."""
        RUNE = (0.72, 0.45, 1.0)
        y = 1.5
        i = 0
        while y < top_y - 1.2:
            for face in range(4):
                depth = 0.625 * (1.0 - ((y - 1.35) / (top_y - 1.35)) * 0.62) + 0.012
                ang = face * math.pi / 2
                fx, fz = math.sin(ang) * depth, math.cos(ang) * depth
                w, h = 0.09, 0.34
                # пластина-руна: вертикальная черта + точка
                if face in (0, 2):
                    self.box(fx, y, fz, w, 0.03, h, 1, RUNE, 0.05, rnd)
                else:
                    self.box(fx, y, fz, 0.03, w, h, 1, RUNE, 0.05, rnd)
                if i % 2 == 0:
                    dy = y + h + 0.12
                    if face in (0, 2):
                        self.box(fx, dy, fz, 0.07, 0.03, 0.07, 1, RUNE, 0.05, rnd)
                    else:
                        self.box(fx, dy, fz, 0.03, 0.07, 0.07, 1, RUNE, 0.05, rnd)
            y += 0.62
            i += 1

    def to_glb(self, path, name):
        blob = b''
        views = []

        def add(data, target=None):
            nonlocal blob
            while len(blob) % 4:
                blob += b'\0'
            views.append({'buffer': 0, 'byteOffset': len(blob), 'byteLength': len(data),
                          **({'target': target} if target else {})})
            blob += data
            return len(views) - 1

        v_pos = add(b''.join(struct.pack('<3f', *p) for p in self.pos), 34962)
        v_nrm = add(b''.join(struct.pack('<3f', *p) for p in self.nrm), 34962)
        v_col = add(b''.join(struct.pack('<3f', *p) for p in self.col), 34962)
        idx_all = []
        # примитивы: mat0 (камень), mat1 (руны)
        prim_idx_views = []
        for mat in sorted(self.groups):
            ids = self.groups[mat]
            vi = add(b''.join(struct.pack('<I', i) for i in ids), 34963)
            prim_idx_views.append((vi, len(ids), mat))
        minp = [min(p[i] for p in self.pos) for i in range(3)]
        maxp = [max(p[i] for p in self.pos) for i in range(3)]
        primitives = []
        acc_offset = 0
        for vi, count, mat in prim_idx_views:
            primitives.append({'attributes': {'POSITION': v_pos, 'NORMAL': v_nrm, 'COLOR_0': v_col},
                               'indices': vi, 'material': mat, 'mode': 4})
            acc_offset += 1
        gltf = {
            'asset': {'version': '2.0', 'generator': 'StalkerRevert preparer (procedural)'},
            'scene': 0, 'scenes': [{'nodes': [0]}],
            'nodes': [{'name': name, 'mesh': 0}],
            'meshes': [{'primitives': primitives}],
            'materials': [
                {'name': 'dark_stone', 'doubleSided': True,
                 'pbrMetallicRoughness': {'baseColorFactor': [1, 1, 1, 1], 'metallicFactor': 0.0,
                                          'roughnessFactor': 0.95}},
                {'name': 'rune_echo', 'doubleSided': True,
                 'pbrMetallicRoughness': {'baseColorFactor': [1, 1, 1, 1], 'metallicFactor': 0.0,
                                          'roughnessFactor': 0.4},
                 'emissiveFactor': [0.62, 0.36, 1.0]},
            ],
            'buffers': [{'byteLength': len(blob)}],
            'bufferViews': views,
            'accessors': [
                {'bufferView': v_pos, 'componentType': 5126, 'count': len(self.pos), 'type': 'VEC3',
                 'min': minp, 'max': maxp},
                {'bufferView': v_nrm, 'componentType': 5126, 'count': len(self.nrm), 'type': 'VEC3'},
                {'bufferView': v_col, 'componentType': 5126, 'count': len(self.col), 'type': 'VEC3'},
            ] + [
                {'bufferView': vi, 'componentType': 5125, 'count': cnt, 'type': 'SCALAR'}
                for vi, cnt, _ in prim_idx_views
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
        tris = sum(len(v) for v in self.groups.values()) // 3
        print(f"{os.path.basename(path):22} {tris} трис, высота {maxp[1]-minp[1]:.2f} м, {len(out)//1024} КБ")


if __name__ == '__main__':
    import os
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    rnd = random.Random(35)
    b = Builder()
    top = b.obelisk_body(rnd)
    b.runes(rnd, top)
    b.to_glb(OUT, 'EchoObelisk')
