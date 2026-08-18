#if defined _metin2_rpg_included
	#endinput
#endif
#define _metin2_rpg_included

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib metin2_rpg
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib metin2_rpg
	#endif
#else
	#pragma library metin2_rpg
#endif

/*================================================================================
	Metin2 RPG Core - Include File
	Versiune 1.1
	
	Natives + Forwards + Stocks utile
================================================================================*/

// ======================== RASE ========================
#define M2_RACE_NONE      0
#define M2_RACE_WARRIOR   1
#define M2_RACE_SURA      2
#define M2_RACE_NINJA     3
#define M2_RACE_SHAMAN    4

// ======================== SLOTURI ECHIPAMENT ========================
#define M2_SLOT_WEAPON    0
#define M2_SLOT_ARMOR     1
#define M2_SLOT_HELMET    2
#define M2_SLOT_SHIELD    3
#define M2_SLOT_SHOES     4
#define M2_SLOT_JEWEL     5

// ======================== STAT TYPES (pentru forward m2_stat_allocated) ========================
#define M2_STAT_STR       1
#define M2_STAT_HP        2
#define M2_STAT_DEX       3
#define M2_STAT_INT       4

// ======================== NATIVES ========================

/**
 * Returneaza level-ul jucatorului
 *
 * @param id        Indexul jucatorului
 * @return          Level-ul (1+) sau 0 daca jucatorul nu e conectat
 */
native get_user_m2_level(id);

/**
 * Returneaza XP-ul curent al jucatorului
 *
 * @param id        Indexul jucatorului
 * @return          XP-ul sau 0 daca jucatorul nu e conectat
 */
native get_user_m2_xp(id);

/**
 * Seteaza level-ul jucatorului
 *
 * @param id        Indexul jucatorului
 * @param level     Noul level (minim 1)
 * @return          1 la succes, 0 la esec
 */
native set_user_m2_level(id, level);

/**
 * Seteaza XP-ul jucatorului
 *
 * @param id        Indexul jucatorului
 * @param xp        Noul XP (minim 0)
 * @return          1 la succes, 0 la esec
 */
native set_user_m2_xp(id, xp);

/**
 * Returneaza Yang-ul jucatorului
 *
 * @param id        Indexul jucatorului
 * @return          Yang-ul sau 0 daca jucatorul nu e conectat
 */
native get_user_m2_yang(id);

/**
 * Seteaza Yang-ul jucatorului
 *
 * @param id        Indexul jucatorului
 * @param yang      Noul Yang (minim 0)
 * @return          1 la succes, 0 la esec
 */
native set_user_m2_yang(id, yang);

/**
 * Returneaza rasa jucatorului
 *
 * @param id        Indexul jucatorului
 * @return          Rasa (M2_RACE_*) sau 0 daca nu e conectat / nu are rasa
 */
native get_user_m2_race(id);

/**
 * Returneaza valoarea STR
 *
 * @param id        Indexul jucatorului
 * @return          STR sau 0
 */
native get_user_m2_str(id);

/**
 * Returneaza valoarea HP (stat)
 *
 * @param id        Indexul jucatorului
 * @return          HP stat sau 0
 */
native get_user_m2_hp(id);

/**
 * Returneaza valoarea DEX
 *
 * @param id        Indexul jucatorului
 * @return          DEX sau 0
 */
native get_user_m2_dex(id);

/**
 * Returneaza valoarea INT
 *
 * @param id        Indexul jucatorului
 * @return          INT sau 0
 */
native get_user_m2_int(id);

/**
 * Returneaza mana curenta
 *
 * @param id        Indexul jucatorului
 * @return          MP curent sau 0
 */
native get_user_m2_mp(id);

/**
 * Returneaza mana maxima
 *
 * @param id        Indexul jucatorului
 * @return          Max MP sau 0
 */
native get_user_m2_maxmp(id);

// ======================== FORWARDS ========================

/**
 * Apelat atunci cand un jucator foloseste un skill
 *
 * @param id            Indexul jucatorului
 * @param skill_idx     Indexul skill-ului (0-19)
 * @param skill_level   Nivelul skill-ului la momentul folosirii
 */
forward m2_skill_used(id, skill_idx, skill_level);

/**
 * Apelat atunci cand un jucator face level up
 *
 * @param id            Indexul jucatorului
 * @param new_level     Noul level
 */
forward m2_level_up(id, new_level);

/**
 * Apelat atunci cand un jucator omoara alt jucator (si primeste XP/Yang)
 *
 * @param killer        Indexul killer-ului
 * @param victim        Indexul victimei
 * @param xp            XP primit
 * @param yang          Yang primit
 */
forward m2_player_kill(killer, victim, xp, yang);

/**
 * Apelat atunci cand un jucator echipaza un item
 *
 * @param id            Indexul jucatorului
 * @param itemid        ID-ul itemului
 * @param slot          Slotul de echipament (M2_SLOT_*)
 */
forward m2_item_equipped(id, itemid, slot);

/**
 * Apelat atunci cand un jucator dezechipaza un item
 *
 * @param id            Indexul jucatorului
 * @param itemid        ID-ul itemului
 * @param slot          Slotul de echipament (M2_SLOT_*)
 */
forward m2_item_unequipped(id, itemid, slot);

/**
 * Apelat atunci cand un upgrade reuseste
 *
 * @param id            Indexul jucatorului
 * @param itemid        ID-ul itemului
 * @param new_upgrade   Noul nivel de upgrade
 */
forward m2_upgrade_success(id, itemid, new_upgrade);

/**
 * Apelat atunci cand un upgrade esueaza
 *
 * @param id            Indexul jucatorului
 * @param itemid        ID-ul itemului
 * @param destroyed     1 daca itemul a fost distrus, 0 daca doar a scazut nivelul
 */
forward m2_upgrade_fail(id, itemid, destroyed);

/**
 * Apelat atunci cand un jucator isi alege rasa
 *
 * @param id            Indexul jucatorului
 * @param race          Rasa aleasa (M2_RACE_*)
 */
forward m2_race_selected(id, race);

/**
 * Apelat atunci cand un jucator aloca un punct de statut
 *
 * @param id            Indexul jucatorului
 * @param stat_type     Tipul statului (M2_STAT_STR / HP / DEX / INT)
 */
forward m2_stat_allocated(id, stat_type);

/**
 * Apelat atunci cand un jucator invata / upgradeaza un skill
 *
 * @param id            Indexul jucatorului
 * @param skill_idx     Indexul skill-ului (0-19)
 * @param new_level     Noul nivel al skill-ului
 */
forward m2_skill_learned(id, skill_idx, new_level);

// ======================== STOCK-URI UTILE ========================

/**
 * Verifica daca jucatorul are o rasa aleasa
 *
 * @param id        Indexul jucatorului
 * @return          true daca are rasa, false altfel
 */
stock bool:m2_has_race(id)
{
	return (get_user_m2_race(id) != M2_RACE_NONE);
}

/**
 * Returneaza numele rasei
 *
 * @param race      ID-ul rasei
 * @param output    Buffer-ul de output
 * @param len       Lungimea buffer-ului
 */
stock m2_get_race_name(race, output[], len)
{
	static const race_names[][] = {
		"Nespecificat",
		"Razboinic",
		"Sura",
		"Ninja",
		"Saman"
	};
	
	if (race < 0 || race > 4)
	{
		copy(output, len, "Invalid");
		return;
	}
	
	copy(output, len, race_names[race]);
}

/**
 * Returneaza numele skill-ului dupa index
 *
 * @param skill_idx     Indexul skill-ului (0-19)
 * @param output        Buffer-ul de output
 * @param len           Lungimea buffer-ului
 */
stock m2_get_skill_name(skill_idx, output[], len)
{
	static const skill_names[20][] = {
		"Aura Sabiei", "Corp Rezistent", "Izbitura", "Atac Sabie", "Vartej Sabie",
		"Tais Vrajit", "Armura Vrajita", "Lovitura Degetului", "Atacul Fulgerului", "Pietrificare",
		"Camuflaj", "Atacul Fulgerator", "Ambush", "Otrava", "Ploaie de Sageti",
		"Lecuire", "Atac Intens", "Binecuvantare", "Iutesenie", "Chemarea Fulgerului"
	};
	
	if (skill_idx < 0 || skill_idx >= 20)
	{
		copy(output, len, "Invalid");
		return;
	}
	
	copy(output, len, skill_names[skill_idx]);
}

/**
 * Calculeaza XP-ul necesar pentru un anumit level
 *
 * @param level     Level-ul
 * @return          XP necesar
 */
stock m2_get_xp_needed(level)
{
	return 100 + (level * 75) + (level * level * 5);
}

/**
 * Returneaza rank-ul skill-ului sub forma de string (N1, M5, G3, P etc.)
 *
 * @param level     Nivelul skill-ului
 * @param output    Buffer-ul de output
 * @param len       Lungimea buffer-ului
 */
stock m2_get_skill_rank(level, output[], len)
{
	if (level <= 0)
		formatex(output, len, "0");
	else if (level < 20)
		formatex(output, len, "N%d", level);
	else if (level < 30)
		formatex(output, len, "M%d", level - 19);
	else if (level < 40)
		formatex(output, len, "G%d", level - 29);
	else
		formatex(output, len, "P");
}

/**
 * Verifica daca jucatorul este Warrior
 */
stock bool:m2_is_warrior(id)
{
	return (get_user_m2_race(id) == M2_RACE_WARRIOR);
}

/**
 * Verifica daca jucatorul este Sura
 */
stock bool:m2_is_sura(id)
{
	return (get_user_m2_race(id) == M2_RACE_SURA);
}

/**
 * Verifica daca jucatorul este Ninja
 */
stock bool:m2_is_ninja(id)
{
	return (get_user_m2_race(id) == M2_RACE_NINJA);
}

/**
 * Verifica daca jucatorul este Shaman
 */
stock bool:m2_is_shaman(id)
{
	return (get_user_m2_race(id) == M2_RACE_SHAMAN);
}

/**
 * Returneaza procentul de progres XP (0.0 - 100.0)
 *
 * @param id        Indexul jucatorului
 * @return          Procentul de progres
 */
stock Float:m2_get_xp_percent(id)
{
	new level = get_user_m2_level(id);
	new xp = get_user_m2_xp(id);
	new needed = m2_get_xp_needed(level);
	
	if (needed <= 0)
		return 0.0;
	
	return float(xp) / float(needed) * 100.0;
}

/**
 * Adauga Yang unui jucator (wrapper sigur)
 *
 * @param id        Indexul jucatorului
 * @param amount    Cantitatea de adaugat (poate fi negativa)
 * @return          1 la succes, 0 la esec
 */
stock m2_add_yang(id, amount)
{
	new current = get_user_m2_yang(id);
	new new_yang = current + amount;
	
	if (new_yang < 0)
		new_yang = 0;
	
	return set_user_m2_yang(id, new_yang);
}

/**
 * Adauga XP unui jucator (doar seteaza, nu face level-up automat - level-up-ul e gestionat de core)
 * Pentru level-up real foloseste set_user_m2_level sau lasa core-ul sa gestioneze prin kill-uri.
 *
 * @param id        Indexul jucatorului
 * @param amount    Cantitatea de XP de adaugat
 * @return          1 la succes, 0 la esec
 */
stock m2_add_xp(id, amount)
{
	new current = get_user_m2_xp(id);
	new new_xp = current + amount;
	
	if (new_xp < 0)
		new_xp = 0;
	
	return set_user_m2_xp(id, new_xp);
}

/**
 * Returneaza indexul de start al skill-urilor pentru o rasa
 * (Warrior = 0, Sura = 5, Ninja = 10, Shaman = 15)
 *
 * @param race      Rasa (M2_RACE_*)
 * @return          Indexul de start sau -1 daca rasa e invalida
 */
stock m2_get_race_skill_start(race)
{
	if (race < M2_RACE_WARRIOR || race > M2_RACE_SHAMAN)
		return -1;
	
	return (race - 1) * 5;
}

/**
 * Verifica daca un skill_idx apartine rasei specificate
 *
 * @param skill_idx     Indexul skill-ului
 * @param race          Rasa
 * @return              true daca skill-ul apartine rasei
 */
stock bool:m2_skill_belongs_to_race(skill_idx, race)
{
	new start = m2_get_race_skill_start(race);
	if (start == -1)
		return false;
	
	return (skill_idx >= start && skill_idx < start + 5);
}
