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

// ======================== TIPURI ITEME ========================
#define ITEM_WEAPON          1
#define ITEM_ARMOR           2
#define ITEM_HELMET          3
#define ITEM_SHIELD          4
#define ITEM_SHOES           5
#define ITEM_JEWEL           6
#define ITEM_POTION          7

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
 * Înregistrează un item nou.
 * Returnează ID-ul itemului (sau -1 la eroare).
 *
 * @param name         Numele itemului
 * @param type         ITEM_WEAPON / ITEM_ARMOR / ITEM_HELMET / ITEM_SHIELD / ITEM_SHOES / ITEM_JEWEL / ITEM_POTION
 * @param req_level    Level minim (rezervat pentru viitor)
 * @param race_req     0 = orice rasă, altfel RACE_*
 * @param str          Bonus STR
 * @param hp           Bonus HP / Defense
 * @param dex          Bonus DEX
 * @param intt         Bonus INT
 * @param crit         Bonus Crit
 * @param speed        Bonus Speed
 * @param price        Preț Yang (0 = nu apare în magazin)
 * @param potion_type  1 = HP Potion, 2 = MP Potion, orice alta valoare (ex 3+) = item custom:
 *                     nu are efect predefinit in core, dar la folosire declanseaza
 *                     forward-ul m2_item_used(id, itemid, potion_type) ca sa il tratezi din plugin propriu.
 */
native m2_register_item(const name[], type, req_level = 1, race_req = 0, str = 0, hp = 0, dex = 0, intt = 0, crit = 0, speed = 0, price = 0, potion_type = 0);

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

/**
 * Seteaza rasa jucatorului
 *
 * @param id        Indexul jucatorului
 * @param race      Rasa (M2_RACE_NONE / WARRIOR / SURA / NINJA / SHAMAN)
 * @return          1 la succes, 0 la esec
 */
native set_user_m2_race(id, race);

/**
 * Seteaza valoarea STR
 *
 * @param id        Indexul jucatorului
 * @param amount    Noua valoare (minim 1 recomandat)
 * @return          1 la succes, 0 la esec
 */
native set_user_m2_str(id, amount);

/**
 * Seteaza valoarea HP (stat)
 *
 * @param id        Indexul jucatorului
 * @param amount    Noua valoare (minim 1 recomandat)
 * @return          1 la succes, 0 la esec
 */
native set_user_m2_hp(id, amount);

/**
 * Seteaza valoarea DEX
 *
 * @param id        Indexul jucatorului
 * @param amount    Noua valoare (minim 1 recomandat)
 * @return          1 la succes, 0 la esec
 */
native set_user_m2_dex(id, amount);

/**
 * Seteaza valoarea INT
 *
 * @param id        Indexul jucatorului
 * @param amount    Noua valoare (minim 1 recomandat)
 * @return          1 la succes, 0 la esec
 */
native set_user_m2_int(id, amount);

/**
 * Seteaza mana curenta
 *
 * @param id        Indexul jucatorului
 * @param amount    Noua valoare (va fi clamp-uita la 0..MaxMP)
 * @return          1 la succes, 0 la esec
 */
native set_user_m2_mp(id, amount);

/**
 * Seteaza mana maxima
 *
 * @param id        Indexul jucatorului
 * @param amount    Noua valoare (minim 1)
 * @return          1 la succes, 0 la esec
 *
 * Nota: Daca setezi MaxMP sub MP curent, MP-ul va fi ajustat automat.
 */
native set_user_m2_maxmp(id, amount);

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
	static const skill_names[40][] = {
		// WARRIOR - Corporal (0-4) / Mental (5-9)
		"Aura Sabiei", "Corp Rezistent", "Izbitura", "Atac Sabie", "Vartej Sabie",
		"Lovitura Spiritului", "Scut Mental", "Valul de Putere", "Concentrare", "Explozie Interioara",
		
		// SURA - Arme Magice (10-14) / Magie Neagra (15-19)
		"Tais Vrajit", "Armura Vrajita", "Lovitura Degetului", "Atacul Fulgerului", "Pietrificare",
		"Flacara Intunecata", "Blestem", "Absorbtie de Suflet", "Umbre", "Invocarea Haosului",
		
		// NINJA - Lame (20-24) / Arc (25-29)
		"Camuflaj", "Atacul Fulgerator", "Ambush", "Otrava", "Dansul Lamelor",
		"Ploaie de Sageti", "Sageata Exploziva", "Tintire Precisa", "Sageata Otravita", "Val de Sageti",
		
		// SHAMAN - Zmeu/Dragon (30-34) / Fulger/Vindecare (35-39)
		"Chemarea Dragonului", "Flacara Dragonului", "Scut de Solzi", "Zborul Dragonului", "Furia Dragonului",
		"Lecuire", "Atac Intens", "Binecuvantare", "Iutesenie", "Chemarea Fulgerului"
	};
	
	if (skill_idx < 0 || skill_idx >= 40)
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
stock m2_get_race_skill_start(race, path = 1)
{
	if (race < M2_RACE_WARRIOR || race > M2_RACE_SHAMAN)
		return -1;
	
	if (path <= 0)
		path = 1;
	
	return (race - 1) * 10 + (path - 1) * 5;
}

/**
 * Verifica daca un skill_idx apartine rasei specificate
 *
 * @param skill_idx     Indexul skill-ului
 * @param race          Rasa
 * @param path          0 = verifica ambele cai, altfel PATH_A(1) / PATH_B(2)
 * @return              true daca skill-ul apartine rasei
 */
stock bool:m2_skill_belongs_to_race(skill_idx, race, path = 0)
{
	if (race < M2_RACE_WARRIOR || race > M2_RACE_SHAMAN)
		return false;
	
	if (path == 0) // verifică ambele căi
		return (skill_idx >= (race - 1) * 10 && skill_idx < race * 10);
	
	new start = m2_get_race_skill_start(race, path);
	if (start == -1)
		return false;
	
	return (skill_idx >= start && skill_idx < start + 5);
}

// ======================== NATIVES NOI (v1.3) ========================

// Slot-uri echipament: 0=Weapon, 1=Armor, 2=Helmet, 3=Shield, 4=Shoes, 5=Jewel

// Returnează item ID echipat pe slot (0 daca e gol)
native m2_get_user_equipped(id, slot);

// Returnează nivelul de upgrade al itemului echipat pe slot
native m2_get_user_equipped_upgrade(id, slot);

// Numărul de iteme din inventar
native m2_get_user_inventory_count(id);

// Item ID din slotul de inventar (0-based)
native m2_get_user_inventory_item(id, inv_slot);

// Upgrade-ul itemului din slotul de inventar
native m2_get_user_inventory_upgrade(id, inv_slot);

// 1 dacă jucătorul are itemul (echipat SAU în inventar)
native m2_user_has_item(id, itemid);

// Copiază numele itemului în buffer
native m2_get_item_name(itemid, buffer[], len);

// Tip item: 1=Weapon, 2=Armor, 3=Helmet, 4=Shield, 5=Shoes, 6=Jewel, 7=Potion
native m2_get_item_type(itemid);

// Prețul itemului din magazin
native m2_get_item_price(itemid);

// Câte iteme sunt înregistrate în total (inclusiv ID 0 = Gol)
native m2_get_item_count();

// Dă un item în inventar. upgrade opțional (default 0). Returnează 1 la succes
native m2_give_item(id, itemid, upgrade = 0);

// Scoate prima apariție a itemului din inventar (nu din echipat). Returnează 1 dacă a fost scos
native m2_remove_item(id, itemid);

// Stats totale (base + iteme + upgrade)
native m2_get_total_str(id);
native m2_get_total_hp(id);
native m2_get_total_dex(id);
native m2_get_total_int(id);


// ======================== FORWARDS NOI (v1.3) ========================

// Când un jucător cumpără un item din magazin
// id = jucător, itemid = ID item, price = preț plătit
forward m2_item_bought(id, itemid, price);

// Când un jucător folosește o poțiune
// id = jucător, itemid = ID item, potion_type = 1 (HP), 2 (MP), sau altul (custom, tratat de plugin extern)
forward m2_item_used(id, itemid, potion_type);

// ======================== NATIVES NOI (v1.4) ========================

/**
 * Forteaza (sau anuleaza) urmatorul upgrade al jucatorului sa reuseasca 100%.
 * Se consuma automat dupa o singura folosire a comenzii /upgrade (succes sau reset manual).
 *
 * @param id        Indexul jucatorului
 * @param enable    true = urmatorul upgrade e garantat, false = anuleaza garantia
 * @return          1 la succes, 0 daca jucatorul nu e conectat
 */
native m2_set_force_upgrade(id, bool:enable = true);

/**
 * Verifica daca jucatorul are activa garantia de succes la upgrade
 *
 * @param id        Indexul jucatorului
 * @return          true daca are garantia activa
 */
native bool:m2_get_force_upgrade(id);
