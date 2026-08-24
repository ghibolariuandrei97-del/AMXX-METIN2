#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <metin2_api>

#define PLUGIN_NAME    "Metin2 BunnyHop + Gravity/Speed"
#define PLUGIN_VERSION "1.4"
#define PLUGIN_AUTHOR  "Grok"

// ======================== CVARS ========================
new g_pCvarEnable
new g_pCvarGravityBase
new g_pCvarGravityPerLevel
new g_pCvarGravityMin
new g_pCvarSpeedBase
new g_pCvarSpeedPerLevel
new g_pCvarSpeedMax
new g_pCvarBhopEnable
new g_pCvarBhopSpeedGain
new g_pCvarBhopAuto
new g_pCvarNoFallDamage
new g_pCvarShowInfo

// ======================== PLAYER DATA ========================
new Float:g_fPlayerGravity[33]
new Float:g_fPlayerMaxSpeed[33]
new bool:g_bWasOnGround[33]

// Damage Indicator
new Float:g_fLastDamageTime[33]
new g_iHudSync

// ======================== PLUGIN ========================

public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)

	// CVARs
	g_pCvarEnable          = register_cvar("m2_bhop_enable", "1")
	g_pCvarGravityBase     = register_cvar("m2_gravity_base", "1.0")
	g_pCvarGravityPerLevel = register_cvar("m2_gravity_per_level", "0.008")
	g_pCvarGravityMin      = register_cvar("m2_gravity_min", "0.55")
	g_pCvarSpeedBase       = register_cvar("m2_speed_base", "250.0")
	g_pCvarSpeedPerLevel   = register_cvar("m2_speed_per_level", "3.5")
	g_pCvarSpeedMax        = register_cvar("m2_speed_max", "450.0")
	g_pCvarBhopEnable      = register_cvar("m2_bhop_enable_system", "1")
	g_pCvarBhopSpeedGain   = register_cvar("m2_bhop_speed_gain", "1.08")
	g_pCvarBhopAuto        = register_cvar("m2_bhop_auto", "1")
	g_pCvarNoFallDamage    = register_cvar("m2_nofalldamage", "1")
	g_pCvarShowInfo        = register_cvar("m2_bhop_showinfo", "1")

	// Hooks
	RegisterHookChain(RG_CBasePlayer_Spawn, "RG_PlayerSpawn_Post", true)
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "RG_TakeDamage")
	RegisterHookChain(RG_CBasePlayer_PreThink, "RG_PlayerPreThink")

	g_iHudSync = CreateHudSyncObj()
}
// ======================== METIN2 LEVEL UP ========================

public m2_level_up(id, new_level)
{
	if (!is_user_connected(id) || !get_pcvar_num(g_pCvarEnable))
		return

	UpdatePlayerStats(id)

	if (get_pcvar_num(g_pCvarShowInfo))
	{
		client_print(id, print_chat, "[Metin2 Bhop] Level %d | Gravity: %.2f | MaxSpeed: %.0f", new_level, g_fPlayerGravity[id], g_fPlayerMaxSpeed[id])
	}
}

// ======================== SPAWN ========================

public RG_PlayerSpawn_Post(const id)
{
	if (!is_user_alive(id) || !get_pcvar_num(g_pCvarEnable))
		return

	set_task(0.4, "Task_UpdateStats", id)
	g_bWasOnGround[id] = false
}

public Task_UpdateStats(id)
{
	if (is_user_alive(id))
		UpdatePlayerStats(id)
}

// ======================== UPDATE STATS ========================

UpdatePlayerStats(id)
{
	if (!is_user_connected(id))
		return

	new level = get_user_m2_level(id)
	if (level < 1) level = 1

	// Gravity
	new Float:base_grav = get_pcvar_float(g_pCvarGravityBase)
	new Float:per_level = get_pcvar_float(g_pCvarGravityPerLevel)
	new Float:min_grav  = get_pcvar_float(g_pCvarGravityMin)

	new Float:new_grav = base_grav - (float(level - 1) * per_level)
	if (new_grav < min_grav)
		new_grav = min_grav

	g_fPlayerGravity[id] = new_grav
	set_entvar(id, var_gravity, new_grav)

	// MaxSpeed
	new Float:base_spd = get_pcvar_float(g_pCvarSpeedBase)
	new Float:spd_per  = get_pcvar_float(g_pCvarSpeedPerLevel)
	new Float:max_spd  = get_pcvar_float(g_pCvarSpeedMax)

	new Float:new_spd = base_spd + (float(level - 1) * spd_per)
	if (new_spd > max_spd)
		new_spd = max_spd

	g_fPlayerMaxSpeed[id] = new_spd
	set_entvar(id, var_maxspeed, new_spd)
}

// ======================== NO FALL DAMAGE ========================

public RG_TakeDamage(const id, pevInflictor, pevAttacker, Float:flDamage, bitsDamageType)
{
	// ---- Fall Damage block (fără SUPERCEDE ca să nu mai dea eroare) ----
	if (get_pcvar_num(g_pCvarNoFallDamage) && (bitsDamageType & DMG_FALL))
	{
		SetHookChainArg(4, ATYPE_FLOAT, 0.0)   // damage = 0
		return HC_CONTINUE                     // important! nu mai folosim SUPERCEDE
	}

	// ---- Damage Indicator ----
	if (flDamage > 0.0 && is_user_connected(pevAttacker) && pevAttacker != id)
	{
		ShowDamageIndicator(pevAttacker, floatround(flDamage))
	}

	return HC_CONTINUE
}

// ======================== BUNNYHOP (ReAPI - fără forțare) ========================

public RG_PlayerPreThink(const id)
{
	if (!is_user_alive(id) || !get_pcvar_num(g_pCvarEnable))
		return HC_CONTINUE

	// Păstrează gravity + maxspeed
	if (g_fPlayerGravity[id] > 0.0)
		set_entvar(id, var_gravity, g_fPlayerGravity[id])

	if (g_fPlayerMaxSpeed[id] > 0.0)
		set_entvar(id, var_maxspeed, g_fPlayerMaxSpeed[id])

	// Extra protecție fall damage
	if (get_pcvar_num(g_pCvarNoFallDamage))
		set_entvar(id, var_flFallVelocity, 0.0)

	if (!get_pcvar_num(g_pCvarBhopEnable))
		return HC_CONTINUE

	new flags = get_entvar(id, var_flags)
	new bool:onGround = bool:(flags & FL_ONGROUND)

	// Doar când tocmai a aterizat
	if (onGround && !g_bWasOnGround[id])
	{
		new buttons = get_entvar(id, var_button)

		// Sari DOAR dacă ține spațiu (sau auto-bhop e activ și ține spațiu)
		// Nu mai forțăm săritura dacă nu apasă nimic
		if (buttons & IN_JUMP)
		{
			new Float:velocity[3]
			get_entvar(id, var_velocity, velocity)

			new Float:speed = floatsqroot(velocity[0]*velocity[0] + velocity[1]*velocity[1])
			new Float:gain = get_pcvar_float(g_pCvarBhopSpeedGain)
			if (gain < 1.01) gain = 1.01

			if (speed > 20.0)
			{
				// Speed gain pe direcția actuală
				velocity[0] *= gain
				velocity[1] *= gain
			}

			// Jump normal
			velocity[2] = 268.0
			set_entvar(id, var_velocity, velocity)

			// Scoatem butonul de jump ca să nu interfereze engine-ul
			set_entvar(id, var_button, buttons & ~IN_JUMP)
		}
		else if (get_pcvar_num(g_pCvarBhopAuto))
		{
			// Auto-bhop clasic: doar permite săritură rapidă dacă ține spațiu
			// (nu forțăm nimic dacă nu ține)
		}
	}

	g_bWasOnGround[id] = onGround

	return HC_CONTINUE
}

// ======================== CLIENT ========================

public client_putinserver(id)
{
	g_fPlayerGravity[id] = 1.0
	g_fPlayerMaxSpeed[id] = 250.0
	g_bWasOnGround[id] = false
}

public client_disconnected(id)
{
	remove_task(id)
	g_fPlayerGravity[id] = 1.0
	g_fPlayerMaxSpeed[id] = 250.0
	g_bWasOnGround[id] = false

	g_fLastDamageTime[id] = 0.0
}
// ======================== DAMAGE INDICATOR ========================

ShowDamageIndicator(attacker, damage)
{
	if (!is_user_connected(attacker) || damage <= 0)
		return

	// Anti-spam (nu arăta mai des de 0.05 secunde)
	new Float:gametime = get_gametime()
	if (gametime - g_fLastDamageTime[attacker] < 0.05)
		return

	g_fLastDamageTime[attacker] = gametime

	// Poziție HUD (centru-sus, deasupra crosshair-ului)
	set_hudmessage(255, 50, 50, -1.0, 0.35, 0, 0.1, 1.2, 0.05, 0.05, -1)

	// Afișăm damage-ul
	ShowSyncHudMsg(attacker, g_iHudSync, "%d", damage)
}
