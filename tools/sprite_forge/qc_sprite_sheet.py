#!/usr/bin/env python3
"""Validate a transparent horizontal sprite sheet without generating art."""
import argparse, json, sys
from pathlib import Path
from PIL import Image

def alpha_bbox(alpha):
    return alpha.getbbox()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', required=True)
    parser.add_argument('--frames', required=True, type=int)
    parser.add_argument('--frame-width', required=True, type=int)
    parser.add_argument('--frame-height', required=True, type=int)
    parser.add_argument('--feet-y', type=int, help='Required shared feet anchor for grounded actions; omit for airborne actions.')
    parser.add_argument('--min-visible-height', type=int, default=48)
    parser.add_argument('--max-visible-height', type=int, default=72)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    image = Image.open(args.input).convert('RGBA')
    expected = (args.frame_width * args.frames, args.frame_height)
    errors, report = [], {'input': str(args.input), 'expected_size': expected, 'actual_size': image.size, 'frames': []}
    if image.size != expected:
        errors.append(f'sheet size {image.size} does not match {expected}')
    for index in range(args.frames):
        left = index * args.frame_width
        frame = image.crop((left, 0, left + args.frame_width, args.frame_height))
        alpha = frame.getchannel('A')
        bbox = alpha_bbox(alpha)
        frame_report = {'index': index, 'bbox': bbox, 'valid': True}
        if bbox is None:
            errors.append(f'frame {index} is empty')
            frame_report['valid'] = False
        else:
            x0, y0, x1, y1 = bbox
            height = y1 - y0
            touches = x0 == 0 or y0 == 0 or x1 == args.frame_width or y1 == args.frame_height
            frame_report.update({'visible_height': height, 'feet_y': y1 - 1, 'touches_edge': touches})
            if touches:
                errors.append(f'frame {index} alpha touches edge')
                frame_report['valid'] = False
            if not args.min_visible_height <= height <= args.max_visible_height:
                errors.append(f'frame {index} visible height {height} outside range')
                frame_report['valid'] = False
            if args.feet_y is not None and abs((y1 - 1) - args.feet_y) > 1:
                errors.append(f'frame {index} feet y {y1 - 1} differs from {args.feet_y}')
                frame_report['valid'] = False
        report['frames'].append(frame_report)
    report['passed'] = not errors
    report['errors'] = errors
    Path(args.output).write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report['passed'] else 2

if __name__ == '__main__':
    sys.exit(main())