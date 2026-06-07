#!/usr/bin/env python3
# Shared scene-graph -> PPTX + PNG preview
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR, MSO_AUTO_SIZE
from pptx.enum.shapes import MSO_SHAPE, MSO_CONNECTOR
from PIL import Image, ImageDraw, ImageFont

SW, SH = 13.333, 7.5
# palette
TEAL="2D6A6E"; DTEAL="234F52"; INK="15302E"; GREY="5A6A66"; MUT="8A938F"
BG="FAFAF7"; CARD="FFFFFF"; STROKE="D8E0DE"; APRICOT="F2A878"
PSTRONG=["2D6A6E","356985","C0703F","6E5A86","4C8060"]
PTINT  =["DCE9E8","DCE7EE","F6E5D7","E8E2F0","DCEBE0"]
PAIN="F1EEE9"; CHIP="E3EFEE"; BAND="F6F4EF"; PAINK="6E2F2F"

slides=[]   # each: list of ops
def newslide(bg=BG):
    s=[("rect",0,0,SW,SH,bg,None,0,False)]; slides.append(s); return s
def rect(s,x,y,w,h,fill,line=None,radius=0.08,rounded=True):
    s.append(("rect",x,y,w,h,fill,line,radius,rounded))
def text(s,x,y,w,h,runs,anchor='m',align='l',autofit=False):
    s.append(("text",x,y,w,h,runs,anchor,align,autofit))
def line(s,x1,y1,x2,y2,color,wpt):
    s.append(("line",x1,y1,x2,y2,color,wpt))
def oval(s,x,y,w,h,fill,linec,lw):
    s.append(("oval",x,y,w,h,fill,linec,lw))
def cell(s,x,y,w,h,fill,txt,size,color=INK,bold=False,align='c',line=None,radius=0.10,anchor='m',autofit=True):
    rect(s,x,y,w,h,fill,line=line,radius=radius)
    text(s,x,y,w,h,[(txt,size,bold,color,0)],anchor=anchor,align=align,autofit=autofit)

L=0.45; R=12.88; CW=R-L

# ============ SLIDE 1 : OVERVIEW ============
s=newslide()
rect(s,L,0.4,CW,1.45,TEAL,radius=0.06)
text(s,L,0.4,CW,1.45,[("Sona — Care Journey & Product Overview",30,True,"FFFFFF",0),
   ("An AI co-pilot that reduces admin burnout in UK private Speech & Language Therapy (SLT) — giving clinicians more productive time for care across a client's first 30 days.",13,False,"DCEDEC",8)],anchor='m',align='l')
rect(s,L,2.1,6.05,3.45,CARD,line=STROKE)
text(s,L,2.1,6.05,3.45,[("WHAT IS SONA?",13,True,TEAL,0),
   ("Sona is an AI co-pilot for UK private Speech & Language Therapy (SLT) practices.",12.5,False,INK,12),
   ("It does the repetitive admin alongside the clinician — capturing the enquiry, running a smart intake, prepping the consult, recording the triage decision, and drafting the first session plan and family summary — always as drafts for the clinician to review.",12.5,False,INK,10),
   ("Sona augments clinicians. Its purpose is to increase human productivity — less admin burnout, more time for care.",12.5,False,INK,10)],anchor='t',align='l')
rect(s,6.83,2.1,6.05,3.45,CARD,line=STROKE)
text(s,6.83,2.1,6.05,3.45,[("HOW TO READ THIS BOARD",13,True,TEAL,0),
   ("•  Two views follow: the Executive view (the journey, the value, the bets) and the Product view (what we'll build, stage by stage).",12.5,False,INK,12),
   ("•  Read each view left → right — the client's journey across the first ~30 days of a new case.",12.5,False,INK,10),
   ("•  Who's who: client / parent / carer = the family or adult client · clinician / SLT = the therapist · practice = the private clinic.",12.5,False,INK,10)],anchor='t',align='l')
rect(s,L,5.75,CW,0.78,DTEAL,radius=0.10)
text(s,L,5.75,CW,0.78,[("ANCHOR PRINCIPLES      (1) AI drafts, clinician decides      (2) No screen time for children — all interfaces are adult-facing      (3) UK data residency + audit trail by construction      (4) Augment people, never replace them — increase human productivity",11.5,True,"FFFFFF",0)],anchor='m',align='c',autofit=True)
text(s,L,6.6,CW,0.35,[("Generalized across SLTs (Pediatric & Adult) · synthetic example persona · no PHI",10,False,MUT,0)],anchor='m',align='l')

# ============ SLIDE 2 : EXECUTIVE — JOURNEY ============
s=newslide()
text(s,L,0.28,CW,0.55,[("Executive view — the care journey at a glance",24,True,TEAL,0)],anchor='m',align='l')
text(s,L,0.8,CW,0.32,[("How a new SLT case feels today, and where Sona reduces admin burnout and adds value — five phases.",12.5,False,GREY,0)],anchor='m',align='l')
phases=[("1 · Find & enquire",0),("2 · Understand",1),("3 · Meet & decide",2),("4 · Plan & share",3),("5 · Progress together",4)]
pw=2.35; pgap=(CW-5*pw)/4; pstep=pw+pgap
pxs=[L+i*pstep for i in range(5)]
for (lab,pi),x in zip(phases,pxs):
    cell(s,x,1.2,pw,0.72,PSTRONG[pi],lab,13,color="FFFFFF",bold=True,radius=0.14)
sb_y,sb_h=2.1,1.45
rect(s,L,sb_y,CW,sb_h,BAND,radius=0.04)
text(s,L+0.12,sb_y+0.04,3.0,0.25,[("SENTIMENT — family + clinician",10,True,MUT,0)],anchor='t',align='l')
moods=[("Anxious",0.18),("Overwhelmed",0.06),("Hopeful",0.5),("Reassured",0.78),("Confident",0.96)]
cxs=[x+pw/2 for x in pxs]
top=sb_y+0.4; rng=0.72
pys=[top+(1-lvl)*rng for _,lvl in moods]
for i in range(4):
    line(s,cxs[i],pys[i],cxs[i+1],pys[i+1],DTEAL,2.5)
for (m,_),cx,py in zip(moods,cxs,pys):
    oval(s,cx-0.08,py-0.08,0.16,0.16,TEAL,"FFFFFF",2)
    text(s,cx-1.0,sb_y+sb_h-0.34,2.0,0.28,[(m,11,True,TEAL,0)],anchor='m',align='c')
text(s,L,3.62,CW,0.25,[("TOP PAINS TODAY",10,True,MUT,0)],anchor='t',align='l')
pains=["Enquiries slip through the cracks","Chasing forms; everything is manual","Prep rushed; the free consult under-delivers","Plans hand-built; reports take ~3 weeks","Carryover is ad-hoc (email / WhatsApp)"]
for p,x in zip(pains,pxs):
    cell(s,x,3.88,pw,0.8,PAIN,p,11,color=PAINK,radius=0.10)
text(s,L,4.88,CW,0.25,[("WHAT IT'S WORTH (TARGETS)",10,True,MUT,0)],anchor='t',align='l')
targets=[("≥ 4 hours / month","TARGET — productive hours given back to each clinician"),
         ("Same-day","TARGET — client summaries & reports vs the ~3-week baseline")]
tw=(CW-0.4)/2
for i,(big,sub) in enumerate(targets):
    x=L+i*(tw+0.4)
    rect(s,x,5.14,tw,1.18,CARD,line=STROKE)
    rect(s,x+0.22,5.34,0.5,0.06,APRICOT,radius=0.02)
    text(s,x,5.46,tw,0.55,[(big,26,True,TEAL,0)],anchor='t',align='l')
    text(s,x,6.02,tw,0.25,[(sub,11.5,False,GREY,0)],anchor='t',align='l')

# ============ SLIDE 3 : EXECUTIVE — STRATEGY ============
s=newslide()
text(s,L,0.28,CW,0.55,[("Executive view — strategy & sequencing",24,True,TEAL,0)],anchor='m',align='l')
text(s,L,0.86,CW,0.25,[("STRATEGIC OPPORTUNITIES — where Sona wins",10,True,MUT,0)],anchor='t',align='l')
opps=["Own the first 30 days as one reviewed loop","Trust is the moat — clinician signs every AI draft","Start paediatric, generalise across other areas","UK data residency + Clinical audit"]
ow=(CW-3*0.18)/4; ostep=ow+0.18
for o,i in zip(opps,range(4)):
    cell(s,L+i*ostep,1.1,ow,0.85,CHIP,o,11.5,color=TEAL,bold=True,radius=0.10)
text(s,L,2.2,6.0,0.25,[("PRIORITISATION — impact × effort · vertical = impact, horizontal = effort",10,True,MUT,0)],anchor='t',align='l')
mx,my,mw,mh=L,2.5,6.0,4.3
rect(s,mx,my,mw,mh,BAND,radius=0.03)
line(s,mx+mw/2,my+0.1,mx+mw/2,my+mh-0.1,"C9CFC9",1)
line(s,mx+0.1,my+mh/2,mx+mw-0.1,my+mh/2,"C9CFC9",1)
text(s,mx+0.12,my+0.06,2.0,0.25,[("QUICK WINS",9.5,True,GREY,0)],anchor='t',align='l')
text(s,mx+mw-2.12,my+0.06,2.0,0.25,[("BIG BETS",9.5,True,GREY,0)],anchor='t',align='r')
text(s,mx+0.12,my+mh-0.3,2.0,0.25,[("FILL-INS",9.5,True,GREY,0)],anchor='t',align='l')
text(s,mx+mw-2.12,my+mh-0.3,2.0,0.25,[("TIME SINKS",9.5,True,GREY,0)],anchor='t',align='r')
dots=[("Trust / sign-off",0.22,0.85),("Own 30-day loop",0.6,0.8),("Paediatric → generalise",0.42,0.62),("UK residency + audit",0.55,0.42)]
pad=0.55
for lab,eff,imp in dots:
    px=mx+pad+eff*(mw-2*pad); py=my+mh-pad-imp*(mh-2*pad)
    oval(s,px-0.08,py-0.08,0.16,0.16,APRICOT,TEAL,1.5)
    text(s,px+0.14,py-0.15,2.6,0.3,[(lab,10,True,TEAL,0)],anchor='m',align='l')
sx=6.9; sw=R-sx
text(s,sx,2.2,sw,0.25,[("SEQUENCED BETS — ranked by impact × feasibility",10,True,MUT,0)],anchor='t',align='l')
seq=["1 · Trust as the moat — clinician sign-off on every AI draft   (Impact H · Effort L–M · DO NOW)",
     "2 · Own the first 30 days as one reviewed loop   (Impact H · Effort M · DO NOW)",
     "3 · UK data residency + audit by construction   (Impact M · Effort M · NOW)",
     "4 · Start paediatric, then generalise across other areas   (Impact H · Effort M · NEXT)"]
for i,t in enumerate(seq):
    cell(s,sx,2.55+i*0.95,sw,0.78,CHIP,t,11.5,color=TEAL,bold=True,align='l',radius=0.10)

# ============ SLIDE 4 : PRODUCT VIEW ============
s=newslide()
text(s,L,0.28,CW,0.55,[("Product view — overview of the proposed solution",24,True,TEAL,0)],anchor='m',align='l')
text(s,L,0.82,CW,0.45,[("The client's first 30 days of care as 9 stages grouped into 5 phases. For each stage: what Sona does for the user, and the surface (family app / portal, clinician web, or background AI) that delivers it.",12,False,GREY,0)],anchor='t',align='l')
labW=1.25; gx=L+labW+0.08; ncol=9; cgap=0.07
cw=(R-gx-(ncol-1)*cgap)/ncol; cstep=cw+cgap
colx=[gx+i*cstep for i in range(ncol)]
stage_phase=[0,1,1,2,2,2,3,3,4]
stages=["1 · Referral / first contact","2 · Smart intake","3 · Intake review & overview","4 · Consult prep","5 · Consultation","6 · Triage decision","7 · First session plan","8 · Client / family summary","9 · Carryover & progress"]
whats=["Capture every enquiry in one place — case record + audit trail.","Adaptive magic-link intake + live status + consent.","One-screen client overview / summary view.","AI prep brief — probe areas, red flags, references.","Schedule the consult + calendar / video links.","Capture triage outcome + rationale (configurable).","AI-drafted, clinician-edited first session plan.","Tone / reading-level client summary via secure portal.","Resources, progress portal & assessment-report loop."]
surf=["Clinician web — enquiry queue","Family / client portal (mobile · web)","Clinician web","Clinician web + AI worker","Clinician web + calendar / video","Clinician web — triage","Clinician web + AI worker","Client portal / app + AI worker","Client app + clinician web"]
phase_lbl=["1 · Find & enquire","2 · Understand","3 · Meet & decide","4 · Plan & share","5 · Progress together"]
y_phase,h_phase=1.5,0.5; y_stage,h_stage=2.05,0.62; y_what,h_what=2.72,1.95; y_surf,h_surf=4.72,1.45
cell(s,L,y_phase,labW,h_phase,TEAL,"Phase",11,color="FFFFFF",bold=True,radius=0.12)
cell(s,L,y_stage,labW,h_stage,TEAL,"Stage",11,color="FFFFFF",bold=True,radius=0.12)
cell(s,L,y_what,labW,h_what,"E7E7E2","What Sona does",12,color=INK,bold=True,radius=0.10)
cell(s,L,y_surf,labW,h_surf,"E7E7E2","Surface / owner",12,color=INK,bold=True,radius=0.10)
spans={0:(0,0),1:(1,2),2:(3,5),3:(6,7),4:(8,8)}
for pi,(a,b) in spans.items():
    x0=colx[a]; x1=colx[b]+cw
    cell(s,x0,y_phase,x1-x0,h_phase,PSTRONG[pi],phase_lbl[pi],11,color="FFFFFF",bold=True,radius=0.10)
for i in range(ncol):
    pi=stage_phase[i]; x=colx[i]
    cell(s,x,y_stage,cw,h_stage,PSTRONG[pi],stages[i],8.5,color="FFFFFF",bold=True,radius=0.12)
    cell(s,x,y_what,cw,h_what,PTINT[pi],whats[i],9.5,color=INK,radius=0.10)
    cell(s,x,y_surf,cw,h_surf,PTINT[pi],surf[i],9.5,color=INK,radius=0.10)
text(s,L,y_surf+h_surf+0.12,CW,0.3,[("Generalized across SLTs (Pediatric & Adult)   ·   Colour groups the 9 stages into their 5 phases.",10,False,MUT,0)],anchor='t',align='l')

# ============ RENDER: PPTX ============
def C(h): return RGBColor.from_string(h)
ALIGN={'l':PP_ALIGN.LEFT,'c':PP_ALIGN.CENTER,'r':PP_ALIGN.RIGHT}
ANCH={'t':MSO_ANCHOR.TOP,'m':MSO_ANCHOR.MIDDLE}
prs=Presentation(); prs.slide_width=Inches(SW); prs.slide_height=Inches(SH)
BL=prs.slide_layouts[6]
for ops in slides:
    sl=prs.slides.add_slide(BL)
    for op in ops:
        k=op[0]
        if k=="rect":
            _,x,y,w,h,fill,lc,rad,rnd=op
            shp=sl.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE if rnd else MSO_SHAPE.RECTANGLE,Inches(x),Inches(y),Inches(w),Inches(h))
            if fill is None: shp.fill.background()
            else: shp.fill.solid(); shp.fill.fore_color.rgb=C(fill)
            if lc is None: shp.line.fill.background()
            else: shp.line.color.rgb=C(lc); shp.line.width=Pt(1)
            shp.shadow.inherit=False
            if rnd:
                try: shp.adjustments[0]=max(0.0,min(0.5,rad/min(w,h)))
                except Exception: pass
        elif k=="oval":
            _,x,y,w,h,fill,lc,lw=op
            shp=sl.shapes.add_shape(MSO_SHAPE.OVAL,Inches(x),Inches(y),Inches(w),Inches(h))
            shp.fill.solid(); shp.fill.fore_color.rgb=C(fill)
            shp.line.color.rgb=C(lc); shp.line.width=Pt(lw); shp.shadow.inherit=False
        elif k=="line":
            _,x1,y1,x2,y2,col,wpt=op
            cn=sl.shapes.add_connector(MSO_CONNECTOR.STRAIGHT,Inches(x1),Inches(y1),Inches(x2),Inches(y2))
            cn.line.color.rgb=C(col); cn.line.width=Pt(wpt); cn.shadow.inherit=False
        elif k=="text":
            _,x,y,w,h,runs,anchor,align,autofit=op
            tb=sl.shapes.add_textbox(Inches(x),Inches(y),Inches(w),Inches(h))
            tf=tb.text_frame; tf.word_wrap=True; tf.vertical_anchor=ANCH[anchor]
            if autofit: tf.auto_size=MSO_AUTO_SIZE.TEXT_TO_FIT_SHAPE
            tf.margin_left=Inches(0.07); tf.margin_right=Inches(0.07); tf.margin_top=Inches(0.03); tf.margin_bottom=Inches(0.03)
            for i,(txt,size,bold,color,sp) in enumerate(runs):
                p=tf.paragraphs[0] if i==0 else tf.add_paragraph()
                p.alignment=ALIGN[align]
                if sp: p.space_before=Pt(sp)
                p.space_after=Pt(0)
                r=p.add_run(); r.text=txt; r.font.size=Pt(size); r.font.bold=bold; r.font.color.rgb=C(color); r.font.name="Calibri"
prs.save("/tmp/Sona_Care_Journey_Deck.pptx")
print("pptx saved")

# ============ RENDER: PNG preview ============
S=150
FR="/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
FB="/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
def rgb(h): return tuple(int(h[i:i+2],16) for i in (0,2,4))
def font(size_pt,bold): return ImageFont.truetype(FB if bold else FR, max(6,int(round(size_pt*S/72))))
def wrap(draw,txt,fnt,maxw):
    words=txt.split(); lines=[]; cur=""
    for wd in words:
        t=(cur+" "+wd).strip()
        if draw.textlength(t,font=fnt)<=maxw or not cur: cur=t
        else: lines.append(cur); cur=wd
    if cur: lines.append(cur)
    return lines
def para_layout(draw,runs,maxw,scale):
    blocks=[]
    for (txt,size,bold,color,sp) in runs:
        fnt=font(size*scale,bold)
        ls=wrap(draw,txt,fnt,maxw)
        asc,desc=fnt.getmetrics(); lh=asc+desc+int(2*scale)
        blocks.append((ls,fnt,rgb(color),int(sp*S/72*scale),lh))
    total=0
    for ls,fnt,col,sp,lh in blocks: total+=sp+lh*len(ls)
    return blocks,total
imgs=[]
for ops in slides:
    im=Image.new("RGB",(int(SW*S),int(SH*S)),(255,255,255)); d=ImageDraw.Draw(im)
    for op in ops:
        k=op[0]
        if k=="rect":
            _,x,y,w,h,fill,lc,rad,rnd=op
            box=[x*S,y*S,(x+w)*S,(y+h)*S]; r=int(rad*S) if rnd else 0
            fl=rgb(fill) if fill else None; ol=rgb(lc) if lc else None
            if r>0: d.rounded_rectangle(box,radius=r,fill=fl,outline=ol,width=2 if ol else 1)
            else: d.rectangle(box,fill=fl,outline=ol,width=2 if ol else 1)
        elif k=="oval":
            _,x,y,w,h,fill,lc,lw=op
            d.ellipse([x*S,y*S,(x+w)*S,(y+h)*S],fill=rgb(fill),outline=rgb(lc),width=max(1,int(lw)))
        elif k=="line":
            _,x1,y1,x2,y2,col,wpt=op
            d.line([x1*S,y1*S,x2*S,y2*S],fill=rgb(col),width=max(1,int(wpt)))
        elif k=="text":
            _,x,y,w,h,runs,anchor,align,autofit=op
            maxw=(w-0.14)*S; boxh=(h-0.06)*S
            scale=1.0
            blocks,total=para_layout(d,runs,maxw,scale)
            if autofit and total>boxh and total>0:
                scale=max(0.4,boxh/total); blocks,total=para_layout(d,runs,maxw,scale)
            cy=y*S+0.03*S
            if anchor=='m': cy=y*S+max(0,(h*S-total)/2)
            for ls,fnt,col,sp,lh in blocks:
                cy+=sp
                for ln in ls:
                    tw=d.textlength(ln,font=fnt)
                    if align=='c': tx=x*S+(w*S-tw)/2
                    elif align=='r': tx=(x+w)*S-0.07*S-tw
                    else: tx=x*S+0.07*S
                    d.text((tx,cy),ln,font=fnt,fill=col); cy+=lh
    imgs.append(im)
# stack vertically with gaps into one preview
gap=30
W=imgs[0].width; H=sum(i.height for i in imgs)+gap*(len(imgs)+1)
sheet=Image.new("RGB",(W,H),(220,220,220)); yy=gap
for i in imgs:
    sheet.paste(i,(0,yy)); yy+=i.height+gap
sheet.save("/tmp/deck_preview.png")
for idx,i in enumerate(imgs): i.save(f"/tmp/slide_{idx+1}.png")
print("preview saved", sheet.size)
