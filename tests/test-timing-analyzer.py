"""Negative controls for analyze-timing.py. Pass a completed passing capture."""
import csv, json, shutil, subprocess, sys, tempfile, wave
from pathlib import Path

source=Path(sys.argv[1]).resolve()
analyzer=Path(__file__).with_name('analyze-timing.py')
def analyze(work, expected):
    p=subprocess.run([sys.executable,str(analyzer),str(work)],capture_output=True,text=True)
    result=json.loads((work/'timing-results.json').read_text())
    assert (p.returncode==0)==expected,(p.stdout,p.stderr)
    assert result['status']==('PASS' if expected else 'FAIL')
    return result
analyze(source,True)
with tempfile.TemporaryDirectory(prefix='y8960-timing-') as tmp:
    work=Path(tmp)
    for f in ['capture.json','CAPTURE.txt','record-start.txt','transitions.wav']:
        shutil.copyfile(source/f,work/f)
    original=list(csv.DictReader((source/'timing.csv').open()))
    def save(rows):
        with (work/'timing.csv').open('w',newline='') as f:
            w=csv.DictWriter(f,fieldnames=['time','tick','reg','value']);w.writeheader();w.writerows(rows)
    # Drop one complete lead note, keeping all other events and PCM unchanged.
    indexes=[i for i,r in enumerate(original) if r['reg']=='0']
    a,b=indexes[35],indexes[36]
    save(original[:a]+original[b:])
    result=analyze(work,False)
    assert any('sequence' in e for e in result['errors'])
    print('PASS: missing note rejected')
    # Delay one boundary note by 100 ms. No score or PCM changes.
    changed=[dict(r) for r in original]
    a,b=indexes[32],indexes[33]
    for r in changed[a:b]:r['time']=str(float(r['time'])+.1)
    save(changed)
    result=analyze(work,False)
    assert any('transition note delay' in e for e in result['errors'])
    print('PASS: 100 ms boundary delay rejected')
    # Keep I/O correct but insert 50 ms digital silence in boundary PCM.
    save(original)
    with wave.open(str(source/'transitions.wav'),'rb') as w:
        params=w.getparams();pcm=bytearray(w.readframes(w.getnframes()))
    t0=float(original[indexes[0]+2]['time'])
    start=float((source/'record-start.txt').read_text())
    t=t0+32*15*262*1368/(3579545*6)-start+.05
    a=round(t*params.framerate)*params.nchannels*2
    count=round(.05*params.framerate)*params.nchannels*2
    pcm[a:a+count]=bytes(count)
    with wave.open(str(work/'transitions.wav'),'wb') as w:
        w.setparams(params);w.writeframes(pcm)
    result=analyze(work,False)
    assert any('PCM silence' in e for e in result['errors'])
    print('PASS: 50 ms PCM dropout rejected')
    # Non-zero residual signal must fail the relative-level detector too.
    with wave.open(str(source/'transitions.wav'),'rb') as w:
        pcm=bytearray(w.readframes(w.getnframes()))
    pcm[a:a+count]=(20).to_bytes(2,'little',signed=True)*(count//2)
    with wave.open(str(work/'transitions.wav'),'wb') as w:
        w.setparams(params);w.writeframes(pcm)
    result=analyze(work,False)
    assert any('Relative PCM' in e for e in result['errors'])
    print('PASS: dropout with non-zero residual level rejected')
    shutil.copyfile(source/'transitions.wav',work/'transitions.wav')
    # Offset the recording timestamp without moving PCM. This must fail even
    # though the trace and note sequence remain unchanged.
    (work/'record-start.txt').write_text(str(start+.025))
    result=analyze(work,False)
    assert any('onset' in e for e in result['errors'])
    print('PASS: 25 ms recording clock mismatch rejected')
    shutil.copyfile(source/'record-start.txt',work/'record-start.txt')
    for key in ['romSha256','emulatorCommit','emulatorSha256','assetsSha256']:
        meta=json.loads((source/'capture.json').read_text(encoding='utf-8-sig'))
        meta[key]='invalid'
        (work/'capture.json').write_text(json.dumps(meta))
        p=subprocess.run([sys.executable,str(analyzer),str(work)],capture_output=True,text=True)
        assert p.returncode!=0 and 'identity mismatch' in p.stderr
        print('PASS: incorrect '+key+' rejected')
