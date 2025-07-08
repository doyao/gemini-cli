/**
 * @license
 * Copyright 2025 Google LLC
 * SPDX-License-Identifier: Apache-2.0
 */

import { AuthType, ContentGenerator } from '../core/contentGenerator.js';
import { getOauthClient } from './oauth2.js';
import { setupUser } from './setup.js';
import { CodeAssistServer, HttpOptions } from './server.js';

// Simple BigQuant implementation that extends CodeAssistServer
class BigQuantServer extends CodeAssistServer {
  private model: string;

  constructor(model: string, httpOptions: HttpOptions = {}, sessionId?: string) {
    // Create a dummy OAuth client for BigQuant
    super(null as any, undefined, httpOptions, sessionId);
    this.model = model;
  }

  async requestPost<T>(method: string, req: object, signal?: AbortSignal): Promise<T> {
    const url = this.getMethodUrl(method);
    return this.makeBigQuantRequest(url, req, signal);
  }

  private async makeBigQuantRequest<T>(url: string, req: object, signal?: AbortSignal): Promise<T> {
    const body = JSON.stringify(req);
    const timestamp = Date.now().toString();
    
    // Get BigQuant credentials from environment
    const apiKey = (globalThis as any).process?.env?.GEMINI_API_KEY || '';
    const [accessKey, secretKey] = apiKey.split('&');
    
    // Generate signature using the BigQuant format
    const signature = await this.generateSimpleSignature(url, body, secretKey, timestamp);
    
    const headers: any = {
      'Content-Type': 'application/json',
      'X-BigQuant-Access-Key': accessKey,
      'X-BigQuant-Timestamp': timestamp,
      'X-BigQuant-Signature': signature,
      ...this.httpOptions.headers,
    };

    const response = await fetch(url, {
      method: 'POST',
      headers,
      body,
      signal,
    });

    if (!response.ok) {
      throw new Error(`BigQuant API request failed: ${response.status} ${response.statusText}`);
    }

    return await response.json();
  }

  private async generateSimpleSignature(url: string, body: string, secretKey: string, timestamp: string): Promise<string> {
    // Simplified BigQuant signature generation
    // Extract pathname from URL
    const urlObj = new URL(url);
    const pathname = urlObj.pathname;
    
    // Create message: pathname + body + timestamp
    const message = pathname + (body || '') + timestamp;
    
    // Use Web Crypto API for HMAC-SHA256
    const encoder = new TextEncoder();
    const keyData = encoder.encode(secretKey);
    const messageData = encoder.encode(message);
    
    try {
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
    } catch (error) {
      // Fallback: simple hash if HMAC is not available
      console.warn('HMAC not available, using simple hash:', error);
      const hashBuffer = await crypto.subtle.digest('SHA-256', messageData);
      const hashArray = Array.from(new Uint8Array(hashBuffer));
      return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
    }
  }

  getMethodUrl(method: string): string {
    const endpoint = (globalThis as any).process?.env?.CODE_ASSIST_ENDPOINT || 'https://bigquant.com/bigapis/codev/v1/gemini';
    // 构造正确的 BigQuant URL 格式: endpoint/model/模型名称/方法名
    return `${endpoint}/model/${this.model}/${method}`;
  }
}

export async function createCodeAssistContentGenerator(
  httpOptions: HttpOptions,
  authType: AuthType,
  sessionId?: string,
  model?: string,
): Promise<ContentGenerator> {
  if (authType === AuthType.LOGIN_WITH_GOOGLE) {
    const authClient = await getOauthClient();
    const projectId = await setupUser(authClient);
    return new CodeAssistServer(authClient, projectId, httpOptions, sessionId);
  }

  if (authType === AuthType.USE_BIGQUANT) {
    const modelName = model || 'gemini-pro'; // 默认模型
    return new BigQuantServer(modelName, httpOptions, sessionId);
  }

  throw new Error(`Unsupported authType: ${authType}`);
}
