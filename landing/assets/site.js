// Words that arrive out of a blur, and the calculator. Same maths as the app (lib/projection.dart).
const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;

// Blur-in on scroll.
for (const el of document.querySelectorAll('[data-blur]')) {
  const label = el.textContent.trim();
  el.setAttribute('aria-label', label);
  el.textContent = '';
  label.split(' ').forEach((word, i) => {
    const s = document.createElement('span');
    s.className = 'w';
    s.setAttribute('aria-hidden', 'true');
    s.style.setProperty('--i', i);
    s.textContent = word;
    el.append(s, ' ');
  });
}
const seen = new IntersectionObserver((entries) => {
  for (const e of entries) if (e.isIntersecting) { e.target.classList.add('in'); seen.unobserve(e.target); }
}, { threshold: 0.25 });
for (const el of document.querySelectorAll('[data-blur], .rise')) reduce ? el.classList.add('in') : seen.observe(el);

// Calculator.
const form = document.getElementById('calc');
if (form) {
  const RETURNS = [3, 6.5, 9]; // cautious, expected, hopeful, per year in percent
  const $ = (id) => document.getElementById(id);
  const eur = (v) => '€' + Math.round(v).toLocaleString('en');
  const short = (v) => (v >= 1e6 ? '€' + (v / 1e6).toFixed(v >= 1e7 ? 0 : 1) + 'M' : v >= 1e3 ? '€' + Math.round(v / 1e3) + 'K' : '€' + Math.round(v));

  function series(start, monthly, months, yearly) {
    const i = Math.pow(1 + yearly / 100, 1 / 12) - 1;
    const out = [start];
    let bal = start;
    for (let m = 1; m <= months; m++) { bal = (bal + monthly) * (1 + i); out.push(bal); }
    return out;
  }

  const niceMax = (v) => {
    const e = Math.pow(10, Math.floor(Math.log10(v || 1)));
    return [1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10].map((m) => m * e).find((x) => x >= v * 1.04) ?? 10 * e;
  };

  let shown = 0;
  let raf = 0;
  function countTo(el, to) {
    cancelAnimationFrame(raf);
    if (reduce) { shown = to; el.textContent = eur(to); return; }
    const from = shown, t0 = performance.now();
    const step = (t) => {
      const k = Math.min(1, (t - t0) / 600), e = 1 - Math.pow(1 - k, 3);
      shown = from + (to - from) * e;
      el.textContent = eur(shown);
      if (k < 1) raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
  }

  function update() {
    const start = Math.max(0, Number($('start').value.replace(/[^\d]/g, '')) || 0);
    const monthly = Number($('monthly').value);
    const years = Number(form.elements.years.value);
    const pick = Number(form.elements.case.value);
    const months = years * 12;
    const all = RETURNS.map((r) => series(start, monthly, months, r));
    const mid = all[pick];
    const end = mid[months];
    const put = monthly * months;

    $('monthlyOut').textContent = eur(monthly);
    $('monthly').style.setProperty('--p', (monthly / Number($('monthly').max)) * 100 + '%');
    countTo($('big'), end);
    $('years').textContent = years;
    $('now').textContent = eur(start);
    $('add').textContent = '+' + eur(put);
    $('grow').textContent = '+' + eur(end - start - put);
    $('addNote').textContent = eur(monthly) + ' a month for ' + years + ' years';

    // Chart: band between cautious and hopeful, the picked case as the line.
    const W = 640, H = 300, L = 44, T = 10, B = 28, R = 12;
    const yMax = niceMax(all[2][months]);
    const x = (m) => L + ((W - L - R) * m) / months;
    const y = (v) => H - B - ((H - T - B) * v) / yMax;
    const stepN = Math.max(1, Math.ceil(months / 120));
    const idx = []; for (let m = 0; m < months; m += stepN) idx.push(m); idx.push(months);
    const pts = (s) => idx.map((m) => x(m).toFixed(1) + ',' + y(s[m]).toFixed(1));
    const band = pts(all[2]).join(' L') + ' L' + pts(all[0]).reverse().join(' L');
    let grid = '';
    for (let g = 0; g <= 4; g++) {
      const v = (yMax * g) / 4;
      grid += '<line x1="' + L + '" x2="' + (W - R) + '" y1="' + y(v) + '" y2="' + y(v) + '" stroke="rgba(22,23,15,.14)" stroke-dasharray="1.5 4" />' +
        '<text x="' + (L - 8) + '" y="' + (y(v) + 4) + '" text-anchor="end">' + short(v) + '</text>';
    }
    const endPt = [x(months), y(mid[months])];
    const year = new Date().getFullYear();
    $('chart').innerHTML = grid +
      '<text x="' + L + '" y="' + (H - 6) + '">Now</text><text x="' + (W - R) + '" y="' + (H - 6) + '" text-anchor="end">' + (year + years) + '</text>' +
      '<path d="M' + band + 'Z" fill="rgba(74,139,90,.12)" />' +
      '<path d="M' + pts(all[0]).join(' L') + '" fill="none" stroke="rgba(74,139,90,.4)" stroke-width="1.2" />' +
      '<path d="M' + pts(all[2]).join(' L') + '" fill="none" stroke="rgba(74,139,90,.4)" stroke-width="1.2" />' +
      '<path d="M' + pts(mid).join(' L') + '" fill="none" stroke="#4a8b5a" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" />' +
      '<circle cx="' + endPt[0] + '" cy="' + endPt[1] + '" r="16" fill="rgba(74,139,90,.22)" /><circle cx="' + endPt[0] + '" cy="' + endPt[1] + '" r="5.5" fill="#4a8b5a" stroke="#f8f5ec" stroke-width="2" />';
    $('chartLabel').textContent = 'In ' + years + ' years: ' + eur(all[0][months]) + ' cautious, ' + eur(all[1][months]) + ' expected, ' + eur(all[2][months]) + ' hopeful.';
  }

  form.addEventListener('input', update);
  form.addEventListener('submit', (e) => e.preventDefault());
  $('start').addEventListener('blur', () => { $('start').value = (Number($('start').value.replace(/[^\d]/g, '')) || 0).toLocaleString('en'); });
  update();
}
