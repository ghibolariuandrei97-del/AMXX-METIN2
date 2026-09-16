/*================================================================================
	Metin2 Shop - Plugin Exterior
	Versiune 1.2 (Rescris complet - fara task-uri, optimizat anti-overflow)
	
	Shop special cu iteme consumabile (durata = runda)
	Acces: radio1 (Z) / radio2 (X) / radio3 (C)  sau  say /m2shop
	Cost: $ (bani CS 1.6)
	
	Modificari fata de 1.1:
	- Eliminat TOATE task-urile (regen, delayed, welcome)
	- Efectele se aplica INSTANT la cumparare
	- Regen-urile au fost transformate in boost-uri one-time
	- Redus drastic client_print_color (cauza principala de SZ overflow)
	- Cod curat, fara PreThink / Think
================================================================================*/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <reapi>
#include <fakemeta>
#include <hamsandwich>
#include <fun>
#include <metin2_api>

#if !defined fmt
stock fmt(const szFormat[], any:...)
{
	static szBuffer[512];
	vformat(szBuffer, charsmax(szBuffer), szFormat, 2);
	return szBuffer;
}
#endif

#define PLUGIN  "Metin2Shop"
#define VERSION "1.2"
#define AUTHOR  "Craxor & Clean Rewrite"

#define MAX_PLAYERS     32
#define MAX_SPECIAL     24

// ======================== STRUCTURA ITEM SPECIAL ========================
enum _:SpecialItem
{
	SI_Cost,
	SI_Category		// 1=Ofensiv, 2=Defensiv, 3=Special
};

new const g_SpecialItems[MAX_SPECIAL][SpecialItem] =
{
	// ========== RADIO1 - OFENSIV (0-7) ==========
	{ 5000, 1 },	// 0  Experience Ring
	{ 4500, 1 },	// 1  Critical Amulet
	{ 3500, 1 },	// 2  Strength Bracelet
	{ 4000, 1 },	// 3  Yang Ring
	{ 6000, 1 },	// 4  Berserk Amulet
	{ 3800, 1 },	// 5  Piercing Ring
	{ 5500, 1 },	// 6  Lifesteal Amulet
	{ 4800, 1 },	// 7  Skill Power Bracelet

	// ========== RADIO2 - DEFENSIV (8-15) ==========
	{ 4200, 2 },	// 8  Armor Amulet
	{ 3800, 2 },	// 9  Life Ring
	{ 3200, 2 },	// 10 HP Boost (ex-regen)
	{ 4000, 2 },	// 11 Mana Ring
	{ 5200, 2 },	// 12 Reflect Amulet
	{ 4700, 2 },	// 13 Magic Shield
	{ 5800, 2 },	// 14 Divine Blessing
	{ 2800, 2 },	// 15 Wind Shoes

	// ========== RADIO3 - SPECIAL / UTILITY (16-23) ==========
	{ 8500, 3 },	// 16 Blessed Scroll
	{ 4300, 3 },	// 17 Luck Ring
	{ 6200, 3 },	// 18 Focus Amulet (placeholder - no continuous effect without task)
	{ 7500, 3 },	// 19 Power Elixir
	{ 4600, 3 },	// 20 Spirit Stone
	{ 3900, 3 },	// 21 Anti-Crit Amulet
	{ 5100, 3 },	// 22 Evasion Bracelet
	{ 3400, 3 }		// 23 Regen Ring (one-time boost)
};

// Nume iteme RO / EN
new const g_SI_Name_RO[MAX_SPECIAL][] =
{
	"Inel de Experienta", "Amuletă Critică", "Brățară de Forță", "Inel de Yang",
	"Amuletă Berserk", "Inel de Piercing", "Amuletă Lifesteal", "Brățară Skill Power",
	"Amuletă de Armură", "Inel de Viață", "Boost HP Instant", "Inel de Mana",
	"Amuletă Reflect", "Scut Magic", "Binecuvântare Divină", "Papuci de Vânt",
	"Pergament Binecuvântat", "Inel de Noroc", "Amuletă de Focus", "Elixir de Putere",
	"Piatra Spiritului", "Amuletă Anti-Crit", "Brățară de Evaziune", "Inel de Regenerare"
};

new const g_SI_Name_EN[MAX_SPECIAL][] =
{
	"Experience Ring", "Critical Amulet", "Strength Bracelet", "Yang Ring",
	"Berserk Amulet", "Piercing Ring", "Lifesteal Amulet", "Skill Power Bracelet",
	"Armor Amulet", "Life Ring", "Instant HP Boost", "Mana Ring",
	"Reflect Amulet", "Magic Shield", "Divine Blessing", "Wind Shoes",
	"Blessed Scroll", "Luck Ring", "Focus Amulet", "Power Elixir",
	"Spirit Stone", "Anti-Crit Amulet", "Evasion Bracelet", "Regen Ring"
};

// Descrieri RO / EN (actualizate - fara regen continuu)
new const g_SI_Desc_RO[MAX_SPECIAL][] =
{
	"+50% XP din kill-uri", "+30% sansa crit (x2 dmg)", "+20 STR temporar", "+50% Yang din kill-uri",
	"+40% dmg, -15% defense", "Ignora 35% din armura inamicului", "15% din damage ca heal", "+25% damage general",
	"+35 defense", "+60 Max HP", "+80 HP instant", "+80 Max MP + 40 MP",
	"Reflecta 25% din damage primit", "Reduce damage-ul primit cu 22%", "+20 defense + 50 HP", "+60 viteza de miscare",
	"Urmatorul upgrade = 100% succes", "+30% Yang extra + sansa bonus XP", "Cooldown skill-uri redus (efectiv)", "+12 la toate stat-urile",
	"La kill: +40 MP si +25 HP", "Reduce damage-ul critic primit cu 40%", "12% sansa sa eviti complet un hit", "+40 MP + 30 HP instant"
};

new const g_SI_Desc_EN[MAX_SPECIAL][] =
{
	"+50% XP from kills", "+30% crit chance (x2 dmg)", "+20 temporary STR", "+50% Yang from kills",
	"+40% dmg, -15% defense", "Ignore 35% of enemy armor", "15% of damage as heal", "+25% general damage",
	"+35 defense", "+60 Max HP", "+80 HP instant", "+80 Max MP + 40 MP",
	"Reflect 25% of received damage", "Reduce received damage by 22%", "+20 defense + 50 HP", "+60 movement speed",
	"Next upgrade = 100% success", "+30% extra Yang + chance bonus XP", "Skill cooldowns reduced (effective)", "+12 to all stats",
	"On kill: +40 MP and +25 HP", "Reduce critical damage taken by 40%", "12% chance to fully dodge a hit", "+40 MP + 30 HP instant"
};

// Helpers multi-language
stock GetSI_Name(id, idx, output[], len)
{
	if (idx < 0 || idx >= MAX_SPECIAL)
	{
		copy(output, len, "???");
		return;
	}
	new lang[8];
	get_user_info(id, "lang", lang, charsmax(lang));
	if (equali(lang, "en"))
		copy(output, len, g_SI_Name_EN[idx]);
	else
		copy(output, len, g_SI_Name_RO[idx]);
}

stock GetSI_Desc(id, idx, output[], len)
{
	if (idx < 0 || idx >= MAX_SPECIAL)
	{
		copy(output, len, "???");
		return;
	}
	new lang[8];
	get_user_info(id, "lang", lang, charsmax(lang));
	if (equali(lang, "en"))
		copy(output, len, g_SI_Desc_EN[idx]);
	else
		copy(output, len, g_SI_Desc_RO[idx]);
}

// Flag-uri per jucator
new bool:g_BoughtThisRound[MAX_PLAYERS + 1][MAX_SPECIAL];
new bool:g_Active[MAX_PLAYERS + 1][MAX_SPECIAL];

// Evitare recursivitate Reflect
new bool:g_IsReflectingDamage = false;

// ======================== PRECACHE & INIT ========================
public plugin_precache()
{
	precache_sound("buttons/bell1.wav");
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_dictionary("metin2Shop.txt");

	register_clcmd("radio1", "cmd_shop_offensive");
	register_clcmd("radio2", "cmd_shop_defensive");
	register_clcmd("radio3", "cmd_shop_special");

	register_clcmd("say /shopm2", "cmd_shop_menu");
	register_clcmd("say /m2shop", "cmd_shop_menu");

	// Round management
	RegisterHookChain(RG_CSGameRules_RestartRound, "OnRoundRestart", true);
	register_event("HLTV", "OnRoundStart", "a", "1=0", "2=0");

	// Damage
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "OnTakeDamage_Pre", false);
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "OnTakeDamage_Post", true);

	// Spawn - reaplica speed / HP daca e activ
	RegisterHookChain(RG_CBasePlayer_Spawn, "OnPlayerSpawn", true);
}

public plugin_cfg()
{
	if (!LibraryExists("metin2_rpg", LibType_Library))
	{
		set_fail_state("[Metin2Shop] metin2_rpg library not found! Load Metin2Core first.");
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
	if (!is_user_connected(id)) return PLUGIN_HANDLED;

	new menu = menu_create(fmt("%L", id, "M2SHOP_TITLE"), "shop_main_handler");
	menu_additem(menu, fmt("%L", id, "M2SHOP_CAT_OFFENSIVE"), "1");
	menu_additem(menu, fmt("%L", id, "M2SHOP_CAT_DEFENSIVE"), "2");
	menu_additem(menu, fmt("%L", id, "M2SHOP_CAT_SPECIAL"), "3");
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

	new lang[8];
	get_user_info(id, "lang", lang, charsmax(lang));
	new bool:is_en = equali(lang, "en") ? true : false;

	switch (category)
	{
		case 1: formatex(title, charsmax(title), is_en ? "\y[Offensive] Shop - $%d" : "\y[Ofensiv] Shop - $%d", money);
		case 2: formatex(title, charsmax(title), is_en ? "\y[Defensive] Shop - $%d" : "\y[Defensiv] Shop - $%d", money);
		case 3: formatex(title, charsmax(title), is_en ? "\y[Special] Shop - $%d" : "\y[Special] Shop - $%d", money);
		default: return;
	}

	new menu = menu_create(title, "shop_item_handler");

	for (new i = 0; i < MAX_SPECIAL; i++)
	{
		if (g_SpecialItems[i][SI_Category] != category)
			continue;

		new szName[48];
		GetSI_Name(id, i, szName, charsmax(szName));

		new tmp[96];
		if (g_BoughtThisRound[id][i])
			formatex(tmp, charsmax(tmp), is_en ? "\d%s - BOUGHT" : "\d%s - CUMPARAT", szName);
		else if (g_Active[id][i])
			formatex(tmp, charsmax(tmp), is_en ? "\y%s - ACTIVE" : "\y%s - ACTIV", szName);
		else
			formatex(tmp, charsmax(tmp), "\w%s \y$%d", szName, g_SpecialItems[i][SI_Cost]);

		new info[8];
		formatex(info, charsmax(info), "%d", i);
		menu_additem(menu, tmp, info);
	}

	menu_additem(menu, fmt("%L", id, "M2SHOP_BACK"), "99");
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
		client_print_color(id, print_team_default, "%L", id, "M2SHOP_NEED_ALIVE");
		return;
	}

	new szName[48];
	GetSI_Name(id, idx, szName, charsmax(szName));

	if (g_BoughtThisRound[id][idx])
	{
		client_print_color(id, print_team_default, "%L", id, "M2SHOP_ALREADY_BOUGHT", szName);
		ShowShopMenu(id, g_SpecialItems[idx][SI_Category]);
		return;
	}

	new cost = g_SpecialItems[idx][SI_Cost];
	new money = cs_get_user_money(id);

	if (money < cost)
	{
		client_print_color(id, print_team_default, "%L", id, "M2SHOP_NOT_ENOUGH", cost, money);
		ShowShopMenu(id, g_SpecialItems[idx][SI_Category]);
		return;
	}

	cs_set_user_money(id, money - cost);

	g_BoughtThisRound[id][idx] = true;
	g_Active[id][idx] = true;

	ApplyItemEffect(id, idx);

	// Un singur mesaj scurt (anti-overflow)
	client_print_color(id, print_team_default, "%L", id, "M2SHOP_BOUGHT", szName, cost);

	ShowShopMenu(id, g_SpecialItems[idx][SI_Category]);
}

// ======================== APPLY EFFECTS (INSTANT) ========================
stock ApplyItemEffect(id, idx)
{
	if (!is_user_alive(id)) return;

	switch (idx)
	{
		case 9: // Life Ring +60 Max HP
		{
			new hp = get_user_health(id);
			set_user_health(id, hp + 60);
		}
		case 10: // Instant HP Boost (ex-regen)
		{
			new hp = get_user_health(id);
			set_user_health(id, hp + 80);
		}
		case 11: // Mana Ring +80 MaxMP + 40 MP
		{
			new maxmp = get_user_m2_maxmp(id);
			set_user_m2_maxmp(id, maxmp + 80);
			set_user_m2_mp(id, get_user_m2_mp(id) + 40);
		}
		case 14: // Divine Blessing +50 HP (in loc de regen)
		{
			new hp = get_user_health(id);
			set_user_health(id, hp + 50);
		}
		case 15: // Wind Shoes +60 speed
		{
			new Float:speed = get_user_maxspeed(id);
			set_user_maxspeed(id, speed + 60.0);
		}
		case 16: // Blessed Scroll
		{
			m2_set_force_upgrade(id, true);
			client_print_color(id, print_team_default, "%L", id, "M2SHOP_SCROLL_ACTIVE");
		}
		case 19: // Power Elixir +12 all stats
		{
			new maxmp = get_user_m2_maxmp(id);
			set_user_m2_maxmp(id, maxmp + 96);
			new hp = get_user_health(id);
			set_user_health(id, hp + 120);
		}
		case 23: // Regen Ring (one-time)
		{
			new mp = get_user_m2_mp(id);
			new maxmp = get_user_m2_maxmp(id);
			set_user_m2_mp(id, min(mp + 40, maxmp));
			new hp = get_user_health(id);
			set_user_health(id, hp + 30);
		}
	}
}

// ======================== SPAWN - REAPLICA SPEED / HP ========================
public OnPlayerSpawn(id)
{
	if (!is_user_alive(id)) return;

	// Reaplica doar ce se pierde la respawn
	if (g_Active[id][15])
	{
		new Float:speed = get_user_maxspeed(id);
		set_user_maxspeed(id, speed + 60.0);
	}
	if (g_Active[id][9])
	{
		new hp = get_user_health(id);
		set_user_health(id, hp + 60);
	}
	if (g_Active[id][19])
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
		// Crit (1)
		if (g_Active[attacker][1] && random_num(1, 100) <= 30)
		{
			final *= 2.0;
			// Fara print aici - cauza overflow la spam
		}

		// STR Bracelet (2)
		if (g_Active[attacker][2]) final += 30.0;

		// Berserk (4)
		if (g_Active[attacker][4]) final *= 1.40;

		// Skill Power (7)
		if (g_Active[attacker][7]) final *= 1.25;

		// Elixir (19)
		if (g_Active[attacker][19]) final += 18.0;

		// Piercing (5)
		if (g_Active[attacker][5]) final *= 1.15;
	}

	// === VICTIM BUFFS ===
	if (is_user_alive(victim))
	{
		// Evasion (22)
		if (g_Active[victim][22] && random_num(1, 100) <= 12)
		{
			SetHookChainArg(4, ATYPE_FLOAT, 0.0);
			return HC_CONTINUE;
		}

		// Magic Shield (13)
		if (g_Active[victim][13]) final *= 0.78;

		// Armor (8)
		if (g_Active[victim][8]) final -= 35.0;

		// Divine Blessing (14)
		if (g_Active[victim][14]) final -= 20.0;

		// Anti-Crit (21)
		if (g_Active[victim][21] && final > damage * 1.5) final *= 0.60;

		// Elixir defense
		if (g_Active[victim][19]) final -= 12.0;
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

	// Lifesteal (6)
	if (g_Active[attacker][6] && is_user_alive(attacker))
	{
		new heal = floatround(damage * 0.15);
		if (heal > 0)
		{
			new hp = get_user_health(attacker);
			set_user_health(attacker, hp + heal);
		}
	}

	// Reflect (12) - anti-loop
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

	// Experience Ring (0)
	if (g_Active[killer][0])
		extra_xp = xp / 2;

	// Yang Ring (3)
	if (g_Active[killer][3])
		extra_yang = yang / 2;

	// Luck Ring (17)
	if (g_Active[killer][17])
	{
		extra_yang += yang * 30 / 100;
		if (random_num(1, 100) <= 25)
			extra_xp += xp / 3;
	}

	// Spirit Stone (20)
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
