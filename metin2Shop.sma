/*================================================================================
	Metin2 Shop - Plugin Exterior
	Versiune 1.1 (Fixat & Optimizat)
	
	Shop special cu iteme consumabile (durata = runda)
	Acces: radio1 (Z) / radio2 (X) / radio3 (C)
	Cost: $ (bani CS 1.6)
================================================================================*/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <reapi>
#include <fakemeta>
#include <hamsandwich>
#include <fun>
#include <metin2_api>

#define PLUGIN  "Metin2Shop"
#define VERSION "1.1"
#define AUTHOR  "Craxor"

#define MAX_PLAYERS     32
#define MAX_SPECIAL     24

// ======================== STRUCTURA ITEM SPECIAL ========================
enum _:SpecialItem
{
	SI_Name[48],
	SI_Desc[64],
	SI_Cost,            // pret in $
	SI_Category         // 1=Ofensiv, 2=Defensiv, 3=Special
};

new const g_SpecialItems[MAX_SPECIAL][SpecialItem] =
{
	// ========== RADIO1 - OFENSIV (0-7) ==========
	{ "Inel de Experienta",      "+50% XP din kill-uri",                    5000, 1 },
	{ "Amuletă Critică",         "+30% șansă crit (x2 dmg)",                4500, 1 },
	{ "Brățară de Forță",        "+20 STR temporar",                        3500, 1 },
	{ "Inel de Yang",            "+50% Yang din kill-uri",                  4000, 1 },
	{ "Amuletă Berserk",         "+40% dmg, -15% defense",                  6000, 1 },
	{ "Inel de Piercing",        "Ignoră 35% din armura inamicului",        3800, 1 },
	{ "Amuletă Lifesteal",       "15% din damage ca heal",                  5500, 1 },
	{ "Brățară Skill Power",     "+25% damage general (skill & arma)",      4800, 1 },

	// ========== RADIO2 - DEFENSIV (8-15) ==========
	{ "Amuletă de Armură",       "+35 defense",                             4200, 2 },
	{ "Inel de Viață",           "+60 Max HP",                              3800, 2 },
	{ "Amuletă Regen HP",        "+6 HP / secundă",                         3200, 2 },
	{ "Inel de Mana",            "+80 Max MP + regen accelerat",            4000, 2 },
	{ "Amuletă Reflect",         "Reflectă 25% din damage primit",         5200, 2 },
	{ "Scut Magic",              "Reduce damage-ul primit cu 22%",         4700, 2 },
	{ "Binecuvântare Divină",    "+20 defense + 4 HP/sec",                 5800, 2 },
	{ "Papuci de Vânt",          "+60 viteză de mișcare",                   2800, 2 },

	// ========== RADIO3 - SPECIAL / UTILITY (16-23) ==========
	{ "Pergament Binecuvântat", "Următorul upgrade = 100% succes",        8500, 3 },
	{ "Inel de Noroc",           "+30% Yang extra + șansă bonus XP",        4300, 3 },
	{ "Amuletă de Focus",        "Cooldown skill-uri redus (efectiv)",     6200, 3 },
	{ "Elixir de Putere",        "+12 la toate stat-urile (STR/HP/DEX/INT)", 7500, 3 },
	{ "Piatra Spiritului",       "La kill: +40 MP și +25 HP",               4600, 3 },
	{ "Amuletă Anti-Crit",       "Reduce damage-ul critic primit cu 40%",   3900, 3 },
	{ "Brățară de Evaziune",     "12% șansă să eviți complet un hit",       5100, 3 },
	{ "Inel de Regenerare",      "Regen MP +15 / 2 sec + HP mic",           3400, 3 }
};

// Flag-uri per jucător
new bool:g_BoughtThisRound[MAX_PLAYERS + 1][MAX_SPECIAL];
new bool:g_Active[MAX_PLAYERS + 1][MAX_SPECIAL];

// Evitare recursivitate la Reflect Damage
new bool:g_IsReflectingDamage = false;

// ======================== PRECACHE & INIT ========================
public plugin_precache()
{
	// Sunet esential pentru meniurile CS 1.6 / AMXX
	precache_sound("buttons/bell1.wav");
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	// Acces shop prin radio (Z / X / C)
	register_clcmd("radio1", "cmd_shop_offensive");
	register_clcmd("radio2", "cmd_shop_defensive");
	register_clcmd("radio3", "cmd_shop_special");

	// Alternativ și prin say
	register_clcmd("say /shopm2", "cmd_shop_menu");
	register_clcmd("say /m2shop", "cmd_shop_menu");

	// Round start/end
	RegisterHookChain(RG_CSGameRules_RestartRound, "OnRoundRestart", true);
	register_event("HLTV", "OnRoundStart", "a", "1=0", "2=0");

	// Damage hook
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "OnTakeDamage_Pre", false);
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "OnTakeDamage_Post", true);

	// Spawn - aplică bonusuri HP / speed
	RegisterHookChain(RG_CBasePlayer_Spawn, "OnPlayerSpawn", true);

	// Task pentru regenerare HP/MP
	set_task(1.0, "Task_Regen", _, _, _, "b");
}

public plugin_cfg()
{
	if (!LibraryExists("metin2_rpg", LibType_Library))
	{
		set_fail_state("[Metin2Shop] metin2_rpg library nu a fost găsită! Încarcă mai întâi Metin2Core.");
	}
}

// ======================== ROUND MANAGEMENT ========================
public OnRoundRestart()
{
	for (new id = 1; id <= MaxClients; id++)
	{
		if (is_user_connected(id))
			ClearPlayerBuffs(id);
	}
}

public OnRoundStart()
{
	for (new id = 1; id <= MaxClients; id++)
	{
		if (is_user_connected(id))
			ClearPlayerBuffs(id);
	}
}

stock ClearPlayerBuffs(id)
{
	for (new i = 0; i < MAX_SPECIAL; i++)
	{
		g_BoughtThisRound[id][i] = false;
		g_Active[id][i] = false;
	}

	if (is_user_connected(id) && m2_get_force_upgrade(id))
		m2_set_force_upgrade(id, false);
}

public client_disconnected(id)
{
	ClearPlayerBuffs(id);
}

// ======================== SHOP MENUS ========================
public cmd_shop_offensive(id)
{
	if (!is_user_connected(id)) return PLUGIN_HANDLED;
	ShowShopMenu(id, 1);
	return PLUGIN_HANDLED;
}

public cmd_shop_defensive(id)
{
	if (!is_user_connected(id)) return PLUGIN_HANDLED;
	ShowShopMenu(id, 2);
	return PLUGIN_HANDLED;
}

public cmd_shop_special(id)
{
	if (!is_user_connected(id)) return PLUGIN_HANDLED;
	ShowShopMenu(id, 3);
	return PLUGIN_HANDLED;
}

public cmd_shop_menu(id)
{
	new menu = menu_create("\y[Metin2] Shop Special", "shop_main_handler");
	menu_additem(menu, "\wOfensiv \y(Z / radio1)", "1");
	menu_additem(menu, "\wDefensiv \y(X / radio2)", "2");
	menu_additem(menu, "\wSpecial / Utility \y(C / radio3)", "3");
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_display(id, menu);
	return PLUGIN_HANDLED;
}

public shop_main_handler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new data[6];
	menu_item_getinfo(menu, item, _, data, charsmax(data), _, _, _);
	new cat = str_to_num(data);
	menu_destroy(menu);

	ShowShopMenu(id, cat);
	return PLUGIN_HANDLED;
}

stock ShowShopMenu(id, category)
{
	if (!is_user_connected(id)) return;

	new title[64];
	new money = cs_get_user_money(id);

	switch (category)
	{
		case 1: formatex(title, charsmax(title), "\y[Ofensiv] Shop - $%d", money);
		case 2: formatex(title, charsmax(title), "\y[Defensiv] Shop - $%d", money);
		case 3: formatex(title, charsmax(title), "\y[Special] Shop - $%d", money);
		default: return;
	}

	new menu = menu_create(title, "shop_item_handler");

	for (new i = 0; i < MAX_SPECIAL; i++)
	{
		if (g_SpecialItems[i][SI_Category] != category)
			continue;

		new tmp[96];
		if (g_BoughtThisRound[id][i])
			formatex(tmp, charsmax(tmp), "\d%s - CUMPĂRAT", g_SpecialItems[i][SI_Name]);
		else if (g_Active[id][i])
			formatex(tmp, charsmax(tmp), "\y%s - ACTIV", g_SpecialItems[i][SI_Name]);
		else
			formatex(tmp, charsmax(tmp), "\w%s \y$%d", g_SpecialItems[i][SI_Name], g_SpecialItems[i][SI_Cost]);

		new info[8];
		formatex(info, charsmax(info), "%d", i);
		menu_additem(menu, tmp, info);
	}

	menu_additem(menu, "\rÎnapoi", "99");
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_display(id, menu);
}

public shop_item_handler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new data[8];
	menu_item_getinfo(menu, item, _, data, charsmax(data), _, _, _);
	new idx = str_to_num(data);
	menu_destroy(menu);

	if (idx == 99)
	{
		cmd_shop_menu(id);
		return PLUGIN_HANDLED;
	}

	if (idx < 0 || idx >= MAX_SPECIAL)
		return PLUGIN_HANDLED;

	BuySpecialItem(id, idx);
	return PLUGIN_HANDLED;
}

// ======================== BUY LOGIC ========================
stock BuySpecialItem(id, idx)
{
	if (!is_user_connected(id) || !is_user_alive(id))
	{
		client_print_color(id, print_team_default, "^4[Metin2Shop]^1 Trebuie să fii în viață ca să cumperi!");
		return;
	}

	if (g_BoughtThisRound[id][idx])
	{
		client_print_color(id, print_team_default, "^4[Metin2Shop]^1 Ai cumpărat deja ^3%s^1 în această rundă!", g_SpecialItems[idx][SI_Name]);
		ShowShopMenu(id, g_SpecialItems[idx][SI_Category]);
		return;
	}

	new cost = g_SpecialItems[idx][SI_Cost];
	new money = cs_get_user_money(id);

	if (money < cost)
	{
		client_print_color(id, print_team_default, "^4[Metin2Shop]^1 Nu ai destui bani! Cost: ^3$%d^1 | Ai: ^3$%d", cost, money);
		ShowShopMenu(id, g_SpecialItems[idx][SI_Category]);
		return;
	}

	cs_set_user_money(id, money - cost);

	g_BoughtThisRound[id][idx] = true;
	g_Active[id][idx] = true;

	ApplyItemEffect(id, idx);

	client_print_color(id, print_team_default, "^4[Metin2Shop]^1 Ai cumpărat ^3%s^1 pentru ^3$%d^1!", g_SpecialItems[idx][SI_Name], cost);
	client_print_color(id, print_team_default, "^4[Metin2Shop]^1 Efect: ^3%s^1 | Durată: până la finalul rundei", g_SpecialItems[idx][SI_Desc]);

	ShowShopMenu(id, g_SpecialItems[idx][SI_Category]);
}

// ======================== APPLY EFFECTS ========================
stock ApplyItemEffect(id, idx)
{
	switch (idx)
	{
		case 9: // Inel de Viață +60 Max HP
		{
			if (is_user_alive(id))
			{
				new hp = get_user_health(id);
				set_user_health(id, hp + 60);
			}
		}
		case 11: // Inel de Mana +80 MaxMP
		{
			new maxmp = get_user_m2_maxmp(id);
			set_user_m2_maxmp(id, maxmp + 80);
			set_user_m2_mp(id, get_user_m2_mp(id) + 40);
		}
		case 15: // Papuci de Vânt +60 speed
		{
			if (is_user_alive(id))
			{
				new Float:speed = get_user_maxspeed(id);
				set_user_maxspeed(id, speed + 60.0);
			}
		}
		case 16: // Pergament Binecuvântat
		{
			m2_set_force_upgrade(id, true);
			client_print_color(id, print_team_default, "^4[Metin2Shop]^1 ^3Pergamentul^1 e activ - următorul /upgrade are 100%% succes!");
		}
		case 19: // Elixir de Putere +12 all stats
		{
			new maxmp = get_user_m2_maxmp(id);
			set_user_m2_maxmp(id, maxmp + 96);
			if (is_user_alive(id))
			{
				new hp = get_user_health(id);
				set_user_health(id, hp + 120);
			}
		}
	}
}

// ======================== SPAWN - REAPLICĂ SPEED / HP ========================
public OnPlayerSpawn(id)
{
	if (!is_user_alive(id)) return;

	if (g_Active[id][15]) set_task(0.1, "DelayedSpeed", id);
	if (g_Active[id][9]) set_task(0.15, "DelayedHP", id);
	if (g_Active[id][19]) set_task(0.2, "DelayedElixir", id);
}

public DelayedSpeed(id)
{
	if (is_user_alive(id) && g_Active[id][15])
	{
		new Float:speed = get_user_maxspeed(id);
		set_user_maxspeed(id, speed + 60.0);
	}
}

public DelayedHP(id)
{
	if (is_user_alive(id) && g_Active[id][9])
	{
		new hp = get_user_health(id);
		set_user_health(id, hp + 60);
	}
}

public DelayedElixir(id)
{
	if (is_user_alive(id) && g_Active[id][19])
	{
		new hp = get_user_health(id);
		set_user_health(id, hp + 120);
	}
}

// ======================== DAMAGE HOOKS ========================
public OnTakeDamage_Pre(victim, inflictor, attacker, Float:damage, damagebits)
{
	if (!is_user_connected(attacker) || !is_user_connected(victim))
		return HC_CONTINUE;
	if (attacker == victim)
		return HC_CONTINUE;

	new Float:final = damage;

	// === ATTACKER BUFFS ===
	if (is_user_alive(attacker))
	{
		// Crit (idx 1)
		if (g_Active[attacker][1] && random_num(1, 100) <= 30)
		{
			final *= 2.0;
			client_print_color(attacker, print_team_default, "^4[Metin2Shop]^1 ^3CRITIC^1 cu Amuletă Critică!");
		}

		// Brățară STR (idx 2)
		if (g_Active[attacker][2]) final += 30.0;

		// Berserk (idx 4) +40% dmg
		if (g_Active[attacker][4]) final *= 1.40;

		// Skill Power (idx 7) +25%
		if (g_Active[attacker][7]) final *= 1.25;

		// Elixir (idx 19)
		if (g_Active[attacker][19]) final += 18.0;
	}

	// === VICTIM BUFFS ===
	if (is_user_alive(victim))
	{
		// Evaziune (idx 22) 12%
		if (g_Active[victim][22] && random_num(1, 100) <= 12)
		{
			SetHookChainArg(4, ATYPE_FLOAT, 0.0);
			client_print_color(victim, print_team_default, "^4[Metin2Shop]^1 ^3EVAZIUNE^1! Ai evitat hit-ul.");
			return HC_CONTINUE;
		}

		// Scut Magic (idx 13) -22%
		if (g_Active[victim][13]) final *= 0.78;

		// Armură (idx 8) +35 defense
		if (g_Active[victim][8]) final -= 35.0;

		// Binecuvântare (idx 14) +20 defense
		if (g_Active[victim][14]) final -= 20.0;

		// Anti-Crit (idx 21)
		if (g_Active[victim][21] && final > damage * 1.5) final *= 0.60;

		// Elixir defense
		if (g_Active[victim][19]) final -= 12.0;
	}

	// Piercing
	if (is_user_alive(attacker) && g_Active[attacker][5])
	{
		final *= 1.15;
	}

	if (final < 1.0) final = 1.0;

	SetHookChainArg(4, ATYPE_FLOAT, final);
	return HC_CONTINUE;
}

public OnTakeDamage_Post(victim, inflictor, attacker, Float:damage, damagebits)
{
	if (!is_user_connected(attacker) || !is_user_connected(victim))
		return HC_CONTINUE;
	if (attacker == victim || damage < 1.0)
		return HC_CONTINUE;

	// Lifesteal (idx 6)
	if (g_Active[attacker][6] && is_user_alive(attacker))
	{
		new heal = floatround(damage * 0.15);
		if (heal > 0)
		{
			new hp = get_user_health(attacker);
			set_user_health(attacker, hp + heal);
		}
	}

	// Reflect (idx 12) - Prevenire Buclă Infinită / Crash
	if (g_Active[victim][12] && is_user_alive(attacker) && !g_IsReflectingDamage)
	{
		new Float:reflect = damage * 0.25;
		if (reflect > 0.0)
		{
			g_IsReflectingDamage = true;
			ExecuteHamB(Ham_TakeDamage, attacker, victim, victim, reflect, DMG_GENERIC);
			g_IsReflectingDamage = false;
		}
	}

	return HC_CONTINUE;
}

// ======================== FORWARD m2_player_kill ========================
public m2_player_kill(killer, victim, xp, yang)
{
	if (!is_user_connected(killer))
		return;

	new extra_xp = 0;
	new extra_yang = 0;

	// Inel XP (0)
	if (g_Active[killer][0])
	{
		extra_xp = xp / 2;
		client_print_color(killer, print_team_default, "^4[Metin2Shop]^1 Inel XP: ^3+%d XP^1 bonus!", extra_xp);
	}

	// Inel Yang (3)
	if (g_Active[killer][3])
	{
		extra_yang = yang / 2;
		client_print_color(killer, print_team_default, "^4[Metin2Shop]^1 Inel Yang: ^3+%d Yang^1 bonus!", extra_yang);
	}

	// Inel de Noroc (17)
	if (g_Active[killer][17])
	{
		extra_yang += yang * 30 / 100;
		if (random_num(1, 100) <= 25)
		{
			new bonus = xp / 3;
			extra_xp += bonus;
			client_print_color(killer, print_team_default, "^4[Metin2Shop]^1 Noroc: ^3+%d XP^1 extra!", bonus);
		}
	}

	// Piatra Spiritului (20)
	if (g_Active[killer][20])
	{
		new mp = get_user_m2_mp(killer);
		new maxmp = get_user_m2_maxmp(killer);
		set_user_m2_mp(killer, min(mp + 40, maxmp));

		if (is_user_alive(killer))
		{
			new hp = get_user_health(killer);
			set_user_health(killer, hp + 25);
		}
		client_print_color(killer, print_team_default, "^4[Metin2Shop]^1 Piatra Spiritului: ^3+40 MP / +25 HP^1");
	}

	if (extra_xp > 0)
	{
		new current = get_user_m2_xp(killer);
		set_user_m2_xp(killer, current + extra_xp);
	}

	if (extra_yang > 0)
	{
		new current = get_user_m2_yang(killer);
		set_user_m2_yang(killer, current + extra_yang);
	}
}

// ======================== REGEN TASK ========================
public Task_Regen()
{
	static sec_counter = 0;
	sec_counter++;

	for (new id = 1; id <= MaxClients; id++)
	{
		if (!is_user_alive(id)) continue;

		// Regen HP (idx 10) +6/sec
		if (g_Active[id][10])
		{
			set_user_health(id, get_user_health(id) + 6);
		}

		// Binecuvântare (idx 14) +4 HP/sec
		if (g_Active[id][14])
		{
			set_user_health(id, get_user_health(id) + 4);
		}

		// Inel Mana (idx 11)
		if (g_Active[id][11])
		{
			new mp = get_user_m2_mp(id);
			new maxmp = get_user_m2_maxmp(id);
			if (mp < maxmp) set_user_m2_mp(id, min(mp + 8, maxmp));
		}

		// Inel Regenerare (idx 23) la fiecare 2 secunde
		if (g_Active[id][23] && (sec_counter % 2 == 0))
		{
			new mp = get_user_m2_mp(id);
			new maxmp = get_user_m2_maxmp(id);
			set_user_m2_mp(id, min(mp + 15, maxmp));
			set_user_health(id, get_user_health(id) + 3);
		}
	}
}

// ======================== INFO LA CONNECT ========================
public client_putinserver(id)
{
	set_task(5.0, "Task_WelcomeShop", id);
}

public Task_WelcomeShop(id)
{
	if (!is_user_connected(id)) return;

	client_print_color(id, print_team_default, "^4[Metin2Shop]^1 Shop special disponibil!");
	client_print_color(id, print_team_default, "^4[Metin2Shop]^1 Apasă ^3Z^1 (Ofensiv) | ^3X^1 (Defensiv) | ^3C^1 (Special)");
	client_print_color(id, print_team_default, "^4[Metin2Shop]^1 Sau scrie ^3/m2shop^1 | Itemele țin până la finalul rundei.");
}
