"""Reachability checker for Shadow Swap layouts.
Models player as a point vs barrier rects grown by the player radius (10 px),
and the game's swap rule: swap refused if any barrier solid in the NEW realm
has rect.grow(12) containing the player centre.
BFS over (x, y, realm) on a 4 px grid."""
import re, sys, numpy as np
from collections import deque

STEP = 4
R = 10.0
X0, X1, Y0, Y1 = 32, 928, 112, 600

def parse_stages(path):
    txt = open(path).read()
    stages = {}
    for m in re.finditer(r'^\t(\d+): \{(.*?)^\t\},?$', txt, re.S | re.M):
        n = int(m.group(1)); body = m.group(2)
        def vec(key):
            mm = re.search(r'"%s":\s*Vector2\(([-\d.]+),\s*([-\d.]+)\)' % key, body)
            return (float(mm.group(1)), float(mm.group(2)))
        shards = re.findall(r'Vector2\(([-\d.]+),\s*([-\d.]+)\)', re.search(r'"shards":\s*\[(.*?)\]', body, re.S).group(1))
        barriers = [(tuple(map(float, r.groups()[:4])), int(r.group(5)))
                    for r in re.finditer(r'Rect2\(([-\d.]+),\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+)\),\s*"realm":\s*(-?\d)', body)]
        stages[n] = dict(checkpoint=vec("checkpoint"), portal=vec("portal"),
                         shards=[(float(a), float(b)) for a, b in shards], barriers=barriers)
    return stages

def solid_mask(xs, ys, barriers, realm, grow):
    X, Y = np.meshgrid(xs, ys, indexing="ij")
    m = np.zeros_like(X, dtype=bool)
    for (x, y, w, h), br in barriers:
        if br == -1 or br == realm:
            m |= (X > x - grow) & (X < x + w + grow) & (Y > y - grow) & (Y < y + h + grow)
    return m

def check(stage):
    xs = np.arange(X0, X1 + 1, STEP, dtype=float); ys = np.arange(Y0, Y1 + 1, STEP, dtype=float)
    bars = stage["barriers"]
    blocked = [solid_mask(xs, ys, bars, r, R) for r in (0, 1)]
    swapblock = [solid_mask(xs, ys, bars, r, 12.0) for r in (0, 1)]
    def idx(p): return (int(round((p[0] - X0) / STEP)), int(round((p[1] - Y0) / STEP)))
    sx, sy = idx(stage["checkpoint"])
    if blocked[0][sx, sy]: return {"error": "start blocked"}
    seen = np.zeros((2,) + blocked[0].shape, dtype=bool)
    seen[0, sx, sy] = True
    dq = deque([(0, sx, sy)])
    while dq:
        r, x, y = dq.popleft()
        for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
            nx, ny = x+dx, y+dy
            if 0 <= nx < blocked[r].shape[0] and 0 <= ny < blocked[r].shape[1] and not blocked[r][nx, ny] and not seen[r, nx, ny]:
                seen[r, nx, ny] = True; dq.append((r, nx, ny))
        o = 1 - r
        if not swapblock[o][x, y] and not blocked[o][x, y] and not seen[o, x, y]:
            seen[o, x, y] = True; dq.append((o, x, y))
    reach = seen[0] | seen[1]
    def reachable(p, rad):
        X, Y = np.meshgrid(xs, ys, indexing="ij")
        return bool(((X - p[0])**2 + (Y - p[1])**2 <= rad**2)[reach].any())
    out = {"shards": [reachable(s, 25) for s in stage["shards"]], "portal": reachable(stage["portal"], 58)}
    out["shard_in_barrier"] = [bool(any(((x-R)<=s[0]<=(x+w+R)) and ((y-R)<=s[1]<=(y+h+R)) for (x,y,w,h), br in bars if br == -1)) for s in stage["shards"]]
    # which shards need which realm?
    return out

if __name__ == "__main__":
    st = parse_stages(sys.argv[1])
    ok = True
    for n, s in sorted(st.items()):
        r = check(s); print("stage", n, r)
        if "error" in r or not all(r["shards"]) or not r["portal"]: ok = False
    sys.exit(0 if ok else 1)

def min_swaps(stage):
    """0-1 BFS: minimum number of realm swaps needed to reach each shard/portal."""
    from collections import deque
    xs = np.arange(X0, X1 + 1, STEP, dtype=float); ys = np.arange(Y0, Y1 + 1, STEP, dtype=float)
    bars = stage["barriers"]
    blocked = [solid_mask(xs, ys, bars, r, R) for r in (0, 1)]
    swapblock = [solid_mask(xs, ys, bars, r, 12.0) for r in (0, 1)]
    INF = 10**6
    dist = np.full((2,) + blocked[0].shape, INF, dtype=int)
    sx = int(round((stage["checkpoint"][0]-X0)/STEP)); sy = int(round((stage["checkpoint"][1]-Y0)/STEP))
    dist[0, sx, sy] = 0
    dq = deque([(0, sx, sy)])
    while dq:
        r, x, y = dq.popleft(); d = dist[r, x, y]
        for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
            nx, ny = x+dx, y+dy
            if 0 <= nx < blocked[r].shape[0] and 0 <= ny < blocked[r].shape[1] and not blocked[r][nx, ny] and dist[r, nx, ny] > d:
                dist[r, nx, ny] = d; dq.appendleft((r, nx, ny))
        o = 1 - r
        if not swapblock[o][x, y] and not blocked[o][x, y] and dist[o, x, y] > d + 1:
            dist[o, x, y] = d + 1; dq.append((o, x, y))
    X, Y = np.meshgrid(xs, ys, indexing="ij")
    best = np.minimum(dist[0], dist[1])
    def need(p, rad):
        m = (X - p[0])**2 + (Y - p[1])**2 <= rad**2
        return int(best[m].min()) if m.any() else None
    return {"shards": [need(s, 25) for s in stage["shards"]], "portal": need(stage["portal"], 58)}
