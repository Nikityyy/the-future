// Reads the portfolio from Bitpanda (read-only key) and writes the sealed snapshot.
//   BITPANDA_API_KEY=... SYNC_PASSPHRASE=... node tools/sync.mjs <out-file>
// Without a key it writes nothing and exits 0, so a fresh fork still deploys.
import { mkdir, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import { buildSnapshot, seal } from './snapshot.mjs';

const BASE = 'https://api.public.bitpanda.com/v1';
const [out] = process.argv.slice(2);
const key = process.env.BITPANDA_API_KEY;
const pass = process.env.SYNC_PASSPHRASE;

if (!key || !pass) {
  console.log('No BITPANDA_API_KEY or SYNC_PASSPHRASE set: skipping the sync.');
  process.exit(0);
}

async function get(path, params = {}) {
  const url = new URL(BASE + path);
  for (const [k, v] of Object.entries(params)) if (v != null) url.searchParams.set(k, v);
  const res = await fetch(url, { headers: { 'x-api-key': key } });
  if (!res.ok) throw new Error(`${path} answered ${res.status}`);
  return res.json();
}

async function pages(path, params) {
  const all = [];
  let cursor;
  for (let i = 0; i < 200; i++) {
    const page = await get(path, { ...params, page_size: 100, cursor });
    all.push(...(page.data ?? []));
    if (!page.has_next_page || !page.next_cursor || page.next_cursor === cursor) break;
    cursor = page.next_cursor;
  }
  return all;
}

const portfolio = (await get('/portfolio')).data ?? [];
const ids = [...new Set(portfolio.map((p) => p.asset_id))];
const assets = [];
for (let i = 0; i < ids.length; i += 25) assets.push(...(await get('/assets', { id: ids.slice(i, i + 25).join(',') })).data);
const operations = await pages('/operations');

const snapshot = buildSnapshot({ portfolio, assets, operations });
console.log(`Synced ${snapshot.holdings.length} holdings and ${operations.length} operations.`);
await mkdir(dirname(out), { recursive: true });
await writeFile(out, JSON.stringify(seal(snapshot, pass)));
