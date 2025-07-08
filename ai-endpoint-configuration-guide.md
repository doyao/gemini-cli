# 修改 Gemini CLI 的 AI 请求地址配置指南

## 概述
根据代码分析，Gemini CLI项目支持多种AI服务端点，你可以通过以下几种方式修改AI请求地址，让它走你自己的后端服务。

## 🎯 主要配置方式

### 1. 环境变量方式（推荐）

#### CODE_ASSIST_ENDPOINT（Code Assist API）
这是最简单的方式，适用于Google Code Assist API的端点修改：

```bash
# 设置自定义端点
export CODE_ASSIST_ENDPOINT="https://your-backend-service.com"

# 然后启动CLI
npm run start
```

#### 配置文件位置
```bash
# 在项目根目录创建 .env 文件
echo 'CODE_ASSIST_ENDPOINT=https://your-backend-service.com' >> .env
```

### 2. 修改源代码方式

#### 方法1：修改 Code Assist 端点
文件：`packages/core/src/code_assist/server.ts`

```typescript
// 修改第42行的默认端点
export const CODE_ASSIST_ENDPOINT = 'https://your-backend-service.com';
```

修改位置：
```42:42:packages/core/src/code_assist/server.ts
export const CODE_ASSIST_ENDPOINT = 'https://your-backend-service.com';
```

#### 方法2：修改 Gemini API 端点  
文件：`packages/core/src/core/modelCheck.ts`

```typescript
// 修改第30行的Gemini API端点
const endpoint = `https://your-backend-service.com/v1beta/models/${modelToTest}:generateContent?key=${apiKey}`;
```

### 3. 自定义 GoogleGenAI 配置

在 `packages/core/src/core/contentGenerator.ts` 中修改GoogleGenAI实例化：

```typescript
// 在第123行附近修改
const googleGenAI = new GoogleGenAI({
  apiKey: config.apiKey === '' ? undefined : config.apiKey,
  vertexai: config.vertexai,
  httpOptions,
  // 添加自定义端点配置（如果库支持）
  baseUrl: process.env.CUSTOM_GENAI_ENDPOINT || 'https://your-backend-service.com',
});
```

## 🔧 具体实施步骤

### 步骤1：检查当前配置
```bash
# 查看当前环境变量
echo $CODE_ASSIST_ENDPOINT
echo $GEMINI_API_KEY
```

### 步骤2：设置自定义端点
选择以下任一方式：

#### 方式A：临时设置（仅当前会话）
```bash
export CODE_ASSIST_ENDPOINT="https://your-backend-service.com"
export CUSTOM_GENAI_ENDPOINT="https://your-backend-service.com"
npm run start
```

#### 方式B：永久设置（添加到shell配置）
```bash
# 对于bash用户
echo 'export CODE_ASSIST_ENDPOINT="https://your-backend-service.com"' >> ~/.bashrc
echo 'export CUSTOM_GENAI_ENDPOINT="https://your-backend-service.com"' >> ~/.bashrc
source ~/.bashrc

# 对于zsh用户  
echo 'export CODE_ASSIST_ENDPOINT="https://your-backend-service.com"' >> ~/.zshrc
echo 'export CUSTOM_GENAI_ENDPOINT="https://your-backend-service.com"' >> ~/.zshrc
source ~/.zshrc
```

#### 方式C：项目级设置（.env文件）
```bash
# 在项目根目录创建.env文件
cat > .env << EOF
CODE_ASSIST_ENDPOINT=https://your-backend-service.com
CUSTOM_GENAI_ENDPOINT=https://your-backend-service.com
GEMINI_API_KEY=your-api-key
EOF
```

### 步骤3：修改源代码（如果需要）

如果环境变量不够，可以直接修改源码：

#### 修改1：Code Assist端点
```bash
# 编辑文件
vim packages/core/src/code_assist/server.ts
```

找到第42行，修改为：
```typescript
export const CODE_ASSIST_ENDPOINT = 'https://your-backend-service.com';
```

#### 修改2：Gemini API端点
```bash
# 编辑文件  
vim packages/core/src/core/modelCheck.ts
```

找到第30行，修改为：
```typescript
const endpoint = `https://your-backend-service.com/v1beta/models/${modelToTest}:generateContent?key=${apiKey}`;
```

### 步骤4：重新构建项目
```bash
# 清理并重新构建
npm run clean
npm run build
npm run start
```

## 🚀 高级配置

### 创建自定义配置文件
在项目根目录创建 `config/endpoints.js`：

```javascript
// config/endpoints.js
export const CUSTOM_ENDPOINTS = {
  CODE_ASSIST: process.env.CODE_ASSIST_ENDPOINT || 'https://your-backend-service.com',
  GEMINI_API: process.env.GEMINI_API_ENDPOINT || 'https://your-backend-service.com',
  VERTEX_AI: process.env.VERTEX_AI_ENDPOINT || 'https://your-backend-service.com',
};
```

然后在需要的地方引入这个配置。

### 动态端点配置
修改 `packages/core/src/code_assist/server.ts` 的 `getMethodUrl` 方法：

```typescript
getMethodUrl(method: string): string {
  // 支持多种端点配置方式
  const endpoint = 
    process.env.CODE_ASSIST_ENDPOINT ?? 
    process.env.CUSTOM_AI_ENDPOINT ?? 
    CODE_ASSIST_ENDPOINT;
  
  return `${endpoint}/${CODE_ASSIST_API_VERSION}:${method}`;
}
```

## 🔍 验证配置

### 检查端点是否生效
1. 启动调试模式：
```bash
npm run debug
```

2. 查看网络请求：
在浏览器开发者工具的Network标签页中查看请求是否指向你的端点。

3. 添加日志验证：
在相关文件中添加console.log来验证端点配置：

```typescript
// 在 server.ts 中添加
console.log('Using endpoint:', this.getMethodUrl(method));
```

## 🛠️ 支持的认证方式

项目支持三种认证方式，你的后端服务需要相应支持：

1. **OAuth 个人账号** (`AuthType.LOGIN_WITH_GOOGLE`)
2. **Gemini API Key** (`AuthType.USE_GEMINI`) 
3. **Vertex AI** (`AuthType.USE_VERTEX_AI`)

### 配置认证
```bash
# 根据你的后端服务选择合适的认证方式
export GEMINI_API_KEY="your-custom-api-key"
export GOOGLE_CLOUD_PROJECT="your-project"
export GOOGLE_CLOUD_LOCATION="your-location"
```

## 📝 注意事项

1. **API兼容性**：确保你的后端服务API与Google Gemini API兼容
2. **请求格式**：检查请求和响应格式是否匹配
3. **认证机制**：确保你的服务支持相应的认证方式
4. **CORS设置**：如果是浏览器环境，确保后端服务设置了正确的CORS

## 🔧 故障排查

### 常见问题

1. **端点不生效**
   - 检查环境变量是否正确设置
   - 重启终端或重新加载shell配置
   - 确认构建是否成功

2. **请求失败**
   - 检查网络连接
   - 验证API密钥是否正确
   - 确认后端服务是否正常运行

3. **调试方法**
```bash
# 开启详细日志
DEBUG=1 npm run start

# 查看网络请求
npm run debug
# 然后在浏览器中打开开发者工具查看Network标签页
```

## 总结

推荐的修改方式按优先级排序：

1. **首选**：使用环境变量 `CODE_ASSIST_ENDPOINT`
2. **备选**：修改源代码中的常量定义
3. **高级**：自定义配置系统

通过以上方法，你就可以成功将Gemini CLI的AI请求指向你自己的后端服务了！