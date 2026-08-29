#include <amxmodx>
#include <amxmisc>
#include <fun>
#include <fakemeta>
#include <hamsandwich>
#include <metin2_api>

#define PLUGIN  "Metin2 Skill Effects"
#define VERSION "2.2"
#define AUTHOR  "Andrew"

/*================================================================================
	IMPORTANT - sincronizare cu metin2Core.sma (v1.5+ scaling)

	Duratele de mai jos sunt aliniate cu formulele din metin2Core:
	  GetSkillDuration(base, skill_lvl, player_lvl, per_skill, per_level)
	+ aceleasi cap-uri (max duration) ca in core.

	API folosite:
	  get_user_m2_level()  - player level
	  get_user_m2_int()    - INT (unde mai e relevant la stun-uri vechi)

	Skill mapping (core real):
	  0-4   Warrior Corporal
	  5-9   Warrior Mental
	  10-14 Sura Arme Magice
	  15-19 Sura Magie Neagra
	  20-24 Ninja Lame
	  25-29 Ninja Arc
	  30-34 Shaman Zmeu (Dragon)
	  35-39 Shaman Fulger (Support)
================================================================================*/

#define MAX_SKILLS 40

// ======================== CATEGORII DE EFECT ========================
#define FX_BUFF_SELF   0   // aura/glow persistent pe caster
#define FX_STEALTH     1   // persistent, translucid
#define FX_STUN        2   // freeze vizual pe tinta
#define FX_SLOW        3   // marcaj vizual pe tinta incetinita
#define FX_DOT         4   // tick-uri persistente (otrava / flacara)
#define FX_AOE         5   // explozie / shockwave
#define FX_SINGLE_BEAM 6   // beam instant catre un target
#define FX_FLAG        7   // marcaj scurt (crit / reset CD)
#define FX_HEAL        8   // particule verzi + dlight
#define FX_AOE_STUN    9   // flash + shockwave cu stun pe zona
#define FX_DASH        10  // trail scurt in spatele jucatorului

// ======================== DATE PER SKILL ========================

new const g_iSkillCategory[MAX_SKILLS] = {
	// WARRIOR - Corporal (0-4)
	FX_BUFF_SELF, FX_BUFF_SELF, FX_STUN, FX_DASH, FX_AOE,
	// WARRIOR - Mental (5-9)
	FX_SINGLE_BEAM, FX_BUFF_SELF, FX_AOE, FX_BUFF_SELF, FX_AOE,
	// SURA - Arme Magice (10-14)
	FX_BUFF_SELF, FX_BUFF_SELF, FX_BUFF_SELF, FX_SLOW, FX_STUN,
	// SURA - Magie Neagra (15-19)
	FX_DOT, FX_SLOW, FX_SINGLE_BEAM, FX_STEALTH, FX_AOE,
	// NINJA - Lame (20-24)
	FX_STEALTH, FX_BUFF_SELF, FX_FLAG, FX_DOT, FX_AOE,
	// NINJA - Arc (25-29)
	FX_AOE, FX_AOE, FX_FLAG, FX_DOT, FX_AOE,
	// SHAMAN - Zmeu (30-34) -- dupa fix core: AoE foc / beam foc / scut / speed / fury AoE
	FX_AOE, FX_SINGLE_BEAM, FX_BUFF_SELF, FX_BUFF_SELF, FX_AOE,
	// SHAMAN - Fulger (35-39) -- support: heal / aura / bless / flag / aoe stun
	FX_HEAL, FX_BUFF_SELF, FX_BUFF_SELF, FX_FLAG, FX_AOE_STUN
};

// Culori RGB per skill
new const g_iSkillColor[MAX_SKILLS][3] = {
	// WARRIOR
	{255,80,0},   {30,100,255}, {255,255,255}, {255,255,255}, {255,60,0},
	{150,150,255},{100,100,255},{255,255,255}, {180,180,255}, {255,30,30},
	// SURA Arme Magice
	{180,50,255}, {255,0,100},  {255,255,0},   {200,200,255}, {160,160,160},
	// SURA Magie Neagra
	{255,120,0},  {130,0,180},  {150,0,60},    {40,0,60},     {90,0,120},
	// NINJA Lame
	{60,60,60},   {255,255,255},{255,255,255}, {60,200,60},   {255,255,255},
	// NINJA Arc
	{255,255,255},{255,140,0},  {255,220,0},   {60,200,60},   {200,180,120},
	// SHAMAN Zmeu (foc / dragon: rosu-portocaliu)
	{255,80,0},   {255,120,20}, {255,140,40},  {255,200,80},  {255,50,0},
	// SHAMAN Fulger (verde/albastru support)
	{0,255,120},  {255,220,50}, {80,255,120},  {0,150,255},   {200,220,255}
};

// Scale per skill
new const Float:g_flSkillScale[MAX_SKILLS] = {
	1.1, 1.0, 0.9, 1.0, 1.3,
	1.1, 1.0, 1.4, 1.0, 1.6,
	1.0, 1.0, 0.8, 0.9, 1.1,
	0.9, 0.9, 1.0, 1.0, 1.6,
	0.7, 0.8, 0.7, 0.8, 1.2,
	1.3, 1.3, 0.7, 0.8, 1.4,
	1.0, 1.0, 1.0, 0.7, 1.5,
	1.0, 1.0, 1.0, 0.7, 1.6
};

// Sunete (stringuri - precache_sound le accepta)
new const g_szSkillSound[MAX_SKILLS][] = {
	"ambience/pulsemachine_lp.wav", "items/armorpickup1.wav", "weapons/knife_hit2.wav", "weapons/knife_slash1.wav", "weapons/explode3.wav",
	"debris/beamstart7.wav",        "items/armorpickup2.wav", "weapons/explode4.wav",  "ambience/pulsemachine_lp.wav", "weapons/explode5.wav",

	"ambience/pulsemachine_lp.wav", "items/armorpickup1.wav", "items/gunpickup2.wav",  "player/pl_slosh1.wav", "weapons/knife_hit1.wav",

	"player/pl_slosh2.wav",         "player/pl_slosh1.wav",   "debris/beamstart7.wav", "player/pl_step1.wav",  "weapons/explode2.wav",

	"player/pl_step1.wav",          "items/gunpickup2.wav",   "weapons/357_cock1.wav", "player/pl_slosh2.wav", "weapons/explode3.wav",

	"weapons/explode3.wav",         "weapons/explode4.wav",   "weapons/357_cock1.wav", "player/pl_slosh2.wav", "weapons/explode2.wav",

	"ambience/pulsemachine_lp.wav", "ambience/pulsemachine_lp.wav", "ambience/pulsemachine_lp.wav", "weapons/357_cock1.wav", "ambience/thunder_clap.wav",

	"ambience/pulsemachine_lp.wav", "ambience/pulsemachine_lp.wav", "ambience/pulsemachine_lp.wav", "weapons/357_cock1.wav", "ambience/thunder_clap.wav"
};

// ======================== SPRITE INDEXES (precache o singura data) ========================
// Indexuri unice de sprite (precache-uite in plugin_precache)
new g_sprLightning;
new g_sprShockwave;
new g_sprRicho;
new g_sprLaser;
new g_sprDot;
new g_sprSmoke;
new g_sprSteam;

// Mapare skill -> sprite index (folosim indexul deja precache-uit)
new g_iSkillSprite[MAX_SKILLS];

// ======================== STATE PER PLAYER ========================
new bool:g_bEffectActive[33];
new g_iActiveSkill[33];
new g_iActiveSkillLevel[33];
new Float:g_flEffectEndTime[33];

#define TASK_SKILL_LOOP 7771

// Rank tier: 0 = N (1-19), 1 = M (20-29), 2 = G (30-39), 3 = P (40+)
stock GetRankTier(level)
{
	if (level >= 40) return 3;
	if (level >= 30) return 2;
	if (level >= 20) return 1;
	return 0;
}

// Multiplicator vizual in functie de rank (N=1.0, M=1.35, G=1.7, P=2.15)
stock Float:GetRankScale(level)
{
	static const Float:scales[4] = { 1.0, 1.35, 1.70, 2.15 };
	return scales[GetRankTier(level)];
}

// ======================== DURATA REALA (sincron cu metin2Core) ========================
// Formulele oglindesc GetSkillDuration() + cap-urile din core.
stock Float:GetSkillDuration(id, skill_idx, level)
{
	new Float:l = float(level);
	new Float:pl = float(get_user_m2_level(id));
	new Float:intt = float(get_user_m2_int(id));
	new Float:dur;

	switch (skill_idx)
	{
		// ===== WARRIOR - Corporal =====
		case 0: // Aura Sabiei
		{
			dur = 8.0 + (l * 0.28) + (pl * 0.15);
			return (dur > 18.0) ? 18.0 : dur;
		}
		case 1: // Corp Rezistent
		{
			dur = 7.0 + (l * 0.22) + (pl * 0.12);
			return (dur > 16.0) ? 16.0 : dur;
		}
		case 2: // Izbitura (stun)
		{
			dur = 1.4 + (l * 0.07) + (pl * 0.015);
			return (dur > 3.5) ? 3.5 : dur;
		}

		// ===== WARRIOR - Mental =====
		case 6: // Scut Mental
		{
			dur = 6.5 + (l * 0.20) + (pl * 0.12);
			return (dur > 14.0) ? 14.0 : dur;
		}
		case 8: // Concentrare
		{
			dur = 7.0 + (l * 0.22) + (pl * 0.13);
			return (dur > 15.0) ? 15.0 : dur;
		}

		// ===== SURA - Arme Magice =====
		case 10: // Tais Vrajit
		{
			dur = 7.0 + (l * 0.22) + (pl * 0.13);
			return (dur > 16.0) ? 16.0 : dur;
		}
		case 11: // Armura Vrajita (reflect)
		{
			dur = 6.0 + (l * 0.20) + (pl * 0.12);
			return (dur > 14.0) ? 14.0 : dur;
		}
		case 12: // Lovitura Degetului (pierce)
		{
			dur = 6.0 + (l * 0.18) + (pl * 0.10);
			return (dur > 12.0) ? 12.0 : dur;
		}
		case 13: // Atacul Fulgerului (slow)
		{
			dur = 3.5 + (l * 0.12) + (pl * 0.04) + (intt * 0.02);
			return (dur > 7.0) ? 7.0 : dur;
		}
		case 14: // Pietrificare (stun + residual slow ~2.5s)
		{
			dur = 1.8 + (l * 0.06) + (intt * 0.025) + (pl * 0.02);
			if (dur > 4.0) dur = 4.0;
			return dur + 2.5;
		}

		// ===== SURA - Magie Neagra =====
		case 15: // Flacara Intunecata (DoT ticks)
		{
			new ticks = 4 + (level / 6) + (get_user_m2_level(id) / 25);
			if (ticks > 10) ticks = 10;
			return float(ticks);
		}
		case 16: // Blestem
		{
			dur = 4.0 + (l * 0.14) + (pl * 0.05) + (intt * 0.02);
			return (dur > 8.0) ? 8.0 : dur;
		}
		case 18: // Umbre
		{
			dur = 4.0 + (l * 0.18) + (pl * 0.10);
			return (dur > 11.0) ? 11.0 : dur;
		}

		// ===== NINJA - Lame =====
		case 20: // Camuflaj
		{
			dur = 4.5 + (l * 0.20) + (pl * 0.10);
			return (dur > 12.0) ? 12.0 : dur;
		}
		case 21: // Atacul Fulgerator (speed)
		{
			dur = 6.0 + (l * 0.15) + (pl * 0.10);
			return (dur > 12.0) ? 12.0 : dur;
		}
		case 23: // Otrava (DoT)
		{
			new ticks = 4 + (level / 5) + (get_user_m2_level(id) / 20);
			if (ticks > 12) ticks = 12;
			return float(ticks);
		}

		// ===== NINJA - Arc =====
		case 28: // Sageata Otravita (DoT)
		{
			new ticks = 5 + (level / 4) + (get_user_m2_level(id) / 20);
			if (ticks > 14) ticks = 14;
			return float(ticks);
		}

		// ===== SHAMAN - Zmeu =====
		case 32: // Scut de Solzi
		{
			dur = 7.0 + (l * 0.20) + (pl * 0.12);
			return (dur > 15.0) ? 15.0 : dur;
		}
		case 33: // Zborul Dragonului
		{
			dur = 6.0 + (l * 0.15) + (pl * 0.10);
			return (dur > 12.0) ? 12.0 : dur;
		}
		case 34: // Furia Dragonului
		{
			dur = 7.5 + (l * 0.20) + (pl * 0.13);
			return (dur > 16.0) ? 16.0 : dur;
		}

		// ===== SHAMAN - Fulger =====
		case 36: // Atac Intens
		{
			dur = 8.5 + (l * 0.22) + (pl * 0.14);
			return (dur > 18.0) ? 18.0 : dur;
		}
		case 37: // Binecuvantare
		{
			dur = 10.0 + (l * 0.25) + (pl * 0.15);
			return (dur > 20.0) ? 20.0 : dur;
		}
	}

	return 0.0; // instant (fara loop persistent)
}

// ======================== PLUGIN INIT ========================

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_forward(FM_ClientConnect, "fw_ClientConnect");
}

public plugin_precache()
{
	// ---- SPRITES ----
	g_sprLightning = precache_model("sprites/lgtning.spr");
	g_sprShockwave = precache_model("sprites/shockwave.spr");
	g_sprRicho     = precache_model("sprites/richo1.spr");
	g_sprLaser     = precache_model("sprites/laserbeam.spr");
	g_sprDot       = precache_model("sprites/dot.spr");
	g_sprSmoke     = precache_model("sprites/smoke.spr");
	g_sprSteam     = precache_model("sprites/steam1.spr");

	// Mapare skill -> sprite (alegem sprite-ul cel mai potrivit pentru fiecare skill)
	// WARRIOR Corporal
	g_iSkillSprite[0]  = g_sprLightning;   // Aura Sabiei
	g_iSkillSprite[1]  = g_sprShockwave;   // Corp Rezistent
	g_iSkillSprite[2]  = g_sprRicho;       // Izbitura
	g_iSkillSprite[3]  = g_sprLaser;       // Dash
	g_iSkillSprite[4]  = g_sprShockwave;   // AoE

	// WARRIOR Mental
	g_iSkillSprite[5]  = g_sprLaser;       // Beam
	g_iSkillSprite[6]  = g_sprShockwave;   // Scut Mental
	g_iSkillSprite[7]  = g_sprShockwave;   // AoE
	g_iSkillSprite[8]  = g_sprDot;         // Concentrare
	g_iSkillSprite[9]  = g_sprShockwave;   // AoE mare

	// SURA Arme Magice
	g_iSkillSprite[10] = g_sprDot;         // Tais Vrajit
	g_iSkillSprite[11] = g_sprShockwave;   // Armura Vrajita
	g_iSkillSprite[12] = g_sprDot;         // Pierce
	g_iSkillSprite[13] = g_sprSmoke;       // Slow
	g_iSkillSprite[14] = g_sprRicho;       // Stun

	// SURA Magie Neagra
	g_iSkillSprite[15] = g_sprSteam;       // DoT flacara
	g_iSkillSprite[16] = g_sprSmoke;       // Blestem
	g_iSkillSprite[17] = g_sprLaser;       // Beam
	g_iSkillSprite[18] = g_sprSmoke;       // Umbre
	g_iSkillSprite[19] = g_sprShockwave;   // AoE

	// NINJA Lame
	g_iSkillSprite[20] = g_sprSmoke;       // Camuflaj
	g_iSkillSprite[21] = g_sprLaser;       // Speed
	g_iSkillSprite[22] = g_sprDot;         // Flag
	g_iSkillSprite[23] = g_sprSteam;       // Otrava
	g_iSkillSprite[24] = g_sprShockwave;   // AoE

	// NINJA Arc
	g_iSkillSprite[25] = g_sprShockwave;   // AoE
	g_iSkillSprite[26] = g_sprShockwave;   // AoE
	g_iSkillSprite[27] = g_sprDot;         // Flag
	g_iSkillSprite[28] = g_sprSteam;       // Sageata Otravita
	g_iSkillSprite[29] = g_sprShockwave;   // AoE

	// SHAMAN Zmeu (dragon / foc)
	g_iSkillSprite[30] = g_sprShockwave;   // Chemarea Dragonului (AoE)
	g_iSkillSprite[31] = g_sprLaser;       // Flacara Dragonului (beam)
	g_iSkillSprite[32] = g_sprShockwave;   // Scut de Solzi
	g_iSkillSprite[33] = g_sprLaser;       // Zborul Dragonului (speed trail)
	g_iSkillSprite[34] = g_sprShockwave;   // Furia Dragonului (AoE)

	// SHAMAN Fulger (support)
	g_iSkillSprite[35] = g_sprDot;         // Lecuire
	g_iSkillSprite[36] = g_sprDot;         // Atac Intens
	g_iSkillSprite[37] = g_sprDot;         // Binecuvantare
	g_iSkillSprite[38] = g_sprDot;         // Iutesenie
	g_iSkillSprite[39] = g_sprLightning;   // Chemarea Fulgerului

	// ---- SOUNDS ----
	static const szSounds[][] = {
		"weapons/knife_hit1.wav", "weapons/knife_hit2.wav", "weapons/knife_slash1.wav",
		"items/armorpickup1.wav", "items/armorpickup2.wav",
		"weapons/explode2.wav", "weapons/explode3.wav", "weapons/explode4.wav", "weapons/explode5.wav",
		"ambience/pulsemachine_lp.wav", "ambience/thunder_clap.wav",
		"player/pl_slosh1.wav", "player/pl_slosh2.wav", "player/pl_step1.wav",
		"weapons/357_cock1.wav", "debris/beamstart7.wav", "items/gunpickup2.wav"
	};
	for (new i = 0; i < sizeof szSounds; i++)
		precache_sound(szSounds[i]);
}

public fw_ClientConnect(id)
{
	g_bEffectActive[id] = false;
	return FMRES_IGNORED;
}

// ======================== HOOK PRINCIPAL ========================

public m2_skill_used(id, skill_idx, skill_level)
{
	if (!is_user_connected(id) || !is_user_alive(id))
		return;
	if (skill_idx < 0 || skill_idx >= MAX_SKILLS)
		return;

	PlaySkillSound(id, skill_idx);
	RenderSkillEffect(id, skill_idx, skill_level);

	new category = g_iSkillCategory[skill_idx];
	new Float:duration = GetSkillDuration(id, skill_idx, skill_level);

	// Loop persistent doar pe caster (buff / stealth).
	// DoT-ul e pe tinta (aim) → doar efectul instant din RenderSkillEffect e corect.
	if (duration > 0.0 && (category == FX_BUFF_SELF || category == FX_STEALTH))
	{
		g_bEffectActive[id] = true;
		g_iActiveSkill[id] = skill_idx;
		g_iActiveSkillLevel[id] = skill_level;
		g_flEffectEndTime[id] = get_gametime() + duration;

		// Nu suprascriem rendering-ul de stealth al core-ului (alpha 8-15).

		remove_task(TASK_SKILL_LOOP + id);
		set_task(0.35, "task_persistent_fx", TASK_SKILL_LOOP + id, _, _, "b");
	}
}

public task_persistent_fx(taskid)
{
	new id = taskid - TASK_SKILL_LOOP;

	if (!is_user_connected(id) || !is_user_alive(id) || get_gametime() >= g_flEffectEndTime[id])
	{
		if (is_user_connected(id))
			EndPersistentFx(id);
		remove_task(taskid);
		return;
	}

	RenderPersistentTick(id, g_iActiveSkill[id], g_iActiveSkillLevel[id]);
}

EndPersistentFx(id)
{
	g_bEffectActive[id] = false;
	if (is_user_alive(id))
		set_user_rendering(id);
}

// ======================== SUNET ========================

PlaySkillSound(id, skill_idx)
{
	emit_sound(id, CHAN_ITEM, g_szSkillSound[skill_idx], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

// ======================== EFECT INSTANT (scale cu rank N/M/G/P) ========================

RenderSkillEffect(id, skill_idx, skill_level)
{
	new origin[3], aim_origin[3];
	get_user_origin(id, origin, 0);
	get_user_origin(id, aim_origin, 3);

	new r = g_iSkillColor[skill_idx][0];
	new g = g_iSkillColor[skill_idx][1];
	new b = g_iSkillColor[skill_idx][2];
	new sprite = g_iSkillSprite[skill_idx];

	new Float:baseScale = g_flSkillScale[skill_idx];
	new Float:rankMul   = GetRankScale(skill_level);
	new Float:scale     = baseScale * rankMul;
	new tier            = GetRankTier(skill_level);

	// Extra particule / inele in functie de rank
	new extraRings   = tier;              // 0..3
	new particleCnt  = 4 + tier * 2;      // 4 / 6 / 8 / 10
	new beamWidthAdd = tier * 2;          // 0 / 2 / 4 / 6

	switch (g_iSkillCategory[skill_idx])
	{
		case FX_BUFF_SELF:
		{
			FxDlight(origin, r, g, b, floatround(20.0 * scale), 7 + tier);
			FxRingpoint(origin, sprite, floatround(30.0 * scale), r, g, b, 210 + tier * 15);
			FxSpriteTrail(origin, sprite, particleCnt);

			// La M+ mai multe inele concentrice
			for (new i = 0; i < extraRings; i++)
				FxRingpoint(origin, sprite, floatround((22.0 + i * 9.0) * scale), r, g, b, 170 - i * 15);

			// P: mic shockwave la activare
			if (tier >= 3)
				FxShockwave(origin, r, g, b, floatround(28.0 * scale));
		}
		case FX_STEALTH:
		{
			new puffs = 3 + tier;
			for (new i = 0; i < puffs; i++)
				FxSmokePuff(origin);
			FxDlight(origin, 55, 55, 70, 10 + tier * 3, 3 + tier);
			if (tier >= 2)
				FxCloud(origin, sprite, floatround(14.0 * scale));
		}
		case FX_STUN:
		{
			FxBeamPoints(origin, aim_origin, sprite, 2 + tier / 2, floatround(7.0 * scale) + beamWidthAdd, r, g, b, 230);
			FxDlight(aim_origin, r, g, b, floatround(14.0 * scale), 4 + tier);
			FxRingpoint(aim_origin, g_sprShockwave, floatround(18.0 * scale), r, g, b, 190);

			if (tier >= 2) // G / P
				FxExplosion(aim_origin, floatround(10.0 * scale), r, g, b);
		}
		case FX_SLOW:
		{
			FxRingpoint(aim_origin, sprite, floatround(20.0 * scale), r, g, b, 170);
			FxCloud(aim_origin, sprite, floatround(16.0 * scale));
			FxDlight(aim_origin, r, g, b, 12 + tier * 2, 3 + tier);

			if (tier >= 1)
				FxSmokePuff(aim_origin);
		}
		case FX_DOT:
		{
			// pe tinta (aim), nu pe caster
			FxCloud(aim_origin, sprite, floatround(22.0 * scale));
			FxDlight(aim_origin, r, g, b, 12 + tier * 3, 5 + tier);
			FxSmokePuff(aim_origin);
			FxRingpoint(aim_origin, sprite, floatround(16.0 * scale), r, g, b, 160);

			if (tier >= 1)
				FxSmokePuff(aim_origin);
			if (tier >= 2)
				FxCloud(aim_origin, sprite, floatround(16.0 * scale));
			if (tier >= 3)
				FxSpriteTrail(aim_origin, sprite, 4);
		}
		case FX_AOE:
		{
			FxExplosion(aim_origin, floatround(16.0 * scale), r, g, b);
			FxShockwave(aim_origin, r, g, b, floatround(36.0 * scale));
			FxDlight(aim_origin, r, g, b, floatround(22.0 * scale), 5 + tier);

			// G/P: al doilea shockwave mai mare
			if (tier >= 2)
				FxShockwave(aim_origin, r, g, b, floatround(50.0 * scale));
			if (tier >= 3)
				FxSpriteTrail(aim_origin, sprite, 6);
		}
		case FX_SINGLE_BEAM:
		{
			FxBeamPoints(origin, aim_origin, sprite, 2 + tier / 2, floatround(10.0 * scale) + beamWidthAdd, r, g, b, 240);
			FxDlight(aim_origin, r, g, b, floatround(16.0 * scale), 4 + tier);
			FxRingpoint(aim_origin, g_sprShockwave, floatround(14.0 * scale), r, g, b, 190);

			if (tier >= 2)
				FxBeamPoints(origin, aim_origin, sprite, 1, floatround(6.0 * scale), r, g, b, 180);
		}
		case FX_FLAG:
		{
			FxDlight(origin, r, g, b, floatround(14.0 * scale), 3 + tier);
			FxRingpoint(origin, sprite, floatround(18.0 * scale), r, g, b, 190);

			if (tier >= 1)
				FxSpriteTrail(origin, sprite, 3 + tier);
		}
		case FX_HEAL:
		{
			FxDlight(origin, r, g, b, floatround(20.0 * scale), 7 + tier);
			FxRingpoint(origin, sprite, floatround(24.0 * scale), r, g, b, 170);
			FxSpriteTrail(origin, sprite, particleCnt);

			for (new i = 0; i < extraRings; i++)
				FxRingpoint(origin, sprite, floatround((18.0 + i * 7.0) * scale), r, g, b, 140);
		}
		case FX_AOE_STUN:
		{
			new sky[3];
			sky[0] = origin[0];
			sky[1] = origin[1];
			sky[2] = origin[2] + 500 + tier * 80;

			FxBeamPoints(sky, origin, sprite, 2 + tier / 2, floatround(9.0 * scale) + beamWidthAdd, r, g, b, 255);
			FxShockwave(origin, r, g, b, floatround(40.0 * scale));
			FxDlight(origin, r, g, b, floatround(26.0 * scale), 6 + tier);
			FxExplosion(origin, floatround(12.0 * scale), r, g, b);

			// P: al doilea fulger + shockwave extra
			if (tier >= 3)
			{
				sky[0] += random_num(-40, 40);
				sky[1] += random_num(-40, 40);
				FxBeamPoints(sky, origin, sprite, 2, floatround(7.0 * scale), r, g, b, 220);
				FxShockwave(origin, r, g, b, floatround(55.0 * scale));
			}
		}
		case FX_DASH:
		{
			FxBeamPoints(origin, aim_origin, sprite, 1 + tier / 2, floatround(4.0 * scale) + beamWidthAdd, r, g, b, 190);
			FxDlight(origin, r, g, b, 10 + tier * 2, 2 + tier);

			if (tier >= 2)
				FxSpriteTrail(origin, sprite, 4);
		}
	}
}

// tick pentru efectele persistente (scaleaza cu rank N/M/G/P)
RenderPersistentTick(id, skill_idx, skill_level)
{
	new origin[3];
	get_user_origin(id, origin, 0);

	new r = g_iSkillColor[skill_idx][0];
	new g = g_iSkillColor[skill_idx][1];
	new b = g_iSkillColor[skill_idx][2];
	new sprite = g_iSkillSprite[skill_idx];

	new Float:rankMul = GetRankScale(skill_level);
	new tier = GetRankTier(skill_level);

	switch (g_iSkillCategory[skill_idx])
	{
		case FX_BUFF_SELF:
		{
			// inel periodic + dlight, mai dens la rank mare
			FxRingpoint(origin, sprite, floatround(16.0 * rankMul), r, g, b, 140 + tier * 25);
			if (random_num(0, 2 - (tier > 1 ? 1 : 0)) == 0)
				FxDlight(origin, r, g, b, 13 + tier * 3, 2 + tier);

			if (tier >= 1 && random_num(0, 3) == 0)
				FxSpriteTrail(origin, sprite, 2 + tier / 2);

			// P: al doilea inel mai mare
			if (tier >= 3 && random_num(0, 2) == 0)
				FxRingpoint(origin, sprite, floatround(26.0 * rankMul), r, g, b, 110);
		}
		case FX_STEALTH:
		{
			// fum discret (nu interferam cu alpha din core)
			if (random_num(0, 2 - (tier > 0 ? 1 : 0)) == 0)
				FxSmokePuff(origin);
			if (tier >= 2 && random_num(0, 4) == 0)
				FxDlight(origin, 50, 50, 60, 8 + tier, 2);
		}
		case FX_DOT:
		{
			FxCloud(origin, sprite, floatround(13.0 * rankMul));
			if (random_num(0, 1) == 0)
				FxSmokePuff(origin);

			if (tier >= 1)
				FxDlight(origin, r, g, b, 9 + tier * 2, 2);

			if (tier >= 3 && random_num(0, 2) == 0)
				FxSpriteTrail(origin, sprite, 2);
		}
	}
}

// ======================== PRIMITIVE TE_ (SAFE) ========================
// Toate mesajele sunt scrise cu parametri clamp-uiti ca sa nu corupa stream-ul de retea.
// Evitam TE_FIREFIELD (cauza frecventa de CL_Parse_Version / kick).

stock clamp_byte(value, minv = 0, maxv = 255)
{
	if (value < minv) return minv;
	if (value > maxv) return maxv;
	return value;
}

FxBeamPoints(start[3], end[3], sprite, life, width, r, g, b, brightness)
{
	life       = clamp_byte(life, 1, 30);
	width      = clamp_byte(width, 1, 40);
	brightness = clamp_byte(brightness, 50, 255);

	message_begin(MSG_PVS, SVC_TEMPENTITY, start);
	write_byte(TE_BEAMPOINTS);
	write_coord(start[0]); write_coord(start[1]); write_coord(start[2]);
	write_coord(end[0]);   write_coord(end[1]);   write_coord(end[2]);
	write_short(sprite);
	write_byte(0);              // start frame
	write_byte(0);              // frame rate
	write_byte(life);           // life * 0.1s
	write_byte(width);          // width
	write_byte(0);              // noise
	write_byte(clamp_byte(r)); write_byte(clamp_byte(g)); write_byte(clamp_byte(b));
	write_byte(brightness);
	write_byte(0);              // scroll
	message_end();
}

FxDlight(origin[3], r, g, b, radius, life)
{
	radius = clamp_byte(radius, 1, 50);
	life   = clamp_byte(life, 1, 20);

	message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
	write_byte(TE_DLIGHT);
	write_coord(origin[0]); write_coord(origin[1]); write_coord(origin[2]);
	write_byte(radius);
	write_byte(clamp_byte(r)); write_byte(clamp_byte(g)); write_byte(clamp_byte(b));
	write_byte(life);
	write_byte(0);              // decay
	message_end();
}

FxRingpoint(origin[3], sprite, radius, r, g, b, brightness)
{
	// TE_BEAMCYLINDER e mai stabil decat TE_BEAMRING pe multi clienti
	new height = clamp_byte(radius, 20, 120);

	message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
	write_byte(TE_BEAMCYLINDER);
	write_coord(origin[0]); write_coord(origin[1]); write_coord(origin[2] - 15);
	write_coord(origin[0]); write_coord(origin[1]); write_coord(origin[2] + height);
	write_short(sprite);
	write_byte(0);              // start frame
	write_byte(0);              // frame rate
	write_byte(4);              // life
	write_byte(8);              // width
	write_byte(0);              // noise
	write_byte(clamp_byte(r)); write_byte(clamp_byte(g)); write_byte(clamp_byte(b));
	write_byte(clamp_byte(brightness, 80, 255));
	write_byte(0);              // scroll
	message_end();
}

FxExplosion(origin[3], scale, r, g, b)
{
	// Mereu shockwave.spr pentru TE_EXPLOSION (alte sprite-uri pot crasa clientul)
	new sc = clamp_byte(scale / 4, 5, 25);

	message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
	write_byte(TE_EXPLOSION);
	write_coord(origin[0]); write_coord(origin[1]); write_coord(origin[2]);
	write_short(g_sprShockwave);
	write_byte(sc);                 // scale
	write_byte(12);                 // framerate
	write_byte(0);                  // flags
	message_end();

	FxDlight(origin, r, g, b, scale, 5);
}

FxShockwave(origin[3], r, g, b, radius)
{
	new height = clamp_byte(radius, 30, 150);

	message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
	write_byte(TE_BEAMCYLINDER);
	write_coord(origin[0]); write_coord(origin[1]); write_coord(origin[2] - 10);
	write_coord(origin[0]); write_coord(origin[1]); write_coord(origin[2] + height);
	write_short(g_sprShockwave);
	write_byte(0);
	write_byte(0);
	write_byte(5);              // life
	write_byte(10);             // width
	write_byte(0);
	write_byte(clamp_byte(r)); write_byte(clamp_byte(g)); write_byte(clamp_byte(b));
	write_byte(200);
	write_byte(0);
	message_end();
}

FxCloud(origin[3], sprite, radius)
{
	// Inlocuim TE_FIREFIELD (periculos) cu cateva TE_SMOKE + TE_SPRITE
	// Arata ca un nor / otrava fara sa rupa protocolul
	new i;
	for (i = 0; i < 3; i++)
	{
		new ox = origin[0] + random_num(-20, 20);
		new oy = origin[1] + random_num(-20, 20);
		new oz = origin[2] + random_num(0, 25);

		message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
		write_byte(TE_SMOKE);
		write_coord(ox); write_coord(oy); write_coord(oz);
		write_short(g_sprSteam);
		write_byte(clamp_byte(radius / 3, 8, 18));  // scale
		write_byte(8);                              // framerate
		message_end();
	}

	// cateva particule colorate
	for (i = 0; i < 2; i++)
	{
		new ox = origin[0] + random_num(-15, 15);
		new oy = origin[1] + random_num(-15, 15);
		new oz = origin[2] + random_num(5, 30);

		message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
		write_byte(TE_SPRITE);
		write_coord(ox); write_coord(oy); write_coord(oz);
		write_short(sprite);
		write_byte(random_num(4, 9));
		write_byte(160);
		message_end();
	}
}

FxSmokePuff(origin[3])
{
	message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
	write_byte(TE_SMOKE);
	write_coord(origin[0]); write_coord(origin[1]); write_coord(origin[2] + 8);
	write_short(g_sprSteam);
	write_byte(10);             // scale
	write_byte(8);              // framerate
	message_end();
}

FxSpriteTrail(origin[3], sprite, count)
{
	if (count > 6) count = 6;   // nu spamam prea mult

	for (new i = 0; i < count; i++)
	{
		new ox = origin[0] + random_num(-20, 20);
		new oy = origin[1] + random_num(-20, 20);
		new oz = origin[2] + random_num(0, 35);

		message_begin(MSG_PVS, SVC_TEMPENTITY, origin);
		write_byte(TE_SPRITE);
		write_coord(ox); write_coord(oy); write_coord(oz);
		write_short(sprite);
		write_byte(random_num(3, 7));
		write_byte(170);
		message_end();
	}
}
