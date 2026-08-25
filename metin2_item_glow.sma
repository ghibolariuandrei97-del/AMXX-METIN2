#include <amxmodx>
#include <amxmisc>
#include <fun>
#include <reapi>
#include <metin2_api>

#define PLUGIN_NAME    "Metin2 RPG - Item Glow / Shine"
#define PLUGIN_VERSION "1.1.0"
#define PLUGIN_AUTHOR  "Custom / Grok"

#define MAX_PLAYERS        32
#define MAX_EQUIP_SLOTS    6
#define TASK_GLOW_REFRESH  77100
#define TASK_GLOW_PULSE    77200

// ======================== CVARS ========================
new g_CvarEnable;
new g_CvarMinUpgrade;          // minimum upgrade to start glowing (default 5)
new g_CvarRefreshInterval;     // seconds between full scans
new g_CvarPulseHigh;           // 1 = pulse effect for very high upgrades
new g_CvarIgnoreBots;

// ======================== PLAYER STATE ========================
new bool:g_bHasGlow[MAX_PLAYERS + 1];
new g_iGlowR[MAX_PLAYERS + 1];
new g_iGlowG[MAX_PLAYERS + 1];
new g_iGlowB[MAX_PLAYERS + 1];
new g_iGlowAmount[MAX_PLAYERS + 1];
new g_iGlowTier[MAX_PLAYERS + 1];   // 0=none, 1=soft, 2=medium, 3=strong, 4=legendary
new Float:g_flPulseDir[MAX_PLAYERS + 1];

new g_iMaxPlayers;

// ======================== PLUGIN ========================
public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
	
	g_CvarEnable            = register_cvar("amx_metin2_glow_enable", "1");
	g_CvarMinUpgrade        = register_cvar("amx_metin2_glow_min_upgrade", "5");
	g_CvarRefreshInterval   = register_cvar("amx_metin2_glow_refresh", "2.0");
	g_CvarPulseHigh         = register_cvar("amx_metin2_glow_pulse", "1");
	g_CvarIgnoreBots        = register_cvar("amx_metin2_glow_ignore_bots", "1");
	
	g_iMaxPlayers = get_maxplayers();
	
	// Periodic full refresh (safety net)
	set_task(2.0, "TaskRefreshAll", TASK_GLOW_REFRESH, _, _, "b");
	
	// Optional pulse for high tiers
	set_task(0.35, "TaskPulseGlow", TASK_GLOW_PULSE, _, _, "b");
	
	// ReAPI spawn (after core has applied data)
	RegisterHookChain(RG_CBasePlayer_Spawn, "OnPlayerSpawn", true);
	
	server_print("[Metin2 Glow] Loaded v%s", PLUGIN_VERSION);
}

public plugin_cfg()
{
	// Re-schedule with cvar value if changed
	remove_task(TASK_GLOW_REFRESH);
	new Float:interval = get_pcvar_float(g_CvarRefreshInterval);
	if (interval < 0.5) interval = 0.5;
	set_task(interval, "TaskRefreshAll", TASK_GLOW_REFRESH, _, _, "b");
}

public plugin_end()
{
	remove_task(TASK_GLOW_REFRESH);
	remove_task(TASK_GLOW_PULSE);
}

// ======================== FORWARDS FROM CORE ========================
public m2_item_equipped(id, itemid, slot)
{
	if (is_user_connected(id))
		UpdatePlayerGlow(id);
}

public m2_item_unequipped(id, itemid, slot)
{
	if (is_user_connected(id))
		UpdatePlayerGlow(id);
}

// ======================== SPAWN / DISCONNECT ========================
public OnPlayerSpawn(const id)
{
	if (!is_user_connected(id))
		return;
	
	// Small delay so inventory is fully applied
	set_task(0.3, "TaskDelayedGlow", id);
}

public TaskDelayedGlow(id)
{
	if (is_user_connected(id))
		UpdatePlayerGlow(id);
}

public client_disconnected(id)
{
	ClearGlow(id);
	g_bHasGlow[id] = false;
	g_iGlowTier[id] = 0;
	remove_task(id); // any pending delayed tasks
}

public client_putinserver(id)
{
	g_bHasGlow[id] = false;
	g_iGlowTier[id] = 0;
	g_flPulseDir[id] = 1.0;
}

// ======================== MAIN LOGIC ========================
public TaskRefreshAll()
{
	if (!get_pcvar_num(g_CvarEnable))
	{
		// If disabled mid-game, clear everyone
		for (new i = 1; i <= g_iMaxPlayers; i++)
		{
			if (is_user_connected(i) && g_bHasGlow[i])
				ClearGlow(i);
		}
		return;
	}
	
	for (new i = 1; i <= g_iMaxPlayers; i++)
	{
		if (!is_user_connected(i))
			continue;
		
		if (get_pcvar_num(g_CvarIgnoreBots) && is_user_bot(i))
			continue;
		
		UpdatePlayerGlow(i);
	}
}

UpdatePlayerGlow(id)
{
	if (!get_pcvar_num(g_CvarEnable) || !is_user_connected(id) || !is_user_alive(id))
	{
		if (g_bHasGlow[id])
			ClearGlow(id);
		return;
	}
	
	if (get_pcvar_num(g_CvarIgnoreBots) && is_user_bot(id))
	{
		if (g_bHasGlow[id])
			ClearGlow(id);
		return;
	}
	
	new minUpg = get_pcvar_num(g_CvarMinUpgrade);
	if (minUpg < 1) minUpg = 1;
	if (minUpg > 9) minUpg = 9;
	
	// ----- Analyse equipped items -----
	new totalUpgrade = 0;
	new highCount = 0;          // items >= minUpg
	new veryHighCount = 0;      // items >= 7
	new maxUpgrade = 0;
	new sumHigh = 0;            // sum of upgrades that are >= minUpg
	
	for (new slot = 0; slot < MAX_EQUIP_SLOTS; slot++)
	{
		new itemid = m2_get_user_equipped(id, slot);
		if (itemid <= 0)
			continue;
		
		new upg = m2_get_user_equipped_upgrade(id, slot);
		if (upg < 0) upg = 0;
		if (upg > 9) upg = 9;
		
		totalUpgrade += upg;
		
		if (upg > maxUpgrade)
			maxUpgrade = upg;
		
		if (upg >= minUpg)
		{
			highCount++;
			sumHigh += upg;
			
			if (upg >= 7)
				veryHighCount++;
		}
	}
	
	// No qualifying items → remove glow
	if (highCount == 0 || maxUpgrade < minUpg)
	{
		if (g_bHasGlow[id])
			ClearGlow(id);
		return;
	}
	
	// ----- Calculate tier & color -----
	// Tier system (visual intensity):
	// 1 Soft     : mostly +5 / few items
	// 2 Medium   : +6 or several +5
	// 3 Strong   : +7/+8 or multiple high
	// 4 Legendary: one or more +9, or extreme combinations
	
	new tier = 1;
	new amount = 15;
	new r = 80, g = 160, b = 255;   // default soft cyan-blue
	
	// Base on highest upgrade
	switch (maxUpgrade)
	{
		case 5:
		{
			tier = 1;
			amount = 18 + (highCount * 4);
			r = 70;  g = 170; b = 255;          // light blue
		}
		case 6:
		{
			tier = 2;
			amount = 28 + (highCount * 5);
			r = 40;  g = 220; b = 255;          // cyan
		}
		case 7:
		{
			tier = 3;
			amount = 40 + (highCount * 6);
			r = 180; g = 60;  b = 255;          // purple / magenta
		}
		case 8:
		{
			tier = 3;
			amount = 55 + (highCount * 7);
			r = 255; g = 140; b = 40;           // orange-gold
		}
		default: // 9+
		{
			tier = 4;
			amount = 70 + (highCount * 8) + (veryHighCount * 10);
			r = 255; g = 215; b = 50;           // bright gold
		}
	}
	
	// Extra boost from multiple high items
	if (highCount >= 3)
	{
		amount += 12;
		if (tier < 3) tier = 3;
	}
	if (highCount >= 5)
	{
		amount += 18;
		tier = 4;
		// Shift toward pure white-gold for full set
		r = min(255, r + 40);
		g = min(255, g + 30);
		b = min(255, b + 20);
	}
	
	// Extra from raw sum of high upgrades
	if (sumHigh >= 30)
		amount += 10;
	if (sumHigh >= 45)
		amount += 15;
	
	// Clamp amount (GlowShell works best 10-120 range)
	if (amount < 12)  amount = 12;
	if (amount > 110) amount = 110;
	
	// Apply
	ApplyGlow(id, r, g, b, amount, tier);
}

ApplyGlow(id, r, g, b, amount, tier)
{
	g_iGlowR[id] = r;
	g_iGlowG[id] = g;
	g_iGlowB[id] = b;
	g_iGlowAmount[id] = amount;
	g_iGlowTier[id] = tier;
	g_bHasGlow[id] = true;
	
	// Classic Metin2-style shell glow
	set_user_rendering(id, kRenderFxGlowShell, r, g, b, kRenderNormal, amount);
}

ClearGlow(id)
{
	if (!is_user_connected(id))
		return;
	
	set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderNormal, 0);
	g_bHasGlow[id] = false;
	g_iGlowTier[id] = 0;
	g_iGlowAmount[id] = 0;
}

// ======================== PULSE EFFECT (high tiers) ========================
public TaskPulseGlow()
{
	if (!get_pcvar_num(g_CvarEnable) || !get_pcvar_num(g_CvarPulseHigh))
		return;
	
	for (new id = 1; id <= g_iMaxPlayers; id++)
	{
		if (!g_bHasGlow[id] || !is_user_connected(id) || !is_user_alive(id))
			continue;
		
		// Only pulse Strong + Legendary
		if (g_iGlowTier[id] < 3)
			continue;
		
		new base = g_iGlowAmount[id];
		new delta = (g_iGlowTier[id] == 4) ? 18 : 10;
		
		// Simple triangle wave
		g_flPulseDir[id] = -g_flPulseDir[id];
		new newAmount = base + floatround(g_flPulseDir[id] * float(delta));
		
		if (newAmount < 15) newAmount = 15;
		if (newAmount > 120) newAmount = 120;
		
		set_user_rendering(id, kRenderFxGlowShell,
			g_iGlowR[id], g_iGlowG[id], g_iGlowB[id],
			kRenderNormal, newAmount);
	}
}

// ======================== ADMIN / DEBUG (optional) ========================
public plugin_natives()
{
	// none needed
}

// Simple status command for testing
public plugin_cfg_post()
{
	register_clcmd("say /glow", "CmdGlowStatus");
	register_clcmd("say /shine", "CmdGlowStatus");
}

public CmdGlowStatus(id)
{
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;
	
	if (!get_pcvar_num(g_CvarEnable))
	{
		client_print_color(id, print_team_default, "^4[Metin2 Glow]^1 Sistemul de luciu este dezactivat.");
		return PLUGIN_HANDLED;
	}
	
	new minUpg = get_pcvar_num(g_CvarMinUpgrade);
	new high = 0, maxu = 0, sum = 0;
	
	for (new s = 0; s < MAX_EQUIP_SLOTS; s++)
	{
		new upg = m2_get_user_equipped_upgrade(id, s);
		if (upg >= minUpg)
		{
			high++;
			sum += upg;
		}
		if (upg > maxu) maxu = upg;
	}
	
	client_print_color(id, print_team_default, "^4[Metin2 Glow]^1 Status luciu:");
	client_print_color(id, print_team_default, "^1• Iteme >= +%d: ^3%d^1 | Max upgrade: ^3+%d^1 | Suma high: ^3%d",
		minUpg, high, maxu, sum);
	
	if (g_bHasGlow[id])
	{
		new const tierNames[][] = { "Niciunul", "Soft (+5)", "Medium (+6)", "Strong (+7/+8)", "Legendary (+9)" };
		new t = g_iGlowTier[id];
		if (t < 0) t = 0;
		if (t > 4) t = 4;
		
		client_print_color(id, print_team_default, "^1• Tier actual: ^3%s^1 | Intensitate: ^3%d^1 | Culoare RGB: ^3%d %d %d",
			tierNames[t], g_iGlowAmount[id], g_iGlowR[id], g_iGlowG[id], g_iGlowB[id]);
	}
	else
	{
		client_print_color(id, print_team_default, "^1• Momentan ^3nu^1 ai luciu (echipeaza iteme +%d sau mai mari).", minUpg);
	}
	
	return PLUGIN_HANDLED;
}
