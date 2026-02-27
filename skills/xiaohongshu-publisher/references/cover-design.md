# Xiaohongshu Cover Image Design Guide

## Optimal Specs

- **Ratio**: 3:4 vertical (1080×1440px)
- **Format**: JPG, quality 95
- **Max size**: 32MB

## Best Performing Cover Styles (Knowledge Accounts)

Based on real Xiaohongshu research (Feb 2026), knowledge/career accounts perform best with:

1. **Infographic/Flowchart** — Structured visual with icons, hierarchy, knowledge maps
2. **Bold Title + Bullet Points** — High-saturation background (red/blue/yellow) + white text + key points
3. **Handwritten/Whiteboard** — Approachable, high recognition
4. **Data Visualization** — Charts, comparisons, before/after

**Person photos are NOT the norm** for knowledge content. Save selfies/lifestyle photos for personal diary posts.

## Cover Design Rules

- **3-second rule**: Core message must be readable in 3 seconds at thumbnail size
- **Top-heavy layout**: Put key info in upper 2/3 (bottom may be cropped by title bar)
- **High saturation colors**: White/light backgrounds work but need bold colored text. Avoid all-dark covers.
- **Max 3 lines of title text** on cover
- **No pure-color + single-line-text covers** — zero appeal
- **Test at thumbnail size** before publishing

## Python PIL Template

```python
from PIL import Image, ImageDraw, ImageFont

img = Image.new('RGB', (1080, 1440), '#FFFDF5')
draw = ImageDraw.Draw(img)

# Use system CJK font
font = ImageFont.truetype("/System/Library/Fonts/STHeiti Medium.ttc", 80)

# Tag label
draw.rounded_rectangle([(60, 50), (300, 110)], radius=25, fill='#FF4757')
draw.text((80, 55), "标签文字", font=ImageFont.truetype(..., 32), fill='white')

# Big title
draw.text((60, 150), "主标题", font=font, fill='#FF4757')
draw.text((60, 260), "副标题", font=font, fill='#2d3436')

# Key points with colored bullets
y = 500
for point in ["要点1", "要点2", "要点3"]:
    draw.ellipse([(60, y+10), (84, y+34)], fill='#FF4757')
    draw.text((100, y), point, font=ImageFont.truetype(..., 36), fill='#2d3436')
    y += 60

img.save("cover.jpg", quality=95)
```

## Font Paths (macOS)

- `/System/Library/Fonts/STHeiti Medium.ttc` — Bold CJK
- `/System/Library/Fonts/PingFang.ttc` — Clean CJK
- `/System/Library/Fonts/Hiragino Sans GB.ttc` — Alternative
