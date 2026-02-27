---
name: xiaohongshu-publisher
description: Publish image-text posts (图文笔记) to Xiaohongshu (小红书) via Playwright browser automation. Use when asked to publish, post, or create content on Xiaohongshu/小红书/RedNote. Handles image upload, title/body filling, AI content declaration, and publish verification. Auto-manages Chromium with persistent login session.
allowed-tools: Bash(node:*) Bash(npx:*) Read Write
---

# Xiaohongshu Publisher

Publish image-text posts to Xiaohongshu creator platform via Playwright (auto-managed Chromium).

## Prerequisites

- Playwright installed (bundled with OpenClaw)
- Cover image file (JPG/PNG, recommended 1080x1440px, 3:4 ratio)
- **First run only**: Manually log in to `creator.xiaohongshu.com` in the Chromium window that opens

## Quick Start

```bash
node scripts/publish.mjs <cover-image-path> <title> <body-html | @body-file> [--ai-declare]
```

**Example:**

```bash
node scripts/publish.mjs ./cover.jpg "供应链AI实战分享" "<p>今天分享一个案例...</p>" --ai-declare
```

No need to manually launch Chrome. Playwright auto-manages a dedicated Chromium instance with persistent session.

## Parameters

| Parameter        | Required | Description                                         |
| ---------------- | -------- | --------------------------------------------------- |
| cover-image-path | Yes      | Path to cover image                                 |
| title            | Yes      | Post title (max 20 chars recommended)               |
| body-html        | Yes      | Post body as HTML, or `@path` to read from file     |
| --ai-declare     | No       | Check AI content declaration                        |
| --headless       | No       | Run Chromium without GUI (no manual login possible) |
| --timeout        | No       | Action timeout in ms (default: 30000)               |

## How It Works

1. Launches Chromium with persistent context (`~/.openclaw/browser/xhs-publisher/user-data`)
2. Navigates to `creator.xiaohongshu.com/publish/publish`
3. Detects login state — if not logged in, waits 120s for manual login
4. Clicks "上传图文" tab (page defaults to video upload)
5. Uploads cover image via `setInputFiles()`
6. Fills title via Playwright `fill()`
7. Fills body in TipTap/ProseMirror contenteditable editor
8. Optionally checks AI content declaration
9. Clicks "发布" button and verifies redirect

## Session Management

- **First run**: Chromium opens, you log in manually. Session saved automatically.
- **Subsequent runs**: Session auto-restored. No login needed.
- **Session expired**: Script detects login redirect and waits for manual re-login.
- **User data**: `~/.openclaw/browser/xhs-publisher/user-data` (cookies, localStorage persist here)
- **Normal Chrome unaffected**: Playwright uses its own Chromium, not your system Chrome.

## Important Notes

- **Tab selection**: Publish page defaults to "上传视频". Script auto-clicks "上传图文".
- **Image format**: 3:4 vertical (1080x1440px) performs best. Max 18 images per post.
- **Body formatting**: Use `<br>` for line breaks, emoji for bullets. Keep under 800 chars.
- **Cover generation**: Use the `xiaohongshu-cover-image-generator` skill to generate AI covers.

## Cover Image Generation

For creating covers, chain with the cover image generator skill:

```bash
# Generate cover
RESULT=$(bash ~/.openclaw/skills/xiaohongshu-cover-image-generator/scripts/generate.sh \
  "供应链物流港口" --style realistic_scene)
COVER=$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['file'])")

# Publish
node scripts/publish.mjs "$COVER" "标题" "<p>内容</p>" --ai-declare
```

See `references/cover-design.md` for infographic-style cover design guidelines.

## Troubleshooting

- **"NOT LOGGED IN"**: Log in manually in the Chromium window, then re-run
- **"Published!" but post not visible**: Title was likely empty — verify title input
- **Image upload fails**: Ensure cover image file exists and is valid JPG/PNG
- **AI declaration not found**: Page structure may have changed — check XHS creator platform
- **Timeout errors**: Increase with `--timeout 60000`
