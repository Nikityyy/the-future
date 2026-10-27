import assert from 'node:assert/strict';
import { createDecipheriv, pbkdf2Sync } from 'node:crypto';
import { test } from 'node:test';
import { buildSnapshot, historyFrom, kindOf, seal, unseal, withPids } from '../tools/snapshot.mjs';

const assets = [
  { id: 'btc', name: 'Bitcoin', symbol: 'BTC', type: 'CRYPTO', group: 'CRYPTOCOIN' },
  { id: 'vwce', name: 'FTSE All-World', symbol: 'VWCE', type: 'ETF', group: 'ETF' },
  { id: 'eur', name: 'Euro', symbol: 'EUR', type: 'FIAT', group: 'FIAT' },
];
const amount = (value) => ({ value });
const portfolio = [
  { asset_id: 'vwce', balance: amount('10'), currency_balance: amount('1200.5'), invested_amount: amount('1000') },
  { asset_id: 'btc', balance: amount('0.01'), currency_balance: amount('900'), invested_amount: amount('500') },
  { asset_id: 'eur', balance: amount('50'), currency_balance: amount('50'), invested_amount: amount('0') },
];
const buy = (asset_id, credited_at, qty, rate, flow = 'INCOMING') => ({
  operation_type: 'TRADE',
  transactions: [{ asset_id, credited_at, flow, asset_amount: amount(qty), trade: { rate } }],
});
const operations = [
  buy('vwce', '2026-08-03T08:00:00Z', '1', '100'),
  buy('vwce', '2026-08-20T08:00:00Z', '1', '100'),
  buy('btc', '2026-08-21T08:00:00Z', '0.001', '60000'),
  buy('btc', '2026-09-02T08:00:00Z', '0.0005', '60000', 'OUTGOING'),
  { operation_type: 'DEPOSIT', transactions: [{ asset_id: 'eur', credited_at: '2026-08-01T00:00:00Z' }] },
];

test('classifies asset types', () => {
  assert.equal(kindOf(assets[0]), 'crypto');
  assert.equal(kindOf(assets[1]), 'fund');
  assert.equal(kindOf(assets[2]), 'cash');
  assert.equal(kindOf(undefined), 'fund');
});

test('builds holdings without cash, largest first', () => {
  const s = buildSnapshot({ portfolio, assets, operations, now: new Date('2026-10-27') });
  assert.deepEqual(s.holdings.map((h) => h.symbol), ['VWCE', 'BTC']);
  assert.equal(s.holdings[0].invested, 1000);
});

test('sums net buys per month and kind', () => {
  const s = buildSnapshot({ portfolio, assets, operations, now: new Date('2026-10-27') });
  assert.deepEqual(s.monthly, [
    { month: '2026-08', crypto: 60, fund: 200, metal: 0 },
    { month: '2026-09', crypto: -30, fund: 0, metal: 0 },
  ]);
});

test('lists every non-cash transaction, oldest first, with its euro value', () => {
  const s = buildSnapshot({ portfolio, assets, operations, now: new Date('2026-10-27') });
  assert.equal(s.trades.length, 4);
  assert.deepEqual(s.trades[0], { date: '2026-08-03T08:00:00Z', symbol: 'VWCE', name: 'FTSE All-World', kind: 'fund', side: 'buy', type: 'TRADE', amount: 1, price: 100, value: 100, fee: null });
  assert.equal(s.trades[3].side, 'sell');
  assert.equal(s.trades[3].value, 30);
});

test('keeps history older than the Bitpanda year from the last sync', () => {
  const p = (iso, v) => ({ time: iso, value: { value: String(v) } });
  const previous = { all: [[Date.parse('2024-01-01') / 1000, 50], [Date.parse('2025-06-01') / 1000, 80]] };
  const h = historyFrom({ YEAR: [p('2025-12-01T00:00:00Z', 100), p('2025-11-01T00:00:00Z', 90)], DAY: [p('2026-10-27T10:00:00Z', 101.234)] }, previous);
  assert.deepEqual(h.year.map(([, v]) => v), [90, 100], 'oldest first');
  assert.deepEqual(h.all.map(([, v]) => v), [50, 80, 90, 100]);
  assert.equal(h.day[0][1], 101.23);
  assert.deepEqual(h.week, []);
  assert.deepEqual(historyFrom({}, undefined).all, []);
});

test('finds the chart id by symbol within the holding kind', () => {
  const c = (symbol, pid) => ({ attributes: { symbol, pid } });
  const currencies = { data: { attributes: { cryptocoins: [c('BTC', 'p-btc')], stocks: [c('BTC', 'p-stock')], etfs: [c('SXR8', 'p-sxr8')] } } };
  const [btc, etf, gone] = withPids(
    [{ symbol: 'BTC', kind: 'crypto' }, { symbol: 'SXR8', kind: 'fund' }, { symbol: 'NOPE', kind: 'fund' }],
    currencies,
  );
  assert.equal(btc.pid, 'p-btc');
  assert.equal(etf.pid, 'p-sxr8');
  assert.equal(gone.pid, undefined);
  assert.deepEqual(withPids([{ symbol: 'BTC', kind: 'crypto' }], undefined), [{ symbol: 'BTC', kind: 'crypto' }]);
});

test('unseal reads what seal wrote', () => {
  assert.deepEqual(unseal(seal({ a: 1 }, 'correct horse battery'), 'correct horse battery'), { a: 1 });
  assert.throws(() => unseal(seal({ a: 1 }, 'correct horse battery'), 'wrong horse battery'));
});

test('seals so that WebCrypto layout decrypts with the passphrase', () => {
  const sealed = seal({ hello: 'world' }, 'correct horse battery');
  const [salt, iv, ct] = ['salt', 'iv', 'ct'].map((k) => Buffer.from(sealed[k], 'base64'));
  const key = pbkdf2Sync('correct horse battery', salt, sealed.iter, 32, 'sha256');
  const d = createDecipheriv('aes-256-gcm', key, iv);
  d.setAuthTag(ct.subarray(ct.length - 16));
  const text = Buffer.concat([d.update(ct.subarray(0, ct.length - 16)), d.final()]).toString();
  assert.deepEqual(JSON.parse(text), { hello: 'world' });
  assert.throws(() => seal({}, 'short'));
});
