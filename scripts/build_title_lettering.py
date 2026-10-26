#!/usr/bin/env python3
"""Build outlined title/menu image assets; no runtime font dependency.

Requires fonttools and the OFL NanumMyeongjo fonts. Pass their directory with
--font-dir. The generated SVGs contain paths only and Godot imports them as
transparent textures. Fonts are not bundled in the application.
"""
import argparse
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen


def lettering(font, text, size, x, baseline, tracking=1.5):
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    scale = size / font['head'].unitsPerEm
    paths = []
    for character in text:
        name = cmap[ord(character)]
        pen = SVGPathPen(glyphs)
        glyphs[name].draw(TransformPen(pen, (scale, 0, 0, -scale, x, baseline)))
        paths.append(pen.getCommands())
        x += glyphs[name].width * scale + tracking
    return ''.join(paths), x


def save(path, width, height, body, label):
    path.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}"><title>{label}</title>{body}</svg>\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--font-dir', required=True, type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1] / 'game/assets/title/lettering'
    root.mkdir(parents=True, exist_ok=True)
    regular = TTFont(args.font_dir / 'NanumMyeongjo.ttf')
    bold = TTFont(args.font_dir / 'NanumMyeongjoBold.ttf')
    for name, label in [('continue', '이어하기'), ('new-journey', '새 도전'),
                        ('village', '시간의 닻 마을'), ('journal', '기억 수첩'), ('settings', '설정')]:
        data, right = lettering(bold, label, 106, 14, 108, 2)
        save(root / (name + '.svg'), round(right + 12), 136,
             f'<path d="{data}" fill="#ffffff"/>', label)
    data, right = lettering(regular, 'Rewind to Dawn', 78, 8, 83, 2)
    save(root / 'subtitle.svg', round(right + 8), 104,
         f'<path d="{data}" fill="#ffffff"/>', 'Rewind to Dawn')
    lines = []
    for label, size, baseline in [('다시 피는', 151, 178), ('새벽', 182, 351)]:
        _, right = lettering(bold, label, size, 0, baseline, 3)
        data, _ = lettering(bold, label, size, (760 - right) / 2, baseline, 3)
        lines.append(data)
    data = ''.join(lines)
    title = '<defs><linearGradient id="dawn" x2="0" y2="1"><stop stop-color="#fffcef"/><stop offset=".5" stop-color="#fff3c9"/><stop offset="1" stop-color="#e8be66"/></linearGradient></defs>'
    title += '<path d="M176 59 Q380 -5 584 59 M219 361 Q380 392 541 361" fill="none" stroke="#e5cd92" stroke-width="2" opacity=".75"/>'
    title += '<path d="M380 11 385 29 403 34 385 39 380 57 375 39 357 34 375 29Z" fill="#fff0ba"/>'
    title += f'<path d="{data}" fill="#092e30" opacity=".75" transform="translate(0 4)"/><path d="{data}" fill="url(#dawn)"/>'
    save(root / 'dawn-title.svg', 760, 406, title, '다시 피는 새벽')


if __name__ == '__main__':
    main()
