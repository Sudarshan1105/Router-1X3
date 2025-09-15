echo "******************************************************************************************
      *                      #MINI_PROJECT (Router1x3 - Single_domain)                         *
      *                                                                                        *                                    
      *                                                                -By SUDARSHAN.R (PD-09) *
      ******************************************************************************************"

#-----------------------------------------------
# Setup and Read RTL
#-----------------------------------------------
source -echo ../Scripts/setup.tcl

create_lib -technology $TECH_FILE -ref_libs $REFERENCE_LIBRARY router.dlib
analyze -format verilog [glob ../Rtl/*.v]
elaborate router_top
set_top_module router_top


#-----------------------------------------------
# Technology Setup
#-----------------------------------------------
read_parasitic_tech -layermap ../Scripts/tech/saed32nm_tf_itf_tluplus.map \
    -tlup ../Scripts/tech/saed32nm_1p9m_Cmax.lv.nxtgrd -name maxTLU
read_parasitic_tech -layermap ../Scripts/tech/saed32nm_tf_itf_tluplus.map \
    -tlup ../Scripts/tech/saed32nm_1p9m_Cmin.lv.nxtgrd -name minTLU

#===============================================
#SDC
#===============================================
create_clock -name clk -period 2.5 [get_ports router_clock]

#-----------------------------------------------
# Load UPF
#-----------------------------------------------
load_upf ../Scripts/router1x3_SD.upf
commit_upf


#-----------------------------------------------
# MCMM Setup
#-----------------------------------------------
source -echo ../Scripts/MCMM/mcmm_risc_core.tcl
set_scenario_status -active true -dynamic_power true [get_scenarios func.ss_m40c]



# Routing layer setup
set_attribute [get_layers {M1 M3 M5 M7 M9}] routing_direction horizontal
set_attribute [get_layers {M2 M4 M6 M8}] routing_direction vertical
set_ignored_layers -max_routing_layer M8
report_ignored_layers
set_attribute [get_site_defs unit] is_default true

# Find available tie-cells
get_lib_cells -filter "function_id==a0.0"
get_lib_cells -filter "function_id==Ia0.0"

# Make tie-cells available to synthesis
set_dont_touch [get_lib_cells */TIE*] false
set_lib_cell_purpose -include optimization [get_lib_cells */TIE*]


#-----------------------------------------------
# Synthesis and Placement
#-----------------------------------------------

compile_fusion -from initial_map -to initial_map
compile_fusion -from logic_opto -to logic_opto




#-----------------------------------------------
# Floorplanning
#-----------------------------------------------
initialize_floorplan -core_utilization 0.6 -side_ratio {2 2} -core_offset {15}
set_block_pin_constraints -self -allowed_layers {M3 M4 M5 M6}
place_pins -self
shape_blocks

#create_voltage_area_shape -voltage_area PD_FIFO -region {{15.0000 15.0000} {127.0240 103.6720}}
create_voltage_area_shape -voltage_area PD_FIFO -region {{80.5290 80.2270} {146.0240 111.9760}}
#guard_band 0 1.672 0 0 
#{80.529 111.976} {80.529 80.227} {146.024 80.227} {146.024 111.976}

report_shaping_options
report_voltage_area
set compile.auto_floorplan.shape_voltage_areas auto
check_mv_design

#-----------------------------------------------
# Power Network Synthesis
#----------------------------------------------
remove_pg_strategies -all
remove_pg_patterns -all
remove_pg_regions -all
remove_pg_via_master_rules -all
remove_pg_strategy_via_rules -all
remove_routes -net_types {power ground} -ring -stripe -macro_pin_connect \
-lib_cell_pin_connect

connect_pg_net 

source -echo ../Scripts/pns.tcl

check_pg_drc
check_pg_connectivity
check_pg_missing_vias
analyze_rail
#=========================================
# Placement
#=========================================
compile_fusion -from initial_place -to initial_place

#=========================================
#Compile_fusion
#=========================================
compile_fusion -from initial_drc -to initial_drc

compile_fusion -from initial_opto -to initial_opto

compile_fusion -from final_place -to final_place

compile_fusion -from final_opto -to final_opto

#-----------------------------------------------
# Clock Tree Synthesis
#-----------------------------------------------



##Clock_tree_targets

set_clock_tree_options -target_skew 0.04 -corners [get_corners ss*]
set_clock_tree_options -target_skew 0.02 -corners [get_corners ff*]

## CTS Cell Selection

derive_clock_cell_references -output cts_leq_set.tcl > /dev/null

set CTS_CELLS [get_lib_cells "*/NBUFF*LVT */NBUFF*RVT */INVX*_LVT */INVX*_RVT */CGL* */LSUP* */*DFF*"]
set_dont_touch $CTS_CELLS false
set_lib_cell_purpose -exclude cts [get_lib_cells] 
set_lib_cell_purpose -include cts $CTS_CELLS

source ../Scripts/cts_include_refs.tcl

report_lib_cells -objects [get_lib_cells] -columns {name:20 valid_purposes dont_touch}

## CTS NDRs

source -echo ../Scripts/ndr.tcl
report_routing_rules -verbose
report_clock_routing_rules
set_app_options -name clock_opt.flow.enable_ccd -value true

set_clock_uncertainty 0.1 -setup [all_clocks]
set_clock_uncertainty 0.05 -hold [all_clocks]
set_max_transition 0.1 -clock_path [get_clocks] -corners [all_corners]
check_timing

clock_opt -to route_clock

report_clocks -skew
report_clock_routing_rules

#-----------------------------------------------
# Routing and Filler Cells
#-----------------------------------------------
source -echo ../../ref/tech/saed32nm_ant_1p9m.tcl

set_app_options -name route_opt.flow.enable_ccd -value true

route_auto -stop_after_track_assignment true
set SH_FILLERS [get_lib_cells "*/SHFILL128_HVT */SHFILL64_HVT */SHFILL3_HVT */SHFILL2_HVT */SHFILL1_HVT"]
create_stdcell_fillers -lib_cells $SH_FILLERS

check_routes
route_opt
check_lvs
report_timing
report_constraints -all_violators
save_block_as_routersignoff
# Exit
quit

