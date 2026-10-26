#!/usr/bin/env python3
"""Outlined image lettering for weapon selection. Requires FontTools and OFL NanumMyeongjoBold."""
import sys
sys.dont_write_bytecode = True
import argparse
from pathlib import Path
from fontTools.ttLib import TTFont
from build_title_lettering import lettering, save
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--font-dir',required=True,type=Path)
args=parser.parse_args()
font=TTFont(args.font_dir/'NanumMyeongjoBold.ttf')
root=Path(__file__).resolve().parents[1]/'game/assets/preparation/weapon-lettering'
root.mkdir(exist_ok=True)
words={'heading':'무기 선택','hero':'· 주인공','settings':'도전 설정','back':'‹ 이전: 주인공','return':'‹ 돌아가기','start':'모험 시작 ›','backup':'보조로 선택','backup-selected':'보조','primary':'주무기','close':'닫기','sword':'검','bow':'활','fist':'주먹','staff':'지팡이','polearm':'장봉','shield':'방패','sword_dash':'돌진 베기','sword_spin':'회전 베기','bow_piercing':'관통 화살','bow_arrow_rain':'화살비','fist_dash':'쇄도권','fist_flurry':'연환권','staff_fireball':'화염구','staff_ice_lance':'얼음창','polearm_sweep':'횡소봉','polearm_thrust':'관통봉','shield_guard':'방패 올리기','shield_counter':'응수'}
for name,label in words.items():
 data,right=lettering(font,label,106,14,108,2)
 save(root/(name+'.svg'),round(right+12),136,f'<path d="{data}" fill="#ffffff"/>',label)
