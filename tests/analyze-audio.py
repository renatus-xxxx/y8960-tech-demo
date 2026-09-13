"""Measure emulator WAV output; no external Python dependencies."""
import array, json, math, pathlib, sys, wave
root=pathlib.Path(sys.argv[1]); results={}
for name in ['section-1','section-2','section-3','section-4','muted','stopped']:
    with wave.open(str(root/(name+'.wav')),'rb') as w:
        assert w.getsampwidth()==2
        channels=w.getnchannels(); rate=w.getframerate()
        a=array.array('h',w.readframes(w.getnframes()))
    if sys.byteorder!='little': a.byteswap()
    # Exclude switching/release tails from silence measurements.
    if name in ('muted','stopped'): a=a[len(a)//2:]
    rms=math.sqrt(sum(float(x)*x for x in a)/len(a))
    peak=max(abs(x) for x in a)
    clip=sum(abs(x)>=32760 for x in a)/len(a)
    side=math.sqrt(sum(float(a[i]-a[i+1])**2 for i in range(0,len(a)-1,2))/(len(a)//2)) if channels==2 else 0
    results[name]={'rate':rate,'channels':channels,'rms':round(rms,2),'peak':peak,'clippedFraction':clip,'stereoDifferenceRms':round(side,2)}
    if name.startswith('section'):
        assert rms>20, (name,'silent',rms)
        assert clip<0.001, (name,'clipping',clip)
    else: assert rms<3,(name,'not silent',rms)
assert results['section-2']['stereoDifferenceRms']>10,'Stereo effect missing'
(root/'audio-results.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8')
print(json.dumps(results,indent=2));print('PASS: audio energy, clipping, stereo, mute/stop')
