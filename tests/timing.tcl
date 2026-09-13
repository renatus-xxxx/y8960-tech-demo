# Observe real I/O writes, not a timing value reported by the ROM.
set renderer none
set sound_driver null
set throttle off
set save_settings_on_exit false
set master_volume 65
set mute off
set out $::env(OPENMSX_HOME)
set trace [open "$out/timing.csv" w]
puts $trace "time,tick,reg,value"
set selected 255
set recording 0
debug set_watchpoint write_io 0xa0 {} {set ::selected $::wp_last_value}
debug set_watchpoint write_io 0xa1 {} {
 if {[debug read memory 0xc100]==0x60 && [debug read memory 0xc101]==0x89} {
  if {!$::recording} {
   set ::recording 1
   set f [open "$::out/record-start.txt" w];puts $f [machine_info time];close $f
   record start -audioonly "$::out/transitions.wav"
   after time 70 {
    record stop;close $::trace
    set f [open "$::out/CAPTURE.txt" w];puts $f "70 seconds captured; run analyze-timing.py for PASS/FAIL";close $f
    exit
   }
  }
  if {$::selected==0 || $::selected==1 || $::selected==8} {
   set tick [expr {[debug read memory 0xfc9e]+256*[debug read memory 0xfc9f]}]
   puts $::trace "[machine_info time],$tick,$::selected,$::wp_last_value"
  }
 }
}
after time 100 {puts stderr "Timing capture timed out";exit 1}
