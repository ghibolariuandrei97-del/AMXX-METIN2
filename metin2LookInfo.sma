#include <amxmodx>
#include <reapi>
#include <metin2_api>

#define PLUGIN_NAME    "Metin2LookInfo"
#define PLUGIN_VERSION "1.0"
#define PLUGIN_AUTHOR  "Craxor"

new g_msgStatusText;
new g_msgStatusValue;
new g_iAimingAt[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

	g_msgStatusText  = get_user_msgid("StatusText");
	g_msgStatusValue = get_user_msgid("StatusValue");

	// Hook pe UpdateClientData pentru procesare la fiecare frame/update de pozitie
	RegisterHookChain(RG_CBasePlayer_UpdateClientData, "OnUpdateClientData_Post", true);
}

public client_disconnected(id)
{
	g_iAimingAt[id] = 0;
}

public OnUpdateClientData_Post(const id)
{
	if (!is_user_alive(id) || is_user_bot(id))
	{
		if (g_iAimingAt[id])
		{
			g_iAimingAt[id] = 0;
			UTIL_ClearStatus(id);
		}
		return;
	}

	new target, body;
	get_user_aiming(id, target, body, 1000);

	if (!is_user_alive(target) || target == id)
	{
		if (g_iAimingAt[id])
		{
			g_iAimingAt[id] = 0;
			UTIL_ClearStatus(id);
		}
		return;
	}

	g_iAimingAt[id] = target;

	// === Date Metin2 ===
	new race  = get_user_m2_race(target);
	new level = get_user_m2_level(target);
	new mp    = get_user_m2_mp(target);
	new maxmp = get_user_m2_maxmp(target);

	new race_name[24];
	m2_get_race_name(race, race_name, charsmax(race_name));

	new name[32];
	get_entvar(target, var_netname, name, charsmax(name));

	new hp = floatround(get_entvar(target, var_health));

	static szText[128];
	formatex(szText, charsmax(szText), "[%s lvl %d] %s  HP:%d  MP:%d/%d",
		race_name, level, name, hp, mp, maxmp);

	// Pasi obligatorii pentru a activa rendering-ul in clientul de CS:
	// 1. Trimitem StatusValue = 2 (trigger de inamic/target pentru ca motorul sa activeze randarea)
	UTIL_SendStatusValue(id, 2, target);
	
	// 2. Trimitem textul customizat de Metin2
	UTIL_SendStatusText(id, szText);
}

// Trimite StatusValue direct catre jucator
stock UTIL_SendStatusValue(const id, const iFlag, const iValue)
{
	message_begin(MSG_ONE_UNRELIABLE, g_msgStatusValue, .player = id);
	write_byte(iFlag);
	write_short(iValue);
	message_end();
}

// Trimite StatusText customizat
stock UTIL_SendStatusText(const id, const szText[])
{
	message_begin(MSG_ONE_UNRELIABLE, g_msgStatusText, .player = id);
	write_byte(0);
	write_string(szText);
	message_end();
}

// Curata tot de pe ecran cand muti tinta
stock UTIL_ClearStatus(const id)
{
	UTIL_SendStatusValue(id, 0, 0);
	UTIL_SendStatusText(id, "");
}
