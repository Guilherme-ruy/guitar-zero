"""Precompute the hero's approved white-background mask without RGB re-encoding.

Requires Pillow and NumPy. The CLI derives a new v4 sequence from an existing
v3 directory; the MP4 converter also uses these helpers for direct reproduction.
WebP container: https://developers.google.com/speed/webp/docs/riff_container
"""

import argparse
import io
import json
from pathlib import Path
import shutil
import struct

import numpy as np
from PIL import Image


ALPHA_METADATA = {
    'alphaPrecomputed': True,
    'alpha': {
        'background': 'edge-connected studio white',
        'minChannel': 240,
        'maxChannelSpread': 14,
        'connectivity': 4,
        'values': [0, 255],
        'encoding': 'lossless WebP ALPH; Pillow method=1, alpha_quality=100',
        'rgb': 'original FFmpeg Q88 VP8 chunk preserved byte-for-byte',
        'processing': 'threshold after WebP decode; NumPy row spans and union-find',
        'implementation': 'site/tools/prepare_hero_alpha.py',
    },
}


def webp_chunks(data):
    """Read complete, padded RIFF chunks; reject malformed or duplicate chunks."""
    if (len(data) < 12 or data[:4] != b'RIFF' or data[8:12] != b'WEBP'
            or len(data) != struct.unpack_from('<I', data, 4)[0] + 8):
        raise ValueError('Invalid WebP RIFF header')
    offset = 12
    result = {}
    while offset < len(data):
        if offset + 8 > len(data):
            raise ValueError('Truncated WebP chunk header')
        code = data[offset:offset + 4]
        length = struct.unpack_from('<I', data, offset + 4)[0]
        end = offset + 8 + length + (length & 1)
        if end > len(data) or code in result or (length & 1 and data[end - 1] != 0):
            raise ValueError('Invalid WebP chunk')
        result[code] = data[offset:end]
        offset = end
    return result


def foreground_alpha(rgb):
    """Return the same binary, four-connected mask as the former UI worker."""
    low = rgb.min(axis=2)
    high = rgb.max(axis=2)
    eligible = (low >= 240) & (high - low <= 14)
    height, width = eligible.shape
    parents = []
    edge = []
    rows = []
    previous = []

    def find(index):
        while parents[index] != index:
            parents[index] = parents[parents[index]]
            index = parents[index]
        return index

    def union(left, right):
        left, right = find(left), find(right)
        if left != right:
            parents[right] = left
            edge[left] = edge[left] or edge[right]

    padded = np.zeros(width + 2, dtype=np.int8)
    for y in range(height):
        padded[1:-1] = eligible[y]
        changes = np.diff(padded)
        starts = np.flatnonzero(changes == 1)
        ends = np.flatnonzero(changes == -1)
        current = []
        prev_index = 0
        for x0, x1 in zip(starts.tolist(), ends.tolist()):
            component = len(parents)
            parents.append(component)
            edge.append(y == 0 or y == height - 1 or x0 == 0 or x1 == width)
            current.append((x0, x1, component))
            while prev_index < len(previous) and previous[prev_index][1] <= x0:
                prev_index += 1
            overlap = prev_index
            while overlap < len(previous) and previous[overlap][0] < x1:
                union(component, previous[overlap][2])
                overlap += 1
        rows.append(current)
        previous = current

    alpha = np.full((height, width), 255, dtype=np.uint8)
    for y, spans in enumerate(rows):
        for x0, x1, component in spans:
            if edge[find(component)]:
                alpha[y, x0:x1] = 0
    return alpha


def precompute_alpha(data):
    """Attach lossless ALPH to a plain lossy WebP, retaining its complete VP8."""
    original = webp_chunks(data)
    if list(original) != [b'VP8 ']:
        raise ValueError('Expected a plain FFmpeg VP8 WebP without existing alpha')
    with Image.open(io.BytesIO(data)) as image:
        rgb = np.array(image.convert('RGB'))
    alpha = foreground_alpha(rgb)
    height, width = alpha.shape
    fake = Image.new('RGBA', (width, height), (0, 0, 0, 255))
    fake.putalpha(Image.fromarray(alpha))
    buffer = io.BytesIO()
    # Encode only a disposable black RGB plane. Its VP8 is discarded below;
    # ALPH stays lossless, and the approved guitar's VP8 never gets re-encoded.
    fake.save(buffer, format='WEBP', lossless=False, quality=0, method=1, alpha_quality=100)
    encoded = webp_chunks(buffer.getvalue())
    if b'ALPH' not in encoded or not encoded[b'VP8X'][8] & 0x10:
        raise ValueError('Encoder did not produce an alpha subchunk')
    body = b'WEBP' + encoded[b'VP8X'] + encoded[b'ALPH'] + original[b'VP8 ']
    return b'RIFF' + struct.pack('<I', len(body)) + body


def prepare_sequence(source, output):
    """Derive a complete new v4 directory from the approved v3 WebPs."""
    source = source.resolve(strict=True)
    output = output.resolve()
    if output.exists():
        raise ValueError('Use a new output directory to avoid mixing asset versions')
    manifest = json.loads((source / 'manifest.json').read_text(encoding='utf-8'))
    if (manifest.get('assetVersion') != 3 or manifest.get('frameCount') != 70
            or [variant['width'] for variant in manifest['variants']] != [960, 1440, 1920]):
        raise ValueError('Expected the approved v3 sequence: 70 frames at 960/1440/1920')
    output.mkdir(parents=True)
    expected = [f'frame-{index:03d}.webp' for index in range(70)]
    for variant in manifest['variants']:
        width, height = variant['width'], variant['height']
        if variant['quality'] != 88 or height != width * 9 // 16:
            raise ValueError('Unexpected source dimensions or quality')
        frames = sorted((source / str(width)).glob('frame-*.webp'))
        if [frame.name for frame in frames] != expected:
            raise ValueError(f'Incomplete source sequence: {width}')
        directory = output / str(width)
        directory.mkdir()
        for frame in frames:
            data = frame.read_bytes()
            with Image.open(io.BytesIO(data)) as image:
                if image.size != (width, height):
                    raise ValueError(f'Unexpected dimensions: {frame}')
            (directory / frame.name).write_bytes(precompute_alpha(data))
        variant['bytes'] = sum(frame.stat().st_size for frame in directory.glob('frame-*.webp'))
        print(f'Prepared {width}: 70 frames, {variant["bytes"]} bytes', flush=True)
    shutil.copyfile(output / '1440/frame-000.webp', output / 'poster.webp')
    manifest.update({'assetVersion': 4, **ALPHA_METADATA})
    manifest['poster']['bytes'] = (output / 'poster.webp').stat().st_size
    (output / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True, help='Approved v3 sequence directory')
    parser.add_argument('--output', type=Path, required=True, help='New v4 staging directory')
    args = parser.parse_args()
    try:
        manifest = prepare_sequence(args.source, args.output)
    except ValueError as error:
        parser.error(str(error))
    print(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
