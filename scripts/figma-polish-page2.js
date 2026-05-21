// Polish 2/8 — match page 1 visual system (Sona tokens)
const FRAME_ID = '72:126';
const CONTENT_ID = '72:142';
const BADGE_SRC = '72:66';
const FIELD_SRC = '72:70';
const TITLE_SRC = '72:68';
const SUBTITLE_SRC = '72:69';

const SECTIONS = [
  { title: 'SPEECH & LANGUAGE', items: [
    'Speech sounds', 'Saying longer words', 'Expressing ideas clearly',
    'Understanding what is said to them', 'Following directions/instructions',
  ]},
  { title: 'ATTENTION & LISTENING', items: [
    'Sitting or standing still', 'Staying on task', 'Maintaining focus',
    'Ignoring distractions appropriately', 'Overly sensitive to sounds/noises',
  ]},
  { title: 'SOCIAL SKILLS', items: [
    'Maintaining eye contact', 'Turn taking', 'Sharing',
    'Playing with others appropriately', 'Staying on topic of conversation', 'Reading between the lines',
  ]},
  { title: 'READING & WRITING', items: [
    'Maintaining interest in story books', 'Understanding stories and answering questions',
    'Reading and spelling words', 'Letter/number formation', 'Writing stories',
  ]},
];

const page = figma.root.children.find((p) => p.name === 'MVP Screens');
await figma.setCurrentPageAsync(page);

const phone = await figma.getNodeByIdAsync(FRAME_ID);
const contentWrap = await figma.getNodeByIdAsync(CONTENT_ID);
const oldScroll = contentWrap.findOne((n) => n.name === 'Scroll');
if (oldScroll) oldScroll.remove();

const PHONE_H = 812;
const HEADER_H = 126;
const FOOTER_H = 84;
const SCROLL_H = PHONE_H - HEADER_H - FOOTER_H;

phone.resize(375, PHONE_H);
phone.clipsContent = true;
phone.fills = [{ type: 'SOLID', color: { r: 0.98, g: 0.98, b: 0.969 } }];

const footer = phone.children[phone.children.length - 1];
if (footer && footer.type === 'FRAME') {
  footer.y = PHONE_H - FOOTER_H;
  footer.resize(375, FOOTER_H);
}

contentWrap.resize(375, SCROLL_H);
contentWrap.y = HEADER_H;
contentWrap.overflowDirection = 'VERTICAL';
contentWrap.clipsContent = true;
contentWrap.paddingLeft = 0;
contentWrap.paddingRight = 0;

const scroll = figma.createFrame();
scroll.name = 'Scroll';
scroll.layoutMode = 'VERTICAL';
scroll.primaryAxisSizingMode = 'AUTO';
scroll.counterAxisSizingMode = 'FIXED';
scroll.resize(327, 100);
scroll.itemSpacing = 0;
scroll.fills = [];
scroll.paddingBottom = 32;
contentWrap.appendChild(scroll);
scroll.x = 24;
scroll.layoutSizingHorizontal = 'FILL';

const badgeSrc = await figma.getNodeByIdAsync(BADGE_SRC);
const titleSrc = await figma.getNodeByIdAsync(TITLE_SRC);
const subSrc = await figma.getNodeByIdAsync(SUBTITLE_SRC);
const fieldSrc = await figma.getNodeByIdAsync(FIELD_SRC);

const badge = badgeSrc.clone();
const title = titleSrc.clone();
const subtitle = subSrc.clone();
const mainField = fieldSrc.clone();

await figma.loadFontAsync({ family: 'Inter', style: 'Semi Bold' });
await figma.loadFontAsync({ family: 'Inter', style: 'Bold' });
await figma.loadFontAsync({ family: 'Inter', style: 'Regular' });
await figma.loadFontAsync({ family: 'Inter', style: 'Medium' });

badge.findOne((n) => n.type === 'TEXT').characters = 'REASON FOR REFERRAL';
title.characters = 'Reason for referral';
subtitle.characters = 'Tell us what you are most worried about, then tick every area that applies.';
mainField.name = 'Main concern *';
const mfLabel = mainField.children[0];
mfLabel.characters = 'Main concern *';
const mfBox = mainField.children[1];
mfBox.children[0].characters = 'Describe in your own words';
mainField.resize(327, 118);
mfBox.resize(327, 88);
mfBox.y = 26;

function gap(h) {
  const s = figma.createFrame();
  s.resize(327, h);
  s.fills = [];
  scroll.appendChild(s);
  s.layoutSizingHorizontal = 'FILL';
  return s;
}

function sectionTitle(text) {
  gap(16);
  const t = figma.createText();
  t.fontName = { family: 'Inter', style: 'Semi Bold' };
  t.fontSize = 11;
  t.letterSpacing = { unit: 'PERCENT', value: 4 };
  t.characters = text;
  t.fills = [{ type: 'SOLID', color: { r: 0.118, g: 0.29, b: 0.302 } }];
  t.textAutoResize = 'HEIGHT';
  t.resize(327, t.height);
  scroll.appendChild(t);
  t.layoutSizingHorizontal = 'FILL';
  gap(8);
  return t;
}

function checklistPrompt() {
  const t = figma.createText();
  t.fontName = { family: 'Inter', style: 'Semi Bold' };
  t.fontSize = 13;
  t.characters = 'Is your child having difficulty with (tick all that apply) *';
  t.textAutoResize = 'HEIGHT';
  t.resize(327, t.height);
  t.fills = [{ type: 'SOLID', color: { r: 0.078, g: 0.141, b: 0.2 } }];
  scroll.appendChild(t);
  t.layoutSizingHorizontal = 'FILL';
  gap(10);
  return t;
}

function makeChip(label) {
  const row = figma.createFrame();
  row.name = label;
  row.layoutMode = 'HORIZONTAL';
  row.primaryAxisAlignItems = 'CENTER';
  row.counterAxisAlignItems = 'CENTER';
  row.paddingLeft = 14;
  row.paddingRight = 14;
  row.paddingTop = 12;
  row.paddingBottom = 12;
  row.itemSpacing = 12;
  row.cornerRadius = 10;
  row.strokeWeight = 1;
  row.strokes = [{ type: 'SOLID', color: { r: 0.898, g: 0.906, b: 0.922 } }];
  row.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }];
  row.resize(327, 48);

  const box = figma.createFrame();
  box.resize(20, 20);
  box.cornerRadius = 4;
  box.strokeWeight = 1.5;
  box.strokes = [{ type: 'SOLID', color: { r: 0.804, g: 0.831, b: 0.855 } }];
  box.fills = [];

  const t = figma.createText();
  t.fontName = { family: 'Inter', style: 'Regular' };
  t.fontSize = 14;
  t.characters = label;
  t.textAutoResize = 'HEIGHT';
  t.resize(271, t.height);
  t.fills = [{ type: 'SOLID', color: { r: 0.078, g: 0.141, b: 0.2 } }];
  t.lineHeight = { unit: 'PIXELS', value: 20 };

  row.appendChild(box);
  row.appendChild(t);
  scroll.appendChild(row);
  row.layoutSizingHorizontal = 'FILL';
  const sp = gap(8);
  return row;
}

// Stack content
scroll.appendChild(badge);
badge.layoutSizingHorizontal = 'HUG';
gap(12);
scroll.appendChild(title);
title.layoutSizingHorizontal = 'FILL';
gap(8);
scroll.appendChild(subtitle);
subtitle.layoutSizingHorizontal = 'FILL';
gap(16);
scroll.appendChild(mainField);
mainField.layoutSizingHorizontal = 'FILL';
gap(20);
checklistPrompt();

let chips = 0;
for (const sec of SECTIONS) {
  sectionTitle(sec.title);
  for (const item of sec.items) {
    makeChip(item);
    chips++;
  }
}

return { scrollHeight: scroll.height, chips, scrollId: scroll.id };
