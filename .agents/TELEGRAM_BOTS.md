# Telegram Bot 配置归档

> 本文档记录所有 Telegram Bot 的完整配置信息，防止 token 丢失。
> 最后更新：2026-03-03

## Bot 清单

| #   | 角色名                       | Bot Username           | 通道名称         | 对应 Agent       | 部署端    | 状态      |
| --- | ---------------------------- | ---------------------- | ---------------- | ---------------- | --------- | --------- |
| 1   | 诸葛亮-首席用户增长总监      | `@SCIAI_Marketing_bot` | `default`        | `sciai-marketer` | NAS       | ✅ 运行中 |
| 2   | 林紫涵-供应链AI自媒体主理人  | `@linzihan_bot`        | `linzihan`       | `whatsapp-agent` | Mac       | ✅ 运行中 |
| 3   | 米亚·凌                      | `@Mia_Ling_bot`        | `mia`            | `virtual-lover`  | NAS       | ✅ 运行中 |
| 4   | Agent Dev                    | `@RL_Agent_Dev_bot`    | `moviedev`       | `movie-dev`      | NAS       | ✅ 运行中 |
| 5   | 链语者-智链进化论-主理人     | `@EvoChain_LinX_bot`   | `wechat-editor`  | `wechat-editor`  | NAS + Mac | ✅ 运行中 |
| 6   | 阿维-首席运维总监            | `@ServerOps_AW_bot`    | `serverops`      | `ops-agent`      | NAS       | ✅ 运行中 |
| 7   | 小暖-首席客户运营官          | `@UserOps_bot`         | `sciai-user-ops` | `sciai-user-ops` | NAS       | ✅ 运行中 |
| 8   | 赵子龙Draco-首席内容运营总监 | `@Simon_Main_bot`      | `simon-main`     | `main`           | NAS       | ✅ 运行中 |

## Bot Token

从 Telegram @BotFather `/mybots` → 选择 bot → `API Token` 获取。

### 1. @SCIAI_Marketing_bot (诸葛亮-首席用户增长总监)

- **通道**: `default` → Agent: `sciai-marketer`
- **Token**: `8510199988:AAFyPqDpdpgpcOQOiTpqz73bIS2BOJ-TUHU`
- **allowFrom**: —
- **部署**: NAS

### 2. @linzihan_bot (林紫涵-供应链AI 自媒体主理人)

- **通道**: `linzihan` → Agent: `whatsapp-agent`
- **Token**: `8541902904:AAGPyAiGxmYO22vTA9yNpZjoLgLq9DhkC8s`
- **allowFrom**: `8529197605`
- **部署**: Mac（NAS 已禁用）

### 3. @Mia_Ling_bot (米亚·凌)

- **通道**: `mia` → Agent: `virtual-lover`
- **Token**: `8486751560:AAEwDfu76iXch3p-MROkSqXg-0w7CrkVpQE`
- **allowFrom**: `8529197605`
- **部署**: NAS

### 4. @RL_Agent_Dev_bot (Agent Dev)

- **通道**: `moviedev` → Agent: `movie-dev`
- **Token**: `8356205469:AAHdMmb7PDc3TJDj-pU8BEULxYdaBUTmtfc`
- **allowFrom**: `8529197605`
- **部署**: NAS

### 5. @EvoChain_LinX_bot (链语者-智链进化论-主理人)

- **通道**: `wechat-editor` → Agent: `wechat-editor`
- **Token**: `8656295393:AAHKnzjnc29D_pWC7fPCqrMJ-_g2uXuxE9c`
- **allowFrom**: `8529197605`
- **部署**: NAS + Mac

### 6. @ServerOps_AW_bot (阿维-首席运维总监)

- **通道**: `serverops` → Agent: `ops-agent`
- **Token**: `8661021439:AAFP5qgey1rEA4M_MFPfUHQP8CqhnkuSBWA`
- **allowFrom**: `8529197605`
- **部署**: NAS

### 7. @UserOps_bot (小暖-首席客户运营官)

- **通道**: `sciai-user-ops` → Agent: `sciai-user-ops`
- **Token**: `8728504340:AAHK4KWMhhFuWEhcc3TdOiZVHzqzN31oags`
- **allowFrom**: `8529197605`
- **部署**: NAS

### 8. @Simon_Main_bot (赵子龙Draco-首席内容运营总监)

- **通道**: `simon-main` → Agent: `main`
- **Token**: `8501043853:AAHVXpDcYRpFcBwqPs0slJ-mJHNFwIXJwcc`
- **allowFrom**: `8529197605`
- **部署**: NAS
- **历史 offset**: `update-offset-simon-main.json`
