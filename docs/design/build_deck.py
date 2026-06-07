#!/usr/bin/env python3
# 16:9 deck mirroring the 4 Figma board slides
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR, MSO_AUTO_SIZE
from pptx.enum.shapes import MSO_SHAPE, MSO_CONNECTOR
from pptx.oxml.ns import qn
from PIL import Image, ImageDraw, ImageFont
import math

W,H=1920,1080
T=dict(bg="FAFAF7",surf="FFFFFF",teal="2D6A6E",dteal="1E4A4D",apri="F2A878",ink="142433",
       sec="4A5B6B",mut="8597A4",bord="E5E7EB",hero="E6F0F0",lt="EAF1F0",ltteal="A9C7C7",
       paincard="F2F5F6",painink="3A4A55",area="D9E7E6",guide="D7DDE0",aibg="FFF0E6",aibd="C45A1A",band2="F3F6F6",cline="9AA7AD")
PS=["2D6A6E","356985","C0703F","6E5A86","4C8060"]; PT=["DCE9E8","DCE7EE","F6E5D7","E8E2F0","DCEBE0"]
slides=[]
def NS(): s=[("rect",0,0,W,H,T["bg"],None,0)]; slides.append(s); return s
def R(s,x,y,w,h,fill,rad=0,stroke=None): s.append(("rect",x,y,w,h,fill,stroke,rad))
def L(s,x1,y1,x2,y2,col,wpx): s.append(("line",x1,y1,x2,y2,col,wpx))
def O(s,x,y,w,h,fill,stroke): s.append(("oval",x,y,w,h,fill,stroke))
def AREA(s,pts,fill): s.append(("area",pts,fill))
def TX(s,x,y,w,h,runs,anchor='t',align='l',autofit=False):
    if isinstance(runs,str): runs=[(runs,16,False,T["ink"],0)]
    s.append(("text",x,y,w,h,runs,anchor,align,autofit))
def LINE2(s,x,y,w,h,lead,rest,size): s.append(("line2",x,y,w,h,lead,rest,size))
def RT(s,x,y,w,h,txt,size,color): s.append(("rtext",x,y,w,h,txt,size,color))
def DIA(s,x,y,w,h,fill,stroke,txt,size,color): s.append(("dia",x,y,w,h,fill,stroke,txt,size,color))
def CELL(s,x,y,w,h,fill,txt,size,color,bold=False,align='c',rad=12,stroke=None,pad=12):
    R(s,x,y,w,h,fill,rad,stroke); TX(s,x+pad,y,w-2*pad,h,[(txt,size,bold,color,0)],'m',align,True)

L0=90; R0=1830
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
TX(s,1006,320,800,28,[("HOW TO READ THIS",16,True,T["teal"],0)])
TX(s,1006,362,800,28,[("Three views, read left → right:",18,False,T["sec"],0)])
LINE2(s,1006,406,820,28,"Executive","  —  the journey & the value",18)
LINE2(s,1006,446,820,28,"Product","  —  the proposed solution",18)
LINE2(s,1006,486,820,28,"Process flow","  —  the To-Be swimlane",18)
TX(s,1006,556,800,26,[("WHO'S WHO",15,True,T["teal"],0)])
TX(s,1006,588,810,60,[("client / parent / carer — the family or adult client\nclinician / SLT — the therapist    ·    practice — the private clinic",16,False,T["sec"],0)])
R(s,90,892,1740,120,T["lt"],16)
TX(s,122,914,600,24,[("ANCHOR PRINCIPLES",14,True,T["teal"],0)])
for p,x in zip(["AI drafts, clinician decides","No screen time for children","UK data residency + audit by construction","Augment people, never replace them"],[122,556,990,1410]):
    TX(s,x,950,420,28,[(p,15,False,T["dteal"],0)])
for x in [540,974,1394]: R(s,x,946,1,44,T["bord"],0)
TX(s,90,1040,900,22,[("Sona — Care Journey & Product Overview",12,False,T["mut"],0)]); TX(s,1640,1040,190,22,[("1 / 4",12,False,T["mut"],0)],'t','r')

# ---------- SLIDE 2 ----------
s=NS()
TX(s,90,74,900,26,[("EXECUTIVE VIEW",15,True,T["mut"],0)])
TX(s,90,100,1600,60,[("The care journey at a glance",40,True,T["teal"],0)])
TX(s,90,168,1620,50,[("How a new SLT case feels today, and where Sona reduces admin burnout and adds value — across five phases.",19,False,T["sec"],0)])
R(s,92,224,140,5,T["apri"],2)
gap=22; cw=(R0-L0-4*gap)/5; step=cw+gap; xs=[L0+i*step for i in range(5)]; cx=[x+cw/2 for x in xs]
ph=["1 · Find & enquire","2 · Understand","3 · Meet & decide","4 · Plan & share","5 · Progress together"]
for i in range(5): CELL(s,xs[i],262,cw,66,PS[i],ph[i],18,"FFFFFF",True,'c',12)
TX(s,90,360,1200,24,[("HOW EACH PHASE FEELS  ·  one point per phase, family + clinician",14,True,T["mut"],0)])
lvl=[0.18,0.06,0.5,0.78,0.96]; base=540; py=[414+(1-l)*108 for l in lvl]
for i in range(5): L(s,cx[i],330,cx[i],py[i]-9,T["guide"],1.5)
AREA(s,[(cx[0],base)]+[(cx[i],py[i]) for i in range(5)]+[(cx[4],base)],T["area"])
L(s,L0,base,R0,base,T["bord"],1.5)
for i in range(4): L(s,cx[i],py[i],cx[i+1],py[i+1],T["teal"],4)
moods=["Anxious","Overwhelmed","Hopeful","Reassured","Confident"]
desc=["unsure where to start","so much to take in","a clear path forward","kept in the loop","confident & in control"]
for i in range(5):
    O(s,cx[i]-11,py[i]-11,22,22,PS[i],"FFFFFF")
    TX(s,xs[i],556,cw,24,[(moods[i],17,True,PS[i],0)],'m','c'); TX(s,xs[i],582,cw,22,[(desc[i],13.5,False,T["sec"],0)],'m','c')
TX(s,90,636,900,24,[("TODAY'S PAIN — BY PHASE",14,True,T["mut"],0)])
pains=["Enquiries slip through the cracks","Chasing forms — everything is manual","Prep is rushed; the free consult under-delivers","Plans hand-built; reports take ~3 weeks","Carryover is ad-hoc (email / WhatsApp)"]
for i in range(5):
    R(s,xs[i],668,cw,116,T["paincard"],12,T["bord"]); O(s,xs[i]+16,668+16,9,9,PS[i],None)
    TX(s,xs[i]+16,668,cw-32,116,[(pains[i],16,False,T["painink"],0)],'m','c',True)
TX(s,90,812,900,24,[("TARGET OUTCOMES",14,True,T["mut"],0)])
R(s,92,844,90,5,T["apri"],2); TX(s,90,858,820,56,[("≥ 4 hours / month",42,True,T["teal"],0)]); TX(s,90,924,820,30,[("productive hours given back to each clinician",18,False,T["sec"],0)])
R(s,1002,844,90,5,T["apri"],2); TX(s,1000,858,820,56,[("Same-day",42,True,T["teal"],0)]); TX(s,1000,924,820,30,[("client summaries & reports, vs the ~3-week manual baseline",18,False,T["sec"],0)])
TX(s,90,1040,900,22,[("Sona — Care Journey & Product Overview",12,False,T["mut"],0)]); TX(s,1640,1040,190,22,[("2 / 4",12,False,T["mut"],0)],'t','r')

# ---------- SLIDE 3 ----------
s=NS()
TX(s,90,74,900,26,[("PRODUCT VIEW",15,True,T["mut"],0)])
TX(s,90,100,1600,60,[("The proposed solution",40,True,T["teal"],0)])
TX(s,90,168,1660,50,[("The client's first 30 days as nine stages grouped into five phases — for each stage: what Sona does, and the surface that delivers it.",19,False,T["sec"],0)])
R(s,92,224,140,5,T["apri"],2)
lab=148; gx=L0+lab+12; ncol=9; cg=10; cwd=(R0-gx-(ncol-1)*cg)/ncol; st2=cwd+cg; colx=[gx+i*st2 for i in range(ncol)]; spn=[0,1,1,2,2,2,3,3,4]
stg=["1 · Referral","2 · Smart intake","3 · Intake review","4 · Consult prep","5 · Consultation","6 · Triage","7 · Session plan","8 · Family summary","9 · Carryover"]
wh=["Capture every enquiry — one case record + audit trail.","Adaptive magic-link intake + live status + consent.","One-screen client overview / summary.","AI prep brief — probes, red flags, references.","Schedule the consult + calendar / video links.","Capture triage outcome + rationale.","AI-drafted, clinician-edited session plan.","Tone / reading-level client summary via portal.","Resources, progress portal & report loop."]
sf=["Clinician web — enquiry queue","Family / client portal","Clinician web","Clinician web + AI","Clinician web + calendar / video","Clinician web — triage","Clinician web + AI","Client app / portal + AI","Client app + clinician web"]
plab=["Find & enquire","Understand","Meet & decide","Plan & share","Progress together"]; spans={0:(0,0),1:(1,2),2:(3,5),3:(6,7),4:(8,8)}
yP,hP,yS,hS,yW,hW,yU,hU=288,50,346,60,414,180,602,120
TX(s,90,yP,lab,hP,[("Phase",14,True,T["sec"],0)],'m','l'); TX(s,90,yS,lab,hS,[("Stage",14,True,T["sec"],0)],'m','l')
TX(s,90,yW,lab,hW,[("What Sona does",14,True,T["sec"],0)],'m','l'); TX(s,90,yU,lab,hU,[("Surface / owner",14,True,T["sec"],0)],'m','l')
for k,(a,b) in spans.items():
    x0=colx[a]; x1=colx[b]+cwd; CELL(s,x0,yP,x1-x0,hP,PS[k],plab[k],14,"FFFFFF",True,'c',10)
for i in range(ncol):
    p=spn[i]; x=colx[i]
    CELL(s,x,yS,cwd,hS,PS[p],stg[i],12,"FFFFFF",True,'c',10,None,6)
    CELL(s,x,yW,cwd,hW,PT[p],wh[i],13,T["ink"],False,'c',10,None,12)
    CELL(s,x,yU,cwd,hU,PT[p],sf[i],12.5,T["ink"],False,'c',10,None,12)
TX(s,90,772,900,24,[("WHERE SONA WINS",14,True,T["mut"],0)])
opp=["Own the first 30 days as one reviewed loop","Trust is the moat — clinician signs every AI draft","Start paediatric, then generalise","UK data residency + clinical audit"]
ow=(R0-L0-3*20)/4; ostep=ow+20
for i,o in enumerate(opp): CELL(s,L0+i*ostep,806,ow,82,T["hero"],o,15,T["teal"],True,'c',12,None,16)
TX(s,90,1006,1740,22,[("Colour groups the nine stages into their five phases.   ·   Generalized across SLTs (Pediatric & Adult).",12.5,False,T["mut"],0)])
TX(s,90,1040,900,22,[("Sona — Care Journey & Product Overview",12,False,T["mut"],0)]); TX(s,1640,1040,190,22,[("3 / 4",12,False,T["mut"],0)],'t','r')

# ---------- SLIDE 4 : PROCESS FLOW (positions match the adjusted board) ----------
s=NS()
TX(s,90,64,900,26,[("PROCESS FLOW",15,True,T["mut"],0)])
TX(s,90,90,1500,60,[("How the journey runs with Sona",40,True,T["teal"],0)])
TX(s,90,158,1720,40,[("A swimlane map of the proposed process.",18,False,T["sec"],0)])
top=232; lh=196; labW=156; bandX=60+labW; bandW=1860-bandX; ly=[top+i*lh+lh//2 for i in range(4)]
lanes=[("Client / Parent / Carer","C98A5E"),("Clinician / SLT","2D6A6E"),("Sona  (app & AI)","356985"),("External  (calendar · PMS)","4C8060")]
for i,(nm,col) in enumerate(lanes):
    y=top+i*lh; R(s,bandX,y,bandW,lh,(T["band2"] if i%2 else "FFFFFF"),0,T["bord"]); R(s,60,y,labW,lh,col,0); RT(s,60,y,labW,lh,nm,14,"FFFFFF")
# name: (cx,cy,w,h,kind)
NP={
 "start":(308,330,164,76,"pill"),"end":(1772,330,150,76,"pill"),
 "comp":(480,330,160,70,"box"),"recv":(1596,330,160,70,"box"),
 "dec":(1037,526,172,104,"dia"),"rev":(649,526,160,70,"box"),"cons":(840,526,160,70,"box"),
 "strat":(1254,526,160,70,"box"),"edit":(1488,526,160,70,"box"),"send":(1668,526,160,70,"box"),
 "cap":(306,722,160,70,"box"),"prep":(515,722,160,70,"box"),"plan":(1212,722,160,70,"box"),
 "sum":(1516,722,160,70,"box"),"carry":(1712,722,160,70,"box"),
 "cal":(756,918,160,70,"box"),"pms":(1712,919,160,70,"box")}
LB={"start":"Enquiry arrives","end":"Ongoing care","comp":"Complete intake & consent","recv":"Receive summary (app)",
 "dec":"Ongoing therapy?","rev":"Review overview + prep","cons":"Consultation (~20 min)","strat":"Strategy advice & home tips",
 "edit":"Edit & sign plan","send":"Review & send summary","cap":"Capture enquiry + smart intake","prep":"AI prep brief (DRAFT)",
 "plan":"AI session plan (DRAFT)","sum":"AI family summary (DRAFT)","carry":"Carryover + progress portal","cal":"Calendar / video link","pms":"PMS sync (vision)"}
for n,(cxN,cyN,w,h,kind) in NP.items():
    x=cxN-w/2; y=cyN-h/2
    if kind=="box": CELL(s,x,y,w,h,T["hero"],LB[n],12.5,T["ink"],False,'c',12,T["teal"],10)
    elif kind=="pill": CELL(s,x,y,w,h,T["surf"],LB[n],12.5,T["ink"],True,'c',h/2,"C98A5E",10)
    elif kind=="dia": DIA(s,x,y,w,h,T["aibg"],T["aibd"],LB[n],12.5,T["ink"])
def CONN(a,b,label=""):
    ax,ay,aw,ah,_=NP[a]; bx,by,bw,bh,_=NP[b]; dx=bx-ax; dy=by-ay
    if abs(dx)>=abs(dy): x1=ax+(aw/2 if dx>0 else -aw/2); y1=ay; x2=bx+(-bw/2 if dx>0 else bw/2); y2=by; orient='h'
    else: x1=ax; y1=ay+(ah/2 if dy>0 else -ah/2); x2=bx; y2=by+(-bh/2 if dy>0 else bh/2); orient='v'
    s.append(("conn",x1,y1,x2,y2,orient,label))
for a,b,lbl in [("start","cap",""),("cap","comp",""),("comp","prep",""),("prep","rev",""),("cal","cons",""),("rev","cons",""),("cons","dec",""),("dec","plan","Yes"),("dec","strat","No"),("plan","edit",""),("edit","sum",""),("strat","sum",""),("sum","send",""),("send","recv",""),("send","carry",""),("recv","end",""),("carry","pms","")]:
    CONN(a,b,lbl)
TX(s,bandX,1018,1740,22,[("Shapes:  rounded = task   ·   diamond = decision   ·   pill = start / end.    DRAFT = AI artifact the clinician reviews & signs.",12.5,False,T["mut"],0)])
TX(s,90,1048,900,22,[("Sona — Care Journey & Product Overview",12,False,T["mut"],0)]); TX(s,1640,1048,190,22,[("4 / 4",12,False,T["mut"],0)],'t','r')

# ===== render PPTX =====
def C(h): return RGBColor.from_string(h)
def IN(px): return Inches(px/144.0)
def PTf(px): return Pt(px/2.0)
AL={'l':PP_ALIGN.LEFT,'c':PP_ALIGN.CENTER,'r':PP_ALIGN.RIGHT}; AN={'t':MSO_ANCHOR.TOP,'m':MSO_ANCHOR.MIDDLE}
def fl(shp,fill,stroke,sw=1.0):
    if fill is None: shp.fill.background()
    else: shp.fill.solid(); shp.fill.fore_color.rgb=C(fill)
    if stroke is None: shp.line.fill.background()
    else: shp.line.color.rgb=C(stroke); shp.line.width=Pt(sw)
    shp.shadow.inherit=False
def settext(shp,txt,size,color,bold,align='c'):
    tf=shp.text_frame; tf.word_wrap=True; tf.vertical_anchor=MSO_ANCHOR.MIDDLE; tf.auto_size=MSO_AUTO_SIZE.TEXT_TO_FIT_SHAPE
    for m in ('margin_left','margin_right','margin_top','margin_bottom'): setattr(tf,m,Pt(2))
    p=tf.paragraphs[0]; p.alignment=AL[align]; r=p.add_run(); r.text=txt; r.font.size=PTf(size); r.font.bold=bold; r.font.color.rgb=C(color); r.font.name="Inter"
prs=Presentation(); prs.slide_width=IN(W); prs.slide_height=IN(H); BL=prs.slide_layouts[6]
for ops in slides:
    sl=prs.slides.add_slide(BL)
    for op in ops:
        k=op[0]
        if k=="rect":
            _,x,y,w,h,fill,stroke,rad=op; shp=sl.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE if rad else MSO_SHAPE.RECTANGLE,IN(x),IN(y),IN(w),IN(h)); fl(shp,fill,stroke)
            if rad:
                try: shp.adjustments[0]=max(0,min(0.5,rad/min(w,h)))
                except Exception: pass
        elif k=="oval":
            _,x,y,w,h,fill,stroke=op; shp=sl.shapes.add_shape(MSO_SHAPE.OVAL,IN(x),IN(y),IN(w),IN(h)); fl(shp,fill,stroke,1.5)
        elif k=="dia":
            _,x,y,w,h,fill,stroke,txt,size,color=op; shp=sl.shapes.add_shape(MSO_SHAPE.DIAMOND,IN(x),IN(y),IN(w),IN(h)); fl(shp,fill,stroke,1.5); settext(shp,txt,size,color,True)
        elif k=="area":
            _,pts,fill=op
            try:
                e=[(int(IN(px)),int(IN(py))) for (px,py) in pts]
                fb=sl.shapes.build_freeform(e[0][0],e[0][1],scale=1.0); fb.add_line_segments(e[1:],close=True); shp=fb.convert_to_shape(); fl(shp,fill,None)
            except Exception: pass
        elif k=="line":
            _,x1,y1,x2,y2,col,wpx=op; cn=sl.shapes.add_connector(MSO_CONNECTOR.STRAIGHT,IN(x1),IN(y1),IN(x2),IN(y2)); cn.line.color.rgb=C(col); cn.line.width=Pt(wpx/2.0); cn.shadow.inherit=False
        elif k=="conn":
            _,x1,y1,x2,y2,orient,label=op
            cn=sl.shapes.add_connector(MSO_CONNECTOR.ELBOW,IN(x1),IN(y1),IN(x2),IN(y2)); cn.line.color.rgb=C(T["cline"]); cn.line.width=Pt(1.25); cn.shadow.inherit=False
            ln=cn.line._get_or_add_ln(); ln.append(ln.makeelement(qn('a:tailEnd'),{'type':'triangle','w':'med','len':'med'}))
            if label:
                mx=(x1+x2)/2; my=(y1+y2)/2; tb=sl.shapes.add_textbox(IN(mx-30),IN(my-22),IN(60),IN(22)); pp=tb.text_frame.paragraphs[0]; pp.alignment=PP_ALIGN.CENTER; rr=pp.add_run(); rr.text=label; rr.font.size=PTf(12); rr.font.bold=True; rr.font.color.rgb=C(T["sec"]); rr.font.name="Inter"
        elif k=="rtext":
            _,x,y,w,h,txt,size,color=op; tb=sl.shapes.add_textbox(IN(x),IN(y),IN(w),IN(h)); tb.rotation=270; tf=tb.text_frame; tf.word_wrap=True; tf.vertical_anchor=MSO_ANCHOR.MIDDLE
            p=tf.paragraphs[0]; p.alignment=PP_ALIGN.CENTER; r=p.add_run(); r.text=txt; r.font.size=PTf(size); r.font.bold=True; r.font.color.rgb=C(color); r.font.name="Inter"
        elif k=="line2":
            _,x,y,w,h,lead,rest,size=op; tb=sl.shapes.add_textbox(IN(x),IN(y),IN(w),IN(h)); tf=tb.text_frame; tf.word_wrap=True; p=tf.paragraphs[0]; p.alignment=PP_ALIGN.LEFT
            r1=p.add_run(); r1.text=lead; r1.font.size=PTf(size); r1.font.bold=True; r1.font.color.rgb=C(T["teal"]); r1.font.name="Inter"
            r2=p.add_run(); r2.text=rest; r2.font.size=PTf(size); r2.font.bold=False; r2.font.color.rgb=C(T["ink"]); r2.font.name="Inter"
        elif k=="text":
            _,x,y,w,h,runs,anchor,align,autofit=op; tb=sl.shapes.add_textbox(IN(x),IN(y),IN(w),IN(h)); tf=tb.text_frame; tf.word_wrap=True; tf.vertical_anchor=AN[anchor]
            if autofit: tf.auto_size=MSO_AUTO_SIZE.TEXT_TO_FIT_SHAPE
            for m in ('margin_left','margin_right','margin_top','margin_bottom'): setattr(tf,m,Pt(2))
            for i,(txt,size,bold,color,spb) in enumerate(runs):
                p=tf.paragraphs[0] if i==0 else tf.add_paragraph(); p.alignment=AL[align]
                if spb: p.space_before=PTf(spb)
                p.space_after=Pt(0); r=p.add_run(); r.text=txt; r.font.size=PTf(size); r.font.bold=bold; r.font.color.rgb=C(color); r.font.name="Inter"
prs.save("/tmp/Sona_Care_Journey_Deck.pptx"); print("pptx saved",len(slides))

# ===== PNG preview =====
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
        f=font(size*sc,bold); ls=wrap(d,txt,f,mw); a,de=f.getmetrics(); lh=a+de+int(3*sc); blks.append((ls,f,rgb(color),int(spb*sc),lh))
    return blks,sum(spb+lh*len(ls) for ls,f,c,spb,lh in blks)
def drawtext(d,x,y,w,h,runs,anchor,align,autofit):
    mw=w-4; sc=1.0; blks,tot=layout(d,runs,mw,sc)
    if autofit and tot>h-2 and tot>0: sc=max(0.4,(h-2)/tot); blks,tot=layout(d,runs,mw,sc)
    cy=y+1 if anchor=='t' else y+max(0,(h-tot)/2)
    for ls,f,col,spb,lh in blks:
        cy+=spb
        for ln in ls:
            tw=d.textlength(ln,font=f); tx=x+(w-tw)/2 if align=='c' else (x+w-2-tw if align=='r' else x+2)
            d.text((tx,cy),ln,font=f,fill=col); cy+=lh
def arrow(d,p,ang,col,sz=11):
    x,y=p; a=math.radians(ang); d.polygon([(x,y),(x-sz*math.cos(a-0.5),y-sz*math.sin(a-0.5)),(x-sz*math.cos(a+0.5),y-sz*math.sin(a+0.5))],fill=col)
imgs=[]
for ops in slides:
    im=Image.new("RGB",(W,H),(255,255,255)); d=ImageDraw.Draw(im)
    for op in ops:
        k=op[0]
        if k=="rect":
            _,x,y,w,h,fill,stroke,rad=op; box=[x,y,x+w,y+h]
            if rad: d.rounded_rectangle(box,radius=min(rad,h/2),fill=rgb(fill) if fill else None,outline=rgb(stroke) if stroke else None,width=2 if stroke else 1)
            else: d.rectangle(box,fill=rgb(fill) if fill else None,outline=rgb(stroke) if stroke else None,width=2 if stroke else 1)
        elif k=="oval":
            _,x,y,w,h,fill,stroke=op; d.ellipse([x,y,x+w,y+h],fill=rgb(fill) if fill else None,outline=rgb(stroke) if stroke else None,width=3 if stroke else 1)
        elif k=="area":
            _,pts,fill=op; d.polygon([(px,py) for px,py in pts],fill=rgb(fill))
        elif k=="dia":
            _,x,y,w,h,fill,stroke,txt,size,color=op; d.polygon([(x+w/2,y),(x+w,y+h/2),(x+w/2,y+h),(x,y+h/2)],fill=rgb(fill),outline=rgb(stroke)); drawtext(d,x+14,y,w-28,h,[(txt,size,True,color,0)],'m','c',True)
        elif k=="line":
            _,x1,y1,x2,y2,col,wpx=op; d.line([x1,y1,x2,y2],fill=rgb(col),width=max(1,int(wpx)))
        elif k=="conn":
            _,x1,y1,x2,y2,orient,label=op; col=rgb(T["cline"])
            if orient=='h': mx=(x1+x2)/2; pts=[(x1,y1),(mx,y1),(mx,y2),(x2,y2)]; ang=0 if x2>=mx else 180
            else: my=(y1+y2)/2; pts=[(x1,y1),(x1,my),(x2,my),(x2,y2)]; ang=90 if y2>=my else 270
            d.line(pts,fill=col,width=2,joint="curve"); arrow(d,(x2,y2),ang,col)
            if label: drawtext(d,(x1+x2)/2-30,(y1+y2)/2-20,60,20,[(label,12,True,T["sec"],0)],'m','c',False)
        elif k=="rtext":
            _,x,y,w,h,txt,size,color=op; th=int(h); tw=int(labW); ti=Image.new("RGBA",(th,tw),(0,0,0,0)); td=ImageDraw.Draw(ti)
            f=font(size,True); lines=wrap(td,txt,f,th-10); a,de=f.getmetrics(); llh=a+de+2; cy=(tw-llh*len(lines))/2
            for ln in lines: lw=td.textlength(ln,font=f); td.text(((th-lw)/2,cy),ln,font=f,fill=rgb(color)); cy+=llh
            ti=ti.rotate(90,expand=True); im.paste(ti,(int(x),int(y)),ti)
        elif k=="line2":
            _,x,y,w,h,lead,rest,size=op; fL=font(size,True); fR=font(size,False); a,de=fL.getmetrics(); yy=y+max(0,(h-(a+de))/2)
            d.text((x,yy),lead,font=fL,fill=rgb(T["teal"])); lw=d.textlength(lead,font=fL); d.text((x+lw,yy),rest,font=fR,fill=rgb(T["ink"]))
        elif k=="text":
            _,x,y,w,h,runs,anchor,align,autofit=op; drawtext(d,x,y,w,h,runs,anchor,align,autofit)
    imgs.append(im)
for i,im in enumerate(imgs): im.save(f"/tmp/n_slide_{i+1}.png")
gap=28; sheet=Image.new("RGB",(W,H*len(imgs)+gap*(len(imgs)+1)),(220,220,220)); yy=gap
for im in imgs: sheet.paste(im,(0,yy)); yy+=H+gap
sheet.save("/tmp/n_deck_preview.png"); print("preview saved")
