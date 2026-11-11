// Generates iPhone lock-screen wallpapers (1290x2796) for upper/lower week.
const { chromium } = require('playwright');
const fs = require('fs'); const path = require('path');
const D = JSON.parse(fs.readFileSync(path.join(__dirname, 'data.json'), 'utf8'));
const DAYS = {1:'Понедельник',2:'Вторник',3:'Среда',4:'Четверг',5:'Пятница',6:'Суббота'};

function html(week) { // week: 'в' | 'н'
  const title = week === 'в' ? 'ВЕРХНЯЯ НЕДЕЛЯ' : 'НИЖНЯЯ НЕДЕЛЯ';
  const accent = week === 'в' ? '#ffb15c' : '#7cc4ff';
  let body = '';
  for (const d of [1,2,3,4,5,6]) {
    const ls = D.lessons.filter(l => l.day === d && l.w.includes(week)).sort((a,b)=>a.n-b.n);
    if (!ls.length) continue;
    body += `<div class="day"><div class="dn">${DAYS[d]}</div>`;
    for (const l of ls) {
      const [, short] = D.subjects[l.s];
      const tt = l.t === 'лекция' ? 'Лек' : 'Пр';
      body += `<div class="row"><span class="tm"><b>${l.n}</b> ${D.times[l.n][0]}</span>`+
        `<span class="sb">${short}</span><span class="tp ${tt==='Лек'?'lec':''}">${tt}</span><span class="rm">${l.r}</span></div>`;
    }
    body += `</div>`;
  }
  return `<!doctype html><html><head><meta charset="utf-8"><style>
  *{margin:0;padding:0;box-sizing:border-box}
  html,body{width:430px;height:932px;overflow:hidden}
  body{font-family:Inter,sans-serif;color:#f2f2f5;
    background:radial-gradient(120% 70% at 20% 0%, #2a3350 0%, #12141c 55%, #0b0c10 100%);}
  .wrap{position:absolute;top:345px;left:18px;right:18px}
  .hd{display:flex;justify-content:space-between;align-items:baseline;margin-bottom:8px}
  .hd .w{font-weight:800;font-size:13px;letter-spacing:.14em;color:${accent}}
  .hd .g{font-size:11px;color:#9aa0b0}
  .card{background:rgba(255,255,255,.07);border:1px solid rgba(255,255,255,.09);border-radius:18px;padding:6px 12px 8px}
  .day{padding:5px 0 4px;border-bottom:1px solid rgba(255,255,255,.07)}
  .day:last-child{border-bottom:none}
  .dn{font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:${accent};margin-bottom:2px}
  .row{display:flex;align-items:center;gap:7px;height:22px;font-size:13px}
  .tm{width:54px;color:#b8bccb;font-variant-numeric:tabular-nums;font-size:12px}
  .tm b{color:#fff;margin-right:2px}
  .sb{flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;font-weight:500}
  .tp{font-size:10px;font-weight:600;padding:2px 5px;border-radius:6px;background:rgba(255,255,255,.1);color:#cfd3de}
  .tp.lec{background:${accent}33;color:${accent}}
  .rm{width:52px;text-align:right;font-weight:800;font-variant-numeric:tabular-nums}
  .ft{margin-top:8px;font-size:10.5px;color:#8a90a0;text-align:center}
  </style></head><body><div class="wrap">
  <div class="hd"><span class="w">${title}</span><span class="g">пары: 8:30 · 10:15 · 12:00 · 14:35</span></div>
  <div class="card">${body}</div>
  <div class="ft">Пятница — выходной${week==='н'?' · Суббота — выходной':''}</div>
  </div></body></html>`;
}

(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 430, height: 932 }, deviceScaleFactor: 3 });
  for (const [w, name] of [['в','wallpaper_upper_week.png'],['н','wallpaper_lower_week.png']]) {
    await p.setContent(html(w)); await p.evaluate(() => document.fonts.ready);
    await p.screenshot({ path: path.join(__dirname, name) });
  }
  await b.close();
})();
