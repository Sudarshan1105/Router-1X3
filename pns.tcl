#REMOVE_ALL
remove_pg_strategies -all
remove_pg_patterns -all
remove_pg_regions -all
remove_pg_via_master_rules -all
remove_pg_strategy_via_rules -all
remove_routes -net_types {power ground} -ring -stripe -macro_pin_connect \
-lib_cell_pin_connect

connect_pg_net 
#==============================================
#POWER_RINGS
#==============================================
create_pg_ring_pattern ring_pattern \
   -horizontal_layer M7 -horizontal_width 2 -horizontal_spacing 2 \
   -vertical_layer M8 -vertical_width 2 -vertical_spacing 2 -corner_bridge true

set_pg_strategy core_ring \
   -pattern {{name: ring_pattern} {nets: {VDDH VDDL VSS}} {offset: {2 2}}} \
   -core -extension {{nets: {VDDH VDDL VSS}} {side: 1} {direction: b} {stop: design_boundary_and_generate_pin}} \
              
compile_pg -strategies core_ring

#======================================================
#POWER_RAIL
#======================================================
create_pg_std_cell_conn_pattern rail_pattern -layers M1

set_pg_strategy M1_rails -voltage_area DEFAULT_VA \
   -pattern {{name: rail_pattern}{nets: VDDH VSS}} \
   -blockage {{nets: VDDH VSS} {voltage_areas: PD_FIFO}} \
 

compile_pg -strategies M1_rails

create_pg_std_cell_conn_pattern rail_pattern -layers M1

set_pg_strategy M1_rails -voltage_area PD_FIFO \
   -pattern {{name: rail_pattern}{nets: VDDL VSS}} \
   -blockage {{nets: VDDH VSS} {voltage_areas: DEFAULT_VA}} \
 

compile_pg -strategies M1_rails
                       

#===============================================
#ROUTER_MESH
#===============================================
create_pg_mesh_pattern ROUTER_mesh \
   -layers {{{vertical_layer: M8} {width: 0.16} {pitch: 5} {offset: 2} {spacing: interleaving} {trim:true}} \
            {{horizontal_layer: M7} {width: 0.16} {pitch: 5} {offset: 2} {spacing: interleaving} {trim:true}}} \
   -via_rule {{intersection: adjacent} {via_master:default}}
set_pg_strategy M7M8_mesh \
   -voltage_area DEFAULT_VA  \
   -blockage {{nets: VDDH} {voltage_areas: PD_FIFO}} \
   -pattern {{name: ROUTER_mesh} {nets: VDDH VSS} {offset:{1 1}}} \
   -extension {stop: outermost_ring}
compile_pg -strategies M7M8_mesh

#==========================================
#FIFO_MESH
#==========================================
create_pg_mesh_pattern mesh_pattern_FIFO \
   -layers {{{vertical_layer: M8} {width: 0.20} {pitch: 5} {offset: 2} {spacing: interleaving} {trim: true}} \
            {{horizontal_layer: M7} {width: 0.18} {pitch: 5} {offset: 2} {spacing: interleaving} {trim: true}}} \
   -via_rule {{intersection: adjacent} {via_master:default}}
set_pg_strategy M7M8_mesh \
   -voltage_area PD_FIFO  \
   -blockage {{nets: VDDL} {voltage_areas: DEFAULT_VA}} \
   -pattern {{name: mesh_pattern_FIFO} {nets: VDDL VSS} {offset:{1 1}}} \
   -extension {stop: outermost_ring}
compile_pg -strategies M7M8_mesh
