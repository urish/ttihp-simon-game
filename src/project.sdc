# Ring oscillator clock
set rosc_clock_name "clk_ring_osc"
set rosc_freq_mhz 700
set rosc_clock_net [get_nets $rosc_clock_name]
set rosc_pin [get_pins -of_objects $rosc_clock_net -filter "direction==output"]
puts "\[INFO] Using ring oscillator clock $rosc_clock_name"
create_clock $rosc_pin -name $rosc_clock_name -period [expr 1000 / $rosc_freq_mhz]

# print the names of all nets:
puts "\[INFO] Generating clock divider stages"
set divider_stages 13
set prev_stage_clk_pin $rosc_pin
set divider_clock_groups [list]
for {set i 0} {$i < $divider_stages - 1} {incr i} {
    set net_name "ring_osc.divider\[$i]"
    set net [get_nets $net_name]
    set clk_pin [get_pins -of_objects $net -filter "direction==output"]
    create_generated_clock -name $net_name -source $prev_stage_clk_pin -divide_by 2 $clk_pin
    puts "\[INFO] -> Created clock $net_name"
    set divider_clock_groups [lappend divider_clocks -group $net_name]
    set prev_stage_clk_pin $clk_pin
}

# Main clock
set clock_name "clk_simon"
set clock_net [get_nets $clock_name]
set port_args [get_pins -of_objects $clock_net -filter "direction==output"]
puts "\[INFO] Using clock $clock_name"
create_clock {*}$port_args -name $clock_name -period $::env(CLOCK_PERIOD)

set_clock_groups -asynchronous -group [get_clocks $rosc_clock_name] -group [get_clocks $clock_name] {*}$divider_clock_groups

set input_delay_value [expr $::env(CLOCK_PERIOD) * $::env(IO_DELAY_CONSTRAINT) / 100]
set output_delay_value [expr $::env(CLOCK_PERIOD) * $::env(IO_DELAY_CONSTRAINT) / 100]
puts "\[INFO] Setting output delay to: $output_delay_value"
puts "\[INFO] Setting input delay to: $input_delay_value"

set_max_fanout $::env(MAX_FANOUT_CONSTRAINT) [current_design]
if { [info exists ::env(MAX_TRANSITION_CONSTRAINT)] } {
    set_max_transition $::env(MAX_TRANSITION_CONSTRAINT) [current_design]
}
if { [info exists ::env(MAX_CAPACITANCE_CONSTRAINT)] } {
    set_max_capacitance $::env(MAX_CAPACITANCE_CONSTRAINT) [current_design]
} 

set clk_input [get_pins -of_objects $clock_net -filter "direction==output"]
set clk_indx [lsearch [all_inputs] $clk_input]
set all_inputs_wo_clk [lreplace [all_inputs] $clk_indx $clk_indx ""]

#set rst_input [get_port resetn]
#set rst_indx [lsearch [all_inputs] $rst_input]
#set all_inputs_wo_clk_rst [lreplace $all_inputs_wo_clk $rst_indx $rst_indx ""]
set all_inputs_wo_clk_rst $all_inputs_wo_clk

# correct resetn
set clocks [get_clocks $clock_name]

set_input_delay $input_delay_value -clock $clocks $all_inputs_wo_clk_rst
set_output_delay $output_delay_value -clock $clocks [all_outputs]

if { ![info exists ::env(SYNTH_CLK_DRIVING_CELL)] } {
    set ::env(SYNTH_CLK_DRIVING_CELL) $::env(SYNTH_DRIVING_CELL)
}

set_driving_cell \
    -lib_cell [lindex [split $::env(SYNTH_DRIVING_CELL) "/"] 0] \
    -pin [lindex [split $::env(SYNTH_DRIVING_CELL) "/"] 1] \
    $all_inputs_wo_clk_rst

#set_driving_cell \
#    -lib_cell [lindex [split $::env(SYNTH_CLK_DRIVING_CELL) "/"] 0] \
#    -pin [lindex [split $::env(SYNTH_CLK_DRIVING_CELL) "/"] 1] \
#    $clk_input

set cap_load [expr $::env(OUTPUT_CAP_LOAD) / 1000.0]
puts "\[INFO] Setting load to: $cap_load"
set_load $cap_load [all_outputs]

puts "\[INFO] Setting clock uncertainty to: $::env(CLOCK_UNCERTAINTY_CONSTRAINT)"
set_clock_uncertainty $::env(CLOCK_UNCERTAINTY_CONSTRAINT) $clocks

puts "\[INFO] Setting clock transition to: $::env(CLOCK_TRANSITION_CONSTRAINT)"
set_clock_transition $::env(CLOCK_TRANSITION_CONSTRAINT) $clocks

puts "\[INFO] Setting timing derate to: $::env(TIME_DERATING_CONSTRAINT)%"
set_timing_derate -early [expr 1-[expr $::env(TIME_DERATING_CONSTRAINT) / 100]]
set_timing_derate -late [expr 1+[expr $::env(TIME_DERATING_CONSTRAINT) / 100]]

if { [info exists ::env(OPENLANE_SDC_IDEAL_CLOCKS)] && $::env(OPENLANE_SDC_IDEAL_CLOCKS) } {
    unset_propagated_clock [all_clocks]
} else {
    set_propagated_clock [all_clocks]
}
