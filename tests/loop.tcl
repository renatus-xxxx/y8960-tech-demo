set renderer none
set sound_driver null
set throttle off
set save_settings_on_exit false
set out $::env(OPENMSX_HOME)
proc phase_is {n} {
 if {[debug read memory 0xc104] != $n} {
  set f [open "$::out/FAIL.txt" w];puts $f "Automatic phase mismatch: expected $n";close $f;exit
 }
}
after time 9 {phase_is 0}
after time 18 {phase_is 1}
after time 26 {phase_is 2}
after time 34 {phase_is 3}
after time 42 {phase_is 0;set f [open "$::out/PASS.txt" w];puts $f "PASS: automatic 0-1-2-3-0 loop";close $f;exit}
