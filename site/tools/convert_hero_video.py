"""Convert the approved 8-second Flow clip into the site's WebP sequence.

Requires FFmpeg/ffprobe on PATH, Pillow and NumPy. Output must be a new staging
directory. Background alpha is precomputed without re-encoding the VP8 RGB.
"""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

from prepare_hero_alpha import ALPHA_METADATA, precompute_alpha


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    source = args.source.resolve(strict=True)
    output = args.output.resolve()
    if output.exists():
        parser.error('Use a new output directory to avoid mixing asset versions.')

    probe = json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-select_streams', 'v:0',
        '-show_entries', 'stream=width,height,r_frame_rate:format=duration',
        '-of', 'json', str(source),
    ], text=True))
    stream = probe['streams'][0]
    numerator, denominator = map(int, stream['r_frame_rate'].split('/'))
    source_fps = numerator / denominator
    duration = float(probe['format']['duration'])
    if (stream['width'], stream['height']) != (1920, 1080) or source_fps != 24 or abs(duration - 8) > .05:
        parser.error('Expected the approved 1920x1080, 24fps, 8-second source.')

    output.mkdir(parents=True)
    variants = []
    for width, height, quality in [(960, 540, 88), (1440, 810, 88), (1920, 1080, 88)]:
        directory = output / str(width)
        directory.mkdir()
        subprocess.run([
            'ffmpeg', '-hide_banner', '-loglevel', 'error', '-n',
            '-ss', '1', '-i', str(source), '-an',
            '-vf', f'fps=10,scale={width}:{height}:flags=lanczos',
            '-frames:v', '70', '-c:v', 'libwebp', '-quality', str(quality),
            '-compression_level', '6', '-start_number', '0',
            str(directory / 'frame-%03d.webp'),
        ], check=True)
        frames = sorted(directory.glob('frame-*.webp'))
        expected = [f'frame-{index:03d}.webp' for index in range(70)]
        if [frame.name for frame in frames] != expected:
            raise RuntimeError(f'Incomplete sequence: {directory}')
        for frame in frames:
            frame.write_bytes(precompute_alpha(frame.read_bytes()))
        variants.append({
            'width': width, 'height': height,
            'path': f'{width}/frame-{{index:03d}}.webp',
            'quality': quality, 'bytes': sum(frame.stat().st_size for frame in frames),
        })

    shutil.copyfile(output / '1440/frame-000.webp', output / 'poster.webp')
    manifest = {
        'assetVersion': 4,
        **ALPHA_METADATA,
        'sourceFile': source.name,
        'sourceSha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'sourceWidth': stream['width'], 'sourceHeight': stream['height'],
        'frameCount': 70, 'sourceFps': source_fps, 'sequenceFps': 10,
        'sourceDurationSeconds': duration,
        'trimStartSeconds': 1, 'trimDurationSeconds': 7,
        'sampling': 'FFmpeg fps=10 after input trim, Lanczos scaling',
        'variants': variants,
        'poster': {'width': 1440, 'height': 810, 'frameIndex': 0, 'bytes': (output / 'poster.webp').stat().st_size},
    }
    (output / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
