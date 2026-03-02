#!/bin/bash
# ============================================================
# Deploy OpenClaw Skill to NAS (ZSpace)
#
# 用法:
#   ./deploy-skill-to-nas.sh <skill-name>
#   ./deploy-skill-to-nas.sh daily-supply-news-digest
#   ./deploy-skill-to-nas.sh weekly-report
#
# 流程: 本地打包 → SCP 传输 → 解压到正确路径 → 容器内验证
# ============================================================

set -euo pipefail

SKILL_NAME="${1:?用法: $0 <skill-name>}"
LOCAL_SKILLS_DIR="$HOME/.openclaw/skills"
NAS_SKILLS_DIR="/data_ZR5D8EL4/openclaw/config/skills"
NAS_HOST="13911033691@192.168.3.185"
NAS_PORT="10000"
NAS_PASS="Simon2028"
SSH_SCRIPT="$HOME/.ssh/zspace-ssh"

# Validate
if [ ! -d "$LOCAL_SKILLS_DIR/$SKILL_NAME" ]; then
    echo "Error: Skill not found: $LOCAL_SKILLS_DIR/$SKILL_NAME" >&2
    echo "" >&2
    echo "Available skills:" >&2
    ls -1 "$LOCAL_SKILLS_DIR" | grep -v '^\.' | grep -v '\.sh$' | grep -v '\.md$' >&2
    exit 1
fi

if ! command -v sshpass &> /dev/null; then
    echo "Error: sshpass not found. Install with: brew install hudochenkov/sshpass/sshpass" >&2
    exit 1
fi

echo "============================================"
echo " Deploying: $SKILL_NAME → NAS"
echo "============================================"
echo ""

# Step 1: Pack
echo "[1/4] Packing $SKILL_NAME ..."
tar czf "/tmp/${SKILL_NAME}.tar.gz" -C "$LOCAL_SKILLS_DIR" "$SKILL_NAME"
SIZE=$(ls -lh "/tmp/${SKILL_NAME}.tar.gz" | awk '{print $5}')
echo "      Archive: /tmp/${SKILL_NAME}.tar.gz ($SIZE)"

# Step 2: Transfer
echo "[2/4] Transferring to NAS (${NAS_HOST}:${NAS_PORT}) ..."
sshpass -p "$NAS_PASS" scp -P "$NAS_PORT" -o StrictHostKeyChecking=no \
  "/tmp/${SKILL_NAME}.tar.gz" "${NAS_HOST}:/tmp/"
echo "      Transfer complete"

# Step 3: Extract + cleanup macOS metadata
echo "[3/4] Extracting on NAS ..."
"$SSH_SCRIPT" "tar xzf /tmp/${SKILL_NAME}.tar.gz -C ${NAS_SKILLS_DIR}/ && chmod -R +x ${NAS_SKILLS_DIR}/${SKILL_NAME}/scripts/ 2>/dev/null; find ${NAS_SKILLS_DIR}/${SKILL_NAME} -name '._*' -delete 2>/dev/null; rm -f /tmp/${SKILL_NAME}.tar.gz; echo 'EXTRACT_OK'" 2>&1 | tail -3

# Step 4: Verify inside container
echo "[4/4] Verifying in container ..."
VERIFY=$("$SSH_SCRIPT" "docker exec openclaw-gateway ls /home/node/.openclaw/skills/${SKILL_NAME}/SKILL.md 2>/dev/null && echo 'SKILL_VERIFIED_OK' || echo 'SKILL_NOT_FOUND'" 2>&1)

if echo "$VERIFY" | grep -q "SKILL_VERIFIED_OK"; then
    echo ""
    echo "============================================"
    echo " ✅ $SKILL_NAME deployed successfully!"
    echo ""
    echo " 宿主机: ${NAS_SKILLS_DIR}/${SKILL_NAME}/"
    echo " 容器内: /home/node/.openclaw/skills/${SKILL_NAME}/"
    echo "============================================"
else
    echo ""
    echo "============================================"
    echo " ⚠️  Deploy may have issues — SKILL.md not found in container"
    echo " Check: docker exec openclaw-gateway ls /home/node/.openclaw/skills/${SKILL_NAME}/"
    echo "============================================"
    exit 1
fi
