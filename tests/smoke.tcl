set renderer none
set sound_driver null
set throttle off
set save_settings_on_exit false
proc check {} {
 if {[debug read memory 0xc100] != 0x60 || [debug read memory 0xc101] != 0x89} {error "Demo did not initialize"}
 if {[debug read memory 0xc107] != 0x55} {error "Y8960 slot/I-O enable failed"}
 set devices [machine_info sounddevice]
 foreach name {{Y8960 SSGS} {Y8960 OPLL 0} {Y8960 OPLL 1} {Y8960 OPL2 0} {Y8960 OPL2 1}} {
  if {[lsearch -exact $devices $name] < 0} {error "Missing $name: $devices"}
 }
 set f [open "$::env(OPENMSX_HOME)/PASS.txt" w];puts $f "PASS: C-BIOS, demo ROM and Y8960 devices started";close $f
 exit
}
after time 8 {if {[catch {check} e]} {puts stderr $e;exit}}
