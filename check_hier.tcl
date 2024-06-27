 set report_directory [file join [pwd] "REPORTS_DIR"]
file mkdir $report_directory
 
set pins_report [file join $report_directory "pins_lists_og.rpt"]
set summary_rpt [file join $report_directory "Detail_warning_summary_new.rpt"]
 
##########################Creating HASH ###########################
set hash_table [dict create]
proc add_to_hash_table {pin reason} {
    global hash_table
        if {[dict exists $hash_table $pin]} {
            dict lappend hash_table $pin $reason
        } else {
            dict set hash_table $pin $reason 
        }
}
####################################################################
 
################Updating a hash with modified reason############
proc update_reason {pin new_reason} {
    global hash_table
        if {[dict exists $hash_table $pin]} {
            dict set hash_table $pin $new_reason
        } else {
#puts "PIN $pin not found in the hash table."
        }
}
################################################################
## Main Command Evaluation:
eval [check_timing -check_only clock_expected -verbose > $pins_report]
 
set inputFile $pins_report
set fileHandle [open $inputFile "r"]
set fileContent [read $fileHandle]
close $fileHandle
 
set inTimingCheckDetail 0
set pinNames {}
 
set lines [split $fileContent "\n"]
 
foreach line $lines {
#Worked with T..L
    if {[string match "TIMING CHECK DETAIL" $line]} {
        set inTimingCheckDetail 1
            continue
    }
## Tracking the pins with associated message
    if {$inTimingCheckDetail && [regexp {^\s*(\S+)\s+Clock not found where clock is expected} $line -> pin]} {
        lappend pinNames $pin
    }    
}
 
##Extracted Pin data stored in the pins variable
set pins $pinNames
 
##################MAIN PROC#########################################
 
 
proc main_part {pin_name} { ;#Pin name at every level
    set PROC_STATE 0
        set clock_names [list]
        set case_value_is [list]
        set disable_timing_is [list]
        set pin_value_clk_is [list]    
        set pin_value_case_is [list]
        set pin_value_dis_is [list]
        set clock_names_X [list]
        set case_value_is_X [list]
        set disable_timing_is_X [list]
        set pin_value_clk_is_X [list]    
        set pin_value_case_is_X [list]
        set pin_value_dis_is_X [list]
        set dis_list [list]
        set case_list [list]
        set dis_list_pin [list]
        set case_list_pin [list]
        set pin_val [get_pins $pin_name]
        set cell_val [get_cells -of_objects [get_pins $pin_val]]
        set pins_coll [get_pins -of_objects [get_cells $cell_val]]
        if {[string match "" [get_object_name [get_property [get_pins $pins_coll] clocks]]]} {
            set PROC_STATE 0
 
        } else {
            set PROC_STATE 1 
                foreach_in_collection ui $pins_coll {
                    if {[string match "" [get_object_name [get_property [get_pins $ui] clocks]]]} {
                    } else {
                        lappend clock_names [get_object_name [get_property [get_pins $ui] clocks]]
                            lappend pin_value_clk_is $ui
                    }
                }
 
            foreach_in_collection uic $pins_coll {
                set CASE_VALUE_CHECK [get_property $uic case_value]
                    if {$CASE_VALUE_CHECK eq "0" || $CASE_VALUE_CHECK eq "1"} {
                        lappend case_value_is $CASE_VALUE_CHECK
                            lappend pin_value_case_is $uic
                    } else {
                    }
            }
 
            foreach_in_collection uid $pins_coll {
                set DIS_VALUE_CHECK [get_property $uid is_disable_timing]
                    if {$DIS_VALUE_CHECK eq "true"} {
                        lappend disable_timing_is $DIS_VALUE_CHECK
                            lappend pin_value_dis_is $uid
                    } else {
                    }
            }
 
 
##additional variable to pass in return
            set clock_names_X $clock_names 
                set case_value_is_X $case_value_is
                set disable_timing_is_X $disable_timing_is
                set pin_value_clk_is_X $pin_value_clk_is 
                set pin_value_case_is_X $pin_value_case_is
                set pin_value_dis_is_X $pin_value_dis_is
                unset clock_names 
                unset case_value_is
                unset disable_timing_is 
                unset pin_value_clk_is     
                unset pin_value_case_is 
                unset pin_value_dis_is
 
        }
    return [list $PROC_STATE $clock_names_X $case_value_is_X $disable_timing_is_X $pin_value_clk_is_X $pin_value_case_is_X $pin_value_dis_is_X]
 
 
}
 
#####################################################################
set CURRENT_STATE 0 
if {$CURRENT_STATE == 0} {
set PORT_IS {}

    foreach pinss $pins { 
        set pinz [get_pins $pinss]
            set port [filter_collection [all_fanin -to [get_pins $pinz] -startpoints_only] "is_port==true"]
 
            if {[string match "" [get_object_name $port]]} {
                set flag_value 0
            } else {
                set flag_value 1
                    set PORT_IS $port
            }
 
        set port_clocks [get_object_name [get_property [get_ports $PORT_IS] clocks]]
            if {[string match "" $port_clocks] && $flag_value} {
                add_to_hash_table "[get_object_name $pinz]" "Port \"[get_object_name $PORT_IS]\" connected to the clk pin doesn't have a clock defined over it."
            } else {
                add_to_hash_table "[get_object_name $pinz]" "no_reason"
            }
    }
 
    set CURRENT_STATE 1
}
 
puts "CURRENT STATE IS $CURRENT_STATE"
 
if {$CURRENT_STATE == 1} {
 
    set desired_reason "no_reason"
        set no_reason_pins [list]
        foreach {pin reason} $hash_table {
            if {$reason eq $desired_reason} {
                lappend no_reason_pins $pin
            }
        }
 
    set CURRENT_STATE 2
}
 
puts "CURRENT STATE IS $CURRENT_STATE"
 
if {$CURRENT_STATE == 2} {
    foreach no_res_elements $no_reason_pins {
        set lev_val 20
            for {set i 0} {$i < $lev_val} {incr i} {
                set flag 0
                    set fanin_main_data [all_fanin -to $no_res_elements -levels $i]
 
                    if {[lindex [main_part $fanin_main_data] 0]} {
                        set flag 1
#################################################################################
 
                            set pins_coll_for_clock_cell [get_pins -of_objects [get_cells -of_objects [get_pins [get_object_name [lindex [main_part $fanin_main_data] 4]]]]]
                            foreach_in_collection fui $pins_coll_for_clock_cell {
 
                                set CASE_VALUE_CHECK_2 [get_property $fui case_value]
                                    if {$CASE_VALUE_CHECK_2 eq "0" || $CASE_VALUE_CHECK_2 eq "1"} {
                                        lappend case_list [get_property $fui case_value]
                                            lappend case_list_pin $fui
                                    }
 
                                set DIS_VALUE_CHECK_1 [get_property $fui is_disable_timing]
                                    if {$DIS_VALUE_CHECK_1 eq "true"} {
                                        lappend dis_list $DIS_VALUE_CHECK_1
                                            lappend  dis_list_pin $fui
                                    }
                            }
 
 
                        set reason_is "Clock \"[lindex [main_part $fanin_main_data] 1]\" present on the pin [get_object_name [lindex [main_part $fanin_main_data] 4]] of the cell \"[get_object_name [get_cells -of_objects [get_pins [get_object_name [lindex [main_part $fanin_main_data] 4]]]]]\" \
                            at cell level $i in the Fanin cone.Case value of \"$case_list\" present on the pin \"[get_object_name $case_list_pin]\" with disable timing seen on the pin \"[get_object_name
[9:04 PM, 6/21/2024] Mandar: $dis_list_pin]\""
                            update_reason $no_res_elements $reason_is
 
                            set dis_list []
                            set case_list []
                            set dis_list_pin []
                            set case_list_pin []
#################################################################################
 
                            if {$flag} {
                                break
                                    set flag 0 
                            } 
                    }
            }
    }    
}
 
###Checking PROC #########################
foreach item [dict keys $hash_table] {
    set value [dict get $hash_table $item]
#  puts "HASH VALUE [dict size $hash_table]"
# puts  "$item $value"
}
####################################################
 
################################################################
##Final Report Generation:
set report_file [open $summary_rpt "w"]
 
# Write the header to the report file
puts $report_file "###################################################################"
puts $report_file "#                                                                 #"
puts $report_file " No\tPIN_NAME\tREASON_FOR_CLOCK_UNREACHABLE"
puts $report_file "#                                                                 #"
puts $report_file "###################################################################"
 
 
set serial_no 1
dict for {pin reason} $hash_table {
    puts $report_file " $serial_no\t$pin \> \t\t\t$reason"
        puts $report_file ""
        incr serial_no
}
# Close the report file
close $report_file
puts "Report generated successfully!"
 
