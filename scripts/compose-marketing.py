#!/usr/bin/env python3
"""Compose verified native Band Practice captures; stage the complete selection before publishing."""
import argparse
import copy
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parents[1]
SKILL = Path('/Users/keithbarney/.codex/skills/ios-app-store-screenshots')
SCREENS = [(2, 'day-detail', 'Find a time\nyour band can play.'),
           (1, 'calendar', 'See when\nyour band is free.'),
           (8, 'availability-automatic', 'Let your calendar\nfind free time.'),
           (8, 'availability-manual', 'Set the hours\nyou want to play.'),
           (3, 'settings', 'Keep rehearsals\nin your calendar.'),
           (11, 'band', 'Your bandmates.\nAll in one place.')]
GEOMETRY = {
    'iphone': dict(width=1320, height=2868, headlineTop=210, headlineSize=124,
                   headlineLineHeight=136, screenshotTop=700, screenshotWidth=1100,
                   frameWidth=14, cornerRadius=108),
    'ipad': dict(width=2064, height=2752, headlineTop=160, headlineSize=164,
                 headlineLineHeight=180, screenshotTop=650, screenshotWidth=1720,
                 frameWidth=22, cornerRadius=64),
}

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read_json(path):
    return json.loads(path.read_text())

def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')

def selection(value, allowed):
    values = value.split(',')
    if not values or len(set(values)) != len(values) or set(values) - set(allowed):
        raise ValueError(f'Invalid selection {value}; choose from {allowed}')
    return values

def filename(device, appearance, number, slug):
    return f'{number}-{device}-{appearance}-{slug}.png'

def contact_sheet(folder, device, appearance, output):
    thumb_w = 330
    thumb_h = round(thumb_w * GEOMETRY[device]['height'] / GEOMETRY[device]['width'])
    # Three columns keep headline and UI content legible without a very wide sheet.
    cols, gap, label_h = 3, 24, 36
    sheet = Image.new('RGB', (gap + cols * (thumb_w + gap), gap + 2 * (thumb_h + label_h + gap)), '#ececee')
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 18)
    for index, (number, slug, _) in enumerate(SCREENS):
        x, y = gap + (index % cols) * (thumb_w + gap), gap + (index // cols) * (thumb_h + label_h + gap)
        draw.text((x, y), f'{index + 1}. {slug.replace("-", " ").title()}', fill='#222222', font=font)
        with Image.open(folder / filename(device, appearance, number, slug)) as image:
            image.thumbnail((thumb_w, thumb_h), Image.Resampling.LANCZOS)
            sheet.paste(image, (x, y + label_h))
    sheet.save(output, quality=95)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-root', type=Path, required=True)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--devices', default='iphone,ipad')
    parser.add_argument('--appearances', default='light,dark')
    parser.add_argument('--screens', default=','.join(s for _, s, _ in SCREENS))
    parser.add_argument('--output-root', type=Path, default=REPO / 'screenshots')
    parser.add_argument('--publish', action='store_true', help='Publish staged, validated images and metadata; otherwise retain review staging.')
    args = parser.parse_args()
    devices = selection(args.devices, GEOMETRY)
    appearances = selection(args.appearances, ['light', 'dark'])
    slugs = selection(args.screens, [s for _, s, _ in SCREENS])
    if args.source_root.resolve() == args.output_root.resolve():
        raise ValueError('Native source root must be separate from the maintained marketing output root')
    raw_manifest = read_json(args.manifest)
    raw_entries = raw_manifest['images']
    if not isinstance(raw_entries, dict):
        raise ValueError('Expected native capture manifest images keyed by device/appearance/filename')
    output_manifest_path = args.output_root / 'manifest.json'
    output_manifest = read_json(output_manifest_path) if output_manifest_path.exists() else {'images': {}}
    # Migrate the earlier record-list manifest while preserving untouched entries.
    if 'images' not in output_manifest:
        output_manifest['images'] = {}
        for record in output_manifest.pop('records', []):
            key = record['file'].removeprefix('screenshots/')
            output_manifest['images'][key] = dict(record, sha256=record['outputSha256'])
    sources = []
    # Preflight every input before producing or replacing anything.
    for device in devices:
        for appearance in appearances:
            for number, slug, headline in SCREENS:
                if slug not in slugs:
                    continue
                key = f'{device}/{appearance}/{filename(device, appearance, number, slug)}'
                entry = raw_entries.get(key)
                source = args.source_root / key
                if not entry or entry.get('kind') == 'marketing' or entry.get('marketing') or entry.get('composition'):
                    raise ValueError(f'Expected verified raw native source, rejected: {key}')
                if not source.is_file() or digest(source) != entry.get('sha256'):
                    raise ValueError(f'Native source missing/hash mismatch: {key}')
                if entry.get('device') != device or entry.get('appearance') != appearance:
                    raise ValueError(f'Native device/appearance provenance mismatch: {key}')
                if not entry.get('capture'):
                    raise ValueError(f'Missing native capture provenance: {key}')
                with Image.open(source) as image:
                    expected = (GEOMETRY[device]['width'], GEOMETRY[device]['height'])
                    if image.size != expected:
                        raise ValueError(f'Wrong native dimensions for {key}: {image.size}')
                    image.verify()
                sources.append((device, appearance, number, slug, headline, key, source, entry))
    stage = Path(tempfile.mkdtemp(prefix='band-marketing-review-'))
    now = datetime.now(timezone.utc).isoformat()
    metadata = copy.deepcopy(output_manifest)
    renderer = SKILL / 'scripts/render_marketing.swift'
    spec = importlib.util.spec_from_file_location('image_validation', SKILL / 'scripts/validate_screenshots.py')
    validator = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(validator)
    reports = {}
    try:
        for device in devices:
            for appearance in appearances:
                folder = stage / device / appearance
                folder.mkdir(parents=True)
                # A selected-screen run validates its final combined core set.
                for number, slug, _ in SCREENS:
                    if slug in slugs:
                        continue
                    key = f'{device}/{appearance}/{filename(device, appearance, number, slug)}'
                    existing = args.output_root / key
                    entry = metadata['images'].get(key, {})
                    if entry.get('kind') != 'marketing' or not existing.is_file() or digest(existing) != entry.get('sha256'):
                        raise ValueError(f'Missing verified untouched marketing card: {key}')
                    shutil.copy2(existing, stage / key)
        for device, appearance, number, slug, headline, key, source, entry in sources:
            work = stage / 'inputs' / device / appearance
            work.mkdir(parents=True, exist_ok=True)
            native = work / f'{number}-{slug}-source.png'
            shutil.copy2(source, native)
            config = dict(GEOMETRY[device], headline=headline, headlineWeight='semibold', source=native.name,
                          output=os.path.relpath(stage / key, work))
            config_path = work / f'{number}-{slug}-config.json'
            write_json(config_path, config)
            env = dict(os.environ, CLANG_MODULE_CACHE_PATH='/tmp/app-store-template-module-cache')
            subprocess.run(['swift', str(renderer), str(config_path)], env=env, check=True, stdout=subprocess.DEVNULL)
            result = dict(kind='marketing', templateVersion='v1', headline=headline, configuration=config,
                          composedAt=now, sha256=digest(stage / key), dimensions=[config['width'], config['height']],
                          device=device, appearance=appearance, screen_number=number, screen=slug,
                          sourceSha256=digest(source), sourceCapture=copy.deepcopy(entry['capture']),
                          sourceManifest=str(args.manifest.resolve()), rendererSha256=digest(renderer))
            # Retain any original attachment metadata outside capture as well.
            result['nativeSourceRecord'] = copy.deepcopy(entry)
            metadata['images'][key] = result
        for device in devices:
            for appearance in appearances:
                report = validator.validate(stage / device / appearance, 'iphone-6.9' if device == 'iphone' else 'ipad-13')
                if not report['valid'] or len(report['images']) != len(SCREENS):
                    raise ValueError(f'Incomplete/invalid {device}/{appearance}: {report}')
                report['specifications_checked'] = '2026-09-12'
                report['validatedAt'] = now
                report['folder'] = str((args.output_root if args.publish else stage) / device / appearance)
                reports[(device, appearance)] = report
                write_json(stage / f'validation-{device}-{appearance}.json', report)
                contact_sheet(stage / device / appearance, device, appearance, stage / f'contact-sheet-{device}-{appearance}.jpg')
                metadata[f'store_selection_{device}_{appearance}'] = [f'{device}/{appearance}/{filename(device, appearance, n, s)}' for n, s, _ in SCREENS]
        metadata['marketing'] = dict(template='v1', updated_utc=now, presentation_order=[s for _, s, _ in SCREENS],
                                     headline_mapping={s: h for _, s, h in SCREENS}, geometry=GEOMETRY,
                                     requested_devices=devices, requested_appearances=appearances, requested_screens=slugs,
                                     status='ready-for-visual-review', uploadPerformed=False)
        metadata['note'] = 'Current canonical core files are marketing cards. Per-image native source provenance is separate from composition time; historical captures remain historical.'
        write_json(stage / 'manifest.json', metadata)
        if args.publish:
            # Every selected set has passed before any canonical mutation.
            for _, _, _, _, _, key, _, _ in sources:
                dest = args.output_root / key
                dest.parent.mkdir(parents=True, exist_ok=True)
                os.replace(stage / key, dest)
            for device, appearance in reports:
                for name in [f'validation-{device}-{appearance}.json', f'contact-sheet-{device}-{appearance}.jpg']:
                    os.replace(stage / name, args.output_root / name)
            os.replace(stage / 'manifest.json', output_manifest_path)
            print(f'Published {len(sources)} cards after complete validation: {args.output_root}')
            shutil.rmtree(stage)
        else:
            print(f'Composed {len(sources)} cards for visual review; staging retained: {stage}')
    except Exception:
        print(f'Canonical files were not published. Diagnostic staging retained: {stage}')
        raise

if __name__ == '__main__':
    main()
