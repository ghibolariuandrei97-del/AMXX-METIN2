#include <amxmodx>
#include <amxmisc>
#include <fun>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <nvault>
#include <metin2_api>

#define PLUGIN  "Metin2 Altar"
#define VERSION "1.0"
#define AUTHOR  "Andrew"

/*================================================================================
	Metin2 Altar - Pietre pretioase (spirit stones)

	/altar  - cumperi sau upgradezi pietre cu Yang
	Pietrele sunt legate de jucator (nu de iteme), max +4
	Bonusurile scaleaza: +0=25% | +1=50% | +2=75% | +3=90% | +4=100% din efectul maxim

	Inspirat din pietrele din Metin2 (anti-rasa, stats, combat, XP/Yang).
================================================================================*/

#define MAX_PLAYERS     32
#define MAX_STONE_UPG   4
#define STONE_COUNT     18

// ======================== TIPURI PIETRE ========================
enum _:StoneType
{
	STONE_ANTI_WAR = 0,   // +dmg vs Warrior
	STONE_ANTI_SURA,      // +dmg vs Sura
	STONE_ANTI_NINJA,     // +dmg vs Ninja
	STONE_ANTI_SHAMAN,    // +dmg vs Shaman
	STONE_STR,            // bonus damage din STR
	STONE_VIT,            // bonus HP la spawn
	STONE_DEX,            // bonus defense / reduce dmg
	STONE_INT,            // bonus MP max
	STONE_HP,             // +Max HP flat
	STONE_MP,             // +Max MP flat
	STONE_DAMAGE,         // +% damage general
	STONE_DEFENSE,        // -% damage primit
	STONE_CRIT,           // sansa crit extra
	STONE_PIERCE,         // ignora % din aparare (extra dmg)
	STONE_SPEED,          // +viteza miscare
	STONE_XP,             // +% XP la kill
	STONE_YANG,           // +% Yang la kill
	STONE_VAMP            // lifesteal % din damage
};

new const g_szStoneName[STONE_COUNT][] = {
	"Anti-Razboinic",
	"Anti-Sura",
	"Anti-Ninja",
	"Anti-Saman",
	"Piatra Puterii (STR)",
	"Piatra Vitalitatii (VIT)",
	"Piatra Agilitatii (DEX)",
	"Piatra Inteligentei (INT)",
	"Piatra Vietii (HP)",
	"Piatra Maniei (MP)",
	"Piatra Distrugerii",
	"Piatra Apararii",
	"Piatra Critica",
	"Piatra Penetrarii",
	"Piatra Vitezei",
	"Piatra Experientei",
	"Piatra Bogatiei (Yang)",
	"Piatra Vampirismului"
};

new const g_szStoneDesc[STONE_COUNT][] = {
	"+Dmg vs Razboinic",
	"+Dmg vs Sura",
	"+Dmg vs Ninja",
	"+Dmg vs Saman",
	"Bonus damage (STR)",
	"Bonus HP la spawn",
	"Reduce damage primit",
	"Bonus Max MP",
	"+Max HP",
	"+Max MP",
	"+Damage general %",
	"-Damage primit %",
	"Sansa crit extra",
	"Penetrare aparare",
	"+Viteza miscare",
	"+XP la kill",
	"+Yang la kill",
	"Lifesteal din damage"
};

// Cost cumparare baza (Yang) - +0
new const g_iStoneBuyCost[STONE_COUNT] = {
	25000, 25000, 25000, 25000,   // anti
	20000, 20000, 20000, 20000,   // stats
	22000, 22000,                 // HP/MP
	30000, 28000, 32000, 30000,   // combat
	18000,                        // speed
	35000, 35000,                 // XP/Yang
	40000                         // vamp
};

// Efect maxim la +4 (valoarea "100%")
// Anti / Damage / Defense / Pierce / XP / Yang / Vamp = procent (0.25 = 25% la +0 ... 1.0 = 100% la +4)
// STR = damage flat maxim adaugat
// VIT/HP = HP flat maxim
// INT/MP = MP flat maxim
// Crit = sansa % maxima
// Speed = unitati viteza maxime
new const Float:g_flStoneMaxEffect[STONE_COUNT] = {
	1.00,   // Anti-War  +100% dmg vs race la +4
	1.00,   // Anti-Sura
	1.00,   // Anti-Ninja
	1.00,   // Anti-Shaman
	40.0,   // STR      +40 dmg flat la +4
	80.0,   // VIT      +80 HP la +4
	0.40,   // DEX      -40% dmg primit la +4
	60.0,   // INT      +60 MaxMP la +4
	100.0,  // HP       +100 MaxHP la +4
	80.0,   // MP       +80 MaxMP la +4
	0.50,   // Damage   +50% dmg general la +4
	0.35,   // Defense  -35% dmg primit la +4
	25.0,   // Crit     25% sansa crit la +4
	0.40,   // Pierce   +40% dmg (penetrare) la +4
	40.0,   // Speed    +40 speed la +4
	1.00,   // XP       +100% XP la +4
	1.00,   // Yang     +100% Yang la +4
	0.30    // Vamp     30% lifesteal la +4
};

// Multiplicator efect pe nivel: +0=0.25 ... +4=1.00
new const Float:g_flUpgMult[MAX_STONE_UPG + 1] = {
	0.25, 0.50, 0.75, 0.90, 1.00
};

// ======================== DATE JUCATOR ========================
// -1 = nu detine piatra | 0..4 = nivel upgrade
new g_iStoneLevel[MAX_PLAYERS + 1][STONE_COUNT];
new bool:g_bLoaded[MAX_PLAYERS + 1];
new g_iVault = INVALID_HANDLE;

new g_sprShockwave;
new g_sprDot;
//new g_sprSteam;

// ======================== PLUGIN ========================

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_clcmd("say /altar", "cmd_altar");
	register_clcmd("say_team /altar", "cmd_altar");
	register_clcmd("say /pietre", "cmd_altar");
	register_clcmd("say /stones", "cmd_altar");

	register_clcmd("nightvision", "cmd_altar");

	RegisterHookChain(RG_CBasePlayer_TakeDamage, "OnTakeDamage", false);
	RegisterHookChain(RG_CBasePlayer_Spawn, "OnPlayerSpawn", true);

	register_event("DeathMsg", "OnDeath", "a");

	g_iVault = nvault_open("metin2_altar");
	if (g_iVault == INVALID_HANDLE)
		set_fail_state("[Metin2 Altar] Nu s-a putut deschide vault-ul!");
}

public plugin_precache()
{
	g_sprShockwave = precache_model("sprites/shockwave.spr");
	g_sprDot       = precache_model("sprites/dot.spr");
	//g_sprSteam     = precache_model("sprites/steam1.spr");

	precache_sound("items/suitchargeok1.wav");
	precache_sound("items/gunpickup2.wav");
	precache_sound("weapons/explode3.wav");
	precache_sound("buttons/blip1.wav");
}

public plugin_end()
{
	if (g_iVault != INVALID_HANDLE)
		nvault_close(g_iVault);
}

public client_putinserver(id)
{
	reset_stones(id);
	load_stones(id);
}

public client_disconnected(id)
{
	if (g_bLoaded[id])
		save_stones(id);
	reset_stones(id);
}

// ======================== RESET / LOAD / SAVE ========================

stock reset_stones(id)
{
	for (new i = 0; i < STONE_COUNT; i++)
		g_iStoneLevel[id][i] = -1;
	g_bLoaded[id] = false;
}

stock load_stones(id)
{
	new name[32], key[48], data[128];
	get_user_name(id, name, charsmax(name));
	formatex(key, charsmax(key), "altar_%s", name);

	g_bLoaded[id] = true;

	if (!nvault_get(g_iVault, key, data, charsmax(data)) || !data[0])
		return;

	// Format: lvl0 lvl1 lvl2 ... (space separated, -1 daca nu are)
	new pos, val[8];
	for (new i = 0; i < STONE_COUNT; i++)
	{
		pos = argparse(data, pos, val, charsmax(val));
		if (pos == -1 && !val[0])
			break;
		g_iStoneLevel[id][i] = str_to_num(val);
		if (g_iStoneLevel[id][i] < -1) g_iStoneLevel[id][i] = -1;
		if (g_iStoneLevel[id][i] > MAX_STONE_UPG) g_iStoneLevel[id][i] = MAX_STONE_UPG;
	}
}

stock save_stones(id)
{
	if (!g_bLoaded[id] || id < 1 || id > MaxClients)
		return;

	new name[32], key[48], data[128];
	get_user_name(id, name, charsmax(name));
	if (!name[0]) return;

	formatex(key, charsmax(key), "altar_%s", name);

	new len;
	for (new i = 0; i < STONE_COUNT; i++)
		len += formatex(data[len], charsmax(data) - len, "%d ", g_iStoneLevel[id][i]);

	nvault_set(g_iVault, key, data);
}

// argparse simplu

// ======================== HELPERS ========================

stock Float:GetStoneEffect(id, stone)
{
	new lvl = g_iStoneLevel[id][stone];
	if (lvl < 0 || lvl > MAX_STONE_UPG)
		return 0.0;
	return g_flStoneMaxEffect[stone] * g_flUpgMult[lvl];
}

stock bool:HasStone(id, stone)
{
	return (g_iStoneLevel[id][stone] >= 0);
}

stock GetUpgradeCost(stone, current_lvl)
{
	// cost +1: buy_cost * (current+2)^2 / 2
	new next = current_lvl + 1;
	if (next > MAX_STONE_UPG) return 0;
	return g_iStoneBuyCost[stone] * (next + 1) * (next + 1) / 2;
}

stock FormatStoneLine(id, stone, out[], len)
{
	new lvl = g_iStoneLevel[id][stone];
	if (lvl < 0)
		formatex(out, len, "%s \d[nu detii]", g_szStoneName[stone]);
	else
		formatex(out, len, "%s \y+%d", g_szStoneName[stone], lvl);
}

// ======================== MENIU /ALTAR ========================

public cmd_altar(id)
{
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	if (!m2_has_race(id))
	{
		client_print_color(id, print_team_default, "^4[Altar]^1 Alege mai intai o rasa cu ^3/menu^1!");
		return PLUGIN_HANDLED;
	}

	show_altar_menu(id);
	return PLUGIN_HANDLED;
}

stock show_altar_menu(id)
{
	new yang = get_user_m2_yang(id);
	new title[64];
	formatex(title, charsmax(title), "\y[Metin2] Altarul Pietrelor^n\wYang: \y%d", yang);

	new menu = menu_create(title, "altar_handler");

	new line[64], info[8];
	for (new i = 0; i < STONE_COUNT; i++)
	{
		FormatStoneLine(id, i, line, charsmax(line));
		formatex(info, charsmax(info), "%d", i);
		menu_additem(menu, line, info);
	}

	menu_additem(menu, "\rInfo pietre", "99");
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_display(id, menu);
}

public altar_handler(id, menu, item)
{
	if (item == MENU_EXIT || !is_user_connected(id))
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new data[8], access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), _, _, callback);
	menu_destroy(menu);

	new key = str_to_num(data);
	if (key == 99)
	{
		show_altar_info(id);
		return PLUGIN_HANDLED;
	}

	if (key < 0 || key >= STONE_COUNT)
		return PLUGIN_HANDLED;

	show_stone_detail(id, key);
	return PLUGIN_HANDLED;
}

stock show_stone_detail(id, stone)
{
	new lvl = g_iStoneLevel[id][stone];
	new title[96];

	if (lvl < 0)
		formatex(title, charsmax(title), "\y%s^n\wNu detii - Cumpara", g_szStoneName[stone]);
	else if (lvl >= MAX_STONE_UPG)
		formatex(title, charsmax(title), "\y%s +%d^n\wMAXIM", g_szStoneName[stone], lvl);
	else
		formatex(title, charsmax(title), "\y%s +%d^n\wUpgrade la +%d", g_szStoneName[stone], lvl, lvl + 1);

	new menu = menu_create(title, "stone_detail_handler");

	new info[16];
	formatex(info, charsmax(info), "%d", stone);

	// Descriere efect curent / maxim
	new desc[96];
	new Float:cur = (lvl >= 0) ? GetStoneEffect(id, stone) : 0.0;
	new Float:maxe = g_flStoneMaxEffect[stone];

	switch (stone)
	{
		case STONE_ANTI_WAR, STONE_ANTI_SURA, STONE_ANTI_NINJA, STONE_ANTI_SHAMAN:
			formatex(desc, charsmax(desc), "Efect: \y+%.0f%%\w dmg vs rasa (max +%.0f%%)", cur * 100.0, maxe * 100.0);
		case STONE_STR:
			formatex(desc, charsmax(desc), "Efect: \y+%.0f\w dmg flat (max +%.0f)", cur, maxe);
		case STONE_VIT, STONE_HP:
			formatex(desc, charsmax(desc), "Efect: \y+%.0f\w HP (max +%.0f)", cur, maxe);
		case STONE_DEX, STONE_DEFENSE:
			formatex(desc, charsmax(desc), "Efect: \y-%.0f%%\w dmg primit (max -%.0f%%)", cur * 100.0, maxe * 100.0);
		case STONE_INT, STONE_MP:
			formatex(desc, charsmax(desc), "Efect: \y+%.0f\w Max MP (max +%.0f)", cur, maxe);
		case STONE_DAMAGE, STONE_PIERCE:
			formatex(desc, charsmax(desc), "Efect: \y+%.0f%%\w dmg (max +%.0f%%)", cur * 100.0, maxe * 100.0);
		case STONE_CRIT:
			formatex(desc, charsmax(desc), "Efect: \y%.0f%%\w sansa crit (max %.0f%%)", cur, maxe);
		case STONE_SPEED:
			formatex(desc, charsmax(desc), "Efect: \y+%.0f\w speed (max +%.0f)", cur, maxe);
		case STONE_XP, STONE_YANG:
			formatex(desc, charsmax(desc), "Efect: \y+%.0f%%\w la kill (max +%.0f%%)", cur * 100.0, maxe * 100.0);
		case STONE_VAMP:
			formatex(desc, charsmax(desc), "Efect: \y%.0f%%\w lifesteal (max %.0f%%)", cur * 100.0, maxe * 100.0);
		default:
			formatex(desc, charsmax(desc), "%s", g_szStoneDesc[stone]);
	}
	menu_additem(menu, desc, "x"); // non-selectabil practic - user apasa oricum

	if (lvl < 0)
	{
		new buy[64];
		formatex(buy, charsmax(buy), "Cumpara (+0) - \y%d Yang", g_iStoneBuyCost[stone]);
		menu_additem(menu, buy, info);
	}
	else if (lvl < MAX_STONE_UPG)
	{
		new cost = GetUpgradeCost(stone, lvl);
		new upg[64];
		formatex(upg, charsmax(upg), "Upgrade la +%d - \y%d Yang", lvl + 1, cost);
		menu_additem(menu, upg, info);
	}
	else
	{
		menu_additem(menu, "\dPiatra la nivel maxim", "x");
	}

	menu_additem(menu, "\rInapoi", "98");
	menu_display(id, menu, 0);
}

public stone_detail_handler(id, menu, item)
{
	if (item == MENU_EXIT || !is_user_connected(id))
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new data[16], access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), _, _, callback);
	menu_destroy(menu);

	if (equal(data, "98"))
	{
		show_altar_menu(id);
		return PLUGIN_HANDLED;
	}
	if (equal(data, "x"))
	{
		// re-open last - nu stim stone-ul; inapoi la lista
		show_altar_menu(id);
		return PLUGIN_HANDLED;
	}

	new stone = str_to_num(data);
	if (stone < 0 || stone >= STONE_COUNT)
		return PLUGIN_HANDLED;

	try_buy_or_upgrade(id, stone);
	return PLUGIN_HANDLED;
}

stock try_buy_or_upgrade(id, stone)
{
	new lvl = g_iStoneLevel[id][stone];
	new yang = get_user_m2_yang(id);

	if (lvl < 0)
	{
		// Cumpara
		new cost = g_iStoneBuyCost[stone];
		if (yang < cost)
		{
			client_print_color(id, print_team_default, "^4[Altar]^1 Yang insuficient! Ai nevoie de ^3%d^1.", cost);
			show_stone_detail(id, stone);
			return;
		}

		set_user_m2_yang(id, yang - cost);
		g_iStoneLevel[id][stone] = 0;
		save_stones(id);

		client_print_color(id, print_team_default, "^4[Altar]^1 Ai cumparat ^3%s +0^1!", g_szStoneName[stone]);
		FxAltarSuccess(id);
		emit_sound(id, CHAN_ITEM, "items/gunpickup2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

		// aplica imediat daca e spawn-related
		if (is_user_alive(id))
			ApplySpawnBonuses(id);

		show_stone_detail(id, stone);
	}
	else if (lvl < MAX_STONE_UPG)
	{
		new cost = GetUpgradeCost(stone, lvl);
		if (yang < cost)
		{
			client_print_color(id, print_team_default, "^4[Altar]^1 Yang insuficient! Ai nevoie de ^3%d^1.", cost);
			show_stone_detail(id, stone);
			return;
		}

		set_user_m2_yang(id, yang - cost);
		g_iStoneLevel[id][stone] = lvl + 1;
		save_stones(id);

		client_print_color(id, print_team_default, "^4[Altar]^1 ^3%s^1 a devenit ^3+%d^1!", g_szStoneName[stone], lvl + 1);
		FxAltarUpgrade(id, lvl + 1);
		emit_sound(id, CHAN_ITEM, "items/suitchargeok1.wav", VOL_NORM, ATTN_NORM, 0, PITCH_HIGH);

		if (is_user_alive(id))
			ApplySpawnBonuses(id);

		show_stone_detail(id, stone);
	}
	else
	{
		client_print_color(id, print_team_default, "^4[Altar]^1 Piatra este deja la maxim (+%d)!", MAX_STONE_UPG);
		show_stone_detail(id, stone);
	}
}

stock show_altar_info(id)
{
	static motd[1536];
	formatex(motd, charsmax(motd),
		"<html><body bgcolor=#0a0a12 text=#e8e8e8 style='font:13px Arial;margin:8px'>\
		<b style='color:#ffd700;font-size:16px'>[Metin2] Altarul Pietrelor</b><br><br>\
		Pietrele pretioase iti ofera bonusuri permanente pe harta.<br>\
		Le cumperi cu <font color=#ffd54f>Yang</font> si le upgradezi pana la <font color=#69f0ae>+4</font>.<br><br>\
		<b style='color:#4fc3f7'>Scale efect:</b><br>\
		+0 = 25%% &nbsp; +1 = 50%% &nbsp; +2 = 75%% &nbsp; +3 = 90%% &nbsp; +4 = 100%%<br><br>\
		<b style='color:#ef5350'>Anti-Rasa</b> - damage masiv vs rasa respectiva<br>\
		<b style='color:#ff9800'>STR / VIT / DEX / INT</b> - bonusuri de lupta si stats<br>\
		<b style='color:#81c784'>HP / MP</b> - viata si mana maxima<br>\
		<b style='color:#e040fb'>Distrugere / Aparare / Crit / Penetrare</b> - combat<br>\
		<b style='color:#00e5ff'>Viteza / XP / Yang / Vampirism</b> - utilitare<br><br>\
		<font color=#aaaaaa>Scrie /altar pentru a deschide meniul.<br>\
		Bonusurile se salveaza automat.</font>\
		</body></html>");
	show_motd(id, motd, "Metin2 Altar");
}

// ======================== APLICARE BONUSURI ========================

public OnPlayerSpawn(id)
{
	if (!is_user_alive(id) || !g_bLoaded[id])
		return;

	set_task(0.3, "Task_ApplySpawn", id);
}

public Task_ApplySpawn(id)
{
	if (!is_user_alive(id))
		return;
	ApplySpawnBonuses(id);
}

stock ApplySpawnBonuses(id)
{
	if (!is_user_alive(id) || !m2_has_race(id))
		return;

	// --- HP ---
	new hp_bonus = floatround(GetStoneEffect(id, STONE_VIT) + GetStoneEffect(id, STONE_HP));
	if (hp_bonus > 0)
	{
		new hp = get_user_health(id);
		set_user_health(id, hp + hp_bonus);
	}

	// --- MP ---
	new mp_bonus = floatround(GetStoneEffect(id, STONE_INT) + GetStoneEffect(id, STONE_MP));
	if (mp_bonus > 0)
	{
		new maxmp = get_user_m2_maxmp(id);
		set_user_m2_maxmp(id, maxmp + mp_bonus);
		set_user_m2_mp(id, get_user_m2_maxmp(id));
	}

	// --- Speed ---
	new Float:spd = GetStoneEffect(id, STONE_SPEED);
	if (spd > 0.0)
	{
		new Float:cur = get_user_maxspeed(id);
		if (cur < 1.0) cur = 250.0;
		set_user_maxspeed(id, cur + spd);
	}
}

// ======================== DAMAGE ========================

public OnTakeDamage(victim, inflictor, attacker, Float:damage, damagebits)
{
	if (!is_user_connected(attacker) || !is_user_connected(victim))
		return HC_CONTINUE;
	if (attacker == victim)
		return HC_CONTINUE;
	if (!g_bLoaded[attacker] && !g_bLoaded[victim])
		return HC_CONTINUE;

	new Float:final = damage;

	// ----- ATACATOR -----
	if (g_bLoaded[attacker] && m2_has_race(attacker))
	{
		// Anti-rasa
		new vrace = get_user_m2_race(victim);
		if (vrace == M2_RACE_WARRIOR)
			final += damage * GetStoneEffect(attacker, STONE_ANTI_WAR);
		else if (vrace == M2_RACE_SURA)
			final += damage * GetStoneEffect(attacker, STONE_ANTI_SURA);
		else if (vrace == M2_RACE_NINJA)
			final += damage * GetStoneEffect(attacker, STONE_ANTI_NINJA);
		else if (vrace == M2_RACE_SHAMAN)
			final += damage * GetStoneEffect(attacker, STONE_ANTI_SHAMAN);

		// Damage general %
		final += damage * GetStoneEffect(attacker, STONE_DAMAGE);

		// STR flat
		final += GetStoneEffect(attacker, STONE_STR);

		// Pierce (extra % din damage-ul original)
		final += damage * GetStoneEffect(attacker, STONE_PIERCE);

		// Crit
		new Float:crit_chance = GetStoneEffect(attacker, STONE_CRIT);
		if (crit_chance > 0.0 && random_float(0.0, 100.0) <= crit_chance)
		{
			final *= 1.75;
			client_print_color(attacker, print_team_default, "^4[Altar]^1 ^3CRITIC^1 din Piatra Critica!");
			FxCrit(attacker);
		}

		// Vampirism
		new Float:vamp = GetStoneEffect(attacker, STONE_VAMP);
		if (vamp > 0.0 && is_user_alive(attacker))
		{
			new heal = floatround(final * vamp);
			if (heal > 0)
			{
				new hp = get_user_health(attacker);
				// plafon generos
				set_user_health(attacker, min(hp + heal, 500));
			}
		}
	}

	// ----- VICTIMA (defense) -----
	if (g_bLoaded[victim] && m2_has_race(victim))
	{
		new Float:def = GetStoneEffect(victim, STONE_DEX) + GetStoneEffect(victim, STONE_DEFENSE);
		if (def > 0.0)
		{
			if (def > 0.70) def = 0.70; // cap 70% reducere
			final *= (1.0 - def);
		}
	}

	if (final < 1.0) final = 1.0;
	SetHookChainArg(4, ATYPE_FLOAT, final);
	return HC_CONTINUE;
}

// ======================== XP / YANG LA KILL ========================

public OnDeath()
{
	new killer = read_data(1);
	new victim = read_data(2);

	if (!is_user_connected(killer) || killer == victim)
		return;
	if (!g_bLoaded[killer] || !m2_has_race(killer))
		return;

	// Bonusurile de XP/Yang se aplica peste ce da deja core-ul
	// Core adauga XP/Yang in DeathMsg - noi adaugam EXTRA dupa

	set_task(0.1, "Task_KillBonus", killer + (victim * 100));
}

public Task_KillBonus(tid)
{
	new killer = tid % 100;
	new victim = tid / 100;

	if (!is_user_connected(killer))
		return;

	// XP bonus - folosim un amount de baza estimat (core da ~100-150)
	new Float:xp_pct = GetStoneEffect(killer, STONE_XP);
	new Float:yang_pct = GetStoneEffect(killer, STONE_YANG);

	if (xp_pct > 0.0)
	{
		new extra_xp = floatround(120.0 * xp_pct); // aprox pe baza kill-ului mediu
		if (extra_xp > 0)
		{
			new xp = get_user_m2_xp(killer);
			set_user_m2_xp(killer, xp + extra_xp);
			client_print_color(killer, print_team_default, "^4[Altar]^1 +%d XP bonus (Piatra Experientei)", extra_xp);
		}
	}

	if (yang_pct > 0.0)
	{
		new extra_yang = floatround(500.0 * yang_pct);
		if (extra_yang > 0)
		{
			new yang = get_user_m2_yang(killer);
			set_user_m2_yang(killer, yang + extra_yang);
			client_print_color(killer, print_team_default, "^4[Altar]^1 +%d Yang bonus (Piatra Bogatiei)", extra_yang);
		}
	}

	#pragma unused victim
}

// ======================== FX ========================

stock FxAltarSuccess(id)
{
	new origin[3];
	get_user_origin(id, origin, 0);

	message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
	write_byte(TE_BEAMCYLINDER);
	write_coord(origin[0]); write_coord(origin[1]); write_coord(origin[2] - 10);
	write_coord(origin[0]); write_coord(origin[1]); write_coord(origin[2] + 60);
	write_short(g_sprShockwave);
	write_byte(0); write_byte(0); write_byte(6); write_byte(10); write_byte(0);
	write_byte(255); write_byte(215); write_byte(0); write_byte(200); write_byte(0);
	message_end();

	message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
	write_byte(TE_DLIGHT);
	write_coord(origin[0]); write_coord(origin[1]); write_coord(origin[2]);
	write_byte(20);
	write_byte(255); write_byte(200); write_byte(50);
	write_byte(8); write_byte(0);
	message_end();
}

stock FxAltarUpgrade(id, new_lvl)
{
	new origin[3];
	get_user_origin(id, origin, 0);

	new r = 100 + new_lvl * 30;
	new g = 150 + new_lvl * 20;
	new b = 255;

	for (new i = 0; i < 1 + new_lvl / 2; i++)
	{
		message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
		write_byte(TE_BEAMCYLINDER);
		write_coord(origin[0]); write_coord(origin[1]); write_coord(origin[2] - 10);
		write_coord(origin[0]); write_coord(origin[1]); write_coord(origin[2] + 40 + i * 25);
		write_short(g_sprShockwave);
		write_byte(0); write_byte(0); write_byte(5); write_byte(8); write_byte(0);
		write_byte(r); write_byte(g); write_byte(b); write_byte(180); write_byte(0);
		message_end();
	}

	message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
	write_byte(TE_DLIGHT);
	write_coord(origin[0]); write_coord(origin[1]); write_coord(origin[2]);
	write_byte(18 + new_lvl * 3);
	write_byte(r); write_byte(g); write_byte(b);
	write_byte(10); write_byte(0);
	message_end();

	// particule
	for (new i = 0; i < 3 + new_lvl; i++)
	{
		message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
		write_byte(TE_SPRITE);
		write_coord(origin[0] + random_num(-25, 25));
		write_coord(origin[1] + random_num(-25, 25));
		write_coord(origin[2] + random_num(5, 40));
		write_short(g_sprDot);
		write_byte(random_num(4, 8));
		write_byte(180);
		message_end();
	}

	if (new_lvl >= MAX_STONE_UPG)
	{
		emit_sound(id, CHAN_ITEM, "weapons/explode3.wav", 0.6, ATTN_NORM, 0, PITCH_HIGH);
		client_print_color(0, print_team_default, "^4[Altar]^1 %n a maximizat o piatra pretioasa (^3+4^1)!", id);
	}
}

stock FxCrit(id)
{
	new origin[3];
	get_user_origin(id, origin, 0);

	message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
	write_byte(TE_DLIGHT);
	write_coord(origin[0]); write_coord(origin[1]); write_coord(origin[2]);
	write_byte(15);
	write_byte(255); write_byte(50); write_byte(50);
	write_byte(3); write_byte(0);
	message_end();
}
