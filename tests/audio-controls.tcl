set renderer none
set sound_driver null
set throttle off
set save_settings_on_exit false
set master_volume 65
set mute off
set out $::env(OPENMSX_HOME)
proc fail {message} {set f [open "$::out/FAIL.txt" w];puts $f $message;close $f;puts stderr $message;exit}
proc require {value message} {if {!$value} {fail $message}}
proc press {row mask} {keymatrixdown $row $mask;after time 0.1 [list keymatrixup $row $mask]}
proc begin_section {n} {
 press 0 [expr {1<<$n}]
 after time 0.8 [list record_section $n]
}
proc record_section {n} {
 require [expr {[debug read memory 0xc104] == $n-1}] "Section selection failed: $n"
 record start -audioonly "$::out/section-$n.wav"
 after time 6 [list next_section $n]
}
proc next_section {n} {
 record stop
 if {$n<4} {begin_section [expr {$n+1}]} else {
  require [expr {[debug read {Y8960 OPL2 0 regs} 0x63] == 0xf2}] "OPL2 configuration missing"
  press 4 4
  after time 0.8 mute_record
 }
}
proc mute_record {} {
 require [expr {[debug read memory 0xc105]&1}] "M did not mute"
 record start -audioonly "$::out/muted.wav"
 after time 1 pause_check
}
proc pause_check {} {
 record stop
 press 8 1
 after time 0.8 {set ::step [debug read memory 0xc102];after time 1.5 paused_check}
}
proc paused_check {} {
 require [expr {[debug read memory 0xc105]&2}] "Space did not pause"
 require [expr {[debug read memory 0xc102] == $::step}] "Paused timeline advanced"
 press 8 1
 press 4 4
 after time 0.8 {press 4 128;after time 0.8 reset_check}
}
proc reset_check {} {
 require [expr {[debug read memory 0xc104] == 0}] "R did not restart"
 require [expr {[debug read memory 0xc105] == 0}] "Resume/unmute failed"
 press 7 4
 after time 0.8 {
  require [expr {[debug read memory 0xc106] == 1}] "Escape did not stop"
  record start -audioonly "$::out/stopped.wav"
  after time 1 {record stop;set f [open "$::out/PASS.txt" w];puts $f "PASS: sections 1-4, mute, pause/resume, restart, escape";close $f;exit}
 }
}
after time 8 {
 require [expr {[debug read memory 0xc100] == 0x60 && [debug read memory 0xc101] == 0x89}] "ROM did not start"
 require [expr {[debug read memory 0xc107] == 0x55}] "I/O enable failed"
 begin_section 1
}
