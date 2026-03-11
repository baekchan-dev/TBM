#!/usr/bin/env python3
"""
ST7735 LCD Screen Simulator
============================
Renders LCD screen buffers and converts them to the actual LCD view
for visual verification without needing physical hardware.

Usage:
    python simulate_screens.py <images_dir> <fonts_dir> <output_dir> [--angle 270]

The script renders a set of test screens and saves two versions:
  - <output_dir>/buffer/  : raw 128x160 buffer (what the code draws)
  - <output_dir>/lcd/     : rotated view (what appears on the physical LCD)

The LCD view rotation is determined by the MADCTL setting and physical
mounting orientation. Use --lcd-rotate to specify the final rotation
applied to convert buffer → LCD view (default: 90 CW = rotate(90)).
"""

import argparse
import os
from PIL import Image, ImageDraw, ImageFont


def make_text_image(text, font, fill=(255, 255, 255)):
    """Render text to a transparent RGBA image."""
    tmp = Image.new('RGBA', (1, 1))
    d = ImageDraw.Draw(tmp)
    bbox = d.textbbox((0, 0), text, font=font)
    w = max(bbox[2] - bbox[0], 1)
    h = max(bbox[3] - bbox[1], 1)
    img = Image.new('RGBA', (w, h + 4), (0, 0, 0, 0))
    ImageDraw.Draw(img).text((-bbox[0], -bbox[1]), text, font=font, fill=fill)
    return img


def draw_left(buf, text, x, y, angle, font, fill=(255, 255, 255)):
    """Draw left-justified rotated text at (x, y)."""
    ti = make_text_image(text, font, fill)
    rt = ti.rotate(angle, expand=True)
    buf.paste(rt, (x, y), rt)


def draw_right(buf, text, x, y_from_right, angle, font, fill=(255, 255, 255)):
    """Draw right-justified rotated text (y measured from right edge)."""
    ti = make_text_image(text, font, fill)
    w, _ = ti.size
    rt = ti.rotate(angle, expand=True)
    HEIGHT = buf.size[1]
    buf.paste(rt, (x, int((HEIGHT - w) - y_from_right)), rt)


def draw_center(buf, text, x, angle, font, fill=(255, 255, 255)):
    """Draw horizontally centered rotated text at row x."""
    ti = make_text_image(text, font, fill)
    w, _ = ti.size
    rt = ti.rotate(angle, expand=True)
    HEIGHT = buf.size[1]
    buf.paste(rt, (x, int((HEIGHT - w) / 2)), rt)


def load_bg(images_dir, name, width=128, height=160):
    """Load background PNG, resize to 160x128, rotate 270° into buffer."""
    img = Image.open(os.path.join(images_dir, name)).convert('RGBA')
    img = img.resize((160, 128), Image.BICUBIC)
    rotated = img.rotate(270, expand=True)
    buf = Image.new('RGB', (width, height))
    buf.paste(rotated, (0, 0), rotated)
    return buf


def display_icon(buf, path, position, size):
    """Paste a PNG icon rotated 270° at position."""
    pic = Image.open(path).convert('RGBA')
    pic = pic.resize((size, size), Image.BICUBIC)
    rt = pic.rotate(270, expand=True)
    buf.paste(rt, position, rt)


def save_screen(buf, name, buf_dir, lcd_dir, lcd_rotate=90):
    """Save raw buffer and LCD-view (rotated) versions."""
    buf.save(os.path.join(buf_dir, name))
    lcd = buf.rotate(lcd_rotate, expand=True)
    lcd.save(os.path.join(lcd_dir, name))


def main():
    parser = argparse.ArgumentParser(description='ST7735 LCD Screen Simulator')
    parser.add_argument('images_dir', help='Path to background images directory')
    parser.add_argument('fonts_dir', help='Path to Poppins fonts directory')
    parser.add_argument('output_dir', help='Output directory for simulated screens')
    parser.add_argument('--angle', type=int, default=270,
                        help='Text rotation angle (default: 270)')
    parser.add_argument('--lcd-rotate', type=int, default=90,
                        help='Rotation to apply to buffer for LCD view (default: 90)')
    args = parser.parse_args()

    buf_dir = os.path.join(args.output_dir, 'buffer')
    lcd_dir = os.path.join(args.output_dir, 'lcd')
    os.makedirs(buf_dir, exist_ok=True)
    os.makedirs(lcd_dir, exist_ok=True)

    angle = args.angle
    lcd_rotate = args.lcd_rotate

    def font(size):
        return ImageFont.truetype(os.path.join(args.fonts_dir, 'Poppins-Bold.ttf'), size)

    # ── Screen 1: Bitcoin Price ──────────────────────────────────────────────
    buf = load_bg(args.images_dir, 'Screen1@288x.png')
    display_icon(buf, os.path.join(args.images_dir, 'bitcoin_seeklogo.png'), (80, 2), 27)
    display_icon(buf, os.path.join(args.images_dir, 'Satoshi_regular_elipse.png'), (27, 2), 27)
    price = "83907"
    fs = min(int(195 / len(price)), 39)
    draw_left(buf, price, 79 + int((39 - fs) / 2), 30, angle, font(fs))
    draw_right(buf, "USD", 128 - 1 - 12, 4, angle, font(12))
    draw_left(buf, "SATS / USD", 1, 39, angle, font(14))
    sat_val = "1191"
    sf = min(int(200 / len(sat_val)) if len(sat_val) > 4 else 50, 50)
    draw_left(buf, sat_val, 24 + int((50 - sf) / 2), 30, angle, font(sf))
    draw_right(buf, "51'C", 3, 3, angle, font(12))
    save_screen(buf, 'screen1_btcprice.png', buf_dir, lcd_dir, lcd_rotate)

    # ── Screen 2: Transactions ───────────────────────────────────────────────
    buf = load_bg(args.images_dir, 'TxsBG.png')
    high, low = 72, 4
    def fee_fs(n): return int(86 / n) if n > 2 else 43
    low_x = 90 if len(str(low)) == 3 else 85
    high_x = 90 if len(str(high)) == 3 else 85
    draw_left(buf, str(low), low_x, 9, angle, font(fee_fs(len(str(low)))))
    draw_left(buf, str(high), high_x, 88, angle, font(fee_fs(len(str(high)))))
    txs = 2353
    txs_fs = int(112 / len(str(txs))) if len(str(txs)) > 4 else 28
    draw_left(buf, str(txs), 43, 67, angle, font(txs_fs))
    unconf = "34133"
    u_fs = int(120 / len(unconf)) if len(unconf) > 5 else 24
    draw_left(buf, unconf, 7, 64, angle, font(u_fs))
    save_screen(buf, 'screen2_txs.png', buf_dir, lcd_dir, lcd_rotate)

    # ── Screen 3: Block Height ───────────────────────────────────────────────
    buf = load_bg(args.images_dir, 'Block_HeightBG.png')
    draw_center(buf, "939236", 128 - 72 - 40, angle, font(40))
    save_screen(buf, 'screen3_block.png', buf_dir, lcd_dir, lcd_rotate)

    # ── Screen 4: Date/Time ──────────────────────────────────────────────────
    buf = Image.new('RGB', (128, 160), (0, 0, 50))
    draw_center(buf, "6:02 AM", 128 - 16 - 30, angle, font(30))
    draw_center(buf, "Friday", 128 - 59 - 26, angle, font(26))
    draw_center(buf, "March 06", 128 - 91 - 22, angle, font(22))
    save_screen(buf, 'screen4_datetime.png', buf_dir, lcd_dir, lcd_rotate)

    # ── Screen 5: Network ────────────────────────────────────────────────────
    buf = load_bg(args.images_dir, 'network.png')
    for val, unit, x_val, x_unit, y_map in [
        ("11", "Peers", 68, 55, {1: 27, 2: 23, 3: 19}),
        ("816", "KB", 68, 55, {1: 108, 2: 101, 3: 98}),
    ]:
        y = y_map.get(len(val), 19)
        draw_left(buf, val, x_val, y, angle, font(15))
        draw_left(buf, unit, x_unit, 22 if unit == "Peers" else 105, angle, font(9))
    for val, unit, x_val, x_unit, y_map in [
        ("240", "EH/s", 22, 8, {1: 27, 2: 23, 3: 19}),
        ("457", "GB", 22, 8, {1: 108, 2: 101, 3: 98}),
    ]:
        y = y_map.get(len(val), 19)
        draw_left(buf, val, x_val, y, angle, font(15))
        draw_left(buf, unit, x_unit, 22 if unit == "EH/s" else 105, angle, font(9))
    save_screen(buf, 'screen5_network.png', buf_dir, lcd_dir, lcd_rotate)

    # ── Screen 6: Payment Channels ───────────────────────────────────────────
    buf = load_bg(args.images_dir, 'payment_channels.png')
    connections, active = 5, 0
    conn_y = {1: 27, 2: 23, 3: 19}.get(len(str(connections)), 19)
    ch_y = {1: 108, 2: 101, 3: 98}.get(len(str(active)), 98)
    draw_left(buf, str(connections), 68, conn_y, angle, font(15))
    draw_left(buf, str(active), 68, ch_y, angle, font(15))
    draw_left(buf, "Peers", 55, 22, angle, font(9))
    draw_left(buf, "Channels", 55, 98, angle, font(9))
    send_y = {1: 27, 2: 23, 3: 19, 4: 15, 5: 10}.get(1, 6)
    recv_y = {1: 108, 2: 101, 3: 98, 4: 93, 5: 90}.get(1, 90)
    draw_left(buf, "0", 22, send_y, angle, font(15))
    draw_left(buf, "0", 22, recv_y, angle, font(15))
    draw_left(buf, "BTC", 8, 22, angle, font(10))
    draw_left(buf, "BTC", 8, 100, angle, font(10))
    save_screen(buf, 'screen6_channels.png', buf_dir, lcd_dir, lcd_rotate)

    # ── Screen 7: Storage ────────────────────────────────────────────────────
    buf = load_bg(args.images_dir, 'storage.png')
    draw_left(buf, "929.6 GB", 59, 7, angle, font(20))
    draw_left(buf, "Used out of 2.0 TB", 44, 7, angle, font(11))
    draw_right(buf, "1.0 TB available", 13, 11, angle, font(11))
    d = ImageDraw.Draw(buf)
    x, y, w, h = 29, 7, 2, 140
    inner_h = int((90 * h) / 100) + y
    d.rectangle((x, y, x + w, y + h), outline=(255, 255, 255), fill=(255, 255, 255))
    d.rectangle((x, y, x + w, inner_h), outline=(0, 160, 0), fill=(0, 160, 0))
    save_screen(buf, 'screen7_storage.png', buf_dir, lcd_dir, lcd_rotate)

    print(f"Simulation complete. Buffer: {buf_dir}  LCD view: {lcd_dir}")


if __name__ == '__main__':
    main()
