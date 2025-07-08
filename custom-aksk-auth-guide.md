# 自定义 AK/SK 认证方式集成指南

## 概述
本指南将帮你在 Gemini CLI 项目中添加自定义的 AK/SK (Access Key/Secret Key) 认证方式，替代默认的 Google 认证。

## 🎯 实现步骤

### 步骤1：扩展 AuthType 枚举

修改 `packages/core/src/core/contentGenerator.ts`:

```typescript
export enum AuthType {
  LOGIN_WITH_GOOGLE = 'oauth-personal',
  USE_GEMINI = 'gemini-api-key',
  USE_VERTEX_AI = 'vertex-ai',
  USE_CUSTOM_AKSK = 'custom-aksk', // 新增自定义认证类型
}

export type ContentGeneratorConfig = {
  model: string;
  apiKey?: string;
  vertexai?: boolean;
  authType?: AuthType | undefined;
  // 新增 AK/SK 配置
  accessKey?: string;
  secretKey?: string;
  customEndpoint?: string;
};
```

### 步骤2：修改配置生成函数

在同一文件中修改 `createContentGeneratorConfig` 函数：

```typescript
export async function createContentGeneratorConfig(
  model: string | undefined,
  authType: AuthType | undefined,
  config?: { getModel?: () => string },
): Promise<ContentGeneratorConfig> {
  const geminiApiKey = process.env.GEMINI_API_KEY;
  const googleApiKey = process.env.GOOGLE_API_KEY;
  const googleCloudProject = process.env.GOOGLE_CLOUD_PROJECT;
  const googleCloudLocation = process.env.GOOGLE_CLOUD_LOCATION;
  
  // 新增 AK/SK 环境变量
  const customAccessKey = process.env.CUSTOM_ACCESS_KEY;
  const customSecretKey = process.env.CUSTOM_SECRET_KEY;
  const customEndpoint = process.env.CUSTOM_AI_ENDPOINT;

  const effectiveModel = config?.getModel?.() || model || DEFAULT_GEMINI_MODEL;

  const contentGeneratorConfig: ContentGeneratorConfig = {
    model: effectiveModel,
    authType,
  };

  // 现有认证逻辑...
  if (authType === AuthType.LOGIN_WITH_GOOGLE) {
    return contentGeneratorConfig;
  }

  if (authType === AuthType.USE_GEMINI && geminiApiKey) {
    contentGeneratorConfig.apiKey = geminiApiKey;
    contentGeneratorConfig.model = await getEffectiveModel(
      contentGeneratorConfig.apiKey,
      contentGeneratorConfig.model,
    );
    return contentGeneratorConfig;
  }

  if (
    authType === AuthType.USE_VERTEX_AI &&
    !!googleApiKey &&
    googleCloudProject &&
    googleCloudLocation
  ) {
    contentGeneratorConfig.apiKey = googleApiKey;
    contentGeneratorConfig.vertexai = true;
    contentGeneratorConfig.model = await getEffectiveModel(
      contentGeneratorConfig.apiKey,
      contentGeneratorConfig.model,
    );
    return contentGeneratorConfig;
  }

  // 新增自定义 AK/SK 认证逻辑
  if (authType === AuthType.USE_CUSTOM_AKSK && customAccessKey && customSecretKey) {
    contentGeneratorConfig.accessKey = customAccessKey;
    contentGeneratorConfig.secretKey = customSecretKey;
    contentGeneratorConfig.customEndpoint = customEndpoint;
    return contentGeneratorConfig;
  }

  return contentGeneratorConfig;
}
```

### 步骤3：修改内容生成器创建函数

在同一文件中修改 `createContentGenerator` 函数：

```typescript
export async function createContentGenerator(
  config: ContentGeneratorConfig,
  sessionId?: string,
): Promise<ContentGenerator> {
  const version = process.env.CLI_VERSION || process.version;
  const httpOptions = {
    headers: {
      'User-Agent': `GeminiCLI/${version} (${process.platform}; ${process.arch})`,
    },
  };

  if (config.authType === AuthType.LOGIN_WITH_GOOGLE) {
    return createCodeAssistContentGenerator(
      httpOptions,
      config.authType,
      sessionId,
    );
  }

  if (
    config.authType === AuthType.USE_GEMINI ||
    config.authType === AuthType.USE_VERTEX_AI
  ) {
    const googleGenAI = new GoogleGenAI({
      apiKey: config.apiKey === '' ? undefined : config.apiKey,
      vertexai: config.vertexai,
      httpOptions,
    });
    return googleGenAI.models;
  }

  // 新增自定义 AK/SK 认证处理
  if (config.authType === AuthType.USE_CUSTOM_AKSK) {
    return createCustomAKSKContentGenerator(config, httpOptions, sessionId);
  }

  throw new Error(
    `Error creating contentGenerator: Unsupported authType: ${config.authType}`,
  );
}
```

### 步骤4：创建自定义 AK/SK 内容生成器

创建新文件 `packages/core/src/core/customAKSKGenerator.ts`:

```typescript
/**
 * @license
 * Copyright 2025 Google LLC
 * SPDX-License-Identifier: Apache-2.0
 */

import {
  CountTokensResponse,
  GenerateContentResponse,
  GenerateContentParameters,
  CountTokensParameters,
  EmbedContentResponse,
  EmbedContentParameters,
} from '@google/genai';
import { ContentGenerator, ContentGeneratorConfig } from './contentGenerator.js';
import { HttpOptions } from '../code_assist/server.js';
import crypto from 'node:crypto';

/**
 * 自定义 AK/SK 认证的内容生成器
 */
export class CustomAKSKContentGenerator implements ContentGenerator {
  private accessKey: string;
  private secretKey: string;
  private endpoint: string;
  private httpOptions: HttpOptions;

  constructor(
    config: ContentGeneratorConfig,
    httpOptions: HttpOptions,
    sessionId?: string,
  ) {
    this.accessKey = config.accessKey!;
    this.secretKey = config.secretKey!;
    this.endpoint = config.customEndpoint || 'https://your-default-endpoint.com';
    this.httpOptions = httpOptions;
  }

  /**
   * 生成认证签名
   */
  private generateSignature(method: string, path: string, timestamp: string, body?: string): string {
    // 实现你的签名算法，例如 HMAC-SHA256
    const stringToSign = `${method}\n${path}\n${timestamp}\n${body || ''}`;
    return crypto
      .createHmac('sha256', this.secretKey)
      .update(stringToSign)
      .digest('hex');
  }

  /**
   * 生成认证头
   */
  private getAuthHeaders(method: string, path: string, body?: string): Record<string, string> {
    const timestamp = new Date().toISOString();
    const signature = this.generateSignature(method, path, timestamp, body);
    
    return {
      'Authorization': `AKSK ${this.accessKey}:${signature}`,
      'X-Timestamp': timestamp,
      'Content-Type': 'application/json',
      ...this.httpOptions.headers,
    };
  }

  /**
   * 通用请求方法
   */
  private async makeRequest<T>(
    endpoint: string,
    method: string,
    body?: object,
    signal?: AbortSignal,
  ): Promise<T> {
    const url = new URL(endpoint, this.endpoint);
    const requestBody = body ? JSON.stringify(body) : undefined;
    const headers = this.getAuthHeaders(method, url.pathname, requestBody);

    const response = await fetch(url.toString(), {
      method,
      headers,
      body: requestBody,
      signal,
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    return response.json() as T;
  }

  async generateContent(
    request: GenerateContentParameters,
  ): Promise<GenerateContentResponse> {
    // 将 Google Gemini API 格式转换为你的后端 API 格式
    const customRequest = this.convertToCustomFormat(request);
    
    const response = await this.makeRequest<any>(
      '/v1/generate',
      'POST',
      customRequest,
      request.config?.abortSignal,
    );

    // 将后端响应转换回 Google Gemini API 格式
    return this.convertFromCustomFormat(response);
  }

  async generateContentStream(
    request: GenerateContentParameters,
  ): Promise<AsyncGenerator<GenerateContentResponse>> {
    // 实现流式响应
    const customRequest = this.convertToCustomFormat(request);
    
    const response = await fetch(`${this.endpoint}/v1/generate-stream`, {
      method: 'POST',
      headers: this.getAuthHeaders('POST', '/v1/generate-stream', JSON.stringify(customRequest)),
      body: JSON.stringify(customRequest),
      signal: request.config?.abortSignal,
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    return this.parseStreamingResponse(response);
  }

  async countTokens(request: CountTokensParameters): Promise<CountTokensResponse> {
    const customRequest = this.convertTokenCountRequest(request);
    
    const response = await this.makeRequest<any>(
      '/v1/count-tokens',
      'POST',
      customRequest,
    );

    return this.convertTokenCountResponse(response);
  }

  async embedContent(request: EmbedContentParameters): Promise<EmbedContentResponse> {
    const customRequest = this.convertEmbedRequest(request);
    
    const response = await this.makeRequest<any>(
      '/v1/embed',
      'POST',
      customRequest,
    );

    return this.convertEmbedResponse(response);
  }

  /**
   * 格式转换方法 - 根据你的后端API格式进行调整
   */
  private convertToCustomFormat(request: GenerateContentParameters): any {
    return {
      model: request.model,
      messages: request.contents,
      config: request.config,
      // 根据你的API格式进行转换
    };
  }

  private convertFromCustomFormat(response: any): GenerateContentResponse {
    // 将你的后端响应转换为 Gemini API 格式
    return {
      candidates: response.candidates || [],
      promptFeedback: response.promptFeedback,
      usageMetadata: response.usageMetadata,
    } as GenerateContentResponse;
  }

  private convertTokenCountRequest(request: CountTokensParameters): any {
    return {
      model: request.model,
      contents: request.contents,
    };
  }

  private convertTokenCountResponse(response: any): CountTokensResponse {
    return {
      totalTokens: response.totalTokens || 0,
    };
  }

  private convertEmbedRequest(request: EmbedContentParameters): any {
    return {
      model: request.model,
      contents: request.contents,
    };
  }

  private convertEmbedResponse(response: any): EmbedContentResponse {
    return {
      embeddings: response.embeddings || [],
    };
  }

  private async *parseStreamingResponse(
    response: Response,
  ): AsyncGenerator<GenerateContentResponse> {
    const reader = response.body?.getReader();
    if (!reader) {
      throw new Error('No response body');
    }

    const decoder = new TextDecoder();
    
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        const chunk = decoder.decode(value);
        const lines = chunk.split('\n');

        for (const line of lines) {
          if (line.startsWith('data: ')) {
            try {
              const data = JSON.parse(line.slice(6));
              yield this.convertFromCustomFormat(data);
            } catch (e) {
              // 忽略解析错误
            }
          }
        }
      }
    } finally {
      reader.releaseLock();
    }
  }
}

/**
 * 创建自定义 AK/SK 内容生成器的工厂函数
 */
export function createCustomAKSKContentGenerator(
  config: ContentGeneratorConfig,
  httpOptions: HttpOptions,
  sessionId?: string,
): ContentGenerator {
  return new CustomAKSKContentGenerator(config, httpOptions, sessionId);
}
```

### 步骤5：修改 contentGenerator.ts 导入

在 `packages/core/src/core/contentGenerator.ts` 文件开头添加导入：

```typescript
import { createCustomAKSKContentGenerator } from './customAKSKGenerator.js';
```

### 步骤6：更新认证验证

修改 `packages/cli/src/config/auth.ts`:

```typescript
import { AuthType } from '@google/gemini-cli-core';

export function validateAuth(authMethod: AuthType): string | undefined {
  if (authMethod === AuthType.LOGIN_WITH_GOOGLE) {
    return undefined; // Google auth is handled by OAuth flow
  }

  if (authMethod === AuthType.USE_GEMINI) {
    if (!process.env.GEMINI_API_KEY) {
      return 'GEMINI_API_KEY environment variable not found. Add that to your .env and try again, no reload needed!';
    }
    return undefined;
  }

  if (authMethod === AuthType.USE_VERTEX_AI) {
    const hasVertexProjectLocationConfig =
      !!process.env.GOOGLE_CLOUD_PROJECT && !!process.env.GOOGLE_CLOUD_LOCATION;
    const hasGoogleApiKey = !!process.env.GOOGLE_API_KEY;
    if (!hasVertexProjectLocationConfig && !hasGoogleApiKey) {
      return (
        'Must specify GOOGLE_GENAI_USE_VERTEXAI=true and either:\n' +
        '  - GOOGLE_CLOUD_PROJECT and GOOGLE_CLOUD_LOCATION environment variables, or\n' +
        '  - GOOGLE_API_KEY environment variable.\n' +
        'Update your .env and try again, no reload needed!'
      );
    }
    return undefined;
  }

  // 新增自定义 AK/SK 验证
  if (authMethod === AuthType.USE_CUSTOM_AKSK) {
    if (!process.env.CUSTOM_ACCESS_KEY || !process.env.CUSTOM_SECRET_KEY) {
      return (
        'CUSTOM_ACCESS_KEY and CUSTOM_SECRET_KEY environment variables are required for custom AK/SK authentication.\n' +
        'Update your .env and try again, no reload needed!'
      );
    }
    return undefined;
  }

  return `Unknown authentication method: ${authMethod}`;
}
```

### 步骤7：更新环境变量配置

修改 `.env.example` 文件：

```bash
# =====================================
# 自定义 AK/SK 认证配置
# =====================================

# 自定义认证的 Access Key
CUSTOM_ACCESS_KEY=your-access-key

# 自定义认证的 Secret Key  
CUSTOM_SECRET_KEY=your-secret-key

# 自定义 AI 服务端点
CUSTOM_AI_ENDPOINT=https://your-backend-service.com

# =====================================
# 选择认证方式
# =====================================

# 设置使用自定义 AK/SK 认证（在 settings.json 中配置）
# "selectedAuthType": "custom-aksk"
```

### 步骤8：更新设置配置

在用户的 `~/.gemini/settings.json` 中添加：

```json
{
  "selectedAuthType": "custom-aksk",
  "customEndpoint": "https://your-backend-service.com"
}
```

### 步骤9：更新错误处理

修改 `packages/cli/src/ui/utils/errorParsing.ts`:

```typescript
function getRateLimitMessage(authType?: AuthType): string {
  switch (authType) {
    case AuthType.LOGIN_WITH_GOOGLE:
      return RATE_LIMIT_ERROR_MESSAGE_OAUTH;
    case AuthType.USE_GEMINI:
      return RATE_LIMIT_ERROR_MESSAGE_GEMINI;
    case AuthType.USE_VERTEX_AI:
      return RATE_LIMIT_ERROR_MESSAGE_VERTEX;
    case AuthType.USE_CUSTOM_AKSK:
      return '\nPlease check your custom service rate limits and try again later.';
    default:
      return RATE_LIMIT_ERROR_MESSAGE_OAUTH;
  }
}
```

## 🔧 使用方法

### 1. 设置环境变量

```bash
# 复制配置文件
cp .env.example .env

# 编辑 .env 文件
cat >> .env << EOF
CUSTOM_ACCESS_KEY=your-access-key
CUSTOM_SECRET_KEY=your-secret-key
CUSTOM_AI_ENDPOINT=https://your-backend-service.com
EOF
```

### 2. 配置认证类型

编辑 `~/.gemini/settings.json`:

```json
{
  "selectedAuthType": "custom-aksk"
}
```

### 3. 重新构建和启动

```bash
# 重新构建项目
npm run build

# 启动 CLI
npm run start
```

## 🔍 验证配置

1. 启动调试模式：
```bash
DEBUG=1 npm run start
```

2. 检查认证头：
在 `customAKSKGenerator.ts` 中添加日志：
```typescript
private getAuthHeaders(method: string, path: string, body?: string): Record<string, string> {
  const timestamp = new Date().toISOString();
  const signature = this.generateSignature(method, path, timestamp, body);
  
  const headers = {
    'Authorization': `AKSK ${this.accessKey}:${signature}`,
    'X-Timestamp': timestamp,
    'Content-Type': 'application/json',
    ...this.httpOptions.headers,
  };

  console.log('Auth headers:', headers); // 调试用
  return headers;
}
```

## 📝 后端API要求

你的后端服务需要：

1. **认证格式**：支持 `Authorization: AKSK access-key:signature` 格式
2. **API兼容性**：提供与 Gemini API 兼容的端点
3. **必需端点**：
   - `POST /v1/generate` - 内容生成
   - `POST /v1/generate-stream` - 流式生成
   - `POST /v1/count-tokens` - Token计数
   - `POST /v1/embed` - 嵌入生成

## 🚀 高级定制

### 自定义签名算法

根据你的后端要求修改 `generateSignature` 方法：

```typescript
private generateSignature(method: string, path: string, timestamp: string, body?: string): string {
  // 示例：AWS Signature V4 风格
  const canonicalRequest = `${method}\n${path}\n\n${timestamp}\n${body || ''}`;
  return crypto
    .createHmac('sha256', this.secretKey)
    .update(canonicalRequest)
    .digest('hex');
}
```

### 自定义请求格式

根据你的API格式修改转换方法：

```typescript
private convertToCustomFormat(request: GenerateContentParameters): any {
  return {
    // 根据你的API格式进行转换
    prompt: request.contents[0]?.parts[0]?.text,
    model: request.model,
    temperature: request.config?.temperature,
    max_tokens: request.config?.maxOutputTokens,
  };
}
```

通过以上步骤，你就可以成功集成自定义的 AK/SK 认证方式了！