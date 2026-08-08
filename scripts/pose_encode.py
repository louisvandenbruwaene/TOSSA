"""Encode a pose as the SMALLEST lossless PNG, for handing to PixelLab.

WHY THIS EXISTS. The MCP tools take images as inline base64 and their own docs warn that
clients truncate large blobs. An RGBA PNG of the performer is ~12.5k base64 characters; the
same picture as a PALETTE png with a transparency index is ~5k, because pixel art is 43
colours and one byte per pixel rather than four. Alpha here is strictly 0 or 255, so an
index is exactly as faithful as a channel - verified per call below, and it refuses to emit
anything it cannot prove identical.
"""
import base64
import io
import sys
import numpy as np
from PIL import Image


def encode(path, crop=True):
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im)
    if crop:
        ys, xs = np.where(a[..., 3] > 0)
        im = im.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
        a = np.asarray(im)
    if not set(np.unique(a[..., 3]).tolist()) <= {0, 255}:
        raise SystemExit(f"{path}: alpha is not binary; a palette index cannot carry it")
    alpha = a[..., 3]
    cols = np.unique(a[..., :3][alpha > 0].reshape(-1, 3), axis=0)
    if len(cols) > 255:
        raise SystemExit(f"{path}: {len(cols)} colours, too many for one palette")
    lut = {tuple(c): i for i, c in enumerate(cols.tolist())}
    idx = np.full(alpha.shape, len(cols), np.uint8)          # last index = transparent
    op = alpha > 0
    flat = a[..., :3][op]
    idx[op] = [lut[tuple(c)] for c in flat.tolist()]
    pal = cols.astype(np.uint8).reshape(-1).tolist() + [0, 0, 0]
    p = Image.fromarray(idx, "P")
    p.putpalette(pal + [0] * (768 - len(pal)))
    buf = io.BytesIO()
    p.save(buf, "PNG", optimize=True, compress_level=9, transparency=len(cols))
    raw = buf.getvalue()
    # prove it round-trips before anyone sends it anywhere
    rt = np.asarray(Image.open(io.BytesIO(raw)).convert("RGBA"))
    assert rt.shape == a.shape, (rt.shape, a.shape)
    assert ((rt[..., 3] > 0) == op).all(), "alpha changed"
    assert not np.any(rt[..., :3][op] != a[..., :3][op]), "colour changed"
    return raw, base64.b64encode(raw).decode(), im.size, len(cols)


if __name__ == "__main__":
    for p in sys.argv[1:]:
        raw, b, size, n = encode(p)
        print(f"{p}: {size[0]}x{size[1]}, {n} colours, {len(raw)} bytes, {len(b)} b64 chars  [verified lossless]")
