import assert from 'node:assert/strict';
import { createDecipheriv, pbkdf2Sync } from 'node:crypto';
import { test } from 'node:test';
import { buildSnapshot, kindOf, seal } from '../tools/snapshot.mjs';

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
