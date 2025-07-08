#!/bin/bash

# Gemini CLI 自定义 AK/SK 认证快速设置脚本

set -e

echo "🚀 Gemini CLI 自定义 AK/SK 认证设置向导"
echo "========================================"

# 检查是否在项目根目录
if [ ! -f "package.json" ]; then
    echo "❌ 请在 Gemini CLI 项目根目录下运行此脚本"
    exit 1
fi

# 创建 .env 文件
if [ ! -f ".env" ]; then
    echo "📋 创建 .env 配置文件..."
    cp .env.example .env
    echo "✅ .env 文件已创建"
else
    echo "ℹ️ .env 文件已存在，将进行更新"
fi

# 获取用户输入
echo ""
echo "📝 请输入您的认证信息："

read -p "🔑 Access Key: " ACCESS_KEY
while [ -z "$ACCESS_KEY" ]; do
    echo "❌ Access Key 不能为空"
    read -p "🔑 Access Key: " ACCESS_KEY
done

read -s -p "🔐 Secret Key: " SECRET_KEY
echo ""
while [ -z "$SECRET_KEY" ]; do
    echo "❌ Secret Key 不能为空"
    read -s -p "🔐 Secret Key: " SECRET_KEY
    echo ""
done

read -p "🌐 AI 服务端点 (例如: https://your-backend-service.com): " ENDPOINT
while [ -z "$ENDPOINT" ]; do
    echo "❌ 端点地址不能为空"
    read -p "🌐 AI 服务端点: " ENDPOINT
done

# 更新 .env 文件
echo ""
echo "📝 更新配置文件..."

# 使用 sed 更新配置
sed -i.bak \
    -e "s|CUSTOM_ACCESS_KEY=.*|CUSTOM_ACCESS_KEY=$ACCESS_KEY|" \
    -e "s|CUSTOM_SECRET_KEY=.*|CUSTOM_SECRET_KEY=$SECRET_KEY|" \
    -e "s|CUSTOM_AI_ENDPOINT=.*|CUSTOM_AI_ENDPOINT=$ENDPOINT|" \
    .env

echo "✅ .env 文件已更新"

# 创建或更新 settings.json
SETTINGS_DIR="$HOME/.gemini"
SETTINGS_FILE="$SETTINGS_DIR/settings.json"

echo "📋 配置认证类型..."

# 创建 .gemini 目录
if [ ! -d "$SETTINGS_DIR" ]; then
    mkdir -p "$SETTINGS_DIR"
    echo "✅ 创建 $SETTINGS_DIR 目录"
fi

# 创建或更新 settings.json
if [ ! -f "$SETTINGS_FILE" ]; then
    # 创建新的 settings.json
    cat > "$SETTINGS_FILE" << EOF
{
  "selectedAuthType": "custom-aksk",
  "customEndpoint": "$ENDPOINT"
}
EOF
    echo "✅ 创建 $SETTINGS_FILE"
else
    # 更新现有的 settings.json
    # 使用 jq 工具更新 JSON（如果可用）
    if command -v jq >/dev/null 2>&1; then
        tmp_file=$(mktemp)
        jq --arg authType "custom-aksk" --arg endpoint "$ENDPOINT" \
           '.selectedAuthType = $authType | .customEndpoint = $endpoint' \
           "$SETTINGS_FILE" > "$tmp_file" && mv "$tmp_file" "$SETTINGS_FILE"
        echo "✅ 更新 $SETTINGS_FILE"
    else
        echo "⚠️ 请手动编辑 $SETTINGS_FILE 文件："
        echo "   设置 \"selectedAuthType\": \"custom-aksk\""
        echo "   设置 \"customEndpoint\": \"$ENDPOINT\""
    fi
fi

echo ""
echo "🎉 配置完成！"
echo "=============="
echo ""
echo "📁 配置文件位置："
echo "   - 环境变量: $(pwd)/.env"
echo "   - 用户设置: $SETTINGS_FILE"
echo ""
echo "🔧 下一步操作："
echo "   1. 验证配置: npm run debug"
echo "   2. 启动 CLI: npm run start"
echo "   3. 测试连接: echo 'Hello' | npm run start"
echo ""
echo "📋 验证配置命令："
echo "   # 检查环境变量"
echo "   cat .env | grep CUSTOM_"
echo ""
echo "   # 检查认证设置"
echo "   cat ~/.gemini/settings.json"
echo ""
echo "⚡ 快速测试："
echo "   DEBUG=1 npm run start"

# 显示警告
echo ""
echo "⚠️ 重要提示："
echo "   - 请确保你的后端服务支持 AKSK 认证格式"
echo "   - 认证头格式: Authorization: AKSK access-key:signature"
echo "   - 请妥善保管你的 Secret Key"
echo "   - .env 文件包含敏感信息，请勿提交到版本控制"

echo ""
echo "🔗 参考文档："
echo "   - 详细配置指南: custom-aksk-auth-guide.md"
echo "   - 端点配置指南: ai-endpoint-configuration-guide.md"

echo ""
echo "✨ 设置完成，祝您使用愉快！"