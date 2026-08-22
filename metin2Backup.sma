#include <amxmodx>
#include <nvault>
#include <nvault_array>
#include <metin2_api>

#define PLUGIN "M2 BackupLevel"
#define VERSION "1.3"
#define AUTHOR "Andrew"

#define VAULT_NAME "m2_backupvault"

// indecsi in array-ul salvat
enum
{
	B_LEVEL = 0,
	B_XP,
	B_YANG,
	B_RACE,
	B_STR,
	B_HP,
	B_DEX,
	B_INT,
	B_MP,
	B_MAXMP,
	B_SIZE
};

new g_vault;
new g_menuRestore;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_clcmd("say /check", "cmdCheck");
	register_clcmd("say /restore", "cmdRestore");

	g_vault = nvault_open(VAULT_NAME);
	if (g_vault == INVALID_HANDLE)
		set_fail_state("Nu pot deschide vaultul %s", VAULT_NAME);

	g_menuRestore = menu_create("Confirmare Restore", "handlerRestoreMenu");
	menu_additem(g_menuRestore, "Da", "1");
	menu_additem(g_menuRestore, "Nu", "2");
}

public plugin_end()
{
	if (g_vault != INVALID_HANDLE)
		nvault_close(g_vault);
}

// ======================== FORWARD M2 ========================

public m2_level_up(id, new_level)
{
	if (!is_user_connected(id))
		return;

	new key[64];
	getVaultKey(id, key, charsmax(key));

	new stored_level = getStoredLevel(key);

	if (new_level < stored_level)
		return; // nu suprascriem cu un level mai mic / corupt

	saveBackup(id, key);
}

// ======================== COMENZI ========================

public cmdCheck(id)
{
	new key[64];
	getVaultKey(id, key, charsmax(key));

	new data[B_SIZE];
	if (!nvault_get_array(g_vault, key, data, B_SIZE))
	{
		motdNoBackup(id);
		return PLUGIN_HANDLED;
	}

	motdCheck(id, data);

	return PLUGIN_HANDLED;
}

public cmdRestore(id)
{
	new key[64];
	getVaultKey(id, key, charsmax(key));

	new data[B_SIZE];
	if (!nvault_get_array(g_vault, key, data, B_SIZE))
	{
		motdNoBackup(id);
		return PLUGIN_HANDLED;
	}

	new current_level = get_user_m2_level(id);
	if (data[B_LEVEL] < current_level)
	{
		motdRestoreBlocked(id, data[B_LEVEL], current_level);
		return PLUGIN_HANDLED;
	}

	menu_display(id, g_menuRestore, 0);

	return PLUGIN_HANDLED;
}

public handlerRestoreMenu(id, menu, item)
{
	if (item == MENU_EXIT)
		return PLUGIN_HANDLED;

	new access, callback;
	new szData[6];
	menu_item_getinfo(menu, item, access, szData, charsmax(szData), _, _, callback);

	new choice = str_to_num(szData);

	if (choice == 2)
	{
		motdRestoreCancelled(id);
		return PLUGIN_HANDLED;
	}

	new key[64];
	getVaultKey(id, key, charsmax(key));

	new data[B_SIZE];
	if (!nvault_get_array(g_vault, key, data, B_SIZE))
	{
		motdNoBackup(id);
		return PLUGIN_HANDLED;
	}

	new current_level = get_user_m2_level(id);
	if (data[B_LEVEL] < current_level)
	{
		motdRestoreBlocked(id, data[B_LEVEL], current_level);
		return PLUGIN_HANDLED;
	}

	set_user_m2_level(id, data[B_LEVEL]);
	set_user_m2_xp(id, data[B_XP]);
	set_user_m2_yang(id, data[B_YANG]);
	set_user_m2_race(id, data[B_RACE]);
	set_user_m2_str(id, data[B_STR]);
	set_user_m2_hp(id, data[B_HP]);
	set_user_m2_dex(id, data[B_DEX]);
	set_user_m2_int(id, data[B_INT]);
	set_user_m2_maxmp(id, data[B_MAXMP]);
	set_user_m2_mp(id, data[B_MP]);

	motdRestoreSuccess(id, data[B_LEVEL]);

	return PLUGIN_HANDLED;
}

// ======================== HELPERE ========================

getVaultKey(id, output[], len)
{
	new name[32];
	get_user_name(id, name, charsmax(name));
	formatex(output, len, "m2bck_%s", name);
}

getStoredLevel(const key[])
{
	new data[B_SIZE];
	if (!nvault_get_array(g_vault, key, data, B_SIZE))
		return 0;

	return data[B_LEVEL];
}

saveBackup(id, const key[])
{
	new data[B_SIZE];

	data[B_LEVEL] = get_user_m2_level(id);
	data[B_XP]    = get_user_m2_xp(id);
	data[B_YANG]  = get_user_m2_yang(id);
	data[B_RACE]  = get_user_m2_race(id);
	data[B_STR]   = get_user_m2_str(id);
	data[B_HP]    = get_user_m2_hp(id);
	data[B_DEX]   = get_user_m2_dex(id);
	data[B_INT]   = get_user_m2_int(id);
	data[B_MP]    = get_user_m2_mp(id);
	data[B_MAXMP] = get_user_m2_maxmp(id);

	nvault_set_array(g_vault, key, data, B_SIZE);
}

// ======================== MOTD ========================

stock showBackupMotd(id, const title[], const body[])
{
	show_motd(id, body, title);
}

stock motdNoBackup(id)
{
	new body[512];
	formatex(body, charsmax(body),
		"<body bgcolor='#1a1a1a'><font color='#e0e0e0' face='Tahoma' size='3'>^n\
		<font color='#ff5555'><b>Niciun backup gasit</b></font><br><br>\
		Nu ai niciun backup salvat momentan.<br>\
		Backup-ul se creeaza automat cand faci level up.\
		</font></body>");

	showBackupMotd(id, "BackupLevel", body);
}

stock motdCheck(id, data[B_SIZE])
{
	new body[1024];
	formatex(body, charsmax(body),
		"<body bgcolor='#1a1a1a'><font color='#e0e0e0' face='Tahoma' size='3'>^n\
		<font color='#55aaff'><b>Backup salvat</b></font><br><br>\
		<table border='0' cellpadding='3'>\
		<tr><td>Level</td><td><b>%d</b></td></tr>\
		<tr><td>XP</td><td>%d</td></tr>\
		<tr><td>Yang</td><td>%d</td></tr>\
		<tr><td>Rasa</td><td>%d</td></tr>\
		<tr><td>STR</td><td>%d</td></tr>\
		<tr><td>HP</td><td>%d</td></tr>\
		<tr><td>DEX</td><td>%d</td></tr>\
		<tr><td>INT</td><td>%d</td></tr>\
		<tr><td>MP</td><td>%d / %d</td></tr>\
		</table>\
		</font></body>",
		data[B_LEVEL], data[B_XP], data[B_YANG], data[B_RACE],
		data[B_STR], data[B_HP], data[B_DEX], data[B_INT],
		data[B_MP], data[B_MAXMP]);

	showBackupMotd(id, "BackupLevel - /check", body);
}

stock motdRestoreBlocked(id, backupLevel, currentLevel)
{
	new body[512];
	formatex(body, charsmax(body),
		"<body bgcolor='#1a1a1a'><font color='#e0e0e0' face='Tahoma' size='3'>^n\
		<font color='#ff5555'><b>Restore anulat</b></font><br><br>\
		Backup-ul salvat (Level <b>%d</b>) este mai mic decat level-ul tau curent (Level <b>%d</b>).<br>\
		Restore-ul a fost blocat pentru a preveni pierderea progresului.\
		</font></body>",
		backupLevel, currentLevel);

	showBackupMotd(id, "BackupLevel - Restore", body);
}

stock motdRestoreCancelled(id)
{
	new body[256];
	formatex(body, charsmax(body),
		"<body bgcolor='#1a1a1a'><font color='#e0e0e0' face='Tahoma' size='3'>^n\
		<font color='#ffaa00'><b>Restore anulat</b></font><br><br>\
		Ai ales sa nu restaurezi backup-ul.\
		</font></body>");

	showBackupMotd(id, "BackupLevel - Restore", body);
}

stock motdRestoreSuccess(id, level)
{
	new body[512];
	formatex(body, charsmax(body),
		"<body bgcolor='#1a1a1a'><font color='#e0e0e0' face='Tahoma' size='3'>^n\
		<font color='#55ff55'><b>Restore reusit</b></font><br><br>\
		Ai fost restaurat cu succes la Level <b>%d</b>.\
		</font></body>",
		level);

	showBackupMotd(id, "BackupLevel - Restore", body);
}
