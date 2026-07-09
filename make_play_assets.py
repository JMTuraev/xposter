# -*- coding: utf-8 -*-
"""Xposter uchun Google Play store-listing asset'lari."""
import os
from PIL import Image, ImageDraw, ImageFont

SRC = "/sessions/gallant-inspiring-davinci/mnt/poster/buxoro_pos"
OUT = "/sessions/gallant-inspiring-davinci/mnt/poster/play-assets"
os.makedirs(OUT, exist_ok=True)
os.makedirs(os.path.join(OUT, "screenshots"), exist_ok=True)

CREAM   = (250, 249, 245)
CREAM2  = (240, 238, 230)
TERRA   = (217, 119, 87)
TERRA_DK= (201, 100, 66)
OLIVE   = (120, 140, 93)
INK     = (20, 20, 19)
SECOND  = (110, 107, 99)
WHITE   = (255, 255, 255)

FS_B  = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FS_R  = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
SER_B = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"

def font(path, size): return ImageFont.truetype(path, size)

def rounded(draw, box, r, fill):
    draw.rounded_rectangle(box, radius=r, fill=fill)

def make_icon():
    S = 512
    img = Image.new("RGB", (S, S), TERRA)
    d = ImageDraw.Draw(img)
    d.polygon([(S, 0), (S, S), (0, S)], fill=TERRA_DK)
    f = font(SER_B, 300)
    tw = d.textbbox((0, 0), "X", font=f)
    w = tw[2]-tw[0]; h = tw[3]-tw[1]
    d.text(((S-w)/2 - tw[0], (S-h)/2 - tw[1] - 10), "X", font=f, fill=WHITE)
    fd = font(FS_B, 46)
    sub = "poster"
    sb = d.textbbox((0, 0), sub, font=fd)
    sw = sb[2]-sb[0]
    d.text(((S-sw)/2 - sb[0], 400), sub, font=fd, fill=WHITE)
    img.save(os.path.join(OUT, "icon-512.png"))
    print("icon done")

def make_feature():
    W, H = 1024, 500
    img = Image.new("RGB", (W, H), CREAM)
    d = ImageDraw.Draw(img)
    d.rectangle([620, 0, W, H], fill=TERRA)
    d.polygon([(620, 0), (700, 0), (620, H)], fill=CREAM)
    d.text((60, 120), "Xposter", font=font(SER_B, 92), fill=INK)
    d.text((64, 235), "Choyxona va restoran uchun", font=font(FS_R, 34), fill=SECOND)
    d.text((64, 280), "zamonaviy kassa (POS) tizimi", font=font(FS_R, 34), fill=SECOND)
    pill_txt = "Kassa • Menyu • Ombor • Hisobot"
    pf = font(FS_B, 22)
    pb = d.textbbox((0, 0), pill_txt, font=pf)
    pw = pb[2]-pb[0]
    rounded(d, [64, 350, 64+pw+52, 408], 29, TERRA)
    d.text((90, 366), pill_txt, font=pf, fill=WHITE)
    try:
        shot = Image.open(os.path.join(SRC, "screen_final.png")).convert("RGB")
        ph_h = 430; ratio = ph_h / shot.height
        ph_w = int(shot.width * ratio)
        shot = shot.resize((ph_w, ph_h))
        frame = Image.new("RGB", (ph_w+16, ph_h+16), INK)
        frame.paste(shot, (8, 8))
        img.paste(frame, (760, 35))
    except Exception as e:
        print("feat shot err", e)
    img.save(os.path.join(OUT, "feature-1024x500.png"))
    print("feature done")

SHOTS = [
    ("screen_final.png",       "Bosh sahifa — kunlik daromad va tez amallar"),
    ("screen.png",             "Kassa — chek ochish va sotuv"),
    ("screen_stats.png",       "Statistika — savdo tahlili"),
    ("screen_finance.png",     "Moliya — daromad va xarajatlar"),
    ("screen_loyalty.png",     "Marketing — mijozlar sodiqligi"),
    ("screen_pererabotka.png", "Ombor — qoldiq va qayta ishlash"),
    ("screen_limit.png",       "Nazorat — limitlar va cheklovlar"),
]

def make_screens():
    W, H = 1440, 2560  # 9:16 exactly
    brand_f = font(SER_B, 72)
    cap_f = font(FS_B, 40)
    for i, (fn, cap) in enumerate(SHOTS, 1):
        p = os.path.join(SRC, fn)
        if not os.path.exists(p):
            print("skip", fn); continue
        shot = Image.open(p).convert("RGB")
        sw, sh = shot.size
        head_h = 250
        canvas = Image.new("RGB", (W, H), CREAM)
        d = ImageDraw.Draw(canvas)
        bt = d.textbbox((0, 0), "Xposter", font=brand_f)
        bw = bt[2]-bt[0]
        d.text(((W-bw)/2 - bt[0], 40), "Xposter", font=brand_f, fill=TERRA)
        cb = d.textbbox((0, 0), cap, font=cap_f)
        cw = cb[2]-cb[0]
        d.text(((W-cw)/2 - cb[0], 152), cap, font=cap_f, fill=SECOND)
        x = (W - sw)//2
        y = head_h + 10
        bordered = Image.new("RGB", (sw+4, sh+4), CREAM2)
        bordered.paste(shot, (2, 2))
        canvas.paste(bordered, (x-2, y-2))
        out = os.path.join(OUT, "screenshots", f"{i:02d}_{fn}")
        canvas.save(out)
        print(f"screen {i}: {W}x{H} brand=Xposter -> {out}")

make_icon()
make_feature()
make_screens()
print("ALL DONE ->", OUT)
