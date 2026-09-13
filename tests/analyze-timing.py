"""Measure actual SSG lead writes and transition audio. Standard Python only.

Run after timing.tcl. No assertion depends on ROM-reported timing telemetry.
Pass applies to this score, pinned 60 Hz emulator, and observed run only.
"""
import array, csv, json, math, re, sys, wave, hashlib, statistics
from pathlib import Path

root = Path(__file__).resolve().parents[1]
work = Path(sys.argv[1])
capture=json.loads((work/'capture.json').read_text(encoding='utf-8-sig'))
manifest=json.loads((root/'config/versions.json').read_text())
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
checks=[(capture.get('romSha256'),sha(root/'demo/Y8960-DEMO.rom'),'captured ROM'),
        (capture.get('romSha256'),manifest['demo']['sha256'],'manifest ROM'),
        (capture.get('emulatorCommit'),manifest['emulator']['commit'],'emulator commit'),
        (capture.get('emulatorSha256'),manifest['emulator']['exeSha256'],'emulator binary'),
        (capture.get('assetsSha256'),sha(root/'src/assets.h'),'score assets')]
for got,expected,label in checks:
    if got!=expected: raise ValueError('Capture identity mismatch: '+label)
if not (work/'CAPTURE.txt').is_file(): raise ValueError('Capture did not complete')
assets = (root / 'src/assets.h').read_text()
def data(name):
    return list(map(int, re.search(r'\b'+name+r'\[\]=\{(.*?)\};', assets, re.S)[1].replace('\n','').split(',')))
melody, periods = data('melody'), data('psg_period')
rows = list(csv.DictReader((work / 'timing.csv').open()))
events, silence = [], []
low = high = 0
pending = None
off = None
for row in rows:
    t, tick, reg, value = float(row['time']), int(row['tick']), int(row['reg']), int(row['value'])
    if reg == 0:
        low = value
        pending = (t, tick)
    elif reg == 1:
        high = value
    elif reg == 8:
        if pending is not None:
            events.append({'time': t, 'tick': tick, 'period': low+256*high, 'volume':value})
            pending = None
        elif value == 0:
            # quiet(): not a scored rest, because no period pair preceded it.
            off = t
        if value and off is not None:
            silence.append({'time':off, 'seconds':t-off})
            off = None

errors=[]
if len(events)<257: errors.append('Fewer than two complete 128-step loops')
for i,e in enumerate(events):
    n=melody[i%64]
    if e['period']!=periods[n] or e['volume']!=(10 if n else 0):
        errors.append(f'Note sequence mismatch at event {i} (missed/duplicated/wrong note)')
        break
# C-BIOS is NTSC: use emulated frame duration, not exactly 1/60 second.
frame=262*1368/(3579545*6)
beat=15*frame
intervals=[events[i]['time']-events[i-1]['time'] for i in range(1,len(events))]
interval_error=max((abs(x-beat) for x in intervals),default=999)
drift=max((abs(e['time']-events[0]['time']-i*beat) for i,e in enumerate(events)),default=999)
boundaries=[i for i in range(32,len(events),32)]
transition_error=max((abs(intervals[i-1]-beat) for i in boundaries),default=999)
max_off=max((e['seconds'] for e in silence),default=0)
if interval_error>2*frame: errors.append('Note interval error exceeds two VBlanks')
if drift>2*frame: errors.append('Timeline drift exceeds two VBlanks')
if transition_error>frame: errors.append('Scene transition note delay exceeds one VBlank')
if max_off>0.010: errors.append('Unscored silence between quiet() and play() exceeds 10 ms')

# PCM check: this score starts each section with a non-rest lead. Examine the
# 150 ms after each expected boundary; fail on >=20 ms of near-digital silence.
# This supplements I/O timing, not a guarantee against every audible click.
start=float((work/'record-start.txt').read_text())
with wave.open(str(work/'transitions.wav'),'rb') as w:
    rate,channels=w.getframerate(),w.getnchannels()
    if w.getsampwidth()!=2: raise ValueError('Expected signed 16-bit PCM')
    pcm=array.array('h',w.readframes(w.getnframes()))
if sys.byteorder!='little': pcm.byteswap()
# Independently locate the first audible sample, allowing resampling latency.
# Capture starts before the initial quiet->play, when this score is silent.
first_audible=next((i//channels/rate for i in range(len(pcm)) if abs(pcm[i])>5),None)
expected_onset=events[0]['time']-start
onset_error=abs(first_audible-expected_onset) if first_audible is not None else 999
if onset_error>.005: errors.append('PCM onset does not align with I/O within 5 ms')
chunk=max(1,round(rate*.005))
max_silent=0
max_relative=0
for i in boundaries:
    first=round((events[0]['time']+i*beat-start)*rate)
    # Reference is the non-rest portion after this boundary, not the previous rest.
    ref=[]
    for a in range(first+round(rate*.02),first+round(rate*.23),chunk):
        q=pcm[max(0,a)*channels:(a+chunk)*channels]
        if q: ref.append(math.sqrt(sum(x*x for x in q)/len(q)))
    reference=statistics.median(ref) if ref else 0
    run=relative_run=0
    for a in range(first,first+round(rate*.15),chunk):
        block=pcm[max(0,a)*channels:(a+chunk)*channels]
        if len(block)!=chunk*channels:
            errors.append('PCM does not cover a transition');break
        rms=math.sqrt(sum(x*x for x in block)/len(block))
        run=run+1 if rms<1 else 0
        max_silent=max(max_silent,run*chunk/rate)
        relative_run=relative_run+1 if rms<max(1,reference*.1) else 0
        max_relative=max(max_relative,relative_run*chunk/rate)
if max_silent>=.020: errors.append('Unexpected PCM silence >=20 ms after a scene boundary')
if max_relative>=.020: errors.append('Relative PCM level below 10% for >=20 ms')
result={'status':'FAIL' if errors else 'PASS','events':len(events),'boundaries':len(boundaries),
 'romSha256':capture['romSha256'],
 'expectedStepMs':round(beat*1000,3),'maxIntervalErrorMs':round(interval_error*1000,3),
 'maxTimelineDriftMs':round(drift*1000,3),'maxTransitionErrorMs':round(transition_error*1000,3),
 'maxQuietToPlayMs':round(max_off*1000,3),'maxTransitionPcmSilenceMs':round(max_silent*1000,3),
 'pcmOnsetErrorMs':round(onset_error*1000,3),'maxRelativeDropoutMs':round(max_relative*1000,3),
 'thresholdsMs':{'interval':round(2*frame*1000,3),'drift':round(2*frame*1000,3),
 'transition':round(frame*1000,3),'quietToPlay':10,'pcmSilence':20},'errors':errors}
(work/'timing-results.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
sys.exit(bool(errors))
