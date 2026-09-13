"""Original score and synthesized percussion. Python 3, no packages required."""
from pathlib import Path
import math, random, json, hashlib
root=Path(__file__).resolve().parents[1]
random.seed(8960)
def array(name,data,kind='unsigned char'):
    return 'static const '+kind+' '+name+'[]={\n'+',\n'.join(','.join(str(x) for x in data[i:i+24]) for i in range(0,len(data),24))+'\n};\n'
# D minor, Bb, G minor, A: four original two-bar phrases, eighth-note grid.
phrases=[
 [74,69,65,69,77,74,69,65, 76,72,69,72,74,69,65,69],
 [74,70,65,70,77,74,70,65, 72,69,65,69,70,65,62,65],
 [74,70,67,70,79,74,70,67, 77,74,70,74,76,72,69,72],
 [73,69,64,69,76,73,69,64, 77,76,73,69,74,0,69,0]]
melody=sum(phrases,[])
bass=[38,34,43,45]
assert all(n == 0 or 12 <= n < 96 for n in melody), "Melody/transposition outside pitch table"
assert all(0 <= b and b+31 < 96 for b in bass), "Bass/transposition outside pitch table"
psg=[]; fm=[]; opl=[]
for n in range(96):
    f=440*2**((n-69)/12)
    psg.append(min(4095,round(1789772.5/(16*f))))
    block=0; fn=round(f*2**19/49716)
    while fn>511: block+=1;fn=round(f*2**(19-block)/49716)
    fm.append(fn|(block<<9))
    block=0;fn=round(f*2**20/49716)
    while fn>1023: block+=1;fn=round(f*2**(20-block)/49716)
    opl.append(fn|(block<<10))
def encode(samples):
    acc=0;step=127; nib=[]
    factors=[57,57,57,57,77,102,128,153]
    for s in samples:
        d=s-acc; mag=min(7,int(abs(d)*4/step)); code=mag|(8 if d<0 else 0)
        acc=max(-32768,min(32767,acc+(-1 if code&8 else 1)*((2*mag+1)*step//8)))
        step=max(127,min(24576,step*factors[mag]//64));nib.append(code)
    return [(nib[i]<<4)|nib[i+1] for i in range(0,len(nib),2)]
drums=[]
for typ in range(2):
    pcm=[];phase=0
    for i in range(4096):
        t=i/11025
        if typ==0:
            phase+=2*math.pi*(48+95*math.exp(-t*38))/11025
            v=math.sin(phase)*math.exp(-t*19)+0.15*random.uniform(-1,1)*math.exp(-t*130)
        else:
            v=(0.72*random.uniform(-1,1)+0.28*math.sin(2*math.pi*185*t))*math.exp(-t*24)
        pcm.append(int(15000*v))
    drums+=encode(pcm)
out='/* Generated: original music (MIT), font by 1re1 (see third-party/fonts). Do not edit: scripts/generate-assets.py */\n'
# MSX 8x8 font by 1re1; see third-party/fonts/README.md for terms.
import re
asm=(root/'third-party/fonts/msx8x8-ascii.asm').read_text(encoding='utf-8-sig')
glyph={}
for section,base in [('PGT1',32),('PGT2',65)]:
    part=asm.split(section+':',1)[1].split('PGT2:',1)[0]
    for n,row in enumerate(re.findall(r'^\s*DB\s+([^;]+)',part,re.M)):
        values=[int(v,16) for v in re.findall(r'#([0-9A-Fa-f]{2})',row)]
        assert len(values)==8
        glyph[base+n]=values
out+=array('glyph_data',[v for code in range(32,91) for v in glyph[code]])
# Four-pixel foreground/shadow lookup; foreground always wins.
blend=[]
for fg in range(16):
    for sh in range(16):
        v=0
        for bit in (8,4,2,1): v=(v<<4)|(15 if fg&bit else 1 if sh&bit else 4)
        blend.append(v)
out+=array('font_blend',blend,'unsigned int')
for name,data,kind in [('melody',melody,'unsigned char'),('bass_notes',bass,'unsigned char'),('psg_period',psg,'unsigned int'),('fm_pitch',fm,'unsigned int'),('opl_pitch',opl,'unsigned int'),('drum_data',drums,'unsigned char')]:out+=array(name,data,kind)
(root/'src/assets.h').write_text(out,encoding='ascii')
print('Generated original 64-step score and 4096 ADPCM bytes.')

