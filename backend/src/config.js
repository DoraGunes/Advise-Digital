import 'dotenv/config';

function required(name) {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is missing in .env`);
  return value.trim();
}

export const config = {
  port: Number(process.env.PORT || 3001),
  jwtSecret: required('JWT_SECRET'),
  adminUsername: required('ADMIN_USERNAME'),
  adminPassword: required('ADMIN_PASSWORD'),
  metaApiVersion: (process.env.META_API_VERSION || 'v24.0').trim(),
  metaAccessToken: (process.env.META_ACCESS_TOKEN || '').trim(),
  adAccountId: (process.env.META_AD_ACCOUNT_ID || '').replace(/^act_/, '').trim(),
  instagramUserId: (process.env.INSTAGRAM_USER_ID || '').trim(),
  instagramAccessToken: (process.env.INSTAGRAM_ACCESS_TOKEN || '').trim(),
  metaAppId: (process.env.META_APP_ID || '').trim(),
  metaAppSecret: (process.env.META_APP_SECRET || '').trim(),
  metaLoginConfigId: (process.env.META_LOGIN_CONFIG_ID || '').trim(),
  metaRedirectUri: (process.env.META_REDIRECT_URI || '').trim(),
  metaBusinessId: (process.env.META_BUSINESS_ID || '').trim(),
  metaPageId: (process.env.META_PAGE_ID || '').trim(),
  metaInstagramUserId: (process.env.META_INSTAGRAM_ID || '').trim(),
  instagramUsername: (process.env.INSTAGRAM_USERNAME || '').trim(),
  metaOAuthScopes: (process.env.META_OAUTH_SCOPES || 'ads_management,business_management,pages_show_list,pages_read_engagement,instagram_basic,instagram_content_publish').split(',').map(x => x.trim()).filter(Boolean),
  publicBaseUrl: (process.env.PUBLIC_BASE_URL || 'http://localhost:3001').replace(/\/+$/, ''),
  aiModel: (process.env.OPENAI_MODEL || 'gpt-5.6-luna').trim(),
  publishMaxRetries: Math.max(1, Math.min(5, Number(process.env.PUBLISH_MAX_RETRIES || 3))),
  publishRetryMinutes: Math.max(1, Math.min(120, Number(process.env.PUBLISH_RETRY_MINUTES || 10))),
  timezone: process.env.TIMEZONE || 'Europe/Istanbul',
  cronEnabled: String(process.env.CRON_ENABLED ?? 'true').toLowerCase() === 'true',
  cronEveryMinutes: Math.max(1, Number(process.env.CRON_EVERY_MINUTES || 1)),
  databaseUrl: (process.env.DATABASE_URL || '').trim(),
  dbSsl: String(process.env.DB_SSL ?? 'false').toLowerCase() === 'true',
  environment: process.env.NODE_ENV || 'development',
  appVersion: '14.0.0',
  messageActionTypes: (process.env.MESSAGE_ACTION_TYPES ||
    'onsite_conversion.messaging_conversation_started_7d,messaging_conversation_started_7d')
    .split(',')
    .map(x => x.trim())
    .filter(Boolean)
};
