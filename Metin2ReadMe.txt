================================================================================
                    METIN2 RPG CORE (CS 1.6) - GHID COMPLET & DOCUMENTATIE
================================================================================
[0]
IMPORTANT , INAINTE DE TOATE!
--------------------------------------------------------------------------------
Fisierul metin2Core.amxx odata ce e compilat, trebuie sa fie PRIMUL SCRIS CAT MAI SUS in plugins.ini inainte
oricarui alt plugin inafara celor amxx default. 

Orice plugin Extern care foloseste metin2 api trebuie sa fie intodeauna sub metin2Core.amxx ! ! !
--------------------------------------------------------------------------------

[1] DESPRE MOD / DESCRIERE GENERALA
--------------------------------------------------------------------------------
Plugin-ul 'Metin2RPG Core' transforma serverul clasic de Counter-Strike 1.6 intr-un 
RPG interactiv bazat pe mecanicile jocului Metin2. Jucatorii pot sa isi aleaga 
o rasa (Razboinic, Sura, Ninja, Saman), sa faca Level-Up omorand adversari, sa 
aloce puncte de Statut (STR, HP, DEX, INT), sa invete si sa foloseasca Skill-uri 
active/pasive, sa cumpere si sa ecipeze Iteme din Magazin si sa le imbunatateasca 
la Fierar (Upgrade +1 pana la +9).

Sistemul include economie de Yang, bara de Mana (MP) cu regenerare automata, 
un sistem dinamic de iteme extensibil prin API/Natives, salvare automata prin 
nVault Array si securitate impotriva schimbarii numelui in timpul jocului.

--------------------------------------------------------------------------------
[2] INSTALARE & CERINȚE TEHNICE
--------------------------------------------------------------------------------
Cerințe de Sistem / Cerințe Mod:
 - Server Counter-Strike 1.6
 - AMX Mod X versiunea 1.10 sau mai noua: https://www.amxmodx.org/downloads.php
 - ReAPI (HookChain & ReGamedll): 
		https://github.com/rehlds/ReAPI  
		https://github.com/rehlds/ReGameDLL_CS
 - Module AMXX active: nvault, nvault_array, fakemeta, hamsandwich, fun, reapi
	Nvault Array: https://forums.alliedmods.net/showthread.php?t=291662

Pasi de Instalare:
 1. Descarca / Copiaza fisierul sursa 'metin2_rpg.sma' in directorul:
    addons/amxmodx/scripting/

 2. Copiaza fisierul include 'metin2_rpg.inc' in directorul:
    addons/amxmodx/scripting/include/

 3. Compileaza plugin-ul 'metin2_rpg.sma'.
    (Poti folosi compilatorul local amxxpc sau cel online).

 4. Muta fisierul compilat 'metin2_rpg.amxx' din 'scripting/compiled/' in:
    addons/amxmodx/plugins/

 5. Deschide fisierul:
    addons/amxmodx/configs/plugins.ini
    si adauga la sfarsitul fisierului linia:
    metin2_rpg.amxx

 6. Schimba harta sau da restart la server (amx_rcon restart / map).

--------------------------------------------------------------------------------
[3] TOATE COMENZILE DIN JOC (CHAT & CONSOLA)
--------------------------------------------------------------------------------
Comenzi Chat pentru Jucatori (se scriu in chat cu / sau fara /):
 - /menu, /metin2    : Deschide Meniul Principal Metin2.
 - /stats, /statut   : Deschide meniul de alocare a punctelor de Statut (STR, HP, DEX, INT).
 - /skills           : Deschide meniul de Skill-uri (alocare puncte & nivel skill).
 - /inventar, /inv   : Deschide inventarul cu itemele detinute si echipate.
 - /upgrade, /fierar : Deschide meniul Fierarului pentru imbunatatirea itemelor.
 - /shop, /magazin   : Deschide Magazinul de unde poti cumpara arme, armuri, accesorii si licori.
 - /binds            : Afiseaza ghidul si comenzile pentru setarea tastelor rapide (binds).
 - /reset            : Reseteaza rasa, statusurile si skill-urile (pastreaza Lvl, XP, Yang, Echipament).

Comenzi Consola pentru Jucatori (pentru Bind-uri):
 - skill1            : Activeaza Skill-ul 1 al rasei tale.
 - skill2            : Activeaza Skill-ul 2 al rasei tale.
 - skill3            : Activeaza Skill-ul 3 al rasei tale.
 - skill4            : Activeaza Skill-ul 4 al rasei tale.
 - skill5            : Activeaza Skill-ul 5 al rasei tale.

Comenzi Administrative (Consola / AMX Admin cu acces FLAG A):
 - amx_set_level <nume/#userid> <level>        : Seteaza nivelul direct al unui jucator (1-999).
 - amx_set_xp <nume/#userid> <xp>              : Seteaza valoarea exacta de XP a unui jucator.
 - amx_set_statuspoints <nume/#userid> <puncte>: Seteaza numarul de Puncte Statut disponibile.
 - amx_set_skillpoints <nume/#userid> <puncte> : Seteaza numarul de Puncte Skill disponibile.
 - amx_set_yang <nume/#userid> <yang>          : Seteaza cantitatea de Yang detinuta de un jucator.

--------------------------------------------------------------------------------
[4] CVAR-URI (SETARI SERVER)
--------------------------------------------------------------------------------
Setarile pot fi adaugate sau modificate in 'amxmodx/configs/amxx.cfg':

 - amx_metin2_xp_kill <numar>         (Default: 100)
   Cantitatea de XP primita pentru fiecare eliminare de jucator.

 - amx_metin2_xp_hs_bonus <numar>     (Default: 50)
   XP bonus acordat daca eliminarea a fost facuta prin Headshot.

 - amx_metin2_yang_kill <numar>       (Default: 500)
   Cantitatea de Yang primita la fiecare kill.

 - amx_metin2_yang_hs_bonus <numar>   (Default: 250)
   Yang bonus acordat pentru uciderea inamicilor prin Headshot.

 - amx_metin2_upgrade_fail_destroy <0|1> (Default: 1)
   Setare Fierar: 1 = Itemul se distruge complet daca upgrade-ul esueaza.
                  0 = Itemul doar scade in nivel / ramane la fel (in functie de logica extinsa).

--------------------------------------------------------------------------------
[5] RASE, SKILL-URI SI MECANICI DE JOC
--------------------------------------------------------------------------------
1. RASE DISPONIBILE:
 - Razboinic : Axat pe atac fizic ridicat, rezistenta la daune si stuns.
 - Sura      : Imbina atacurile magice cu protectia, reflectarea daunelor si penetrarea armurii.
 - Ninja     : Infiltrator rapid cu stealth, viteza sporita, critice x3 (Ambush) si otrava.
 - Saman     : Sustinere si magie: vindecare HP, buff de aparare, resetare cooldowns si stun/flash.

2. LISTA SKILL-URI PER RASA:
 * Razboinic:
   - Skill 1: Aura Sabiei (Bonus masiv de daune bazat pe nivel)
   - Skill 2: Corp Rezistent (Reducere procentuala de daune de pana la 55%)
   - Skill 3: Izbitura (Ingheata/Stuneaza tinta tintita)
   - Skill 4: Atac Sabie (Dash rapid inainte)
   - Skill 5: Vartej Sabie (Atac AoE circular pe o raza definita)

 * Sura:
   - Skill 1: Tais Vrajit (Daune magice amplificate de INT)
   - Skill 2: Armura Vrajita (Reflecta 35% din daunele primite inapoi la atacator)
   - Skill 3: Lovitura Degetului (Armor Pierce: ignora pana la 70% din apararea tintei)
   - Skill 4: Atacul Fulgerului (Incetineste viteza de deplasare a tintei la 110)
   - Skill 5: Pietrificare (Stun complet + slow rezidual dupa unfreeze)

 * Ninja:
   - Skill 1: Camuflaj (Transparenata aproape totala - stealth)
   - Skill 2: Atacul Fulgerator (Viteza extrema de deplasare)
   - Skill 3: Ambush (Urmatorul atac aplicat devine CRITIC cu daune x3)
   - Skill 4: Otrava (Daune periodice in timp / DoT pe tinta)
   - Skill 5: Ploaie de Sageti (Atac AoE la distanta)

 * Saman:
   - Skill 1: Lecuire (Vindeca HP-ul propriu calculat dupa INT si nivel skill)
   - Skill 2: Atac Intens (Buff temporar de daune)
   - Skill 3: Binecuvantare (Ofera aparare suplimentara masiva)
   - Skill 4: Iutesenie (Reseteaza instant cooldown-urile tuturor celorlalte skill-uri)
   - Skill 5: Chemarea Fulgerului (Efect de orbire/flash + sansa de stun in zona)

3. ATRIBUTE / STATUT:
 - STR (Forță)     : Crește daunele fizice aplicate.
 - HP (Viata)      : Oferă +10 Viata maxima per punct alocat.
 - DEX (Agilitate) : Mareste apararea nativa si scala abilitatile de Ninja.
 - INT (Inteligenta): Crește Mana Maxima (+8 MP/punct), viteza de regenerare MP si puterea skill-urilor magice.

--------------------------------------------------------------------------------
[6] ITEME, MAGAZIN & FIERAR (UPGRADE)
--------------------------------------------------------------------------------
Sistem de Echipament:
 Jucatorii pot echipa pana la 6 sloturi:
 [0] Arma | [1] Armura | [2] Coif | [3] Scut | [4] Papuci | [5] Bijuterii

Magazin (Shop):
 De unde se pot achizitiona iteme default (Luna Plina, Armura Posedata, Scut Titan, 
 Cercei de Abanos, Lichior HP/MP etc.) in schimbul monedei Yang.

Fierar (Upgrade):
 Itemele pot fi imbunatatite de la +0 pana la +9. Fiecare nivel de upgrade adauga 
 bonusuri suplimentare la stats, HP sau viteza. Atentie: Daca upgrade-ul esueaza si 
 cvar-ul 'amx_metin2_upgrade_fail_destroy' este 1, itemul va fi distrus!

--------------------------------------------------------------------------------
[7] API PENTRU DEVOLOPERI (NATIVES & FORWARDS)
--------------------------------------------------------------------------------
Plugin-ul ofera o librarie completa 'metin2_rpg' pentru a permite altor plugin-uri 
sa interactioneze cu modul:

Natives principale:
 - m2_register_item(...) : Inregistreaza dinamice iteme noi in magazin/joc.
 - get_user_m2_level(id) / set_user_m2_level(id, level)
 - get_user_m2_xp(id) / set_user_m2_xp(id, xp)
 - get_user_m2_yang(id) / set_user_m2_yang(id, yang)
 - get_user_m2_race(id)
 - get_user_m2_str(id), get_user_m2_hp(id), get_user_m2_dex(id), get_user_m2_int(id)
 - get_user_m2_mp(id), get_user_m2_maxmp(id)

Forwards disponibile:
 - m2_skill_used(id, skill_idx, skill_level)
 - m2_level_up(id, new_level)
 - m2_player_kill(killer, victim, xp, yang)
 - m2_item_equipped(id, itemid, slot)
 - m2_item_unequipped(id, itemid, slot)
 - m2_upgrade_success(id, itemid, new_upgrade)
 - m2_upgrade_fail(id, itemid, destroyed)
 - m2_race_selected(id, race)
 - m2_stat_allocated(id, stat_type)
 - m2_skill_learned(id, skill_idx, new_level)

================================================================================
