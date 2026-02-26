# Agent 调用指南

本文档说明林紫涵 Agent 如何调用 `xiaohongshu-cover-image-generator` 技能。

## 1. 技能发现

Agent 系统提示词中会自动列出可用技能：

```
<available_skills>
  <skill>
    <name>xiaohongshu-cover-image-generator</name>
    <description>Generate AI background images for Xiaohongshu post covers...</description>
    <location>~/.openclaw/skills/xiaohongshu-cover-image-generator/SKILL.md</location>
  </skill>
</available_skills>
```

当用户请求涉及"小红书封面"、"生成背景图"等关键词时，Agent 自动匹配该技能。

## 2. Agent 调用步骤

### Step 1 — 读取 SKILL.md

Agent 用 Read 工具读取技能说明：

```
Read("~/.openclaw/skills/xiaohongshu-cover-image-generator/SKILL.md")
```

### Step 2 — 调用生成脚本

Agent 用 Bash 工具执行脚本，根据内容主题选择合适的 prompt 和 style：

```bash
bash ~/.openclaw/skills/xiaohongshu-cover-image-generator/scripts/generate.sh \
  "供应链物流港口全景，集装箱码头" --style realistic_scene --aspect portrait
```

### Step 3 — 解析输出

脚本将 JSON 输出到 stdout，Agent 从中提取文件路径：

```json
{
  "status": "success",
  "file": "/tmp/xhs_cover_20260226_224340.jpg",
  "width": 1080,
  "height": 1440,
  "size_bytes": 536718,
  "provider": "dashscope/wan2.6-t2i",
  "style": "realistic_scene",
  "aspect": "portrait",
  "prompt_used": "Realistic photography scene, ... 供应链物流港口全景，集装箱码头, ..."
}
```

## 3. 参数速查

| 参数       | 必填 | 默认值     | 说明                                         |
| ---------- | ---- | ---------- | -------------------------------------------- |
| `<prompt>` | 是   | -          | 图片描述（中英文均可）                       |
| `--style`  | 否   | `auto`     | 风格预设（见下表）                           |
| `--aspect` | 否   | `portrait` | `portrait`(1080x1440) 或 `square`(1080x1080) |
| `--seed`   | 否   | 随机       | 随机种子，用于复现                           |

### 风格预设

| 风格                | 适用场景                              |
| ------------------- | ------------------------------------- |
| `auto`              | 不加前缀，prompt 本身已足够详细时使用 |
| `cyberpunk`         | 科技、AI、游戏、霓虹风格              |
| `minimalist`        | 生活方式、效率工具、简约设计          |
| `infographic`       | 数据图表、商业分析、教程指南          |
| `realistic_scene`   | 美食、旅行、产品、自然风光            |
| `watercolor`        | 艺术文化、诗词、情感类内容            |
| `gradient_abstract` | 通用背景、公告、语录金句              |
| `tech_futuristic`   | AI/芯片/机器人/科学话题               |
| `nature_zen`        | 养生、冥想、传统文化、茶道            |

## 4. 与 xiaohongshu-publisher 串联

生成封面 + 发布笔记的完整流程：

```bash
# 1. 生成封面图
RESULT=$(bash ~/.openclaw/skills/xiaohongshu-cover-image-generator/scripts/generate.sh \
  "供应链物流港口全景" --style realistic_scene)
COVER=$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['file'])")

# 2. 发布小红书笔记
node ~/.openclaw/skills/xiaohongshu-publisher/scripts/publish.mjs \
  "$COVER" "2026供应链趋势分析" "<p>内容正文...</p>" --ai-declare
```

## 5. allowed-tools 权限

SKILL.md frontmatter 声明了允许的工具：

```yaml
allowed-tools: Bash(curl:*) Bash(python3:*) Bash(bash:*) Read Write
```

Agent 在执行该技能时只能使用上述工具，确保安全隔离。

## 6. 错误处理

脚本失败时 stdout 输出错误 JSON：

```json
{ "status": "error", "message": "...", "raw_response": "..." }
```

Agent 应检查 `status` 字段，失败时可：

- 更换 prompt 重试
- 切换 `--style auto` 减少前缀干扰
- 检查 stderr 日志获取详细错误信息

## 7. 技术细节

- **模型**: DashScope `wan2.6-t2i`（同步调用，约 10-15 秒/张）
- **API Key**: 环境变量 `DASHSCOPE_API_KEY` 或脚本内置默认值
- **依赖**: `curl`、`python3`、`Pillow`（`pip3 install Pillow`）
- **运行环境**: Mac 本地（非 NAS 容器）
- **无人物策略**: 双重保障 — negative_prompt 屏蔽 + 风格前缀引导
