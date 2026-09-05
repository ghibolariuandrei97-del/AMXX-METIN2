/*================================================================================
	Metin2 RPG Core - CS 1.6
	AMX Mod X 1.10+ | ReAPI | nVault Array | fun | fakemeta
	Skill-uri reale + Mana + Item bonuses + Potions + API + Forwards
	             + Sistem iteme 100% dinamic (m2_register_item functional)
================================================================================*/


// 1=Debug Oprit , 0=Debug Pornit
#define DEBUG_LOGS_OFF 1
//

#include <amxmodx>
#include <amxmisc>
#include <nvault>
#include <nvault_array>
#include <reapi>
#include <fakemeta>
#include <hamsandwich>
#include <fun>

// AMX Mod X 1.8.2 / 1.8.3+ Inline Multilingual Formatting Support
#if !defined fmt
stock fmt(const szFormat[], any:...)
{
    static szBuffer[512];
    vformat(szBuffer, charsmax(szBuffer), szFormat, 2);
    return szBuffer;
}
#endif

#define PLUGIN  "Metin2Core"
#define VERSION "1.6"
#define AUTHOR  "Craxor"

#define MAX_PLAYERS          32
#define MAX_INVENTORY        30
#define MAX_SKILLS           40
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
	g_SkillPath,                 
	g_SkillLevel[MAX_SKILLS],
	g_Equipped[MAX_EQUIP_SLOTS],
	g_EquippedUpgrade[MAX_EQUIP_SLOTS],
	g_Inventory[MAX_INVENTORY],
	g_InventoryUpgrade[MAX_INVENTORY],
	g_InventoryCount,
	g_MP,
	g_MaxMP
};

#define PATH_NONE            0
#define PATH_A               1
#define PATH_B               2

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
new bool:g_DataLoaded[MAX_PLAYERS + 1];
new g_Vault = INVALID_HANDLE;
new g_HudSync;
new Float:g_SkillCooldown[MAX_PLAYERS + 1][5];
new bool:g_AuraActive[MAX_PLAYERS + 1];
new bool:g_ReflectActive[MAX_PLAYERS + 1];
new bool:g_AmbushActive[MAX_PLAYERS + 1];
new bool:g_ResistActive[MAX_PLAYERS + 1];
new bool:g_PierceActive[MAX_PLAYERS + 1];
new bool:g_BlessActive[MAX_PLAYERS + 1];
new bool:g_ForceUpgrade[MAX_PLAYERS + 1];
new Float:g_ResistAmount[MAX_PLAYERS + 1];
new Float:g_PierceAmount[MAX_PLAYERS + 1];
new Float:g_BlessAmount[MAX_PLAYERS + 1];

new g_Items[MAX_ITEMS][ItemStruct];
new g_ItemCount = 0;

new cvar_xp_kill, cvar_xp_hs, cvar_yang_kill, cvar_yang_hs;
new cvar_upgrade_destroy;

// ======================== RASE (RO / EN) ========================
new const g_RaceName_RO[][] = {
	"Nespecificat",
	"Razboinic",
	"Sura",
	"Ninja",
	"Saman"
};

new const g_RaceName_EN[][] = {
	"Unspecified",
	"Warrior",
	"Sura",
	"Ninja",
	"Shaman"
};

// ======================== SKILL-URI (RO / EN) ========================
new const g_SkillName_RO[MAX_SKILLS][] = {
	// ===== WARRIOR - Corporal (0-4) =====
	"Aura Sabiei", "Corp Rezistent", "Izbitura", "Atac Sabie", "Vartej Sabie",
	
	// ===== WARRIOR - Mental (5-9) =====
	"Lovitura Spiritului", "Scut Mental", "Valul de Putere", "Concentrare", "Explozie Interioara",
	
	// ===== SURA - Arme Magice (10-14) =====
	"Tais Vrajit", "Armura Vrajita", "Lovitura Degetului", "Atacul Fulgerului", "Pietrificare",
	
	// ===== SURA - Magie Neagra (15-19) =====
	"Flacara Intunecata", "Blestem", "Absorbție de Suflet", "Umbre", "Invocarea Haosului",
	
	// ===== NINJA - Lame / Cuțite (20-24) =====
	"Camuflaj", "Atacul Fulgerator", "Ambush", "Otrava", "Dansul Lamelor",
	
	// ===== NINJA - Arc (25-29) =====
	"Ploaie de Sageti", "Sageata Exploziva", "Tintire Precisa", "Sageata Otravita", "Val de Sageti",
	
	// ===== SHAMAN - Zmeu / Dragon (30-34) =====
	"Chemarea Dragonului", "Flacara Dragonului", "Scut de Solzi", "Zborul Dragonului", "Furia Dragonului",
	
	// ===== SHAMAN - Fulger / Vindecare (35-39) =====
	"Lecuire", "Atac Intens", "Binecuvantare", "Iutesenie", "Chemarea Fulgerului"
};

new const g_SkillName_EN[MAX_SKILLS][] = {
	// ===== WARRIOR - Corporal (0-4) =====
	"Sword Aura", "Resistant Body", "Bash", "Sword Strike", "Sword Whirlwind",
	
	// ===== WARRIOR - Mental (5-9) =====
	"Spirit Strike", "Mental Shield", "Power Wave", "Concentration", "Inner Explosion",
	
	// ===== SURA - Arme Magice (10-14) =====
	"Enchanted Blade", "Enchanted Armor", "Finger Strike", "Lightning Attack", "Petrify",
	
	// ===== SURA - Magie Neagra (15-19) =====
	"Dark Flame", "Curse", "Soul Absorption", "Shadows", "Chaos Summon",
	
	// ===== NINJA - Lame / Cuțite (20-24) =====
	"Camouflage", "Lightning Assault", "Ambush", "Poison", "Blade Dance",
	
	// ===== NINJA - Arc (25-29) =====
	"Arrow Rain", "Explosive Arrow", "Precise Aim", "Poisoned Arrow", "Arrow Wave",
	
	// ===== SHAMAN - Zmeu / Dragon (30-34) =====
	"Dragon Call", "Dragon Flame", "Scale Shield", "Dragon Flight", "Dragon Fury",
	
	// ===== SHAMAN - Fulger / Vindecare (35-39) =====
	"Heal", "Intense Attack", "Blessing", "Quickness", "Lightning Call"
};

// ======================== CĂI (RO / EN) ========================
new const g_PathName_RO[][][] = {
	{ "", "" },                          // index 0 nefolosit
	{ "Corporal", "Mental" },            // Warrior
	{ "Arme Magice", "Magie Neagra" },   // Sura
	{ "Lame", "Arc" },                   // Ninja
	{ "Zmeu", "Fulger" }                 // Shaman
};

new const g_PathName_EN[][][] = {
	{ "", "" },                          // index 0 nefolosit
	{ "Body", "Mental" },                // Warrior
	{ "Magic Weapons", "Black Magic" },  // Sura
	{ "Blades", "Bow" },                 // Ninja
	{ "Dragon", "Lightning" }            // Shaman
};

// Cost mana pe skill (baza)
new const g_SkillManaCost[5] = { 25, 30, 35, 20, 40 };

// ======================== HELPERS MULTI-LANGUAGE ========================

stock GetRaceName(id, race, output[], len)
{
	if (race < 0 || race >= sizeof(g_RaceName_RO))
	{
		copy(output, len, "???");
		return;
	}

	new lang[8];
	get_user_info(id, "lang", lang, charsmax(lang));

	if (equali(lang, "en"))
		copy(output, len, g_RaceName_EN[race]);
	else
		copy(output, len, g_RaceName_RO[race]);
}

stock GetSkillName(id, skill_idx, output[], len)
{
	if (skill_idx < 0 || skill_idx >= MAX_SKILLS)
	{
		copy(output, len, "???");
		return;
	}

	new lang[8];
	get_user_info(id, "lang", lang, charsmax(lang));

	if (equali(lang, "en"))
		copy(output, len, g_SkillName_EN[skill_idx]);
	else
		copy(output, len, g_SkillName_RO[skill_idx]);
}

stock GetPathName(id, race, path, output[], len)
{
	// path trebuie să fie 1 sau 2
	if (race < 1 || race > 4 || path < 1 || path > 2)
	{
		copy(output, len, "???");
		return;
	}

	new lang[8];
	get_user_info(id, "lang", lang, charsmax(lang));

	if (equali(lang, "en"))
		copy(output, len, g_PathName_EN[race][path - 1]);
	else
		copy(output, len, g_PathName_RO[race][path - 1]);
}

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
new g_fwd_ItemBought;
new g_fwd_ItemUsed;

null_func(){}

static stock const szDebugFileLocation[] = "addons/amxmodx/data/metin2debug.txt";

#if DEBUG_LOGS_OFF
	#define debug_log(%1)		null_func()
	#define debug_log_user(%1)	null_func()
#else
stock debug_log(const szMessage[], any:...)
{
	static Frm[128];
	vformat(Frm, charsmax(Frm), szMessage, 2);   // <-- aici era greșeala
	new szMap[32];
	get_mapname(szMap, charsmax(szMap));
	new Players[32], Num;
	get_players(Players, Num);
	new buff[120];
	formatex(buff, charsmax(buff), "[DEBUG, SysTime: %i, Map: %s, Players: %i] %s", get_systime(), szMap, Num, Frm);
	write_file(szDebugFileLocation, buff);
	null_func();
}

stock debug_log_user(id, const szMessage[], any:...)
{
	static Frm[128];
	vformat(Frm, charsmax(Frm), szMessage, 3);
	new szMap[32];
	get_mapname(szMap, charsmax(szMap));
	new Players[32], Num;
	get_players(Players, Num);
	new szName[32];
	get_user_name(id, szName, charsmax(szName));
	new buff[200];
	formatex(buff, charsmax(buff), "[DEBUG, SysTime: %i, Map: %s, Players: %i, User: %s, Level: %d, XP: %d, Yang: %d, Race: %d] %s",
		get_systime(), szMap, Num, szName,
		g_Player[id][g_Level], g_Player[id][g_XP], g_Player[id][g_Yang], g_Player[id][g_Race],
		Frm);

	write_file(szDebugFileLocation, buff);
	null_func();
}

#endif


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
	register_native("set_user_m2_race",   "_set_user_m2_race");
	register_native("set_user_m2_str",    "_set_user_m2_str");
	register_native("set_user_m2_hp",     "_set_user_m2_hp");
	register_native("set_user_m2_dex",    "_set_user_m2_dex");
	register_native("set_user_m2_int",    "_set_user_m2_int");
	register_native("set_user_m2_mp",     "_set_user_m2_mp");
	register_native("set_user_m2_maxmp",  "_set_user_m2_maxmp");
	
	// Item / Inventory natives
	register_native("m2_get_user_equipped",         "_m2_get_user_equipped");
	register_native("m2_get_user_equipped_upgrade", "_m2_get_user_equipped_upgrade");
	register_native("m2_get_user_inventory_count",  "_m2_get_user_inventory_count");
	register_native("m2_get_user_inventory_item",   "_m2_get_user_inventory_item");
	register_native("m2_get_user_inventory_upgrade","_m2_get_user_inventory_upgrade");
	register_native("m2_user_has_item",             "_m2_user_has_item");
	register_native("m2_get_item_name",             "_m2_get_item_name");
	register_native("m2_get_item_type",             "_m2_get_item_type");
	register_native("m2_get_item_price",            "_m2_get_item_price");
	register_native("m2_get_item_count",            "_m2_get_item_count");
	register_native("m2_give_item",                 "_m2_give_item");
	register_native("m2_remove_item",               "_m2_remove_item");
	register_native("m2_get_total_str",             "_m2_get_total_str");
	register_native("m2_get_total_hp",              "_m2_get_total_hp");
	register_native("m2_get_total_dex",             "_m2_get_total_dex");
	register_native("m2_get_total_int",             "_m2_get_total_int");
	register_native("m2_set_force_upgrade",         "_m2_set_force_upgrade");
	register_native("m2_get_force_upgrade",         "_m2_get_force_upgrade");
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_dictionary("metin2Core.txt");

	register_clcmd("say /menu",     "cmd_menu");
	register_clcmd("say /metin2",   "cmd_status_motd");
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
	
	register_forward(FM_ClientUserInfoChanged, "OnClientUserInfoChanged");
	register_forward(FM_ServerDeactivate, "OnServerDeactivate");
	
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
	g_fwd_ItemBought     = CreateMultiForward("m2_item_bought", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL); // id, itemid, price
	g_fwd_ItemUsed       = CreateMultiForward("m2_item_used", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL); // id, itemid, potion_type (1=HP,2=MP)
	
	// Inregistreaza itemele default (ID-uri 0-15 pastrate pentru compatibilitate salvari)
	RegisterDefaultItems();
	
	set_task(1.0, "Task_HUD", _, _, _, "b");
	set_task(2.0, "Task_ManaRegen", _, _, _, "b");

	debug_log( "Plugin_Init() Initializat cu Succes - Vault deschis cu succes!");
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
	DestroyForward(g_fwd_ItemBought);
	DestroyForward(g_fwd_ItemUsed);

	debug_log( "Plugin_End() initiazliat cu succs, vault deschis");
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
	debug_log(  "g_itemCound %i", g_ItemCount); 
	return item_id;
}

// ======================== NATIVES ========================
public _m2_register_item(plugin, params)
{
	if (g_ItemCount >= MAX_ITEMS)
	{
		log_amx("[Metin2] Nu se mai pot inregistra iteme! Limita de %d a fost atinsa.", MAX_ITEMS);
		debug_log( "Limita de inregistrare iteme a fost atinsa");
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

	debug_log("[Metin2] Item inregistrat: '%s' (ID %d, Type %d, Price %d)", szName, item_id, type, price);
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

public _set_user_m2_race(plugin, params)
{
	new id = get_param(1);
	new race = get_param(2);

	if (!is_user_connected(id))
		return 0;

	// Validare rasă (0-4)
	if (race < RACE_NONE || race > RACE_SHAMAN)
		return 0;

	g_Player[id][g_Race] = race;

	// Dacă setezi RACE_NONE, poți decide să resetezi și skill-urile (opțional)
	// for (new i = 0; i < MAX_SKILLS; i++)
	//     g_Player[id][g_SkillLevel][i] = 0;

	recalc_max_mp(id);
	save_player(id);
	return 1;
}

public _set_user_m2_str(plugin, params)
{
	new id = get_param(1);
	new amount = get_param(2);

	if (!is_user_connected(id) || amount < 0)
		return 0;

	g_Player[id][g_STR] = amount;
	save_player(id);
	return 1;
}

public _set_user_m2_hp(plugin, params)
{
	new id = get_param(1);
	new amount = get_param(2);

	if (!is_user_connected(id) || amount < 0)
		return 0;

	g_Player[id][g_HP] = amount;
	save_player(id);
	return 1;
}

public _set_user_m2_dex(plugin, params)
{
	new id = get_param(1);
	new amount = get_param(2);

	if (!is_user_connected(id) || amount < 0)
		return 0;

	g_Player[id][g_DEX] = amount;
	save_player(id);
	return 1;
}

public _set_user_m2_int(plugin, params)
{
	new id = get_param(1);
	new amount = get_param(2);

	if (!is_user_connected(id) || amount < 0)
		return 0;

	g_Player[id][g_INT] = amount;
	recalc_max_mp(id);          // INT influențează MaxMP
	save_player(id);
	return 1;
}

public _set_user_m2_mp(plugin, params)
{
	new id = get_param(1);
	new amount = get_param(2);

	if (!is_user_connected(id))
		return 0;

	if (amount < 0)
		amount = 0;

	if (amount > g_Player[id][g_MaxMP])
		amount = g_Player[id][g_MaxMP];

	g_Player[id][g_MP] = amount;
	// Nu e obligatoriu să salvezi la fiecare set de MP (e volatil),
	// dar dacă vrei consistență la reconnect poți lăsa save_player(id);
	return 1;
}

public _set_user_m2_maxmp(plugin, params)
{
	new id = get_param(1);
	new amount = get_param(2);

	if (!is_user_connected(id) || amount < 1)
		return 0;

	g_Player[id][g_MaxMP] = amount;

	// Dacă MP-ul curent depășește noul maxim, îl ajustăm
	if (g_Player[id][g_MP] > amount)
		g_Player[id][g_MP] = amount;

	save_player(id);
	return 1;
}

// ======================== ITEM / INVENTORY NATIVES ========================

public _m2_get_user_equipped(plugin, params)
{
	new id = get_param(1);
	new slot = get_param(2);
	if (!is_user_connected(id) || slot < 0 || slot >= MAX_EQUIP_SLOTS)
		return 0;
	return g_Player[id][g_Equipped][slot];
}

public _m2_get_user_equipped_upgrade(plugin, params)
{
	new id = get_param(1);
	new slot = get_param(2);
	if (!is_user_connected(id) || slot < 0 || slot >= MAX_EQUIP_SLOTS)
		return 0;
	return g_Player[id][g_EquippedUpgrade][slot];
}

public _m2_get_user_inventory_count(plugin, params)
{
	new id = get_param(1);
	if (!is_user_connected(id)) return 0;
	return g_Player[id][g_InventoryCount];
}

public _m2_get_user_inventory_item(plugin, params)
{
	new id = get_param(1);
	new inv_slot = get_param(2);
	if (!is_user_connected(id) || inv_slot < 0 || inv_slot >= g_Player[id][g_InventoryCount])
		return 0;
	return g_Player[id][g_Inventory][inv_slot];
}

public _m2_get_user_inventory_upgrade(plugin, params)
{
	new id = get_param(1);
	new inv_slot = get_param(2);
	if (!is_user_connected(id) || inv_slot < 0 || inv_slot >= g_Player[id][g_InventoryCount])
		return 0;
	return g_Player[id][g_InventoryUpgrade][inv_slot];
}

// Returns 1 if player has the item equipped OR in inventory
public _m2_user_has_item(plugin, params)
{
	new id = get_param(1);
	new itemid = get_param(2);
	if (!is_user_connected(id) || itemid <= 0 || itemid >= g_ItemCount)
		return 0;
	
	// Check equipped
	for (new i = 0; i < MAX_EQUIP_SLOTS; i++)
	{
		if (g_Player[id][g_Equipped][i] == itemid)
			return 1;
	}
	
	// Check inventory
	for (new i = 0; i < g_Player[id][g_InventoryCount]; i++)
	{
		if (g_Player[id][g_Inventory][i] == itemid)
			return 1;
	}
	return 0;
}

public _m2_get_item_name(plugin, params)
{
	new itemid = get_param(1);
	new len = get_param(3);
	if (itemid <= 0 || itemid >= g_ItemCount)
	{
		set_string(2, "Gol", len);
		return 0;
	}
	set_string(2, g_Items[itemid][ItemName], len);
	return 1;
}

public _m2_get_item_type(plugin, params)
{
	new itemid = get_param(1);
	if (itemid <= 0 || itemid >= g_ItemCount) return 0;
	return g_Items[itemid][ItemType];
}

public _m2_get_item_price(plugin, params)
{
	new itemid = get_param(1);
	if (itemid <= 0 || itemid >= g_ItemCount) return 0;
	return g_Items[itemid][ItemPrice];
}

public _m2_get_item_count(plugin, params)
{
	return g_ItemCount;
}

// Give item to inventory. Returns 1 on success, 0 on fail (full inv / invalid)
public _m2_give_item(plugin, params)
{
	new id = get_param(1);
	new itemid = get_param(2);
	new upgrade = get_param(3);
	
	if (!is_user_connected(id) || itemid <= 0 || itemid >= g_ItemCount)
		return 0;
	if (g_Player[id][g_InventoryCount] >= MAX_INVENTORY)
		return 0;
	if (upgrade < 0) upgrade = 0;
	if (upgrade > MAX_UPGRADE) upgrade = MAX_UPGRADE;
	
	new idx = g_Player[id][g_InventoryCount];
	g_Player[id][g_Inventory][idx] = itemid;
	g_Player[id][g_InventoryUpgrade][idx] = upgrade;
	g_Player[id][g_InventoryCount]++;
	save_player(id);
	return 1;
}

// Remove first occurrence of itemid from inventory (not equipped). Returns 1 if removed.
public _m2_remove_item(plugin, params)
{
	new id = get_param(1);
	new itemid = get_param(2);
	
	if (!is_user_connected(id) || itemid <= 0)
		return 0;
	
	for (new i = 0; i < g_Player[id][g_InventoryCount]; i++)
	{
		if (g_Player[id][g_Inventory][i] == itemid)
		{
			for (new j = i; j < g_Player[id][g_InventoryCount] - 1; j++)
			{
				g_Player[id][g_Inventory][j] = g_Player[id][g_Inventory][j + 1];
				g_Player[id][g_InventoryUpgrade][j] = g_Player[id][g_InventoryUpgrade][j + 1];
			}
			g_Player[id][g_Inventory][g_Player[id][g_InventoryCount] - 1] = 0;
			g_Player[id][g_InventoryUpgrade][g_Player[id][g_InventoryCount] - 1] = 0;
			g_Player[id][g_InventoryCount]--;
			save_player(id);
			return 1;
		}
	}
	return 0;
}

public _m2_get_total_str(plugin, params)
{
	new id = get_param(1);
	if (!is_user_connected(id)) return 0;
	return get_total_str(id);
}

public _m2_get_total_hp(plugin, params)
{
	new id = get_param(1);
	if (!is_user_connected(id)) return 0;
	return get_total_hp(id);
}

public _m2_get_total_dex(plugin, params)
{
	new id = get_param(1);
	if (!is_user_connected(id)) return 0;
	return get_total_dex(id);
}

public _m2_get_total_int(plugin, params)
{
	new id = get_param(1);
	if (!is_user_connected(id)) return 0;
	return get_total_int(id);
}

public _m2_set_force_upgrade(plugin, params)
{
	new id = get_param(1);
	new bool:enable = bool:get_param(2);
	if (!is_user_connected(id)) return 0;

	g_ForceUpgrade[id] = enable;
	return 1;
}

public _m2_get_force_upgrade(plugin, params)
{
	new id = get_param(1);
	if (!is_user_connected(id)) return 0;
	return g_ForceUpgrade[id];
}

// ======================== NAME CHANGE BLOCK ========================
public OnClientUserInfoChanged(id)
{
	if (!is_user_connected(id))
		return FMRES_IGNORED;
	
	static oldname[32], newname[32];
	pev(id, pev_netname, oldname, charsmax(oldname));
	
	get_user_info(id, "name", newname, charsmax(newname));

	debug_log("OnClientUserInfoChanged a fost apelat, numele: %s -- A fost si blocat? uitativa in contiuare", oldname);
	
	if (!equal(oldname, newname) && oldname[0])
	{
		set_user_info(id, "name", oldname);
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_SCHIMBAREA_NUMELUI_ESTE");
		debug_log_user(id, "OnClientUserInfoChanged: Nume a fost blocat! din %s in %s",oldname, newname);
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
	debug_log_user( id, "Client_putinserver() a fost apelat, reset_player(), load_players() si set_task(TaslWelcomeMEssage) vor fi apelate!");
}

public Task_WelcomeMsg(id)
{
	if (!is_user_connected(id))
		return;
	

	debug_log_user(id, " public Task_WelcomeMEssage a fost apelat!" );
	if (g_Player[id][g_Race] == RACE_NONE)
	{
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_BUN_VENIT_ALEGE");
	}
	else
	{
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_DATE_INCARCATE_LEVEL", g_Player[id][g_Level], g_Player[id][g_Yang]);
	}

}

public client_disconnected(id)
{
	remove_task(id);
	save_player(id);
	reset_player(id);

	debug_log_user(id, "Client_DIsconnected() apelat" );
}

public OnServerDeactivate()
{
	for (new id = 1; id <= MaxClients; id++)
	{
		if (is_user_connected(id))
			save_player(id);
	}

	debug_log( "OnServerDeactivate() apelat - toti jucatorii au fost salvati inainte de schimbarea hartii");
}

stock reset_player(id)
{
	g_Player[id][g_Level] = 1;
	g_DataLoaded[id] = false;
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
	g_ForceUpgrade[id] = false;
	g_ResistAmount[id] = 0.0;
	g_PierceAmount[id] = 0.0;
	g_BlessAmount[id] = 0.0;

	g_Player[id][g_SkillPath] = PATH_NONE;

	remove_task(id);		
	if (is_user_connected(id))
		set_user_rendering(id);


	debug_log_user(id, "Reset_Player() apelat cu succes" );
}

// ======================== PLAYER LOAD / SAVE (RESTORED FROM WORKING 0.2) ========================

stock load_player(id)
{
	new name[32], key[48];
	get_user_name(id, name, charsmax(name));
	formatex(key, charsmax(key), "m2_%s", name);
	
	new timestamp;
	new size = nvault_get_array(g_Vault, key, g_Player[id], PlayerData, timestamp);
	debug_log_user(id, "Load_Player: LOAD → key=%s | size=%d | Level=%d | XP=%d | Yang=%d | Race=%d", key, size, g_Player[id][g_Level], g_Player[id][g_XP], g_Player[id][g_Yang], g_Player[id][g_Race]);
	

	if (size <= 0)
	{
		g_Player[id][g_Level] = 1;
		g_Player[id][g_Yang] = 1000;
		g_Player[id][g_STR] = 1;
		g_Player[id][g_HP] = 1;
		g_Player[id][g_DEX] = 1;
		g_Player[id][g_INT] = 1;
		g_Player[id][g_MP] = 50;
		g_Player[id][g_MaxMP] = 50;
		debug_log_user(id, "load_player() if size is smaller or equal with 0");
	}
	else
	{
		recalc_max_mp(id);
	}
	g_DataLoaded[id] = true;
}

stock save_player(id)
{
	// Ne asigurăm că ID-ul este in intervalul corect
	if (id < 1 || id > MaxClients)
		return;

	if (!g_DataLoaded[id])
	{
		debug_log_user(id, "SAVE_player() BLOCAT - g_DataLoaded[id] e false, datele nu au fost inca incarcate");
		return;
	}
    
	new name[32], key[48];
	get_user_name(id, name, charsmax(name));
    
	if (!name[0])
		return;
        
	formatex(key, charsmax(key), "m2_%s", name);
	nvault_set_array(g_Vault, key, g_Player[id], PlayerData);
	debug_log_user(id, "SAVE_player() called");
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
		
		client_print_color(0, print_team_default, "%L", LANG_PLAYER, "METIN2_METIN2_%N_AJUNS_LA", id, g_Player[id][g_Level]);
		
		new ret;
		ExecuteForward(g_fwd_LevelUp, ret, id, g_Player[id][g_Level]);
		
		set_task(2.0, "RemoveGlow", id);
		
		needed = get_xp_needed(g_Player[id][g_Level]);
	}
	
	// ← ADAUGĂ ASTA
	debug_log_user(id, "Add_XP stock apelat");
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
	
	client_print_color(killer, print_team_default, "%L", killer, "METIN2_METIN2_XP_YANG", xp, yang, headshot ? " ^3(Headshot)" : "");
	debug_log_user(victim, "OnDeah() Victim Id");
	debug_log_user(killer, "OnDeah() Killer Id");
	
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

	debug_log_user(id, "OnPlayerSpawn()");
}

public OnTakeDamage(victim, inflictor, attacker, Float:damage, damagebits)
{
	if (!is_user_connected(attacker) || !is_user_connected(victim))
		return HC_CONTINUE;
	if (attacker == victim)
		return HC_CONTINUE;
	
	new Float:str_bonus = float(get_total_str(attacker)) * 1.35;
	
	// Bonus arma
	new weap_id = g_Player[attacker][g_Equipped][SLOT_WEAPON];
	new weap_upg = g_Player[attacker][g_EquippedUpgrade][SLOT_WEAPON];
	new Float:weap_bonus = 0.0;
	if (weap_id > 0 && weap_id < g_ItemCount)
		weap_bonus = float(g_Items[weap_id][ItemStr] * 2 + weap_upg * 4);
	
	// Aura Sabiei / Tais Vrajit / Atac Intens / Furia Dragonului / Concentrare
	if (g_AuraActive[attacker])
	{
		new atk_path = g_Player[attacker][g_SkillPath];
		new atk_skill_idx = (g_Player[attacker][g_Race]-1)*10 + (atk_path-1)*5;
		new skill_lvl = g_Player[attacker][g_SkillLevel][atk_skill_idx];
		new player_lvl = g_Player[attacker][g_Level];
		new race = g_Player[attacker][g_Race];

		new Float:aura_bonus = 28.0 + float(skill_lvl) * 2.5 + float(player_lvl) * 0.6;

		// Sinergie pe rasă
		if (race == RACE_WARRIOR)
			aura_bonus += float(get_total_str(attacker)) * 0.75;
		else if (race == RACE_NINJA)
			aura_bonus += float(get_total_dex(attacker)) * 0.70;
		else // Sura / Shaman
			aura_bonus += float(get_total_int(attacker)) * 0.70;

		weap_bonus += aura_bonus;
	}
	
	// Ambush (crit)
	if (g_AmbushActive[attacker])
	{
		damage *= 3.0;
		g_AmbushActive[attacker] = false;
		client_print_color(attacker, print_team_default, "%L", attacker, "METIN2_METIN2_AMBUSH_CRIT");
	}
	
	// Armor Pierce - reduce defense (folosește total DEX + armor)
	new Float:def = float(get_total_dex(victim)) * 0.75;
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
		
		// Determină pe cine să arătăm informațiile
		new target = id;
		
		// Dacă e mort și stă pe cineva în spectator
		if (!is_user_alive(id))
		{
			new spec = pev(id, pev_iuser2);
			
			if (is_user_alive(spec) && is_user_connected(spec))
			{
				target = spec;		// arată info-ul celui pe care îl urmărește
			}
			else
			{
				// Nu urmărește pe nimeni valid → mesaj simplu
				set_hudmessage(255, 180, 0, -1.0, 0.90, 0, 0.0, 1.1, 0.0, 0.0, -1);
				ShowSyncHudMsg(id, g_HudSync, "%L", id, "METIN2_METIN2_ESTI_MORT_ALEGE");
				continue;
			}
		}
		
		// Dacă ținta nu are rasă
		if (g_Player[target][g_Race] == RACE_NONE)
		{
			if (target == id)
			{
				set_hudmessage(255, 200, 0, -1.0, 0.90, 0, 0.0, 1.1, 0.0, 0.0, -1);
				ShowSyncHudMsg(id, g_HudSync, "%L", id, "METIN2_METIN2_SCRIE_MENU_SAU");
			}
			else
			{
				set_hudmessage(255, 180, 0, -1.0, 0.90, 0, 0.0, 1.1, 0.0, 0.0, -1);
				ShowSyncHudMsg(id, g_HudSync, "%L", id, "METIN2_METIN2_JUCATORUL_URMARIT_NU");
			}
			continue;
		}
		
		// HUD normal (propriu sau al celui urmărit)
		new needed = get_xp_needed(g_Player[target][g_Level]);
		new Float:pct = 0.0;
		
		if (needed > 0)
			pct = (float(g_Player[target][g_XP]) / float(needed)) * 100.0;
		
		// Culoare diferită dacă e spectator
		if (target == id)
			set_hudmessage(0, 255, 100, -1.0, 0.90, 0, 0.0, 1.1, 0.0, 0.0, -1);		// verde = propriu
		else
			set_hudmessage(100, 200, 255, -1.0, 0.90, 0, 0.0, 1.1, 0.0, 0.0, -1);		// albastru = spectator
		
		new prefix[32];
		if (target != id)
			formatex(prefix, charsmax(prefix), "[SPEC] ");
		else
			prefix[0] = EOS;
		
		new hp = is_user_alive(target) ? get_user_health(target) : 0;
		
		new szRace[32];
		GetRaceName(id, g_Player[target][g_Race], szRace, charsmax(szRace));
		
		ShowSyncHudMsg(id, g_HudSync, "%L", id, "METIN2_METIN2_LVL_XP_HP", prefix, szRace, g_Player[target][g_Level], pct, hp, g_Player[target][g_Yang], g_Player[target][g_MP], g_Player[target][g_MaxMP], g_Player[target][g_StatPoints], g_Player[target][g_SkillPoints]);
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
	if (!is_user_alive(id) || g_Player[id][g_Race] == RACE_NONE || g_Player[id][g_SkillPath] == PATH_NONE)
		return false;
	
	new Float:now = get_gametime();
	
	if (now < g_SkillCooldown[id][skill_slot])
	{
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_SKILL_IN_COOLDOWN");
		return false;
	}
	
	new race = g_Player[id][g_Race];
	new path = g_Player[id][g_SkillPath];
	new skill_idx = (race - 1) * 10 + (path - 1) * 5 + skill_slot;
	
	if (g_Player[id][g_SkillLevel][skill_idx] <= 0)
	{
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_SKILL_UL_NU");
		return false;
	}
	
	new cost = g_SkillManaCost[skill_slot] + (g_Player[id][g_SkillLevel][skill_idx] / 4);
	if (g_Player[id][g_MP] < cost)
	{
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_MANA_INSUFICIENTA_AI", cost);
		return false;
	}
	
	g_Player[id][g_MP] -= cost;
	return true;
}

stock execute_skill(id, slot)
{
	if (!can_use_skill(id, slot))
		return;
	
	new race = g_Player[id][g_Race];
	new path = g_Player[id][g_SkillPath];
	new skill_idx = (race - 1) * 10 + (path - 1) * 5 + slot;
	new lvl = g_Player[id][g_SkillLevel][skill_idx];
	
	new szSkill[48];
	GetSkillName(id, skill_idx, szSkill, charsmax(szSkill));
	client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_ACTIVEZI_NIVEL", szSkill, lvl);
	
	switch (race)
	{
		case RACE_WARRIOR:
		{
			if (path == PATH_A) skill_warrior_corporal(id, slot, lvl);
			else                skill_warrior_mental(id, slot, lvl);
		}
		case RACE_SURA:
		{
			if (path == PATH_A) skill_sura_arme(id, slot, lvl);
			else                skill_sura_neagra(id, slot, lvl);
		}
		case RACE_NINJA:
		{
			if (path == PATH_A) skill_ninja_lame(id, slot, lvl);
			else                skill_ninja_arc(id, slot, lvl);
		}
		case RACE_SHAMAN:
		{
			if (path == PATH_A) skill_shaman_zmeu(id, slot, lvl);
			else                skill_shaman_fulger(id, slot, lvl);
		}
	}
	
	new ret;
	ExecuteForward(g_fwd_SkillUsed, ret, id, skill_idx, lvl);
}

stock apply_skill_cooldown(id, skill_slot, Float:base_cd)
{
	new Float:cd = GetSkillCooldown(id, skill_slot, base_cd);
	g_SkillCooldown[id][skill_slot] = get_gametime() + cd;
}

// ======================== SKILL SCALING HELPERS ========================
// Cooldown redus pe baza skill level + player level
stock Float:GetSkillCooldown(id, skill_slot, Float:base_cd)
{
	new race = g_Player[id][g_Race];
	new path = g_Player[id][g_SkillPath];
	new skill_idx = (race - 1) * 10 + (path - 1) * 5 + skill_slot;
	new skill_lvl = g_Player[id][g_SkillLevel][skill_idx];
	new player_lvl = g_Player[id][g_Level];

	new Float:cd = base_cd;
	cd -= float(skill_lvl) * 0.35;          // -0.35 pe skill level
	cd -= float(player_lvl) * 0.08;         // -0.08 pe player level

	if (cd < 3.0) cd = 3.0;                 // minim 3 secunde
	return cd;
}

// Durată care crește cu Skill Level + Player Level
stock Float:GetSkillDuration(Float:base_dur, Float:skill_lvl, player_lvl, Float:per_skill, Float:per_level)
{
	new Float:dur = base_dur;
	dur += skill_lvl * per_skill;
	dur += float(player_lvl) * per_level;
	return dur;
}

public cmd_skill1(id) { execute_skill(id, 0); return PLUGIN_HANDLED; }
public cmd_skill2(id) { execute_skill(id, 1); return PLUGIN_HANDLED; }
public cmd_skill3(id) { execute_skill(id, 2); return PLUGIN_HANDLED; }
public cmd_skill4(id) { execute_skill(id, 3); return PLUGIN_HANDLED; }
public cmd_skill5(id) { execute_skill(id, 4); return PLUGIN_HANDLED; }

// ---------- WARRIOR ----------
stock skill_warrior_corporal(id, slot, lvl)
{
	// STR dominant + Level + Skill Level
	new Float:power = float(lvl) * 2.2 + float(g_Player[id][g_Level]) * 1.1 + float(get_total_str(id)) * 1.8 + float(get_total_int(id)) * 0.35;
	
	switch (slot)
	{
		case 0: // Aura Sabiei - damage boost
		{
			g_AuraActive[id] = true;
			new Float:dur = GetSkillDuration(8.0, float(lvl), g_Player[id][g_Level], 0.28, 0.15);
			if (dur > 18.0) dur = 18.0;
			set_user_rendering(id, kRenderFxGlowShell, 255, 80, 0, kRenderNormal, 40);
			set_task(dur, "RemoveAura", id);
			apply_skill_cooldown(id, 0, 20.0);
			new Float:bonus = 28.0 + float(lvl) * 2.4 + float(get_total_str(id)) * 0.6 + float(g_Player[id][g_Level]) * 0.5;
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_AURA_SABIEI_DAMAGE", dur, bonus);
		}
		case 1: // Corp Rezistent - real damage reduction (HP dominant)
		{
			g_ResistActive[id] = true;
			g_ResistAmount[id] = 0.25 + (float(lvl) * 0.008) + (float(get_total_hp(id)) * 0.003) + (float(g_Player[id][g_Level]) * 0.0015);
			if (g_ResistAmount[id] > 0.60) g_ResistAmount[id] = 0.60;
			
			new Float:dur = GetSkillDuration(7.0, float(lvl), g_Player[id][g_Level], 0.22, 0.12);
			if (dur > 16.0) dur = 16.0;
			set_user_rendering(id, kRenderFxGlowShell, 30, 100, 255, kRenderNormal, 35);
			set_task(dur, "RemoveResist", id);
			apply_skill_cooldown(id, 1, 26.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_CORP_REZISTENT_REDUCERE", g_ResistAmount[id] * 100.0, dur);
		}
		case 2: // Izbitura - stun
		{
			new target = get_aim_target(id);
			if (is_user_alive(target))
			{
				new Float:stun = 1.4 + (lvl * 0.07) + (float(g_Player[id][g_Level]) * 0.015) + (float(get_total_str(id)) * 0.012);
				if (stun > 3.5) stun = 3.5;
				set_pev(target, pev_flags, pev(target, pev_flags) | FL_FROZEN);
				set_task(stun, "Unfreeze", target);
				apply_skill_cooldown(id, 2, 16.0);
				client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_IZBITURA_INAMIC_INGHETAT", stun);
			}
			else
			{
				apply_skill_cooldown(id, 2, 16.0);
				client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_NICIO_TINTA_VALIDA");
			}
		}
		case 3: // Dash
		{
			new Float:angles[3], Float:vec[3];
			pev(id, pev_v_angle, angles);
			angle_vector(angles, ANGLEVECTOR_FORWARD, vec);
	
			new Float:speed = 900.0 + (lvl * 18.0) + (float(g_Player[id][g_Level]) * 4.0) + (float(get_total_str(id)) * 2.0);
			vec[0] *= speed;
			vec[1] *= speed;
			vec[2] = 150.0;
	
			set_pev(id, pev_velocity, vec);
	
			apply_skill_cooldown(id, 3, 12.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_ATAC_SABIE_DASH");
		}
		case 4: // Vartej AoE
		{
			new Float:origin[3];
			pev(id, pev_origin, origin);
			
			new Float:radius = 180.0 + (lvl * 3.5) + (float(g_Player[id][g_Level]) * 1.2);
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
			apply_skill_cooldown(id, 4, 24.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_VARTEJ_SABIE_AOE", dmg, radius, hit);
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
stock skill_sura_arme(id, slot, lvl)
{	
	switch (slot)
	{
		case 0: // Tais Vrajit - damage + lifesteal simplified as damage boost
		{
			g_AuraActive[id] = true;
			new Float:dur = GetSkillDuration(7.0, float(lvl), g_Player[id][g_Level], 0.22, 0.13);
			if (dur > 16.0) dur = 16.0;
			set_user_rendering(id, kRenderFxGlowShell, 180, 50, 255, kRenderNormal, 40);
			set_task(dur, "RemoveAura", id);
			apply_skill_cooldown(id, 0, 18.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_TAIS_VRAJIT_DAMAGE", dur);
		}
		case 1: // Reflect
		{
			g_ReflectActive[id] = true;
			new Float:dur = GetSkillDuration(6.0, float(lvl), g_Player[id][g_Level], 0.20, 0.12);
			if (dur > 14.0) dur = 14.0;
			set_user_rendering(id, kRenderFxGlowShell, 255, 0, 100, kRenderNormal, 35);
			set_task(dur, "RemoveReflect", id);
			apply_skill_cooldown(id, 1, 28.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_ARMURA_VRAJITA_REFLECTI", dur);
		}
		case 2: // Armor Pierce - real pierce
		{
			g_PierceActive[id] = true;
			g_PierceAmount[id] = 0.35 + (float(lvl) * 0.011) + (float(get_total_int(id)) * 0.006) + (float(g_Player[id][g_Level]) * 0.002);
			if (g_PierceAmount[id] > 0.75) g_PierceAmount[id] = 0.75;
			
			new Float:dur = GetSkillDuration(6.0, float(lvl), g_Player[id][g_Level], 0.18, 0.10);
			if (dur > 12.0) dur = 12.0;
			set_task(dur, "RemovePierce", id);
			apply_skill_cooldown(id, 2, 14.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_LOVITURA_DEGETULUI_ARMOR", g_PierceAmount[id] * 100.0, dur);
		}
		case 3: // Slow
		{
			new target = get_aim_target(id);
			if (is_user_alive(target))
			{
				new Float:slow_dur = 3.5 + (lvl * 0.12) + (float(g_Player[id][g_Level]) * 0.04) + (float(get_total_int(id)) * 0.02);
				if (slow_dur > 7.0) slow_dur = 7.0;
				set_user_maxspeed(target, 110.0);
				set_task(slow_dur, "RestoreSpeed", target);
				apply_skill_cooldown(id, 3, 16.0);
				client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_ATACUL_FULGERULUI_TINTA", slow_dur);
			}
			else
			{
				apply_skill_cooldown(id, 3, 16.0);
				client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_NICIO_TINTA_VALIDA_2");
			}
		}
		case 4: // Pietrificare - real freeze + slow after
		{
			new target = get_aim_target(id);
			if (is_user_alive(target))
			{
				new Float:stun = 1.8 + (lvl * 0.06) + (float(get_total_int(id)) * 0.025) + (float(g_Player[id][g_Level]) * 0.02);
				if (stun > 4.0) stun = 4.0;
				set_pev(target, pev_flags, pev(target, pev_flags) | FL_FROZEN);
				set_task(stun, "Unfreeze", target);
				
				// After unfreeze, residual slow
				set_task(stun + 0.1, "ApplyResidualSlow", target);
				
				apply_skill_cooldown(id, 4, 34.0);
				client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_PIETRIFICARE_INAMICUL_ESTE", stun);
			}
			else
			{
				apply_skill_cooldown(id, 4, 34.0);
				client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_NICIO_TINTA_VALIDA_3");
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
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_NU_AI_INCA");
		return PLUGIN_HANDLED;
	}
	
	new level = g_Player[id][g_Level];
	
	// ===== PĂSTREAZĂ =====
	// Level, XP, Yang, Inventar, Echipament → NU se ating!
	
	// ===== RESETEAZĂ =====
	g_Player[id][g_Race] = RACE_NONE;
	
	// Stats de bază la 1 (minim)
	g_Player[id][g_STR] = 1;
	g_Player[id][g_HP]  = 1;
	g_Player[id][g_DEX] = 1;
	g_Player[id][g_INT] = 1;
	
	// Dă înapoi TOATE punctele pe care le-ar fi avut la acel nivel
	// (5 la start + 1 pe fiecare level up)
	g_Player[id][g_StatPoints]  = 5 + (level - 1);
	g_Player[id][g_SkillPoints] = 3 + (level - 1);
	
	// Resetează toate skill-urile
	for (new i = 0; i < MAX_SKILLS; i++)
		g_Player[id][g_SkillLevel][i] = 0;
	
	g_Player[id][g_SkillPath] = PATH_NONE;
	
	// Oprește buff-urile active
	g_AuraActive[id]     = false;
	g_ReflectActive[id]  = false;
	g_AmbushActive[id]   = false;
	g_ResistActive[id]   = false;
	g_PierceActive[id]   = false;
	g_BlessActive[id]    = false;
	g_ResistAmount[id]   = 0.0;
	g_PierceAmount[id]   = 0.0;
	g_BlessAmount[id]    = 0.0;
	
	remove_task(id);
	if (is_user_alive(id))
		set_user_rendering(id);
	
	recalc_max_mp(id);
	
	// === IMPORTANT: recalculează HP + Speed LIVE dacă e în viață ===
	if (is_user_alive(id))
	{
		// HP = 100 + (HP_stat * 10) + bonus iteme
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
		
		// Speed = 250 + bonus iteme
		new Float:speed = 250.0;
		for (new i = 0; i < MAX_EQUIP_SLOTS; i++)
		{
			new itemid = g_Player[id][g_Equipped][i];
			if (itemid > 0 && itemid < g_ItemCount)
				speed += float(g_Items[itemid][ItemSpeed] + g_Player[id][g_EquippedUpgrade][i] * 2);
		}
		
		set_user_maxspeed(id, speed);
		
		// MP full după recalc
		g_Player[id][g_MP] = g_Player[id][g_MaxMP];
	}
	
	save_player(id);
	
	client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_CARACTER_RESETAT_LEVEL", level, g_Player[id][g_StatPoints], g_Player[id][g_SkillPoints]);
	client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_ITEMELE_SI_YANG");

	debug_log_user(id, "cmd reset()");
	
	return PLUGIN_HANDLED;
}

// ---------- NINJA ----------
stock skill_ninja_lame(id, slot, lvl)
{
	// DEX dominant
	new Float:power = float(lvl) * 2.0 + float(g_Player[id][g_Level]) * 0.9 + float(get_total_dex(id)) * 2.1 + float(get_total_int(id)) * 0.35;

	switch (slot)
	{
		case 0: // Camuflaj
		{
			new Float:dur = GetSkillDuration(4.5, float(lvl), g_Player[id][g_Level], 0.20, 0.10);
			if (dur > 12.0) dur = 12.0;
			set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, 8);
			set_task(dur, "RemoveInvis", id);
			apply_skill_cooldown(id, 0, 24.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_CAMUFLAJ_ESTI_APROAPE", dur);
		}
		case 1: // Speed
		{
			new Float:spd = 420.0 + (lvl * 7.0) + (float(get_total_dex(id)) * 2.5) + (float(g_Player[id][g_Level]) * 3.0);
			set_user_maxspeed(id, spd);
			new Float:dur = GetSkillDuration(6.0, float(lvl), g_Player[id][g_Level], 0.15, 0.10);
			if (dur > 12.0) dur = 12.0;
			set_task(dur, "RestoreSpeed", id);
			apply_skill_cooldown(id, 1, 18.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_ATACUL_FULGERATOR_VITEZA", spd, dur);
		}
		case 2: // Ambush
		{
			g_AmbushActive[id] = true;
			apply_skill_cooldown(id, 2, 15.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_AMBUSH_PREGATIT_URMATORUL");
		}
		case 3: // Poison
		{
			new target = get_aim_target(id);
			if (is_user_alive(target))
			{
				new taskid = (id * 100) + target;
				new ticks = 4 + (lvl / 5) + (g_Player[id][g_Level] / 20);
				if (ticks > 12) ticks = 12;
				set_task(1.0, "PoisonTick", taskid, _, _, "a", ticks);
				apply_skill_cooldown(id, 3, 17.0);
				client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_OTRAVA_DOT_PE", ticks);
			}
			else
			{
				apply_skill_cooldown(id, 3, 17.0);
				client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_NICIO_TINTA_VALIDA_2");
			}
		}
		case 4: // Ploaie de sageti (AoE mic)
		{
			new Float:origin[3];
			pev(id, pev_origin, origin);
			
			new Float:dmg = 28.0 + power;
			
			new hit = 0;
			for (new i = 1; i <= MaxClients; i++)
			{
				if (!is_user_alive(i) || i == id) continue;
				if (get_user_team(i) == get_user_team(id)) continue;
				
				new Float:torigin[3];
				pev(i, pev_origin, torigin);
				
				if (get_distance_f(origin, torigin) < 250.0 + float(lvl) * 2.0)
				{
					ExecuteHamB(Ham_TakeDamage, i, id, id, dmg, DMG_BULLET);
					hit++;
				}
			}
			apply_skill_cooldown(id, 4, 26.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_PLOAIE_DE_SAGETI", dmg, hit);
		}
	}
}

// ---------- SHAMAN ----------
stock skill_shaman_zmeu(id, slot, lvl)
{
	// INT dominant
	new Float:power = float(lvl) * 2.2 + float(g_Player[id][g_Level]) * 1.0 + float(get_total_int(id)) * 1.9 + float(get_total_str(id)) * 0.25;
	
	switch (slot)
	{
		// 0 - Chemarea Dragonului: AoE foc în jurul tău
		case 0:
		{
			new Float:origin[3];
			pev(id, pev_origin, origin);
			
			new Float:radius = 220.0 + (lvl * 3.5) + (float(g_Player[id][g_Level]) * 1.5);
			new Float:dmg = 35.0 + power * 0.95;
			new hit = 0;
			
			for (new i = 1; i <= MaxClients; i++)
			{
				if (!is_user_alive(i) || i == id) continue;
				if (get_user_team(i) == get_user_team(id)) continue;
				
				new Float:torigin[3];
				pev(i, pev_origin, torigin);
				
				if (get_distance_f(origin, torigin) < radius)
				{
					ExecuteHamB(Ham_TakeDamage, i, id, id, dmg, DMG_BURN);
					hit++;
				}
			}
			
			apply_skill_cooldown(id, 0, 14.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_CHEMAREA_DRAGONULUI_DMG", dmg, hit);
		}
		
		// 1 - Flacara Dragonului: damage mare single-target
		case 1:
		{
			new target = get_aim_target(id);
			if (is_user_alive(target))
			{
				new Float:dmg = 55.0 + power * 1.15;
				ExecuteHamB(Ham_TakeDamage, target, id, id, dmg, DMG_BURN);
				apply_skill_cooldown(id, 1, 12.0);
				client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_FLACARA_DRAGONULUI_DMG", dmg);
			}
			else
			{
				apply_skill_cooldown(id, 1, 12.0);
				client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_NICIO_TINTA_VALIDA_2");
			}
		}
		
		// 2 - Scut de Solzi: reducere damage (HP + INT)
		case 2:
		{
			g_ResistActive[id] = true;
			g_ResistAmount[id] = 0.28 + (float(lvl) * 0.007) + (float(get_total_hp(id)) * 0.0025) + (float(g_Player[id][g_Level]) * 0.0015);
			if (g_ResistAmount[id] > 0.55) g_ResistAmount[id] = 0.55;
			
			new Float:dur = GetSkillDuration(7.0, float(lvl), g_Player[id][g_Level], 0.20, 0.12);
			if (dur > 15.0) dur = 15.0;
			set_user_rendering(id, kRenderFxGlowShell, 255, 140, 40, kRenderNormal, 40);
			set_task(dur, "RemoveResist", id);
			apply_skill_cooldown(id, 2, 22.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_SCUT_DE_SOLZI", g_ResistAmount[id]*100.0, dur);
		}
		
		// 3 - Zborul Dragonului: boost de viteză
		case 3:
		{
			new Float:speed = 280.0 + (lvl * 2.0) + float(get_total_dex(id)) * 0.6 + float(g_Player[id][g_Level]) * 1.5;
			// bonus din papuci
			for (new i = 0; i < MAX_EQUIP_SLOTS; i++)
			{
				new itemid = g_Player[id][g_Equipped][i];
				if (itemid > 0 && itemid < g_ItemCount)
					speed += float(g_Items[itemid][ItemSpeed] + g_Player[id][g_EquippedUpgrade][i] * 2);
			}
			
			set_user_maxspeed(id, speed);
			new Float:dur = GetSkillDuration(6.0, float(lvl), g_Player[id][g_Level], 0.15, 0.10);
			if (dur > 12.0) dur = 12.0;
			set_task(dur, "RestoreSpeed", id);
			apply_skill_cooldown(id, 3, 18.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_ZBORUL_DRAGONULUI_VITEZA", dur);
		}
		
		// 4 - Furia Dragonului: buff puternic de damage + mic AoE la activare
		case 4:
		{
			g_AuraActive[id] = true;
			new Float:dur = GetSkillDuration(7.5, float(lvl), g_Player[id][g_Level], 0.20, 0.13);
			if (dur > 16.0) dur = 16.0;
			set_user_rendering(id, kRenderFxGlowShell, 255, 60, 0, kRenderNormal, 45);
			set_task(dur, "RemoveAura", id);
			
			// mic burst AoE la activare
			new Float:origin[3];
			pev(id, pev_origin, origin);
			new Float:burst = 25.0 + power * 0.55;
			
			for (new i = 1; i <= MaxClients; i++)
			{
				if (!is_user_alive(i) || i == id) continue;
				if (get_user_team(i) == get_user_team(id)) continue;
				
				new Float:torigin[3];
				pev(i, pev_origin, torigin);
				
				if (get_distance_f(origin, torigin) < 180.0 + float(lvl) * 2.0)
					ExecuteHamB(Ham_TakeDamage, i, id, id, burst, DMG_BURN);
			}
			
			apply_skill_cooldown(id, 4, 30.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_FURIA_DRAGONULUI_DAMAGE", dur);
		}
	}
}

// ======================== WARRIOR - MENTAL ========================
stock skill_warrior_mental(id, slot, lvl)
{
	// STR + INT mix (Mental path)
	new Float:power = float(lvl) * 2.0 + float(g_Player[id][g_Level]) * 1.0 + float(get_total_str(id)) * 1.2 + float(get_total_int(id)) * 1.1;
	
	switch (slot)
	{
		case 0: // Lovitura Spiritului - damage magic single target
		{
			new target = get_aim_target(id);
			if (is_user_alive(target))
			{
				new Float:dmg = 40.0 + power;
				ExecuteHamB(Ham_TakeDamage, target, id, id, dmg, DMG_ENERGYBEAM);
				apply_skill_cooldown(id, 0, 14.0);
				client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_LOVITURA_SPIRITULUI_DAMAGE", dmg);
			}
			else
			{
				apply_skill_cooldown(id, 0, 14.0);
				client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_NICIO_TINTA_VALIDA_2");
			}
		}
		case 1: // Scut Mental - absorb damage (HP + INT)
		{
			g_ResistActive[id] = true;
			g_ResistAmount[id] = 0.30 + (float(lvl) * 0.008) + (float(get_total_hp(id)) * 0.0025) + (float(g_Player[id][g_Level]) * 0.0015);
			if (g_ResistAmount[id] > 0.58) g_ResistAmount[id] = 0.58;
			
			new Float:dur = GetSkillDuration(6.5, float(lvl), g_Player[id][g_Level], 0.20, 0.12);
			if (dur > 14.0) dur = 14.0;
			set_user_rendering(id, kRenderFxGlowShell, 100, 100, 255, kRenderNormal, 35);
			set_task(dur, "RemoveResist", id);
			apply_skill_cooldown(id, 1, 22.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_SCUT_MENTAL_REDUCERE", g_ResistAmount[id]*100.0, dur);
		}
		case 2: // Valul de Putere - AoE knockback + small dmg
		{
			new Float:origin[3];
			pev(id, pev_origin, origin);
			
			new Float:radius = 200.0 + (lvl * 3.0) + (float(g_Player[id][g_Level]) * 1.2);
			new Float:dmg = 25.0 + power * 0.75;
			new hit = 0;
			
			for (new i = 1; i <= MaxClients; i++)
			{
				if (!is_user_alive(i) || i == id) continue;
				if (get_user_team(i) == get_user_team(id)) continue;
				
				new Float:torigin[3];
				pev(i, pev_origin, torigin);
				
				if (get_distance_f(origin, torigin) < radius)
				{
					ExecuteHamB(Ham_TakeDamage, i, id, id, dmg, DMG_SONIC);
					
					// mic knockback
					new Float:vel[3];
					vel[0] = (torigin[0] - origin[0]) * 2.5;
					vel[1] = (torigin[1] - origin[1]) * 2.5;
					vel[2] = 220.0;
					set_pev(i, pev_velocity, vel);
					hit++;
				}
			}
			apply_skill_cooldown(id, 2, 18.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_VALUL_DE_PUTERE", hit);
		}
		case 3: // Concentrare - buff damage + crit chance
		{
			g_AmbushActive[id] = true;
			g_AuraActive[id] = true;
			new Float:dur = GetSkillDuration(7.0, float(lvl), g_Player[id][g_Level], 0.22, 0.13);
			if (dur > 15.0) dur = 15.0;
			set_user_rendering(id, kRenderFxGlowShell, 180, 180, 255, kRenderNormal, 40);
			set_task(dur, "RemoveAura", id);
			apply_skill_cooldown(id, 3, 17.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_CONCENTRARE_DAMAGE_URMATORUL", dur);
		}
		case 4: // Explozie Interioara - self damage + big AoE
		{
			new Float:origin[3];
			pev(id, pev_origin, origin);
			
			new Float:dmg = 55.0 + power;
			new hit = 0;
			
			// damage pe sine (mic)
			ExecuteHamB(Ham_TakeDamage, id, id, id, 15.0, DMG_BLAST);
			
			for (new i = 1; i <= MaxClients; i++)
			{
				if (!is_user_alive(i) || i == id) continue;
				if (get_user_team(i) == get_user_team(id)) continue;
				
				new Float:torigin[3];
				pev(i, pev_origin, torigin);
				
				if (get_distance_f(origin, torigin) < 230.0 + float(lvl) * 2.0)
				{
					ExecuteHamB(Ham_TakeDamage, i, id, id, dmg, DMG_BLAST);
					hit++;
				}
			}
			apply_skill_cooldown(id, 4, 26.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_EXPLOZIE_INTERIOARA_AOE", dmg, hit);
		}
	}
}

// ======================== SURA - MAGIE NEAGRA ========================
stock skill_sura_neagra(id, slot, lvl)
{
	// INT dominant
	new Float:power = float(lvl) * 2.0 + float(g_Player[id][g_Level]) * 1.0 + float(get_total_int(id)) * 1.9 + float(get_total_str(id)) * 0.3;
	
	switch (slot)
	{
		case 0: // Flacara Intunecata - DoT + damage
		{
			new target = get_aim_target(id);
			if (is_user_alive(target))
			{
				new Float:dmg = 30.0 + power * 0.85;
				ExecuteHamB(Ham_TakeDamage, target, id, id, dmg, DMG_BURN);
				
				new taskid = (id * 100) + target + 5000;
				new ticks = 4 + (lvl / 6) + (g_Player[id][g_Level] / 25);
				if (ticks > 10) ticks = 10;
				set_task(1.0, "DarkFlameTick", taskid, _, _, "a", ticks);
				
				apply_skill_cooldown(id, 0, 15.0);
				client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_FLACARA_INTUNECATA_DAMAGE");
			}
			else
			{
				apply_skill_cooldown(id, 0, 15.0);
				client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_NICIO_TINTA_VALIDA_2");
			}
		}
		case 1: // Blestem - reduce stats inamic
		{
			new target = get_aim_target(id);
			if (is_user_alive(target))
			{
				new Float:slow_dur = 4.0 + (lvl * 0.14) + (float(g_Player[id][g_Level]) * 0.05) + (float(get_total_int(id)) * 0.02);
				if (slow_dur > 8.0) slow_dur = 8.0;
				set_user_maxspeed(target, 130.0);
				set_task(slow_dur, "RestoreSpeed", target);
				
				g_ReflectActive[target] = true;
				set_task(slow_dur + 0.5, "RemoveReflect", target);
				
				apply_skill_cooldown(id, 1, 20.0);
				client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_BLESTEM_TINTA_INCETINITA", slow_dur);
			}
			else
			{
				apply_skill_cooldown(id, 1, 20.0);
				client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_NICIO_TINTA_VALIDA_2");
			}
		}
		case 2: // Absorbție de Suflet - lifesteal
		{
			new target = get_aim_target(id);
			if (is_user_alive(target))
			{
				new Float:dmg = 35.0 + power * 0.95;
				ExecuteHamB(Ham_TakeDamage, target, id, id, dmg, DMG_ENERGYBEAM);
				
				new heal = floatround(dmg * 0.48);
				new hp = get_user_health(id);
				set_user_health(id, min(hp + heal, 100 + g_Player[id][g_HP] * 10 + 80));
				
				apply_skill_cooldown(id, 2, 14.0);
				client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_ABSORBTIE_DE_SUFLET", dmg, heal);
			}
			else
			{
				apply_skill_cooldown(id, 2, 14.0);
				client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_NICIO_TINTA_VALIDA_2");
			}
		}
		case 3: // Umbre - invis + speed
		{
			new Float:dur = GetSkillDuration(4.0, float(lvl), g_Player[id][g_Level], 0.18, 0.10);
			if (dur > 11.0) dur = 11.0;
			set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderTransAlpha, 15);
			set_user_maxspeed(id, 380.0 + (lvl * 5.0) + (float(g_Player[id][g_Level]) * 2.0));
			set_task(dur, "RemoveInvis", id);
			set_task(dur, "RestoreSpeed", id);
			apply_skill_cooldown(id, 3, 22.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_UMBRE_APROAPE_INVIZIBIL", dur);
		}
		case 4: // Invocarea Haosului - big AoE dark
		{
			new Float:origin[3];
			pev(id, pev_origin, origin);
			
			new Float:dmg = 48.0 + power;
			new hit = 0;
			
			for (new i = 1; i <= MaxClients; i++)
			{
				if (!is_user_alive(i) || i == id) continue;
				if (get_user_team(i) == get_user_team(id)) continue;
				
				new Float:torigin[3];
				pev(i, pev_origin, torigin);
				
				if (get_distance_f(origin, torigin) < 260.0 + float(lvl) * 2.5)
				{
					ExecuteHamB(Ham_TakeDamage, i, id, id, dmg, DMG_ENERGYBEAM);
					hit++;
				}
			}
			apply_skill_cooldown(id, 4, 28.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_INVOCAREA_HAOSULUI_AOE", dmg, hit);
		}
	}
}

public DarkFlameTick(taskid)
{
	new attacker = (taskid - 5000) / 100;
	new target = (taskid - 5000) % 100;
	
	if (is_user_alive(target) && is_user_connected(attacker))
		ExecuteHamB(Ham_TakeDamage, target, attacker, attacker, 8.0 + float(get_total_int(attacker)) * 0.35 + float(g_Player[attacker][g_Level]) * 0.15, DMG_BURN);
}

// ======================== NINJA - ARC ========================
stock skill_ninja_arc(id, slot, lvl)
{
	// DEX dominant
	new Float:power = float(lvl) * 2.1 + float(g_Player[id][g_Level]) * 0.95 + float(get_total_dex(id)) * 2.0 + float(get_total_int(id)) * 0.4;
	
	switch (slot)
	{
		case 0: // Ploaie de Sageti
		{
			new Float:origin[3];
			pev(id, pev_origin, origin);
			
			new Float:dmg = 32.0 + power;
			new hit = 0;
			
			for (new i = 1; i <= MaxClients; i++)
			{
				if (!is_user_alive(i) || i == id) continue;
				if (get_user_team(i) == get_user_team(id)) continue;
				
				new Float:torigin[3];
				pev(i, pev_origin, torigin);
				
				if (get_distance_f(origin, torigin) < 280.0 + float(lvl) * 2.5)
				{
					ExecuteHamB(Ham_TakeDamage, i, id, id, dmg, DMG_BULLET);
					hit++;
				}
			}
			apply_skill_cooldown(id, 0, 18.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_PLOAIE_DE_SAGETI_2", dmg, hit);
		}
		case 1: // Sageata Exploziva
		{
			new target = get_aim_target(id);
			if (is_user_alive(target))
			{
				new Float:dmg = 45.0 + power;
				ExecuteHamB(Ham_TakeDamage, target, id, id, dmg, DMG_BLAST);
				
				// mic AoE în jurul țintei
				new Float:torigin[3];
				pev(target, pev_origin, torigin);
				
				for (new i = 1; i <= MaxClients; i++)
				{
					if (!is_user_alive(i) || i == id || i == target) continue;
					if (get_user_team(i) == get_user_team(id)) continue;
					
					new Float:o[3];
					pev(i, pev_origin, o);
					if (get_distance_f(torigin, o) < 150.0 + float(lvl) * 1.5)
						ExecuteHamB(Ham_TakeDamage, i, id, id, dmg * 0.5, DMG_BLAST);
				}
				
				apply_skill_cooldown(id, 1, 16.0);
				client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_SAGEATA_EXPLOZIVA_DMG", dmg);
			}
			else
			{
				apply_skill_cooldown(id, 1, 16.0);
				client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_NICIO_TINTA_VALIDA_2");
			}
		}
		case 2: // Tintire Precisa - next hit guaranteed high damage
		{
			g_AmbushActive[id] = true; // x3 crit
			apply_skill_cooldown(id, 2, 12.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_TINTIRE_PRECISA_URMATORUL");
		}
		case 3: // Sageata Otravita
		{
			new target = get_aim_target(id);
			if (is_user_alive(target))
			{
				new taskid = (id * 100) + target;
				new ticks = 5 + (lvl / 4) + (g_Player[id][g_Level] / 20);
				if (ticks > 14) ticks = 14;
				set_task(1.0, "PoisonTick", taskid, _, _, "a", ticks);
				
				apply_skill_cooldown(id, 3, 15.0);
				client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_SAGEATA_OTRAVITA_DOT", ticks);
			}
			else
			{
				apply_skill_cooldown(id, 3, 15.0);
				client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_NICIO_TINTA_VALIDA_2");
			}
		}
		case 4: // Val de Sageti - rapid fire AoE
		{
			new Float:origin[3];
			pev(id, pev_origin, origin);
			
			new Float:dmg = 22.0 + power * 0.65;
			new hit = 0;
			
			for (new i = 1; i <= MaxClients; i++)
			{
				if (!is_user_alive(i) || i == id) continue;
				if (get_user_team(i) == get_user_team(id)) continue;
				
				new Float:torigin[3];
				pev(i, pev_origin, torigin);
				
				if (get_distance_f(origin, torigin) < 320.0 + float(lvl) * 2.0)
				{
					ExecuteHamB(Ham_TakeDamage, i, id, id, dmg, DMG_BULLET);
					hit++;
				}
			}
			apply_skill_cooldown(id, 4, 24.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_VAL_DE_SAGETI", dmg, hit);
		}
	}
}

// ======================== SHAMAN - FULGER / VINDECARE ========================
stock skill_shaman_fulger(id, slot, lvl)
{
	// INT dominant
	new Float:power = float(lvl) * 2.2 + float(g_Player[id][g_Level]) * 1.1 + float(get_total_int(id)) * 1.95 + float(get_total_hp(id)) * 0.15;
	
	switch (slot)
	{
		case 0: // Lecuire
		{
			new heal = 55 + floatround(power * 0.9);
			new hp = get_user_health(id);
			new maxhp = 100 + g_Player[id][g_HP] * 10;
			
			for (new i = 0; i < MAX_EQUIP_SLOTS; i++)
			{
				new itemid = g_Player[id][g_Equipped][i];
				if (itemid > 0 && itemid < g_ItemCount)
					maxhp += g_Items[itemid][ItemHp] + g_Player[id][g_EquippedUpgrade][i] * 3;
			}
			
			set_user_health(id, min(hp + heal, maxhp));
			apply_skill_cooldown(id, 0, 10.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_LECUIRE_HP", heal);
		}
		case 1: // Atac Intens
		{
			g_AuraActive[id] = true;
			new Float:dur = GetSkillDuration(8.5, float(lvl), g_Player[id][g_Level], 0.22, 0.14);
			if (dur > 18.0) dur = 18.0;
			set_user_rendering(id, kRenderFxGlowShell, 255, 220, 50, kRenderNormal, 40);
			set_task(dur, "RemoveAura", id);
			apply_skill_cooldown(id, 1, 26.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_ATAC_INTENS_DAMAGE", dur);
		}
		case 2: // Binecuvantare
		{
			g_BlessActive[id] = true;
			g_BlessAmount[id] = 18.0 + (float(lvl) * 1.6) + (float(get_total_int(id)) * 1.1) + (float(g_Player[id][g_Level]) * 0.4);
			
			new Float:dur = GetSkillDuration(10.0, float(lvl), g_Player[id][g_Level], 0.25, 0.15);
			if (dur > 20.0) dur = 20.0;
			set_user_rendering(id, kRenderFxGlowShell, 80, 255, 120, kRenderNormal, 35);
			set_task(dur, "RemoveBless", id);
			apply_skill_cooldown(id, 2, 22.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_BINECUVANTARE_DEFENSE_SEC", g_BlessAmount[id], dur);
		}
		case 3: // Iutesenie - reset CD
		{
			for (new i = 0; i < 5; i++)
				g_SkillCooldown[id][i] = 0.0;
			
			// CD-ul pe Iutesenie scade puțin cu level
			new Float:base_cd = 50.0 - (float(g_Player[id][g_Level]) * 0.15) - (float(lvl) * 0.2);
			if (base_cd < 35.0) base_cd = 35.0;
			apply_skill_cooldown(id, 3, base_cd);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_IUTESENIE_TOATE_COOLDOWN");
		}
		case 4: // Chemarea Fulgerului
		{
			new Float:origin[3];
			pev(id, pev_origin, origin);

			engfunc(EngFunc_MessageBegin, MSG_PVS, get_user_msgid("ScreenFade"), origin, 0);
			write_short(1<<10);
			write_short(1<<10);
			write_short(1<<12);
			write_byte(200);
			write_byte(220);
			write_byte(255);
			write_byte(200);
			message_end();
			
			new Float:radius = 220.0 + (lvl * 3.0) + (float(g_Player[id][g_Level]) * 1.2);
			new stunned = 0;
			
			for (new i = 1; i <= MaxClients; i++)
			{
				if (!is_user_alive(i) || i == id) continue;
				if (get_user_team(i) == get_user_team(id)) continue;
				
				new Float:torigin[3];
				pev(i, pev_origin, torigin);
				
				if (get_distance_f(origin, torigin) < radius)
				{
					if (random_num(1, 100) <= (30 + lvl / 2 + g_Player[id][g_Level] / 10))
					{
						new Float:stun_time = 1.4 + (lvl * 0.05) + (float(g_Player[id][g_Level]) * 0.015);
						if (stun_time > 3.0) stun_time = 3.0;
						set_pev(i, pev_flags, pev(i, pev_flags) | FL_FROZEN);
						set_task(stun_time, "Unfreeze", i);
						stunned++;
					}
					
					// mic damage de fulger
					ExecuteHamB(Ham_TakeDamage, i, id, id, 20.0 + power * 0.45, DMG_SHOCK);
				}
			}
			
			apply_skill_cooldown(id, 4, 26.0);
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_CHEMAREA_FULGERULUI_FLASH", stunned);
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
		ExecuteHamB(Ham_TakeDamage, target, attacker, attacker, 9.0 + float(get_total_dex(attacker)) * 0.25 + float(get_total_int(attacker)) * 0.2 + float(g_Player[attacker][g_Level]) * 0.12, DMG_POISON);
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
	
	client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_AI_SETAT_LEVEL", target, newlevel);
	client_print_color(target, print_team_default, "%L", target, "METIN2_METIN2_UN_ADMIN_TI", newlevel);
	
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
	
	client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_AI_SETAT_XP", target, newxp);
	client_print_color(target, print_team_default, "%L", target, "METIN2_METIN2_UN_ADMIN_TI_2", newxp);
	
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
	
	client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_AI_SETAT_STATUS", target, points);
	client_print_color(target, print_team_default, "%L", target, "METIN2_METIN2_UN_ADMIN_TI_3", points);
	
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
	
	client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_AI_SETAT_YANG", target, yang);
	client_print_color(target, print_team_default, "%L", target, "METIN2_METIN2_UN_ADMIN_TI_4", yang);
	
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
	
	client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_AI_SETAT_SKILL", target, points);
	client_print_color(target, print_team_default, "%L", target, "METIN2_METIN2_UN_ADMIN_TI_5", points);
	
	return PLUGIN_HANDLED;
}

// ======================== MENIURI ========================

public cmd_menu(id)
{
	new menu = menu_create(fmt("%L", id, "METIN2_METIN2_MENIU_PRINCIPAL"), "menu_handler");
	menu_additem(menu, fmt("%L", id, "ALEGE_RASA"), "1");
	menu_additem(menu, fmt("%L", id, "STATUT_ALOCARE_PUNCTE"), "2");
	menu_additem(menu, fmt("%L", id, "SKILL_URI"), "3");
	menu_additem(menu, fmt("%L", id, "INVENTAR_ECHIPARE"), "4");
	menu_additem(menu, fmt("%L", id, "FIERAR_UPGRADE"), "5");
	menu_additem(menu, fmt("%L", id, "MAGAZIN"), "6");
	menu_additem(menu, fmt("%L", id, "GHID_BIND_URI"), "7");
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
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
	menu_destroy(menu);
	
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
	
	return PLUGIN_HANDLED;
}

stock show_race_menu(id)
{
	if (g_Player[id][g_Race] != RACE_NONE)
	{
		new szRace[32];
		GetRaceName(id, g_Player[id][g_Race], szRace, charsmax(szRace));
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_AI_DEJA_RASA", szRace);
		return;
	}
	
	new menu = menu_create(fmt("%L", id, "ALEGE_RASA_2"), "race_handler");
	menu_additem(menu, fmt("%L", id, "RAZBOINIC_PUTERE_BRUTA"), "1");
	menu_additem(menu, fmt("%L", id, "SURA_MAGIE_REFLECT"), "2");
	menu_additem(menu, fmt("%L", id, "NINJA_VITEZA_CRIT"), "3");
	menu_additem(menu, fmt("%L", id, "SAMAN_SUPPORT_HEAL"), "4");
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
	g_Player[id][g_SkillPath] = PATH_NONE;

	// Dă punctele de start DOAR dacă e caracter nou (level 1 și 0 puncte)
	// Altfel (după /reset) păstrează punctele calculate în cmd_reset
	if (g_Player[id][g_Level] <= 1 && g_Player[id][g_StatPoints] <= 0)
	{
		g_Player[id][g_StatPoints]  = 5;
		g_Player[id][g_SkillPoints] = 3;
	}
	
	recalc_max_mp(id);
	g_Player[id][g_MP] = g_Player[id][g_MaxMP];
	
	new szRace[32];
	GetRaceName(id, race, szRace, charsmax(szRace));
	client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_AI_ALES_RASA", szRace);
	save_player(id);
	
	new ret;
	ExecuteForward(g_fwd_RaceSelected, ret, id, race);
	
	menu_destroy(menu);
	
	show_path_menu(id);
	
	return PLUGIN_HANDLED;
}

stock show_path_menu(id)
{
	if (g_Player[id][g_Race] == RACE_NONE)
		return;
	
	if (g_Player[id][g_SkillPath] != PATH_NONE)
	{
		new szPath[32];
		GetPathName(id, g_Player[id][g_Race], g_Player[id][g_SkillPath], szPath, charsmax(szPath));
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_AI_DEJA_CALEA", szPath);
		return;
	}
	
	new szRace[32];
	GetRaceName(id, g_Player[id][g_Race], szRace, charsmax(szRace));
	
	new title[64];
	formatex(title, charsmax(title), "\yAlege Calea - %s", szRace);
	
	new menu = menu_create(title, "path_handler");
	
	new tmp[48];
	GetPathName(id, g_Player[id][g_Race], 1, tmp, charsmax(tmp));
	menu_additem(menu, tmp, "1");
	
	GetPathName(id, g_Player[id][g_Race], 2, tmp, charsmax(tmp));
	menu_additem(menu, tmp, "2");
	
	menu_display(id, menu);
}

public path_handler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new data[6];
	new access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), _, _, callback);
	
	new path = str_to_num(data);
	g_Player[id][g_SkillPath] = path;
	
	new szPath[32];
	GetPathName(id, g_Player[id][g_Race], path, szPath, charsmax(szPath));
	client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_AI_ALES_CALEA", szPath);
	
	save_player(id);
	
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public cmd_stats(id)
{
	if (g_Player[id][g_Race] == RACE_NONE)
	{
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_ALEGE_MAI_INTAI");
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
	menu_additem(menu, fmt("%L", id, "INAPOI"), "0");
	
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
	
	new data[6];
	new access, callback;
	menu_item_getinfo(menu, item, access, data, charsmax(data), _, _, callback);
	
	new key = str_to_num(data);
	menu_destroy(menu);
	
	if (key == 0)
	{
		cmd_menu(id);
		return PLUGIN_HANDLED;
	}
	
	if (g_Player[id][g_StatPoints] <= 0)
	{
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_NU_AI_PUNCTE");
		cmd_stats(id);
		return PLUGIN_HANDLED;
	}
	
	g_Player[id][g_StatPoints]--;
	
	switch (key)
	{
		case 1: g_Player[id][g_STR]++;
		case 2: g_Player[id][g_HP]++;
		case 3: g_Player[id][g_DEX]++;
		case 4: g_Player[id][g_INT]++;
	}
	
	recalc_max_mp(id);
	client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_PUNCT_ALOCAT");
	save_player(id);
	
	// Forward
	new ret;
	ExecuteForward(g_fwd_StatAllocated, ret, id, key);
	
	cmd_stats(id); // re-open menu (nu se inchide)
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

public cmd_skills(id)
{
	if (g_Player[id][g_Race] == RACE_NONE)
	{
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_ALEGE_MAI_INTAI");
		return PLUGIN_HANDLED;
	}
	
	if (g_Player[id][g_SkillPath] == PATH_NONE)
	{
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_ALEGE_MAI_INTAI_2");
		show_path_menu(id);
		return PLUGIN_HANDLED;
	}
	
	new race = g_Player[id][g_Race];
	new path = g_Player[id][g_SkillPath];
	new start = (race - 1) * 10 + (path - 1) * 5;
	
	new szRace[32], szPath[32];
	GetRaceName(id, race, szRace, charsmax(szRace));
	GetPathName(id, race, path, szPath, charsmax(szPath));
	
	new title[80];
	formatex(title, charsmax(title), "\ySkill-uri %s (%s) - Puncte: %d", 
		szRace, szPath, g_Player[id][g_SkillPoints]);
	
	new menu = menu_create(title, "skills_handler");
	
	for (new i = 0; i < 5; i++)
	{
		new lvl = g_Player[id][g_SkillLevel][start + i];
		new rank[16];
		get_skill_rank(lvl, rank, charsmax(rank));
		
		new szSkill[48];
		GetSkillName(id, start + i, szSkill, charsmax(szSkill));
		
		new tmp[64];
		formatex(tmp, charsmax(tmp), "%s [%s]", szSkill, rank);
		
		new info[8];
		formatex(info, charsmax(info), "%d", start + i);
		menu_additem(menu, tmp, info);
	}
	menu_additem(menu, fmt("%L", id, "INAPOI"), "999");
	
	menu_display(id, menu);
	return PLUGIN_HANDLED;
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
	menu_destroy(menu);
	
	if (skill_idx == 999)          // ← schimbat din 0
	{
		cmd_menu(id);
		return PLUGIN_HANDLED;
	}
	
	if (g_Player[id][g_SkillPoints] <= 0)
	{
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_NU_AI_PUNCTE_2");
		cmd_skills(id);
		return PLUGIN_HANDLED;
	}
	
	if (g_Player[id][g_SkillLevel][skill_idx] >= 40)
	{
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_SKILL_DEJA_PERFECT");
		cmd_skills(id);
		return PLUGIN_HANDLED;
	}
	
	g_Player[id][g_SkillLevel][skill_idx]++;
	g_Player[id][g_SkillPoints]--;
	
	new rank[16];
	get_skill_rank(g_Player[id][g_SkillLevel][skill_idx], rank, charsmax(rank));
	
	new szSkill[48];
	GetSkillName(id, skill_idx, szSkill, charsmax(szSkill));
	client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2", szSkill, rank);
	
	save_player(id);
	
	new ret;
	ExecuteForward(g_fwd_SkillLearned, ret, id, skill_idx, g_Player[id][g_SkillLevel][skill_idx]);
	
	cmd_skills(id); // re-open
	return PLUGIN_HANDLED;
}


// Inventar, Upgrade, Shop, Binds

public cmd_inventar(id)
{
	new menu = menu_create(fmt("%L", id, "INVENTAR_ECHIPAMENT"), "inv_handler");
	menu_additem(menu, fmt("%L", id, "VEZI_ECHIPAMENT_CURENT"), "1");
	menu_additem(menu, fmt("%L", id, "ECHIPEAZA_DIN_INVENTAR"), "2");
	menu_additem(menu, fmt("%L", id, "DEZBRACA_SLOT"), "3");
	menu_additem(menu, fmt("%L", id, "FOLOSESTE_LICHIOR_HP_MP"), "4");
	menu_additem(menu, fmt("%L", id, "INAPOI"), "0");
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
	new key = str_to_num(data);
	menu_destroy(menu);
	
	switch (key)
	{
		case 0: cmd_menu(id);
		case 1: client_equipment_motd(id); //cmd_inventar(id); // re-open after MOTD
		case 2: show_equip_from_inv(id);
		case 3: show_unequip(id);
		case 4: use_potion_menu(id);
	}
	
	return PLUGIN_HANDLED;
}

public client_equipment_motd(id)
{
    static motd[1024];
    new len = 0;

    // Header
    len = formatex(motd[len], charsmax(motd) - len,
        "<html><body bgcolor=#1a1a1a text=#e0e0e0 style='font-family:Arial;font-size:13px;margin:8px'>");
    
    len += formatex(motd[len], charsmax(motd) - len,
        "<b style='color:#4fc3f7;font-size:15px'>[Metin2] Echipament</b><br><br>");

    // Arma
    len += formatex(motd[len], charsmax(motd) - len,
        "<b style='color:#81c784'>Arma:</b> %s <span style='color:#ffd54f'>+%d</span><br>",
        get_item_name(g_Player[id][g_Equipped][SLOT_WEAPON]),
        g_Player[id][g_EquippedUpgrade][SLOT_WEAPON]);

    // Armura
    len += formatex(motd[len], charsmax(motd) - len,
        "<b style='color:#81c784'>Armura:</b> %s <span style='color:#ffd54f'>+%d</span><br>",
        get_item_name(g_Player[id][g_Equipped][SLOT_ARMOR]),
        g_Player[id][g_EquippedUpgrade][SLOT_ARMOR]);

    // Coif
    len += formatex(motd[len], charsmax(motd) - len,
        "<b style='color:#81c784'>Coif:</b> %s <span style='color:#ffd54f'>+%d</span><br>",
        get_item_name(g_Player[id][g_Equipped][SLOT_HELMET]),
        g_Player[id][g_EquippedUpgrade][SLOT_HELMET]);

    // Scut
    len += formatex(motd[len], charsmax(motd) - len,
        "<b style='color:#81c784'>Scut:</b> %s <span style='color:#ffd54f'>+%d</span><br>",
        get_item_name(g_Player[id][g_Equipped][SLOT_SHIELD]),
        g_Player[id][g_EquippedUpgrade][SLOT_SHIELD]);

    // Papuci
    len += formatex(motd[len], charsmax(motd) - len,
        "<b style='color:#81c784'>Papuci:</b> %s <span style='color:#ffd54f'>+%d</span><br>",
        get_item_name(g_Player[id][g_Equipped][SLOT_SHOES]),
        g_Player[id][g_EquippedUpgrade][SLOT_SHOES]);

    // Bijuterie
    len += formatex(motd[len], charsmax(motd) - len,
        "<b style='color:#81c784'>Bijuterie:</b> %s <span style='color:#ffd54f'>+%d</span>",
        get_item_name(g_Player[id][g_Equipped][SLOT_JEWEL]),
        g_Player[id][g_EquippedUpgrade][SLOT_JEWEL]);

    // Închidere
    len += formatex(motd[len], charsmax(motd) - len, "</body></html>");

    show_motd(id, motd, "[Metin2] Echipament");
}

// Calculează STR total (base + iteme + upgrade)
stock get_total_str(id)
{
	new total = g_Player[id][g_STR];
	
	for (new i = 0; i < MAX_EQUIP_SLOTS; i++)
	{
		new itemid = g_Player[id][g_Equipped][i];
		if (itemid > 0 && itemid < g_ItemCount)
		{
			total += g_Items[itemid][ItemStr];
			total += g_Player[id][g_EquippedUpgrade][i];   // +1 per nivel de upgrade
		}
	}
	return total;
}

// Calculează HP Stat total (base + iteme + upgrade)
stock get_total_hp(id)
{
	new total = g_Player[id][g_HP];
	
	for (new i = 0; i < MAX_EQUIP_SLOTS; i++)
	{
		new itemid = g_Player[id][g_Equipped][i];
		if (itemid > 0 && itemid < g_ItemCount)
		{
			total += g_Items[itemid][ItemHp];
			total += g_Player[id][g_EquippedUpgrade][i] * 2;   // upgrade dă mai mult la HP
		}
	}
	return total;
}

// Calculează DEX total
stock get_total_dex(id)
{
	new total = g_Player[id][g_DEX];
	
	for (new i = 0; i < MAX_EQUIP_SLOTS; i++)
	{
		new itemid = g_Player[id][g_Equipped][i];
		if (itemid > 0 && itemid < g_ItemCount)
		{
			total += g_Items[itemid][ItemDex];
			total += g_Player[id][g_EquippedUpgrade][i];
		}
	}
	return total;
}

// Calculează INT total
stock get_total_int(id)
{
	new total = g_Player[id][g_INT];
	
	for (new i = 0; i < MAX_EQUIP_SLOTS; i++)
	{
		new itemid = g_Player[id][g_Equipped][i];
		if (itemid > 0 && itemid < g_ItemCount)
		{
			total += g_Items[itemid][ItemInt];
			total += g_Player[id][g_EquippedUpgrade][i];
		}
	}
	return total;
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
	new menu = menu_create(fmt("%L", id, "ALEGE_ITEM_DIN_INVENTAR"),"equip_handler");
	
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
	menu_additem(menu, fmt("%L", id, "INAPOI"), "999");
	
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
	menu_destroy(menu);
	
	if (inv_slot == 999)
	{
		cmd_inventar(id);
		return PLUGIN_HANDLED;
	}
	
	new itemid = g_Player[id][g_Inventory][inv_slot];
	new upg = g_Player[id][g_InventoryUpgrade][inv_slot];
	
	if (itemid <= 0 || itemid >= g_ItemCount)
	{
		show_equip_from_inv(id);
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
		show_equip_from_inv(id);
		return PLUGIN_HANDLED;
	}
	
	// --- SWAP LOGIC ---
	// Salvăm itemul vechi (dacă există) ca să-l punem înapoi în inventar
	new old_itemid = g_Player[id][g_Equipped][equip_slot];
	new old_upg    = g_Player[id][g_EquippedUpgrade][equip_slot];
	
	// 1. Scoatem itemul NOU din inventar (eliberează un slot)
	for (new i = inv_slot; i < g_Player[id][g_InventoryCount] - 1; i++)
	{
		g_Player[id][g_Inventory][i] = g_Player[id][g_Inventory][i + 1];
		g_Player[id][g_InventoryUpgrade][i] = g_Player[id][g_InventoryUpgrade][i + 1];
	}
	g_Player[id][g_Inventory][g_Player[id][g_InventoryCount] - 1] = 0;
	g_Player[id][g_InventoryUpgrade][g_Player[id][g_InventoryCount] - 1] = 0;
	g_Player[id][g_InventoryCount]--;
	
	// 2. Dacă exista un item vechi pe slot → îl punem în inventar (acum avem loc sigur)
	if (old_itemid > 0 && old_itemid < g_ItemCount)
	{
		// Forward pentru dezechipare
		new ret_unequip;
		ExecuteForward(g_fwd_ItemUnequipped, ret_unequip, id, old_itemid, equip_slot);
		
		new idx = g_Player[id][g_InventoryCount];
		g_Player[id][g_Inventory][idx] = old_itemid;
		g_Player[id][g_InventoryUpgrade][idx] = old_upg;
		g_Player[id][g_InventoryCount]++;
	}
	
	// 3. Echipăm itemul nou
	g_Player[id][g_Equipped][equip_slot] = itemid;
	g_Player[id][g_EquippedUpgrade][equip_slot] = upg;
	
	recalc_max_mp(id);
	
	if (old_itemid > 0)
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_AI_SCHIMBAT_CU", g_Items[old_itemid][ItemName], old_upg, g_Items[itemid][ItemName], upg);
	else
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_AI_ECHIPAT", g_Items[itemid][ItemName], upg);
	
	save_player(id);
	
	// Forward pentru echipare
	new ret;
	ExecuteForward(g_fwd_ItemEquipped, ret, id, itemid, equip_slot);
	
	show_equip_from_inv(id); // re-open
	return PLUGIN_HANDLED;
}

stock show_unequip(id)
{
	new menu = menu_create(fmt("%L", id, "DEZBRACA_SLOT_2"), "unequip_handler");
	menu_additem(menu, fmt("%L", id, "ARMA"), "0");
	menu_additem(menu, fmt("%L", id, "ARMURA"), "1");
	menu_additem(menu, fmt("%L", id, "COIF"), "2");
	menu_additem(menu, fmt("%L", id, "SCUT"), "3");
	menu_additem(menu, fmt("%L", id, "PAPUCI"), "4");
	menu_additem(menu, fmt("%L", id, "BIJUTERIE"), "5");
	menu_additem(menu, fmt("%L", id, "INAPOI"), "999");
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
	menu_destroy(menu);
	
	if (slot == 999)
	{
		cmd_inventar(id);
		return PLUGIN_HANDLED;
	}
	
	if (g_Player[id][g_Equipped][slot] == 0)
	{
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_SLOT_GOL");
		show_unequip(id);
		return PLUGIN_HANDLED;
	}
	
	if (g_Player[id][g_InventoryCount] >= MAX_INVENTORY)
	{
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_INVENTAR_PLIN");
		show_unequip(id);
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
	client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_ITEM_MUTAT_IN");
	save_player(id);
	
	// Forward
	new ret;
	ExecuteForward(g_fwd_ItemUnequipped, ret, id, itemid, slot);
	
	show_unequip(id); // re-open
	return PLUGIN_HANDLED;
}

stock use_potion_menu(id)
{
	new menu = menu_create(fmt("%L", id, "FOLOSESTE_LICHIOR"), "potion_handler");
	
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
	menu_additem(menu, fmt("%L", id, "INAPOI"), "999");
	
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
	menu_destroy(menu);
	
	if (inv_slot == 999)
	{
		cmd_inventar(id);
		return PLUGIN_HANDLED;
	}
	
	new itemid = g_Player[id][g_Inventory][inv_slot];
	
	if (itemid <= 0 || itemid >= g_ItemCount || g_Items[itemid][ItemType] != ITEM_POTION)
	{
		use_potion_menu(id);
		return PLUGIN_HANDLED;
	}
	
	new potion_type = g_Items[itemid][ItemPotionType];
	
	if (potion_type == 1) // HP
	{
		new hp = get_user_health(id);
		set_user_health(id, min(hp + 80, 100 + g_Player[id][g_HP] * 10 + 50));
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_AI_FOLOSIT_LICHIOR");
	}
	else if (potion_type == 2) // MP
	{
		g_Player[id][g_MP] = min(g_Player[id][g_MP] + 60, g_Player[id][g_MaxMP]);
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_AI_FOLOSIT_LICHIOR_2");
	}
	else // custom - fara efect predefinit, tratat de un plugin extern prin forward-ul m2_item_used
	{
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_AI_FOLOSIT", g_Items[itemid][ItemName]);
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
	
	// Forward
	new ret;
	ExecuteForward(g_fwd_ItemUsed, ret, id, itemid, potion_type);
	
	save_player(id);
	use_potion_menu(id); // re-open
	return PLUGIN_HANDLED;
}

public cmd_upgrade(id)
{
	new menu = menu_create(fmt("%L", id, "FIERAR_UPGRADE_ITEM"), "upgrade_menu_handler");
	
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
	menu_additem(menu, fmt("%L", id, "INAPOI"), "999");
	
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
	menu_destroy(menu);
	
	if (inv_slot == 999)
	{
		cmd_menu(id);
		return PLUGIN_HANDLED;
	}
	
	new upg = g_Player[id][g_InventoryUpgrade][inv_slot];
	new cost = 1000 * (upg + 1) * (upg + 1);
	
	if (g_Player[id][g_Yang] < cost)
	{
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_NU_AI_DESTUL", cost);
		cmd_upgrade(id);
		return PLUGIN_HANDLED;
	}
	
	g_Player[id][g_Yang] -= cost;
	
	new chance;
	new bool:forced = g_ForceUpgrade[id];

	if (forced)
	{
		chance = 100;
		g_ForceUpgrade[id] = false; // se consuma la aceasta incercare, indiferent de rezultat
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_PERGAMENTUL_BINECUVANTARII_ACTIV");
	}
	else if (upg < 6) chance = 85 - (upg * 5);
	else if (upg == 6) chance = 50;
	else if (upg == 7) chance = 30;
	else chance = 15;
	
	new itemid = g_Player[id][g_Inventory][inv_slot];
	
	if (random_num(1, 100) <= chance)
	{
		g_Player[id][g_InventoryUpgrade][inv_slot]++;
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_SUCCES_ITEM", g_Player[id][g_InventoryUpgrade][inv_slot]);
		
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
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_FIERARUL_SPART_ITEMUL");
		}
		else
		{
			if (upg > 0) g_Player[id][g_InventoryUpgrade][inv_slot]--;
			client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_ESEC_NIVEL_SCAZUT");
		}
		
		// Forward fail
		new ret;
		ExecuteForward(g_fwd_UpgradeFail, ret, id, itemid, destroyed);
	}

	save_player(id);
	cmd_upgrade(id); // re-open (nu se inchide)
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
	menu_additem(menu, fmt("%L", id, "INAPOI"), "0");
	
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
	menu_destroy(menu);
	
	if (itemid == 0)
	{
		cmd_menu(id);
		return PLUGIN_HANDLED;
	}
	
	if (itemid <= 0 || itemid >= g_ItemCount)
	{
		cmd_shop(id);
		return PLUGIN_HANDLED;
	}
	
	if (g_Player[id][g_InventoryCount] >= MAX_INVENTORY)
	{
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_INVENTAR_PLIN");
		cmd_shop(id);
		return PLUGIN_HANDLED;
	}
	
	new price = g_Items[itemid][ItemPrice];
	if (g_Player[id][g_Yang] < price)
	{
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_YANG_INSUFICIENT");
		cmd_shop(id);
		return PLUGIN_HANDLED;
	}
	
	g_Player[id][g_Yang] -= price;
	
	new idx = g_Player[id][g_InventoryCount];
	g_Player[id][g_Inventory][idx] = itemid;
	g_Player[id][g_InventoryUpgrade][idx] = 0;
	g_Player[id][g_InventoryCount]++;
	
	client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_AI_CUMPARAT", g_Items[itemid][ItemName]);
	
	// Forward
	new ret;
	ExecuteForward(g_fwd_ItemBought, ret, id, itemid, price);
	
	save_player(id);
	cmd_shop(id); // re-open (nu se inchide)
	return PLUGIN_HANDLED;
}

public cmd_status_motd(id)
{
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;
	
	if (g_Player[id][g_Race] == RACE_NONE)
	{
		client_print_color(id, print_team_default, "%L", id, "METIN2_METIN2_ALEGE_MAI_INTAI_3");
		return PLUGIN_HANDLED;
	}
	
	static motd[1536];
	new name[32];
	get_user_name(id, name, charsmax(name));
	new needed = get_xp_needed(g_Player[id][g_Level]);
	
	// Copiem numele itemelor in buffere locale (get_item_name e static)
	new wpn[32], arm[32], hlm[32], shd[32], sho[32], jwl[32];
	copy(wpn, charsmax(wpn), get_item_name(g_Player[id][g_Equipped][SLOT_WEAPON]));
	copy(arm, charsmax(arm), get_item_name(g_Player[id][g_Equipped][SLOT_ARMOR]));
	copy(hlm, charsmax(hlm), get_item_name(g_Player[id][g_Equipped][SLOT_HELMET]));
	copy(shd, charsmax(shd), get_item_name(g_Player[id][g_Equipped][SLOT_SHIELD]));
	copy(sho, charsmax(sho), get_item_name(g_Player[id][g_Equipped][SLOT_SHOES]));
	copy(jwl, charsmax(jwl), get_item_name(g_Player[id][g_Equipped][SLOT_JEWEL]));
	
	new szRace[32];
	GetRaceName(id, g_Player[id][g_Race], szRace, charsmax(szRace));
	
	// Culori luminoase, contrast bun pe fundal inchis
	formatex(motd, charsmax(motd),
		"<html><body bgcolor=#0a0a12 text=#ffffff style='font:13px Arial;margin:6px'>\
		<b style='color:#ffd700'>[Metin2] Status</b><br>\
		<font color=#00e5ff>%s</font> | <font color=#b39ddb>%s</font> | Lv <font color=#ffeb3b>%d</font><br>\
		XP: <font color=#81c784>%d</font>/%d | Yang: <font color=#ffd54f>%d</font><br>\
		MP: <font color=#64b5f6>%d</font>/%d | SP: %d | SkP: %d<br>\
		STR:<font color=#ef5350>%d</font> HP:<font color=#ef5350>%d</font> DEX:<font color=#ef5350>%d</font> INT:<font color=#ef5350>%d</font><br><br>\
		<b style='color:#69f0ae'>Echipament</b><br>\
		Arma: <font color=#fff59d>%s</font> <font color=#ffab40>+%d</font><br>\
		Armura: <font color=#fff59d>%s</font> <font color=#ffab40>+%d</font><br>\
		Coif: <font color=#fff59d>%s</font> <font color=#ffab40>+%d</font><br>\
		Scut: <font color=#fff59d>%s</font> <font color=#ffab40>+%d</font><br>\
		Papuci: <font color=#fff59d>%s</font> <font color=#ffab40>+%d</font><br>\
		Bijuterie: <font color=#fff59d>%s</font> <font color=#ffab40>+%d</font>\
		</body></html>",
		name,
		szRace,
		g_Player[id][g_Level],
		g_Player[id][g_XP], needed,
		g_Player[id][g_Yang],
		g_Player[id][g_MP], g_Player[id][g_MaxMP],
		g_Player[id][g_StatPoints], g_Player[id][g_SkillPoints],
		get_total_str(id), get_total_hp(id), get_total_dex(id), get_total_int(id),
		wpn, g_Player[id][g_EquippedUpgrade][SLOT_WEAPON],
		arm, g_Player[id][g_EquippedUpgrade][SLOT_ARMOR],
		hlm, g_Player[id][g_EquippedUpgrade][SLOT_HELMET],
		shd, g_Player[id][g_EquippedUpgrade][SLOT_SHIELD],
		sho, g_Player[id][g_EquippedUpgrade][SLOT_SHOES],
		jwl, g_Player[id][g_EquippedUpgrade][SLOT_JEWEL]
	);
	
	show_motd(id, motd, "[Metin2] Status");
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
