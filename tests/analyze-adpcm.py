"""Check generated ADPCM RAM and isolated ADPCM PCM, using standard Python."""
from pathlib import Path
import array,hashlib,json,math,re,sys,wave
root=Path(__file__).resolve().parents[1];work=Path(sys.argv[1])
s=(root/'src/assets.h').read_text()
expected=bytes(map(int,re.search(r'drum_data\[\]=\{(.*?)\};',s,re.S)[1].replace('\n','').split(',')))
actual=(work/'sample-ram.bin').read_bytes()
if actual!=expected:raise ValueError('ADPCM RAM differs from generated sample data')
with wave.open(str(work/'adpcm-solo.wav'),'rb') as w:
 if w.getsampwidth()!=2:raise ValueError('Expected 16-bit PCM')
 rate=w.getframerate();frames=w.getnframes();pcm=array.array('h',w.readframes(frames))
if sys.byteorder!='little':pcm.byteswap()
if frames/rate<5:raise ValueError('Recording too short')
rms=math.sqrt(sum(x*x for x in pcm)/len(pcm));peak=max(abs(x) for x in pcm)
if rms<10 or peak<100:raise ValueError('Isolated ADPCM voice missing')
if any(abs(x)>=32760 for x in pcm):raise ValueError('Clipping in isolated ADPCM')
d={'status':'PASS','ramMatches':True,'bytes':len(actual),'rms':round(rms,2),'peak':peak,'romSha256':hashlib.sha256((root/'demo/Y8960-DEMO.rom').read_bytes()).hexdigest()}
(work/'adpcm-results.json').write_text(json.dumps(d,indent=2)+'\n');print(json.dumps(d,indent=2))
