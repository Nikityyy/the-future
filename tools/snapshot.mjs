// Turns the raw Bitpanda Public API answers into the snapshot the app shows,
// and seals it with a passphrase. Pure functions, no network: sync.mjs does the
// fetching, tests/snapshot.test.mjs checks the rest.
import { createCipheriv, pbkdf2Sync, randomBytes } from 'node:crypto';

// ponytail: the account is in EUR (Bitpanda Austria); other currencies are not converted.
export const ITERATIONS = 600_000;
const MONTHS = 36;

/** crypto, fund (ETFs, stocks, ETCs), metal, or cash (not an investment). */
export function kindOf(asset) {
  const t = `${asset?.type ?? ''} ${asset?.group ?? ''}`.toUpperCase();
  if (/FIAT|CURRENCY/.test(t)) return 'cash';
  if (/CRYPTO/.test(t)) return 'crypto';
  if (/METAL|COMMODITY/.test(t)) return 'metal';
  return 'fund';
}

const num = (v) => {
  const n = Number.parseFloat(v?.value ?? v);
  return Number.isFinite(n) ? n : 0;
};

export function holdingsFrom(portfolio, assets) {
  const byId = new Map(assets.map((a) => [a.id, a]));
  return portfolio
    .map((p) => {
      const a = byId.get(p.asset_id);
      const kind = kindOf(a);
      return {
        id: p.asset_id,
        name: a?.name ?? 'Unknown asset',
        symbol: a?.symbol ?? '',
        kind,
        amount: num(p.balance),
        value: num(p.currency_balance),
        invested: num(p.invested_amount),
      };
    })
    .filter((h) => h.kind !== 'cash' && (h.value > 0 || h.amount > 0))
    .sort((x, y) => y.value - x.value);
}

/** Net money put in per month and kind: buys count plus, sells minus. */
export function monthlyFrom(operations, assets, now = new Date()) {
  const byId = new Map(assets.map((a) => [a.id, a]));
  const months = new Map();
  for (const op of operations) {
    for (const tx of op.transactions ?? []) {
      if (!tx.trade) continue;
      const kind = kindOf(byId.get(tx.asset_id));
      if (kind === 'cash') continue;
      const price = num(tx.trade.rate_with_fee) || num(tx.trade.rate);
      const eur = num(tx.asset_amount) * price * (tx.flow === 'OUTGOING' ? -1 : 1);
      const month = String(tx.credited_at ?? '').slice(0, 7);
      if (!/^\d{4}-\d{2}$/.test(month)) continue;
      const row = months.get(month) ?? { month, crypto: 0, fund: 0, metal: 0 };
      row[kind] += eur;
      months.set(month, row);
    }
  }
  const floor = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - MONTHS, 1)).toISOString().slice(0, 7);
  return [...months.values()]
    .filter((m) => m.month >= floor)
    .sort((a, b) => a.month.localeCompare(b.month))
    .map((m) => ({ ...m, crypto: round(m.crypto), fund: round(m.fund), metal: round(m.metal) }));
}

const round = (n) => Math.round(n * 100) / 100;

export function buildSnapshot({ portfolio, assets, operations, now = new Date() }) {
  return {
    v: 1,
    generatedAt: now.toISOString(),
    currency: 'EUR',
    holdings: holdingsFrom(portfolio, assets),
    monthly: monthlyFrom(operations, assets, now),
  };
}

/** PBKDF2-SHA256 and AES-256-GCM, laid out the way WebCrypto reads it (tag after the ciphertext). */
export function seal(snapshot, passphrase) {
  if (passphrase.length < 12) throw new Error('SYNC_PASSPHRASE needs at least 12 characters');
  const salt = randomBytes(16);
  const iv = randomBytes(12);
  const key = pbkdf2Sync(passphrase, salt, ITERATIONS, 32, 'sha256');
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const body = Buffer.concat([cipher.update(JSON.stringify(snapshot), 'utf8'), cipher.final(), cipher.getAuthTag()]);
  return { v: 1, iter: ITERATIONS, salt: salt.toString('base64'), iv: iv.toString('base64'), ct: body.toString('base64') };
}
