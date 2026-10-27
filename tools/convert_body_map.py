"""Convert react-native-body-highlighter 3.2.0 male front/back SVG paths into dense polygons for app/lib/muscle_shapes.dart.
Reads only the path strings (text); runs none of the package's code."""
import math, re, sys

SRC, OUT = sys.argv[1], sys.argv[2]

FRONT = {
    'chest': ('Chest', 'Chest'), 'obliques': ('Core', 'Obliques'), 'abs': ('Core', 'Abs'),
    'biceps': ('Arms', 'Biceps'), 'triceps': ('Arms', 'Triceps'), 'forearm': ('Arms', 'Forearms'),
    'deltoids': ('Shoulders', 'Front shoulders'), 'trapezius': ('Back', 'Trapezius'),
    'adductors': ('Hips and glutes', 'Adductors'), 'quadriceps': ('Thighs', 'Quadriceps'),
    'tibialis': ('Calves', 'Tibialis'), 'calves': ('Calves', 'Calves'),
}
BACK = {
    'trapezius': ('Back', 'Trapezius'), 'upper-back': ('Back', 'Upper back'), 'lower-back': ('Back', 'Lower back'),
    'deltoids': ('Shoulders', 'Rear shoulders'), 'triceps': ('Arms', 'Triceps'), 'forearm': ('Arms', 'Forearms'),
    'gluteal': ('Hips and glutes', 'Glutes'), 'hamstring': ('Thighs', 'Hamstrings'),
    'adductors': ('Hips and glutes', 'Adductors'), 'calves': ('Calves', 'Calves'),
}
NON_SELECTABLE = {'head', 'hair', 'neck', 'hands', 'feet', 'ankles', 'knees'}
WS = ' ,\n\t\r'
NUM = re.compile(r'[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?')


def entries(js):
    """[(slug, [path strings])] in file order: split the file at each slug."""
    parts = re.split(r'slug:\s*"([a-z-]+)"', js)
    return [(parts[k], re.findall(r'"(M[^"]*)"', parts[k + 1])) for k in range(1, len(parts), 2)]


def arc_points(x1, y1, rx, ry, phi, fa, fs, x2, y2, n=10):
    if rx == 0 or ry == 0:
        return [(x2, y2)]
    phi = math.radians(phi)
    cp, sp = math.cos(phi), math.sin(phi)
    dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
    x1p, y1p = cp * dx + sp * dy, -sp * dx + cp * dy
    rx, ry = abs(rx), abs(ry)
    lam = x1p ** 2 / rx ** 2 + y1p ** 2 / ry ** 2
    if lam > 1:
        rx, ry = rx * math.sqrt(lam), ry * math.sqrt(lam)
    num = rx ** 2 * ry ** 2 - rx ** 2 * y1p ** 2 - ry ** 2 * x1p ** 2
    den = rx ** 2 * y1p ** 2 + ry ** 2 * x1p ** 2
    co = math.sqrt(max(0.0, num / den)) if den else 0.0
    if fa == fs:
        co = -co
    cxp, cyp = co * rx * y1p / ry, -co * ry * x1p / rx
    cx = cp * cxp - sp * cyp + (x1 + x2) / 2
    cy = sp * cxp + cp * cyp + (y1 + y2) / 2
    ang = lambda ux, uy, vx, vy: math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
    t1 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    dt = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if not fs and dt > 0:
        dt -= 2 * math.pi
    elif fs and dt < 0:
        dt += 2 * math.pi
    pts = []
    for k in range(1, n + 1):
        t = t1 + dt * k / n
        ex, ey = rx * math.cos(t), ry * math.sin(t)
        pts.append((cp * ex - sp * ey + cx, sp * ex + cp * ey + cy))
    return pts


class Reader:
    """Character-level SVG path reader: numbers like '1.5.5' or '-2-3', and single-digit arc flags."""
    def __init__(self, d):
        self.d, self.i = d, 0
    def skip(self):
        while self.i < len(self.d) and self.d[self.i] in WS:
            self.i += 1
    def done(self):
        self.skip()
        return self.i >= len(self.d)
    def at_cmd(self):
        self.skip()
        return self.i < len(self.d) and self.d[self.i].isalpha()
    def cmd(self):
        self.skip()
        c = self.d[self.i]
        self.i += 1
        return c
    def num(self):
        self.skip()
        m = NUM.match(self.d, self.i)
        if not m:
            raise ValueError('number expected at %d: %r' % (self.i, self.d[self.i:self.i + 12]))
        self.i = m.end()
        return float(m.group())
    def flag(self):
        self.skip()
        c = self.d[self.i]
        self.i += 1
        if c not in '01':
            raise ValueError('arc flag expected')
        return int(c)


def parse(d, n=8):
    """Polygons for one path string; curves sampled n points per segment."""
    r = Reader(d)
    cmd = None
    x = y = sx = sy = 0.0
    polys, cur = [], []
    while not r.done():
        if r.at_cmd():
            cmd = r.cmd()
            if cmd in 'Zz':
                if cur:
                    polys.append(cur)
                cur = []
                x, y = sx, sy
                continue
        c = cmd
        if c in 'Mm':
            nx, ny = r.num(), r.num()
            if c == 'm':
                nx, ny = x + nx, y + ny
            if cur:
                polys.append(cur)
            x, y = sx, sy = nx, ny
            cur = [(x, y)]
            cmd = 'l' if c == 'm' else 'L'
        elif c in 'Ll':
            nx, ny = r.num(), r.num()
            if c == 'l':
                nx, ny = x + nx, y + ny
            x, y = nx, ny
            cur.append((x, y))
        elif c in 'Hh':
            v = r.num()
            x = x + v if c == 'h' else v
            cur.append((x, y))
        elif c in 'Vv':
            v = r.num()
            y = y + v if c == 'v' else v
            cur.append((x, y))
        elif c in 'Cc':
            p = [r.num() for _ in range(6)]
            if c == 'c':
                p = [p[0] + x, p[1] + y, p[2] + x, p[3] + y, p[4] + x, p[5] + y]
            x0, y0 = x, y
            for k in range(1, n + 1):
                t = k / n
                u = 1 - t
                cur.append((u ** 3 * x0 + 3 * u * u * t * p[0] + 3 * u * t * t * p[2] + t ** 3 * p[4],
                            u ** 3 * y0 + 3 * u * u * t * p[1] + 3 * u * t * t * p[3] + t ** 3 * p[5]))
            x, y = p[4], p[5]
        elif c in 'Qq':
            p = [r.num() for _ in range(4)]
            if c == 'q':
                p = [p[0] + x, p[1] + y, p[2] + x, p[3] + y]
            x0, y0 = x, y
            for k in range(1, n + 1):
                t = k / n
                u = 1 - t
                cur.append((u * u * x0 + 2 * u * t * p[0] + t * t * p[2], u * u * y0 + 2 * u * t * p[1] + t * t * p[3]))
            x, y = p[2], p[3]
        elif c in 'Aa':
            rx, ry, phi = r.num(), r.num(), r.num()
            fa, fs = r.flag(), r.flag()
            nx, ny = r.num(), r.num()
            if c == 'a':
                nx, ny = x + nx, y + ny
            cur.extend(arc_points(x, y, rx, ry, phi, fa, fs, nx, ny))
            x, y = nx, ny
        else:
            raise ValueError('unsupported command ' + str(c))
    if cur:
        polys.append(cur)
    return [p for p in polys if len(p) >= 3]


def convert(js, x0, mapping):
    rows = []
    for slug, paths in entries(js):
        if slug in mapping:
            group, label = mapping[slug]
        elif slug in NON_SELECTABLE:
            group, label = None, slug.capitalize()
        else:
            raise ValueError('unmapped slug ' + slug)
        polys = []
        for d in paths:
            for poly in parse(d):
                flat = []
                for (px, py) in poly:
                    flat += [round((px - x0) / 724 * 100, 2), round(py / 1448 * 200, 2)]
                polys.append(flat)
        rows.append((group, label, polys))
    return rows


def emit(name, rows):
    out = ['const %s = <MuscleShape>[' % name]
    for group, label, polys in rows:
        g = 'null' if group is None else "'%s'" % group
        ps = ', '.join('[' + ', '.join('%g' % v for v in p) + ']' for p in polys)
        out.append("  (group: %s, label: '%s', polygons: [%s])," % (g, label, ps))
    out.append('];')
    return '\n'.join(out)


front = convert(open(SRC + '/bodyFront.js', encoding='utf-8').read(), 0, FRONT)
back = convert(open(SRC + '/bodyBack.js', encoding='utf-8').read(), 724, BACK)
# Non-selectable parts first, so muscles draw on top of the skin outline.
front.sort(key=lambda r: 0 if r[0] is None else 1)
back.sort(key=lambda r: 0 if r[0] is None else 1)
HDR = """// Body map outlines, front and back, on a 100 x 200 canvas. Converted from react-native-body-highlighter 3.2.0
// (male figure, dist/assets/bodyFront.js and bodyBack.js), MIT License, Copyright (c) 2022 ELABBASSI Hicham; the notice
// ships as assets/licenses/react-native-body-highlighter-LICENSE (Licences page). Converted 2026-10-28: SVG curves and
// arcs sampled into polygons, coordinates scaled from the 724 x 1448 view and rounded to 2 dp; only the outlines are
// used. group: the exercise guide's muscle group (exercise_guide.dart muscleRegions), null for parts that are drawn but
// not selectable. Each polygon is a flat list of x, y pairs.
// ignore_for_file: lines_longer_than_80_chars

typedef MuscleShape = ({String? group, String label, List<List<double>> polygons});

"""
open(OUT, 'w', encoding='utf-8', newline='\n').write(HDR + emit('frontMuscles', front) + '\n\n' + emit('backMuscles', back) + '\n')
print('front', [(r[1], len(r[2])) for r in front])
print('back', [(r[1], len(r[2])) for r in back])
