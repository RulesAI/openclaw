# 技能跨平台部署方案

## 问题背景

同一技能在 Mac 和 NAS 上部署时存在配置差异：

| 差异项    | Mac                        | NAS 容器                       |
| --------- | -------------------------- | ------------------------------ |
| 技能路径  | `~/.openclaw/skills/`      | `/home/node/.openclaw/skills/` |
| 可用工具  | `jq`、Pillow、macOS 字体   | 无 `jq`、有 ImageMagick        |
| Bash 版本 | 3.2（不支持 `declare -A`） | 5+（支持关联数组）             |
| 网络      | 直连                       | Clash 代理                     |
| API Key   | 可能不同                   | 可能不同                       |

---

## 方案一：脚本内自适应（推荐大部分场景）

脚本用 `$HOME` 和平台检测自动适配，不需要外部配置。

### 路径自适应

```bash
# 用 $HOME 而非硬编码绝对路径
SKILL_DIR="$HOME/.openclaw/skills/xiaohongshu-cover-image-generator"

# 或用脚本自身位置推导
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
```

### 平台检测

```bash
if [[ "$(uname)" == "Darwin" ]]; then
    # Mac: jq available, bash 3.2, macOS fonts
    JSON_TOOL="jq"
    FONT_DIR="/System/Library/Fonts"
else
    # Linux/NAS: use python3 for JSON, no macOS fonts
    JSON_TOOL="python3"
    FONT_DIR="/usr/share/fonts"
fi
```

### 工具可用性检测

```bash
if command -v jq &>/dev/null; then
    RESULT=$(echo "$JSON" | jq -r '.key')
else
    RESULT=$(echo "$JSON" | python3 -c "import json,sys; print(json.load(sys.stdin)['key'])")
fi
```

**优点**：零配置，脚本自带适配逻辑
**适用**：路径差异、工具可用性差异、bash 兼容性

---

## 方案二：`openclaw.json` 技能级环境变量（OpenClaw 原生支持）

OpenClaw 已内置技能级配置机制。在各平台的 `~/.openclaw/openclaw.json` 中为每个技能注入不同的环境变量。

### 配置格式

```json
{
  "skills": {
    "entries": {
      "supply-news-publisher": {
        "enabled": true,
        "apiKey": "IeV6jDeworkGtupzlCh6Uk5SvZnqWxYe",
        "env": {
          "PEXELS_KEY": "qAeoLXS6YGAqDHk...",
          "NEWS_API_BASE": "https://news.yrules.com"
        }
      },
      "xiaohongshu-cover-image-generator": {
        "enabled": true,
        "env": {
          "DASHSCOPE_API_KEY": "sk-d0134e6de24c4e04..."
        }
      },
      "manlin-media": {
        "enabled": true,
        "env": {
          "XAI_API_KEY": "xai-xxx..."
        }
      }
    }
  }
}
```

### 脚本读取方式

```bash
# 环境变量优先，硬编码兜底
API_KEY="${DASHSCOPE_API_KEY:-sk-d0134e6de24c4e04ae9a54524d1d5c39}"
```

### 运行机制

- OpenClaw 加载技能时自动注入 `env` 中声明的环境变量
- 如果声明了 `primaryEnv` 且设置了 `apiKey`，会自动将 apiKey 注入为该环境变量
- 环境变量仅在技能执行期间生效，执行完毕后清理
- `process.env` 已有的变量不会被覆盖（系统环境优先）

**优点**：API Key 不硬编码在脚本里，各平台独立配置
**适用**：API Key、URL 端点、平台特有参数

---

## 方案三：SKILL.md `os` 元数据（平台限制）

某些技能只在特定平台有意义，可在 SKILL.md frontmatter 中声明平台限制。

### 配置格式

```yaml
---
name: xiaohongshu-cover-image-generator
metadata:
  openclaw:
    os: ["darwin"]
    requires:
      bins: ["python3", "curl"]
---
```

```yaml
---
name: supply-news-publisher
metadata:
  openclaw:
    os: ["darwin", "linux"]
    requires:
      bins: ["curl"]
---
```

### 支持的元数据字段

| 字段               | 说明                                                    |
| ------------------ | ------------------------------------------------------- |
| `os`               | 平台限制：`darwin`(Mac)、`linux`(NAS)、`win32`(Windows) |
| `requires.bins`    | 必需的二进制工具，全部存在才加载                        |
| `requires.anyBins` | 至少一个存在即可                                        |
| `requires.env`     | 必需的环境变量                                          |
| `requires.config`  | 必需的配置路径                                          |
| `primaryEnv`       | 主要环境变量名（配合 `apiKey` 使用）                    |
| `always`           | 强制加载（忽略 requires 检查）                          |

**优点**：不符合条件的技能自动不加载，避免运行时报错
**适用**：平台限定技能、依赖特定工具的技能

---

## 现有技能改造建议

| 技能                                  | 当前状态                | 建议改造                                    |
| ------------------------------------- | ----------------------- | ------------------------------------------- |
| **clawra-selfie**                     | 硬编码路径              | 方案一：`$HOME` + `$(dirname "$0")`         |
| **manlin-media**                      | xAI API Key 在 SKILL.md | 方案二：迁移到 `openclaw.json` 的 `env`     |
| **sci-report-analyst**                | 缺少 YAML frontmatter   | 补全 frontmatter + 方案三：声明 `requires`  |
| **supply-news-publisher**             | API Key 硬编码在脚本    | 方案二：迁移到 `openclaw.json` 的 `env`     |
| **xiaohongshu-cover-image-generator** | DashScope Key 硬编码    | 方案二：已支持 `DASHSCOPE_API_KEY` 环境变量 |
| **xiaohongshu-publisher**             | Chrome CDP 端口硬编码   | 方案二：`env` 注入 `CDP_PORT`               |

### 改造优先级

1. **高优先**：API Key 从脚本迁移到 `openclaw.json`（安全性）
2. **中优先**：硬编码路径改为 `$HOME` / `$(dirname "$0")`（可移植性）
3. **低优先**：补全 `os` 和 `requires` 元数据（体验优化）

### 改造原则

- 每次只改一个技能，改完测试通过再改下一个
- 保持向后兼容：环境变量不存在时 fallback 到硬编码默认值
- Mac 和 NAS 各自维护 `openclaw.json`，技能代码保持平台无关
- Bash 脚本统一用 3.2 兼容写法（已执行：`case` 替代 `declare -A`）

---

## 相关源码参考

| 文件                                 | 说明                      |
| ------------------------------------ | ------------------------- |
| `src/agents/skills/types.ts`         | 技能元数据类型定义        |
| `src/agents/skills/config.ts`        | 配置加载与技能可用性判断  |
| `src/agents/skills/env-overrides.ts` | 环境变量注入与清理        |
| `src/agents/skills/frontmatter.ts`   | SKILL.md 解析与元数据提取 |
| `src/agents/skills/workspace.ts`     | 技能发现、加载与优先级    |
| `src/config/types.skills.ts`         | 技能配置 TypeScript 类型  |
| `src/shared/config-eval.ts`          | 平台检测与运行时需求评估  |
