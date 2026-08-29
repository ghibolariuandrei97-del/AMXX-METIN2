#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <metin2_api>          // your include

#define PLUGIN_NAME    "Metin2CrystalDrop"
#define PLUGIN_VERSION "1.2"
#define PLUGIN_AUTHOR  "Grok"

// ======================== CONFIG ========================
#define MAX_CRYSTALS_PER_DEATH   3       // max crystals spawned on death
#define CRYSTAL_LIFETIME         45.0    // seconds until auto-remove
#define CRYSTAL_TOUCH_DISTANCE   45.0    // distance considered "touch"
#define CRYSTAL_Z_OFFSET         15.0    // height above body
#define CRYSTAL_SPAWN_RADIUS     25.0    // random offset around body

// Rewards (base values – can be scaled by level difference)
#define BASE_XP_REWARD           80
#define BASE_YANG_REWARD         250
#define BASE_MONEY_REWARD        300     // CS money ($), set 0 to disable

// Chance for large crystals (better rewards)
#define LARGE_CRYSTAL_CHANCE     35      // %

// Models (must be in models/ folder on server)
new const g_szCrystalModels[][] = {
	"models/crystal1_normal.mdl",
	"models/crystal1_large.mdl",
	"models/crystal2_normal.mdl",
	"models/crystal2_large.mdl",
	"models/crystal3_normal.mdl",
	"models/crystal3_large.mdl"
};

// Sounds (optional – put in sound/ folder)
new const g_szPickupSound[] = "items/gunpickup2.wav";
new const g_szSpawnSound[]  = "items/gunpickup1.wav";

// ======================== DATA ========================
enum _:CrystalData {
	CRYSTAL_ENT,
	CRYSTAL_OWNER,          // who dropped it (0 = none)
	Float:CRYSTAL_SPAWN_TIME,
	bool:CRYSTAL_IS_LARGE,
	CRYSTAL_MODEL_IDX
};

#define MAX_ACTIVE_CRYSTALS  64
new g_Crystals[MAX_ACTIVE_CRYSTALS][CrystalData];
new g_iCrystalCount;

// CVars
new g_pCvarEnable;
new g_pCvarMaxCrystals;
new g_pCvarLifetime;
new g_pCvarXp;
new g_pCvarYang;
new g_pCvarMoney;
new g_pCvarLargeChance;
new g_pCvarOnlyEnemy;       // 1 = only enemies can pick (team check)
new g_pCvarAnnounce;

public plugin_precache()
{
	for (new i = 0; i < sizeof(g_szCrystalModels); i++)
		precache_model(g_szCrystalModels[i]);
	
	precache_sound(g_szPickupSound);
	precache_sound(g_szSpawnSound);
}

public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
	
	// CVars
	g_pCvarEnable      = register_cvar("m2_crystal_enable", "1");
	g_pCvarMaxCrystals = register_cvar("m2_crystal_max", "3");
	g_pCvarLifetime       = register_cvar("m2_crystal_time", "45.0");
	g_pCvarXp          = register_cvar("m2_crystal_xp", "80");
	g_pCvarYang        = register_cvar("m2_crystal_yang", "250");
	g_pCvarMoney       = register_cvar("m2_crystal_money", "300");
	g_pCvarLargeChance = register_cvar("m2_crystal_large_chance", "35");
	g_pCvarOnlyEnemy   = register_cvar("m2_crystal_only_enemy", "0");  // 0 = anyone can pick
	g_pCvarAnnounce    = register_cvar("m2_crystal_announce", "1");
	
	// Death
	RegisterHam(Ham_Killed, "player", "OnPlayerKilled", 1);
	
	// Touch / Think
	register_touch("m2_crystal", "player", "OnCrystalTouch");
	register_think("m2_crystal", "OnCrystalThink");
	
	// Commands
	register_clcmd("say /crystals", "CmdCrystalsInfo");
	register_concmd("m2_crystal_clear", "CmdClearAll", ADMIN_KICK, "Clears all crystals");
	
	// Cleanup on round start / map change
	register_event("HLTV", "OnNewRound", "a", "1=0", "2=0");
	
	set_task(1.0, "Task_CleanupExpired", _, _, _, "b");
}

public plugin_cfg()
{
	// Make sure models folder is correct
	server_print("[Metin2 Crystal Drop] Loaded successfully.");
}

// ================================================================
// DEATH → SPAWN CRYSTALS + REMOVE CORPSE
// ================================================================
public OnPlayerKilled(victim, attacker, shouldgib)
{
	if (!get_pcvar_num(g_pCvarEnable))
		return;
	
	if (!is_user_connected(victim))
		return;
	
	// Remove original corpse (important for respawn servers)
	set_task(0.1, "Task_RemoveCorpse", victim);
	
	// Don't spawn if suicide or worldkill? Optional – currently we do spawn
	// if (attacker == victim || !is_user_connected(attacker)) return;
	
	new Float:origin[3];
	pev(victim, pev_origin, origin);
	origin[2] += CRYSTAL_Z_OFFSET;
	
	new maxCrystals = clamp(get_pcvar_num(g_pCvarMaxCrystals), 1, MAX_CRYSTALS_PER_DEATH);
	new count = random_num(1, maxCrystals);
	
	for (new i = 0; i < count; i++)
	{
		SpawnCrystal(origin, victim);
	}
	
	if (get_pcvar_num(g_pCvarAnnounce))
	{
		new name[32];
		get_user_name(victim, name, charsmax(name));
		client_print_color(0, print_team_default, "^4[Crystal]^1 %s a lasat %d cristal(e)!", name, count);
	}
}

public Task_RemoveCorpse(id)
{
	if (!is_user_connected(id))
		return;
	
	// Hide / remove the body
	set_pev(id, pev_effects, pev(id, pev_effects) | EF_NODRAW);
	set_pev(id, pev_solid, SOLID_NOT);
	
	// Extra safety for some mods
	engfunc(EngFunc_SetOrigin, id, Float:{0.0, 0.0, -4096.0});
}

// ================================================================
// SPAWN CRYSTAL ENTITY
// ================================================================
SpawnCrystal(const Float:baseOrigin[3], owner)
{
	if (g_iCrystalCount >= MAX_ACTIVE_CRYSTALS)
		return;
	
	new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
	if (!pev_valid(ent))
		return;
	
	// Random position around body
	new Float:origin[3];
	origin[0] = baseOrigin[0] + random_float(-CRYSTAL_SPAWN_RADIUS, CRYSTAL_SPAWN_RADIUS);
	origin[1] = baseOrigin[1] + random_float(-CRYSTAL_SPAWN_RADIUS, CRYSTAL_SPAWN_RADIUS);
	origin[2] = baseOrigin[2];
	
	// Decide large or normal
	new bool:isLarge = (random_num(1, 100) <= get_pcvar_num(g_pCvarLargeChance));
	
	// Pick model (0,2,4 = normal | 1,3,5 = large)
	new modelIdx;
	if (isLarge)
		modelIdx = (random_num(0, 2) * 2) + 1;   // 1,3,5
	else
		modelIdx = random_num(0, 2) * 2;         // 0,2,4
	
	set_pev(ent, pev_classname, "m2_crystal");
	set_pev(ent, pev_solid, SOLID_TRIGGER);
	set_pev(ent, pev_movetype, MOVETYPE_TOSS);
	set_pev(ent, pev_owner, owner);
	
	engfunc(EngFunc_SetModel, ent, g_szCrystalModels[modelIdx]);
	engfunc(EngFunc_SetSize, ent, Float:{-12.0, -12.0, -8.0}, Float:{12.0, 12.0, 16.0});
	engfunc(EngFunc_SetOrigin, ent, origin);
	
	// Make it drop a bit + bounce
	set_pev(ent, pev_gravity, 0.6);
	
	// Glow (nice visual)
	set_pev(ent, pev_renderfx, kRenderFxGlowShell);
	new Float:color[3];
	if (isLarge)
	{
		color[0] = 255.0;
		color[1] = 180.0;
		color[2] = 50.0;
	}
	else
	{
		color[0] = 100.0;
		color[1] = 200.0;
		color[2] = 255.0;
	}
	set_pev(ent, pev_rendercolor, color);
	set_pev(ent, pev_renderamt, 40.0);
	
	// Think for lifetime + rotation
	set_pev(ent, pev_nextthink, get_gametime() + 0.1);
	
	// Store data
	new idx = g_iCrystalCount++;
	g_Crystals[idx][CRYSTAL_ENT]        = ent;
	g_Crystals[idx][CRYSTAL_OWNER]      = owner;
	g_Crystals[idx][CRYSTAL_SPAWN_TIME] = get_gametime();
	g_Crystals[idx][CRYSTAL_IS_LARGE]   = isLarge;
	g_Crystals[idx][CRYSTAL_MODEL_IDX]  = modelIdx;
	
	// Sound
	emit_sound(ent, CHAN_ITEM, g_szSpawnSound, 0.6, ATTN_NORM, 0, PITCH_NORM);
}

// ================================================================
// TOUCH → GIVE REWARDS
// ================================================================
public OnCrystalTouch(ent, id)
{
	if (!pev_valid(ent) || !is_user_alive(id))
		return;
	
	// Find crystal data
	new crystalIdx = FindCrystalIndex(ent);
	if (crystalIdx == -1)
		return;
	
	// Optional: only enemies can pick
	if (get_pcvar_num(g_pCvarOnlyEnemy))
	{
		new owner = g_Crystals[crystalIdx][CRYSTAL_OWNER];
		if (is_user_connected(owner) && get_user_team(id) == get_user_team(owner))
			return;
	}
	
	// Don't let the owner pick his own crystal immediately (anti-farm)
	if (g_Crystals[crystalIdx][CRYSTAL_OWNER] == id && (get_gametime() - g_Crystals[crystalIdx][CRYSTAL_SPAWN_TIME]) < 3.0)
		return;
	
	GiveCrystalReward(id, crystalIdx);
	RemoveCrystal(crystalIdx);
}

GiveCrystalReward(id, crystalIdx)
{
	new bool:isLarge = g_Crystals[crystalIdx][CRYSTAL_IS_LARGE];
	
	new xp   = get_pcvar_num(g_pCvarXp);
	new yang = get_pcvar_num(g_pCvarYang);
	new money = get_pcvar_num(g_pCvarMoney);
	
	if (isLarge)
	{
		xp   = floatround(xp * 1.8);
		yang = floatround(yang * 2.0);
		money = floatround(money * 1.7);
	}
	
	// Slight random variation
	xp   = floatround(xp * random_float(0.85, 1.15));
	yang = floatround(yang * random_float(0.80, 1.25));
	
	// Give Metin2 rewards
	m2_add_xp(id, xp);
	m2_add_yang(id, yang);
	
	// Optional CS money
	if (money > 0)
		cs_set_user_money(id, cs_get_user_money(id) + money);
	
	// Feedback
	new name[32];
	get_user_name(id, name, charsmax(name));
	
	client_print_color(id, print_team_default, 
		"^4[Crystal]^1 Ai primit ^3%d XP^1 + ^3%d Yang%s%s!", 
		xp, yang, 
		money > 0 ? fmt(" + $%d", money) : "",
		isLarge ? " ^4(Large!)" : "");
	
	if (get_pcvar_num(g_pCvarAnnounce))
	{
		client_print_color(0, print_team_default, 
			"^4[Crystal]^1 %s a colectat un cristal%s!", name, isLarge ? " ^3mare" : "");
	}
	
	// Effects
	emit_sound(id, CHAN_ITEM, g_szPickupSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	
	// Screen fade + small explosion effect
	message_begin(MSG_ONE, get_user_msgid("ScreenFade"), _, id);
	write_short(1<<10);
	write_short(1<<10);
	write_short(0x0000);
	write_byte(isLarge ? 255 : 100);
	write_byte(isLarge ? 180 : 200);
	write_byte(isLarge ? 50 : 255);
	write_byte(60);
	message_end();
}

// ================================================================
// THINK + LIFETIME
// ================================================================
public OnCrystalThink(ent)
{
	if (!pev_valid(ent))
		return;
	
	// Slow rotation for nice look
	static Float:angles[3];
	pev(ent, pev_angles, angles);
	angles[1] += 2.5;
	set_pev(ent, pev_angles, angles);
	
	set_pev(ent, pev_nextthink, get_gametime() + 0.1);
}

public Task_CleanupExpired()
{
	new Float:now = get_gametime();
	new Float:lifetime = get_pcvar_float(g_pCvarLifetime);
	
	for (new i = g_iCrystalCount - 1; i >= 0; i--)
	{
		if (!pev_valid(g_Crystals[i][CRYSTAL_ENT]))
		{
			RemoveCrystal(i);
			continue;
		}
		
		if (now - g_Crystals[i][CRYSTAL_SPAWN_TIME] >= lifetime)
		{
			RemoveCrystal(i);
		}
	}
}

// ================================================================
// HELPERS
// ================================================================
FindCrystalIndex(ent)
{
	for (new i = 0; i < g_iCrystalCount; i++)
	{
		if (g_Crystals[i][CRYSTAL_ENT] == ent)
			return i;
	}
	return -1;
}

RemoveCrystal(idx)
{
	if (idx < 0 || idx >= g_iCrystalCount)
		return;
	
	new ent = g_Crystals[idx][CRYSTAL_ENT];
	if (pev_valid(ent))
		engfunc(EngFunc_RemoveEntity, ent);
	
	// Shift array
	for (new i = idx; i < g_iCrystalCount - 1; i++)
	{
		g_Crystals[i] = g_Crystals[i + 1];
	}
	g_iCrystalCount--;
}

public OnNewRound()
{
	// Clear all crystals on new round
	for (new i = g_iCrystalCount - 1; i >= 0; i--)
		RemoveCrystal(i);
}

public client_disconnected(id)
{
	// Optional: remove crystals owned by disconnected player
	for (new i = g_iCrystalCount - 1; i >= 0; i--)
	{
		if (g_Crystals[i][CRYSTAL_OWNER] == id)
			RemoveCrystal(i);
	}
}

// ================================================================
// COMMANDS
// ================================================================
public CmdCrystalsInfo(id)
{
	client_print_color(id, print_team_default, 
		"^4[Crystal]^1 Cristale active: ^3%d^1 | XP: ^3%d^1 | Yang: ^3%d", 
		g_iCrystalCount, get_pcvar_num(g_pCvarXp), get_pcvar_num(g_pCvarYang));
	return PLUGIN_HANDLED;
}

public CmdClearAll(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;
	
	new count = g_iCrystalCount;
	for (new i = g_iCrystalCount - 1; i >= 0; i--)
		RemoveCrystal(i);
	
	console_print(id, "[Crystal] Cleared %d crystals.", count);
	return PLUGIN_HANDLED;
}
