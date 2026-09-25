"""Generate high-fidelity Lift Log phone screenshots for the marketing site."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

W, H = 390, 844
BG = (26, 26, 26)
SURFACE = (43, 43, 43)
FG = (243, 243, 243)
MUTED = (148, 148, 148)
BORDER = (58, 58, 58)
ACCENT = (126, 255, 178)
ACCENT_ON = (10, 46, 24)
DANGER = (228, 87, 87)
MYO = (122, 140, 255)
CHEAT = (232, 193, 90)
OUT = Path(__file__).resolve().parent


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf",
        "C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def rr(draw: ImageDraw.ImageDraw, box, radius: int, fill=None, outline=None, width: int = 1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def draw_status(draw: ImageDraw.ImageDraw, title_right: str = "9:41"):
    draw.text((28, 14), title_right, fill=MUTED, font=font(13, True))
    # simple status dots
    for i, x in enumerate((330, 348, 366)):
        draw.ellipse((x, 16, x + 8, 24), fill=FG if i < 2 else MUTED)


def draw_tab_bar(img: Image.Image, active: int):
    draw = ImageDraw.Draw(img)
    y0 = H - 78
    draw.rectangle((0, y0, W, H), fill=(26, 26, 26, 235))
    draw.line((0, y0, W, y0), fill=BORDER, width=1)
    items = [
        ("Шаблоны", 0),
        ("Тренировка", 1),
        ("Статистика", 2),
    ]
    slot = W // 3
    for i, (label, _) in enumerate(items):
        cx = slot * i + slot // 2
        on = i == active
        color = ACCENT if on else MUTED
        # icon placeholder bars
        if i == 0:
            draw.rectangle((cx - 10, y0 + 14, cx + 10, y0 + 30), outline=color, width=2)
        elif i == 1:
            draw.ellipse((cx - 10, y0 + 14, cx + 10, y0 + 34), outline=color, width=2)
            draw.line((cx, y0 + 18, cx, y0 + 30), fill=color, width=2)
        else:
            for j, h in enumerate((10, 16, 12)):
                x = cx - 12 + j * 10
                draw.rectangle((x, y0 + 32 - h, x + 6, y0 + 32), fill=color)
        draw.text((cx, y0 + 40), label, fill=color, font=font(11, on), anchor="mt")


def phone_chrome(img: Image.Image) -> Image.Image:
    """Wrap content in a subtle device bezel for realism."""
    pad = 18
    out_w, out_h = W + pad * 2, H + pad * 2
    canvas = Image.new("RGB", (out_w, out_h), (18, 18, 18))
    d = ImageDraw.Draw(canvas)
    rr(d, (0, 0, out_w - 1, out_h - 1), 48, fill=(28, 28, 28), outline=(55, 55, 55), width=2)
    # notch
    rr(d, (out_w // 2 - 48, 10, out_w // 2 + 48, 28), 12, fill=(12, 12, 12))
    canvas.paste(img, (pad, pad))
    return canvas


def screenshot_templates() -> Image.Image:
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)
    draw_status(draw)
    draw.text((24, 48), "Lift Log", fill=FG, font=font(28, True))

    # primary CTA
    rr(draw, (24, 100, W - 24, 148), 14, fill=ACCENT)
    draw.text((W // 2, 124), "Начать пустую тренировку", fill=ACCENT_ON, font=font(15, True), anchor="mm")

    rr(draw, (24, 160, W - 24, 208), 14, fill=SURFACE, outline=BORDER, width=1)
    draw.text((W // 2, 184), "Создать шаблон", fill=FG, font=font(15, True), anchor="mm")

    draw.text((24, 232), "ДАННЫЕ", fill=MUTED, font=font(11, True))
    rr(draw, (24, 252, W - 24, 296), 12, fill=SURFACE, outline=BORDER)
    draw.text((40, 266), "Скачать резервную копию", fill=FG, font=font(14))

    draw.text((24, 320), "ШАБЛОНЫ", fill=MUTED, font=font(11, True))

    templates = [
        ("Push A", "4 упр. · 16 подх. · Жим лёжа, Жим гантелей"),
        ("Pull B", "4 упр. · 14 подх. · Тяга в наклоне, Подтягивания"),
        ("Legs", "3 упр. · 12 подх. · Присед, Румынская тяга"),
    ]
    y = 344
    for name, sub in templates:
        rr(draw, (24, y, W - 24, y + 78), 14, fill=SURFACE, outline=BORDER)
        draw.text((40, y + 16), name, fill=FG, font=font(17, True))
        draw.text((40, y + 44), sub, fill=MUTED, font=font(12))
        # play circle
        draw.ellipse((W - 70, y + 22, W - 38, y + 54), outline=ACCENT, width=2)
        draw.polygon([(W - 58, y + 30), (W - 58, y + 46), (W - 46, y + 38)], fill=ACCENT)
        y += 90

    draw_tab_bar(img, 0)
    return phone_chrome(img)


def screenshot_workout() -> Image.Image:
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)
    draw_status(draw, "42:18")

    # session header chip
    rr(draw, (24, 44, W - 24, 78), 10, fill=SURFACE)
    draw.text((36, 54), "PUSH A — живой лог", fill=MUTED, font=font(13))
    draw.text((W - 36, 54), "42:18", fill=ACCENT, font=font(13, True), anchor="ra")

    draw.text((24, 100), "Жим лёжа", fill=FG, font=font(22, True))
    draw.text((24, 130), "Подход 3 · цель 8 повт.", fill=MUTED, font=font(13))

    # weight / reps cards
    rr(draw, (24, 160, 186, 232), 12, fill=SURFACE, outline=BORDER)
    draw.text((40, 174), "ВЕС", fill=MUTED, font=font(11, True))
    draw.text((40, 198), "80", fill=FG, font=font(28, True))
    rr(draw, (204, 160, W - 24, 232), 12, fill=SURFACE, outline=BORDER)
    draw.text((220, 174), "ПОВТ.", fill=MUTED, font=font(11, True))
    draw.text((220, 198), "8", fill=FG, font=font(28, True))

    draw.text((24, 256), "ТИП ПОДХОДА", fill=MUTED, font=font(11, True))
    chips = [
        ("Обычный", ACCENT, ACCENT_ON, True),
        ("Дроп", DANGER, DANGER, False),
        ("Мио", MYO, MYO, False),
        ("Читинг", CHEAT, CHEAT, False),
    ]
    gap, x0 = 8, 24
    chip_w = (W - 48 - 3 * gap) // 4
    for i, (label, color, text_c, filled) in enumerate(chips):
        x = x0 + i * (chip_w + gap)
        box = (x, 274, x + chip_w, 310)
        if filled:
            rr(draw, box, 10, fill=color)
            draw.text((x + chip_w / 2, 292), label, fill=text_c, font=font(11, True), anchor="mm")
        else:
            rr(draw, box, 10, fill=SURFACE, outline=color, width=1)
            draw.text((x + chip_w / 2, 292), label, fill=color, font=font(11), anchor="mm")

    sets = [
        ("80 × 8", "обычный", ACCENT, "#1"),
        ("80 × 8", "обычный", ACCENT, "#2"),
        ("70 × 10", "дроп-сет", DANGER, "#3"),
    ]
    y = 334
    for vals, kind, color, num in sets:
        outline = ACCENT if num == "#3" else BORDER
        rr(draw, (24, y, W - 24, y + 56), 12, fill=SURFACE, outline=outline, width=1 if num != "#3" else 2)
        draw.ellipse((40, y + 20, 56, y + 36), fill=color)
        draw.text((68, y + 12), vals, fill=FG, font=font(14, True))
        draw.text((68, y + 32), kind, fill=MUTED if color == ACCENT else color, font=font(12))
        draw.text((W - 40, y + 20), num, fill=MUTED, font=font(12), anchor="ra")
        y += 66

    rr(draw, (24, y + 4, W - 24, y + 68), 14, fill=ACCENT)
    draw.text((W // 2, y + 36), "Записать подход", fill=ACCENT_ON, font=font(16, True), anchor="mm")

    draw.text((24, y + 92), "ТОННАЖ СЕССИИ", fill=MUTED, font=font(11, True))
    draw.text((24, y + 114), "12 480 кг", fill=FG, font=font(26, True))
    draw.text((W - 24, y + 124), "Lift Log", fill=ACCENT, font=font(13, True), anchor="ra")

    draw_tab_bar(img, 1)
    return phone_chrome(img)


def screenshot_stats() -> Image.Image:
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)
    draw_status(draw)
    draw.text((24, 48), "Статистика", fill=FG, font=font(28, True))

    # segment control
    rr(draw, (24, 100, W - 24, 140), 12, fill=SURFACE)
    segs = ["Рабочий вес", "1ПМ", "Сводка"]
    sw = (W - 48) / 3
    for i, s in enumerate(segs):
        x0 = 24 + i * sw
        if i == 0:
            rr(draw, (x0 + 4, 106, x0 + sw - 4, 134), 8, fill=ACCENT)
            draw.text((x0 + sw / 2, 120), s, fill=ACCENT_ON, font=font(12, True), anchor="mm")
        else:
            draw.text((x0 + sw / 2, 120), s, fill=MUTED, font=font(12), anchor="mm")

    draw.text((24, 168), "Жим лёжа", fill=FG, font=font(18, True))
    draw.text((24, 196), "Рабочий вес · последние сессии", fill=MUTED, font=font(12))

    # chart area
    rr(draw, (24, 228, W - 24, 420), 16, fill=SURFACE, outline=BORDER)
    points = [(50, 360), (110, 320), (170, 300), (230, 270), (290, 250), (340, 240)]
    for a, b in zip(points, points[1:]):
        draw.line([a, b], fill=ACCENT, width=3)
    for x, y in points:
        draw.ellipse((x - 4, y - 4, x + 4, y + 4), fill=ACCENT)

    draw.text((40, 248), "80 кг", fill=MUTED, font=font(12))
    draw.text((W - 40, 248), "95 кг", fill=ACCENT, font=font(12, True), anchor="ra")

    # metric cards
    cards = [
        ("Тоннаж", "48.2 т", "за 30 дней"),
        ("1ПМ (Epley)", "118 кг", "жим лёжа"),
        ("Сессии", "12", "в этом месяце"),
    ]
    y = 448
    for title, value, sub in cards:
        rr(draw, (24, y, W - 24, y + 72), 14, fill=SURFACE, outline=BORDER)
        draw.text((40, y + 14), title, fill=MUTED, font=font(12))
        draw.text((40, y + 36), value, fill=FG, font=font(20, True))
        draw.text((W - 40, y + 40), sub, fill=MUTED, font=font(12), anchor="ra")
        y += 84

    draw_tab_bar(img, 2)
    return phone_chrome(img)


def main():
    shots = {
        "screenshot-hero.png": screenshot_workout(),
        "screenshot-templates.png": screenshot_templates(),
        "screenshot-stats.png": screenshot_stats(),
    }
    for name, im in shots.items():
        path = OUT / name
        im.save(path, "PNG", optimize=True)
        print(f"wrote {path} {im.size}")


if __name__ == "__main__":
    main()
