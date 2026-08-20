/*================================================================================
	Metin2 RPG Core - CS 1.6
	AMX Mod X 1.10+ | ReAPI | nVault Array | fun | fakemeta
	Skill-uri reale + Mana + Item bonuses + Potions + API + Forwards
	             + Sistem iteme 100% dinamic (m2_register_item functional)
================================================================================*/



#include <amxmodx>
#include <amxmisc>
#include <nvault>
#include <nvault_array>
#include <reapi>
#include <fakemeta>
#include <hamsandwich>
#include <fun>

// 1=Debug Oprit , 0=Debug Pornit
#define DEBUG_LOGS_OFF 1
null_func(){}

static stock const szDebugFileLocation[] = "addons/amxmodx/data/metin2logs.txt";

#if DEBUG_LOGS_OFF
	#define debug_log(%1)	null_func()
#else
stock debug_log(iDebugLevel = 0, const szMessage[], any:...)
{
	static Frm[128];
	vformat(Frm, charsmax(Frm), szMessage, 3);

	switch (iDebugLevel)
	{
		case 1:
		{
			server_print("[DEBUG] %s", Frm);
			client_print(0, print_console, "[DEBUG] %s", Frm);
		}
		case 2:
		{
			server_print("[DEBUG] %s", Frm);
			client_print(0, print_console, "[DEBUG] %s", Frm);
			new buff[120];
			formatex(buff, charsmax(buff), "[DEBUG] %s", Frm);
			write_file(szDebugFileLocation, buff);
		}
		case 3:
		{
			server_print("[DEBUG, SysTime: %i] %s", get_systime(), Frm);
			client_print(0, print_console, "[DEBUG, SysTime: %i] %s", get_systime(), Frm);
			new buff[120];
			formatex(buff, charsmax(buff), "[DEBUG, SysTime: %i] %s", get_systime(), Frm);
			write_file(szDebugFileLocation, buff);
		}
		case 4:
		{
			new szMap[32];
			get_mapname(szMap, charsmax(szMap));
			server_print("[DEBUG, SysTime: %i, Map: %s] %s", get_systime(), szMap, Frm);
			client_print(0, print_console, "[DEBUG, SysTime: %i, Map: %s] %s", get_systime(), szMap, Frm);
			new buff[120];
			formatex(buff, charsmax(buff), "[DEBUG, SysTime: %i, Map: %s] %s", get_systime(), szMap, Frm);
			write_file(szDebugFileLocation, buff);
		}
		case 5:
		{
			new szMap[32];
			get_mapname(szMap, charsmax(szMap));
			new Players[32], Num;
			get_players(Players, Num);
			server_print("[DEBUG, SysTime: %i, Map: %s, Players: %i] %s", get_systime(), szMap, Num, Frm);
			client_print(0, print_console, "[DEBUG, SysTime: %i, Map: %s, Players: %i] %s", get_systime(), szMap, Num, Frm);
			new buff[120];
			formatex(buff, charsmax(buff), "[DEBUG, SysTime: %i, Map: %s, Players: %i] %s", get_systime(), szMap, Num, Frm);
			write_file(szDebugFileLocation, buff);
		}
		default:
		{
			client_print(0, print_console, Frm);
			null_func();
		}
	}
}
#endif

#define PLUGIN  "Metin2Core"
#define VERSION "1.0"
#define AUTHOR  "Craxor"

#define MAX_PLAYERS          32
#define MAX_INVENTORY        30
#define MAX_SKILLS           20
#define MAX_UPGRADE          9

#define RACE_NONE            0
#define RACE_WARRIOR         1
#define RACE_SURA            2
#define RACE_NINJA           3
#define RACE_SHAMAN          4

#define SLOT_WEAPON          0
#define SLOT_ARMOR           1
#define SLOT_HELMET          2
#define SLOT_SHIELD          3
#define SLOT_SHOES           4
#define SLOT_JEWEL           5
#define MAX_EQUIP_SLOTS      6
#define MAX_ITEMS            64

#define ITEM_WEAPON          1
#define ITEM_ARMOR           2
#define ITEM_HELMET          3
#define ITEM_SHIELD          4
#define ITEM_SHOES           5
#define ITEM_JEWEL           6
#define ITEM_POTION          7

enum _:PlayerData
{
	g_Level,
	g_XP,
	g_Yang,
	g_Race,
	g_STR,
	g_HP,
	g_DEX,
	g_INT,
	g_StatPoints,
	g_SkillPoints,
	g_SkillLevel[MAX_SKILLS],
	g_Equipped[MAX_EQUIP_SLOTS],
	g_EquippedUpgrade[MAX_EQUIP_SLOTS],
	g_Inventory[MAX_INVENTORY],
	g_InventoryUpgrade[MAX_INVENTORY],
	g_InventoryCount,
	g_MP,
	g_MaxMP
};

enum _:ItemStruct
{
	ItemName[32],
	ItemType,          // 1=Weapon ... 7=Potion
	ItemReqLevel,
	ItemRaceReq,       // 0 = orice rasa
	ItemStr,
	ItemHp,
	ItemDex,
	ItemInt,
	ItemCrit,
	ItemSpeed,
	ItemPrice,
	ItemPotionType     // 0=normal, 1=HP Potion, 2=MP Potion
};

new g_Player[MAX_PLAYERS + 1][PlayerData];
new g_Vault = INVALID_HANDLE;
new g_HudSync;
new Float:g_SkillCooldown[MAX_PLAYERS + 1][5];
new bool:g_AuraActive[MAX_PLAYERS + 1];
new bool:g_ReflectActive[MAX_PLAYERS + 1];
new bool:g_AmbushActive[MAX_PLAYERS + 1];
new bool:g_ResistActive[MAX_PLAYERS + 1];
new bool:g_PierceActive[MAX_PLAYERS + 1];
new bool:g_BlessActive[MAX_PLAYERS + 1];
new Float:g_ResistAmount[MAX_PLAYERS + 1];
new Float:g_PierceAmount[MAX_PLAYERS + 1];
new Float:g_BlessAmount[MAX_PLAYERS + 1];

new g_Items[MAX_ITEMS][ItemStruct];
new g_ItemCount = 0;

new cvar_xp_kill, cvar_xp_hs, cvar_yang_kill, cvar_yang_hs;
new cvar_upgrade_destroy;

new const g_RaceName[][] = {
	"Nespecificat",
	"Razboinic",
	"Sura",
	"Ninja",
	"Saman"
};

new const g_SkillName[MAX_SKILLS][] = {
	"Aura Sabiei", "Corp Rezistent", "Izbitura", "Atac Sabie", "Vartej Sabie",
	"Tais Vrajit", "Armura Vrajita", "Lovitura Degetului", "Atacul Fulgerului", "Pietrificare",
	"Camuflaj", "Atacul Fulgerator", "Ambush", "Otrava", "Ploaie de Sageti",
	"Lecuire", "Atac Intens", "Binecuvantare", "Iutesenie", "Chemarea Fulgerului"
};

// Cost mana pe skill (baza)
new const g_SkillManaCost[5] = { 25, 30, 35, 20, 40 };

// ======================== FORWARDS & NATIVES ========================
new g_fwd_SkillUsed;
new g_fwd_LevelUp;
new g_fwd_PlayerKill;
new g_fwd_ItemEquipped;
new g_fwd_ItemUnequipped;
new g_fwd_UpgradeSuccess;
new g_fwd_UpgradeFail;
new g_fwd_RaceSelected;
new g_fwd_StatAllocated;
new g_fwd_SkillLearned;

public plugin_natives()
{
	register_library("metin2_rpg");
	
	register_native("m2_register_item", "_m2_register_item");
	register_native("get_user_m2_level", "_get_user_m2_level");
	register_native("get_user_m2_xp", "_get_user_m2_xp");
	register_native("set_user_m2_level", "_set_user_m2_level");
	register_native("set_user_m2_xp", "_set_user_m2_xp");
	register_native("get_user_m2_yang", "_get_user_m2_yang");
	register_native("set_user_m2_yang", "_set_user_m2_yang");
	register_native("get_user_m2_race", "_get_user_m2_race");
	register_native("get_user_m2_str", "_get_user_m2_str");
	register_native("get_user_m2_hp", "_get_user_m2_hp");
	register_native("get_user_m2_dex", "_get_user_m2_dex");
	register_native("get_user_m2_int", "_get_user_m2_int");
	register_native("get_user_m2_mp", "_get_user_m2_mp");
	register_native("get_user_m2_maxmp", "_get_user_m2_maxmp");
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_clcmd("say /menu",     "cmd_menu");
	register_clcmd("say /metin2",   "cmd_menu");
	register_clcmd("say /stats",    "cmd_stats");
	register_clcmd("say /statut",   "cmd_stats");
	register_clcmd("say /skills",   "cmd_skills");
	register_clcmd("say /inventar", "cmd_inventar");
	register_clcmd("say /inv",      "cmd_inventar");
	register_clcmd("say /upgrade",  "cmd_upgrade");
	register_clcmd("say /fierar",   "cmd_upgrade");
	register_clcmd("say /shop",     "cmd_shop");
	register_clcmd("say /magazin",  "cmd_shop");
	register_clcmd("say /binds",    "cmd_binds");
	register_clcmd("say /reset",    "cmd_reset");

	register_clcmd("skill1", "cmd_skill1");
	register_clcmd("skill2", "cmd_skill2");
	register_clcmd("skill3", "cmd_skill3");
	register_clcmd("skill4", "cmd_skill4");
	register_clcmd("skill5", "cmd_skill5");
	
	// Admin commands
	register_concmd("amx_set_level", "cmd_admin_set_level", ADMIN_LEVEL_A, "<nume/#userid> <level>");
	register_concmd("amx_set_xp",    "cmd_admin_set_xp",    ADMIN_LEVEL_A, "<nume/#userid> <xp>");
	register_concmd("amx_set_statuspoints", "cmd_admin_set_statuspoints", ADMIN_LEVEL_A, "<nume/#userid> <puncte>");
	register_concmd("amx_set_skillpoints",  "cmd_admin_set_skillpoints",  ADMIN_LEVEL_A, "<nume/#userid> <puncte>");
	register_concmd("amx_set_yang", "cmd_admin_set_yang", ADMIN_LEVEL_A, "<nume/#userid> <yang>");
	
	cvar_xp_kill         = register_cvar("amx_metin2_xp_kill", "100");
	cvar_xp_hs           = register_cvar("amx_metin2_xp_hs_bonus", "50");
	cvar_yang_kill       = register_cvar("amx_metin2_yang_kill", "500");
	cvar_yang_hs         = register_cvar("amx_metin2_yang_hs_bonus", "250");
	cvar_upgrade_destroy = register_cvar("amx_metin2_upgrade_fail_destroy", "1");
	
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "OnTakeDamage", false);
	RegisterHookChain(RG_CBasePlayer_Spawn, "OnPlayerSpawn", true);
	
	register_event("DeathMsg", "OnDeath", "a");
	
	// Block name change
	register_forward(FM_ClientUserInfoChanged, "OnClientUserInfoChanged");
	
	g_HudSync = CreateHudSyncObj();
	
	g_Vault = nvault_open("metin2_rpg");
	if (g_Vault == INVALID_HANDLE)
		set_fail_state("[Metin2] Nu s-a putut deschide vault-ul!");
	
	// Forwards
	g_fwd_SkillUsed      = CreateMultiForward("m2_skill_used", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL); // id, skill_idx, skill_level
	g_fwd_LevelUp        = CreateMultiForward("m2_level_up", ET_IGNORE, FP_CELL, FP_CELL); // id, new_level
	g_fwd_PlayerKill     = CreateMultiForward("m2_player_kill", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_CELL); // killer, victim, xp, yang
	g_fwd_ItemEquipped   = CreateMultiForward("m2_item_equipped", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL); // id, itemid, slot
	g_fwd_ItemUnequipped = CreateMultiForward("m2_item_unequipped", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL); // id, itemid, slot
	g_fwd_UpgradeSuccess = CreateMultiForward("m2_upgrade_success", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL); // id, itemid, new_upgrade
	g_fwd_UpgradeFail    = CreateMultiForward("m2_upgrade_fail", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL); // id, itemid, destroyed (0/1)
	g_fwd_RaceSelected   = CreateMultiForward("m2_race_selected", ET_IGNORE, FP_CELL, FP_CELL); // id, race
	g_fwd_StatAllocated  = CreateMultiForward("m2_stat_allocated", ET_IGNORE, FP_CELL, FP_CELL); // id, stat_type (1=STR,2=HP,3=DEX,4=INT)
	g_fwd_SkillLearned   = CreateMultiForward("m2_skill_learned", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL); // id, skill_idx, new_level
	
	// Inregistreaza itemele default (ID-uri 0-15 pastrate pentru compatibilitate salvari)
	RegisterDefaultItems();
	
	set_task(1.0, "Task_HUD", _, _, _, "b");
	set_task(2.0, "Task_ManaRegen", _, _, _, "b");
}

public plugin_end()
{
	if (g_Vault != INVALID_HANDLE)
		nvault_close(g_Vault);
	
	DestroyForward(g_fwd_SkillUsed);
	DestroyForward(g_fwd_LevelUp);
	DestroyForward(g_fwd_PlayerKill);
	DestroyForward(g_fwd_ItemEquipped);
	DestroyForward(g_fwd_ItemUnequipped);
	DestroyForward(g_fwd_UpgradeSuccess);
	DestroyForward(g_fwd_UpgradeFail);
	DestroyForward(g_fwd_RaceSelected);
	DestroyForward(g_fwd_StatAllocated);
	DestroyForward(g_fwd_SkillLearned);
}

// ======================== ITEM SYSTEM (DYNAMIC) ========================

stock RegisterDefaultItems()
{
	// ID 0 = Gol (obligatoriu)
	RegisterItemInternal("Gol",              0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

	// Weapons
	RegisterItemInternal("Luna Plina",       ITEM_WEAPON, 1, 0, 5, 0, 2, 0, 3, 0, 15000, 0);
	RegisterItemInternal("Tais Barbar",      ITEM_WEAPON, 1, 0, 8, 0, 0, 0, 5, 0, 22000, 0);
	RegisterItemInternal("Nimfa",            ITEM_WEAPON, 1, 0, 3, 0, 4, 2, 2, 0, 18000, 0);

	// Armor
	RegisterItemInternal("Armura Posedata",  ITEM_ARMOR,  1, 0, 0,15, 0, 0, 0, 0, 12000, 0);
	RegisterItemInternal("Armura Monstruoasa",ITEM_ARMOR,1, 0, 2,25, 0, 0, 0, 0, 20000, 0);

	// Helmet
	RegisterItemInternal("Coif de Fier",     ITEM_HELMET, 1, 0, 1, 5, 1, 0, 0, 0,  8000, 0);
	RegisterItemInternal("Coif Dragon",      ITEM_HELMET, 1, 0, 3,10, 2, 0, 1, 0, 15000, 0);

	// Shield
	RegisterItemInternal("Scut Chinezesc",   ITEM_SHIELD, 1, 0, 0, 8, 0, 0, 0, 0,  9000, 0);
	RegisterItemInternal("Scut Titan",       ITEM_SHIELD, 1, 0, 2,15, 0, 0, 0, 0, 16000, 0);

	// Shoes
	RegisterItemInternal("Papuci de Vant",   ITEM_SHOES,  1, 0, 0, 0, 5, 0, 0,15, 11000, 0);
	RegisterItemInternal("Papuci Spirit",    ITEM_SHOES,  1, 0, 0, 0, 3, 2, 0,20, 14000, 0);

	// Jewel
	RegisterItemInternal("Cercei de Abanos", ITEM_JEWEL,  1, 0, 0, 0, 0, 4, 4, 0, 13000, 0);
	RegisterItemInternal("Bratara Lunara",   ITEM_JEWEL,  1, 0, 2, 5, 2, 2, 2, 0, 17000, 0);

	// Potions
	RegisterItemInternal("Lichior HP",       ITEM_POTION, 1, 0, 0, 0, 0, 0, 0, 0,   800, 1);
	RegisterItemInternal("Lichior MP",       ITEM_POTION, 1, 0, 0, 0, 0, 0, 0, 0,   900, 2);
}

stock RegisterItemInternal(const name[], type, req_level, race_req, str, hp, dex, intt, crit, speed, price, potion_type)
{
	if (g_ItemCount >= MAX_ITEMS)
		return -1;

	new item_id = g_ItemCount;

	copy(g_Items[item_id][ItemName], charsmax(g_Items[][ItemName]), name);
	g_Items[item_id][ItemType]       = type;
	g_Items[item_id][ItemReqLevel]   = req_level;
	g_Items[item_id][ItemRaceReq]    = race_req;
	g_Items[item_id][ItemStr]        = str;
	g_Items[item_id][ItemHp]         = hp;
	g_Items[item_id][ItemDex]        = dex;
	g_Items[item_id][ItemInt]        = intt;
	g_Items[item_id][ItemCrit]       = crit;
	g_Items[item_id][ItemSpeed]      = speed;
	g_Items[item_id][ItemPrice]      = price;
	g_Items[item_id][ItemPotionType] = potion_type;

	g_ItemCount++;
	debug_log( 5, "g_itemCound %i", g_ItemCount); 
	return item_id;
}

// ======================== NATIVES ========================
public _m2_register_item(plugin, params)
{
	if (g_ItemCount >= MAX_ITEMS)
	{
		log_amx("[Metin2] Nu se mai pot inregistra iteme! Limita de %d a fost atinsa.", MAX_ITEMS);
		debug_log( 5, "Limita de inregistrare iteme a fost atinsa");
		return -1;
	}

	new szName[32];
	get_string(1, szName, charsmax(szName));

	new type        = get_param(2);
	new req_level   = get_param(3);
	new race_req    = get_param(4);
	new str         = get_param(5);
	new hp          = get_param(6);
	new dex         = get_param(7);
	new intt        = get_param(8);
	new crit        = get_param(9);
	new speed       = get_param(10);
	new price       = get_param(11);
	new potion_type = get_param(12);

	new item_id = g_ItemCount;

	copy(g_Items[item_id][ItemName], charsmax(g_Items[][ItemName]), szName);
	g_Items[item_id][ItemType]       = type;
	g_Items[item_id][ItemReqLevel]   = req_level;
	g_Items[item_id][ItemRaceReq]    = race_req;
	g_Items[item_id][ItemStr]        = str;
	g_Items[item_id][ItemHp]         = hp;
	g_Items[item_id][ItemDex]        = dex;
	g_Items[item_id][ItemInt]        = intt;
	g_Items[item_id][ItemCrit]       = crit;
	g_Items[item_id][ItemSpeed]      = speed;
	g_Items[item_id][ItemPrice]      = price;
	g_Items[item_id][ItemPotionType] = potion_type;

	g_ItemCount++;

	debug_log(5, "[Metin2] Item inregistrat: '%s' (ID %d, Type %d, Price %d)", szName, item_id, type, price);
	return item_id;
}

public _get_user_m2_level(plugin, params)
{
	new id = get_param(1);
	if (!is_user_connected(id)) return 0;
	return g_Player[id][g_Level];
}

public _get_user_m2_xp(plugin, params)
{
	new id = get_param(1);
	if (!is_user_connected(id)) return 0;
	return g_Player[id][g_XP];
}

public _set_user_m2_level(plugin, params)
{
	new id = get_param(1);
	new level = get_param(2);
	if (!is_user_connected(id) || level < 1) return 0;
	
	g_Player[id][g_Level] = level;
	recalc_max_mp(id);
	save_player(id);
	return 1;
}

public _set_user_m2_xp(plugin, params)
{
	new id = get_param(1);
	new xp = get_param(2);
	if (!is_user_connected(id) || xp < 0) return 0;
	
	g_Player[id][g_XP] = xp;
	save_player(id);
	return 1;
}

public _get_user_m2_yang(plugin, params)
{
	new id = get_param(1);
	if (!is_user_connected(id)) return 0;
	return g_Player[id][g_Yang];
}

public _set_user_m2_yang(plugin, params)
{
	new id = get_param(1);
	new yang = get_param(2);
	if (!is_user_connected(id) || yang < 0) return 0;
	
	g_Player[id][g_Yang] = yang;
	save_player(id);
	return 1;
}

public _get_user_m2_race(plugin, params)
{
	new id = get_param(1);
	if (!is_user_connected(id)) return 0;
	return g_Player[id][g_Race];
}

public _get_user_m2_str(plugin, params)
{
	new id = get_param(1);
	if (!is_user_connected(id)) return 0;
	return g_Player[id][g_STR];
}

public _get_user_m2_hp(plugin, params)
{
	new id = get_param(1);
	if (!is_user_connected(id)) return 0;
	return g_Player[id][g_HP];
}

public _get_user_m2_dex(plugin, params)
{
	new id = get_param(1);
	if (!is_user_connected(id)) return 0;
	return g_Player[id][g_DEX];
}

public _get_user_m2_int(plugin, params)
{
	new id = get_param(1);
	if (!is_user_connected(id)) return 0;
	return g_Player[id][g_INT];
}

public _get_user_m2_mp(plugin, params)
{
	new id = get_param(1);
	if (!is_user_connected(id)) return 0;
	return g_Player[id][g_MP];
}

public _get_user_m2_maxmp(plugin, params)
{
	new id = get_param(1);
	if (!is_user_connected(id)) return 0;
	return g_Player[id][g_MaxMP];
}

// ======================== NAME CHANGE BLOCK ========================
public OnClientUserInfoChanged(id)
{
	if (!is_user_connected(id))
		return FMRES_IGNORED;
	
	static oldname[32], newname[32];
	pev(id, pev_netname, oldname, charsmax(oldname));
	
	get_user_info(id, "name", newname, charsmax(newname));

	debug_log( 5, "OnClientUserInfoChanged a fost apelat, numele: %s -- A fost si blocat? uitativa in contiuare", oldname);
	
	if (!equal(oldname, newname) && oldname[0])
	{
		set_user_info(id, "name", oldname);
		client_print_color(id, print_team_default, "^4[Metin2]^1 Schimbarea numelui este blocata pe acest server!");
		debug_log( 5, "OnClientUserInfoChanged: Nume a fost blocat! %s", newname);
		return FMRES_HANDLED;
	}
	
	return FMRES_IGNORED;
}


// ======================== PLAYER LOAD / SAVE ========================
public client_putinserver(id)
{
	reset_player(id);
	load_player(id);
	
	set_task(3.0, "Task_WelcomeMsg", id);
	debug_log( 5, "Client_putinserver() a fost apelat, reset_player(), load_players() si set_task(TaslWelcomeMEssage) vor fi apelate!");
}

public Task_WelcomeMsg(id)
{
	if (!is_user_connected(id))
		return;
	

	debug_log(5, " public Task_WelcomeMEssage a fost apelat!" );
	if (g_Player[id][g_Race] == RACE_NONE)
	{
		client_print_color(id, print_team_default, "^4[Metin2]^1 Bun venit! Alege-ti rasa cu ^3/menu^1.");
	}
	else
	{
		client_print_color(id, print_team_default, "^4[Metin2]^1 Date incarcate. Level: ^3%d^1 | Yang: ^3%d", g_Player[id][g_Level], g_Player[id][g_Yang]);
	}
}

public client_disconnected(id)
{
	remove_task(id);
	save_player(id);
	reset_player(id);

	debug_log(5, "Client_DIsconnected() apelat" );
}

stock reset_player(id)
{
	g_Player[id][g_Level] = 1;
	g_Player[id][g_XP] = 0;
	g_Player[id][g_Yang] = 1000;
	g_Player[id][g_Race] = RACE_NONE;
	g_Player[id][g_STR] = 1;
	g_Player[id][g_HP] = 1;
	g_Player[id][g_DEX] = 1;
	g_Player[id][g_INT] = 1;
	g_Player[id][g_StatPoints] = 0;
	g_Player[id][g_SkillPoints] = 0;
	g_Player[id][g_InventoryCount] = 0;
	g_Player[id][g_MP] = 50;
	g_Player[id][g_MaxMP] = 50;
	
	for (new i = 0; i < MAX_SKILLS; i++)
		g_Player[id][g_SkillLevel][i] = 0;
	
	for (new i = 0; i < MAX_EQUIP_SLOTS; i++)
	{
		g_Player[id][g_Equipped][i] = 0;
		g_Player[id][g_EquippedUpgrade][i] = 0;
	}
	
	for (new i = 0; i < MAX_INVENTORY; i++)
	{
		g_Player[id][g_Inventory][i] = 0;
		g_Player[id][g_InventoryUpgrade][i] = 0;
	}
	
	for (new i = 0; i < 5; i++)
		g_SkillCooldown[id][i] = 0.0;
	
	g_AuraActive[id] = false;
	g_ReflectActive[id] = false;
	g_AmbushActive[id] = false;
	g_ResistActive[id] = false;
	g_PierceActive[id] = false;
	g_BlessActive[id] = false;
	g_ResistAmount[id] = 0.0;
	g_PierceAmount[id] = 0.0;
	g_BlessAmount[id] = 0.0;

	remove_task(id);		
	if (is_user_connected(id))
		set_user_rendering(id);


	debug_log(5, "Reset_Player() apelat cu succes" );
}

// ======================== PLAYER LOAD / SAVE (RESTORED FROM WORKING 0.2) ========================

stock load_player(id)
{
	new name[32], key[48];
	get_user_name(id, name, charsmax(name));
	formatex(key, charsmax(key), "m2_%s", name);
	
	new timestamp;
	new size = nvault_get_array(g_Vault, key, g_Player[id], PlayerData, timestamp);
	debug_log(3, "LOAD → key=%s | size=%d | Level=%d | XP=%d | Yang=%d | Race=%d", key, size, g_Player[id][g_Level], g_Player[id][g_XP], g_Player[id][g_Yang], g_Player[id][g_Race]);
	
	debug_log(5, " public Task_WelcomeMEssage a fost apelat!" );

	if (size <= 0)
	{
		g_Player[id][g_Level] = 1;
		g_Player[id][g_Yang] = 1000;
		g_Player[id][g_MP] = 50;
		g_Player[id][g_MaxMP] = 50;
	}
	else
	{
		recalc_max_mp(id);
	}
}

stock save_player(id)
{
	// Ne asigurăm că ID-ul este in intervalul corect
	if (id < 1 || id > MaxClients)
		return;
    
	new name[32], key[48];
	get_user_name(id, name, charsmax(name));
    
	if (!name[0])
		return;
        
	formatex(key, charsmax(key), "m2_%s", name);
	nvault_set_array(g_Vault, key, g_Player[id], PlayerData);
	debug_log(5, "SAVE → key=%s | Level=%d | XP=%d | Yang=%d | Race=%d | size=%d", key, g_Player[id][g_Level], g_Player[id][g_XP], g_Player[id][g_Yang], g_Player[id][g_Race], PlayerData);
}


stock recalc_max_mp(id)
{
	// Max MP = 50 + (INT * 8) + (Level * 3) + bonus iteme
	new maxmp = 50 + (g_Player[id][g_INT] * 8) + (g_Player[id][g_Level] * 3);
	
	for (new i = 0; i < MAX_EQUIP_SLOTS; i++)
	{
		new itemid = g_Player[id][g_Equipped][i];
		if (itemid > 0 && itemid < g_ItemCount)
			maxmp += g_Items[itemid][ItemInt] * 3 + g_Player[id][g_EquippedUpgrade][i] * 2;
	}
	
	g_Player[id][g_MaxMP] = maxmp;
	if (g_Player[id][g_MP] > maxmp)
		g_Player[id][g_MP] = maxmp;
}

stock add_xp(id, amount)
{
	if (!is_user_connected(id) || g_Player[id][g_Race] == RACE_NONE)
		return;
	
	g_Player[id][g_XP] += amount;
	
	new needed = get_xp_needed(g_Player[id][g_Level]);
	
	while (g_Player[id][g_XP] >= needed)
	{
		g_Player[id][g_XP] -= needed;
		g_Player[id][g_Level]++;
		g_Player[id][g_StatPoints]++;
		g_Player[id][g_SkillPoints]++;
		
		recalc_max_mp(id);
		g_Player[id][g_MP] = g_Player[id][g_MaxMP];
		
		set_user_rendering(id, kRenderFxGlowShell, 255, 215, 0, kRenderNormal, 40);
		emit_sound(id, CHAN_AUTO, "buttons/bell1.wav", 1.0, ATTN_NORM, 0, PITCH_HIGH);
		
		client_print_color(0, print_team_default, "^4[Metin2]^1 %n a ajuns la ^3Level %d^1!", id, g_Player[id][g_Level]);
		
		new ret;
		ExecuteForward(g_fwd_LevelUp, ret, id, g_Player[id][g_Level]);
		
		set_task(2.0, "RemoveGlow", id);
		
		needed = get_xp_needed(g_Player[id][g_Level]);
	}
	
	// ← ADAUGĂ ASTA
	save_player(id);
}

stock get_xp_needed(level)
{
	return 100 + (level * 75) + (level * level * 5);
}

public RemoveGlow(id)
{
	if (is_user_connected(id))
		set_user_rendering(id);
}

public OnDeath()
{
	new killer = read_data(1);
	new victim = read_data(2);
	new headshot = read_data(3);
	
	if (!is_user_connected(killer) || killer == victim)
		return;
	if (g_Player[killer][g_Race] == RACE_NONE)
		return;
	
	new xp = get_pcvar_num(cvar_xp_kill);
	new yang = get_pcvar_num(cvar_yang_kill);
	
	if (headshot)
	{
		xp += get_pcvar_num(cvar_xp_hs);
		yang += get_pcvar_num(cvar_yang_hs);
	}
	
	add_xp(killer, xp);
	g_Player[killer][g_Yang] += yang;
	save_player(killer);
	
	client_print_color(killer, print_team_default, "^4[Metin2]^1 +%d XP | +%d Yang%s", xp, yang, headshot ? " ^3(Headshot)" : "");
	
	// Forward kill
	new ret;
	ExecuteForward(g_fwd_PlayerKill, ret, killer, victim, xp, yang);
}

public OnPlayerSpawn(id)
{
	if (!is_user_alive(id))
		return;

	remove_task(id);
	set_user_rendering(id);

	g_AuraActive[id] = false;
	g_ReflectActive[id] = false;
	g_AmbushActive[id] = false;
	g_ResistActive[id] = false;
	g_PierceActive[id] = false;
	g_BlessActive[id] = false;
	g_ResistAmount[id] = 0.0;
	g_PierceAmount[id] = 0.0;
	g_BlessAmount[id] = 0.0;
	
	recalc_max_mp(id);
	g_Player[id][g_MP] = g_Player[id][g_MaxMP];
	
	new hp = 100 + (g_Player[id][g_HP] * 10);
	
	for (new i = 0; i < MAX_EQUIP_SLOTS; i++)
	{
		new itemid = g_Player[id][g_Equipped][i];
		if (itemid > 0 && itemid < g_ItemCount)
		{
			new upg = g_Player[id][g_EquippedUpgrade][i];
			hp += g_Items[itemid][ItemHp] + (upg * 3);
		}
	}
	
	set_user_health(id, hp);
	
	new Float:speed = 250.0;
	for (new i = 0; i < MAX_EQUIP_SLOTS; i++)
	{
		new itemid = g_Player[id][g_Equipped][i];
		if (itemid > 0 && itemid < g_ItemCount)
			speed += float(g_Items[itemid][ItemSpeed] + g_Player[id][g_EquippedUpgrade][i] * 2);
	}
	
	set_user_maxspeed(id, speed);
}

public OnTakeDamage(victim, inflictor, attacker, Float:damage, damagebits)
{
	if (!is_user_connected(attacker) || !is_user_connected(victim))
		return HC_CONTINUE;
	if (attacker == victim)
		return HC_CONTINUE;
	
	new Float:str_bonus = float(g_Player[attacker][g_STR]) * 1.5;
	
	// Bonus arma
	new weap_id = g_Player[attacker][g_Equipped][SLOT_WEAPON];
	new weap_upg = g_Player[attacker][g_EquippedUpgrade][SLOT_WEAPON];
	new Float:weap_bonus = 0.0;
	if (weap_id > 0 && weap_id < g_ItemCount)
		weap_bonus = float(g_Items[weap_id][ItemStr] * 2 + weap_upg * 4);
	
	// Aura Sabiei / Tais Vrajit / Atac Intens
	if (g_AuraActive[attacker])
		weap_bonus += 25.0 + float(g_Player[attacker][g_SkillLevel][(g_Player[attacker][g_Race]-1)*5] * 2);
	
	// Ambush (crit)
	if (g_AmbushActive[attacker])
	{
		damage *= 3.0;
		g_AmbushActive[attacker] = false;
		client_print_color(attacker, print_team_default, "^4[Metin2]^1 ^3AMBUSH CRIT!");
	}
	
	// Armor Pierce - reduce defense
	new Float:def = float(g_Player[victim][g_DEX]) * 0.8;
	new armor_id = g_Player[victim][g_Equipped][SLOT_ARMOR];
	if (armor_id > 0 && armor_id < g_ItemCount)
		def += float(g_Items[armor_id][ItemHp] + g_Player[victim][g_EquippedUpgrade][SLOT_ARMOR] * 3);
	
	if (g_PierceActive[attacker])
	{
		def *= (1.0 - g_PierceAmount[attacker]);
		if (def < 0.0) def = 0.0;
	}
	
	// Bless - extra defense
	if (g_BlessActive[victim])
		def += g_BlessAmount[victim];
	
	new Float:final = damage + str_bonus + weap_bonus - def;
	if (final < 1.0) final = 1.0;
	
	// Corp Rezistent - damage reduction
	if (g_ResistActive[victim])
	{
		final *= (1.0 - g_ResistAmount[victim]);
		if (final < 1.0) final = 1.0;
	}
	
	// Reflect (Sura)
	if (g_ReflectActive[victim] && is_user_alive(attacker))
	{
		new Float:reflect = final * 0.35;
		ExecuteHamB(Ham_TakeDamage, attacker, victim, victim, reflect, DMG_GENERIC);
	}
	
	SetHookChainArg(4, ATYPE_FLOAT, final);
	return HC_CONTINUE;
}

public Task_HUD()
{
	for (new id = 1; id <= MaxClients; id++)
	{
		if (!is_user_connected(id) || is_user_bot(id))
			continue;
		if (g_Player[id][g_Race] == RACE_NONE)
			continue;

		new needed = get_xp_needed(g_Player[id][g_Level]);
		
		// Procent progres (cât ai făcut deja din nivelul curent)
		new Float:pct = (float(g_Player[id][g_XP]) / float(needed)) * 100.0;

		set_hudmessage(0, 255, 100, -1.0, 0.90, 0, 0.0, 1.1, 0.0, 0.0, -1);
		ShowSyncHudMsg(id, g_HudSync, "[Metin2] %s | Lvl %d | XP %.1f%% | Yang %d | MP %d/%d | Stat %d | SkillP %d",
			g_RaceName[g_Player[id][g_Race]],
			g_Player[id][g_Level],
			pct,
			g_Player[id][g_Yang],
			g_Player[id][g_MP], g_Player[id][g_MaxMP],
			g_Player[id][g_StatPoints],
			g_Player[id][g_SkillPoints]);
	}
}

public Task_ManaRegen()
{
	for (new id = 1; id <= MaxClients; id++)
	{
		if (!is_user_alive(id)) continue;
		if (g_Player[id][g_Race] == RACE_NONE) continue;
		
		if (g_Player[id][g_MP] < g_Player[id][g_MaxMP])
		{
			g_Player[id][g_MP] += 3 + (g_Player[id][g_INT] / 5);
			if (g_Player[id][g_MP] > g_Player[id][g_MaxMP])
				g_Player[id][g_MP] = g_Player[id][g_MaxMP];
		}
	}
}

// ======================== SKILL SYSTEM ========================

stock bool:can_use_skill(id, skill_slot)
{
	if (!is_user_alive(id) || g_Player[id][g_Race] == RACE_NONE)
		return false;
	
	new Float:now = get_gametime();
	
	if (now < g_SkillCooldown[id][skill_slot])
	{
		client_print_color(id, print_team_default, "^4[Metin2]^1 Skill in cooldown!");
		return false;
	}
	
	new race = g_Player[id][g_Race];
	new skill_idx = (race - 1) * 5 + skill_slot;
	
	if (g_Player[id][g_SkillLevel][skill_idx] <= 0)
	{
		client_print_color(id, print_team_default, "^4[Metin2]^1 Skill-ul nu este invatat!");
		return false;
	}
	
	new cost = g_SkillManaCost[skill_slot] + (g_Player[id][g_SkillLevel][skill_idx] / 4);
	if (g_Player[id][g_MP] < cost)
	{
		client_print_color(id, print_team_default, "^4[Metin2]^1 Mana insuficienta! Ai nevoie de %d MP.", cost);
		return false;
	}
	
	g_Player[id][g_MP] -= cost;
	return true;
}

stock apply_skill_cooldown(id, skill_slot, Float:base_cd)
{
	new race = g_Player[id][g_Race];
	new skill_idx = (race - 1) * 5 + skill_slot;
	new lvl = g_Player[id][g_SkillLevel][skill_idx];
	
	// Cooldown scade pe masura ce skill-ul creste
	new Float:cd = base_cd - (float(lvl) * 0.25);
	if (cd < 4.0) cd = 4.0;
	
	g_SkillCooldown[id][skill_slot] = get_gametime() + cd;
}

public cmd_skill1(id) { execute_skill(id, 0); return PLUGIN_HANDLED; }
public cmd_skill2(id) { execute_skill(id, 1); return PLUGIN_HANDLED; }
public cmd_skill3(id) { execute_skill(id, 2); return PLUGIN_HANDLED; }
public cmd_skill4(id) { execute_skill(id, 3); return PLUGIN_HANDLED; }
public cmd_skill5(id) { execute_skill(id, 4); return PLUGIN_HANDLED; }

stock execute_skill(id, slot)
{
	if (!can_use_skill(id, slot))
		return;
	
	new race = g_Player[id][g_Race];
	new skill_idx = (race - 1) * 5 + slot;
	new lvl = g_Player[id][g_SkillLevel][skill_idx];
	
	client_print_color(id, print_team_default, "^4[Metin2]^1 Activezi: ^3%s ^1(Nivel %d)", g_SkillName[skill_idx], lvl);
	
	switch (race)
	{
		case RACE_WARRIOR: skill_warrior(id, slot, lvl);
		case RACE_SURA:    skill_sura(id, slot, lvl);
		case RACE_NINJA:   skill_ninja(id, slot, lvl);
		case RACE_SHAMAN:  skill_shaman(id, slot, lvl);
	}
	
	// Forward skill used
	new ret;
	ExecuteForward(g_fwd_SkillUsed, ret, id, skill_idx, lvl);
}

// ---------- WARRIOR ----------
stock skill_warrior(id, slot, lvl)
{
	new Float:power = float(lvl) * 1.8 + float(g_Player[id][g_INT]) * 0.6;
	
	switch (slot)
	{
		case 0: // Aura Sabiei - damage boost
		{
			g_AuraActive[id] = true;
			new Float:dur = 8.0 + (lvl * 0.25) + (g_Player[id][g_INT] * 0.1);
			set_user_rendering(id, kRenderFxGlowShell, 255, 80, 0, kRenderNormal, 40);
			set_task(dur, "RemoveAura", id);
			apply_skill_cooldown(id, 0, 22.0);
			client_print_color(id, print_team_default, "^4[Metin2]^1 Aura Sabiei: +damage (%.0f sec). Bonus: +%.0f dmg!", dur, 25.0 + float(lvl * 2));
		}
		case 1: // Corp Rezistent - real damage reduction
		{
			g_ResistActive[id] = true;
			g_ResistAmount[id] = 0.25 + (float(lvl) * 0.008) + (float(g_Player[id][g_HP]) * 0.002);
			if (g_ResistAmount[id] > 0.55) g_ResistAmount[id] = 0.55;
			
			new Float:dur = 7.0 + (lvl * 0.2);
			set_user_rendering(id, kRenderFxGlowShell, 30, 100, 255, kRenderNormal, 35);
			set_task(dur, "RemoveResist", id);
			apply_skill_cooldown(id, 1, 28.0);
			client_print_color(id, print_team_default, "^4[Metin2]^1 Corp Rezistent: reducere damage cu ^3%.0f%% ^1timp de %.1f sec!", g_ResistAmount[id] * 100.0, dur);
		}
		case 2: // Izbitura - stun
		{
			new target = get_aim_target(id);
			if (is_user_alive(target))
			{
				new Float:stun = 1.4 + (lvl * 0.06) + (g_Player[id][g_INT] * 0.02);
				set_pev(target, pev_flags, pev(target, pev_flags) | FL_FROZEN);
				set_task(stun, "Unfreeze", target);
				apply_skill_cooldown(id, 2, 18.0);
				client_print_color(id, print_team_default, "^4[Metin2]^1 Izbitura: inamic inghetat ^3%.1f secunde^1!", stun);
			}
			else
			{
				apply_skill_cooldown(id, 2, 18.0);
				client_print_color(id, print_team_default, "^4[Metin2]^1 Nicio tinta valida in fata ta.");
			}
		}
		case 3: // Dash
		{
			new Float:angles[3], Float:vec[3];
			pev(id, pev_v_angle, angles);
			angle_vector(angles, ANGLEVECTOR_FORWARD, vec);
	
			new Float:speed = 900.0 + (lvl * 15.0);
			vec[0] *= speed;
			vec[1] *= speed;
			vec[2] = 150.0;
	
			set_pev(id, pev_velocity, vec);
	
			apply_skill_cooldown(id, 3, 14.0);
			client_print_color(id, print_team_default, "^4[Metin2]^1 Atac Sabie: dash inainte!");
		}
		case 4: // Vartej AoE
		{
			new Float:origin[3];
			pev(id, pev_origin, origin);
			
			new Float:radius = 180.0 + (lvl * 3.0);
			new Float:dmg = 35.0 + power;
			
			new hit = 0;
			for (new i = 1; i <= MaxClients; i++)
			{
				if (!is_user_alive(i) || i == id) continue;
				if (get_user_team(i) == get_user_team(id)) continue;
				
				new Float:torigin[3];
				pev(i, pev_origin, torigin);
				
				if (get_distance_f(origin, torigin) < radius)
				{
					ExecuteHamB(Ham_TakeDamage, i, id, id, dmg, DMG_SLASH);
					hit++;
				}
			}
			apply_skill_cooldown(id, 4, 26.0);
			client_print_color(id, print_team_default, "^4[Metin2]^1 Vartej Sabie: AoE %.0f dmg in raza %.0f | Inamici loviti: %d", dmg, radius, hit);
		}
	}
}

public RemoveAura(id)
{
	g_AuraActive[id] = false;
	if (is_user_connected(id))
		set_user_rendering(id);
}

public RemoveResist(id)
{
	g_ResistActive[id] = false;
	g_ResistAmount[id] = 0.0;
	if (is_user_connected(id))
		set_user_rendering(id);
}

// ---------- SURA ----------
stock skill_sura(id, slot, lvl)
{	
	switch (slot)
	{
		case 0: // Tais Vrajit - damage + lifesteal simplified as damage boost
		{
			g_AuraActive[id] = true;
			new Float:dur = 7.0 + (lvl * 0.2);
			set_user_rendering(id, kRenderFxGlowShell, 180, 50, 255, kRenderNormal, 40);
			set_task(dur, "RemoveAura", id);
			apply_skill_cooldown(id, 0, 20.0);
			client_print_color(id, print_team_default, "^4[Metin2]^1 Tais Vrajit: +damage magic (%.0f sec). Putere bazata pe INT!", dur);
		}
		case 1: // Reflect
		{
			g_ReflectActive[id] = true;
			new Float:dur = 6.0 + (lvl * 0.18);
			set_user_rendering(id, kRenderFxGlowShell, 255, 0, 100, kRenderNormal, 35);
			set_task(dur, "RemoveReflect", id);
			apply_skill_cooldown(id, 1, 32.0);
			client_print_color(id, print_team_default, "^4[Metin2]^1 Armura Vrajita: reflecti ^335%% ^1din damage-ul primit timp de %.1f sec!", dur);
		}
		case 2: // Armor Pierce - real pierce
		{
			g_PierceActive[id] = true;
			g_PierceAmount[id] = 0.35 + (float(lvl) * 0.01) + (float(g_Player[id][g_INT]) * 0.005);
			if (g_PierceAmount[id] > 0.70) g_PierceAmount[id] = 0.70;
			
			new Float:dur = 6.0 + (lvl * 0.15);
			set_task(dur, "RemovePierce", id);
			apply_skill_cooldown(id, 2, 16.0);
			client_print_color(id, print_team_default, "^4[Metin2]^1 Lovitura Degetului (Armor Pierce): ignori ^3%.0f%% ^1din apararea inamicului timp de %.1f sec!", g_PierceAmount[id] * 100.0, dur);
		}
		case 3: // Slow
		{
			new target = get_aim_target(id);
			if (is_user_alive(target))
			{
				new Float:slow_dur = 3.5 + (lvl * 0.1);
				set_user_maxspeed(target, 110.0);
				set_task(slow_dur, "RestoreSpeed", target);
				apply_skill_cooldown(id, 3, 18.0);
				client_print_color(id, print_team_default, "^4[Metin2]^1 Atacul Fulgerului: tinta incetinita la 110 speed timp de ^3%.1f sec^1!", slow_dur);
			}
			else
			{
				apply_skill_cooldown(id, 3, 18.0);
				client_print_color(id, print_team_default, "^4[Metin2]^1 Nicio tinta valida.");
			}
		}
		case 4: // Pietrificare - real freeze + slow after
		{
			new target = get_aim_target(id);
			if (is_user_alive(target))
			{
				new Float:stun = 1.8 + (lvl * 0.05) + (g_Player[id][g_INT] * 0.03);
				set_pev(target, pev_flags, pev(target, pev_flags) | FL_FROZEN);
				set_task(stun, "Unfreeze", target);
				
				// After unfreeze, residual slow
				set_task(stun + 0.1, "ApplyResidualSlow", target);
				
				apply_skill_cooldown(id, 4, 38.0);
				client_print_color(id, print_team_default, "^4[Metin2]^1 Pietrificare: inamicul este ^3pietrificat %.1f sec^1 + slow ulterior!", stun);
			}
			else
			{
				apply_skill_cooldown(id, 4, 38.0);
				client_print_color(id, print_team_default, "^4[Metin2]^1 Nicio tinta valida pentru Pietrificare.");
			}
		}
	}
}

public RemoveReflect(id)
{
	g_ReflectActive[id] = false;
	if (is_user_connected(id))
		set_user_rendering(id);
}

public RemovePierce(id)
{
	g_PierceActive[id] = false;
	g_PierceAmount[id] = 0.0;
}

public ApplyResidualSlow(id)
{
	if (is_user_alive(id))
	{
		set_user_maxspeed(id, 150.0);
		set_task(2.5, "RestoreSpeed", id);
	}
}

public cmd_reset(id)
{
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;
	
	if (g_Player[id][g_Race] == RACE_NONE)
	{
		client_print_color(id, print_team_default, "^4[Metin2]^1 Nu ai inca o rasa aleasa!");
		return PLUGIN_HANDLED;
	}
	
	new level = g_Player[id][g_Level];
	
	// Pastreaza Level, XP, Yang, Inventar, Echipament
	// Reseteaza rasa + stats + skill-uri
	
	g_Player[id][g_Race] = RACE_NONE;
	
	g_Player[id][g_STR] = 1;
	g_Player[id][g_HP]  = 1;
	g_Player[id][g_DEX] = 1;
	g_Player[id][g_INT] = 1;
	
	// Puncte totale ca la un caracter nou de acelasi level
	g_Player[id][g_StatPoints]  = 5 + (level - 1);
	g_Player[id][g_SkillPoints] = 3 + (level - 1);
	
	for (new i = 0; i < MAX_SKILLS; i++)
		g_Player[id][g_SkillLevel][i] = 0;
	
	// Opreste buff-uri active
	g_AuraActive[id] = false;
	g_ReflectActive[id] = false;
	g_AmbushActive[id] = false;
	g_ResistActive[id] = false;
	g_PierceActive[id] = false;
	g_BlessActive[id] = false;
	g_ResistAmount[id] = 0.0;
	g_PierceAmount[id] = 0.0;
	g_BlessAmount[id] = 0.0;
	
	remove_task(id);
	if (is_user_alive(id))
		set_user_rendering(id);
	
	recalc_max_mp(id);
	
	save_player(id);
	
	client_print_color(id, print_team_default, "^4[Metin2]^1 Caracter resetat! Level: ^3%d^1 | Stat Points: ^3%d^1 | Skill Points: ^3%d", level, g_Player[id][g_StatPoints], g_Player[id][g_SkillPoints]);
	client_print_color(id, print_team_default, "^4[Metin2]^1 Alege noua rasa cu ^3/menu^1.");
	
	return PLUGIN_HANDLED;
}

// ---------- NINJA ----------
stock skill_ninja(id, slot, lvl)
{
	switch (slot)
	{
		case 0: // Camuflaj
		{
			new Float:dur = 4.5 + (lvl * 0.18) + (g_Player[id][g_INT] * 0.05);
			set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, 8);
			set_task(dur, "RemoveInvis", id);
			apply_skill_cooldown(id, 0, 28.0);
			client_print_color(id, print_team_default, "^4[Metin2]^1 Camuflaj: esti aproape invizibil timp de ^3%.1f secunde^1!", dur);
		}
		case 1: // Speed
		{
			new Float:spd = 420.0 + (lvl * 6.0) + (g_Player[id][g_DEX] * 2.0);
			set_user_maxspeed(id, spd);
			new Float:dur = 6.0 + (lvl * 0.1);
			set_task(dur, "RestoreSpeed", id);
			apply_skill_cooldown(id, 1, 22.0);
			client_print_color(id, print_team_default, "^4[Metin2]^1 Atacul Fulgerator: viteza crescuta la ^3%.0f ^1timp de %.1f sec!", spd, dur);
		}
		case 2: // Ambush
		{
			g_AmbushActive[id] = true;
			apply_skill_cooldown(id, 2, 18.0);
			client_print_color(id, print_team_default, "^4[Metin2]^1 Ambush pregatit! Urmatorul atac va fi ^3CRITIC x3^1.");
		}
		case 3: // Poison
		{
			new target = get_aim_target(id);
			if (is_user_alive(target))
			{
				new taskid = (id * 100) + target;
				new ticks = 4 + (lvl / 6);
				set_task(1.0, "PoisonTick", taskid, _, _, "a", ticks);
				apply_skill_cooldown(id, 3, 20.0);
				client_print_color(id, print_team_default, "^4[Metin2]^1 Otrava: DoT pe tinta (%d tick-uri de poison)!", ticks);
			}
			else
			{
				apply_skill_cooldown(id, 3, 20.0);
				client_print_color(id, print_team_default, "^4[Metin2]^1 Nicio tinta valida.");
			}
		}
		case 4: // Ploaie de sageti (AoE mic)
		{
			new Float:origin[3];
			pev(id, pev_origin, origin);
			
			new Float:dmg = 28.0 + float(lvl) * 2.2 + float(g_Player[id][g_INT]) * 0.7;
			
			new hit = 0;
			for (new i = 1; i <= MaxClients; i++)
			{
				if (!is_user_alive(i) || i == id) continue;
				if (get_user_team(i) == get_user_team(id)) continue;
				
				new Float:torigin[3];
				pev(i, pev_origin, torigin);
				
				if (get_distance_f(origin, torigin) < 250.0)
				{
					ExecuteHamB(Ham_TakeDamage, i, id, id, dmg, DMG_BULLET);
					hit++;
				}
			}
			apply_skill_cooldown(id, 4, 30.0);
			client_print_color(id, print_team_default, "^4[Metin2]^1 Ploaie de Sageti: AoE %.0f dmg | Inamici loviti: %d", dmg, hit);
		}
	}
}

// ---------- SHAMAN ----------
stock skill_shaman(id, slot, lvl)
{
	new Float:power = float(lvl) * 2.0 + float(g_Player[id][g_INT]) * 1.1;
	
	switch (slot)
	{
		case 0: // Heal
		{
			new heal = 40 + floatround(power);
			new hp = get_user_health(id);
			new maxhp = 100 + g_Player[id][g_HP] * 10;
			
			// Bonus armura
			for (new i = 0; i < MAX_EQUIP_SLOTS; i++)
			{
				new itemid = g_Player[id][g_Equipped][i];
				if (itemid > 0 && itemid < g_ItemCount)
					maxhp += g_Items[itemid][ItemHp] + g_Player[id][g_EquippedUpgrade][i] * 3;
			}
			
			set_user_health(id, min(hp + heal, maxhp));
			apply_skill_cooldown(id, 0, 14.0);
			client_print_color(id, print_team_default, "^4[Metin2]^1 Lecuire: ai vindecat ^3%d HP^1 (bazat pe INT + nivel skill)!", heal);
		}
		case 1: // Atac Intens (self damage buff)
		{
			g_AuraActive[id] = true;
			new Float:dur = 8.0 + (lvl * 0.15);
			set_user_rendering(id, kRenderFxGlowShell, 255, 200, 50, kRenderNormal, 40);
			set_task(dur, "RemoveAura", id);
			apply_skill_cooldown(id, 1, 35.0);
			client_print_color(id, print_team_default, "^4[Metin2]^1 Atac Intens: +damage activ timp de ^3%.1f secunde^1!", dur);
		}
		case 2: // Binecuvantare - real defense buff
		{
			g_BlessActive[id] = true;
			g_BlessAmount[id] = 15.0 + (float(lvl) * 1.2) + (float(g_Player[id][g_INT]) * 0.8);
			
			new Float:dur = 9.0 + (lvl * 0.2);
			set_user_rendering(id, kRenderFxGlowShell, 100, 255, 100, kRenderNormal, 35);
			set_task(dur, "RemoveBless", id);
			apply_skill_cooldown(id, 2, 28.0);
			client_print_color(id, print_team_default, "^4[Metin2]^1 Binecuvantare: +%.0f defense timp de ^3%.1f secunde^1!", g_BlessAmount[id], dur);
		}
		case 3: // Iutesenie - reset cooldowns
		{
			for (new i = 0; i < 5; i++)
				g_SkillCooldown[id][i] = 0.0;
			apply_skill_cooldown(id, 3, 55.0);
			client_print_color(id, print_team_default, "^4[Metin2]^1 Iutesenie: ^3toate cooldown-urile au fost resetate^1! (CD lung pe acest skill)");
		}
		case 4: // Chemarea Fulgerului - flash + small AoE stun chance
		{
			new Float:origin[3];
			pev(id, pev_origin, origin);

			engfunc(EngFunc_MessageBegin, MSG_PVS, get_user_msgid("ScreenFade"), origin, 0);
			write_short(1<<10);
			write_short(1<<10);
			write_short(1<<12);
			write_byte(255);
			write_byte(255);
			write_byte(255);
			write_byte(220);
			message_end();
			
			// Small chance to stun nearby enemies
			new Float:radius = 200.0 + (lvl * 2.0);
			new stunned = 0;
			for (new i = 1; i <= MaxClients; i++)
			{
				if (!is_user_alive(i) || i == id) continue;
				if (get_user_team(i) == get_user_team(id)) continue;
				
				new Float:torigin[3];
				pev(i, pev_origin, torigin);
				
				if (get_distance_f(origin, torigin) < radius)
				{
					if (random_num(1, 100) <= (25 + lvl / 2))
					{
						set_pev(i, pev_flags, pev(i, pev_flags) | FL_FROZEN);
						set_task(1.2 + (lvl * 0.03), "Unfreeze", i);
						stunned++;
					}
				}
			}
			
			apply_skill_cooldown(id, 4, 32.0);
			client_print_color(id, print_team_default, "^4[Metin2]^1 Chemarea Fulgerului: flash + sansa de stun pe inamicii apropiati (stunati: %d)!", stunned);
		}
	}
}

public RemoveBless(id)
{
	g_BlessActive[id] = false;
	g_BlessAmount[id] = 0.0;
	if (is_user_connected(id))
		set_user_rendering(id);
}

public Unfreeze(id)
{
	if (is_user_alive(id))
		set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_FROZEN);
}

public RestoreSpeed(id)
{
	if (is_user_alive(id))
	{
		// Restore to base + item bonuses
		new Float:speed = 250.0;
		for (new i = 0; i < MAX_EQUIP_SLOTS; i++)
		{
			new itemid = g_Player[id][g_Equipped][i];
			if (itemid > 0 && itemid < g_ItemCount)
				speed += float(g_Items[itemid][ItemSpeed] + g_Player[id][g_EquippedUpgrade][i] * 2);
		}
		set_user_maxspeed(id, speed);
	}
}

public RemoveInvis(id)
{
	if (is_user_connected(id))
		set_user_rendering(id);
}

public PoisonTick(taskid)
{
	new attacker = taskid / 100;
	new target = taskid % 100;
	
	if (is_user_alive(target) && is_user_connected(attacker))
		ExecuteHamB(Ham_TakeDamage, target, attacker, attacker, 9.0 + float(g_Player[attacker][g_INT]) * 0.3, DMG_POISON);
}

stock get_aim_target(id)
{
	new Float:start[3], Float:view[3], Float:end[3];
	pev(id, pev_origin, start);
	pev(id, pev_view_ofs, view);
	start[2] += view[2];
	
	new Float:angles[3];
	pev(id, pev_v_angle, angles);
	angle_vector(angles, ANGLEVECTOR_FORWARD, end);
	
	end[0] = start[0] + end[0] * 9999.0;
	end[1] = start[1] + end[1] * 9999.0;
	end[2] = start[2] + end[2] * 9999.0;
	
	new tr = create_tr2();
	engfunc(EngFunc_TraceLine, start, end, DONT_IGNORE_MONSTERS, id, tr);
	new ent = get_tr2(tr, TR_pHit);
	free_tr2(tr);
	
	if (is_user_alive(ent))
		return ent;
	
	return 0;
}

// ======================== ADMIN COMMANDS ========================
public cmd_admin_set_level(id, level, cid)
{
	if (!cmd_access(id, level, cid, 3))
		return PLUGIN_HANDLED;
	
	new arg[32], arg2[16];
	read_argv(1, arg, charsmax(arg));
	read_argv(2, arg2, charsmax(arg2));
	
	new target = cmd_target(id, arg, CMDTARGET_NO_BOTS);
	if (!target) return PLUGIN_HANDLED;
	
	new newlevel = str_to_num(arg2);
	if (newlevel < 1) newlevel = 1;
	if (newlevel > 999) newlevel = 999;
	
	g_Player[target][g_Level] = newlevel;
	recalc_max_mp(target);
	save_player(target);
	
	client_print_color(id, print_team_default, "^4[Metin2]^1 Ai setat level-ul lui ^3%n^1 la ^3%d", target, newlevel);
	client_print_color(target, print_team_default, "^4[Metin2]^1 Un admin ti-a setat level-ul la ^3%d", newlevel);
	
	return PLUGIN_HANDLED;
}

public cmd_admin_set_xp(id, level, cid)
{
	if (!cmd_access(id, level, cid, 3))
		return PLUGIN_HANDLED;
	
	new arg[32], arg2[16];
	read_argv(1, arg, charsmax(arg));
	read_argv(2, arg2, charsmax(arg2));
	
	new target = cmd_target(id, arg, CMDTARGET_NO_BOTS);
	if (!target) return PLUGIN_HANDLED;
	
	new newxp = str_to_num(arg2);
	if (newxp < 0) newxp = 0;
	
	g_Player[target][g_XP] = newxp;
	save_player(target);
	
	client_print_color(id, print_team_default, "^4[Metin2]^1 Ai setat XP-ul lui ^3%n^1 la ^3%d", target, newxp);
	client_print_color(target, print_team_default, "^4[Metin2]^1 Un admin ti-a setat XP-ul la ^3%d", newxp);
	
	return PLUGIN_HANDLED;
}

public cmd_admin_set_statuspoints(id, level, cid)
{
	if (!cmd_access(id, level, cid, 3))
		return PLUGIN_HANDLED;
	
	new arg[32], arg2[16];
	read_argv(1, arg, charsmax(arg));
	read_argv(2, arg2, charsmax(arg2));
	
	new target = cmd_target(id, arg, CMDTARGET_NO_BOTS);
	if (!target) return PLUGIN_HANDLED;
	
	new points = str_to_num(arg2);
	if (points < 0) points = 0;
	
	g_Player[target][g_StatPoints] = points;
	save_player(target);
	
	client_print_color(id, print_team_default, "^4[Metin2]^1 Ai setat Status Points lui ^3%n^1 la ^3%d", target, points);
	client_print_color(target, print_team_default, "^4[Metin2]^1 Un admin ti-a setat Status Points la ^3%d", points);
	
	return PLUGIN_HANDLED;
}

public cmd_admin_set_yang(id, level, cid)
{
	if (!cmd_access(id, level, cid, 3))
		return PLUGIN_HANDLED;
	
	new arg[32], arg2[16];
	read_argv(1, arg, charsmax(arg));
	read_argv(2, arg2, charsmax(arg2));
	
	new target = cmd_target(id, arg, CMDTARGET_NO_BOTS);
	if (!target) return PLUGIN_HANDLED;
	
	new yang = str_to_num(arg2);
	if (yang < 0) yang = 0;
	
	g_Player[target][g_Yang] = yang;
	save_player(target);
	
	client_print_color(id, print_team_default, "^4[Metin2]^1 Ai setat Yang-ul lui ^3%n^1 la ^3%d", target, yang);
	client_print_color(target, print_team_default, "^4[Metin2]^1 Un admin ti-a setat Yang-ul la ^3%d", yang);
	
	return PLUGIN_HANDLED;
}

public cmd_admin_set_skillpoints(id, level, cid)
{
	if (!cmd_access(id, level, cid, 3))
		return PLUGIN_HANDLED;
	
	new arg[32], arg2[16];
	read_argv(1, arg, charsmax(arg));
	read_argv(2, arg2, charsmax(arg2));
	
	new target = cmd_target(id, arg, CMDTARGET_NO_BOTS);
	if (!target) return PLUGIN_HANDLED;
	
	new points = str_to_num(arg2);
	if (points < 0) points = 0;
	
	g_Player[target][g_SkillPoints] = points;
	save_player(target);
	
	client_print_color(id, print_team_default, "^4[Metin2]^1 Ai setat Skill Points lui ^3%n^1 la ^3%d", target, points);
	client_print_color(target, print_team_default, "^4[Metin2]^1 Un admin ti-a setat Skill Points la ^3%d", points);
	
	return PLUGIN_HANDLED;
}

// ======================== MENIURI ========================

public cmd_menu(id)
{
	new menu = menu_create("\y[Metin2] Meniu Principal", "menu_handler");
	menu_additem(menu, "Alege Rasa", "1");
	menu_additem(menu, "Statut / Alocare Puncte", "2");
	menu_additem(menu, "Skill-uri", "3");
	menu_additem(menu, "Inventar & Echipare", "4");
	menu_additem(menu, "Fierar (Upgrade)", "5");
	menu_additem(menu, "Magazin", "6");
	menu_additem(menu, "Ghid Bind-uri", "7");
	menu_display(id, menu);
	return PLUGIN_HANDLED;
}

public menu_handler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new data[6], name[32];
	new access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback);
	
	new key = str_to_num(data);
	
	switch (key)
	{
		case 1: show_race_menu(id);
		case 2: cmd_stats(id);
		case 3: cmd_skills(id);
		case 4: cmd_inventar(id);
		case 5: cmd_upgrade(id);
		case 6: cmd_shop(id);
		case 7: cmd_binds(id);
	}
	
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

stock show_race_menu(id)
{
	if (g_Player[id][g_Race] != RACE_NONE)
	{
		client_print_color(id, print_team_default, "^4[Metin2]^1 Ai deja rasa aleasa: ^3%s", g_RaceName[g_Player[id][g_Race]]);
		return;
	}
	
	new menu = menu_create("\yAlege Rasa", "race_handler");
	menu_additem(menu, "Razboinic - Putere bruta", "1");
	menu_additem(menu, "Sura - Magie & Reflect", "2");
	menu_additem(menu, "Ninja - Viteza & Crit", "3");
	menu_additem(menu, "Saman - Support & Heal", "4");
	menu_display(id, menu);
}

public race_handler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new data[6];
	new access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), _, _, callback);
	
	new race = str_to_num(data);
	g_Player[id][g_Race] = race;
	g_Player[id][g_StatPoints] = 5;
	g_Player[id][g_SkillPoints] = 3;
	
	recalc_max_mp(id);
	g_Player[id][g_MP] = g_Player[id][g_MaxMP];
	
	client_print_color(id, print_team_default, "^4[Metin2]^1 Ai ales rasa: ^3%s^1!", g_RaceName[race]);
	save_player(id);
	
	// Forward
	new ret;
	ExecuteForward(g_fwd_RaceSelected, ret, id, race);
	
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public cmd_stats(id)
{
	if (g_Player[id][g_Race] == RACE_NONE)
	{
		client_print_color(id, print_team_default, "^4[Metin2]^1 Alege mai intai o rasa!");
		return PLUGIN_HANDLED;
	}
	
	new title[64];
	formatex(title, charsmax(title), "\yStatut - Puncte: %d", g_Player[id][g_StatPoints]);
	new menu = menu_create(title, "stats_handler");
	
	new tmp[48];
	formatex(tmp, charsmax(tmp), "STR: %d  [+]", g_Player[id][g_STR]);
	menu_additem(menu, tmp, "1");
	formatex(tmp, charsmax(tmp), "HP:  %d  [+]", g_Player[id][g_HP]);
	menu_additem(menu, tmp, "2");
	formatex(tmp, charsmax(tmp), "DEX: %d  [+]", g_Player[id][g_DEX]);
	menu_additem(menu, tmp, "3");
	formatex(tmp, charsmax(tmp), "INT: %d  [+]", g_Player[id][g_INT]);
	menu_additem(menu, tmp, "4");
	
	menu_display(id, menu);
	return PLUGIN_HANDLED;
}

public stats_handler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	if (g_Player[id][g_StatPoints] <= 0)
	{
		client_print_color(id, print_team_default, "^4[Metin2]^1 Nu ai puncte de statut!");
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new data[6];
	new access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), _, _, callback);
	
	new key = str_to_num(data);
	g_Player[id][g_StatPoints]--;
	
	switch (key)
	{
		case 1: g_Player[id][g_STR]++;
		case 2: g_Player[id][g_HP]++;
		case 3: g_Player[id][g_DEX]++;
		case 4: g_Player[id][g_INT]++;
	}
	
	recalc_max_mp(id);
	client_print_color(id, print_team_default, "^4[Metin2]^1 Punct alocat!");
	save_player(id);
	
	// Forward
	new ret;
	ExecuteForward(g_fwd_StatAllocated, ret, id, key);
	
	menu_destroy(menu);
	cmd_stats(id);
	return PLUGIN_HANDLED;
}

public cmd_skills(id)
{
	if (g_Player[id][g_Race] == RACE_NONE)
	{
		client_print_color(id, print_team_default, "^4[Metin2]^1 Alege mai intai o rasa!");
		return PLUGIN_HANDLED;
	}
	
	new race = g_Player[id][g_Race];
	new start = (race - 1) * 5;
	
	new title[64];
	formatex(title, charsmax(title), "\ySkill-uri (%s) - Puncte: %d", g_RaceName[race], g_Player[id][g_SkillPoints]);
	new menu = menu_create(title, "skills_handler");
	
	for (new i = 0; i < 5; i++)
	{
		new lvl = g_Player[id][g_SkillLevel][start + i];
		new rank[16];
		get_skill_rank(lvl, rank, charsmax(rank));
		
		new tmp[64];
		formatex(tmp, charsmax(tmp), "%s [%s]", g_SkillName[start + i], rank);
		
		new info[8];
		formatex(info, charsmax(info), "%d", start + i);
		menu_additem(menu, tmp, info);
	}
	
	menu_display(id, menu);
	return PLUGIN_HANDLED;
}

stock get_skill_rank(level, output[], len)
{
	if (level <= 0) formatex(output, len, "0");
	else if (level < 20) formatex(output, len, "N%d", level);
	else if (level < 30) formatex(output, len, "M%d", level - 19);
	else if (level < 40) formatex(output, len, "G%d", level - 29);
	else formatex(output, len, "P");
}

public skills_handler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new data[6];
	new access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), _, _, callback);
	
	new skill_idx = str_to_num(data);
	
	if (g_Player[id][g_SkillPoints] <= 0)
	{
		client_print_color(id, print_team_default, "^4[Metin2]^1 Nu ai puncte de skill!");
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	if (g_Player[id][g_SkillLevel][skill_idx] >= 40)
	{
		client_print_color(id, print_team_default, "^4[Metin2]^1 Skill deja Perfect Master!");
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	g_Player[id][g_SkillLevel][skill_idx]++;
	g_Player[id][g_SkillPoints]--;
	
	new rank[16];
	get_skill_rank(g_Player[id][g_SkillLevel][skill_idx], rank, charsmax(rank));
	client_print_color(id, print_team_default, "^4[Metin2]^1 %s -> ^3%s", g_SkillName[skill_idx], rank);
	
	save_player(id);
	
	// Forward
	new ret;
	ExecuteForward(g_fwd_SkillLearned, ret, id, skill_idx, g_Player[id][g_SkillLevel][skill_idx]);
	
	menu_destroy(menu);
	cmd_skills(id);
	return PLUGIN_HANDLED;
}

// Inventar, Upgrade, Shop, Binds

public cmd_inventar(id)
{
	new menu = menu_create("\yInventar & Echipament", "inv_handler");
	menu_additem(menu, "Vezi echipament curent", "1");
	menu_additem(menu, "Echipeaza din inventar", "2");
	menu_additem(menu, "Dezbraca slot", "3");
	menu_additem(menu, "Foloseste Lichior HP/MP", "4");
	menu_display(id, menu);
	return PLUGIN_HANDLED;
}

public inv_handler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new data[6];
	menu_item_getinfo(menu, item, _, data, charsmax(data), _, _, _);
	
	switch (str_to_num(data))
	{
		case 1:
		{
			client_print_color(id, print_team_default, "^4[Metin2]^1 Echipament:");
			client_print_color(id, print_team_default, "Arma: %s +%d", get_item_name(g_Player[id][g_Equipped][SLOT_WEAPON]), g_Player[id][g_EquippedUpgrade][SLOT_WEAPON]);
			client_print_color(id, print_team_default, "Armura: %s +%d", get_item_name(g_Player[id][g_Equipped][SLOT_ARMOR]), g_Player[id][g_EquippedUpgrade][SLOT_ARMOR]);
			client_print_color(id, print_team_default, "Coif: %s +%d", get_item_name(g_Player[id][g_Equipped][SLOT_HELMET]), g_Player[id][g_EquippedUpgrade][SLOT_HELMET]);
			client_print_color(id, print_team_default, "Scut: %s +%d", get_item_name(g_Player[id][g_Equipped][SLOT_SHIELD]), g_Player[id][g_EquippedUpgrade][SLOT_SHIELD]);
			client_print_color(id, print_team_default, "Papuci: %s +%d", get_item_name(g_Player[id][g_Equipped][SLOT_SHOES]), g_Player[id][g_EquippedUpgrade][SLOT_SHOES]);
			client_print_color(id, print_team_default, "Bijuterie: %s +%d", get_item_name(g_Player[id][g_Equipped][SLOT_JEWEL]), g_Player[id][g_EquippedUpgrade][SLOT_JEWEL]);
		}
		case 2: show_equip_from_inv(id);
		case 3: show_unequip(id);
		case 4: use_potion_menu(id);
	}
	
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

stock get_item_name(itemid)
{
	static name[32];
	if (itemid <= 0 || itemid >= g_ItemCount)
		formatex(name, charsmax(name), "Gol");
	else
		copy(name, charsmax(name), g_Items[itemid][ItemName]);
	return name;
}

stock show_equip_from_inv(id)
{
	new menu = menu_create("\yAlege item din inventar", "equip_handler");
	
	for (new i = 0; i < g_Player[id][g_InventoryCount]; i++)
	{
		new iid = g_Player[id][g_Inventory][i];
		if (iid > 0 && iid < g_ItemCount && g_Items[iid][ItemType] != ITEM_POTION)
		{
			new tmp[48];
			formatex(tmp, charsmax(tmp), "%s +%d", g_Items[iid][ItemName], g_Player[id][g_InventoryUpgrade][i]);
			new info[8];
			formatex(info, charsmax(info), "%d", i);
			menu_additem(menu, tmp, info);
		}
	}
	
	menu_display(id, menu);
}

public equip_handler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new data[6];
	menu_item_getinfo(menu, item, _, data, charsmax(data), _, _, _);
	new inv_slot = str_to_num(data);
	
	new itemid = g_Player[id][g_Inventory][inv_slot];
	new upg = g_Player[id][g_InventoryUpgrade][inv_slot];
	
	if (itemid <= 0 || itemid >= g_ItemCount)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new type = g_Items[itemid][ItemType];
	
	new equip_slot = -1;
	if (type == ITEM_WEAPON) equip_slot = SLOT_WEAPON;
	else if (type == ITEM_ARMOR) equip_slot = SLOT_ARMOR;
	else if (type == ITEM_HELMET) equip_slot = SLOT_HELMET;
	else if (type == ITEM_SHIELD) equip_slot = SLOT_SHIELD;
	else if (type == ITEM_SHOES) equip_slot = SLOT_SHOES;
	else if (type == ITEM_JEWEL) equip_slot = SLOT_JEWEL;
	
	if (equip_slot == -1)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	g_Player[id][g_Equipped][equip_slot] = itemid;
	g_Player[id][g_EquippedUpgrade][equip_slot] = upg;
	
	for (new i = inv_slot; i < g_Player[id][g_InventoryCount] - 1; i++)
	{
		g_Player[id][g_Inventory][i] = g_Player[id][g_Inventory][i + 1];
		g_Player[id][g_InventoryUpgrade][i] = g_Player[id][g_InventoryUpgrade][i + 1];
	}

	g_Player[id][g_Inventory][g_Player[id][g_InventoryCount] - 1] = 0;
	g_Player[id][g_InventoryUpgrade][g_Player[id][g_InventoryCount] - 1] = 0;
	g_Player[id][g_InventoryCount]--;
	
	recalc_max_mp(id);
	client_print_color(id, print_team_default, "^4[Metin2]^1 Ai echipat ^3%s +%d", g_Items[itemid][ItemName], upg);
	save_player(id);
	
	// Forward
	new ret;
	ExecuteForward(g_fwd_ItemEquipped, ret, id, itemid, equip_slot);
	
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

stock show_unequip(id)
{
	new menu = menu_create("\yDezbraca slot", "unequip_handler");
	menu_additem(menu, "Arma", "0");
	menu_additem(menu, "Armura", "1");
	menu_additem(menu, "Coif", "2");
	menu_additem(menu, "Scut", "3");
	menu_additem(menu, "Papuci", "4");
	menu_additem(menu, "Bijuterie", "5");
	menu_display(id, menu);
}

public unequip_handler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new data[6];
	menu_item_getinfo(menu, item, _, data, charsmax(data), _, _, _);
	new slot = str_to_num(data);
	
	if (g_Player[id][g_Equipped][slot] == 0)
	{
		client_print_color(id, print_team_default, "^4[Metin2]^1 Slot gol!");
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	if (g_Player[id][g_InventoryCount] >= MAX_INVENTORY)
	{
		client_print_color(id, print_team_default, "^4[Metin2]^1 Inventar plin!");
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new itemid = g_Player[id][g_Equipped][slot];
	
	new idx = g_Player[id][g_InventoryCount];
	g_Player[id][g_Inventory][idx] = itemid;
	g_Player[id][g_InventoryUpgrade][idx] = g_Player[id][g_EquippedUpgrade][slot];
	g_Player[id][g_InventoryCount]++;
	
	g_Player[id][g_Equipped][slot] = 0;
	g_Player[id][g_EquippedUpgrade][slot] = 0;
	
	recalc_max_mp(id);
	client_print_color(id, print_team_default, "^4[Metin2]^1 Item mutat in inventar.");
	save_player(id);
	
	// Forward
	new ret;
	ExecuteForward(g_fwd_ItemUnequipped, ret, id, itemid, slot);
	
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

stock use_potion_menu(id)
{
	new menu = menu_create("\yFoloseste Lichior", "potion_handler");
	
	for (new i = 0; i < g_Player[id][g_InventoryCount]; i++)
	{
		new iid = g_Player[id][g_Inventory][i];
		if (iid > 0 && iid < g_ItemCount && g_Items[iid][ItemType] == ITEM_POTION)
		{
			new tmp[32];
			formatex(tmp, charsmax(tmp), "%s", g_Items[iid][ItemName]);
			new info[8];
			formatex(info, charsmax(info), "%d", i);
			menu_additem(menu, tmp, info);
		}
	}
	
	menu_display(id, menu);
}

public potion_handler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new data[6];
	menu_item_getinfo(menu, item, _, data, charsmax(data), _, _, _);
	new inv_slot = str_to_num(data);
	
	new itemid = g_Player[id][g_Inventory][inv_slot];
	
	if (itemid <= 0 || itemid >= g_ItemCount || g_Items[itemid][ItemType] != ITEM_POTION)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	if (g_Items[itemid][ItemPotionType] == 1) // HP
	{
		new hp = get_user_health(id);
		set_user_health(id, min(hp + 80, 100 + g_Player[id][g_HP] * 10 + 50));
		client_print_color(id, print_team_default, "^4[Metin2]^1 Ai folosit Lichior HP!");
	}
	else if (g_Items[itemid][ItemPotionType] == 2) // MP
	{
		g_Player[id][g_MP] = min(g_Player[id][g_MP] + 60, g_Player[id][g_MaxMP]);
		client_print_color(id, print_team_default, "^4[Metin2]^1 Ai folosit Lichior MP!");
	}
	else
	{
		client_print_color(id, print_team_default, "^4[Metin2]^1 Acest item nu este o potiune valida.");
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	// Scoate din inventar
	for (new i = inv_slot; i < g_Player[id][g_InventoryCount] - 1; i++)
	{
		g_Player[id][g_Inventory][i] = g_Player[id][g_Inventory][i + 1];
		g_Player[id][g_InventoryUpgrade][i] = g_Player[id][g_InventoryUpgrade][i + 1];
	}

	g_Player[id][g_Inventory][g_Player[id][g_InventoryCount] - 1] = 0;
	g_Player[id][g_InventoryUpgrade][g_Player[id][g_InventoryCount] - 1] = 0;
	g_Player[id][g_InventoryCount]--;
	
	save_player(id);
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public cmd_upgrade(id)
{
	new menu = menu_create("\yFierar - Upgrade Item", "upgrade_menu_handler");
	
	for (new i = 0; i < g_Player[id][g_InventoryCount]; i++)
	{
		new iid = g_Player[id][g_Inventory][i];
		if (iid > 0 && iid < g_ItemCount && g_Items[iid][ItemType] != ITEM_POTION)
		{
			new upg = g_Player[id][g_InventoryUpgrade][i];
			if (upg < MAX_UPGRADE)
			{
				new tmp[48];
				formatex(tmp, charsmax(tmp), "%s +%d -> +%d", g_Items[iid][ItemName], upg, upg + 1);
				new info[8];
				formatex(info, charsmax(info), "%d", i);
				menu_additem(menu, tmp, info);
			}
		}
	}
	
	menu_display(id, menu);
	return PLUGIN_HANDLED;
}

public upgrade_menu_handler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new data[6];
	menu_item_getinfo(menu, item, _, data, charsmax(data), _, _, _);
	new inv_slot = str_to_num(data);
	
	new upg = g_Player[id][g_InventoryUpgrade][inv_slot];
	new cost = 1000 * (upg + 1) * (upg + 1);
	
	if (g_Player[id][g_Yang] < cost)
	{
		client_print_color(id, print_team_default, "^4[Metin2]^1 Nu ai destul Yang! Cost: %d", cost);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	g_Player[id][g_Yang] -= cost;
	
	new chance;
	if (upg < 6) chance = 85 - (upg * 5);
	else if (upg == 6) chance = 50;
	else if (upg == 7) chance = 30;
	else chance = 15;
	
	new itemid = g_Player[id][g_Inventory][inv_slot];
	
	if (random_num(1, 100) <= chance)
	{
		g_Player[id][g_InventoryUpgrade][inv_slot]++;
		client_print_color(id, print_team_default, "^4[Metin2]^1 ^3SUCCES^1! Item +%d", g_Player[id][g_InventoryUpgrade][inv_slot]);
		
		// Forward success
		new ret;
		ExecuteForward(g_fwd_UpgradeSuccess, ret, id, itemid, g_Player[id][g_InventoryUpgrade][inv_slot]);
	}
	else
	{
		new destroyed = 0;
		if (get_pcvar_num(cvar_upgrade_destroy))
		{
			for (new i = inv_slot; i < g_Player[id][g_InventoryCount] - 1; i++)
			{
				g_Player[id][g_Inventory][i] = g_Player[id][g_Inventory][i + 1];
				g_Player[id][g_InventoryUpgrade][i] = g_Player[id][g_InventoryUpgrade][i + 1];
			}

			g_Player[id][g_Inventory][g_Player[id][g_InventoryCount] - 1] = 0;
			g_Player[id][g_InventoryUpgrade][g_Player[id][g_InventoryCount] - 1] = 0;
			g_Player[id][g_InventoryCount]--;

			destroyed = 1;
			client_print_color(id, print_team_default, "^4[Metin2]^1 ^1FIERARUL A SPART ITEMUL!");
		}
		else
		{
			if (upg > 0) g_Player[id][g_InventoryUpgrade][inv_slot]--;
			client_print_color(id, print_team_default, "^4[Metin2]^1 Esec! Nivel scazut.");
		}
		
		// Forward fail
		new ret;
		ExecuteForward(g_fwd_UpgradeFail, ret, id, itemid, destroyed);
	}

	save_player(id);
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public cmd_shop(id)
{
	new title[48];
	formatex(title, charsmax(title), "\yMagazin - Yang: %d", g_Player[id][g_Yang]);
	new menu = menu_create(title, "shop_handler");
	
	for (new i = 1; i < g_ItemCount; i++)
	{
		if (g_Items[i][ItemPrice] <= 0)
			continue;
		
		new tmp[48];
		formatex(tmp, charsmax(tmp), "%s - %d Yang", g_Items[i][ItemName], g_Items[i][ItemPrice]);
		new info[8];
		formatex(info, charsmax(info), "%d", i);
		menu_additem(menu, tmp, info);
	}
	
	menu_display(id, menu);
	return PLUGIN_HANDLED;
}

public shop_handler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new data[6];
	menu_item_getinfo(menu, item, _, data, charsmax(data), _, _, _);
	new itemid = str_to_num(data);
	
	if (itemid <= 0 || itemid >= g_ItemCount)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	if (g_Player[id][g_InventoryCount] >= MAX_INVENTORY)
	{
		client_print_color(id, print_team_default, "^4[Metin2]^1 Inventar plin!");
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new price = g_Items[itemid][ItemPrice];
	if (g_Player[id][g_Yang] < price)
	{
		client_print_color(id, print_team_default, "^4[Metin2]^1 Yang insuficient!");
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	g_Player[id][g_Yang] -= price;
	
	new idx = g_Player[id][g_InventoryCount];
	g_Player[id][g_Inventory][idx] = itemid;
	g_Player[id][g_InventoryUpgrade][idx] = 0;
	g_Player[id][g_InventoryCount]++;
	
	client_print_color(id, print_team_default, "^4[Metin2]^1 Ai cumparat ^3%s", g_Items[itemid][ItemName]);
	save_player(id);
	
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public cmd_binds(id)
{
	static motd[900];
	
	formatex(motd, charsmax(motd),
	"<html><body bgcolor=#0d0d0d text=#e0e0e0>\
	<center><font color=#ffcc00 size=5><b>Metin2 RPG - Bind-uri</b></font></center><br>\
	\
	<font color=#00ff9d><b>Seteaza in consola (~):</b></font><br><br>\
	\
	<font color=#ffcc00>bind f skill1</font> - Skill 1<br>\
	<font color=#ffcc00>bind g skill2</font> - Skill 2<br>\
	<font color=#ffcc00>bind h skill3</font> - Skill 3<br>\
	<font color=#ffcc00>bind j skill4</font> - Skill 4<br>\
	<font color=#ffcc00>bind k skill5</font> - Skill 5<br><br>\
	\
	<font color=#00ff9d><b>Comenzi utile:</b></font><br>\
	/menu - Meniu principal<br>\
	/stats - Alocare puncte<br>\
	/skills - Skill-uri<br>\
	/inventar - Echipament<br>\
	/upgrade - Fierar<br>\
	/shop - Magazin<br><br>\
	\
	<font color=#aaaaaa>Fiecare skill consuma Mana.<br>\
	Cooldown-ul scade pe masura ce upgradezi skill-ul.</font>\
	</body></html>");
	
	show_motd(id, motd, "Metin2 RPG");
	return PLUGIN_HANDLED;
}
