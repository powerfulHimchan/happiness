from pathlib import Path

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_ALIGN_VERTICAL, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK, WD_LINE_SPACING
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


OUTPUT = str(
    Path(__file__).resolve().parent.parent
    / "docs"
    / "Happiness_Tale_GDD_v0.1.docx"
)
FONT = "Noto Sans KR"
FONT_EA = "Noto Sans KR"
BLACK = "000000"
NAVY = "2F5D73"
BLUE = "DCEBF3"
PALE_BLUE = "F1F7FA"
GOLD = "D7A23A"
LIGHT_GOLD = "F8EFD9"
GRAY = "666666"
LIGHT_GRAY = "F4F5F6"
BORDER = "D9D9D9"


def set_cell_shading(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_margins(cell, top=100, start=120, bottom=100, end=120):
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for margin, value in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = tc_mar.find(qn(f"w:{margin}"))
        if node is None:
            node = OxmlElement(f"w:{margin}")
            tc_mar.append(node)
        node.set(qn("w:w"), str(value))
        node.set(qn("w:type"), "dxa")


def set_cell_borders(cell, color=BORDER, size="6"):
    tc_pr = cell._tc.get_or_add_tcPr()
    tc_borders = tc_pr.first_child_found_in("w:tcBorders")
    if tc_borders is None:
        tc_borders = OxmlElement("w:tcBorders")
        tc_pr.append(tc_borders)
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        tag = f"w:{edge}"
        element = tc_borders.find(qn(tag))
        if element is None:
            element = OxmlElement(tag)
            tc_borders.append(element)
        element.set(qn("w:val"), "single")
        element.set(qn("w:sz"), size)
        element.set(qn("w:color"), color)


def set_repeat_table_header(row):
    tr_pr = row._tr.get_or_add_trPr()
    tbl_header = OxmlElement("w:tblHeader")
    tbl_header.set(qn("w:val"), "true")
    tr_pr.append(tbl_header)


def keep_table_row_together(row):
    tr_pr = row._tr.get_or_add_trPr()
    cant_split = OxmlElement("w:cantSplit")
    cant_split.set(qn("w:val"), "true")
    tr_pr.append(cant_split)


def set_run_font(run, size=None, bold=None, color=None, italic=None):
    run.font.name = FONT
    run._element.get_or_add_rPr().rFonts.set(qn("w:ascii"), FONT)
    run._element.get_or_add_rPr().rFonts.set(qn("w:hAnsi"), FONT)
    run._element.get_or_add_rPr().rFonts.set(qn("w:eastAsia"), FONT_EA)
    if size is not None:
        run.font.size = Pt(size)
    if bold is not None:
        run.bold = bold
    if color is not None:
        run.font.color.rgb = RGBColor.from_string(color)
    if italic is not None:
        run.italic = italic


def configure_style(style, size, bold=False, color=BLACK, space_before=0, space_after=6, line=1.2):
    style.font.name = FONT
    style._element.get_or_add_rPr().rFonts.set(qn("w:ascii"), FONT)
    style._element.get_or_add_rPr().rFonts.set(qn("w:hAnsi"), FONT)
    style._element.get_or_add_rPr().rFonts.set(qn("w:eastAsia"), FONT_EA)
    style.font.size = Pt(size)
    style.font.bold = bold
    style.font.color.rgb = RGBColor.from_string(color)
    pf = style.paragraph_format
    pf.space_before = Pt(space_before)
    pf.space_after = Pt(space_after)
    pf.line_spacing = line


def add_heading(doc, text, level=1):
    p = doc.add_heading(text, level=level)
    p.paragraph_format.keep_with_next = True
    return p


def add_body(doc, text, bold_lead=None):
    p = doc.add_paragraph(style="Body Text")
    if bold_lead and text.startswith(bold_lead):
        r1 = p.add_run(bold_lead)
        set_run_font(r1, bold=True)
        r2 = p.add_run(text[len(bold_lead):])
        set_run_font(r2)
    else:
        r = p.add_run(text)
        set_run_font(r)
    return p


def add_bullets(doc, items, level=0):
    for item in items:
        p = doc.add_paragraph(style="Body Text")
        p.paragraph_format.left_indent = Inches(0.25 + 0.22 * level)
        p.paragraph_format.first_line_indent = Inches(-0.25)
        p.paragraph_format.space_after = Pt(3)
        r = p.add_run(f"•  {item}")
        set_run_font(r)


def add_numbered(doc, items):
    for index, item in enumerate(items, start=1):
        p = doc.add_paragraph(style="Body Text")
        p.paragraph_format.left_indent = Inches(0.28)
        p.paragraph_format.first_line_indent = Inches(-0.28)
        p.paragraph_format.space_after = Pt(4)
        r = p.add_run(f"{index}.  {item}")
        set_run_font(r)


def add_table(doc, headers, rows, widths=None, font_size=9.4):
    table = doc.add_table(rows=1, cols=len(headers))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    table.style = "Table Grid"
    if widths:
        for idx, width in enumerate(widths):
            table.columns[idx].width = Inches(width)
    header = table.rows[0]
    set_repeat_table_header(header)
    for idx, label in enumerate(headers):
        cell = header.cells[idx]
        set_cell_shading(cell, NAVY)
        set_cell_margins(cell)
        set_cell_borders(cell)
        cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_after = Pt(0)
        run = p.add_run(str(label))
        set_run_font(run, size=font_size, bold=True, color="FFFFFF")
    for row_index, row_data in enumerate(rows):
        body_row = table.add_row()
        keep_table_row_together(body_row)
        cells = body_row.cells
        fill = "FFFFFF" if row_index % 2 == 0 else PALE_BLUE
        for idx, value in enumerate(row_data):
            cell = cells[idx]
            set_cell_shading(cell, fill)
            set_cell_margins(cell)
            set_cell_borders(cell)
            cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
            p = cell.paragraphs[0]
            p.paragraph_format.space_after = Pt(0)
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER if idx == 0 else WD_ALIGN_PARAGRAPH.LEFT
            run = p.add_run(str(value))
            set_run_font(run, size=font_size, color=BLACK)
    doc.add_paragraph().paragraph_format.space_after = Pt(0)
    return table


def add_page_number(paragraph):
    paragraph.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    run = paragraph.add_run()
    fld_char1 = OxmlElement("w:fldChar")
    fld_char1.set(qn("w:fldCharType"), "begin")
    instr_text = OxmlElement("w:instrText")
    instr_text.set(qn("xml:space"), "preserve")
    instr_text.text = " PAGE "
    fld_char2 = OxmlElement("w:fldChar")
    fld_char2.set(qn("w:fldCharType"), "end")
    run._r.append(fld_char1)
    run._r.append(instr_text)
    run._r.append(fld_char2)
    set_run_font(run, size=8, color=GRAY)


doc = Document()
section = doc.sections[0]
section.page_width = Inches(8.5)
section.page_height = Inches(11)
section.top_margin = Inches(0.72)
section.bottom_margin = Inches(0.7)
section.left_margin = Inches(0.78)
section.right_margin = Inches(0.78)

styles = doc.styles
configure_style(styles["Normal"], 10.6, space_after=5, line=1.22)
configure_style(styles["Body Text"], 10.6, space_after=6, line=1.23)
configure_style(styles["Title"], 29, bold=True, space_after=12, line=1.0)
configure_style(styles["Subtitle"], 13, color=GRAY, space_after=8, line=1.1)
configure_style(styles["Heading 1"], 18, bold=True, space_before=15, space_after=8, line=1.05)
configure_style(styles["Heading 2"], 13.2, bold=True, space_before=11, space_after=5, line=1.05)
configure_style(styles["Heading 3"], 11.2, bold=True, space_before=8, space_after=4, line=1.05)
configure_style(styles["List Bullet"], 10.4, space_after=3, line=1.16)
configure_style(styles["List Bullet 2"], 10.2, space_after=2, line=1.14)
configure_style(styles["List Number"], 10.4, space_after=3, line=1.16)

for style_name in ["Title", "Subtitle", "Heading 1", "Heading 2", "Heading 3"]:
    styles[style_name].font.color.rgb = RGBColor(0, 0, 0)

title_p_pr = styles["Title"]._element.get_or_add_pPr()
title_border = title_p_pr.find(qn("w:pBdr"))
if title_border is not None:
    title_p_pr.remove(title_border)

for sec in doc.sections:
    footer = sec.footer
    footer.distance = Inches(0.35)
    p = footer.paragraphs[0]
    p.clear()
    p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    add_page_number(p)

# Cover
doc.add_paragraph().paragraph_format.space_after = Pt(60)
p = doc.add_paragraph(style="Title")
p.alignment = WD_ALIGN_PARAGRAPH.LEFT
p_pr = p._p.get_or_add_pPr()
p_border = p_pr.find(qn("w:pBdr"))
if p_border is not None:
    p_pr.remove(p_border)
r = p.add_run("Happiness Tale: Rewind to Dawn")
set_run_font(r, size=29, bold=True, color=BLACK)
p2 = doc.add_paragraph(style="Subtitle")
r = p2.add_run("안드로이드 횡스크롤 로그라이트 게임 기획서")
set_run_font(r, size=13, color=GRAY)

doc.add_paragraph().paragraph_format.space_after = Pt(115)
meta = doc.add_table(rows=4, cols=2)
meta.alignment = WD_TABLE_ALIGNMENT.LEFT
meta.autofit = False
meta.columns[0].width = Inches(1.5)
meta.columns[1].width = Inches(4.6)
cover_rows = [
    ("문서 버전", "0.1"),
    ("작성일", "2026년 9월 23일"),
    ("플랫폼", "Android"),
    ("공개 목표", "Google Play 무료 정식 공개"),
]
for i, (k, v) in enumerate(cover_rows):
    for j, value in enumerate((k, v)):
        cell = meta.rows[i].cells[j]
        set_cell_shading(cell, LIGHT_GRAY if j == 0 else "FFFFFF")
        set_cell_borders(cell, color="FFFFFF", size="0")
        set_cell_margins(cell, top=85, bottom=85)
        p = cell.paragraphs[0]
        p.paragraph_format.space_after = Pt(0)
        run = p.add_run(value)
        set_run_font(run, size=10, bold=(j == 0), color=BLACK if j == 0 else GRAY)

doc.add_paragraph().paragraph_format.space_after = Pt(88)
p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.LEFT
r = p.add_run("가제")
set_run_font(r, size=9, bold=True, color=GRAY)
p.add_run("  Happiness Tale: Rewind to Dawn")
for run in p.runs[1:]:
    set_run_font(run, size=9, color=GRAY)

doc.add_page_break()

# 1 Overview
add_heading(doc, "게임 개요", 1)
add_body(doc, "Happiness Tale: Rewind to Dawn은 밝은 카툰 판타지와 애틋한 미스터리를 결합한 안드로이드용 2D 횡스크롤 로그라이트 액션 게임이다. 플레이어는 희귀병으로 죽어가는 여행자 로안 또는 루미를 선택해 전설 속 행복의 나라로 향한다. 주인공은 직업 없이 출발하며, 무기와 능력 선택, 실제 전투 행동에 따라 직업이 자동으로 발현된다.")
add_body(doc, "한 스테이지는 약 3분이며 전진 구간과 웨이브 전투를 섞는다. 한 번의 도전은 10개 스테이지로 구성하고, 스테이지가 끝날 때 자동 저장한다. 실패하면 현재 도전의 장비와 능력은 사라지지만 무기, 능력, 직업 도감, 마을 시설과 일부 영구 강화는 유지된다.")

add_heading(doc, "핵심 목표", 2)
add_bullets(doc, [
    "기본 공격을 자동화해 모바일 조작 부담을 낮추면서 이동, 점프, 회피, 무기 전환과 스킬 사용에서 손맛을 만든다.",
    "처음부터 직업을 고르지 않고 플레이 과정이 직업과 상위 직업을 결정하게 한다.",
    "3분 단위 스테이지와 중간 저장으로 짧게 플레이할 수 있으면서 전체 도전에는 빌드의 흐름을 남긴다.",
    "밝은 카툰 판타지 안에 시간 반복, 잃어버린 존재, 빌려온 행복이라는 미스터리를 단계적으로 드러낸다.",
    "광고와 결제, 로그인과 서버 없이 완전한 오프라인 게임으로 Google Play에 무료 공개한다.",
])

add_heading(doc, "디자인 원칙", 2)
add_table(doc, ["원칙", "설계 기준"], [
    ("조작", "기본 공격은 자동화하되 바라보는 방향과 위치 선정이 결과를 바꾸게 한다."),
    ("성장", "무작위 선택에 능력 트리를 결합해 우연과 계획을 함께 제공한다."),
    ("반복", "실패해도 새로운 콘텐츠와 이야기 단서를 얻어 다음 도전의 목적을 만든다."),
    ("서사", "긴 설명보다 짧은 대화와 중요한 구간의 짧은 연출로 전달한다."),
    ("범위", "첫 프로토타입은 전투 한 스테이지만 구현하고 검증 후 시스템을 확장한다."),
], widths=[1.25, 5.8])

add_heading(doc, "제품 범위", 2)
add_table(doc, ["항목", "결정"], [
    ("플랫폼", "Android 스마트폰 가로 화면"),
    ("배포", "Google Play 무료 정식 공개"),
    ("수익 모델", "광고와 인앱 결제 없음"),
    ("연결", "완전 오프라인"),
    ("저장", "기기 내부 자동 저장과 향후 파일 내보내기"),
    ("그래픽", "깔끔한 카툰 벡터 스타일"),
    ("플레이", "싱글 플레이"),
], widths=[1.3, 5.75])

# 2 Loop
add_heading(doc, "핵심 플레이 흐름", 1)
add_numbered(doc, [
    "마을에서 주인공 외형과 시작 무기를 선택한다.",
    "해금된 기본 무기 중 하나를 주 무기로 장착하고 도전을 시작한다.",
    "3분 내외 스테이지에서 전진, 플랫폼 이동, 웨이브 전투와 정예 전투를 수행한다.",
    "적을 처치해 경험치를 얻고 레벨업할 때 무작위 능력 세 장 중 하나를 고른다.",
    "능력 선택과 전투 행동으로 성향 점수가 쌓이면 기본 직업이 즉시 발현된다.",
    "지역과 스테이지 보상에서 두 번째 무기, 유물, 회복 수단과 장비를 획득한다.",
    "네 지역을 다른 순서로 통과하고 행복의 나라에 진입해 최종 보스를 상대한다.",
    "성공 또는 실패 후 마을로 돌아와 해금과 영구 강화를 적용하고 다음 도전을 준비한다.",
])

add_heading(doc, "한 번의 도전", 2)
add_body(doc, "한 번의 도전은 10개 스테이지, 약 30분에서 40분을 목표로 한다. 스테이지 종료 시 자동 저장하므로 3분 단위로 플레이를 중단할 수 있다. 전투 중 앱을 종료하면 해당 스테이지 시작 상태로 돌아간다.")
add_table(doc, ["구간", "내용", "목표 시간"], [
    ("1에서 2", "무작위 접근 지역 1", "약 6분"),
    ("3에서 4", "무작위 접근 지역 2와 중간 보스", "약 7분"),
    ("5에서 6", "무작위 접근 지역 3", "약 6분"),
    ("7에서 8", "무작위 접근 지역 4와 관문 보스", "약 7분"),
    ("9", "행복의 나라 성문", "약 3분"),
    ("10", "행복의 나라 중심부와 최종 보스", "약 4분"),
], widths=[1.0, 4.8, 1.25])

add_heading(doc, "스테이지 기본 리듬", 2)
add_table(doc, ["시간", "구성"], [
    ("0분에서 40초", "플랫폼 이동과 일반 몬스터 전투"),
    ("40초에서 1분 10초", "길이 막히고 첫 웨이브 발생"),
    ("1분 10초에서 2분", "갈림길, 함정, 상자 또는 회복 이벤트"),
    ("2분에서 2분 40초", "정예 몬스터가 포함된 혼합 웨이브"),
    ("2분 40초 이후", "출구 수호자 또는 지역별 마무리 전투"),
], widths=[1.65, 5.4])

add_heading(doc, "경로 선택", 2)
add_body(doc, "각 스테이지 종료 후 두 갈래 경로를 제시한다. 안전한 길은 회복과 상점 확률이 높고, 위험한 길은 정예 전투와 희귀 무기 확률이 높다. 미지의 길은 보상을 숨기며, 지름길은 전투를 줄이는 대신 성장 기회를 낮춘다. 지역을 끝내면 아직 방문하지 않은 지역 중 두 곳을 다음 후보로 보여준다.")

# 3 Combat
add_heading(doc, "전투와 조작", 1)
add_heading(doc, "화면 구성", 2)
add_table(doc, ["영역", "조작 요소"], [
    ("왼쪽", "이동 가상 패드"),
    ("오른쪽", "점프, 회피, 액티브 스킬 2개, 필살기"),
    ("보조 위치", "무기 전환 버튼"),
    ("상단", "체력, 경험치, 필살기 게이지, 현재 무기와 직업 성향"),
], widths=[1.25, 5.8])

add_heading(doc, "기본 공격", 2)
add_bullets(doc, [
    "기본 공격은 캐릭터가 바라보는 방향의 공격 범위 안에서 가장 가까운 적을 자동으로 선택한다.",
    "이동 방향을 바꾸면 캐릭터가 바라보는 방향도 바뀐다. 뒤의 적을 공격하기 위해 자동으로 회전하지 않는다.",
    "대상이 사거리에서 벗어나거나 죽으면 다음 대상을 즉시 탐색한다.",
    "현재 대상을 작은 테두리로 표시한다. 활은 화면 밖 적을 공격하지 않는다.",
    "적이 없을 때는 공격 애니메이션을 실행하지 않는다.",
])

add_heading(doc, "점프와 회피", 2)
add_table(doc, ["행동", "규칙"], [
    ("점프", "누르는 시간에 따라 높이가 달라지는 1단 점프로 시작한다."),
    ("입력 보정", "발판을 벗어난 직후와 착지 직전에 약 0.1초의 입력 여유를 제공한다."),
    ("2단 점프", "정식 게임에서 능력으로 해금한다. 전투 프로토타입에는 넣지 않는다."),
    ("지상 회피", "이동 방향으로 짧게 이동하며 약 0.18초 동안 피해를 무시한다."),
    ("공중 회피", "이동 방향으로 공중 대시한다. 공중에서 한 번 사용하고 착지 시 회복한다."),
    ("낙하", "마지막 안전 발판으로 복귀하고 최대 체력의 10퍼센트를 잃는다."),
], widths=[1.35, 5.7])

add_heading(doc, "필살기", 2)
add_body(doc, "필살기 게이지는 공격, 처치와 회피로 채운다. 직업 발현 전에는 새벽시계의 힘을 사용하는 공용 필살기 시간 정지를 사용한다. 직업이 발현되면 직업 전용 필살기 후보 2개 또는 3개 중 하나를 선택한다. 상위 직업 진화 시 선택한 필살기도 같은 계열로 강화된다.")

add_heading(doc, "피격과 회복", 2)
add_table(doc, ["수단", "기본 규칙"], [
    ("회복약", "도전 시작 시 2회, 사용 시 최대 체력의 25퍼센트 회복"),
    ("스테이지 회복", "클리어 시 최대 체력의 5퍼센트 회복"),
    ("회복 구슬", "몬스터가 낮은 확률로 드롭하며 스테이지당 최대 2개"),
    ("빌드 회복", "흡혈, 처치 회복, 보호막 전환 등 능력과 장비로 강화"),
    ("부활", "희귀 유물 불사조 깃털 보유 시 도전당 한 번 체력 50퍼센트로 부활"),
], widths=[1.35, 5.7])

# 4 Weapons
add_heading(doc, "무기 시스템", 1)
add_heading(doc, "두 무기 전환", 2)
add_body(doc, "플레이어는 주 무기와 보조 무기를 하나씩 소지한다. 전환 버튼을 누르면 약 0.5초의 제한 후 즉시 교체한다. 공격 대기시간은 교체해도 초기화하지 않아 전환 반복으로 공격 속도를 높이는 문제를 막는다. 각 무기는 별도의 액티브 스킬 2개를 가진다. 무기를 바꾸면 화면의 스킬 아이콘도 함께 바뀌며, 사용한 스킬의 재사용 대기시간은 계속 흐른다.")

add_heading(doc, "무기 계열", 2)
add_table(doc, ["무기", "기본 공격", "강점", "약점"], [
    ("검", "빠른 3연속 베기", "균형과 이동 공격", "뚜렷한 특화가 적음"),
    ("주먹", "매우 빠른 근접 연타", "콤보와 상태 누적", "사거리가 가장 짧음"),
    ("활", "먼 거리 단일 사격", "안전 거리와 약점 공격", "가까운 적 대응이 어려움"),
    ("지팡이", "느린 마법탄", "속성과 범위 피해", "공격 사이 빈틈이 큼"),
    ("장봉", "넓게 휘두르는 공격", "다수 제어와 밀치기", "단일 대상 피해가 낮음"),
    ("방패", "느린 방패 가격", "방어와 반격과 기절", "공격 속도가 느림"),
], widths=[0.85, 2.0, 2.15, 2.05], font_size=8.8)

add_heading(doc, "주 효과와 보조 효과", 2)
add_body(doc, "각 무기는 주 효과와 보조 효과를 갖는다. 현재 사용 중인 무기는 두 효과를 모두 적용하고 보조 슬롯의 무기는 보조 효과만 적용한다. 예를 들어 바람칼은 사용 중 세 번째 공격마다 검기를 발사하고, 보조 슬롯에서는 이동 속도를 5퍼센트 높인다.")

add_heading(doc, "등급과 획득", 2)
add_table(doc, ["등급", "목적", "예시"], [
    ("일반", "기본 공격 방식 체험", "철제 장검"),
    ("희귀", "빌드 방향 제시", "세 번째 공격마다 검기를 발사하는 바람칼"),
    ("영웅", "직업과 속성 시너지", "화상 적에게 폭발을 일으키는 불씨검"),
    ("전설", "플레이 방식 변화", "무기 전환 시 주변 적을 실명시키는 태양검"),
], widths=[1.0, 2.2, 3.85])
add_bullets(doc, [
    "정예 몬스터와 보스는 높은 등급의 무기 후보를 제공한다.",
    "스테이지 상자는 재화와 회복 아이템, 낮은 확률의 무기를 제공한다.",
    "도전 중 상점에서는 발견한 무기를 구매하고 후보를 재추첨할 수 있다.",
    "숨겨진 방과 특별 과제는 희귀 무기와 전설 무기 설계도를 해금한다.",
    "거점에서 발견한 무기를 승급할 수 있어 낮은 등급의 고유 효과도 후반에 활용할 수 있다.",
])

add_heading(doc, "스킬 교체", 2)
add_body(doc, "액티브 스킬 슬롯이 찬 뒤 새 스킬을 얻으면 기존 스킬과 비교해 즉시 교체할 수 있다. 후반 교체가 손해가 되지 않도록 새 스킬은 현재 두 액티브 스킬 평균 레벨보다 1 낮은 수준으로 시작한다. 같은 무기 계열로 교체하면 스킬 구성을 유지하고, 다른 계열로 바꾸면 해당 무기의 기본 스킬 하나와 호환 가능한 보유 스킬을 제공한다.")

# 5 Growth
add_heading(doc, "성장과 직업 발현", 1)
add_heading(doc, "레벨업 선택", 2)
add_body(doc, "몬스터를 처치해 경험치를 얻고 한 스테이지에서 약 2회에서 4회 레벨업한다. 레벨업 시 전투를 멈추고 능력 카드 세 장을 보여준다. 현재 무기나 직업과 관련된 카드 1장, 모든 빌드에서 사용할 수 있는 공용 카드 1장, 완전 무작위 카드 1장을 기본 구성으로 삼는다. 스테이지마다 재추첨 1회를 제공한다.")
add_body(doc, "능력을 처음 얻으면 이후 레벨업에서 전용 강화 가지가 등장한다. 예를 들어 화염구는 폭발 범위 증가와 적 관통 중 하나로 발전한다. 무작위 선택은 매 도전의 변화를 만들고 능력 트리는 플레이어가 빌드 방향을 완성하게 한다.")

add_heading(doc, "직업 성향", 2)
add_body(doc, "각 능력과 무기에는 두 개 안팎의 성향 태그가 붙는다. 직업 판정에는 능력 선택 70퍼센트, 무기 사용 20퍼센트, 특수 행동 10퍼센트를 반영한다. 주 성향 5점과 보조 성향 3점을 기본 발현 조건으로 사용한다. 조건을 충족하면 전투를 잠시 멈추고 직업이 즉시 발현된다.")
add_bullets(doc, [
    "시작 무기는 초기 성향만 제공하고 직업을 고정하지 않는다.",
    "HUD에 가장 가까운 직업과 남은 성향 점수를 표시한다.",
    "조건이 동시에 충족되면 점수가 높은 직업을 선택하고 동점이면 최근 능력의 성향을 우선한다.",
    "기본 직업은 해당 도전 동안 고정되며 이후 성향은 상위 직업 진화에 반영한다.",
    "기본 직업은 보통 2스테이지에서 4스테이지 사이에 발현하고 상위 직업은 7스테이지 이후 진화한다.",
])

add_heading(doc, "기본 직업과 상위 직업", 2)
add_table(doc, ["기본 직업", "주요 성향", "상위 직업 A", "상위 직업 B"], [
    ("선봉대", "근력과 투지", "용염기사", "파쇄자"),
    ("무도가", "기교와 연계", "뇌권투사", "환영무희"),
    ("추적자", "사격과 자연", "폭풍사수", "숲의 파수꾼"),
    ("원소술사", "마력과 원소", "화염현자", "빙결술사"),
    ("수호자", "방어와 신념", "성벽기사", "룬 수호자"),
    ("순례자", "집중과 조화", "천공봉승", "시간방랑자"),
], widths=[1.35, 2.05, 1.85, 1.85], font_size=9.0)

add_heading(doc, "직업 발현 보상", 2)
add_bullets(doc, [
    "직업 전용 패시브가 즉시 활성화된다.",
    "레벨업 후보에 직업 전용 카드가 추가된다.",
    "직업 전용 필살기 후보 중 하나를 선택한다.",
    "망토, 문양, 오라와 무기 이펙트가 변한다.",
    "상위 직업 진화 시 색상과 실루엣이 한 단계 크게 바뀐다.",
])

# 6 Meta
add_heading(doc, "실패와 영구 성장", 1)
add_heading(doc, "시간 되감기", 2)
add_body(doc, "주인공이 쓰러지면 유품인 새벽시계가 여행을 떠난 날의 새벽으로 시간을 되돌린다. 마을은 시계가 만든 시간의 닻 안에 있어 되감기의 영향을 받지 않는다. 마을 시설, 이주한 NPC, 보관한 설계도, 직업 도감과 주인공의 기억은 유지된다. 여행 중 획득한 무기와 능력은 사라지고 지역과 몬스터 배치가 다시 구성된다.")

add_heading(doc, "영구 유지 요소", 2)
add_table(doc, ["유지 요소", "내용"], [
    ("콘텐츠 해금", "무기, 능력, 유물, 직업과 상위 직업"),
    ("도감", "발견한 직업 조건, 보스 선택, 기억과 엔딩 기록"),
    ("마을", "NPC, 시설, 상점과 해금 기능"),
    ("영구 강화", "체력, 공격력, 회복량 등 항목당 최대 10퍼센트에서 15퍼센트"),
    ("이야기", "새벽시계 누적 사용 횟수와 발견한 진실"),
], widths=[1.4, 5.65])
add_body(doc, "영구 능력치는 반복 플레이를 강제하지 않도록 낮게 제한한다. 영구 성장의 중심은 수치 상승보다 새로운 무기와 능력, 직업 조합을 여는 데 둔다.")

add_heading(doc, "난이도 확장", 2)
add_body(doc, "기본 난이도를 완료하면 원정 단계를 순차 해금한다. 상위 난이도는 적의 체력만 높이기보다 새로운 패턴과 위험 규칙을 추가한다.")
add_table(doc, ["단계", "추가 규칙"], [
    ("원정 1", "정예 몬스터 증가"),
    ("원정 2", "회복 효과 감소"),
    ("원정 3", "새로운 적 패턴 추가"),
    ("원정 4", "보스 강화 패턴 추가"),
    ("원정 5", "일부 스테이지에 특수 제약 발생"),
], widths=[1.2, 5.85])

add_heading(doc, "오프라인 저장", 2)
add_bullets(doc, [
    "스테이지 종료와 영구 강화 구매 시 자동 저장한다.",
    "최근 정상 저장 2개를 순환 보관해 파일 손상에 대비한다.",
    "진행 중 도전의 스테이지, 장비, 능력과 경로를 저장한다.",
    "앱 삭제나 기기 변경 시 기록이 사라질 수 있으므로 향후 파일 내보내기와 가져오기를 제공한다.",
])

# 7 World
add_heading(doc, "세계와 스테이지", 1)
add_heading(doc, "네 개 접근 지역", 2)
add_body(doc, "네 지역은 새벽시계의 영향으로 순서가 매번 달라진다. 지역이 등장한 순서에 따라 적 조합과 함정의 단계가 상승한다. 이야기 대사는 특정 지역 순서가 아니라 현재까지 통과한 지역 수와 기억 조각의 보유 상태를 기준으로 제공한다.")
add_table(doc, ["지역", "시각과 이동", "주요 적과 위험"], [
    ("바람꽃 평원", "넓은 발판과 강풍", "판타지 동물과 돌진형 적"),
    ("거꾸로 자란 숲", "수직 이동과 움직이는 덩굴", "식물과 공중 적"),
    ("별시계 유적", "멈추거나 반복되는 발판", "시간 함정과 마법 인형"),
    ("태엽 축제장", "회전 놀이기구와 기계 발판", "장난감 병정과 포탑"),
], widths=[1.55, 2.6, 2.9])

add_heading(doc, "행복의 나라", 2)
add_body(doc, "행복의 나라는 처음 보았을 때 아름답지만 어딘가 부자연스럽다. 주민들은 모두 웃고 있으나 표정과 동작이 반복되고, 음악도 같은 부분으로 돌아온다. 주인공이 기억 조각을 모을수록 미세한 어긋남이 더 선명하게 보인다. 행복의 나라 성문과 중심부는 네 접근 지역을 모두 통과한 뒤 9스테이지와 10스테이지에 고정한다.")

add_heading(doc, "보스 방향", 2)
add_body(doc, "주요 보스는 행복의 나라를 지키는 기사와 주민, 마법으로 움직이는 인형과 기계로 구성한다. 이들은 악의를 가진 적이라기보다 행복을 유지하라는 명령에 묶인 존재다. 전투 중 긴 설명은 피하고 체력 구간별 짧은 대사와 패턴 변화로 사연을 전달한다.")
add_table(doc, ["구분", "가칭", "역할"], [
    ("중간 보스", "웃는 태엽 기사", "정해진 미소와 동작을 반복하는 지역 수호자"),
    ("관문 보스", "행복의 수호기사", "방문자를 돌려보내는 성문 수호자"),
    ("첫 최종 보스", "미소의 여왕 세라", "나라의 행복을 지켜야 하는 통치자"),
    ("진 최종 보스", "행복의 심장", "슬픔 전가 의식을 실행하는 고대 마법 기계"),
    ("숨겨진 보스", "기억 인형", "주인공에게서 지워진 기억으로 만들어진 존재"),
], widths=[1.25, 2.0, 3.8])

# 8 Story
add_heading(doc, "이야기와 인물", 1)
add_heading(doc, "줄거리", 2)
add_body(doc, "원인을 알 수 없는 희귀병으로 죽어가는 로안 또는 루미는 남은 시간을 고향에서 보내는 대신 어릴 때 들었던 행복의 나라를 직접 보기 위해 길을 떠난다. 주인공은 병 때문에 정식 교육을 받지 못해 직업이 없지만, 여행에서 실제로 선택하고 싸우는 방식을 통해 자신만의 직업을 만든다.")
add_body(doc, "여행이 반복되면서 주인공은 자신의 증상이 일반적인 병과 다르다는 사실을 알게 된다. 그림자와 목소리가 늦게 따라오고, 새벽시계의 금과 몸의 이상이 함께 늘어난다. 행복의 나라에 도착한 뒤 주인공이 그 나라에서 기록과 기억을 지우고 추방된 존재였다는 진실이 드러난다.")

add_heading(doc, "행복의 진실", 2)
add_body(doc, "행복의 나라는 모든 슬픔과 고통을 한 아이에게 옮겨 나라 밖으로 추방하는 의식으로 영원한 행복을 유지해왔다. 주인공은 그 의식의 대상이었다. 병은 나라 전체에서 제거된 슬픔과 고통이 몸에 쌓이며 생긴 증상이다. 주인공의 가족은 의식에 반대해 아이를 탈출시키고 새벽시계를 유품으로 남겼다.")

add_heading(doc, "주요 인물", 2)
add_table(doc, ["인물", "설정", "게임 내 역할"], [
    ("로안", "남성형 외형의 주인공", "루미와 같은 능력과 이야기 사용"),
    ("루미", "여성형 외형의 주인공", "로안과 같은 능력과 이야기 사용"),
    ("세라", "주인공의 어린 시절 가장 친한 친구이자 미소의 여왕", "첫 최종 보스와 이후 조력자"),
    ("가족", "주인공을 탈출시키고 새벽시계를 남긴 인물", "후반 기억과 비밀 장소에서 등장"),
], widths=[1.0, 3.15, 2.9])

add_heading(doc, "세라와의 약속", 2)
add_body(doc, "어린 시절 주인공과 세라는 왕궁 밖 시계탑에서 놀며 언젠가 진짜 행복의 나라를 함께 찾자고 약속했다. 의식 이후 세라의 기억에서는 약속한 상대만 지워졌다. 세라는 상대가 누구인지 모른 채 약속을 기억했고 행복의 나라를 지키는 여왕이 되었다. 두 사람의 관계는 연애가 아닌 깊은 우정으로 표현한다.")
add_bullets(doc, [
    "여왕의 일부 공격 동작은 어린 시절 함께하던 놀이와 닮아 있다.",
    "새벽시계에는 세라가 간직한 장식과 같은 문양이 있다.",
    "전투 후반부터 세라의 고정된 미소가 사라지고 기억이 흔들린다.",
    "전투가 끝난 뒤 서로가 약속의 상대였음을 확인한다.",
])

add_heading(doc, "이야기 전달", 2)
add_table(doc, ["방식", "길이와 목적"], [
    ("스테이지 사이 대화", "2문장부터 5문장으로 관계와 현재 단서를 전달"),
    ("중요 구간 연출", "중간 보스 이후 약 20초로 새로운 진실을 제시"),
    ("직업 발현 연출", "잃어버린 기억이 순간적으로 보이는 짧은 장면"),
    ("엔딩 연출", "약 1분으로 핵심 선택의 결과를 정리"),
], widths=[1.65, 5.4])

# 9 Choice and endings
add_heading(doc, "보스 선택과 엔딩", 1)
add_heading(doc, "구출과 파괴", 2)
add_body(doc, "보스를 쓰러뜨린 뒤 구출하거나 완전히 파괴할 수 있다. 서사 상태와 조력 효과는 다음 도전에만 유지되며 그 뒤에는 초기화된다. 처음 발견한 무기와 능력은 영구 해금된다. 같은 보스를 다시 만나 반대 선택을 할 수 있으므로 저장 파일에서 콘텐츠가 영구히 잠기지 않는다.")
add_table(doc, ["선택", "즉시 보상", "영구 해금", "다음 도전"], [
    ("구출", "회복과 보호 계열 보상", "보조 능력", "조력자로 선택 가능"),
    ("파괴", "공격 재화와 강한 무기", "공격 능력과 무기 설계도", "위험 경로 개방"),
], widths=[0.95, 2.0, 2.1, 2.0], font_size=8.8)

add_heading(doc, "조력자", 2)
add_body(doc, "구출한 보스는 다음 도전을 시작할 때 한 명을 조력자로 선택할 수 있다. 추가 조작 버튼은 사용하지 않는다. 조력자는 소규모 패시브 효과를 주고, 정예 몬스터가 나타나면 대표 기술을 자동 사용하며, 플레이어 체력이 낮을 때 도전당 한 번 구조 행동을 한다. 조력자는 피해를 받거나 사망하지 않는다.")

add_heading(doc, "엔딩 구조", 2)
add_body(doc, "새벽시계 사용 횟수는 실패에 대한 벌점이 아니라 진실을 여는 누적 조건으로 사용한다. 한 번 본 진실과 엔딩은 영구 기록한다. 첫 클리어 이후 새로운 경로와 단서를 열어 여러 엔딩을 순차적으로 발견하게 한다.")
add_table(doc, ["엔딩", "조건", "결과 방향"], [
    ("도착", "첫 기본 난이도 클리어", "행복의 나라에 도착하지만 누구도 주인공을 기억하지 못한다."),
    ("귀환", "일정 횟수 이상 되감기", "국민으로 돌아가는 대신 바깥의 기억을 포기한다."),
    ("해방", "주요 기억 조각 수집", "의식을 파괴해 나라 사람들이 슬픔도 함께 느끼게 한다."),
    ("새벽", "비밀 장소와 기억 완성 후 마지막 선택", "마을 사람들과 고통을 나누고 새로운 삶의 방식을 선택한다."),
], widths=[1.0, 2.35, 3.7])

add_heading(doc, "첫 최종 보스 이후", 2)
add_body(doc, "세라를 쓰러뜨리면 구출하거나 왕관과 함께 파괴할 수 있다. 구출하면 이후 행복의 심장에 접근할 때 조력자가 된다. 파괴하면 왕관의 힘을 사용하는 공격형 무기와 직접 진입하는 위험 경로가 열린다. 첫 엔딩 이후 나라의 행복을 관리하는 고대 마법 기계 행복의 심장이 진 최종 보스로 드러난다.")

# 10 Village and presentation
add_heading(doc, "마을과 표현", 1)
add_heading(doc, "시간의 닻 마을", 2)
add_body(doc, "도전 사이에는 NPC와 시설이 늘어나는 작은 마을이 있다. 여행에서 만난 NPC를 도우면 마을로 이주하고 새로운 기능을 연다. 마을이 활기를 찾는 모습은 주인공이 반복 속에서도 남긴 변화이며, 행복의 의미를 보여주는 핵심 장치다.")
add_table(doc, ["NPC", "시설", "기능"], [
    ("대장장이", "대장간", "무기 해금과 승급"),
    ("약초사", "약방", "회복약과 회복 능력 해금"),
    ("지도 제작자", "지도소", "경로 정보와 숨겨진 방 표시"),
    ("음유시인", "광장", "여행 기록과 직업 도감 열람"),
    ("수상한 상인", "잡화점", "시작 유물과 재추첨권 구매"),
], widths=[1.3, 1.35, 4.4])

add_heading(doc, "카툰 벡터 아트", 2)
add_bullets(doc, [
    "두꺼운 외곽선과 선명한 실루엣을 사용한다.",
    "밝은 색을 중심으로 약한 그라데이션만 사용한다.",
    "배경보다 플레이어, 적과 위험 요소의 채도를 높인다.",
    "직업 발현은 망토, 문양, 오라와 무기 이펙트 변화로 보여준다.",
    "병과 시간 관련 장면에서만 색이 빠지거나 화면이 어긋나는 효과를 사용한다.",
    "위험한 공격은 공통 경고색과 바닥 표시를 사용한다.",
])

add_heading(doc, "주인공 외형", 2)
add_body(doc, "플레이 시작 시 로안 또는 루미를 선택한다. 두 외형은 체력, 이동 속도, 판정 크기, 애니메이션 타이밍과 전체 이야기가 같다. 이미지와 음성만 다르게 제작해 밸런스와 스테이지 설계를 공유한다.")

add_heading(doc, "오디오와 접근성", 2)
add_bullets(doc, [
    "지역마다 짧은 반복에도 피로가 적은 배경음을 사용하고 행복의 나라에서는 같은 구절이 부자연스럽게 반복되게 한다.",
    "공격 성공, 피격, 회피 성공과 직업 발현의 효과음을 명확히 구분한다.",
    "진동 강도와 화면 흔들림을 끌 수 있게 한다.",
    "가상 버튼의 크기, 위치와 투명도를 조절할 수 있게 한다.",
    "색상만으로 위험을 구분하지 않고 형태와 바닥 표시를 함께 사용한다.",
    "짧은 연출은 건너뛰고 회상 메뉴에서 다시 볼 수 있게 한다.",
])

# 11 Prototype
add_heading(doc, "첫 전투 프로토타입", 1)
add_heading(doc, "목표", 2)
add_body(doc, "첫 설치 가능한 버전은 약 3분짜리 전투 스테이지 하나만 제공한다. 마을과 직업, 장비 파밍을 붙이기 전에 이동, 자동 공격, 점프, 회피, 두 무기 전환과 네 개 액티브 스킬의 조작이 재미있는지 확인한다.")

add_heading(doc, "포함 기능", 2)
add_bullets(doc, [
    "가로 화면과 로안 또는 루미 선택",
    "좌우 이동과 1단 점프",
    "자동 기본 공격과 현재 대상 표시",
    "지상 회피와 공중 대시",
    "검과 활 빠른 전환",
    "무기별 액티브 스킬 2개",
    "공용 필살기 시간 정지",
    "일반 적 3종과 정예 적 1종",
    "플레이어 체력과 피격",
    "재도전과 메인 화면 복귀",
    "효과음, 진동과 간단한 배경음",
    "조작 버튼 위치와 크기 조절",
])

add_heading(doc, "제외 기능", 2)
add_bullets(doc, [
    "직업 발현과 레벨업",
    "무기 드롭과 등급",
    "스테이지 갈림길",
    "마을과 영구 성장",
    "진행 저장",
    "스토리 연출",
    "보스와 상위 난이도",
    "Google Play 관련 기능",
])

add_heading(doc, "프로토타입 무기", 2)
add_table(doc, ["무기", "기본 공격", "스킬 1", "스킬 2"], [
    ("검", "가까운 적 연속 베기", "돌진 베기", "회전 베기"),
    ("활", "일정 거리의 적에게 화살", "관통 화살", "화살비"),
], widths=[0.9, 2.35, 1.9, 1.9], font_size=9.0)
add_body(doc, "공용 필살기 시간 정지는 게이지가 가득 찼을 때 사용한다. 약 3초 동안 적과 투사체가 느려지고 플레이어만 정상 속도로 움직인다.")

add_heading(doc, "프로토타입 스테이지", 2)
add_table(doc, ["시간", "검증 내용"], [
    ("0분에서 40초", "이동, 점프와 검 공격 학습"),
    ("40초에서 1분 15초", "근접 적과 원거리 적 웨이브"),
    ("1분 15초에서 1분 50초", "발판과 낙하 구간에서 활 사용"),
    ("1분 50초에서 2분 30초", "무기 전환이 필요한 혼합 웨이브"),
    ("2분 30초에서 3분", "돌진형 정예 몬스터"),
], widths=[1.75, 5.3])

add_heading(doc, "적 구성", 2)
add_table(doc, ["적", "검증 목적"], [
    ("근접 슬라임", "기본 자동 조준과 근접 회피"),
    ("씨앗 식물", "원거리 투사체와 접근 판단"),
    ("작은 정령", "공중 표적과 활 조준"),
    ("돌진 정예", "경고 표시, 지상 회피와 공중 대시"),
], widths=[1.55, 5.5])

add_heading(doc, "합격 기준", 2)
add_bullets(doc, [
    "이동과 점프가 즉각 반응한다.",
    "자동 공격이 원하지 않는 적을 계속 공격하지 않는다.",
    "무기 전환과 스킬 변경을 한눈에 인지할 수 있다.",
    "버튼을 보지 않고도 주요 액션을 사용할 수 있다.",
    "3분 플레이 후 재도전 의사가 생긴다.",
    "일반적인 안드로이드 기기에서 60 FPS를 안정적으로 유지한다.",
])

# 12 Roadmap
add_heading(doc, "개발 단계", 1)
add_table(doc, ["단계", "주요 결과", "다음 단계 조건"], [
    ("1 전투 프로토타입", "1개 스테이지와 검 활 조작", "조작과 자동 조준이 재미있고 안정적임"),
    ("2 성장 시제품", "레벨업, 능력 카드, 직업 2개", "무작위 선택과 직업 발현이 이해됨"),
    ("3 반복 구조", "5개 스테이지, 마을, 실패와 영구 해금", "다시 시작할 동기가 확인됨"),
    ("4 세로 완성본", "지역 1개, 보스, 이야기와 엔딩 일부", "한 지역의 품질 기준이 확정됨"),
    ("5 정식 콘텐츠", "지역 4개, 무기 6종, 직업 6개와 상위 12개", "전체 밸런스와 성능 검증 완료"),
    ("6 출시 준비", "저장 안정화, 기기 테스트, 스토어 자료", "Google Play 검수 기준 충족"),
], widths=[1.35, 3.4, 2.3], font_size=8.7)

add_heading(doc, "우선 검증할 위험", 2)
add_table(doc, ["위험", "문제", "검증 방법"], [
    ("자동 공격", "원하지 않는 적을 공격하면 통제감을 잃음", "대상 표시와 방향 우선 규칙을 프로토타입에서 반복 테스트"),
    ("버튼 수", "점프, 회피, 무기 전환과 스킬이 화면을 가림", "버튼 위치 조절과 실제 기기 엄지 조작 테스트"),
    ("무기별 스킬", "두 무기와 네 스킬이 복잡할 수 있음", "검과 활만 제공해 인지 시간을 측정"),
    ("직업 발현", "원치 않는 직업이 자동 발현될 수 있음", "가까운 후보와 남은 성향 점수를 HUD에 표시"),
    ("콘텐츠 규모", "직업과 상위 직업의 효과 제작량이 큼", "2개 직업 시제품을 먼저 만든 뒤 제작 비용 산정"),
    ("이야기 반복", "같은 대화가 반복되면 피로함", "지역 순서와 기억 상태에 따른 짧은 대화 풀 구성"),
], widths=[1.15, 2.95, 2.95], font_size=8.6)

add_heading(doc, "출시 목표 콘텐츠", 2)
add_table(doc, ["분류", "목표"], [
    ("지역", "접근 지역 4개와 행복의 나라 최종 구간"),
    ("무기", "검, 주먹, 활, 지팡이, 장봉, 방패"),
    ("직업", "기본 6개와 상위 12개"),
    ("스테이지", "도전당 10개, 각 약 3분"),
    ("보스", "지역 중간 보스, 관문 보스, 세라, 행복의 심장과 숨겨진 보스"),
    ("엔딩", "도착, 귀환, 해방과 새벽 엔딩"),
    ("운영", "서버, 광고와 결제 없이 완전 오프라인"),
], widths=[1.3, 5.75])

add_heading(doc, "다음 기획 작업", 2)
add_numbered(doc, [
    "첫 프로토타입의 화면 배치와 터치 영역을 와이어프레임으로 확정한다.",
    "검과 활의 공격 속도, 사거리, 스킬 수치와 적 체력의 초기 밸런스를 작성한다.",
    "프로토타입 제작 엔진과 안드로이드 빌드 기준을 결정한다.",
    "첫 스테이지의 발판, 웨이브와 정예 적 행동을 상세 설계한다.",
    "실제 기기 테스트 항목과 플레이 기록 양식을 만든다.",
])

p = doc.add_paragraph()
p.paragraph_format.space_before = Pt(16)
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = p.add_run("Happiness Tale: Rewind to Dawn  게임 기획서  버전 0.1")
set_run_font(r, size=9, bold=True, color=GRAY)

doc.core_properties.title = "Happiness Tale: Rewind to Dawn 게임 기획서"
doc.core_properties.subject = "안드로이드 횡스크롤 로그라이트 게임 기획"
doc.core_properties.comments = "게임 기획서 버전 0.1"

doc.save(OUTPUT)
print(OUTPUT)
