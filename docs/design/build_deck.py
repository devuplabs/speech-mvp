#!/usr/bin/env python3
# 16:9 deck mirroring the 3 Figma board slides (1920x1080 authored in px)
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR, MSO_AUTO_SIZE
from pptx.enum.shapes import MSO_SHAPE, MSO_CONNECTOR
from PIL import Image, ImageDraw, ImageFont

W,H=1920,1080
T=dict(bg="FAFAF7",surf="FFFFFF",teal="2D6A6E",dteal="1E4A4D",apri="F2A878",ink="142433",
        sec="4A5B6B",mut="8597A4",bord="E5E7EB",hero="E6F0F0",ltteal="A9C7C7",warm="FBF7F1",painink="7A3B2E")
PS=["2D6A6E","356985","C0703F","6E5A86","4C8060"]
PT=["DCE9E8","DCE7EE","F6E5D7","E8E2F0","DCEBE0"]

slides=[]
def NS():
    s=[("rect",0,0,W,H,T["bg"],None,0)]; slides.append(s); return s
def R(s,x,y,w,h,fill,rad=0,stroke=None): s.append(("rect",x,y,w,h,fill,stroke,rad))
def L(s,x1,y1,x2,y2,col,wpx): s.append(("line",x1,y1,x2,y2,col,wpx))
def O(s,x,y,w,h,fill,stroke): s.append(("oval",x,y,w,h,fill,stroke))
def TX(s,x,y,w,h,runs,anchor='t',align='l',autofit=False):
    if isinstance(runs,str): runs=[(runs,16,False,T["ink"],0)]
    s.append(("text",x,y,w,h,runs,anchor,align,autofit))
def CELL(s,x,y,w,h,fill,txt,size,color,bold=False,align='c',rad=12,stroke=None,pad=12):
    R(s,x,y,w,h,fill,rad,stroke); TX(s,x+pad,y,w-2*pad,h,[(txt,size,bold,color,0)],'m',align,True)

# ---------- SLIDE 1 ----------
s=NS()
TX(s,90,74,900,26,[("OVERVIEW",15,True,T["mut"],0)])
TX(s,90,100,1760,70,[("Sona — Care Journey & Product Overview",46,True,T["teal"],0)])
TX(s,90,180,1560,80,[("An AI co-pilot that reduces admin burnout in UK private Speech & Language Therapy (SLT) — giving clinicians more productive time for care across a client's first 30 days.",20,False,T["sec"],0)])
R(s,92,272,140,5,T["apri"],2)
TX(s,90,320,820,28,[("WHAT IS SONA?",16,True,T["teal"],0)])
TX(s,90,360,810,440,[
  ("Sona is an AI co-pilot for UK private Speech & Language Therapy (SLT) practices.",18,False,T["ink"],0),
  ("It does the repetitive admin alongside the clinician — capturing the enquiry, running a smart intake, prepping the consult, recording the triage decision, and drafting the first session plan and family summary, always as drafts for the clinician to review.",18,False,T["ink"],10),
  ("Sona augments clinicians. Its purpose is to increase human productivity — less admin burnout, more time for care.",18,False,T["ink"],10)])
R(s,958,322,2,470,T["bord"],0)
TX(s,1006,320,800,28,[("HOW TO READ THIS BOARD",16,True,T["teal"],0)])
TX(s,1006,360,800,440,[
  ("•  Two views follow — the Executive view (the journey and the value) and the Product view (the proposed solution, phase by phase).",18,False,T["ink"],0),
  ("•  Read each view left → right: the client's journey across the first ~30 days of a new case.",18,False,T["ink"],10),
  ("•  Who's who —  client / parent / carer: the family or adult client;  clinician / SLT: the therapist;  practice: the private clinic.",18,False,T["ink"],10)])
R(s,90,892,1740,128,T["dteal"],16)
TX(s,122,916,600,24,[("ANCHOR PRINCIPLES",14,True,T["ltteal"],0)])
pr=["(1)   AI drafts, clinician decides","(2)   No screen time for children","(3)   UK data residency + audit by construction","(4)   Augment people, never replace them"]
for p,x in zip(pr,[122,556,990,1410]): TX(s,x,958,420,28,[(p,15,False,"FFFFFF",0)])
TX(s,90,1040,900,22,[("Sona — Care Journey & Product Overview",12,False,T["mut"],0)])
TX(s,1640,1040,190,22,[("1 / 3",12,False,T["mut"],0)],'t','r')

# ---------- SLIDE 2 ----------
s=NS()
TX(s,90,74,900,26,[("EXECUTIVE VIEW",15,True,T["mut"],0)])
TX(s,90,100,1600,60,[("The care journey at a glance",40,True,T["teal"],0)])
TX(s,90,168,1620,50,[("How a new SLT case feels today, and where Sona reduces admin burnout and adds value — across five phases.",19,False,T["sec"],0)])
R(s,92,224,140,5,T["apri"],2)
CL,CR=90,1830; gap=22; cw=(CR-CL-4*gap)/5; step=cw+gap
xs=[CL+i*step for i in range(5)]; cx=[x+cw/2 for x in xs]
ph=["1 · Find & enquire","2 · Understand","3 · Meet & decide","4 · Plan & share","5 · Progress together"]
for i in range(5): CELL(s,xs[i],262,cw,66,PS[i],ph[i],18,"FFFFFF",True,'c',12)
TX(s,90,360,900,24,[("SENTIMENT · FAMILY + CLINICIAN",14,True,T["mut"],0)])
moods=[("Anxious",0.18),("Overwhelmed",0.06),("Hopeful",0.5),("Reassured",0.78),("Confident",0.96)]
pys=[406+(1-m[1])*120 for m in moods]
for i in range(4): L(s,cx[i],pys[i],cx[i+1],pys[i+1],T["teal"],3)
for i,(m,_) in enumerate(moods):
    O(s,cx[i]-8,pys[i]-8,16,16,T["teal"],T["bg"])
    TX(s,xs[i],548,cw,26,[(m,16,True,T["teal"],0)],'m','c')
TX(s,90,604,900,24,[("TODAY'S PAIN — BY PHASE",14,True,T["mut"],0)])
pains=["Enquiries slip through the cracks","Chasing forms — everything is manual","Prep is rushed; the free consult under-delivers","Plans hand-built; reports take ~3 weeks","Carryover is ad-hoc (email / WhatsApp)"]
for i in range(5): CELL(s,xs[i],636,cw,118,T["warm"],pains[i],16,T["painink"],False,'c',12,T["bord"],14)
TX(s,90,798,900,24,[("THE PRIZE — TARGETS",14,True,T["mut"],0)])
R(s,92,832,90,5,T["apri"],2); TX(s,90,846,820,56,[("≥ 4 hours / month",42,True,T["teal"],0)]); TX(s,90,912,820,30,[("productive hours given back to each clinician",18,False,T["sec"],0)])
R(s,1002,832,90,5,T["apri"],2); TX(s,1000,846,820,56,[("Same-day",42,True,T["teal"],0)]); TX(s,1000,912,820,30,[("client summaries & reports, vs the ~3-week manual baseline",18,False,T["sec"],0)])
TX(s,90,1040,900,22,[("Sona — Care Journey & Product Overview",12,False,T["mut"],0)])
TX(s,1640,1040,190,22,[("2 / 3",12,False,T["mut"],0)],'t','r')

# ---------- SLIDE 3 ----------
s=NS()
TX(s,90,74,900,26,[("PRODUCT VIEW",15,True,T["mut"],0)])
TX(s,90,100,1600,60,[("The proposed solution",40,True,T["teal"],0)])
TX(s,90,168,1660,50,[("The client's first 30 days as nine stages grouped into five phases — for each stage: what Sona does, and the surface that delivers it.",19,False,T["sec"],0)])
R(s,92,224,140,5,T["apri"],2)
lab=148; gx=CL+lab+12; ncol=9; cgap=10; cwd=(CR-gx-(ncol-1)*cgap)/ncol; st2=cwd+cgap
colx=[gx+i*st2 for i in range(ncol)]; sp=[0,1,1,2,2,2,3,3,4]
stg=["1 · Referral","2 · Smart intake","3 · Intake review","4 · Consult prep","5 · Consultation","6 · Triage","7 · Session plan","8 · Family summary","9 · Carryover"]
wh=["Capture every enquiry — one case record + audit trail.","Adaptive magic-link intake + live status + consent.","One-screen client overview / summary.","AI prep brief — probes, red flags, references.","Schedule the consult + calendar / video links.","Capture triage outcome + rationale.","AI-drafted, clinician-edited session plan.","Tone / reading-level client summary via portal.","Resources, progress portal & report loop."]
sf=["Clinician web — enquiry queue","Family / client portal","Clinician web","Clinician web + AI","Clinician web + calendar / video","Clinician web — triage","Clinician web + AI","Client app / portal + AI","Client app + clinician web"]
plab=["Find & enquire","Understand","Meet & decide","Plan & share","Progress together"]
spans={0:(0,0),1:(1,2),2:(3,5),3:(6,7),4:(8,8)}
yP,hP,yS,hS,yW,hW,yU,hU=288,50,346,60,414,180,602,120
TX(s,90,yP,lab,hP,[("Phase",14,True,T["sec"],0)],'m','l')
TX(s,90,yS,lab,hS,[("Stage",14,True,T["sec"],0)],'m','l')
TX(s,90,yW,lab,hW,[("What Sona does",14,True,T["sec"],0)],'m','l')
TX(s,90,yU,lab,hU,[("Surface / owner",14,True,T["sec"],0)],'m','l')
for k,(a,b) in spans.items():
    x0=colx[a]; x1=colx[b]+cwd; CELL(s,x0,yP,x1-x0,hP,PS[k],plab[k],14,"FFFFFF",True,'c',10)
for i in range(ncol):
    p=sp[i]; x=colx[i]
    CELL(s,x,yS,cwd,hS,PS[p],stg[i],12,"FFFFFF",True,'c',10,None,6)
    CELL(s,x,yW,cwd,hW,PT[p],wh[i],13,T["ink"],False,'c',10,None,12)
    CELL(s,x,yU,cwd,hU,PT[p],sf[i],12.5,T["ink"],False,'c',10,None,12)
TX(s,90,772,900,24,[("WHERE SONA WINS",14,True,T["mut"],0)])
opp=["Own the first 30 days as one reviewed loop","Trust is the moat — clinician signs every AI draft","Start paediatric, then generalise","UK data residency + clinical audit"]
ow=(CR-CL-3*20)/4; ostep=ow+20
for i,o in enumerate(opp): CELL(s,CL+i*ostep,806,ow,82,T["hero"],o,15,T["teal"],True,'c',12,None,16)
TX(s,90,1006,1740,22,[("Colour groups the nine stages into their five phases.   ·   Generalized across SLTs (Pediatric & Adult).",12.5,False,T["mut"],0)])
TX(s,90,1040,900,22,[("Sona — Care Journey & Product Overview",12,False,T["mut"],0)])
TX(s,1640,1040,190,22,[("3 / 3",12,False,T["mut"],0)],'t','r')

# ===== render PPTX =====
def C(h): return RGBColor.from_string(h)
def IN(px): return Inches(px/144.0)
def PTf(px): return Pt(px/2.0)
AL={'l':PP_ALIGN.LEFT,'c':PP_ALIGN.CENTER,'r':PP_ALIGN.RIGHT}; AN={'t':MSO_ANCHOR.TOP,'m':MSO_ANCHOR.MIDDLE}
prs=Presentation(); prs.slide_width=IN(W); prs.slide_height=IN(H); BL=prs.slide_layouts[6]
for ops in slides:
    sl=prs.slides.add_slide(BL)
    for op in ops:
        k=op[0]
        if k=="rect":
            _,x,y,w,h,fill,stroke,rad=op
            shp=sl.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE if rad else MSO_SHAPE.RECTANGLE,IN(x),IN(y),IN(w),IN(h))
            if fill is None: shp.fill.background()
            else: shp.fill.solid(); shp.fill.fore_color.rgb=C(fill)
            if stroke is None: shp.line.fill.background()
            else: shp.line.color.rgb=C(stroke); shp.line.width=Pt(1)
            shp.shadow.inherit=False
            if rad:
                try: shp.adjustments[0]=max(0,min(0.5,(rad/144.0)/(min(w,h)/144.0)))
                except Exception: pass
        elif k=="oval":
            _,x,y,w,h,fill,stroke=op
            shp=sl.shapes.add_shape(MSO_SHAPE.OVAL,IN(x),IN(y),IN(w),IN(h))
            shp.fill.solid(); shp.fill.fore_color.rgb=C(fill); shp.line.color.rgb=C(stroke); shp.line.width=Pt(1.5); shp.shadow.inherit=False
        elif k=="line":
            _,x1,y1,x2,y2,col,wpx=op
            cn=sl.shapes.add_connector(MSO_CONNECTOR.STRAIGHT,IN(x1),IN(y1),IN(x2),IN(y2)); cn.line.color.rgb=C(col); cn.line.width=Pt(wpx/2.0); cn.shadow.inherit=False
        elif k=="text":
            _,x,y,w,h,runs,anchor,align,autofit=op
            tb=sl.shapes.add_textbox(IN(x),IN(y),IN(w),IN(h)); tf=tb.text_frame; tf.word_wrap=True; tf.vertical_anchor=AN[anchor]
            if autofit: tf.auto_size=MSO_AUTO_SIZE.TEXT_TO_FIT_SHAPE
            tf.margin_left=Pt(2); tf.margin_right=Pt(2); tf.margin_top=Pt(1); tf.margin_bottom=Pt(1)
            for i,(txt,size,bold,color,spb) in enumerate(runs):
                p=tf.paragraphs[0] if i==0 else tf.add_paragraph(); p.alignment=AL[align]
                if spb: p.space_before=PTf(spb)
                p.space_after=Pt(0)
                r=p.add_run(); r.text=txt; r.font.size=PTf(size); r.font.bold=bold; r.font.color.rgb=C(color); r.font.name="Inter"
prs.save("/tmp/Sona_Care_Journey_Deck.pptx"); print("pptx saved")

# ===== render PNG preview =====
FR="/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"; FB="/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
def rgb(h): return tuple(int(h[i:i+2],16) for i in (0,2,4))
def font(px,bold): return ImageFont.truetype(FB if bold else FR, max(6,int(round(px))))
def wrap(d,txt,f,mw):
    out=[]
    for seg in txt.split("\n"):
        words=seg.split(); cur=""
        if not words: out.append(""); continue
        for wd in words:
            t=(cur+" "+wd).strip()
            if d.textlength(t,font=f)<=mw or not cur: cur=t
            else: out.append(cur); cur=wd
        out.append(cur)
    return out
def layout(d,runs,mw,sc):
    blks=[]
    for (txt,size,bold,color,spb) in runs:
        f=font(size*sc,bold); ls=wrap(d,txt,f,mw); a,de=f.getmetrics(); lh=a+de+int(3*sc)
        blks.append((ls,f,rgb(color),int(spb*sc),lh))
    tot=sum(spb+lh*len(ls) for ls,f,c,spb,lh in blks)
    return blks,tot
imgs=[]
for ops in slides:
    im=Image.new("RGB",(W,H),(255,255,255)); d=ImageDraw.Draw(im)
    for op in ops:
        k=op[0]
        if k=="rect":
            _,x,y,w,h,fill,stroke,rad=op
            box=[x,y,x+w,y+h]
            if rad: d.rounded_rectangle(box,radius=rad,fill=rgb(fill) if fill else None,outline=rgb(stroke) if stroke else None,width=2 if stroke else 1)
            else: d.rectangle(box,fill=rgb(fill) if fill else None,outline=rgb(stroke) if stroke else None,width=2 if stroke else 1)
        elif k=="oval":
            _,x,y,w,h,fill,stroke=op; d.ellipse([x,y,x+w,y+h],fill=rgb(fill),outline=rgb(stroke),width=3)
        elif k=="line":
            _,x1,y1,x2,y2,col,wpx=op; d.line([x1,y1,x2,y2],fill=rgb(col),width=max(1,int(wpx)))
        elif k=="text":
            _,x,y,w,h,runs,anchor,align,autofit=op
            mw=w-4; sc=1.0; blks,tot=layout(d,runs,mw,sc)
            if autofit and tot>h-2 and tot>0: sc=max(0.4,(h-2)/tot); blks,tot=layout(d,runs,mw,sc)
            cy=y+1
            if anchor=='m': cy=y+max(0,(h-tot)/2)
            for ls,f,col,spb,lh in blks:
                cy+=spb
                for ln in ls:
                    tw=d.textlength(ln,font=f)
                    tx=x+(w-tw)/2 if align=='c' else (x+w-2-tw if align=='r' else x+2)
                    d.text((tx,cy),ln,font=f,fill=col); cy+=lh
    imgs.append(im);
for i,im in enumerate(imgs): im.save(f"/tmp/n_slide_{i+1}.png")
gap=28; sheet=Image.new("RGB",(W,H*3+gap*4),(220,220,220)); yy=gap
for im in imgs: sheet.paste(im,(0,yy)); yy+=H+gap
sheet.save("/tmp/n_deck_preview.png"); print("preview saved")
