import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const OUT = join(dirname(fileURLToPath(import.meta.url)), 'svg');
mkdirSync(OUT, { recursive: true });

/** 线性渐变 */
const lin = (id, stops) =>
  `<linearGradient id="${id}" x1="0" y1="0" x2="1" y2="1">${stops
    .map(([o, c, a = 1]) => `<stop offset="${o}" stop-color="${c}" stop-opacity="${a}"/>`)
    .join('')}</linearGradient>`;

/** 径向高光 */
const spec = (id, cx, cy, r, c, a) =>
  `<radialGradient id="${id}" cx="${cx}" cy="${cy}" r="${r}">` +
  `<stop offset="0" stop-color="${c}" stop-opacity="${a}"/>` +
  `<stop offset="1" stop-color="${c}" stop-opacity="0"/></radialGradient>`;

const dropShadow = (id, dy, blur, op) =>
  `<filter id="${id}" x="-40%" y="-40%" width="180%" height="180%">` +
  `<feDropShadow dx="0" dy="${dy}" stdDeviation="${blur}" flood-color="#0B1F3A" flood-opacity="${op}"/>` +
  `</filter>`;

const svg = (defs, body, size = 1024) =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 1024 1024">` +
  `<defs>${defs}</defs>${body}</svg>`;

const write = (name, content) => {
  writeFileSync(join(OUT, `${name}.svg`), content, 'utf8');
  console.log('wrote', name);
};

const SQUIRCLE =
  `<rect x="64" y="64" width="896" height="896" rx="224" fill="url(#base)"/>`;
const LIT = `<rect x="64" y="64" width="896" height="896" rx="224" fill="url(#topLit)"/>`;

// ── 四款设计 ──────────────────────────────────────────────
// 每款 = { id, base渐变, defs, motif }；base 供传统图标和自适应图标背景层共用
const variants = [];

// V1 三色拼图（蓝底）
{
  const piece = (fill, rot, cx, cy) =>
    `<g transform="translate(${cx} ${cy}) rotate(${rot})">` +
    `<g filter="url(#sh)"><g mask="url(#pieceMask)">` +
    `<rect x="-118" y="-118" width="236" height="236" rx="62" fill="${fill}"/>` +
    `<circle cx="118" cy="0" r="54" fill="${fill}"/>` +
    `</g></g>` +
    `<g mask="url(#pieceMask)" opacity="0.5">` +
    `<rect x="-118" y="-118" width="236" height="236" rx="62" fill="url(#gloss)"/>` +
    `<circle cx="118" cy="0" r="54" fill="url(#gloss)"/>` +
    `</g></g>`;
  variants.push({
    id: 'puzzle',
    fgScale: 0.94,
    baseStops: [[0, '#8FC4F2'], [0.5, '#5B8DEF'], [1, '#3A6EA5']],
    // 自适应图标背景层要铺满整块，不能只画中间的圆角方
    fullBleedStops: [[0, '#7FB6EC'], [0.55, '#4C82D4'], [1, '#2E5C8E']],
    defs:
      lin('p1', [[0, '#FFE08A'], [0.55, '#FFC94D'], [1, '#E8A417']]) +
      lin('p2', [[0, '#A8E6C9'], [0.55, '#6FD3A0'], [1, '#3FAF7C']]) +
      lin('p3', [[0, '#FFB0A8'], [0.55, '#FF8A7A'], [1, '#E85F4E']]) +
      lin('gloss', [[0, '#FFFFFF', 0.6], [0.62, '#FFFFFF', 0.05], [1, '#FFFFFF', 0]]) +
      `<mask id="pieceMask">` +
      `<rect x="-118" y="-118" width="236" height="236" rx="62" fill="#FFFFFF"/>` +
      `<circle cx="118" cy="0" r="54" fill="#FFFFFF"/>` +
      `<circle cx="0" cy="-118" r="54" fill="#000000"/>` +
      `</mask>` +
      dropShadow('sh', 14, 16, 0.32),
    motif:
      piece('url(#p1)', 0, 512, 356) +
      piece('url(#p2)', 120, 648, 590) +
      piece('url(#p3)', 240, 376, 590),
  });
}

// V2 笑脸（琥珀底）
{
  const eye = (cx) =>
    `<ellipse cx="${cx}" cy="470" rx="46" ry="58" fill="#8A4A12" opacity="0.88"/>` +
    `<ellipse cx="${cx - 14}" cy="452" rx="16" ry="20" fill="#FFFFFF" opacity="0.7"/>`;
  variants.push({
    id: 'smile',
    fgScale: 1.0,
    baseStops: [[0, '#FFD97A'], [0.5, '#FB8C00'], [1, '#E65100']],
    fullBleedStops: [[0, '#FFC85C'], [0.55, '#F07C00'], [1, '#D24500']],
    defs:
      lin('face', [[0, '#FFF3D0'], [0.45, '#FFE1A8'], [1, '#FFC96B']]) +
      lin('mouth', [[0, '#E65100'], [1, '#BF360C']]) +
      dropShadow('sh', 16, 18, 0.3),
    motif:
      `<g filter="url(#sh)"><ellipse cx="512" cy="520" rx="268" ry="252" fill="url(#face)"/></g>` +
      eye(392) + eye(632) +
      `<path d="M 366 618 Q 512 738 658 618" stroke="url(#mouth)" stroke-width="52" ` +
      `stroke-linecap="round" fill="none"/>` +
      `<ellipse cx="300" cy="596" rx="46" ry="30" fill="#FF8A65" opacity="0.35"/>` +
      `<ellipse cx="724" cy="596" rx="46" ry="30" fill="#FF8A65" opacity="0.35"/>`,
  });
}

// V3 书本 + 对勾（薄荷绿底）
{
  variants.push({
    id: 'book',
    fgScale: 0.84,
    baseStops: [[0, '#8FE3D0'], [0.5, '#26A69A'], [1, '#00796B']],
    fullBleedStops: [[0, '#7FD8C4'], [0.55, '#1D9488'], [1, '#00695C']],
    defs:
      lin('pageL', [[0, '#FFFFFF'], [1, '#DDEFE9']]) +
      lin('pageR', [[0, '#F2FAF7'], [1, '#CBE6DE']]) +
      lin('cover', [[0, '#00695C'], [1, '#004D40']]) +
      lin('tick', [[0, '#FFD54F'], [1, '#FFA000']]) +
      dropShadow('sh', 16, 18, 0.32),
    motif:
      `<g filter="url(#sh)">` +
      `<path d="M 512 700 C 430 632 300 618 236 636 L 236 430 C 300 412 430 426 512 494 Z" fill="url(#cover)"/>` +
      `<path d="M 512 700 C 594 632 724 618 788 636 L 788 430 C 724 412 594 426 512 494 Z" fill="url(#cover)"/>` +
      `</g>` +
      `<path d="M 500 676 C 424 616 316 604 262 620 L 262 462 C 316 446 424 458 500 518 Z" fill="url(#pageL)"/>` +
      `<path d="M 524 676 C 600 616 708 604 762 620 L 762 462 C 708 446 600 458 524 518 Z" fill="url(#pageR)"/>` +
      `<g filter="url(#sh)"><circle cx="700" cy="360" r="126" fill="url(#tick)"/></g>` +
      `<path d="M 640 362 L 686 408 L 766 316" stroke="#FFFFFF" stroke-width="46" ` +
      `stroke-linecap="round" stroke-linejoin="round" fill="none"/>`,
  });
}

// V4 星火（紫罗兰底）
{
  const star = (cx, cy, r, inner) => {
    const pts = [];
    for (let i = 0; i < 8; i++) {
      const rad = i % 2 === 0 ? r : r * inner;
      const a = (Math.PI / 4) * i - Math.PI / 2;
      pts.push(
        `${(cx + rad * Math.cos(a)).toFixed(1)},${(cy + rad * Math.sin(a)).toFixed(1)}`
      );
    }
    return `<path d="M ${pts.join(' L ')} Z"/>`;
  };
  variants.push({
    id: 'spark',
    fgScale: 0.9,
    baseStops: [[0, '#C9A6F5'], [0.5, '#8E24AA'], [1, '#5B1678']],
    fullBleedStops: [[0, '#B993EC'], [0.55, '#7C1E9A'], [1, '#4A1266']],
    defs:
      lin('star', [[0, '#FFF3B0'], [0.5, '#FFD54F'], [1, '#FFA000']]) +
      lin('star2', [[0, '#FFFFFF'], [1, '#E1BEE7']]) +
      dropShadow('sh', 16, 20, 0.36),
    motif:
      `<g filter="url(#sh)"><g transform="translate(512 512)" fill="url(#star)">${star(0, 0, 268, 0.44)}</g></g>` +
      `<g transform="translate(512 512) scale(0.52)" fill="url(#star2)">${star(0, 0, 268, 0.44)}</g>` +
      `<g transform="translate(766 296) scale(0.24)" fill="url(#star2)">${star(0, 0, 268, 0.45)}</g>` +
      `<g transform="translate(286 726) scale(0.19)" fill="url(#star2)">${star(0, 0, 268, 0.45)}</g>` +
      `<g transform="translate(292 284) scale(0.13)" fill="url(#star2)">${star(0, 0, 268, 0.45)}</g>`,
  });
}

// ── 输出两套 SVG ─────────────────────────────────────────
// 1) 完整合成图：传统 mipmap（Android 8 以下的启动器）直接用这张
// 2) 纯前景图：自适应图标的前景层，背景交给系统裁切
//
// 自适应图标画布 108dp，系统圆形遮罩只留中间 72dp，保证不被切到的安全区更小（66dp）。
// 前景要缩到安全圈里，缩多少取决于这款图形最外沿的元素离中心有多远：
// 笑脸的主体本来就在正中、离边远，几乎不用缩；书本右上角的对勾徽章顶到了画布边角，
// 只能多缩一点，否则换个圆形桌面就被削掉一块。——来自Trae
const fgWrap = (motif, s) =>
  `<g transform="translate(512 512) scale(${s}) translate(-512 -512)">${motif}</g>`;

for (const v of variants) {
  const defs =
    lin('base', v.baseStops) +
    spec('topLit', 0.3, 0.22, 0.72, '#FFFFFF', 0.33) +
    dropShadow('bs', 22, 30, 0.18) +
    v.defs;

  write(
    `v_${v.id}`,
    svg(
      defs,
      `<g filter="url(#bs)">${SQUIRCLE}</g>${LIT}${v.motif}`
    )
  );

  write(`fg_${v.id}`, svg(v.defs, fgWrap(v.motif, v.fgScale)));
}

// 背景层渐变参数交给后续脚本（自适应图标的背景层用 XML shape 直接画，不用位图）
writeFileSync(
  join(OUT, '..', 'icons.json'),
  JSON.stringify(
    variants.map((v) => ({ id: v.id, fullBleedStops: v.fullBleedStops })),
    null,
    2
  )
);