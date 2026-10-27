// Reads the portfolio from Bitpanda (read-only key) and writes the sealed snapshot.
//   BITPANDA_API_KEY=... SYNC_PASSPHRASE=... node tools/sync.mjs <out-file>
// Without a key it writes nothing and exits 0, so a fresh fork still deploys.
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import { buildSnapshot, historyFrom, seal, TIMEFRAMES, unseal } from './snapshot.mjs';

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
  // An array is sent as a repeated parameter, the way the API describes it.
  for (const [k, v] of Object.entries(params)) {
    if (Array.isArray(v)) v.forEach((x) => url.searchParams.append(k, x));
    else if (v != null) url.searchParams.set(k, v);
  }
  const res = await fetch(url, { headers: { 'x-api-key': key } });
  if (!res.ok) {
    // The answer is an error message, never your data, so it is safe in the log.
    const body = (await res.text()).replace(/\s+/g, ' ').slice(0, 300);
    throw new Error(`${path} answered ${res.status}: ${body}`);
  }
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

try {
  await run();
} catch (e) {
  // ::error:: shows the reason on the run page, not only in the raw log.
  console.log(`::error title=Bitpanda sync failed::${String(e?.message ?? e).replace(/\s+/g, ' ')}`);
  process.exit(1);
}

async function run() {
const portfolio = ((await get('/portfolio')).data ?? []).filter((p) => p.asset_id);
const operations = await pages('/operations');
// Names for everything held and everything ever traded, sold-off assets included.
const ids = [...new Set([...portfolio.map((p) => p.asset_id), ...operations.flatMap((o) => (o.transactions ?? []).map((t) => t.asset_id))].filter(Boolean))];
const assets = [];
let everyAsset;
for (let i = 0; i < ids.length; i += 25) {
  const batch = ids.slice(i, i + 25);
  try {
    assets.push(...((await get('/assets', { id: batch, page_size: 100 })).data ?? []));
  } catch (e) {
    // If the batch is refused, ask for the assets one by one.
    console.log(`Batch of assets refused (${e.message}); asking one at a time.`);
    for (const id of batch) {
      try {
        assets.push(...((await get('/assets', { id: [id] })).data ?? []));
      } catch {
        // Last resort: read the whole asset list once and pick from it.
        everyAsset ??= await pages('/assets');
        assets.push(...everyAsset.filter((a) => a.id === id));
      }
    }
  }
}

// The value over time, as the Bitpanda app charts it. A timeframe that fails stays empty.
const byTimeframe = {};
for (const tf of TIMEFRAMES) {
  try {
    byTimeframe[tf] = (await get('/portfolio-history', { timeframe: tf })).data?.datapoints ?? [];
  } catch (e) {
    console.log(`::warning title=No ${tf} history::${e.message}`);
  }
}
// The deploy put the live snapshot at <out> first: its history reaches back further than a year.
let previous;
try {
  previous = unseal(JSON.parse(await readFile(out, 'utf8')), pass).history;
} catch {
  // First sync, or the passphrase changed: the history starts at Bitpanda's year.
}
const history = historyFrom(byTimeframe, previous);

const snapshot = buildSnapshot({ portfolio, assets, operations, history });
console.log(`Synced ${snapshot.holdings.length} holdings, ${operations.length} operations and ${history.all.length} history points.`);
await mkdir(dirname(out), { recursive: true });
await writeFile(out, JSON.stringify(seal(snapshot, pass)));
}
