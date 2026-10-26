#!/usr/bin/env python3
"""Original vector weapon/skill artwork for the approved preparation menu."""
from pathlib import Path
root = Path(__file__).resolve().parents[1] / 'game/assets/preparation'
(root/'weapons').mkdir(exist_ok=True)
(root/'skills').mkdir(exist_ok=True)
defs = '''<defs>
<linearGradient id="steel" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#effbff"/><stop offset=".4" stop-color="#c9e3eb"/><stop offset=".46" stop-color="#fff"/><stop offset=".53" stop-color="#7297ad"/><stop offset="1" stop-color="#203e59"/></linearGradient>
<linearGradient id="gold" x2=".7" y2="1"><stop stop-color="#fff0a3"/><stop offset=".4" stop-color="#e5b557"/><stop offset=".7" stop-color="#a76b2e"/><stop offset="1" stop-color="#f8d47d"/></linearGradient>
<linearGradient id="wood" x2="1" y2=".3"><stop stop-color="#382926"/><stop offset=".5" stop-color="#9b623b"/><stop offset=".7" stop-color="#4f332d"/><stop offset="1" stop-color="#211f28"/></linearGradient>
<linearGradient id="blue" x2="1" y2="1"><stop stop-color="#8ce9e9"/><stop offset=".35" stop-color="#248bb2"/><stop offset="1" stop-color="#12334d"/></linearGradient>
<linearGradient id="violet" x2="1" y2="1"><stop stop-color="#f7dfff"/><stop offset=".45" stop-color="#ae79df"/><stop offset="1" stop-color="#4d2e85"/></linearGradient>
<radialGradient id="night"><stop stop-color="#174f65"/><stop offset="1" stop-color="#061e30"/></radialGradient>
</defs>'''
def path(d, fill='none', stroke='#493023', width=2, extra=''):
 return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round" {extra}/>'
def line(d,c='#9bf2ff',w=4):return path(d,'none',c,w)
def circ(x,y,r,fill,stroke='none',w=1):return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{w}"/>'
def save(folder,name,w,h,body):
 (root/folder/(name+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{defs}{body}</svg>\n')
weapons={}
weapons['sword']=(128,128,
 path('M37 87 92 18 119 7 111 36 51 96Z','url(#steel)')+
 path('M45 85 111 17 96 40 51 91Z','#d9f6ff','none')+
 path('M36 83 Q28 77 25 72 L18 78 31 94 44 107 52 100 Q44 96 44 91 L59 96 64 88 48 82Z','url(#gold)')+
 path('M31 94 14 114 8 110 25 89Z','url(#wood)')+
 line('M17 103 25 109 M21 98 29 104','#dcae63',2)+
 path('M9 107 17 114 12 123 3 119 2 111Z','url(#gold)')+circ(40,89,6,'url(#blue)','#fff0ae',2)+circ(9,115,2,'#9ff2ef'))
weapons['bow']=(128,176,
 path('M44 9 Q87 27 76 56 Q48 75 57 94 Q83 114 63 145 L43 168 48 145 Q61 122 41 99 Q24 78 51 49 Q69 31 44 9Z','url(#wood)')+
 path('M44 9 Q84 27 71 55 M45 102 Q74 128 43 168','none','url(#gold)',5)+
 path('M44 9 113 91 43 168','none','#c0c6ac',1.5)+
 path('M35 74 53 70 58 97 44 103Z','url(#gold)')+
 path('M39 77 49 76 53 96 46 98Z','url(#blue)')+
 line('M55 25 65 32 M57 123 62 133','#f4dd91',2))
fist = path('M37 68 30 44 Q29 34 37 32 L43 17 Q46 12 54 16 L60 26 65 13 Q70 8 77 14 L84 24 91 20 Q102 20 103 31 L108 46 Q116 53 110 68 L99 86 96 119 42 120 42 87Z','url(#gold)')
fist += path('M42 83 98 82 94 119 45 120Z','url(#wood)')
fist += path('M33 43 101 40 105 62 42 71Z','url(#gold)')
fist += line('M46 29 48 47 M63 24 65 44 M82 25 85 43','#795136',3)
fist += path('M62 48 75 43 88 51 77 64 64 61Z','url(#blue)','#fff0b3')
fist += line('M46 94 96 94 M46 105 94 105','#d5ae69',3)
weapons['fist']=(128,128,fist)
weapons['fist-pair']=(224,144,f'<g transform="translate(0 9) rotate(-10 64 64)">{fist}</g><g transform="translate(224 9) scale(-1 1) rotate(-10 64 64)">{fist}</g>')
weapons['staff']=(64,256,
 path('M25 68 36 68 39 243 31 253 25 244Z','url(#wood)')+
 path('M18 56 7 30 18 46 31 59 45 46 57 30 47 61 37 75 25 73Z','url(#gold)')+
 path('M17 30 31 2 46 28 38 53 27 60 19 46Z','url(#violet)','#5b387e')+
 path('M31 2 31 57 46 28Z','#8252c5','none')+line('M20 29 30 12 30 40','#fff0ff',2)+
 path('M23 80 39 80 40 91 24 91Z','url(#gold)')+
 line('M27 145 36 145 M27 153 36 153 M27 161 36 161 M27 169 36 169','#c0a179',3)+
 path('M27 235 39 235 39 247 32 254 25 246Z','url(#gold)'))
weapons['polearm']=(256,48,
 path('M16 18 240 18 240 30 16 30Z','url(#wood)')+
 path('M4 12 28 12 32 24 28 36 4 36 1 24Z','url(#blue)')+
 path('M228 12 252 12 255 24 252 36 228 36 224 24Z','url(#blue)')+
 line('M33 19 83 19 M173 19 221 19','#c38b4c',2)+
 ''.join(line(f'M{x} 18 {x+3} 30','#cfb690',2) for x in range(90,165,7))+
 path('M8 24 14 18 20 24 14 30Z','#b7efcf','none')+
 path('M235 24 241 18 247 24 241 30Z','#b7efcf','none'))
weapons['shield']=(128,160,
 path('M64 4 119 26 114 99 Q105 130 64 156 23 130 14 99 L9 26Z','url(#gold)')+
 path('M64 14 109 33 104 96 Q94 122 64 144 34 122 24 96 L19 33Z','url(#blue)','#1c4660',2)+
 path('M64 15 64 143 28 111 23 95 19 33Z','#2c607e','none')+
 path('M64 30 74 65 101 76 76 88 64 128 53 88 29 76 55 65Z','url(#gold)','#fff1b1',1.5)+
 path('M64 42 64 112 73 80Z','#fff7ce','none')+
 line('M24 36 27 92 M102 35 100 86','#86c4db',2)+
 ''.join(circ(x,y,2.5,'#fff0a1','#9e692e') for x,y in [(16,31),(112,31),(20,98),(108,98),(64,147)]))
for name,(w,h,body) in weapons.items():save('weapons',name,w,h,body)
# Compact action silhouettes remain readable at menu icon sizes.
body = circ(68,30,9,'#fff9e4')+path('M61 42 74 40 80 59 66 74 55 61 48 63 42 56Z','#fff9e4','#1e6680',1)+line('M64 70 44 95 25 103 M70 72 83 91 101 94','#fff9e4',9)
target=lambda x: circ(x,39,5,'none','#66c5d8',2)+line(f'M{x} 46 {x} 82 M{x-7} 55 {x+7} 55 M{x} 82 {x-7} 96 M{x} 82 {x+7} 96','#66c5d8',3)
icons={}
icons['sword_dash']=line('M7 42 50 33 M6 64 48 48 M10 85 44 65','#24c1eb',7)+body+path('M76 57 111 31 101 53 78 64Z','#e8ffff','#7ce5ff',2)
icons['sword_spin']=body+line('M20 51 A48 34 0 1 0 107 47','#299dc4',12)+line('M16 46 A49 35 0 1 0 110 55','#d2ffff',5)+path('M91 40 114 49 102 67Z','#ffd584','none')
icons['bow_piercing']=target(48)+target(77)+target(105)+line('M10 65 109 65','#ffdf8a',8)+path('M96 51 120 65 96 79 102 65Z','#fff3bd','none')+line('M8 54 27 65 8 76','#f5af58',3)
icons['bow_arrow_rain']='<ellipse cx="64" cy="101" rx="49" ry="13" fill="#c37932" opacity=".4"/>'+path('M16 97 A49 15 0 1 0 111 97','none','#ffcf7b',3)+''.join(line(f'M{x} {y} {x} {y+44}','#ffdb8c',3)+path(f'M{x-5} {y+35} {x} {y+47} {x+5} {y+35}Z','#fff4bf','none') for x,y in [(25,19),(42,36),(59,14),(77,35),(94,17),(107,47)])
icons['fist_dash']=line('M8 40 49 42 M6 62 48 59 M12 89 48 78','#f0ad43',8)+f'<g transform="translate(22 0) scale(.83)">{fist}</g>'+path('M97 50 119 46 108 61 121 70 103 73 110 93 91 83Z','#fff1a4','none')
icons['fist_flurry']=''.join(line(f'M8 {y+3} {x} {y+3}','#e6a044',5)+f'<rect x="{x}" y="{y}" width="22" height="18" rx="5" fill="#ffdc85" stroke="#b8792e" stroke-width="2"/>'+line(f'M{x+9} {y+1} {x+9} {y+8} M{x+16} {y+1} {x+16} {y+8}','#fff2be',2) for x,y in [(58,22),(81,40),(46,53),(73,76),(31,88)])
icons['staff_fireball']=path('M14 22 63 43 49 13 Q86 16 105 40 125 69 100 97 75 122 48 99 L14 92 42 70 5 55 42 54Z','#c84624','none')+circ(80,65,31,'#f79c32')+circ(84,64,22,'#ffda72')+path('M72 45 Q107 53 87 85 104 57 68 68 L87 41Z','#fff6c6','none')+line('M15 39 41 48 M19 79 40 74','#ffc563',5)
icons['staff_ice_lance']=target(94)+target(113)+path('M9 58 85 47 120 63 84 79 9 69 42 62Z','#9beaff','#3c9fd0',2)+path('M31 62 120 63 84 49Z','#eefeff','none')+line('M10 37 52 46 M11 89 47 78','#5cc8f7',3)
icons['polearm_sweep']=body+line('M14 59 111 83','#f3d5a2',6)+line('M20 35 Q-7 76 45 101 106 127 115 77','#41c8c2',10)+line('M20 35 Q-7 76 45 101 106 127 115 77','#c1fff0',3)
icons['polearm_thrust']=body+target(110)+line('M16 76 116 52','#ffd68d',7)+line('M12 85 85 68 M20 97 74 80','#36b6c2',3)+path('M100 37 121 50 111 69 108 55Z','#fff8c2','none')
icons['shield_guard']=f'<g transform="translate(29 18) scale(.64)">{weapons["shield"][2]}</g>'+line('M75 14 Q36 61 74 112','#5cbcd5',8)+''.join(line(f'M9 {y} 37 {y+7}','#ffdb91',3)+path(f'M31 {y+2} 43 {y+9} 29 {y+13}Z','#ffe8b0','none') for y in [30,57,84])
icons['shield_counter']=target(112)+f'<g transform="translate(20 25) scale(.52)">{weapons["shield"][2]}</g>'+line('M12 91 Q75 119 111 53','#ffca70',11)+line('M12 91 Q75 119 111 53','#fff4bb',3)+path('M100 33 124 50 111 76 111 53Z','#fff5c4','none')
for name,art in icons.items():
 bg='<rect x="2" y="2" width="124" height="124" rx="19" fill="url(#night)" stroke="#2095ac" stroke-width="3"/><path d="M13 34V23Q13 13 26 13H93" fill="none" stroke="#99dde1" stroke-opacity=".30" stroke-width="2"/>'
 save('skills',name,128,128,bg+art)
