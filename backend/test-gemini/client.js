import fs from 'node:fs';
import path from 'node:path';
import {parse as parseDotenv} from 'dotenv';

export const GEMINI_TEST_TASKS = Object.freeze({
  CONTENT_ANALYSIS: 'CONTENT_ANALYSIS',
  AD_COPY: 'AD_COPY',
  STRATEGY: 'STRATEGY'
});

const taskInstructions = Object.freeze({
  CONTENT_ANALYSIS: 'İçeriği analiz et; güçlü yönleri, riskleri ve iyileştirme önerilerini JSON olarak ver.',
  AD_COPY: 'Yalnız reklam metni taslağı üret; başlık, ana metin ve çağrı metni alanlarını JSON olarak ver.',
  STRATEGY: 'Verilen hedef için reklam stratejisi öner; varsayımları ve riskleri açıkça belirterek JSON olarak ver.'
});

export function readGeminiTestConfig({envPath=path.join(import.meta.dirname, '.env'), env={}}={}) {
  const fileValues = fs.existsSync(envPath) ? parseDotenv(fs.readFileSync(envPath)) : {};
  const values = {...fileValues, ...env};
  return {
    apiKey: String(values.GEMINI_API_KEY || '').trim(),
    model: String(values.GEMINI_MODEL || 'gemini-2.5-flash').trim(),
    apiBase: String(values.GEMINI_API_BASE || 'https://generativelanguage.googleapis.com/v1beta').replace(/\/+$/, ''),
    enabled: String(values.GEMINI_TEST_MODE || 'false').toLowerCase() === 'true'
  };
}

function taskName(task) {
  const value = String(task || '').trim().toUpperCase();
  if (!Object.prototype.hasOwnProperty.call(taskInstructions, value)) {
    throw new Error('Gemini test görevi CONTENT_ANALYSIS, AD_COPY veya STRATEGY olmalı.');
  }
  return value;
}

function promptFor(task, input) {
  return [
    'Bu istek yalnız AdVise test ortamındadır.',
    'Meta API, reklam oluşturma, reklam aktifleştirme, bütçe/harcama ve kuyruk işlemi yapma.',
    'Yalnız verilen girdiyi değerlendir; doğrulanmamış işletme/hukuk bilgisi uydurma.',
    `Görev: ${taskInstructions[task]}`,
    `Girdi:\n${JSON.stringify(input ?? {}, null, 2)}`
  ].join('\n\n');
}

function responseText(data) {
  const text = data?.candidates?.[0]?.content?.parts
    ?.map(part => String(part?.text || ''))
    .join('')
    .trim();
  if (!text) throw new Error('Gemini test yanıtında metin bulunamadı.');
  return text;
}

export async function runGeminiTest(task, input, {envPath, env, transport=fetch}={}) {
  const name = taskName(task);
  const config = readGeminiTestConfig({envPath, env});
  if (!config.enabled) throw new Error('Gemini test modu etkin değil.');
  if (!config.apiKey) throw new Error('GEMINI_API_KEY test .env içinde bulunamadı.');
  const endpoint = `${config.apiBase}/models/${encodeURIComponent(config.model)}:generateContent?key=${encodeURIComponent(config.apiKey)}`;
  const response = await transport(endpoint, {
    method: 'POST',
    headers: {'content-type': 'application/json', accept: 'application/json'},
    body: JSON.stringify({contents: [{role: 'user', parts: [{text: promptFor(name, input)}]}]})
  });
  const data = await response.json();
  if (!response.ok || data?.error) throw new Error(`Gemini test isteği reddedildi (${response.status}).`);
  return {task: name, model: config.model, text: responseText(data)};
}
