#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <metin2_api>

/**
 * ============================================================
 *  Metin2 Stones System
 *  Sprite diferit pe fiecare level + Glow
 *  Versiune: 1.1
 * ============================================================
 */

// ============================================================
//                      CONFIGURARE GENERALĂ
// ============================================================

#define MAX_STONES              8
#define SPAWN_INTERVAL          45.0
#define SPAWN_CHANCE            70
#define MIN_DISTANCE_PLAYERS    180.0
#define MIN_DISTANCE_STONES     250.0
#define STONE_LIFETIME          0.0         // 0 = nu expiră

#define REQUIRE_RACE            1

// Bounding box
#define STONE_MINS              {-20.0, -20.0, -5.0}
#define STONE_MAXS              {20.0, 20.0, 50.0}

// ============================================================
//                   LEVEL 1 - Metin of the Plains
// ============================================================
#define STONE_L1_HP             1200
#define STONE_L1_XP             40
#define STONE_L1_YANG           800
#define STONE_L1_NAME           "Metin of the Plains"
#define STONE_L1_SPAWN_CHANCE   40
#define STONE_L1_SCALE          0.9
#define STONE_L1_COLOR_R        100
#define STONE_L1_COLOR_G        255
#define STONE_L1_COLOR_B        100

// ============================================================
//                   LEVEL 2 - Metin of the Forest
// ============================================================
#define STONE_L2_HP             2800
#define STONE_L2_XP             90
#define STONE_L2_YANG           1800
#define STONE_L2_NAME           "Metin of the Forest"
#define STONE_L2_SPAWN_CHANCE   30
#define STONE_L2_SCALE          1.1
#define STONE_L2_COLOR_R        80
#define STONE_L2_COLOR_G        180
#define STONE_L2_COLOR_B        255

// ============================================================
//                   LEVEL 3 - Metin of the Mountain
// ============================================================
#define STONE_L3_HP             5500
#define STONE_L3_XP             180
#define STONE_L3_YANG           3500
#define STONE_L3_NAME           "Metin of the Mountain"
#define STONE_L3_SPAWN_CHANCE   18
#define STONE_L3_SCALE          1.3
#define STONE_L3_COLOR_R        255
#define STONE_L3_COLOR_G        200
#define STONE_L3_COLOR_B        50

// ============================================================
//                   LEVEL 4 - Metin of the Desert
// ============================================================
#define STONE_L4_HP             9500
#define STONE_L4_XP             320
#define STONE_L4_YANG           6000
#define STONE_L4_NAME           "Metin of the Desert"
#define STONE_L4_SPAWN_CHANCE   9
#define STONE_L4_SCALE          1.5
#define STONE_L4_COLOR_R        255
#define STONE_L4_COLOR_G        80
#define STONE_L4_COLOR_B        40

// ============================================================
//                   LEVEL 5 - Metin of the Heaven
// ============================================================
#define STONE_L5_HP             16000
#define STONE_L5_XP             550
#define STONE_L5_YANG           10000
#define STONE_L5_NAME           "Metin of the Heaven"
#define STONE_L5_SPAWN_CHANCE   3
#define STONE_L5_SCALE          1.7
#define STONE_L5_COLOR_R        255
#define STONE_L5_COLOR_G        255
#define STONE_L5_COLOR_B        180

// ============================================================
//                   BOSS METIN
// ============================================================
#define STONE_BOSS_HP           45000
#define STONE_BOSS_XP           1500
#define STONE_BOSS_YANG         25000
#define STONE_BOSS_NAME         "Boss Metin"
#define STONE_BOSS_SPAWN_CHANCE 1
#define STONE_BOSS_SCALE        2.3
#define STONE_BOSS_COLOR_R      255
#define STONE_BOSS_COLOR_G      50
#define STONE_BOSS_COLOR_B      255

// ============================================================
//                      CONSTANTE INTERNE
// ============================================================

#define STONE_CLASSNAME         "m2_metin_stone"
#define TASK_SPAWN              55100
#define TASK_LIFETIME           55200

enum _:StoneData
{
	STONE_ENT,
	STONE_LEVEL,
	STONE_HP,
	STONE_MAXHP
}

new g_Stones[MAX_STONES][StoneData]
new g_StoneCount

new const Float:g_StoneMins[3] = STONE_MINS
new const Float:g_StoneMaxs[3] = STONE_MAXS


#define STONE_L1_SPRITE         "sprites/blueflare1.spr"
#define STONE_L2_SPRITE         "sprites/redflare2.spr"
#define STONE_L3_SPRITE         "sprites/flame.spr"
#define STONE_L4_SPRITE         "sprites/explode1.spr"
#define STONE_L5_SPRITE         "sprites/laserbeam.spr"
#define STONE_BOSS_SPRITE       "sprites/xbeam1.spr"

// ============================================================
//                         PLUGIN
// ============================================================

public plugin_init()
{
	register_plugin("Metin2 Stones System", "1.1", "Grok")
	
	register_event("HLTV", "event_new_round", "a", "1=0", "2=0")
	
	RegisterHam(Ham_TakeDamage, "info_target", "fw_Stone_TakeDamage")
	RegisterHam(Ham_Think, "info_target", "fw_Stone_Think")
	
	set_task(10.0, "task_TrySpawnStone", TASK_SPAWN, _, _, "b")
	
	server_print("[Metin2 Stones] Plugin incarcat | Max pietre: %d | Interval: %.0fs", MAX_STONES, SPAWN_INTERVAL)
}

public plugin_precache()
{
	// Precache toate sprite-urile folosite
	precache_model(STONE_L1_SPRITE)
	precache_model(STONE_L2_SPRITE)
	precache_model(STONE_L3_SPRITE)
	precache_model(STONE_L4_SPRITE)
	precache_model(STONE_L5_SPRITE)
	precache_model(STONE_BOSS_SPRITE)
}

public plugin_cfg()
{
	remove_all_stones()
}

public event_new_round()
{
	// Opțional: remove_all_stones()
}

public plugin_end()
{
	remove_all_stones()
}

// ============================================================
//                    SPAWN SYSTEM
// ============================================================

public task_TrySpawnStone()
{
	if (g_StoneCount >= MAX_STONES)
		return
	
	if (random_num(1, 100) > SPAWN_CHANCE)
		return
	
	new level = get_random_stone_level()
	if (level < 1)
		return
	
	new Float:origin[3]
	if (!get_valid_spawn_origin(origin))
		return
	
	create_stone(level, origin)
}

stock get_random_stone_level()
{
	new total = STONE_L1_SPAWN_CHANCE + STONE_L2_SPAWN_CHANCE + STONE_L3_SPAWN_CHANCE + 
	            STONE_L4_SPAWN_CHANCE + STONE_L5_SPAWN_CHANCE + STONE_BOSS_SPAWN_CHANCE
	
	new rnd = random_num(1, total)
	new current = 0
	
	current += STONE_L1_SPAWN_CHANCE
	if (rnd <= current) return 1
	
	current += STONE_L2_SPAWN_CHANCE
	if (rnd <= current) return 2
	
	current += STONE_L3_SPAWN_CHANCE
	if (rnd <= current) return 3
	
	current += STONE_L4_SPAWN_CHANCE
	if (rnd <= current) return 4
	
	current += STONE_L5_SPAWN_CHANCE
	if (rnd <= current) return 5
	
	return 6 // Boss
}

stock bool:get_valid_spawn_origin(Float:origin[3])
{
	new Float:start[3], Float:end[3]
	new tries = 30
	
	while (tries--)
	{
		start[0] = random_float(-1800.0, 1800.0)
		start[1] = random_float(-1800.0, 1800.0)
		start[2] = 900.0
		
		end[0] = start[0]
		end[1] = start[1]
		end[2] = -9999.0
		
		new Float:fraction
		engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, 0, 0)
		get_tr2(0, TR_flFraction, fraction)
		
		if (fraction >= 1.0)
			continue
		
		get_tr2(0, TR_vecEndPos, origin)
		origin[2] += 8.0
		
		new contents = engfunc(EngFunc_PointContents, origin)
		if (contents != CONTENTS_EMPTY && contents != CONTENTS_WATER)
			continue
		
		if (is_too_close_to_players(origin, MIN_DISTANCE_PLAYERS))
			continue
		
		if (is_too_close_to_stones(origin, MIN_DISTANCE_STONES))
			continue
		
		return true
	}
	
	return false
}

stock bool:is_too_close_to_players(const Float:origin[3], Float:min_dist)
{
	new Float:player_origin[3]
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!is_user_alive(i))
			continue
		
		pev(i, pev_origin, player_origin)
		
		if (get_distance_f(origin, player_origin) < min_dist)
			return true
	}
	return false
}

stock bool:is_too_close_to_stones(const Float:origin[3], Float:min_dist)
{
	new Float:stone_origin[3]
	
	for (new i = 0; i < MAX_STONES; i++)
	{
		if (!g_Stones[i][STONE_ENT] || !pev_valid(g_Stones[i][STONE_ENT]))
			continue
		
		pev(g_Stones[i][STONE_ENT], pev_origin, stone_origin)
		
		if (get_distance_f(origin, stone_origin) < min_dist)
			return true
	}
	return false
}

// ============================================================
//                    CREARE PIATRĂ
// ============================================================

stock create_stone(level, const Float:origin[3])
{
	if (g_StoneCount >= MAX_STONES)
		return
	
	new slot = -1
	for (new i = 0; i < MAX_STONES; i++)
	{
		if (!g_Stones[i][STONE_ENT] || !pev_valid(g_Stones[i][STONE_ENT]))
		{
			slot = i
			break
		}
	}
	
	if (slot == -1)
		return
	
	new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if (!pev_valid(ent))
		return
	
	set_pev(ent, pev_classname, STONE_CLASSNAME)
	
	// Sprite diferit pe level
	new sprite[64]
	get_stone_sprite(level, sprite, charsmax(sprite))
	engfunc(EngFunc_SetModel, ent, sprite)
	
	set_pev(ent, pev_solid, SOLID_BBOX)
	set_pev(ent, pev_movetype, MOVETYPE_NONE)
	set_pev(ent, pev_takedamage, DAMAGE_YES)
	set_pev(ent, pev_health, 999999.0)
	
	engfunc(EngFunc_SetSize, ent, g_StoneMins, g_StoneMaxs)
	engfunc(EngFunc_SetOrigin, ent, origin)
	
	// ========== GLOW + CULOARE ==========
	set_pev(ent, pev_rendermode, kRenderTransAdd)
	set_pev(ent, pev_renderfx, kRenderFxPulseSlow)
	set_pev(ent, pev_renderamt, 220.0)
	set_pev(ent, pev_scale, get_stone_scale(level))
	
	new r, g, b
	get_stone_color(level, r, g, b)

	new Float:color[3]
	color[0] = float(r)
	color[1] = float(g)
	color[2] = float(b)
	set_pev(ent, pev_rendercolor, color)
	
	// Salvare date
	new hp = get_stone_hp(level)
	
	g_Stones[slot][STONE_ENT]    = ent
	g_Stones[slot][STONE_LEVEL]  = level
	g_Stones[slot][STONE_HP]     = hp
	g_Stones[slot][STONE_MAXHP]  = hp
	g_StoneCount++
	
	set_pev(ent, pev_nextthink, get_gametime() + 0.1)
	
	if (STONE_LIFETIME > 0.0)
	{
		new data[1]
		data[0] = slot
		set_task(STONE_LIFETIME, "task_RemoveStone", TASK_LIFETIME + slot, data, 1)
	}
	
	new name[64]
	get_stone_name(level, name, charsmax(name))
	
	client_print_color(0, print_team_default, "^4[Metin]^1 O piatră ^3%s^1 a apărut pe hartă!", name)
	server_print("[Metin2 Stones] Spawned %s (L%d) | HP: %d | Active: %d/%d", name, level, hp, g_StoneCount, MAX_STONES)
}

// ============================================================
//                    DAMAGE & DESTROY
// ============================================================

public fw_Stone_TakeDamage(victim, inflictor, attacker, Float:damage, damagebits)
{
	if (!pev_valid(victim))
		return HAM_IGNORED
	
	static classname[32]
	pev(victim, pev_classname, classname, charsmax(classname))
	
	if (!equal(classname, STONE_CLASSNAME))
		return HAM_IGNORED
	
	if (!is_user_connected(attacker) || !is_user_alive(attacker))
		return HAM_SUPERCEDE
	
	new slot = get_stone_slot(victim)
	if (slot == -1)
		return HAM_SUPERCEDE
	
	new dmg = floatround(damage)
	if (dmg < 1) dmg = 1
	
	g_Stones[slot][STONE_HP] -= dmg
	
	if (random_num(1, 100) <= 30)
	{
		client_print(attacker, print_center, "Metin HP: %d / %d", g_Stones[slot][STONE_HP], g_Stones[slot][STONE_MAXHP])
	}
	
	if (g_Stones[slot][STONE_HP] <= 0)
	{
		destroy_stone(slot, attacker)
	}
	
	return HAM_SUPERCEDE
}

public fw_Stone_Think(ent)
{
	if (!pev_valid(ent))
		return
	
	static classname[32]
	pev(ent, pev_classname, classname, charsmax(classname))
	
	if (!equal(classname, STONE_CLASSNAME))
		return
	
	set_pev(ent, pev_nextthink, get_gametime() + 1.5)
}

stock destroy_stone(slot, killer)
{
	if (slot < 0 || slot >= MAX_STONES)
		return
	
	new ent = g_Stones[slot][STONE_ENT]
	new level = g_Stones[slot][STONE_LEVEL]
	
	if (pev_valid(ent))
	{
		new Float:origin[3]
		pev(ent, pev_origin, origin)
		
		// Efect de explozie
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_EXPLOSION)
		engfunc(EngFunc_WriteCoord, origin[0])
		engfunc(EngFunc_WriteCoord, origin[1])
		engfunc(EngFunc_WriteCoord, origin[2] + 25.0)
		write_short(0)
		write_byte(15)
		write_byte(12)
		write_byte(0)
		message_end()
		
		engfunc(EngFunc_RemoveEntity, ent)
	}
	
	give_stone_rewards(killer, level)
	
	new name[64], killer_name[32]
	get_stone_name(level, name, charsmax(name))
	get_user_name(killer, killer_name, charsmax(killer_name))
	
	new xp = get_stone_xp(level)
	new yang = get_stone_yang(level)
	
	client_print_color(0, print_team_default, "^4[Metin]^1 ^3%s^1 a distrus ^4%s^1 și a primit ^3%d XP^1 + ^3%d Yang^1!", 
		killer_name, name, xp, yang)
	
	g_Stones[slot][STONE_ENT]   = 0
	g_Stones[slot][STONE_LEVEL] = 0
	g_Stones[slot][STONE_HP]    = 0
	g_Stones[slot][STONE_MAXHP] = 0
	g_StoneCount--
	
	if (g_StoneCount < 0)
		g_StoneCount = 0
}

stock give_stone_rewards(id, level)
{
	if (!is_user_connected(id))
		return
	
	#if REQUIRE_RACE
	if (!m2_has_race(id))
	{
		client_print_color(id, print_team_default, "^4[Metin]^1 Trebuie să ai o rasă aleasă ca să primești recompensele!")
		return
	}
	#endif
	
	new xp = get_stone_xp(level)
	new yang = get_stone_yang(level)
	
	m2_add_xp(id, xp)
	m2_add_yang(id, yang)
	
	client_print(id, print_center, "+ %d XP  |  + %d Yang", xp, yang)
}

// ============================================================
//                    HELPER FUNCTIONS
// ============================================================

stock get_stone_slot(ent)
{
	for (new i = 0; i < MAX_STONES; i++)
	{
		if (g_Stones[i][STONE_ENT] == ent)
			return i
	}
	return -1
}

stock get_stone_hp(level)
{
	switch (level)
	{
		case 1: return STONE_L1_HP
		case 2: return STONE_L2_HP
		case 3: return STONE_L3_HP
		case 4: return STONE_L4_HP
		case 5: return STONE_L5_HP
		case 6: return STONE_BOSS_HP
	}
	return 1000
}

stock get_stone_xp(level)
{
	switch (level)
	{
		case 1: return STONE_L1_XP
		case 2: return STONE_L2_XP
		case 3: return STONE_L3_XP
		case 4: return STONE_L4_XP
		case 5: return STONE_L5_XP
		case 6: return STONE_BOSS_XP
	}
	return 10
}

stock get_stone_yang(level)
{
	switch (level)
	{
		case 1: return STONE_L1_YANG
		case 2: return STONE_L2_YANG
		case 3: return STONE_L3_YANG
		case 4: return STONE_L4_YANG
		case 5: return STONE_L5_YANG
		case 6: return STONE_BOSS_YANG
	}
	return 100
}

stock get_stone_name(level, output[], len)
{
	switch (level)
	{
		case 1: copy(output, len, STONE_L1_NAME)
		case 2: copy(output, len, STONE_L2_NAME)
		case 3: copy(output, len, STONE_L3_NAME)
		case 4: copy(output, len, STONE_L4_NAME)
		case 5: copy(output, len, STONE_L5_NAME)
		case 6: copy(output, len, STONE_BOSS_NAME)
		default: copy(output, len, "Metin Necunoscut")
	}
}

stock get_stone_sprite(level, output[], len)
{
	switch (level)
	{
		case 1: copy(output, len, STONE_L1_SPRITE)
		case 2: copy(output, len, STONE_L2_SPRITE)
		case 3: copy(output, len, STONE_L3_SPRITE)
		case 4: copy(output, len, STONE_L4_SPRITE)
		case 5: copy(output, len, STONE_L5_SPRITE)
		case 6: copy(output, len, STONE_BOSS_SPRITE)
		default: copy(output, len, "sprites/glow.spr")
	}
}

stock Float:get_stone_scale(level)
{
	switch (level)
	{
		case 1: return STONE_L1_SCALE
		case 2: return STONE_L2_SCALE
		case 3: return STONE_L3_SCALE
		case 4: return STONE_L4_SCALE
		case 5: return STONE_L5_SCALE
		case 6: return STONE_BOSS_SCALE
	}
	return 1.0
}

stock get_stone_color(level, &r, &g, &b)
{
	switch (level)
	{
		case 1:
		{
			r = STONE_L1_COLOR_R
			g = STONE_L1_COLOR_G
			b = STONE_L1_COLOR_B
		}
		case 2:
		{
			r = STONE_L2_COLOR_R
			g = STONE_L2_COLOR_G
			b = STONE_L2_COLOR_B
		}
		case 3:
		{
			r = STONE_L3_COLOR_R
			g = STONE_L3_COLOR_G
			b = STONE_L3_COLOR_B
		}
		case 4:
		{
			r = STONE_L4_COLOR_R
			g = STONE_L4_COLOR_G
			b = STONE_L4_COLOR_B
		}
		case 5:
		{
			r = STONE_L5_COLOR_R
			g = STONE_L5_COLOR_G
			b = STONE_L5_COLOR_B
		}
		case 6:
		{
			r = STONE_BOSS_COLOR_R
			g = STONE_BOSS_COLOR_G
			b = STONE_BOSS_COLOR_B
		}
		default:
		{
			r = 255
			g = 255
			b = 255
		}
	}
}

stock remove_all_stones()
{
	for (new i = 0; i < MAX_STONES; i++)
	{
		if (g_Stones[i][STONE_ENT] && pev_valid(g_Stones[i][STONE_ENT]))
			engfunc(EngFunc_RemoveEntity, g_Stones[i][STONE_ENT])
		
		g_Stones[i][STONE_ENT]   = 0
		g_Stones[i][STONE_LEVEL] = 0
		g_Stones[i][STONE_HP]    = 0
		g_Stones[i][STONE_MAXHP] = 0
	}
	g_StoneCount = 0
}

public task_RemoveStone(data[1])
{
	new slot = data[0]
	
	if (slot < 0 || slot >= MAX_STONES)
		return
	
	if (!g_Stones[slot][STONE_ENT] || !pev_valid(g_Stones[slot][STONE_ENT]))
		return
	
	new name[64]
	get_stone_name(g_Stones[slot][STONE_LEVEL], name, charsmax(name))
	
	engfunc(EngFunc_RemoveEntity, g_Stones[slot][STONE_ENT])
	
	g_Stones[slot][STONE_ENT]   = 0
	g_Stones[slot][STONE_LEVEL] = 0
	g_Stones[slot][STONE_HP]    = 0
	g_Stones[slot][STONE_MAXHP] = 0
	g_StoneCount--
	
	client_print_color(0, print_team_default, "^4[Metin]^1 %s a dispărut...", name)
}
