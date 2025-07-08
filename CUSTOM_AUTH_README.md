# Gemini CLI 自定义认证集成说明

## 📋 概述

本文档说明了如何在 Gemini CLI 项目中集成自定义的 AK/SK 认证方式，让AI请求走你们自己的后端服务。

## 🎯 解决方案

### 1. 端点修改（最简单）

如果你只需要修改请求地址，使用环境变量即可：

```bash
# 设置自定义端点
export CODE_ASSIST_ENDPOINT="https://your-backend-service.com"
npm run start
```

**配置文件：**
- 创建 `.env` 文件：`cp .env.example .env`
- 修改 `CODE_ASSIST_ENDPOINT=https://your-backend-service.com`

### 2. 自定义 AK/SK 认证（完整方案）

如果需要完全自定义的认证方式，需要代码修改。

## 🚀 快速开始

### 方法1：自动设置（推荐）

运行自动设置脚本：

```bash
# 使脚本可执行
chmod +x setup-custom-auth.sh

# 运行设置向导
./setup-custom-auth.sh
```

脚本会引导你完成：
- 创建/更新 `.env` 文件
- 配置 AK/SK 认证信息
- 设置认证类型
- 验证配置

### 方法2：手动设置

1. **复制配置文件**：
```bash
cp .env.example .env
```

2. **编辑 .env 文件**：
```bash
# 自定义 AK/SK 认证配置
CUSTOM_ACCESS_KEY=your-access-key
CUSTOM_SECRET_KEY=your-secret-key
CUSTOM_AI_ENDPOINT=https://your-backend-service.com
```

3. **配置认证类型**：
编辑 `~/.gemini/settings.json`：
```json
{
  "selectedAuthType": "custom-aksk"
}
```

4. **重新构建项目**：
```bash
npm run build
npm run start
```

## 📁 文件说明

| 文件 | 描述 |
|------|------|
| `ai-endpoint-configuration-guide.md` | 端点配置详细指南 |
| `custom-aksk-auth-guide.md` | AK/SK 认证集成详细指南 |
| `vscode-console-debug-guide.md` | VS Code 调试配置指南 |
| `.env.example` | 环境变量配置示例 |
| `setup-custom-auth.sh` | 自动设置脚本 |

## 🔧 支持的认证方式

1. **Google OAuth** (`oauth-personal`)
2. **Gemini API Key** (`gemini-api-key`)
3. **Vertex AI** (`vertex-ai`)
4. **自定义 AK/SK** (`custom-aksk`) - 新增

## 🔍 验证配置

### 检查环境变量
```bash
cat .env | grep CUSTOM_
```

### 检查认证设置
```bash
cat ~/.gemini/settings.json
```

### 启动调试模式
```bash
DEBUG=1 npm run start
```

## 📝 后端API要求

你的后端服务需要支持：

### 认证格式
```
Authorization: AKSK access-key:signature
X-Timestamp: 2025-01-08T12:00:00.000Z
```

### 必需端点
- `POST /v1/generate` - 内容生成
- `POST /v1/generate-stream` - 流式生成
- `POST /v1/count-tokens` - Token计数
- `POST /v1/embed` - 嵌入生成

### API 兼容性
响应格式需要与 Google Gemini API 兼容，或在 `customAKSKGenerator.ts` 中实现格式转换。

## 🚨 注意事项

1. **安全性**：
   - 妥善保管 Secret Key
   - 不要将 `.env` 文件提交到版本控制
   - 使用强密码和定期轮换密钥

2. **兼容性**：
   - 确保后端API与Gemini API格式兼容
   - 测试所有功能端点
   - 验证流式响应处理

3. **调试**：
   - 使用 `DEBUG=1` 查看详细日志
   - 检查网络请求和响应
   - 验证认证头格式

## 🛠️ 故障排查

### 常见问题

1. **认证失败**
   - 检查 AK/SK 是否正确
   - 验证签名算法
   - 确认时间戳格式

2. **端点不通**
   - 检查网络连接
   - 验证后端服务状态
   - 确认端点地址正确

3. **格式错误**
   - 检查API请求/响应格式
   - 验证内容转换逻辑
   - 测试流式响应处理

### 调试命令

```bash
# 检查配置
npm run debug

# 查看网络请求
DEBUG=1 npm run start

# 测试连接
echo "Hello" | npm run start
```

## 📞 技术支持

如果遇到问题，请：

1. 查看详细指南文档
2. 检查配置是否正确
3. 验证后端服务是否正常
4. 使用调试模式查看错误信息

## 🎉 完成

通过以上配置，你就可以成功使用自定义的 AK/SK 认证方式了！

**下一步**：
- 测试基本功能
- 验证所有端点
- 部署到生产环境
- 监控性能和错误

祝您使用愉快！ 🚀