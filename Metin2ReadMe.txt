================================================================================
          METIN2 RPG CORE (CS 1.6) - GHID COMPLET & DOCUMENTAȚIE
          Versiune 1.1  |  Autor: Craxor
================================================================================

[0] IMPORTANT – CITIȚI ÎNAINTE DE TOATE!
--------------------------------------------------------------------------------
1. Fișierul compilat metin2Core.amxx TREBUIE să fie primul (sau printre primele)
   plugin-uri non-default din plugins.ini.

2. Orice plugin extern care folosește API-ul Metin2 (metin2_api.inc) TREBUIE
   să fie încărcat DUPĂ metin2Core.amxx.

3. Setati cvar-ul sv_maxspeed din amxx.cfg ca anumite puteri de speed sa functioneze.

--------------------------------------------------------------------------------
[1] DESPRE MOD   /   Tutorial complet pentru Playeri: https://elegant-marshmallow-424909.netlify.app/
--------------------------------------------------------------------------------
Metin2 RPG Core transformă serverul clasic de Counter-Strike 1.6 într-un RPG
complet inspirat din Metin2.

Jucătorii pot:
- Alege una din cele 4 rase (Războinic, Sura, Ninja, Șaman)
- Alege una din cele 2 căi de skill-uri pe rasă (total 8 căi / 40 skill-uri)
- Face Level-Up omorând adversari
- Aloca puncte de Statut (STR, HP, DEX, INT)
- Învăța și folosi skill-uri active
- Cumpăra, echipa și upgrada iteme (+0 → +9)
- Folosi economie Yang + sistem de Mana (MP) cu regenerare

Sistemul include salvare automată (nVault Array), protecție împotriva
schimbării numelui și un API complet pentru dezvoltatori.

--------------------------------------------------------------------------------
[2] CERINȚE TEHNICE
--------------------------------------------------------------------------------
- Counter-Strike 1.6 Server
- AMX Mod X 1.10 sau mai nou
- ReAPI + ReGameDLL_CS
- Module obligatorii: reapi, fakemeta, hamsandwich, fun, nvault, nvault_array

Link-uri utile:
- AMX Mod X: https://www.amxmodx.org/downloads.php
- ReAPI: https://github.com/rehlds/ReAPI
- nVault Array: https://forums.alliedmods.net/showthread.php?t=291662

--------------------------------------------------------------------------------
[3] INSTALARE PAS CU PAS
--------------------------------------------------------------------------------
1. Copiați metin2Core.sma în:
   addons/amxmodx/scripting/

2. Copiați metin2_api.inc în:
   addons/amxmodx/scripting/include/

3. Compilați metin2Core.sma
   (amxxpc local sau compilator online)

4. Mutați fișierul generat metin2Core.amxx în:
   addons/amxmodx/plugins/

5. Deschideți addons/amxmodx/configs/plugins.ini
   și adăugați linia (cât mai sus posibil, după plugin-urile default):
   metin2Core.amxx

6. (Opțional) Adăugați cvar-urile din secțiunea [5] în amxx.cfg

7. Schimbați harta sau dați restart serverului.

--------------------------------------------------------------------------------
[4] COMENZI
--------------------------------------------------------------------------------
Comenzi Chat (jucători):
  /menu  sau  /metin2     → Meniu Principal
  /stats  sau  /statut    → Alocare puncte de Statut
  /skills                 → Meniu Skill-uri (calea aleasă)
  /inventar  sau  /inv    → Inventar & Echipament
  /upgrade  sau  /fierar  → Fierar (Upgrade iteme)
  /shop  sau  /magazin    → Magazin
  /binds                  → Ghid bind-uri
  /reset                  → Resetează rasa + stats + skill-uri
                            (păstrează Level, XP, Yang, Inventar, Echipament)

Comenzi Consolă (pentru bind-uri):
  skill1                  → Activează Skill 1
  skill2                  → Activează Skill 2
  skill3                  → Activează Skill 3
  skill4                  → Activează Skill 4
  skill5                  → Activează Skill 5

Comenzi Admin (FLAG A):
  amx_set_level <nume/#userid> <level>
  amx_set_xp <nume/#userid> <xp>
  amx_set_statuspoints <nume/#userid> <puncte>
  amx_set_skillpoints <nume/#userid> <puncte>
  amx_set_yang <nume/#userid> <yang>

--------------------------------------------------------------------------------
[5] CVAR-URI
--------------------------------------------------------------------------------
Adaugă în amxx.cfg sau server.cfg:

amx_metin2_xp_kill "100"                 // XP pe kill
amx_metin2_xp_hs_bonus "50"              // XP bonus Headshot
amx_metin2_yang_kill "500"               // Yang pe kill
amx_metin2_yang_hs_bonus "250"           // Yang bonus Headshot
amx_metin2_upgrade_fail_destroy "1"      // 1 = itemul se distruge la fail
                                         // 0 = doar scade nivelul

--------------------------------------------------------------------------------
[6] RASE & CĂI DE SKILL-URI
--------------------------------------------------------------------------------
Fiecare rasă are 2 căi (Path A și Path B). După ce alegi rasa, trebuie să alegi
calea. Abia după ce ai calea poți învăța skill-uri.

┌─────────────┬──────────────────────┬──────────────────────┐
│ Rasă        │ Path A               │ Path B               │
├─────────────┼──────────────────────┼──────────────────────┤
│ Războinic   │ Corporal             │ Mental               │
│ Sura        │ Arme Magice          │ Magie Neagră         │
│ Ninja       │ Lame (Cuțite)        │ Arc                  │
│ Șaman       │ Zmeu (Dragon)        │ Fulger (Vindecare)   │
└─────────────┴──────────────────────┴──────────────────────┘

--------------------------------------------------------------------------------
[7] LISTA COMPLETĂ A SKILL-URILOR (40)
--------------------------------------------------------------------------------

=== RĂZBOINIC – Corporal (Path A) ===
1. Aura Sabiei          – Bonus masiv de daune
2. Corp Rezistent       – Reducere daune (până la 55%)
3. Izbitura             – Stun / înghețare țintă
4. Atac Sabie           – Dash rapid înainte
5. Vârtej Sabie         – Atac AoE circular

=== RĂZBOINIC – Mental (Path B) ===
1. Lovitura Spiritului  – Daune magice single-target
2. Scut Mental          – Reducere daune temporară
3. Valul de Putere      – AoE + knockback
4. Concentrare          – Buff damage + următorul atac CRIT x2
5. Explozie Interioară  – AoE puternic (costă puțin HP)

=== SURA – Arme Magice (Path A) ===
1. Tăiș Vrăjit          – Daune magice amplificate de INT
2. Armură Vrăjită       – Reflectă 35% din daune
3. Lovitura Degetului   – Armor Pierce (ignoră până la 70% apărare)
4. Atacul Fulgerului    – Încetinește ținta
5. Pietrificare         – Stun + slow rezidual

=== SURA – Magie Neagră (Path B) ===
1. Flacăra Întunecată   – Damage + DoT
2. Blestem              – Slow + debuff
3. Absorbție de Suflet  – Damage + lifesteal
4. Umbre                – Almost invis + speed
5. Invocarea Haosului   – AoE dark puternic

=== NINJA – Lame / Cuțite (Path A) ===
1. Camuflaj             – Stealth aproape total
2. Atacul Fulgerător    – Viteza extremă
3. Ambush               – Următorul atac = CRIT x3
4. Otrava               – DoT pe țintă
5. Dansul Lamelor       – AoE melee

=== NINJA – Arc (Path B) ===
1. Ploaie de Săgeți     – AoE la distanță
2. Săgeată Explozivă    – Damage + mic AoE
3. Țintire Precisă      – Următorul atac CRIT x3
4. Săgeată Otrăvită     – DoT puternic
5. Val de Săgeți        – AoE rapid pe rază mare

=== ȘAMAN – Zmeu / Dragon (Path A) ===
1. Chemarea Dragonului  – (placeholder / custom)
2. Flacăra Dragonului   – (placeholder / custom)
3. Scut de Solzi        – (placeholder / custom)
4. Zborul Dragonului    – (placeholder / custom)
5. Furia Dragonului     – (placeholder / custom)

=== ȘAMAN – Fulger / Vindecare (Path B) ===
1. Lecuire              – Vindecare HP puternică
2. Atac Intens          – Buff de daune
3. Binecuvântare        – Bonus apărare mare
4. Iuteșenie            – Resetează toate cooldown-urile
5. Chemarea Fulgerului  – Flash + șansă de stun în zonă

Notă: Skill-urile de pe Path A la Șaman (Zmeu) pot fi personalizate ulterior.
Skill-urile de pe Path B sunt deja funcționale.

--------------------------------------------------------------------------------
[8] ATRIBUTE (STATUT)
--------------------------------------------------------------------------------
STR (Forță)       → Crește daunele fizice
HP  (Viață)       → +10 HP maxim per punct
DEX (Agilitate)   → Crește apărarea nativă
INT (Inteligență) → +8 Max MP per punct + putere skill-uri magice + regenerare MP

La fiecare Level-Up primești:
- +1 Punct de Statut
- +1 Punct de Skill

--------------------------------------------------------------------------------
[9] ITEME, MAGAZIN & FIERAR
--------------------------------------------------------------------------------
Sloturi de echipament:
  0 = Armă
  1 = Armură
  2 = Coif
  3 = Scut
  4 = Papuci
  5 = Bijuterie

Magazinul conține iteme default (arme, armuri, coifuri, scuturi, papuci,
bijuterii și licori HP/MP). Poți adăuga iteme noi din alte plugin-uri
folosind native-ul m2_register_item.

Fierar (Upgrade):
- Itemele pot fi upgradate de la +0 până la +9
- Fiecare nivel de upgrade dă bonusuri suplimentare
- Șansa de succes scade odată cu nivelul
- Dacă upgrade-ul eșuează și cvar-ul este 1 → itemul este distrus

--------------------------------------------------------------------------------
[10] API PENTRU DEZVOLTATORI
--------------------------------------------------------------------------------
Include: #include <metin2_api>

Natives disponibile:
  m2_register_item(...)
  get_user_m2_level(id)          /  set_user_m2_level(id, level)
  get_user_m2_xp(id)             /  set_user_m2_xp(id, xp)
  get_user_m2_yang(id)           /  set_user_m2_yang(id, yang)
  get_user_m2_race(id)           /  set_user_m2_race(id, race)
  get_user_m2_str(id)            /  set_user_m2_str(id, amount)
  get_user_m2_hp(id)             /  set_user_m2_hp(id, amount)
  get_user_m2_dex(id)            /  set_user_m2_dex(id, amount)
  get_user_m2_int(id)            /  set_user_m2_int(id, amount)
  get_user_m2_mp(id)             /  set_user_m2_mp(id, amount)
  get_user_m2_maxmp(id)          /  set_user_m2_maxmp(id, amount)

Forwards:
  m2_skill_used(id, skill_idx, skill_level)
  m2_level_up(id, new_level)
  m2_player_kill(killer, victim, xp, yang)
  m2_item_equipped(id, itemid, slot)
  m2_item_unequipped(id, itemid, slot)
  m2_upgrade_success(id, itemid, new_upgrade)
  m2_upgrade_fail(id, itemid, destroyed)
  m2_race_selected(id, race)
  m2_stat_allocated(id, stat_type)
  m2_skill_learned(id, skill_idx, new_level)

Constante utile:
  M2_RACE_NONE, M2_RACE_WARRIOR, M2_RACE_SURA, M2_RACE_NINJA, M2_RACE_SHAMAN
  M2_SLOT_WEAPON ... M2_SLOT_JEWEL
  M2_STAT_STR, M2_STAT_HP, M2_STAT_DEX, M2_STAT_INT
  ITEM_WEAPON ... ITEM_POTION

--------------------------------------------------------------------------------
[11] SFATURI & NOTE
--------------------------------------------------------------------------------
- Meniurile de Stats și Skills rămân deschise până apeși 0 (Exit).
- Dacă un jucător nu are rasă, pe HUD apare mesajul:
  "Scrie /menu sau /metin2 ca sa-ti alegi caracterul si sa incepi jocul!"
- Skill-urile consumă Mana. Cooldown-ul scade pe măsură ce upgradezi skill-ul.
- /reset șterge rasa, calea, stats și skill-uri, dar păstrează Level, XP, Yang
  și tot inventarul/echipamentul.

================================================================================
          Sfârșitul documentației – Metin2 RPG Core v1.1
================================================================================
