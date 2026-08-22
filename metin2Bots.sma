#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <metin2_api>

#define PLUGIN  "Metin2 Bots Manager"
#define VERSION "1.1"
#define AUTHOR  "Grok"

// Cât de des verificăm boții (secunde)
#define CHECK_INTERVAL  8.0

// Câte puncte de status dăm per level (aproximativ)
#define STATS_PER_LEVEL 1

new bool:g_bProcessed[33];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1);

	// Verificare periodică
	set_task(CHECK_INTERVAL, "Task_CheckBots", _, _, _, "b");
}

public client_putinserver(id)
{
	g_bProcessed[id] = false;
}

public client_disconnected(id)
{
	g_bProcessed[id] = false;
}

public fw_PlayerSpawn_Post(id)
{
	if (!is_user_connected(id) || !is_user_bot(id))
		return;

	// Mic delay ca să aibă timp core-ul să încarce datele
	set_task(1.5, "Task_ProcessBot", id);
}

public Task_CheckBots()
{
	for (new id = 1; id <= MaxClients; id++)
	{
		if (!is_user_connected(id) || !is_user_bot(id) || !is_user_alive(id))
			continue;

		ProcessBot(id);
	}
}

public Task_ProcessBot(id)
{
	if (!is_user_connected(id) || !is_user_bot(id))
		return;

	ProcessBot(id);
}

stock ProcessBot(id)
{
	if (!is_user_connected(id) || !is_user_bot(id))
		return;

	new race = get_user_m2_race(id);

	// 1. Dacă nu are rasă → îi alegem una random
	if (race == M2_RACE_NONE)
	{
		race = random_num(M2_RACE_WARRIOR, M2_RACE_SHAMAN);
		set_user_m2_race(id, race);

		// Mesaj opțional în consolă (poți șterge)
		new name[32];
		get_user_name(id, name, charsmax(name));
		server_print("[Metin2 Bots] %s a primit rasa: %d", name, race);
	}

	// 2. Distribuim statusurile în funcție de rasă + level
	DistributeStats(id, race);

	g_bProcessed[id] = true;
}

stock DistributeStats(id, race)
{
	new level = get_user_m2_level(id);
	if (level < 1) level = 1;

	// Total puncte pe care le considerăm "normale" la level-ul ăsta
	// (1 punct per level + 5 de start)
	new total_points = 5 + (level * STATS_PER_LEVEL);

	new str, hp, dex, intt;

	switch (race)
	{
		case M2_RACE_WARRIOR:
		{
			// Tank / Damage: STR + HP
			str  = floatround(total_points * 0.40);
			hp   = floatround(total_points * 0.35);
			dex  = floatround(total_points * 0.15);
			intt = total_points - str - hp - dex;
		}
		case M2_RACE_SURA:
		{
			// Magic / Hybrid: INT + STR
			intt = floatround(total_points * 0.40);
			str  = floatround(total_points * 0.30);
			hp   = floatround(total_points * 0.20);
			dex  = total_points - intt - str - hp;
		}
		case M2_RACE_NINJA:
		{
			// Agility / Crit: DEX + STR
			dex  = floatround(total_points * 0.40);
			str  = floatround(total_points * 0.30);
			hp   = floatround(total_points * 0.20);
			intt = total_points - dex - str - hp;
		}
		case M2_RACE_SHAMAN:
		{
			// Support / Magic: INT + HP
			intt = floatround(total_points * 0.40);
			hp   = floatround(total_points * 0.30);
			str  = floatround(total_points * 0.15);
			dex  = total_points - intt - hp - str;
		}
		default:
		{
			// Fallback egal
			str = hp = dex = intt = total_points / 4;
		}
	}

	// Minim 1 la fiecare
	if (str  < 1) str  = 1;
	if (hp   < 1) hp   = 1;
	if (dex  < 1) dex  = 1;
	if (intt < 1) intt = 1;

	// Setăm valorile
	set_user_m2_str(id, str);
	set_user_m2_hp(id, hp);
	set_user_m2_dex(id, dex);
	set_user_m2_int(id, intt);
}

// ======================== COMENZI ADMIN (opțional) ========================

public plugin_cfg()
{
	register_concmd("m2_bots_force", "cmd_force_bots", ADMIN_KICK, "Forțează procesarea tuturor boților acum");
}

public cmd_force_bots(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	new count = 0;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (is_user_connected(i) && is_user_bot(i))
		{
			ProcessBot(i);
			count++;
		}
	}

	console_print(id, "[Metin2 Bots] Au fost procesați %d boți.", count);
	return PLUGIN_HANDLED;
}
