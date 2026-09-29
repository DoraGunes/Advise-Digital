import pg from 'pg';
import {config} from './config.js';
const {Pool} = pg;
let pool = null;
export function dbConfigured(){ return Boolean(config.databaseUrl); }
export function getPool(){
  if (!config.databaseUrl) return null;
  if (!pool) pool = new Pool({connectionString:config.databaseUrl, ssl:config.dbSsl ? {rejectUnauthorized:false} : false, max:10});
  return pool;
}
export async function dbHealth(){
  const p=getPool();
  if(!p) return {configured:false,connected:false};
  const r=await p.query('select 1 as ok');
  return {configured:true,connected:r.rows[0]?.ok===1};
}
