# BigQuant 鉴权改造实现总结

## 概述

已成功为 Gemini CLI 项目添加了 BigQuant 认证方式的支持。该改造允许用户使用 BigQuant API 端点进行认证和 API 调用。

### ⚠️ 重要更新 (2025-01-27)

**URL 格式修正**: 根据实际需求，修正了 BigQuant API 的请求 URL 格式，现在正确支持 `/model/{模型名称}/{方法名}` 的路径结构。

**修正前**: `https://bigquant.com/bigapis/codev/v1/gemini/{方法名}`  
**修正后**: `https://bigquant.com/bigapis/codev/v1/gemini/model/{模型名称}/{方法名}`

## 主要改动

### 1. 添加新的认证类型

在 `packages/core/src/core/contentGenerator.ts` 中：

```typescript
export enum AuthType {
  LOGIN_WITH_GOOGLE = 'oauth-personal',
  USE_GEMINI = 'gemini-api-key',
  USE_VERTEX_AI = 'vertex-ai',
  USE_BIGQUANT = 'bigquant-api',  // 新增
}
```

### 2. 认证验证逻辑

在 `packages/cli/src/config/auth.ts` 中添加了 BigQuant 认证验证：

```typescript
if (authMethod === AuthType.USE_BIGQUANT) {
  if (!process.env.CODE_ASSIST_ENDPOINT) {
    return 'CODE_ASSIST_ENDPOINT environment variable not found. Please set it to your BigQuant API endpoint.';
  }
  if (!process.env.GEMINI_API_KEY) {
    return 'GEMINI_API_KEY environment variable not found. It should contain access key and secret key separated by &.';
  }
  const apiKeyParts = process.env.GEMINI_API_KEY.split('&');
  if (apiKeyParts.length !== 2) {
    return 'GEMINI_API_KEY must contain access key and secret key separated by & (format: accessKey&secretKey).';
  }
  return null;
}
```

### 3. BigQuant 服务器实现

在 `packages/core/src/code_assist/codeAssist.ts` 中实现了 `BigQuantServer` 类：

- 继承自 `CodeAssistServer`
- 实现 BigQuant 特定的签名认证算法
- 支持自定义 API 端点

### 4. UI 更新

在 `packages/cli/src/ui/components/AuthDialog.tsx` 中添加了 BigQuant 选项：

```typescript
const items = [
  { label: 'Login with Google', value: AuthType.LOGIN_WITH_GOOGLE },
  { label: 'Gemini API Key (AI Studio)', value: AuthType.USE_GEMINI },
  { label: 'Vertex AI', value: AuthType.USE_VERTEX_AI },
  { label: 'BigQuant API', value: AuthType.USE_BIGQUANT },  // 新增
];
```

## 环境变量配置

使用 BigQuant 认证需要设置以下环境变量：

### 必需的环境变量：

1. **CODE_ASSIST_ENDPOINT**
   ```bash
   CODE_ASSIST_ENDPOINT=https://bigquant.com/bigapis/codev/v1/gemini
   ```

2. **GEMINI_API_KEY**
   ```bash
   GEMINI_API_KEY=gkw6wXBChifl&iEupg9tNJ3zKJtQofF89CGgxwLEW3WZ0Kq7SdfvNCoBDBPHo5KkxE1gNccwQLEIX
   ```
   注意：格式为 `accessKey&secretKey`，通过 `&` 分隔

## API 请求 URL 格式

BigQuant API 请求现在使用正确的 URL 格式：

```
{CODE_ASSIST_ENDPOINT}/model/{模型名称}/{方法名}
```

### 示例 URL：

- 基础端点：`https://bigquant.com/bigapis/codev/v1/gemini`
- 生成内容：`https://bigquant.com/bigapis/codev/v1/gemini/model/gemini-pro/generateContent`
- 流式生成：`https://bigquant.com/bigapis/codev/v1/gemini/model/gemini-pro/generateContentStream`
- 计算Token：`https://bigquant.com/bigapis/codev/v1/gemini/model/gemini-pro/countTokens`
- 嵌入内容：`https://bigquant.com/bigapis/codev/v1/gemini/model/gemini-pro/embedContent`

其中：
- `gemini-pro` 是模型名称（从配置中获取，默认为 `gemini-pro`）
- `generateContent`、`countTokens` 等是 API 方法名

### 可用的API方法：

1. **generateContent** - 生成内容（非流式）
2. **generateContentStream** - 生成内容（流式）
3. **countTokens** - 计算token数量
4. **embedContent** - 生成嵌入向量

## 签名算法实现

BigQuant 认证使用 HMAC-SHA256 签名算法：

### 签名生成步骤：

1. 提取 URL 路径 (pathname)
2. 构造消息：`pathname + requestBody + timestamp`
3. 使用 secretKey 对消息进行 HMAC-SHA256 签名
4. 将签名转换为十六进制字符串

### HTTP 请求头：

```typescript
const headers = {
  'Content-Type': 'application/json',
  'X-BigQuant-Access-Key': accessKey,
  'X-BigQuant-Timestamp': timestamp,
  'X-BigQuant-Signature': signature,
  // ... 其他头部
};
```

## 技术实现细节

### URL 构造逻辑：

```typescript
getMethodUrl(method: string): string {
  const endpoint = process.env.CODE_ASSIST_ENDPOINT || 'https://bigquant.com/bigapis/codev/v1/gemini';
  // 构造正确的 BigQuant URL 格式: endpoint/model/模型名称/方法名
  return `${endpoint}/model/${this.model}/${method}`;
}
```

### 模型传递机制：

```typescript
export async function createCodeAssistContentGenerator(
  httpOptions: HttpOptions,
  authType: AuthType,
  sessionId?: string,
  model?: string, // 新增模型参数
): Promise<ContentGenerator> {
  if (authType === AuthType.USE_BIGQUANT) {
    const modelName = model || 'gemini-pro'; // 默认模型
    return new BigQuantServer(modelName, httpOptions, sessionId);
  }
  // ...
}
```

### 签名算法代码片段：

```typescript
private async generateSimpleSignature(url: string, body: string, secretKey: string, timestamp: string): Promise<string> {
  // 提取路径
  const urlObj = new URL(url);
  const pathname = urlObj.pathname;
  
  // 构造消息
  const message = pathname + (body || '') + timestamp;
  
  // 使用 Web Crypto API 进行 HMAC-SHA256 签名
  const encoder = new TextEncoder();
  const keyData = encoder.encode(secretKey);
  const messageData = encoder.encode(message);
  
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    keyData,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  
  const signature = await crypto.subtle.sign('HMAC', cryptoKey, messageData);
  const hashArray = Array.from(new Uint8Array(signature));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}
```

## 使用方法

### 1. 设置环境变量

创建 `.env` 文件或设置环境变量：

```bash
CODE_ASSIST_ENDPOINT=https://bigquant.com/bigapis/codev/v1/gemini
GEMINI_API_KEY=your_access_key&your_secret_key
```

### 2. 启动 CLI

```bash
npm start
```

### 3. 选择认证方式

在认证对话框中选择 "BigQuant API" 选项。

## 特性支持

### ✅ 已实现的功能：

- [x] BigQuant 认证类型定义
- [x] 环境变量验证
- [x] 签名算法实现
- [x] HTTP 请求认证头部
- [x] UI 认证选项
- [x] 基本的 API 请求处理

### 🔄 需要进一步完善：

- [ ] 流式响应解析优化
- [ ] 错误处理增强
- [ ] 单元测试添加
- [ ] 文档完善

## 兼容性

该实现与现有的认证方式完全兼容：

- Google OAuth2 登录
- Gemini API Key
- Vertex AI
- BigQuant API（新增）

用户可以在不同的认证方式之间切换，配置会自动保存。

## 安全考虑

1. **环境变量保护**: API 密钥通过环境变量传递，不在代码中硬编码
2. **签名验证**: 使用 HMAC-SHA256 确保请求完整性
3. **时间戳防重放**: 每个请求包含时间戳
4. **HTTPS 传输**: 所有 API 调用使用 HTTPS 加密传输

## 故障排除

### 常见问题：

1. **环境变量未设置**
   - 确保 `CODE_ASSIST_ENDPOINT` 和 `GEMINI_API_KEY` 已正确设置

2. **API Key 格式错误**
   - 确保 `GEMINI_API_KEY` 格式为 `accessKey&secretKey`

3. **签名验证失败**
   - 检查 secretKey 是否正确
   - 确认 API 端点 URL 是否正确

## 总结

BigQuant 鉴权改造已成功集成到 Gemini CLI 项目中，为用户提供了新的认证选择。该实现遵循了项目的现有架构模式，确保了代码的一致性和可维护性。

通过这次改造，用户现在可以使用 BigQuant API 端点来访问 Gemini 功能，同时享受与其他认证方式相同的用户体验。