"""Compare SCREEN 5 VRAM with the credited font, including 1px shadow."""
from pathlib import Path
import re,sys
root=Path(__file__).resolve().parents[1]
asm=(root/'third-party/fonts/msx8x8-ascii.asm').read_text(encoding='utf-8-sig')
glyph={}
for label,base in [('PGT1',32),('PGT2',65)]:
 for i,row in enumerate(re.findall(r'^\s*DB\s+([^;]+)',asm.split(label+':',1)[1].split('PGT2:',1)[0],re.M)):
  glyph[chr(base+i)]=[int(v,16) for v in re.findall(r'#([0-9a-fA-F]{2})',row)]
raw=Path(sys.argv[1]).read_bytes();assert len(raw)==27136
pixels=[c for b in raw for c in (b>>4,b&15)]
lines=[(8,1,'Y8960 TECH DEMO'),(8,3,'SILICON SYMPHONY'),(2,5,'04  PULSE / FULL ENSEMBLE'),(2,7,'OPL2 BASS + ADPCM PERCUSSION'),(4,10,'LE EC BA F0 F1 OP KI SN'),(4,17,'01 02 03 04 05 06 07 08'),(2,20,'PLAYING'),(2,22,'SPACE PAUSE   M MUTE   R RESET'),(2,24,'1-4 SCENES             ESC END')]
for x,y,text in lines:
 expected=[4]*(256*9)
 for dx,dy,color in [(1,1,1),(0,0,15)]:
  for i,ch in enumerate(text):
   for row,bits in enumerate(glyph[ch]):
    for b in range(8):
     px=x*8+i*8+b+dx
     if bits&(128>>b) and px<256:expected[(row+dy)*256+px]=color
 actual=pixels[y*8*256:(y*8+9)*256]
 assert actual==expected, f'Font/shadow mismatch: {text}; {sum(a!=b for a,b in zip(actual,expected))} pixels'
assert pixels[0]==4,'Non-black background missing'
print('PASS: nine text lines match 1re1 font and 1px shadow; background index 4')

# Sprite data is independent of the text bitmap. Reject the old bitmap bars.
for y in range(96,128):
 assert all(pixels[y*256+x]==4 for x in range(32,216)), 'Bitmap bars remain'
sprites=Path(sys.argv[1]).with_name('sprites.bin').read_bytes()
regs=Path(sys.argv[1]).with_name('vdp-regs.bin').read_bytes()
assert len(sprites)==1568
assert regs[5]==0xef and regs[6]==15 and regs[11]==0
assert regs[1]&3==2 and not regs[8]&2, '16x16 unmagnified sprites must be enabled'
for h in range(17):
 expected=bytes([255 if y>=16-h else 0 for y in range(16)])*2
 assert sprites[0x400+h*32:0x420+h*32]==expected, f'Sprite pattern height {h}'
for i in range(16):
 color=[7,5,10,15][(i//2)%4]
 assert sprites[i*16:(i+1)*16]==bytes([color])*16
 y,x,pattern,unused=sprites[0x200+i*4:0x204+i*4]
 assert (y,x)==(111 if i&1 else 95,32+(i//2)*24)
 assert pattern%4==0 and pattern<=64
assert any(sprites[0x202+i*8] or sprites[0x206+i*8] for i in range(8)), 'All meter bars are empty'
assert sprites[0x240]==216, 'Missing sprite list terminator'
print('PASS: 16 sprite attributes, 17 height patterns, colors and bitmap separation')
