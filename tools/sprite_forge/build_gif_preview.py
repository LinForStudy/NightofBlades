#!/usr/bin/env python3
"""Build a review GIF from already-extracted transparent PNG frames."""
import argparse
from pathlib import Path
from PIL import Image

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--frames-dir', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--duration-ms', type=int, default=140)
    args = parser.parse_args()
    frame_paths = sorted(path for path in Path(args.frames_dir).glob('*.png') if path.stem.rsplit('-', 1)[-1].isdigit())
    frames = [Image.open(path).convert('RGBA') for path in frame_paths]
    if not frames:
        raise SystemExit('No PNG frames found; GIF was not created.')
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(args.output, save_all=True, append_images=frames[1:], duration=args.duration_ms, loop=0, disposal=2)
    print(f'Wrote {args.output} with {len(frames)} frames')

if __name__ == '__main__':
    main()