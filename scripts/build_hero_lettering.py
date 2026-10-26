#!/usr/bin/env python3
"""Build hero selection image lettering from OFL NanumMyeongjoBold outlines."""
import sys
sys.dont_write_bytecode = True
import argparse
from pathlib import Path
from fontTools.ttLib import TTFont
from build_title_lettering import lettering, save

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--font-dir', required=True, type=Path)
args = parser.parse_args()
font = TTFont(args.font_dir / 'NanumMyeongjoBold.ttf')
root = Path(__file__).resolve().parents[1] / 'game/assets/preparation/lettering'
root.mkdir(parents=True, exist_ok=True)
for name, label in [('heading', '주인공 선택'), ('back', '‹ 이전'),
                    ('reselect', '‹ 다시 선택'), ('next', '다음: 무기 선택 ›'),
                    ('story-on', '이야기 켜짐'), ('story-off', '이야기 꺼짐'),
                    ('roan', '로안'), ('lumi', '루미')]:
    data, right = lettering(font, label, 106, 14, 108, 2)
    save(root / (name + '.svg'), round(right + 12), 136,
         f'<path d="{data}" fill="#ffffff"/>', label)
