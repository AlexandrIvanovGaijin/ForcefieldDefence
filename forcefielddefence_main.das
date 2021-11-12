require daslib/media
require daslib/decs_boost
options debugger            // uncomment for debug in VS Code
require daslib/debug        // uncomment for debug in VS Code

var BUILDING_RADIUS_UNIT = 5.0f
var GENERATOR_SIZE = BUILDING_RADIUS_UNIT * 1.0f
var FORCEFIELD_TOWER_SIZE = BUILDING_RADIUS_UNIT * 1.0f
var GENERATOR_TRANSITION_RANGE = BUILDING_RADIUS_UNIT * 10.f
var ENERGY_MAX = 100.f
var RESOLUTION = int2(720, 720)
var RANDOM_SEED = random_seed(0)
var ENEMY_TARGETS : array<float2>
var TOWER_COST = 30.0f
var GENERATOR_COST = 50.0f
var GENERATOR_COUNER = 0

def mk_field_tower_raw(pos:float2)
    create_entity <| @ ( eid, cmp )
        cmp |> set("eid", eid)
        cmp |> set("pos", pos)
        cmp |> set("radius", BUILDING_RADIUS_UNIT)
        cmp |> set("energy", 0.0f)
        cmp |> set("field_tower", true)
        cmp |> set("energy_max", ENERGY_MAX)
        cmp |> set("forcefield", true)

def mk_generator_raw(new_gen_pos:float2)
    GENERATOR_COUNER += 1
    create_entity <| @ ( eid, cmp )
        cmp |> set("eid", eid)
        cmp |> set("pos", new_gen_pos)
        cmp |> set("radius", GENERATOR_SIZE)
        cmp |> set("energy", 0.0f)
        cmp |> set("energy_produce", 15.0f)
        cmp |> set("energy_transition_value", 45.0f)
        cmp |> set("is_generator", true)
        cmp |> set("energy_max", ENERGY_MAX)
        cmp |> set("transition_range", GENERATOR_TRANSITION_RANGE)

def mk_EMP_explode_raw(new_gen_pos:float2)
    let explode_cd = 5.0f
    create_entity <| @ ( eid, cmp )
        cmp |> set("eid", eid)
        cmp |> set("pos", new_gen_pos)
        cmp |> set("radius", 70.0f)
        cmp |> set("explode_time",  get_time_after_start() + explode_cd)

def mk_EMP_explode()
    if(ENEMY_TARGETS |> length() > 0)
        let target = ENEMY_TARGETS[random_int(RANDOM_SEED) % (ENEMY_TARGETS |> length())]
        mk_EMP_explode_raw(target)

def mk_enemy(pos:float2; move_vector:float2)
    create_entity <| @ ( eid, cmp )
        cmp |> set("eid", eid)
        cmp |> set("pos", pos)
        cmp |> set("radius", BUILDING_RADIUS_UNIT / 4.f)
        cmp |> set("move_vector", move_vector)
        cmp |> set("speed", 30.0f)
        cmp |> set("hit_dmg", 10.f)
        cmp |> set("color", float3(0, 1, 0))
        cmp |> set("hp", 0)
        cmp |> set("can_hit_structure", true)
        cmp |> set("moveable", true)

def mk_spawner_raw(n_pos:float2; n_move:float2; spawn_count:int; spawn_cd:float)
    let time = get_time_after_start()
    create_entity <| @ ( eid, cmp )
        cmp |> set("eid", eid)
        cmp |> set("pos", n_pos)
        cmp |> set("radius", BUILDING_RADIUS_UNIT)
        cmp |> set("move_vector", n_move)
        cmp |> set("speed", 25.0f)
        cmp |> set("hit_dmg", 10.f)
        cmp |> set("next_spawn_time", time + spawn_cd)
        cmp |> set("spawn_cd", spawn_cd)
        cmp |> set("spawn_iteration", 0)
        cmp |> set("spawns_count", spawn_count)
        cmp |> set("color", float3(1, 1, 0))
        cmp |> set("hp", 0)
        cmp |> set("can_hit_structure", true)
        cmp |> set("moveable", true)

def mk_shield_drainer_raw(pos:float2; move_vector:float2; hp:int)
    create_entity <| @ ( eid, cmp )
        cmp |> set("eid", eid)
        cmp |> set("pos", pos)
        cmp |> set("radius", BUILDING_RADIUS_UNIT / 1.f)
        cmp |> set("move_vector", move_vector)
        cmp |> set("speed", 20.0f)
        cmp |> set("hit_dmg", 10.f)
        cmp |> set("color", float3(1, 0, 0))
        cmp |> set("hp", hp)
        cmp |> set("moveable", true)

def mk_energy_drainer(pos:float2; move_vector:float2; drain_amount:float; destr_after:float)
    create_entity <| @ ( eid, cmp )
        cmp |> set("eid", eid)
        cmp |> set("pos", pos)
        cmp |> set("radius", BUILDING_RADIUS_UNIT / 4.f)
        cmp |> set("move_vector", move_vector)
        cmp |> set("speed", 100.0f)
        cmp |> set("color", float3(1, 0, 0))
        cmp |> set("drain_amount", 50.f)
        cmp |> set("destroy_after_N_sec", 5.f)
        cmp |> set("destroy_time", 0.f)
        cmp |> set("moveable", true)

def mk_field_tower(new_gen_pos:float2)
    var in_collide_with_other_body = find_query() <| $ (radius:float; pos:float2)
        return is_collide(pos, new_gen_pos, radius, GENERATOR_SIZE)
    if (in_collide_with_other_body)
        return

    var in_range_transition_and_cost_good = find_query() <| $ (transition_range:float; pos:float2; var energy:float)
        if(energy < TOWER_COST)
            return false
        if(is_in_range(pos, new_gen_pos, transition_range))
            energy -= TOWER_COST
            return true
        return false

    if(!in_range_transition_and_cost_good)
        return

    mk_field_tower_raw(new_gen_pos)

def mk_generator(new_gen_pos:float2)
    var in_collide_with_other_body = find_query() <| $ (radius:float; pos:float2)
        return is_collide(pos, new_gen_pos, radius, GENERATOR_SIZE)
    if (in_collide_with_other_body)
        return

    var in_range_transition_and_cost_good = find_query() <| $ (transition_range:float; pos:float2; var energy:float)
        if(energy < GENERATOR_COST)
            return false
        if (is_in_range(pos, new_gen_pos, transition_range))
            energy -= GENERATOR_COST
            return true

    if (in_range_transition_and_cost_good && !in_collide_with_other_body)
        mk_generator_raw(new_gen_pos)

def detect_targets()
    ENEMY_TARGETS |> clear()
    query <| $ (var energy_produce:float; pos:float2)
        push(ENEMY_TARGETS, pos)

def mk_enemy_and_send(pos:float2)
    if(ENEMY_TARGETS |> length() > 0)
        let target = ENEMY_TARGETS[random_int(RANDOM_SEED) % (ENEMY_TARGETS |> length())]
        let move_vector = target - pos
        mk_enemy(pos, move_vector)

def random_point_on_circle()
    let rand = random_float(RANDOM_SEED)
    let center = float2(RESOLUTION.x / 2, RESOLUTION.y / 2)
    let spawn_radius = (center.x + center.y) / 1.f
    let PI2 = PI * 2.0f
    let angle = (rand * PI2) + 1.0
    let pos = center + float2(cos(angle) * spawn_radius, sin(angle) * spawn_radius)
    return pos

def mk_wave(count:int)
    let pos1 = random_point_on_circle()
    let pos2 = random_point_on_circle()
    mk_spawner_raw(pos1, pos2 - pos1, count, 0.1)

def mk_single_attack()
    let pos = random_point_on_circle()
    mk_enemy_and_send(pos)

def mk_single_attack_spawnner_mod()
    if(ENEMY_TARGETS |> length() > 0)
        let target = ENEMY_TARGETS[random_int(RANDOM_SEED) % (ENEMY_TARGETS |> length())]
        let pos = random_point_on_circle()
        mk_spawner_raw(pos, target - pos, 20, 1.0)

def mk_single_attack_shield_drainer_mod()
    if(ENEMY_TARGETS |> length() > 0)
        let target = ENEMY_TARGETS[random_int(RANDOM_SEED) % (ENEMY_TARGETS |> length())]
        let pos = random_point_on_circle()
        mk_shield_drainer_raw(pos, target - pos, 200)

def mk_single_attack_energy_drainer_mod()
    if(ENEMY_TARGETS |> length() > 0)
        let target = ENEMY_TARGETS[random_int(RANDOM_SEED) % (ENEMY_TARGETS |> length())]
        let pos = random_point_on_circle()
        mk_energy_drainer(pos, target - pos, 100.f, 10.f)

[decs(stage = draw)]
def draw_field(forcefield:bool; pos:float2; energy:float)
    if (forcefield)
        circle(pos.x, pos.y, float(energy), make_color(0.0f, 1.0f, 1.0f))

[decs(stage = draw)]
def draw_structure_generator(pos:float2; radius:float; energy:float; energy_max:float; is_generator:bool)
    fill_circle(pos.x, pos.y, float(radius), make_color(0.0f, max(energy/energy_max, 0.1f), 0.0f))

[decs(stage = draw)]
def draw_structure_field_tower(pos:float2; radius:float; energy:float; energy_max:float; field_tower:bool)
    fill_circle(pos.x, pos.y, float(radius), make_color(0.0f, max(energy/energy_max, 0.1f), max(energy/energy_max, 0.1f)))

[decs(stage = draw)]
def enemy_draw(pos:float2; radius:float; moveable:bool; color:float3)
    fill_circle(pos.x, pos.y, radius, make_color(color.x, color.y, color.z))

[decs(stage = draw)]
def draw_energy_transition_range(transition_range:float; pos:float2)
    circle(pos.x, pos.y, transition_range, make_color(0.0f, 0.0f, 1.0f))

[decs(stage = draw)]
def draw_emp_explode(explode_time:float; pos:float2; radius:float)
    circle(pos.x, pos.y, radius, make_color(1.0f, 0.0f, 0.0f))
    let explode_in = int(explode_time - get_time_after_start())
    text_out(pos.x-10.f, pos.y-10.f, "{explode_in}", make_color(1.0, 0.0, 0.0))


[decs(stage = act)]
def spawner_spawn(eid: EntityId; pos:float2; var next_spawn_time:float; spawn_cd:float; var spawn_iteration:int; spawns_count:int)
    let cur_time = get_time_after_start()
    if (cur_time < next_spawn_time)
        return
    next_spawn_time = cur_time + spawn_cd
    mk_enemy_and_send(pos)
    spawn_iteration++
    if (spawn_iteration > spawns_count)
        delete_entity(eid)

[decs(stage = act)]
def emp_explode(eid: EntityId; explode_time:float; pos:float2; radius:float)
    let exp_pos = pos
    if( get_time_after_start() > explode_time)
        query <| $ (pos:float2; var energy:float)
            if(is_in_range(exp_pos, pos, radius))
                energy = 0.0f
        delete_entity(eid)

[decs(stage = act)]
def energy_generation(var energy:float; energy_produce:float; energy_max:float)
    energy += (energy_produce * get_delta_time())
    energy = min(energy, energy_max)

[decs(stage = act)]
def enemy_move(eid: EntityId; var pos:float2; move_vector:float2; speed:float; moveable:bool)
    if(!moveable)
        return
    let move = normalize(move_vector)
    pos += move * speed * get_delta_time()

    if (pos.x < -2000.f || pos.x > 3000.f || pos.y < -2000.f || pos.x > 3000.f)
        delete_entity(eid)
 
def is_collide(pos1:float2; pos2:float2; rad1:float; rad2:float)
    let pos_a = pos1 - pos2
    return length(pos_a) < rad1 + rad2

def is_in_range(pos1:float2; pos2:float2; ran:float)
    let pos_a = pos1 - pos2
    return length(pos_a) < ran

[decs(stage = act)]
def enemy_hit_forcefield(eid: EntityId; var pos:float2; radius:float; hit_dmg:float; var hp:int)
    let enemy_pos = pos;
    let enemy_rad = radius
    var found = find_query() <| $ (var pos:float2; forcefield:bool; var energy:float)
        if(is_collide(enemy_pos, pos, enemy_rad, energy))
            energy -= hit_dmg
            hp -= int(hit_dmg)
            return true

    if (found && hp < 0)
        delete_entity(eid)

[decs(stage = act)]
def enemy_hit_structure(eid: EntityId; var pos:float2; radius:float; hit_dmg:float; can_hit_structure:bool)
    let enemy_pos = pos;
    let enemy_rad = radius
    var found = find_query() <| $ (eid: EntityId; var pos:float2; radius:float; var energy:float)
        if(is_collide(enemy_pos, pos, enemy_rad, radius))
            delete_entity(eid)
    if(found)
        delete_entity(eid)

[decs(stage = act)]
def energy_drainer_hit_energy_source(eid: EntityId; pos:float2; radius:float; var moveable:bool; drain_amount:float; var destroy_time:float; destroy_after_N_sec:float)
    if (!moveable)
        return
    let vamp_pos = pos
    let vamp_rad = radius
    find_query <| $ (var energy:float; pos:float2; radius:float; eid:EntityId)
        if (is_collide(pos, vamp_pos, radius, vamp_rad))
            moveable = false
            destroy_time = get_time_after_start() + destroy_after_N_sec

[decs(stage = act)]
def energy_drainer_drain(eid: EntityId; pos:float2; radius:float; destroy_time:float; drain_amount:float; moveable:bool)
    if(moveable)
        return;
    let vamp_pos = pos
    let vamp_rad = radius
    find_query() <| $ (pos:float2; radius:float; var energy:float)
        if (is_collide(vamp_pos, pos, vamp_rad, radius))
            energy -= drain_amount * get_delta_time()

    if (get_time_after_start() > destroy_time)
        delete_entity(eid)

[decs(stage = act)]
def energy_snd(transition_range:float; var energy:float&; energy_transition_value:float; pos:float2)
    var energy_generator = energy
    var transition = energy_transition_value * get_delta_time()
    let generator_pos = pos
    if(energy_generator < transition)
        return
    query <| $ (var energy:float; field_tower:bool; energy_max:float; pos:float2; forcefield:bool)
        if (is_in_range(generator_pos, pos, transition_range) &&
                field_tower && 
                energy + transition < energy_max)
            energy += transition
            energy_generator -= transition
    query <| $ (transition_range:float; var energy:float&; energy_max:float; energy_transition_value:float; pos:float2)
        if(energy < energy_generator &&
                is_in_range(generator_pos, pos, transition_range) &&
                energy + transition < energy_max)
            energy += transition
            energy_generator -= transition
    energy = energy_generator

def draw_curcosr(curs_pos:float2)
    circle(curs_pos.x, curs_pos.y, BUILDING_RADIUS_UNIT + 1.f, make_color(1.0f, 1.0f, 1.0f, 0.1f))
    var en = 0.0f
    find_query() <| $ (transition_range:float; pos:float2; energy:float; is_generator:bool)
        if(is_in_range(curs_pos, pos, transition_range))
            en = energy
            return true
    text_out(10, 10, "Generator's energy: {en}", 0xFFFFFF)
    text_out(10, 40, "Generator cost: {GENERATOR_COST}", 0xFFFFFF)
    text_out(10, 55, "Shield cost: {TOWER_COST}", 0xFFFFFF)


// 'initialize' runs once when game starts and every hot-reload
[export]
def initialize
    set_window_title("ForcefieldDefence")
    set_resolution(RESOLUTION.x, RESOLUTION.y)
    mk_generator_raw(float2(RESOLUTION.x / 2 - 200, RESOLUTION.y / 2 - 200))
    mk_generator_raw(float2(RESOLUTION.x / 2 + 200, RESOLUTION.y / 2 - 200))
    mk_generator_raw(float2(RESOLUTION.x / 2 - 200, RESOLUTION.y / 2 + 200))
    mk_generator_raw(float2(RESOLUTION.x / 2 + 200, RESOLUTION.y / 2 + 200))
    detect_targets()
    randomize_seed(RANDOM_SEED)
    mk_single_attack_energy_drainer_mod()

    return

// this function is called to update game data,
// dt - time elapsed since the previous update (in seconds)
var singlespawn_time = 0.0f
var singlespawn_cd = 5.0f
var wave_time = 0.0f
var wave_cd = 15.0f
var game_stage = 1
var emp_time = 0.0f;
var emp_cd = 9.0f;
var spawner_mod_each_N_wave = 5
var shield_drainer_add_each_N_wave = 7
var energy_drainer_add_each_N_wave = 3
var signlespawn_iterator = 0
[export]
def act(dt: float)
    detect_targets()
    decs_stage("act")
    let d_time = get_delta_time()
    singlespawn_time += d_time
    wave_time += d_time
    emp_time += d_time
    
    if(singlespawn_time > singlespawn_cd)
        signlespawn_iterator++
        singlespawn_time = 0.0f
        if (signlespawn_iterator % spawner_mod_each_N_wave == 0)
            for i in range(max(game_stage / 8, 1))
                mk_single_attack_spawnner_mod()
        else
            for i in range(game_stage / 4)
                mk_single_attack()
        
        if(signlespawn_iterator % shield_drainer_add_each_N_wave == 0)
            for i in range(game_stage / 12)
                mk_single_attack_shield_drainer_mod()
        if(signlespawn_iterator % energy_drainer_add_each_N_wave == 0)
            for i in range(game_stage / 6)
                mk_single_attack_energy_drainer_mod()
    if(wave_time > wave_cd)
        wave_time = 0.0f
        mk_wave(game_stage)
        game_stage = max(1, GENERATOR_COUNER * (int(ENERGY_MAX) / 10) / 4)
    if(emp_time > emp_cd)
        emp_time = 0.0f
        mk_EMP_explode()

    if get_key(VK_ESCAPE)
        schedule_quit_game()
    if get_mouse_button_up(MB_LEFT)
        mk_field_tower(get_mouse_position())
    if get_mouse_button_down(MB_RIGHT)
        mk_generator(get_mouse_position())
    return

// this function will be called every frame after 'act',
// you can draw anything in this function
[export]
def draw
    decs_stage("draw")
    draw_curcosr(get_mouse_position())
    return
