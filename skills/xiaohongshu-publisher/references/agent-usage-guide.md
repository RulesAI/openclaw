# Agent 调用指南

本文档说明林紫涵 Agent 如何调用 `xiaohongshu-publisher` 技能。

## 1. 技能发现

Agent 系统提示词中会自动列出可用技能：

```
<available_skills>
  <skill>
    <name>xiaohongshu-publisher</name>
    <description>Publish image-text posts to Xiaohongshu via Playwright browser automation...</description>
    <location>~/.openclaw/skills/xiaohongshu-publisher/SKILL.md</location>
  </skill>
</available_skills>
```

当用户请求涉及"发小红书"、"发布到小红书"、"小红书发帖"、"发笔记"等关键词时，Agent 自动匹配该技能。

## 2. Agent 调用步骤

### Step 1 — 读取 SKILL.md

Agent 用 Read 工具读取技能说明：

```
Read("~/.openclaw/skills/xiaohongshu-publisher/SKILL.md")
```

### Step 2 — 准备发布内容

Agent 需要准备三项内容：

- **封面图**：本地图片路径（JPG/PNG，推荐 1080x1440px 3:4 比例）
- **标题**：建议 20 字以内
- **正文**：HTML 格式，用 `<p>` 段落、`<br>` 换行、emoji 作项目符号

### Step 3 — 调用发布脚本

```bash
# 正文较短时直接传参
node ~/.openclaw/skills/xiaohongshu-publisher/scripts/publish.mjs \
  "/tmp/xhs_cover_20260226.jpg" \
  "2026供应链趋势分析" \
  "<p>今天分享三个关键趋势...</p>" \
  --ai-declare

# 正文较长时写入文件再用 @file 传参
node ~/.openclaw/skills/xiaohongshu-publisher/scripts/publish.mjs \
  "/tmp/xhs_cover_20260226.jpg" \
  "2026供应链趋势分析" \
  @/tmp/xhs_body.html \
  --ai-declare
```

## 3. 参数速查

| 参数            | 必填 | 默认值 | 说明                               |
| --------------- | ---- | ------ | ---------------------------------- |
| `<cover-image>` | 是   | -      | 封面图路径（JPG/PNG）              |
| `<title>`       | 是   | -      | 标题（建议 20 字以内）             |
| `<body-html>`   | 是   | -      | HTML 正文，或 `@文件路径` 读取文件 |
| `--ai-declare`  | 否   | 不勾选 | 勾选 AI 内容声明                   |
| `--headless`    | 否   | false  | 无界面模式（无法首次登录）         |
| `--timeout`     | 否   | 30000  | 操作超时毫秒数                     |

## 4. 与封面生成技能串联

生成封面 + 发布笔记的完整流程：

```bash
# 1. 生成封面图
RESULT=$(bash ~/.openclaw/skills/xiaohongshu-cover-image-generator/scripts/generate.sh \
  "供应链物流港口全景，集装箱码头" --style realistic_scene)
COVER=$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['file'])")

# 2. 发布小红书笔记
node ~/.openclaw/skills/xiaohongshu-publisher/scripts/publish.mjs \
  "$COVER" "2026港口智能化升级" "<p>内容正文...</p>" --ai-declare
```

## 5. 输出判断

### 发布成功

```
SUCCESS: Post published! Redirected to: https://creator.xiaohongshu.com/publish/success...
```

Agent 可提取最终 URL 告知用户。

### 发布失败

```
FAILED: Still on publish page. Errors: ...
```

Agent 应检查错误信息，可能的原因：

- 标题为空
- 封面图未上传成功
- 网络超时

### 需要登录

```
NOT LOGGED IN: Please log in manually in the opened browser window.
```

登录态过期，需要人工在 Chromium 窗口手动登录。Agent 应提示用户操作。

## 6. allowed-tools 权限

SKILL.md frontmatter 声明了允许的工具：

```yaml
allowed-tools: Bash(node:*) Bash(npx:*) Read Write
```

Agent 在执行该技能时只能使用 `node`/`npx` 命令和读写文件，确保安全隔离。

## 7. Session 管理

- **首次运行**：Playwright 自动启动 Chromium，用户手动登录小红书创作者平台
- **后续运行**：登录态自动恢复（cookies/localStorage 保存在 `~/.openclaw/browser/xhs-publisher/user-data`）
- **Session 过期**：脚本自动检测登录重定向，提示用户重新登录
- **与正常 Chrome 隔离**：Playwright 使用独立 Chromium，不影响系统 Chrome

## 8. 技术细节

- **浏览器引擎**：Playwright 管理的 Chromium（非系统 Chrome）
- **持久化目录**：`~/.openclaw/browser/xhs-publisher/user-data`
- **依赖**：Playwright（OpenClaw 内置）
- **运行环境**：仅 Mac 本地（非 NAS 容器）
- **富文本编辑器**：XHS 使用 TipTap/ProseMirror，脚本通过 DOM 操作注入 HTML 内容

## 9. 注意事项

- 标题不要超过 20 个字符，否则可能被截断
- 正文 HTML 保持简单，用 `<p>`、`<br>`、emoji，避免复杂样式
- 封面图推荐 3:4 竖版（1080x1440px），横图会被裁切
- `--ai-declare` 建议在 AI 生成内容时始终开启
- 首次运行或 Session 过期时不要使用 `--headless`，否则无法手动登录
