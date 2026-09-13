/* Y8960 TECH DEMO - original music and visualization, MIT.
   C-BIOS MSX2+, demo in cartridge A, HRA_Y8960 in cartridge B (slot 2).
   Register behavior targets madscient/openMSX_Y8960 78469c4. */
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "assets.h"
typedef unsigned char u8;
typedef unsigned int u16;
__sfr __at(0x98) vd;
__sfr __at(0x99) vc;
static volatile u8 phase,muted,paused;
static u8 keys_old,numbers_old=255,vu[8];
static u16 step,clock;
static u8 pending_note=1;
static u8 shown_phase=255,shown_status=255,meter_index;
static const char *titles[]={"01  SEED / ELECTRIC MINIMAL","02  MIRROR / DUAL SSG","03  ALLOY / DUAL FM","04  PULSE / FULL ENSEMBLE"};
static void screen(void) __naked {
#asm
    ld a,5
    call 005fh
    ret
#endasm
}
static u16 ticks(void) __naked {
#asm
    di
    ld hl,(0fc9eh)
    ei
    ret
#endasm
}
/* WRTSLT executes the slot operation in BIOS, never remaps executing ROM. */
static void enable_y8960(void) __naked {
#asm
    ld a,2
    ld hl,07ff6h
    ld e,3
    call 0014h
    ld a,2
    ld hl,07fffh
    ld e,09fh
    call 0014h
    ei
    ret
#endasm
}
static void reg(u8 r,u8 v){
#asm
    di
#endasm
    vc=v;vc=128|r;
#asm
    ei
#endasm
}
/* SCREEN 5 page 0. C200-C27F is a reserved scanline buffer, outside BSS
   and the C100-C107 test mailbox; no heap is used. */
#define ROW ((u8*)0xc200)
static void addr(u16 a){reg(14,a>>14);
#asm
    di
#endasm
    vc=a;vc=64|((a>>8)&63);
#asm
    ei
#endasm
}
static void ready(void){u8 busy;do{
#asm
    di
#endasm
    vc=2;vc=143;busy=inp(0x99)&1;vc=0;vc=143;
#asm
    ei
#endasm
 }while(busy);}
/* HMMV: x and width are even; SCREEN 5 packs two pixels per byte. */
static void rect(u16 x,u16 y,u16 w,u16 h,u8 c){if(!w || !h)return;ready();
#asm
    di
#endasm
 vc=36;vc=145;
 outp(0x9b,x);outp(0x9b,x>>8);outp(0x9b,y);outp(0x9b,y>>8);
 outp(0x9b,w);outp(0x9b,w>>8);outp(0x9b,h);outp(0x9b,h>>8);
 outp(0x9b,c|(c<<4));outp(0x9b,0);outp(0x9b,0xc0);
#asm
    ei
#endasm
 ready();}
/* Each call owns a full-width, nine-pixel-high line. Two nibble
   lookups blend foreground over shadow; carry handles adjacent glyphs. */
static void blitrow(void) __naked {
#asm
 ld hl,0c200h
 ld bc,08098h
 otir
 ret
#endasm
}
static void text(u8 x,u8 y,const char*s){u8 row,i,col,fg,sh,carry,ch;u16 off,v;const char*t;
 ready();for(row=0;row<9;row++){
  memset(ROW,0x44,128);
  t=s;col=x*4;carry=0;
  while(*t && col<128){ch=*t++;if(ch<32||ch>90)ch=32;off=(u16)(ch-32)*8;
   fg=row<8?glyph_data[off+row]:0;sh=row?glyph_data[off+row-1]:0;
   i=sh;sh=(sh>>1)|carry;carry=(i&1)?128:0;
   v=font_blend[(fg&0xf0)|(sh>>4)];ROW[col++]=v>>8;ROW[col++]=v;
   v=font_blend[((fg&15)<<4)|(sh&15)];ROW[col++]=v>>8;ROW[col++]=v;
  }
  if(carry && col<128)ROW[col]=0x14;
  addr(((u16)y*8+row)*128);blitrow();
 }
}
static void ssg(u8 r,u8 v){
#asm
    di
#endasm
    outp(0xa0,r);outp(0xa1,v);
#asm
    ei
#endasm
}
static void fm(u8 unit,u8 r,u8 v){
#asm
    di
#endasm
    outp(unit?0x7a:0x7c,r);outp(unit?0x7b:0x7d,v);
#asm
    ei
#endasm
}
static void opl(u8 unit,u8 r,u8 v){
#asm
    di
#endasm
    outp(unit?0xc2:0xc0,r);outp(unit?0xc3:0xc1,v);
#asm
    ei
#endasm
}
static void quiet(void){u8 u,c;for(u=0;u<2;u++){for(c=0;c<3;c++)ssg(u*32+8+c,0);for(c=0;c<9;c++){fm(u,0x20+c,0);opl(u,0xb0+c,0);}opl(u,7,0);}for(c=0;c<8;c++)vu[c]=0;}
static void note_ssg(u8 unit,u8 ch,u8 n,u8 volume){u16 p=psg_period[n];u8 b=unit*32;ssg(b+ch*2,p);ssg(b+ch*2+1,p>>8);ssg(b+8+ch,n?volume:0);}
static void note_fm(u8 unit,u8 ch,u8 n,u8 ins,u8 volume){u16 p=fm_pitch[n];fm(unit,0x20+ch,0);fm(unit,0x30+ch,ins*16+volume);fm(unit,0x10+ch,p);fm(unit,0x20+ch,(p>>8)|(n?0x10:0));}
static void drum(u8 unit){u16 start=unit?512:0;opl(unit,7,0);opl(unit,9,start);opl(unit,10,start>>8);start+=511;opl(unit,11,start);opl(unit,12,start>>8);opl(unit,0x10,0xc5);opl(unit,0x11,0x38);opl(unit,0x12,175);opl(unit,7,0xa0);}
static void audio_init(void){u16 i;u8 u;
 enable_y8960();quiet();
 outp(0xb0,0x55);*((volatile u8*)0xc107)=inp(0xb0);
 for(u=0;u<2;u++){ssg(u*32+7,0xb8);ssg(u*32+0x10,u?13:2);ssg(u*32+0x11,u?11:4);ssg(u*32+0x12,8);}
 /* Upload two original synthesized percussion samples into shared ADPCM RAM. */
 opl(0,8,0);opl(0,9,0);opl(0,10,0);opl(0,11,0xff);opl(0,12,3);opl(0,7,0x60);
 for(i=0;i<4096;i++)opl(0,0x0f,drum_data[i]);opl(0,7,0);
 /* OPL2 bass: two operators, gentle FM and fast release. */
 opl(0,1,0x20);opl(0,0x20,1);opl(0,0x23,1);opl(0,0x40,0x25);opl(0,0x43,0x12);
 opl(0,0x60,0xf2);opl(0,0x63,0xf2);opl(0,0x80,0x85);opl(0,0x83,0x85);opl(0,0xc0,2);
}
static void play(void){u8 n=melody[step&63],b=bass_notes[(step>>4)&3];u16 p;
 if(muted)return;
 note_ssg(0,0,n,10);vu[0]=n?12:0;
 if(phase>=1){note_ssg(1,0,melody[(step+60)&63],8);note_ssg(0,1,b+12,7);vu[1]=10;vu[2]=8;}
 if(phase>=2){note_fm(0,0,n,3,6);note_fm(1,0,n?n-12:0,4,8);vu[3]=12;vu[4]=10;
  if(!(step&3)){note_fm(0,1,b+24,10,9);note_fm(1,1,b+31,10,10);}}
 if(phase==3){
  if(!(step&1)){p=opl_pitch[b];opl(0,0xb0,0);opl(0,0xa0,p);opl(0,0xb0,(p>>8)|32);vu[5]=12;}
  if(!(step&3)){drum((step&4)?1:0);vu[(step&4)?7:6]=14;}
 }
}
/* Cached captions: page 1, Y=256..383. Status rows: Y=384,400,416.
   Playback never composes glyphs. HMMM starts without waiting for completion. */
static u8 idle(void){u8 busy;
#asm
 di
#endasm
 vc=2;vc=143;busy=inp(0x99)&1;vc=0;vc=143;
#asm
 ei
#endasm
 return !busy;}
static void copy_band(u16 sy,u16 dy,u8 h){
#asm
 di
#endasm
 vc=32;vc=145;
 outp(0x9b,0);outp(0x9b,0);outp(0x9b,sy);outp(0x9b,sy>>8);
 outp(0x9b,0);outp(0x9b,0);outp(0x9b,dy);outp(0x9b,dy>>8);
 outp(0x9b,0);outp(0x9b,1);outp(0x9b,h);outp(0x9b,0);
 outp(0x9b,0);outp(0x9b,0);outp(0x9b,0xd0);
#asm
 ei
#endasm
}
static void cache_captions(void){u8 i,y;
 rect(0,256,256,176,4);
 for(i=0;i<4;i++){y=32+i*4;text(2,y,titles[i]);
  text(2,y+2,i==0?"ONE MOTIF / FOUR TRANSFORMS":i==1?"DUAL SSG / LEFT-RIGHT ECHO":i==2?"OPLL PAIR / LAYERED HARMONICS":"OPL2 BASS + ADPCM PERCUSSION");}
 text(2,48,"PLAYING");text(2,50,"MUTED");text(2,52,"PAUSED");
 ready();copy_band(256,40,32);ready();shown_phase=0;
}
/* Sprite mode 2: colour 7400, attributes 7600, patterns 7800.
   All fit below page-1 caption cache (8000). 17 bottom-aligned heights. */
static void meter_sprites_init(void){u8 h,y,i,c,r;
 ready();reg(5,0xef);reg(11,0);reg(6,15);
 r=(*((u8*)0xf3e0)|2)&0xfe;*((u8*)0xf3e0)=r;reg(1,r);
 addr(0x7800);for(h=0;h<=16;h++)for(i=0;i<2;i++)for(y=0;y<16;y++)vd=y>=16-h?255:0;
 addr(0x7400);for(i=0;i<16;i++){c=(i/2&3)==0?7:(i/2&3)==1?5:(i/2&3)==2?10:15;for(y=0;y<16;y++)vd=c;}
 addr(0x7600);for(i=0;i<16;i++){vd=(i&1)?111:95;vd=32+(i/2)*24;vd=0;vd=0;}vd=216;
}
static void meter_sprite(u8 i,u8 h){
 addr(0x7602+(u16)i*8);vd=(h>16?h-16:0)*4;
 addr(0x7606+(u16)i*8);vd=(h>16?16:h)*4;
}
static void ui_init(void){u8 i;static const u8 colors[]={
 0x00,0, 0x01,1, 0x24,5, 0x36,6, 0x13,2, 0x27,4, 0x64,3, 0x27,7,
 0x74,3, 0x76,5, 0x72,6, 0x75,7, 0x13,4, 0x65,4, 0x56,6, 0x77,7};
 screen();reg(7,4);reg(9,0x80);reg(16,0);
 for(i=0;i<32;i++)outp(0x9a,colors[i]);
 rect(0,0,256,212,4);
 text(8,1,"Y8960 TECH DEMO");text(8,3,"SILICON SYMPHONY");
 text(4,10,"LE EC BA F0 F1 OP KI SN");text(4,17,"01 02 03 04 05 06 07 08");
 text(2,22,"SPACE PAUSE   M MUTE   R RESET");text(2,24,"1-4 SCENES             ESC END");cache_captions();meter_sprites_init();}
/* At most one small visual job per loop. Busy VDP or imminent note:
   skip visuals instead of making playback wait. Eight bars rotate over frames. */
static void draw_slice(void){u8 i,h,status;
 if((!paused && clock>=14) || !idle())return;
 if(shown_phase!=phase){copy_band(256+(u16)phase*32,40,32);shown_phase=phase;return;}
 status=paused?2:muted?1:0;
 if(shown_status!=status){copy_band(384+(u16)status*16,160,9);shown_status=status;return;}
 i=meter_index++;if(meter_index==9)meter_index=0;
 if(i<8){h=vu[i]*2;meter_sprite(i,h);
  if(vu[i])--vu[i];
 }else{rect(24,150,208,3,1);rect(24,150,((step&31)+1)*6,3,7);}
}
static u8 keyrow(u8 row){u8 a,v;
#asm
    di
#endasm
 a=inp(0xaa);outp(0xaa,(a&0xf0)|row);v=inp(0xa9);outp(0xaa,a);
#asm
    ei
#endasm
 return v;}
int main(void){u8 k,oldphase=255,reset_time;u16 now,last,elapsed;audio_init();ui_init();last=ticks();*((volatile u16*)0xc100)=0x8960;
 while(1){
#asm
    halt
#endasm
  now=ticks();elapsed=now-last;last=now;reset_time=0;
  k=0;if(!(keyrow(8)&1))k|=1;if(!(keyrow(4)&4))k|=2;if(!(keyrow(4)&128))k|=4;
  if((k&1)&&!(keys_old&1)){paused^=1;reset_time=1;if(paused)quiet();else pending_note=1;}
  if((k&2)&&!(keys_old&2)){muted^=1;if(muted)quiet();else pending_note=1;}
  if((k&4)&&!(keys_old&4)){step=0;clock=0;reset_time=1;pending_note=1;quiet();}
  keys_old=k;
  if(!(keyrow(7)&4)){quiet();text(5,7,"STOPPED - CLOSE WINDOW");*((volatile u8*)0xc106)=1;for(;;){}}
  k=keyrow(0);if(!(k&2)&&(numbers_old&2)){step=0;clock=0;reset_time=1;pending_note=1;}else if(!(k&4)&&(numbers_old&4)){step=32;clock=0;reset_time=1;pending_note=1;}else if(!(k&8)&&(numbers_old&8)){step=64;clock=0;reset_time=1;pending_note=1;}else if(!(k&16)&&(numbers_old&16)){step=96;clock=0;reset_time=1;pending_note=1;}numbers_old=k;
  if(!paused){if(!reset_time)clock+=elapsed;while(clock>=15){clock-=15;step=(step+1)&127;pending_note=1;}}
  phase=step>>5;if(phase!=oldphase){quiet();oldphase=phase;}
  if(!paused && pending_note){play();pending_note=0;}
  draw_slice();
  *((volatile u16*)0xc102)=step;*((volatile u8*)0xc104)=phase;
  *((volatile u8*)0xc105)=muted;
  if(paused)*((volatile u8*)0xc105)|=2;
 }
}
