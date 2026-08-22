#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <metin2_api>

#define PLUGIN  "Metin2 Race Abilities"
#define VERSION "1.2"
#define AUTHOR  "Grok"

// Cvars
new cvar_bhop_speed
new cvar_multi_jump_force
new cvar_parachute_speed
new cvar_shaman_gravity

// Player data
new bool:g_bHasRace[33]
new g_iRace[33]
new Float:g_flLastJump[33]
new g_iJumps[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	// Cvars
	cvar_bhop_speed         = register_cvar("m2_bhop_speed", "350.0")          // viteza maximă de bază pe care o prinde
	cvar_multi_jump_force   = register_cvar("m2_multijump_force", "280.0")     // forța multi-jump Sura
	cvar_parachute_speed    = register_cvar("m2_parachute_speed", "80.0")      // viteza maximă de cădere cu parachute
	cvar_shaman_gravity     = register_cvar("m2_shaman_gravity", "0.875")      // 700 / 800 = 0.875
	
	// Hooks
	RegisterHam(Ham_Player_Jump, "player", "fw_PlayerJump", 0)
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
	
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_PlayerPreThink, "fw_PlayerPreThink")
	
	// Forward-uri Metin2
	register_forward(FM_ClientDisconnect, "fw_ClientDisconnect")
}

public client_putinserver(id)
{
	reset_player(id)
}

public fw_ClientDisconnect(id)
{
	reset_player(id)
}

reset_player(id)
{
	g_bHasRace[id] = false
	g_iRace[id] = M2_RACE_NONE
	g_flLastJump[id] = 0.0
	g_iJumps[id] = 0
}

// ======================== RACE CHECK ========================

public client_PreThink(id)
{
	if (!is_user_alive(id))
		return
	
	// Actualizăm rasa la fiecare frame (sigur și simplu)
	new race = get_user_m2_race(id)
	
	if (race != g_iRace[id])
	{
		g_iRace[id] = race
		g_bHasRace[id] = (race != M2_RACE_NONE)
		
		// Aplicăm gravitația specială pentru Shaman
		if (race == M2_RACE_SHAMAN)
			set_pev(id, pev_gravity, get_pcvar_float(cvar_shaman_gravity))
		else
			set_pev(id, pev_gravity, 1.0)
	}
}

// ======================== NINJA - BUNNYHOP NELIMITAT ========================

public fw_PlayerJump(id)
{
	if (!is_user_alive(id) || !g_bHasRace[id])
		return HAM_IGNORED
	
	if (g_iRace[id] != M2_RACE_NINJA)
		return HAM_IGNORED
	
	// Auto-Bhop + prinde viteză
	new button = pev(id, pev_button)
	new oldbuttons = pev(id, pev_oldbuttons)
	
	if ((button & IN_JUMP) && !(oldbuttons & IN_JUMP))
	{
		new flags = pev(id, pev_flags)
		
		if (flags & FL_ONGROUND)
		{
			new Float:velocity[3]
			pev(id, pev_velocity, velocity)
			
			// Calculăm viteza curentă pe orizontală
			new Float:speed = floatsqroot(velocity[0]*velocity[0] + velocity[1]*velocity[1])
			
			// Prindem viteză (nelimitat)
			new Float:max_speed = get_pcvar_float(cvar_bhop_speed)
			
			if (speed < max_speed)
			{
				// Boost controlat
				new Float:boost = 1.15
				velocity[0] *= boost
				velocity[1] *= boost
			}
			else
			{
				// Menținem viteza mare (nu o tăiem)
				// Poți crește și mai mult dacă vrei
				new Float:extra = 1.03
				velocity[0] *= extra
				velocity[1] *= extra
			}
			
			// Forța verticală standard
			velocity[2] = 250.0
			
			set_pev(id, pev_velocity, velocity)
			
			// Previne double jump-ul nativ pe ground
			set_pev(id, pev_oldbuttons, oldbuttons | IN_JUMP)
		}
	}
	
	return HAM_IGNORED
}

// ======================== SURA - MULTI JUMP NELIMITAT ========================

public fw_CmdStart(id, uc_handle, seed)
{
	if (!is_user_alive(id) || !g_bHasRace[id])
		return FMRES_IGNORED
	
	if (g_iRace[id] != M2_RACE_SURA)
		return FMRES_IGNORED
	
	new buttons = get_uc(uc_handle, UC_Buttons)
	new oldbuttons = pev(id, pev_oldbuttons)
	new flags = pev(id, pev_flags)
	
	// Multi-jump nelimitat
	if ((buttons & IN_JUMP) && !(oldbuttons & IN_JUMP) && !(flags & FL_ONGROUND))
	{
		new Float:velocity[3]
		pev(id, pev_velocity, velocity)
		
		velocity[2] = get_pcvar_float(cvar_multi_jump_force)
		
		set_pev(id, pev_velocity, velocity)
		
		// Resetăm butonul ca să nu se blocheze
		set_uc(uc_handle, UC_Buttons, buttons & ~IN_JUMP)
		set_pev(id, pev_oldbuttons, oldbuttons | IN_JUMP)
		
		g_iJumps[id]++
	}
	
	// Reset jump counter când atingi solul
	if (flags & FL_ONGROUND)
		g_iJumps[id] = 0
	
	return FMRES_IGNORED
}

// ======================== SHAMAN - PARACHUTE + GRAVITY ========================

public fw_PlayerPreThink(id)
{
	if (!is_user_alive(id) || !g_bHasRace[id])
		return FMRES_IGNORED
	
	if (g_iRace[id] != M2_RACE_SHAMAN)
		return FMRES_IGNORED
	
	// Gravitație permanentă mai mică
	set_pev(id, pev_gravity, get_pcvar_float(cvar_shaman_gravity))
	
	// Parachute când ține E (IN_USE)
	new button = pev(id, pev_button)
	
	if (button & IN_USE)
	{
		new Float:velocity[3]
		pev(id, pev_velocity, velocity)
		
		// Dacă cade
		if (velocity[2] < 0.0)
		{
			new Float:max_fall = -get_pcvar_float(cvar_parachute_speed)
			
			if (velocity[2] < max_fall)
			{
				velocity[2] = max_fall
				set_pev(id, pev_velocity, velocity)
			}
			
			// Efect vizual opțional (poți activa dacă vrei)
			// message_begin(MSG_ONE, get_user_msgid("ScreenFade"), _, id)
			// ...
		}
	}
	
	return FMRES_IGNORED
}

// ======================== WARRIOR - ANTI FALL DAMAGE ========================

public fw_TakeDamage(victim, inflictor, attacker, Float:damage, damage_type)
{
	if (!is_user_alive(victim) || !g_bHasRace[victim])
		return HAM_IGNORED
	
	if (g_iRace[victim] != M2_RACE_WARRIOR)
		return HAM_IGNORED
	
	// DMG_FALL = (1<<5) = 32
	if (damage_type & DMG_FALL)
	{
		return HAM_SUPERCEDE  // blochează complet damage-ul de cădere
	}
	
	return HAM_IGNORED
}

// ======================== EXTRA: Reset la spawn ========================

public client_spawn(id)
{
	if (!is_user_connected(id))
		return
	
	g_iJumps[id] = 0
	
	// Reaplică gravitația dacă e Shaman
	if (get_user_m2_race(id) == M2_RACE_SHAMAN)
		set_pev(id, pev_gravity, get_pcvar_float(cvar_shaman_gravity))
	else
		set_pev(id, pev_gravity, 1.0)
}
