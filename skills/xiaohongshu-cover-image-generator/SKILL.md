---
name: xiaohongshu-cover-image-generator
description: Generate AI background images for Xiaohongshu (小红书) post covers. Creates conceptual, no-people backgrounds optimized for text overlay using DashScope Tongyi Wanxiang.
allowed-tools: Bash(curl:*) Bash(python3:*) Bash(bash:*) Read Write
---

# Xiaohongshu Cover Image Generator

Generate AI background images for XHS post covers using DashScope Tongyi Wanxiang (通义万相) `wan2.6-t2i`.

## Quick Start

```bash
bash ~/.openclaw/skills/xiaohongshu-cover-image-generator/scripts/generate.sh \
  "科技感数据可视化背景，深色调" --style tech_futuristic --aspect portrait
```

Output (JSON to stdout):

```json
{
  "status": "success",
  "file": "/tmp/xhs_cover_20260226_143052.jpg",
  "width": 1080,
  "height": 1440,
  "size_bytes": 245832,
  "provider": "dashscope/wan2.6-t2i",
  "style": "tech_futuristic",
  "aspect": "portrait",
  "prompt_used": "Futuristic technology, circuit board patterns, ..."
}
```

## Parameters

| Parameter  | Required | Default    | Description                                    |
| ---------- | -------- | ---------- | ---------------------------------------------- |
| `<prompt>` | Yes      | -          | Image description (Chinese or English)         |
| `--style`  | No       | `auto`     | Style preset (see below)                       |
| `--aspect` | No       | `portrait` | `portrait` (1080x1440) or `square` (1080x1080) |
| `--seed`   | No       | random     | Seed for reproducible output                   |

## Style Presets

| Style               | Use Case                                       |
| ------------------- | ---------------------------------------------- |
| `auto`              | No prefix; use when prompt is already detailed |
| `cyberpunk`         | Tech, AI, gaming, neon aesthetic               |
| `minimalist`        | Lifestyle, productivity, clean design          |
| `infographic`       | Data, business, how-to guides                  |
| `realistic_scene`   | Food, travel, product, nature                  |
| `watercolor`        | Art, culture, poetry, emotional                |
| `gradient_abstract` | General purpose, announcements, quotes         |
| `tech_futuristic`   | AI/ML, semiconductors, science                 |
| `nature_zen`        | Wellness, meditation, traditional culture      |

See `references/style-presets.md` for detailed prompt prefixes and color palettes.

## Key Features

- **No-people enforcement**: Negative prompt blocks human figures in both Chinese and English
- **Auto-resize**: API generates at closest supported size, then PIL resizes to exact XHS dimensions
- **JPG output**: Quality 95, optimized, ready for XHS upload
- **Error handling**: JSON error output with diagnostic info

## Integration with xiaohongshu-publisher

Chain with the XHS publisher skill:

```bash
# 1. Generate cover image
RESULT=$(bash ~/.openclaw/skills/xiaohongshu-cover-image-generator/scripts/generate.sh \
  "供应链物流港口" --style realistic_scene)
COVER_FILE=$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['file'])")

# 2. Use as cover in XHS publisher
# The cover file path can be passed to the xiaohongshu-publisher skill
```

## Environment

- **API Key**: Set `DASHSCOPE_API_KEY` env var, or uses built-in default
- **Dependencies**: `curl`, `python3`, `Pillow` (`pip3 install Pillow`)
- **Runs on**: Mac local (not NAS container)

## Error Handling

On failure, stdout contains:

```json
{ "status": "error", "message": "...", "raw_response": "..." }
```

Common errors:

- `Pillow not installed`: Run `pip3 install Pillow`
- API timeout: Increase `--max-time` in script or retry
- Image too small: API returned invalid data; retry with different prompt
