"""Reviewed source-cell import, based on scenario-sprite-animation's geometry QA.

The source boards are illustrations, not uniform grids. Cell edges and row bands
below describe actual poses. Fewer drawn poses are explicitly held/resampled to
the gameplay timeline; labels never decide a crop. No synthesis or upscaling.
Run without arguments for review artifacts; --apply installs the reviewed atlas.
Requires Pillow. Original boards and prior exports are preserved.
"""
import argparse
import json
from collections import deque
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Art/References/Imported"
DEST = ROOT / "SwordDuel/Resources/Assets/Characters"
REVIEW = ROOT / "Art/FrameRepair"


def row(y0, y1, edges):
    return [(a, y0, b, y1) for a, b in zip(edges, edges[1:])]


# All coordinates are local to the character column, measured on original PNGs.
common3 = {
    "idle": row(203, 252, [5, 67, 138, 208, 278, 346, 413]),
    "walk": row(272, 325, [5, 65, 129, 194, 258, 322, 386, 449, 507]),
    "run": row(346, 396, [5, 69, 133, 197, 261, 325, 389, 451, 507]),
    "jump": row(416, 474, [5, 87, 170, 280]),
    "crouch_block": row(416, 474, [285, 353, 418, 507]),
    "attack1": row(496, 551, [5, 64, 123, 184, 251]),
    "attack2": row(496, 551, [255, 308, 359, 410, 459, 507]),
    "attack3": row(575, 631, [5, 73, 137, 200, 252]),
    "skill1": row(575, 631, [258, 318, 371, 422]),
    "skill2": row(653, 727, [5, 74, 140, 198, 252]),
    "hurt": row(753, 805, [5, 56, 102, 140]),
    "ko": row(753, 805, [143, 189, 229, 270, 312, 339]),
    "win": row(753, 805, [342, 395, 450, 507]),
}
monk = dict(common3, walk=row(275,325,[5,65,129,194,258,322,386,449,507]),
            jump=[(5,421,87,474),(87,405,170,474),(170,401,280,474)],
            attack2=row(496,551,[255,316,380,437,507]),
            crouch_block=row(421,474,[281,350,421,503]),
            attack3=row(575,631,[5,75,150,248]),
            skill1=row(575,631,[253,331]), skill2=row(653,727,[5,76,146,211]),
            ult=row(653,727,[213,365]), hurt=row(753,805,[5,57,116]),
            ko=row(753,805,[119,165,211,260,324]), win=row(753,805,[331,376,420,464,507]))
tang = dict(common3)
tang["idle"]=row(201,253,[5,94,174,254,334,414,507])
tang["jump"]=[(5,419,93,474),(93,405,184,474),(184,405,280,474)]
tang["attack2"]=row(496,551,[258,322,386,446,510])
tang["skill1"]=row(575,631,[263,334,385,443])
tang["ko"]=row(753,805,[141,193,244,287,336])
tang["win"]=row(753,805,[339,380,423,466,510])
# The lotus is a separate spell sprite. Keep the caster visible during its cast.
tang["ult"] = tang["skill1"]
umbrella = {
    "idle": row(203,264,[5,84,159,235,310,388,465]),
    "walk": row(282,340,[5,66,128,190,251,315,377,439,505]),
    "run": row(359,413,[5,68,131,194,257,320,383,446,505]),
    "jump": row(435,489,[5,80,139,211,290]),
    "crouch_block": row(435,489,[298,364,430,505]),
    "attack1": row(510,563,[5,65,124,183,248]),
    "attack2": row(510,563,[253,320,381,443,505]),
    "attack3": row(586,648,[5,67,126,190,254]),
    "skill1": row(586,648,[260,328,395]),
    "skill2": row(675,736,[5,63,120,178,237]),
    "ult": row(675,736,[240,309]),
    "hurt": row(759,805,[5,51,95,138]),
    "ko": row(759,805,[143,189,232,274,325]),
    "win": row(759,805,[333,389,449,505]),
}
common4 = {
    "idle":row(216,258,[5,61,111,163,217,270,325]),
    "walk":row(276,315,[5,53,100,147,194,241,288,335,380]),
    "run":row(334,373,[5,53,100,147,194,241,288,335,380]),
    "jump":row(391,430,[5,95,151,194]),
    "crouch_block":row(391,430,[200,259,321,380]),
    "attack1":row(450,490,[5,65,127,195]),
    "attack2":row(450,490,[200,258,318,380]),
    "attack3":row(512,555,[5,67,127,187]),
    "skill1":row(512,555,[190,253,314,380]),
    "skill2":row(579,633,[5,65,125,187]),
    "hurt":row(654,696,[5,45,84,118]),
    "ko":row(654,696,[122,166,207,252]),
    "win":row(654,696,[259,299,339,380]),
}
herder=dict(common4); herder["ult"]=herder["skill1"]
elder=dict(common4, jump=row(391,430,[5,96,190]),
           attack1=row(450,490,[5,52,97,142,189]),
           attack2=row(450,490,[194,251,310,380]),
           ult=row(579,633,[5,53,104,154,209]))
elder["skill2"]=elder["attack3"]
elder["ko"]=elder["hurt"]
elder["win"]=row(654,696,[274,335,380])
demon=dict(common4, jump=row(391,430,[5,72,130,206]),
           crouch_block=row(391,430,[211,266,319,380]),
           ult=row(579,633,[5,61,120,178,232]))
demon["skill1"]=demon["attack3"]; demon["skill2"]=common4["skill1"]
demon["jump"]=[(5,390,72,430),(72,382,130,430),(130,381,206,430)]
demon["hurt"]=row(654,696,[5,59,113])
beast=dict(common4, idle=row(216,258,[5,67,128,190,250,312,380]),
           jump=row(391,430,[5,67,128,191]),
           ult=row(579,633,[5,67,128,189]))
beast["skill2"]=beast["attack3"]
beast["walk"]=row(276,315,[5,65,117,163,211,266,325,382])
beast["run"]=row(334,373,[5,81,151,206,265,322,382])
beast["jump"]=[(5,391,72,430),(72,382,157,430)]
beast["crouch_block"]=row(391,430,[160,236,303,382])
beast["hurt"]=row(654,696,[5,54,109])
beast["ko"]=beast["hurt"]
beast["win"]=row(654,696,[269,326,382])
flame={
    "idle":row(33,128,[313,389,462,536,610,684,757]),
    "walk":row(33,128,[828,910,989,1070,1150,1230,1312,1392,1473]),
    "run":row(174,261,[815,906,993,1081,1167,1255,1345,1433,1524]),
    "jump":row(171,261,[313,433,552,683,805]),
    "crouch_block":row(308,391,[313,427,541]),
    "attack1":row(309,391,[536,632,711,807,884,1020]),
    "attack2":row(308,391,[1024,1113,1193,1290,1397,1523]),
    "attack3":row(429,508,[315,408,496,583,673,763,853]),
    "skill1":row(429,508,[864,945,1027,1102,1180,1270,1370,1523]),
    "skill2":row(550,635,[315,405,492,578,681,781]),
    "ult":row(545,635,[799,857,918,979,1044,1120,1217]),
    "hurt":row(676,740,[313,374,435,495]),
    "ko":row(676,740,[502,562,625,687,752,827]),
    "win":row(675,740,[842,915,981,1054,1124,1191,1260]),
}
SPECS={
    "umbrella":("umbrella-tang-monk-atlases.png",0,1.1,umbrella),
    "tang":("umbrella-tang-monk-atlases.png",512,1.2,tang),
    "monk":("umbrella-tang-monk-atlases.png",1024,1.2,monk),
    "herder":("herder-elder-demon-beast-atlases.png",0,1.35,herder),
    "elder":("herder-elder-demon-beast-atlases.png",384,1.35,elder),
    "demon":("herder-elder-demon-beast-atlases.png",768,1.35,demon),
    "beast":("herder-elder-demon-beast-atlases.png",1152,1.2,beast),
    "flame":("flame-swordsman-atlas.png",0,.68,flame),
}
umbrella["ult"]=umbrella["skill1"]
umbrella["hurt"]=umbrella["hurt"][:2]
beast["ult"]=beast["attack3"]
elder["ult"]=elder["skill1"]
herder["walk"]=[cell for i,cell in enumerate(herder["walk"]) if i not in (1,5)]


def key_cell(image, preserve_purple=False):
    """Saturated matte removal, component cleanup, then preserve source pixels.

    Like the skill's cycle_frames foreground/component pass, don't use a crop's
    total rectangle as the body bounds. Here the authored field is pink, not
    the skill's default pure-magenta video key.
    """
    im=image.convert("RGBA"); p=im.load(); w,h=im.size
    for y in range(h):
        for x in range(w):
            r,g,b,a=p[x,y]
            matte = r>105 and b>65 and g<100 and min(r,b)-g>55 and .57*r<b<1.3*r
            spill = not preserve_purple and r>65 and b>30 and min(r,b)-g>24 and .32*r<b<1.5*r
            if matte or spill:
                p[x,y]=(0,0,0,0)
    # Remove disconnected matte specks and text remnants; keep meaningful effects.
    seen=set(); components=[]
    for y in range(h):
        for x in range(w):
            if (x,y) in seen or p[x,y][3]==0: continue
            seen.add((x,y)); q=deque([(x,y)]); comp=[]
            while q:
                xx,yy=q.popleft();comp.append((xx,yy))
                for nx,ny in [(xx-1,yy),(xx+1,yy),(xx,yy-1),(xx,yy+1)]:
                    if 0<=nx<w and 0<=ny<h and (nx,ny) not in seen and p[nx,ny][3]:
                        seen.add((nx,ny));q.append((nx,ny))
            xs=[c[0] for c in comp];ys=[c[1] for c in comp]
            if len(comp)<7 or (max(ys)-min(ys)<3 and max(xs)-min(xs)>12):
                for xx,yy in comp: p[xx,yy]=(0,0,0,0)
            else: components.append(comp)
    # A neighbouring pose's severed arm, face or slash must never become part
    # of this fighter. Detached projectiles are rendered by the combat system.
    if components:
        # Prefer the dark character outline over a larger detached bright spell.
        body=max(components,key=lambda comp: sum(max(p[x,y][:3])<165 for x,y in comp))
        bx0=min(x for x,y in body);bx1=max(x for x,y in body)
        by0=min(y for x,y in body);by1=max(y for x,y in body)
        for comp in components:
            if comp is body: continue
            x0=min(x for x,y in comp);x1=max(x for x,y in comp)
            y0=min(y for x,y in comp);y1=max(y for x,y in comp)
            near=x1>=bx0-6 and x0<=bx1+6 and y1>=by0-16 and y0<=by1+16
            edge=x0==0 or x1==w-1 or y0==0
            if not near or edge:
                for x,y in comp:p[x,y]=(0,0,0,0)
    # Despill only exposed outline pixels; preserve purple costume/spell cores.
    edge=[]
    for y in range(1,h-1):
        for x in range(1,w-1):
            r,g,b,a=p[x,y]
            if a and r-g>35 and b-g>24 and any(p[nx,ny][3]==0 for nx,ny in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]):
                edge.append((x,y,(min(r,g+35),g,min(b,g+35),a)))
    for x,y,color in edge:p[x,y]=color
    return im


def prepare(im):
    bounds=im.getbbox()
    assert bounds, "Empty authored cell"
    # Body center: lower opaque pixels, avoiding a long sword or raised effect.
    pixels=im.load(); x0,y0,x1,y1=bounds
    feet=[x for y in range(max(y0,y1-8),y1) for x in range(x0,x1) if pixels[x,y][3]>128]
    cx=sorted(feet)[len(feet)//2]
    return im, (cx,y1)


def export(char, spec, data, apply):
    board,offset,scale,regions=spec
    src=Image.open(SOURCE/board)
    prepared={}; retained={}; rejected={}
    for name,cells in regions.items():
        prepared[name]=[];retained[name]=[];rejected[name]=[]
        for index,(a,b,c,d) in enumerate(cells):
            im=key_cell(src.crop((a+offset,b,c+offset,d)),char in ("demon","tang"))
            box=im.getbbox()
            px=im.load()
            def body_pixel(x,y):
                r,g,b,alpha=px[x,y]
                return alpha>128 and max(r,g,b)<165
            # Glowing slash tips can touch the source divider. Reject a severed
            # dark body/hair region rather than interpreting glow as anatomy.
            cut_body=any(sum(body_pixel(x,y) for y in range(im.height))>=5 for x in (0,im.width-1))
            cut_head=sum(body_pixel(x,0) for x in range(im.width))>=5
            if not box or cut_body or cut_head:
                rejected[name].append(index)
                continue
            prepared[name].append(prepare(im));retained[name].append(index)
        if not prepared[name]:
            raise ValueError(f"{char}.{name}: every cell touches a cut edge; author new bounds")
    # The elder/beast KO strips join multiple bodies along one opaque floor.
    # Animate a complete hurt pose falling, instead of displaying that composite.
    if char in ("elder","beast"):
        base=prepared["hurt"][0][0]
        base=base.crop(base.getbbox())
        prepared["ko"]=[prepare(base.rotate(angle,resample=Image.Resampling.NEAREST,expand=True)) for angle in (0,25,55,80,90,90)]
        retained["ko"]=list(range(6))
    # One source-pixel canvas and common foot anchor across all cycles.
    extent=max(max(p[0],im.width-p[0],p[1],im.height-p[1]) for poses in prepared.values() for im,p in poses)
    side=2*(extent+6); pivot=(side//2,side-6)
    atlas={"frames":{},"animations":{},"effects":{},"formatVersion":2}
    out=DEST/char if apply else REVIEW/char
    out.mkdir(parents=True,exist_ok=True)
    contact=Image.new("RGB",(10*116,len(data["animations"])*104),(27,34,46)); draw=ImageDraw.Draw(contact)
    provenance={}
    for rowindex,(anim,config) in enumerate(data["animations"].items()):
        source_name="win" if anim=="skill3" else anim
        poses=prepared[source_name]; names=[]; selected=[]
        for index in range(config["frames"]):
            pick=round(index*(len(poses)-1)/max(1,config["frames"]-1))
            im,p=poses[pick]; canvas=Image.new("RGBA",(side,side))
            canvas.paste(im,(pivot[0]-p[0],pivot[1]-p[1]))
            name=f"{anim}_{index+1}"; image=f"{char}_clean_{name}"
            canvas.save(out/(image+".png"))
            atlas["frames"][name]={"image":image,"rect":{"x":0,"y":0,"w":side,"h":side},"pivot":list(pivot),"scale":scale}
            names.append(name);selected.append(pick)
            # Preview at game scale with common baseline, never stretch each cell.
            thumb=canvas.resize((round(side*scale),round(side*scale)),Image.Resampling.NEAREST)
            x=index*116+58-round(pivot[0]*scale); y=rowindex*104+87-round(pivot[1]*scale)
            contact.paste(thumb,(x,y),thumb)
            draw.line((index*116,rowindex*104+87,index*116+115,rowindex*104+87),fill=(65,86,110))
            draw.text((index*116+3,rowindex*104+90),f"{anim} {index+1}/{pick+1}",fill="white")
        atlas["animations"][anim]=names
        provenance[anim]={"sourceCells":regions[source_name],"sourcePoseIndices":[retained[source_name][i] for i in selected],"rejectedCutCells":rejected[source_name]}
        if char in ("elder","beast") and anim=="ko":
            provenance[anim]["derivedMotion"]="Complete hurt pose rotated through 0,25,55,80,90,90 degrees; source KO strip is not separable."
    (out/f"{char}_atlas.json").write_text(json.dumps(atlas,indent=2)+"\n")
    contact.save(REVIEW/f"{char}-contact.png")
    (REVIEW/f"{char}-sources.json").write_text(json.dumps(provenance,indent=2)+"\n")
    print(f"{char}: {len(atlas['frames'])} runtime frames; {sum(map(len,regions.values()))} source poses; canvas {side}px")


if __name__=="__main__":
    parser=argparse.ArgumentParser();parser.add_argument("--apply",action="store_true");parser.add_argument("--character")
    args=parser.parse_args();REVIEW.mkdir(exist_ok=True)
    chars=json.loads((ROOT/"SwordDuel/Data/Characters.json").read_text())
    for char in chars:
        if char["id"] in SPECS and (not args.character or char["id"]==args.character):
            export(char["id"],SPECS[char["id"]],char,args.apply)
