#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <fakemeta>
#include <metin2_api>          // API-ul tău

#define PLUGIN  "Metin2 Auto Respawn"
#define VERSION "1.1"
#define AUTHOR  "Craxor"

#define TASK_RESPAWN_BASE     55100
#define TASK_RESPAWN_DELAY    55200
#define RESPAWN_DELAY_TIME    60.0

new cvar_xp_loss;
new cvar_yang_loss;
new cvar_enabled;

new Float:g_DeathOrigin[33][3];
new bool:g_WaitingRespawn[33];
new g_MenuOpen[33];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	cvar_enabled   = register_cvar("m2_autorespawn", "1");
	cvar_xp_loss   = register_cvar("m2_respawn_xp_loss", "50");      // XP pierdut la revive
	cvar_yang_loss = register_cvar("m2_respawn_yang_loss", "300");  // Yang pierdut la revive
	
	register_event("DeathMsg", "Event_Death", "a");
	
	RegisterHookChain(RG_CBasePlayer_Spawn, "OnPlayerSpawn", true);
}

public client_disconnected(id)
{
	remove_task(id + TASK_RESPAWN_BASE);
	remove_task(id + TASK_RESPAWN_DELAY);
	g_WaitingRespawn[id] = false;
	g_MenuOpen[id] = 0;
}

public Event_Death()
{
	if (!get_pcvar_num(cvar_enabled))
		return;
	
	new victim = read_data(2);
	
	if (!is_user_connected(victim) || is_user_bot(victim))
		return;
	
	if (!m2_has_race(victim))
		return;
	
	// Salvează locația morții
	pev(victim, pev_origin, g_DeathOrigin[victim]);
	
	g_WaitingRespawn[victim] = true;
	
	// Afișează meniul după o mică întârziere (ca să nu se închidă imediat)
	set_task(0.8, "ShowRespawnMenu", victim);
}

public ShowRespawnMenu(id)
{
	if (!is_user_connected(id) || is_user_alive(id) || !g_WaitingRespawn[id])
		return;
	
	new menu = menu_create("\y[Metin2] Respawn", "RespawnMenuHandler");
	
	menu_additem(menu, "\wRespawn in \yBAZA\w (instant)", "1");
	menu_additem(menu, "\wRespawn pe locul mortii \r(60 secunde)", "2");
	
	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);   // nu poate închide meniul
	menu_display(id, menu, 0);
	
	g_MenuOpen[id] = menu;
}

public RespawnMenuHandler(id, menu, item)
{
	if (!is_user_connected(id) || is_user_alive(id))
	{
		menu_destroy(menu);
		g_MenuOpen[id] = 0;
		return PLUGIN_HANDLED;
	}
	
	new data[6], access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), _, _, callback);
	
	new key = str_to_num(data);
	
	menu_destroy(menu);
	g_MenuOpen[id] = 0;
	
	switch (key)
	{
		case 1: // Respawn în bază (instant)
		{
			ApplyDeathPenalty(id);
			RespawnInBase(id);
		}
		case 2: // Respawn pe locul morții după 60s
		{
			client_print_color(id, print_team_default, "^4[Metin2]^1 Vei renvia pe locul mortii in ^3%.0f secunde^1...", RESPAWN_DELAY_TIME);
			
			set_task(RESPAWN_DELAY_TIME, "DelayedRespawnAtDeath", id + TASK_RESPAWN_DELAY);
		}
	}
	
	return PLUGIN_HANDLED;
}

public DelayedRespawnAtDeath(taskid)
{
	new id = taskid - TASK_RESPAWN_DELAY;
	
	if (!is_user_connected(id) || is_user_alive(id) || !g_WaitingRespawn[id])
		return;
	
	ApplyDeathPenalty(id);
	RespawnAtDeathLocation(id);
}

stock ApplyDeathPenalty(id)
{
	new xp_loss   = get_pcvar_num(cvar_xp_loss);
	new yang_loss = get_pcvar_num(cvar_yang_loss);
	
	if (xp_loss > 0)
	{
		new current_xp = get_user_m2_xp(id);
		new new_xp = current_xp - xp_loss;
		if (new_xp < 0) new_xp = 0;
		
		set_user_m2_xp(id, new_xp);
	}
	
	if (yang_loss > 0)
	{
		new current_yang = get_user_m2_yang(id);
		new new_yang = current_yang - yang_loss;
		if (new_yang < 0) new_yang = 0;
		
		set_user_m2_yang(id, new_yang);
	}
	
	if (xp_loss > 0 || yang_loss > 0)
	{
		client_print_color(id, print_team_default, "^4[Metin2]^1 Ai pierdut ^3%d XP^1 si ^3%d Yang^1 la revive.", xp_loss, yang_loss);
	}
}

stock RespawnInBase(id)
{
	if (!is_user_connected(id) || is_user_alive(id))
		return;
	
	g_WaitingRespawn[id] = false;
	
	rg_round_respawn(id);
	
	client_print_color(id, print_team_default, "^4[Metin2]^1 Ai renviat in ^3baza^1!");
}

stock RespawnAtDeathLocation(id)
{
	if (!is_user_connected(id) || is_user_alive(id))
		return;
	
	g_WaitingRespawn[id] = false;
	
	rg_round_respawn(id);
	
	new Float:origin[3];
	origin[0] = g_DeathOrigin[id][0];
	origin[1] = g_DeathOrigin[id][1];
	origin[2] = g_DeathOrigin[id][2] + 15.0;
	
	// Verifică dacă locația e sigură, altfel caută una în apropiere
	if (!IsSafeOrigin(id, origin))
	{
		if (!FindSafeOriginNearby(id, origin, 180.0))
		{
			// Ultimă soluție: respawn normal în bază
			client_print_color(id, print_team_default, "^4[Metin2]^1 Locația era prea îngustă. Ai fost trimis in baza.");
			RespawnInBase(id);
			return;
		}
	}
	
	set_pev(id, pev_origin, origin);
	
	client_print_color(id, print_team_default, "^4[Metin2]^1 Ai renviat pe locul mortii!");
}

// Verifică dacă un origin este liber (nu e în perete / prea îngust)
stock bool:IsSafeOrigin(id, const Float:origin[3])
{
	new Float:mins[3], Float:maxs[3];
	pev(id, pev_mins, mins);
	pev(id, pev_maxs, maxs);
	
	// TraceHull jos-sus
	new tr = create_tr2();
	engfunc(EngFunc_TraceHull, origin, origin, DONT_IGNORE_MONSTERS, HULL_HUMAN, id, tr);
	
	new bool:safe = (get_tr2(tr, TR_StartSolid) == 0 && get_tr2(tr, TR_AllSolid) == 0);
	free_tr2(tr);
	
	return safe;
}

// Caută un loc liber în raza specificată
stock bool:FindSafeOriginNearby(id, Float:origin[3], Float:radius)
{
	new Float:test[3];
	new Float:angle, Float:dist;
	
	for (new i = 0; i < 16; i++)
	{
		angle = float(i) * (360.0 / 16.0);
		dist = radius * (0.4 + float(i % 3) * 0.3);
		
		test[0] = origin[0] + floatcos(angle, degrees) * dist;
		test[1] = origin[1] + floatsin(angle, degrees) * dist;
		test[2] = origin[2];
		
		// Ridică puțin și verifică
		test[2] += 10.0;
		
		if (IsSafeOrigin(id, test))
		{
			origin[0] = test[0];
			origin[1] = test[1];
			origin[2] = test[2];
			return true;
		}
	}
	
	return false;
}

public OnPlayerSpawn(id)
{
	// Dacă jucătorul a renviat normal (nu prin meniu), curățăm flag-urile
	if (g_WaitingRespawn[id])
	{
		remove_task(id + TASK_RESPAWN_DELAY);
		g_WaitingRespawn[id] = false;
	}
	
	if (g_MenuOpen[id])
	{
		// forțează închiderea meniului dacă încă e deschis
		menu_destroy(g_MenuOpen[id]);
		g_MenuOpen[id] = 0;
	}
}
