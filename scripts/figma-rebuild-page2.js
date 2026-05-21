// Rebuild 2/8 checklist — all 21 options + 4 section headers (run via use_figma)
const FRAME_ID = '72:126';
const SCROLL_ID = '102:2';
const CONTENT_ID = '72:142';

const SECTIONS = [
  { title: 'SPEECH & LANGUAGE', items: [
    'Speech sounds',
    'Saying longer words',
    'Expressing ideas clearly',
    'Understanding what is said to them',
    'Following directions/instructions',
  ]},
  { title: 'ATTENTION & LISTENING', items: [
    'Sitting or standing still',
    'Staying on task',
    'Maintaining focus',
    'Ignoring distractions appropriately',
    'Overly sensitive to sounds/noises',
  ]},
  { title: 'SOCIAL SKILLS', items: [
    'Maintaining eye contact',
    'Turn taking',
    'Sharing',
    'Playing with others appropriately',
    'Staying on topic of conversation',
    'Reading between the lines',
  ]},
  { title: 'READING & WRITING', items: [
    'Maintaining interest in story books',
    'Understanding stories and answering questions',
    'Reading and spelling words',
    'Letter/number formation',
    'Writing stories',
  ]},
];

const page = figma.root.children.find((p) => p.name === 'MVP Screens');
await figma.setCurrentPageAsync(page);

const phone = await figma.getNodeByIdAsync(FRAME_ID);
const contentWrap = await figma.getNodeByIdAsync(CONTENT_ID);
let scroll = await figma.getNodeByIdAsync(SCROLL_ID);

await figma.loadFontAsync({ family: 'Inter', style: 'Regular' });
await figma.loadFontAsync({ family: 'Inter', style: 'Medium' });
await figma.loadFontAsync({ family: 'Inter', style: 'Semi Bold' });

const PHONE_H = 812;
const FOOTER_H = 84;
const HEADER_H = 126;
const SCROLL_H = PHONE_H - HEADER_H - FOOTER_H;

phone.resize(375, PHONE_H);
phone.clipsContent = true;

// Reposition footer inside frame
const footer = phone.children.find((c) => c.name === 'Frame' && c.y > 800);
if (footer) {
  footer.y = PHONE_H - FOOTER_H;
  footer.resize(375, FOOTER_H);
}

if (contentWrap && 'layoutMode' in contentWrap) {
  contentWrap.resize(375, SCROLL_H);
  contentWrap.y = HEADER_H;
  contentWrap.overflowDirection = 'VERTICAL';
  contentWrap.clipsContent = true;
}

// Rebuild scroll content
if (scroll) scroll.remove();
scroll = figma.createFrame();
scroll.name = 'Scroll';
scroll.layoutMode = 'VERTICAL';
scroll.primaryAxisSizingMode = 'AUTO';
scroll.counterAxisSizingMode = 'FIXED';
scroll.resize(327, 100);
scroll.itemSpacing = 10;
scroll.paddingTop = 0;
scroll.paddingBottom = 24;
scroll.fills = [];
contentWrap.appendChild(scroll);
scroll.layoutSizingHorizontal = 'FILL';
scroll.x = 24;
scroll.y = 0;

const created = [];

function sectionLabel(text) {
  const f = figma.createFrame();
  f.layoutMode = 'HORIZONTAL';
  f.primaryAxisSizingMode = 'AUTO';
  f.counterAxisSizingMode = 'AUTO';
  f.paddingTop = 8;
  f.paddingBottom = 4;
  f.fills = [{ type: 'SOLID', color: { r: 0.93, g: 0.96, b: 0.98 } }];
  f.cornerRadius = 6;
  f.paddingLeft = 10;
  f.paddingRight = 10;
  const t = figma.createText();
  t.fontName = { family: 'Inter', style: 'Semi Bold' };
  t.fontSize = 11;
  t.characters = text;
  t.fills = [{ type: 'SOLID', color: { r: 0.12, g: 0.35, b: 0.48 } }];
  f.appendChild(t);
  scroll.appendChild(f);
  f.layoutSizingHorizontal = 'FILL';
  created.push(f.id);
  return f;
}

function bodyText(text, size, weight) {
  const t = figma.createText();
  t.fontName = { family: 'Inter', style: weight || 'Regular' };
  t.fontSize = size || 14;
  t.characters = text;
  t.textAutoResize = 'HEIGHT';
  t.resize(327, t.height);
  t.fills = [{ type: 'SOLID', color: { r: 0.1, g: 0.1, b: 0.12 } }];
  scroll.appendChild(t);
  t.layoutSizingHorizontal = 'FILL';
  created.push(t.id);
  return t;
}

function chip(label) {
  const row = figma.createFrame();
  row.name = label;
  row.layoutMode = 'HORIZONTAL';
  row.primaryAxisAlignItems = 'CENTER';
  row.counterAxisAlignItems = 'CENTER';
  row.paddingLeft = 14;
  row.paddingRight = 14;
  row.paddingTop = 12;
  row.paddingBottom = 12;
  row.itemSpacing = 10;
  row.cornerRadius = 10;
  row.strokeWeight = 1;
  row.strokes = [{ type: 'SOLID', color: { r: 0.85, g: 0.88, b: 0.9 } }];
  row.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }];
  row.resize(327, 44);
  const box = figma.createFrame();
  box.resize(18, 18);
  box.cornerRadius = 4;
  box.strokes = [{ type: 'SOLID', color: { r: 0.75, g: 0.78, b: 0.82 } }];
  box.strokeWeight = 1;
  box.fills = [];
  const t = figma.createText();
  t.fontName = { family: 'Inter', style: 'Regular' };
  t.fontSize = 14;
  t.characters = label;
  t.textAutoResize = 'HEIGHT';
  t.resize(280, t.height);
  t.fills = [{ type: 'SOLID', color: { r: 0.15, g: 0.17, b: 0.2 } }];
  row.appendChild(box);
  row.appendChild(t);
  scroll.appendChild(row);
  row.layoutSizingHorizontal = 'FILL';
  created.push(row.id);
  return row;
}

function mainConcernField() {
  const f = figma.createFrame();
  f.name = 'Main concern *';
  f.layoutMode = 'VERTICAL';
  f.itemSpacing = 6;
  f.paddingTop = 10;
  f.paddingBottom = 10;
  f.paddingLeft = 12;
  f.paddingRight = 12;
  f.cornerRadius = 10;
  f.strokeWeight = 1;
  f.strokes = [{ type: 'SOLID', color: { r: 0.85, g: 0.88, b: 0.9 } }];
  f.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }];
  f.resize(327, 88);
  const lbl = figma.createText();
  lbl.fontName = { family: 'Inter', style: 'Medium' };
  lbl.fontSize = 12;
  lbl.characters = 'Main concern *';
  lbl.fills = [{ type: 'SOLID', color: { r: 0.35, g: 0.38, b: 0.42 } }];
  const ph = figma.createText();
  ph.fontName = { family: 'Inter', style: 'Regular' };
  ph.fontSize = 14;
  ph.characters = 'Describe in your own words';
  ph.fills = [{ type: 'SOLID', color: { r: 0.6, g: 0.63, b: 0.67 } }];
  f.appendChild(lbl);
  f.appendChild(ph);
  scroll.appendChild(f);
  f.layoutSizingHorizontal = 'FILL';
  created.push(f.id);
}

// Badge row (match other steps)
const badge = figma.createFrame();
badge.layoutMode = 'HORIZONTAL';
badge.primaryAxisSizingMode = 'AUTO';
badge.counterAxisSizingMode = 'AUTO';
badge.paddingLeft = 10;
badge.paddingRight = 10;
badge.paddingTop = 4;
badge.paddingBottom = 4;
badge.cornerRadius = 6;
badge.fills = [{ type: 'SOLID', color: { r: 0.93, g: 0.96, b: 0.98 } }];
const badgeT = figma.createText();
badgeT.fontName = { family: 'Inter', style: 'Semi Bold' };
badgeT.fontSize = 11;
badgeT.characters = 'REASON FOR REFERRAL';
badgeT.fills = [{ type: 'SOLID', color: { r: 0.12, g: 0.35, b: 0.48 } }];
badge.appendChild(badgeT);
scroll.appendChild(badge);
badge.layoutSizingHorizontal = 'HUG';
created.push(badge.id);

bodyText('What is your main concern?', 16, 'Semi Bold');
mainConcernField();
bodyText('Is your child having difficulty with (tick all that apply) *', 14, 'Medium');
bodyText('Scroll for Attention & listening, Social skills, and Reading & writing.', 12, 'Regular');

let chipTotal = 0;
for (const sec of SECTIONS) {
  sectionLabel(sec.title);
  for (const item of sec.items) {
    chip(item);
    chipTotal++;
  }
}

return {
  mutatedNodeIds: [FRAME_ID, CONTENT_ID, scroll.id, ...created],
  chipTotal,
  scrollHeight: scroll.height,
  sections: SECTIONS.map((s) => ({ title: s.title, count: s.items.length })),
};
