#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>
#include <metin2_api>

#define PLUGIN_NAME    "Metin2 RPG - Events System"
#define PLUGIN_VERSION "1.1.0"
#define PLUGIN_AUTHOR  "Crax"

// ======================== CONSTANTS ========================
#define TASK_CHECK_EVENTS     55440
#define TASK_ANNOUNCE         55441
#define TASK_ABUNDANCE_END    55442
#define ANNOUNCE_INTERVAL     180.0   // every 3 minutes when an event is active

// ======================== GLOBALS ========================
new g_CvarEnable;
new g_CvarXpWeekend;
new g_CvarYangWeekend;
new g_CvarHappyStart;
new g_CvarHappyEnd;
new g_CvarXpHappy;
new g_CvarYangHappy;
new g_CvarXpNightStart;      // optional second window (night / late)
new g_CvarXpNightEnd;
new g_CvarXpNight;
new g_CvarYangNight;
new g_CvarAbundanceXp;
new g_CvarAbundanceYang;
new g_CvarAbundanceForceUpg;
new g_CvarAbundanceDuration; // minutes (0 = until map change)
new g_CvarAnnounce;
new g_CvarExtraYangLevel;    // bonus Yang on level-up during events
new g_CvarKillItemChance;    // % chance to give a free item on kill during Abundance
new g_CvarKillItemId;        // item ID to give (0 = disabled)

new bool:g_bAbundanceActive;
new g_iAbundanceEndTime;     // unix time when abundance ends (0 = map change)
new g_szMapAtAbundance[32];

new Float:g_flCurrentXpMult = 1.0;
new Float:g_flCurrentYangMult = 1.0;
new bool:g_bWeekendActive;
new bool:g_bHappyHourActive;
new bool:g_bNightActive;

new g_iMaxPlayers;

// ======================== PLUGIN INIT ========================
public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
	
	// Core enable
	g_CvarEnable             = register_cvar("amx_metin2_event_enable", "1");
	
	// Weekend (Sat + Sun)
	g_CvarXpWeekend          = register_cvar("amx_metin2_event_xp_weekend", "2.0");
	g_CvarYangWeekend        = register_cvar("amx_metin2_event_yang_weekend", "1.5");
	
	// Happy Hour window (24h format, inclusive start, exclusive end recommended)
	g_CvarHappyStart         = register_cvar("amx_metin2_event_happy_start", "18");
	g_CvarHappyEnd           = register_cvar("amx_metin2_event_happy_end", "22");
	g_CvarXpHappy            = register_cvar("amx_metin2_event_xp_happy", "1.5");
	g_CvarYangHappy          = register_cvar("amx_metin2_event_yang_happy", "1.5");
	
	// Optional Night / Late window (e.g. 00:00 - 06:00)
	g_CvarXpNightStart       = register_cvar("amx_metin2_event_night_start", "0");
	g_CvarXpNightEnd         = register_cvar("amx_metin2_event_night_end", "6");
	g_CvarXpNight            = register_cvar("amx_metin2_event_xp_night", "1.25");
	g_CvarYangNight          = register_cvar("amx_metin2_event_yang_night", "1.25");
	
	// Abundance Mode (admin forced)
	g_CvarAbundanceXp        = register_cvar("amx_metin2_event_abundance_xp", "3.0");
	g_CvarAbundanceYang      = register_cvar("amx_metin2_event_abundance_yang", "2.5");
	g_CvarAbundanceForceUpg  = register_cvar("amx_metin2_event_abundance_force_upgrade", "1");
	g_CvarAbundanceDuration  = register_cvar("amx_metin2_event_abundance_duration", "0"); // 0 = until map change
	
	// Misc
	g_CvarAnnounce           = register_cvar("amx_metin2_event_announce", "1");
	g_CvarExtraYangLevel     = register_cvar("amx_metin2_event_levelup_yang", "1000"); // extra Yang on level-up while any event active
	g_CvarKillItemChance     = register_cvar("amx_metin2_event_abundance_item_chance", "8"); // %
	g_CvarKillItemId         = register_cvar("amx_metin2_event_abundance_item_id", "0"); // set to a valid potion/weapon ID
	
	// Admin commands
	register_concmd("amx_abundance", "CmdAbundance", ADMIN_LEVEL_A, "<0|1|toggle> - Enable/Disable Abundance Mode for current map");
	register_concmd("amx_event_status", "CmdEventStatus", ADMIN_KICK, "- Show current event multipliers");
	register_clcmd("say /event", "CmdPlayerEvent");
	register_clcmd("say /events", "CmdPlayerEvent");
	register_clcmd("say /bonus", "CmdPlayerEvent");
	register_clcmd("say_team /event", "CmdPlayerEvent");
	
	g_iMaxPlayers = get_maxplayers();
	
	// Periodic check (every 30 seconds is enough for hour/day changes)
	set_task(30.0, "TaskCheckEvents", TASK_CHECK_EVENTS, _, _, "b");
	
	// Initial calculation
	RecalculateMultipliers();
	
	server_print("[Metin2 Events] Loaded v%s - Multipliers recalculated", PLUGIN_VERSION);
}

public plugin_cfg()
{
	// Make sure we start clean after configs are loaded
	RecalculateMultipliers();
}

public plugin_end()
{
	remove_task(TASK_CHECK_EVENTS);
	remove_task(TASK_ANNOUNCE);
	remove_task(TASK_ABUNDANCE_END);
}

// ======================== MAP CHANGE / ABUNDANCE RESET ========================
public server_changelevel(map[])
{
	// Called on map change in some engines; also handled by map name check
	ResetAbundance("Map change");
}

// ======================== EVENT CALCULATION ========================
public TaskCheckEvents()
{
	if (!get_pcvar_num(g_CvarEnable))
	{
		g_flCurrentXpMult = 1.0;
		g_flCurrentYangMult = 1.0;
		g_bWeekendActive = false;
		g_bHappyHourActive = false;
		g_bNightActive = false;
		return;
	}
	
	// Auto-end abundance if duration expired
	if (g_bAbundanceActive && g_iAbundanceEndTime > 0)
	{
		if (get_systime() >= g_iAbundanceEndTime)
		{
			ResetAbundance("Duration expired");
		}
	}
	
	// Detect map change for abundance (safety)
	if (g_bAbundanceActive)
	{
		static map[32];
		get_mapname(map, charsmax(map));
		if (!equal(map, g_szMapAtAbundance))
		{
			ResetAbundance("Map changed");
		}
	}
	
	RecalculateMultipliers();
}

RecalculateMultipliers()
{
	new Float:oldXp = g_flCurrentXpMult;
	new Float:oldYang = g_flCurrentYangMult;
	
	g_flCurrentXpMult = 1.0;
	g_flCurrentYangMult = 1.0;
	g_bWeekendActive = false;
	g_bHappyHourActive = false;
	g_bNightActive = false;
	
	if (!get_pcvar_num(g_CvarEnable))
		return;
	
	// ----- Day of week -----
	// %w = 0 (Sunday) ... 6 (Saturday)
	static dayStr[4];
	get_time("%w", dayStr, charsmax(dayStr));
	new weekday = str_to_num(dayStr);
	
	if (weekday == 0 || weekday == 6) // Sunday or Saturday
	{
		g_bWeekendActive = true;
		g_flCurrentXpMult   *= get_pcvar_float(g_CvarXpWeekend);
		g_flCurrentYangMult *= get_pcvar_float(g_CvarYangWeekend);
	}
	
	// ----- Hour windows -----
	static hourStr[4];
	get_time("%H", hourStr, charsmax(hourStr));
	new hour = str_to_num(hourStr);
	
	new happyStart = get_pcvar_num(g_CvarHappyStart);
	new happyEnd   = get_pcvar_num(g_CvarHappyEnd);
	
	if (IsHourInRange(hour, happyStart, happyEnd))
	{
		g_bHappyHourActive = true;
		g_flCurrentXpMult   *= get_pcvar_float(g_CvarXpHappy);
		g_flCurrentYangMult *= get_pcvar_float(g_CvarYangHappy);
	}
	
	new nightStart = get_pcvar_num(g_CvarXpNightStart);
	new nightEnd   = get_pcvar_num(g_CvarXpNightEnd);
	
	if (IsHourInRange(hour, nightStart, nightEnd))
	{
		g_bNightActive = true;
		g_flCurrentXpMult   *= get_pcvar_float(g_CvarXpNight);
		g_flCurrentYangMult *= get_pcvar_float(g_CvarYangNight);
	}
	
	// ----- Abundance overrides / stacks -----
	if (g_bAbundanceActive)
	{
		g_flCurrentXpMult   *= get_pcvar_float(g_CvarAbundanceXp);
		g_flCurrentYangMult *= get_pcvar_float(g_CvarAbundanceYang);
	}
	
	// Clamp to sane values
	if (g_flCurrentXpMult < 0.1)   g_flCurrentXpMult = 0.1;
	if (g_flCurrentYangMult < 0.1) g_flCurrentYangMult = 0.1;
	if (g_flCurrentXpMult > 20.0)  g_flCurrentXpMult = 20.0;
	if (g_flCurrentYangMult > 20.0) g_flCurrentYangMult = 20.0;
	
	// Announce if multipliers changed significantly and announcements are on
	if (get_pcvar_num(g_CvarAnnounce))
	{
		if (floatabs(g_flCurrentXpMult - oldXp) > 0.05 || floatabs(g_flCurrentYangMult - oldYang) > 0.05)
		{
			AnnounceCurrentEvents(true);
		}
		
		// Keep a repeating soft announce while any bonus is active
		if (g_flCurrentXpMult > 1.01 || g_flCurrentYangMult > 1.01 || g_bAbundanceActive)
		{
			if (!task_exists(TASK_ANNOUNCE))
				set_task(ANNOUNCE_INTERVAL, "TaskAnnounce", TASK_ANNOUNCE, _, _, "b");
		}
		else
		{
			remove_task(TASK_ANNOUNCE);
		}
	}
}

bool:IsHourInRange(hour, start, end)
{
	// Handles normal ranges (18-22) and overnight (22-6)
	if (start == end)
		return false; // disabled
	
	if (start < end)
		return (hour >= start && hour < end);
	else
		return (hour >= start || hour < end);
}

// ======================== KILL FORWARD - APPLY MULTIPLIERS ========================
public m2_player_kill(killer, victim, xp, yang)
{
	if (!get_pcvar_num(g_CvarEnable))
		return;
	
	if (!is_user_connected(killer) || killer < 1 || killer > g_iMaxPlayers)
		return;
	
	// Apply extra XP / Yang based on current multiplier
	// Core already gave the base amount → we add the surplus
	if (g_flCurrentXpMult > 1.0 && xp > 0)
	{
		new extra_xp = floatround(float(xp) * (g_flCurrentXpMult - 1.0));
		if (extra_xp > 0)
			m2_add_xp(killer, extra_xp);
	}
	
	if (g_flCurrentYangMult > 1.0 && yang > 0)
	{
		new extra_yang = floatround(float(yang) * (g_flCurrentYangMult - 1.0));
		if (extra_yang > 0)
			m2_add_yang(killer, extra_yang);
	}
	
	// Abundance: small chance to drop a free item
	if (g_bAbundanceActive)
	{
		new itemId = get_pcvar_num(g_CvarKillItemId);
		new chance = get_pcvar_num(g_CvarKillItemChance);
		
		if (itemId > 0 && chance > 0 && random_num(1, 100) <= chance)
		{
			if (m2_give_item(killer, itemId, 0))
			{
				static name[64];
				m2_get_item_name(itemId, name, charsmax(name));
				client_print_color(killer, print_team_default, "^4[Metin2 Events]^1 Abundance drop: ^3%s^1!", name);
			}
		}
		
		// Optional force next upgrade success while Abundance is active
		if (get_pcvar_num(g_CvarAbundanceForceUpg))
		{
			m2_set_force_upgrade(killer, true);
		}
	}
}

// ======================== LEVEL UP BONUS ========================
public m2_level_up(id, new_level)
{
	if (!get_pcvar_num(g_CvarEnable) || !is_user_connected(id))
		return;
	
	if (g_flCurrentXpMult <= 1.0 && g_flCurrentYangMult <= 1.0 && !g_bAbundanceActive)
		return;
	
	new bonus = get_pcvar_num(g_CvarExtraYangLevel);
	if (bonus > 0)
	{
		m2_add_yang(id, bonus);
		client_print_color(id, print_team_default, "^4[Metin2 Events]^1 Level ^3%d^1! Event bonus: ^3+%d Yang^1.", new_level, bonus);
	}
}

// ======================== ABUNDANCE MODE ========================
public CmdAbundance(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;
	
	new arg[8];
	read_argv(1, arg, charsmax(arg));
	
	new bool:enable;
	
	if (arg[0] == 0 || equal(arg, "toggle") || equal(arg, "t"))
	{
		enable = !g_bAbundanceActive;
	}
	else
	{
		enable = bool:(str_to_num(arg) != 0);
	}
	
	if (enable)
	{
		ActivateAbundance(id);
	}
	else
	{
		ResetAbundance("Admin disabled");
		console_print(id, "[Metin2 Events] Abundance Mode DISABLED.");
		client_print_color(0, print_team_default, "^4[Metin2 Events]^1 Abundance Mode has been ^3disabled^1 by an admin.");
	}
	
	return PLUGIN_HANDLED;
}

ActivateAbundance(admin = 0)
{
	g_bAbundanceActive = true;
	get_mapname(g_szMapAtAbundance, charsmax(g_szMapAtAbundance));
	
	new duration = get_pcvar_num(g_CvarAbundanceDuration);
	if (duration > 0)
	{
		g_iAbundanceEndTime = get_systime() + (duration * 60);
		set_task(float(duration * 60), "TaskAbundanceEnd", TASK_ABUNDANCE_END);
	}
	else
	{
		g_iAbundanceEndTime = 0;
		remove_task(TASK_ABUNDANCE_END);
	}
	
	RecalculateMultipliers();
	
	static adminName[32];
	if (admin > 0 && is_user_connected(admin))
		get_user_name(admin, adminName, charsmax(adminName));
	else
		copy(adminName, charsmax(adminName), "CONSOLE");
	
	client_print_color(0, print_team_default, "^4[Metin2 Events]^1 ^3ABUNDANCE MODE^1 activated by ^3%s^1!", adminName);
	client_print_color(0, print_team_default, "^4[Metin2 Events]^1 XP x^3%.2f^1 | Yang x^3%.2f^1%s",
		g_flCurrentXpMult, g_flCurrentYangMult,
		get_pcvar_num(g_CvarAbundanceForceUpg) ? " | Force Upgrade ON" : "");
	
	if (duration > 0)
		client_print_color(0, print_team_default, "^4[Metin2 Events]^1 Duration: ^3%d minutes^1.", duration);
	else
		client_print_color(0, print_team_default, "^4[Metin2 Events]^1 Active until map change.");
	
	// Give force upgrade to all currently connected players if enabled
	if (get_pcvar_num(g_CvarAbundanceForceUpg))
	{
		for (new i = 1; i <= g_iMaxPlayers; i++)
		{
			if (is_user_connected(i) && !is_user_bot(i))
				m2_set_force_upgrade(i, true);
		}
	}
	
	log_amx("[Metin2 Events] Abundance activated by %s (XP x%.2f Yang x%.2f)", adminName, g_flCurrentXpMult, g_flCurrentYangMult);
}

public TaskAbundanceEnd()
{
	ResetAbundance("Duration expired");
}

ResetAbundance(const reason[])
{
	if (!g_bAbundanceActive)
		return;
	
	g_bAbundanceActive = false;
	g_iAbundanceEndTime = 0;
	g_szMapAtAbundance[0] = 0;
	remove_task(TASK_ABUNDANCE_END);
	
	RecalculateMultipliers();
	
	client_print_color(0, print_team_default, "^4[Metin2 Events]^1 Abundance Mode has ended (^3%s^1).", reason);
	log_amx("[Metin2 Events] Abundance ended: %s", reason);
}

// ======================== STATUS / PLAYER COMMANDS ========================
public CmdEventStatus(id, level, cid)
{
	if (!cmd_access(id, level, cid, 0))
		return PLUGIN_HANDLED;
	
	ShowEventStatus(id, true);
	return PLUGIN_HANDLED;
}

public CmdPlayerEvent(id)
{
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;
	
	ShowEventStatus(id, false);
	return PLUGIN_HANDLED;
}

ShowEventStatus(id, bool:detailed)
{
	static timeStr[32];
	get_time("%H:%M %d/%m/%Y", timeStr, charsmax(timeStr));
	
	client_print_color(id, print_team_default, "^4==========[ Metin2 Events ]==========");
	client_print_color(id, print_team_default, "^1Server time: ^3%s", timeStr);
	
	if (!get_pcvar_num(g_CvarEnable))
	{
		client_print_color(id, print_team_default, "^1Events system is currently ^3DISABLED^1.");
		return;
	}
	
	client_print_color(id, print_team_default, "^1Current XP Multiplier:   ^3x%.2f", g_flCurrentXpMult);
	client_print_color(id, print_team_default, "^1Current Yang Multiplier: ^3x%.2f", g_flCurrentYangMult);
	
	if (g_bWeekendActive)
		client_print_color(id, print_team_default, "^1• Weekend Bonus: ^3ACTIVE");
	if (g_bHappyHourActive)
		client_print_color(id, print_team_default, "^1• Happy Hour: ^3ACTIVE");
	if (g_bNightActive)
		client_print_color(id, print_team_default, "^1• Night Bonus: ^3ACTIVE");
	if (g_bAbundanceActive)
	{
		client_print_color(id, print_team_default, "^1• ^4ABUNDANCE MODE: ^3ACTIVE");
		if (g_iAbundanceEndTime > 0)
		{
			new remaining = g_iAbundanceEndTime - get_systime();
			if (remaining > 0)
				client_print_color(id, print_team_default, "^1  Time left: ^3%d min %d sec", remaining / 60, remaining % 60);
		}
		else
			client_print_color(id, print_team_default, "^1  Ends on: ^3map change");
	}
	
	if (g_flCurrentXpMult <= 1.01 && g_flCurrentYangMult <= 1.01 && !g_bAbundanceActive)
		client_print_color(id, print_team_default, "^1No active bonuses right now.");
	
	if (detailed)
	{
		client_print_color(id, print_team_default, "^1--- Config ---");
		client_print_color(id, print_team_default, "^1Weekend XP/Yang: x%.2f / x%.2f", get_pcvar_float(g_CvarXpWeekend), get_pcvar_float(g_CvarYangWeekend));
		client_print_color(id, print_team_default, "^1Happy Hour: %02d:00-%02d:00  (x%.2f / x%.2f)",
			get_pcvar_num(g_CvarHappyStart), get_pcvar_num(g_CvarHappyEnd),
			get_pcvar_float(g_CvarXpHappy), get_pcvar_float(g_CvarYangHappy));
		client_print_color(id, print_team_default, "^1Night: %02d:00-%02d:00  (x%.2f / x%.2f)",
			get_pcvar_num(g_CvarXpNightStart), get_pcvar_num(g_CvarXpNightEnd),
			get_pcvar_float(g_CvarXpNight), get_pcvar_float(g_CvarYangNight));
	}
	
	client_print_color(id, print_team_default, "^4====================================");
}

public TaskAnnounce()
{
	if (!get_pcvar_num(g_CvarAnnounce) || !get_pcvar_num(g_CvarEnable))
		return;
	
	if (g_flCurrentXpMult <= 1.01 && g_flCurrentYangMult <= 1.01 && !g_bAbundanceActive)
		return;
	
	AnnounceCurrentEvents(false);
}

AnnounceCurrentEvents(bool:force)
{
	static msg[192];
	
	if (g_bAbundanceActive)
	{
		formatex(msg, charsmax(msg), "^4[Metin2 Events]^1 ^3ABUNDANCE MODE^1 is active! XP ^3x%.2f^1 | Yang ^3x%.2f^1",
			g_flCurrentXpMult, g_flCurrentYangMult);
	}
	else if (g_bWeekendActive || g_bHappyHourActive || g_bNightActive)
	{
		new parts[128];
		parts[0] = 0;
		
		if (g_bWeekendActive)   add(parts, charsmax(parts), "Weekend ");
		if (g_bHappyHourActive) add(parts, charsmax(parts), "HappyHour ");
		if (g_bNightActive)     add(parts, charsmax(parts), "Night ");
		
		formatex(msg, charsmax(msg), "^4[Metin2 Events]^1 %sactive → XP ^3x%.2f^1 | Yang ^3x%.2f^1",
			parts, g_flCurrentXpMult, g_flCurrentYangMult);
	}
	else if (force)
	{
		formatex(msg, charsmax(msg), "^4[Metin2 Events]^1 Bonuses returned to normal (x1.0).");
	}
	else
		return;
	
	client_print_color(0, print_team_default, msg);
}

// ======================== CONNECT / PUTINSERVER ========================
public client_putinserver(id)
{
	if (!get_pcvar_num(g_CvarEnable) || is_user_bot(id))
		return;
	
	// Small delay so the player sees the message after join
	set_task(4.0, "TaskWelcomeEvent", id);
	
	// If Abundance + force upgrade is on, give them the guarantee
	if (g_bAbundanceActive && get_pcvar_num(g_CvarAbundanceForceUpg))
	{
		m2_set_force_upgrade(id, true);
	}
}

public TaskWelcomeEvent(id)
{
	if (!is_user_connected(id))
		return;
	
	if (g_flCurrentXpMult > 1.01 || g_flCurrentYangMult > 1.01 || g_bAbundanceActive)
	{
		client_print_color(id, print_team_default, "^4[Metin2 Events]^1 Active bonuses: XP ^3x%.2f^1 | Yang ^3x%.2f^1",
			g_flCurrentXpMult, g_flCurrentYangMult);
		client_print_color(id, print_team_default, "^4[Metin2 Events]^1 Type ^3/event^1 for details.");
	}
}

// ======================== STOCK HELPERS ========================
// (none needed beyond what the API already provides)
