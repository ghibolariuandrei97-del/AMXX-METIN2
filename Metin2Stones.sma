#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <metin2_api>

/**
 * ============================================================
 *  Metin2 Stones System (Sprite version)
 *  Plugin separat pentru Metin2 RPG Core
 *  
 *  - Pietre de level diferit (1-5 + Boss)
 *  - Spawn random pe hartă
 *  - Recompense XP + Yang prin API
 *  - Toate valorile configurabile prin #define
 *  
 *  Versiune: 1.0
 *  Notă: Momentan folosește sprite. Când ai model,
 *        schimbă doar STONE_SPRITE și setările de size.
 * ============================================================
 */

// ============================================================
//                      CONFIGURARE GENERALĂ
// ============================================================

#define MAX_STONES              8           // Maxim de pietre active simultan pe hartă
#define SPAWN_INTERVAL          45.0        // La câte secunde încearcă să spawneze o piatră nouă
#define SPAWN_CHANCE            70          // Șansa (%) să spawneze când e timpul (0-100)
#define MIN_DISTANCE_PLAYERS    180.0       // Distanță minimă față de jucători la spawn
#define MIN_DISTANCE_STONES     250.0       // Distanță minimă între pietre
#define STONE_LIFETIME          0.0         // 0 = nu expiră niciodată | >0 = secunde până dispare automat

// Sprite-ul folosit (pune fișierul în cstrike/sprites/)
// Exemplu: sprites/metin2/stone.spr
// Temporar poți folosi un sprite existent din CS (ex: sprites/glow.spr)
#define STONE_SPRITE            "sprites/metin2/stone.spr"

// Mărimea bounding box-ului (pentru coliziune / damage)
#define STONE_MINS              {-22.0, -22.0, -5.0}
#define STONE_MAXS              {22.0, 22.0, 45.0}

// Cine poate primi recompense
#define REQUIRE_RACE            1           // 1 = doar jucătorii cu rasă aleasă primesc XP/Yang

// ============================================================
//                   LEVEL 1 - Metin of the Plains
// ============================================================
#define STONE_L1_HP             1200
#define STONE_L1_XP             40
#define STONE_L1_YANG           800
#define STONE_L1_NAME           "Metin of the Plains"
#define STONE_L1_SPAWN_CHANCE   40          // Greutate relativă la spawn (mai mare = apare mai des)

// ============================================================
//                   LEVEL 2 - Metin of the Forest
// ============================================================
#define STONE_L2_HP             2800
#define STONE_L2_XP             90
#define STONE_L2_YANG           1800
#define STONE_L2_NAME           "Metin of the Forest"
#define STONE_L2_SPAWN_CHANCE   30

// ============================================================
//                   LEVEL 3 - Metin of the Mountain
// ============================================================
#define STONE_L3_HP             5500
#define STONE_L3_XP             180
#define STONE_L3_YANG           3500
#define STONE_L3_NAME           "Metin of the Mountain"
#define STONE_L3_SPAWN_CHANCE   18

// ============================================================
//                   LEVEL 4 - Metin of the Desert
// ============================================================
#define STONE_L4_HP             9500
#define STONE_L4_XP             320
#define STONE_L4_YANG           6000
#define STONE_L4_NAME           "Metin of the Desert"
#define STONE_L4_SPAWN_CHANCE   9

// ============================================================
//                   LEVEL 5 - Metin of the Heaven
// ============================================================
#define STONE_L5_HP             16000
#define STONE_L5_XP             550
#define STONE_L5_YANG           10000
#define STONE_L5_NAME           "Metin of the Heaven"
#define STONE_L5_SPAWN_CHANCE   3

// ============================================================
//                   BOSS METIN (rar)
// ============================================================
#define STONE_BOSS_HP           45000
#define STONE_BOSS_XP           1500
#define STONE_BOSS_YANG         25000
#define STONE_BOSS_NAME         "Boss Metin"
#define STONE_BOSS_SPAWN_CHANCE 1           // Foarte rar

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

// ============================================================
//                         PLUGIN INFO
// ============================================================

public plugin_init()
{
	register_plugin("Metin2 Stones System", "1.0", "Grok")
	
	register_event("HLTV", "event_new_round", "a", "1=0", "2=0")
	
	RegisterHam(Ham_TakeDamage, "info_target", "fw_Stone_TakeDamage")
	RegisterHam(Ham_Think, "info_target", "fw_Stone_Think")
	
	set_task(10.0, "task_TrySpawnStone", TASK_SPAWN, _, _, "b")
	
	// Mesaj la pornire
	server_print("[Metin2 Stones] Plugin încărcat. Max pietre: %d | Interval spawn: %.0fs", MAX_STONES, SPAWN_INTERVAL)
}

public plugin_precache()
{
	// Dacă sprite-ul nu există, serverul va da warning, dar pluginul tot pornește
	precache_model(STONE_SPRITE)
	
	// Sunete opționale (poți comenta dacă nu le ai)
	// precache_sound("metin2/stone_hit.wav")
	// precache_sound("metin2/stone_break.wav")
}

public plugin_cfg()
{
	// Curățăm la start
	remove_all_stones()
}

// ============================================================
//                       ROUND / MAP
// ============================================================

public event_new_round()
{
	// Opțional: șterge pietrele vechi la rundă nouă
	// remove_all_stones()
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
	new tries = 25
	
	while (tries--)
	{
		// Generăm X/Y random pe o zonă rezonabilă (funcționează pe majoritatea hărților)
		start[0] = random_float(-1800.0, 1800.0)
		start[1] = random_float(-1800.0, 1800.0)
		start[2] = 800.0   // Începem de sus
		
		end[0] = start[0]
		end[1] = start[1]
		end[2] = -9999.0
		
		new Float:fraction
		engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, 0, 0)
		get_tr2(0, TR_flFraction, fraction)
		
		if (fraction >= 1.0)
			continue
		
		get_tr2(0, TR_vecEndPos, origin)
		origin[2] += 5.0  // Ridicăm puțin de pe sol
		
		// Verificăm dacă e liber (nu e în solid)
		if (engfunc(EngFunc_PointContents, origin) != CONTENTS_EMPTY && 
		    engfunc(EngFunc_PointContents, origin) != CONTENTS_WATER)
			continue
		
		// Verificăm distanța față de jucători
		if (is_too_close_to_players(origin, MIN_DISTANCE_PLAYERS))
			continue
		
		// Verificăm distanța față de alte pietre
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
	engfunc(EngFunc_SetModel, ent, STONE_SPRITE)
	
	set_pev(ent, pev_solid, SOLID_BBOX)
	set_pev(ent, pev_movetype, MOVETYPE_NONE)
	set_pev(ent, pev_takedamage, DAMAGE_YES)
	set_pev(ent, pev_health, 999999.0) // Nu folosim health-ul engine-ului, avem unul custom
	
	engfunc(EngFunc_SetSize, ent, g_StoneMins, g_StoneMaxs)
	engfunc(EngFunc_SetOrigin, ent, origin)
	
	// Render ca să se vadă bine sprite-ul
	set_pev(ent, pev_rendermode, kRenderNormal)
	set_pev(ent, pev_renderamt, 255.0)
	set_pev(ent, pev_scale, get_stone_scale(level))
	
	// Salvăm datele
	new hp = get_stone_hp(level)
	
	g_Stones[slot][STONE_ENT]    = ent
	g_Stones[slot][STONE_LEVEL]  = level
	g_Stones[slot][STONE_HP]     = hp
	g_Stones[slot][STONE_MAXHP]  = hp
	g_StoneCount++
	
	// Think pentru eventuale efecte
	set_pev(ent, pev_nextthink, get_gametime() + 0.1)
	
	// Lifetime opțional
	if (STONE_LIFETIME > 0.0)
	{
		new data[1]
		data[0] = slot
		set_task(STONE_LIFETIME, "task_RemoveStone", TASK_LIFETIME + slot, data, 1)
	}
	
	// Anunț
	new name[64]
	get_stone_name(level, name, charsmax(name))
	
	client_print(0, print_chat, "[Metin] O piatră ^4%s^1 a apărut pe hartă!", name)
	
	// Log
	server_print("[Metin2 Stones] Spawned %s (Level %d) | HP: %d | Active: %d/%d", name, level, hp, g_StoneCount, MAX_STONES)
}

stock Float:get_stone_scale(level)
{
	switch (level)
	{
		case 1: return 0.8
		case 2: return 1.0
		case 3: return 1.2
		case 4: return 1.4
		case 5: return 1.6
		case 6: return 2.2  // Boss
	}
	return 1.0
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
	
	// Scădem HP
	new dmg = floatround(damage)
	if (dmg < 1) dmg = 1
	
	g_Stones[slot][STONE_HP] -= dmg
	
	// Feedback mic (opțional)
	if (random_num(1, 100) <= 25)
	{
		client_print(attacker, print_center, "Metin HP: %d / %d", g_Stones[slot][STONE_HP], g_Stones[slot][STONE_MAXHP])
	}
	
	if (g_Stones[slot][STONE_HP] <= 0)
	{
		destroy_stone(slot, attacker)
	}
	
	return HAM_SUPERCEDE // Nu vrem ca engine-ul să distrugă entitatea
}

public fw_Stone_Think(ent)
{
	if (!pev_valid(ent))
		return
	
	static classname[32]
	pev(ent, pev_classname, classname, charsmax(classname))
	
	if (!equal(classname, STONE_CLASSNAME))
		return
	
	// Poți adăuga aici efecte de particule / pulse etc.
	set_pev(ent, pev_nextthink, get_gametime() + 1.0)
}

stock destroy_stone(slot, killer)
{
	if (slot < 0 || slot >= MAX_STONES)
		return
	
	new ent = g_Stones[slot][STONE_ENT]
	new level = g_Stones[slot][STONE_LEVEL]
	
	if (pev_valid(ent))
	{
		// Efect de distrugere simplu
		new Float:origin[3]
		pev(ent, pev_origin, origin)
		
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_EXPLOSION)
		engfunc(EngFunc_WriteCoord, origin[0])
		engfunc(EngFunc_WriteCoord, origin[1])
		engfunc(EngFunc_WriteCoord, origin[2] + 20.0)
		write_short(0) // sprite index (0 = default)
		write_byte(12)
		write_byte(15)
		write_byte(0)
		message_end()
		
		engfunc(EngFunc_RemoveEntity, ent)
	}
	
	// Recompense
	give_stone_rewards(killer, level)
	
	// Anunț
	new name[64], killer_name[32]
	get_stone_name(level, name, charsmax(name))
	get_user_name(killer, killer_name, charsmax(killer_name))
	
	new xp = get_stone_xp(level)
	new yang = get_stone_yang(level)
	
	client_print(0, print_chat, "[Metin] ^3%s^1 a distrus ^4%s^1 și a primit ^4%d XP^1 + ^4%d Yang^1!", killer_name, name, xp, yang)
	
	// Reset slot
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
		client_print(id, print_chat, "[Metin] Trebuie să ai o rasă aleasă ca să primești recompensele!")
		return
	}
	#endif
	
	new xp = get_stone_xp(level)
	new yang = get_stone_yang(level)
	
	// Adăugăm XP (core-ul se ocupă de level-up dacă e cazul)
	m2_add_xp(id, xp)
	
	// Adăugăm Yang
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

stock remove_all_stones()
{
	for (new i = 0; i < MAX_STONES; i++)
	{
		if (g_Stones[i][STONE_ENT] && pev_valid(g_Stones[i][STONE_ENT]))
		{
			engfunc(EngFunc_RemoveEntity, g_Stones[i][STONE_ENT])
		}
		
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
	
	client_print(0, print_chat, "[Metin] %s a dispărut...", name)
}
