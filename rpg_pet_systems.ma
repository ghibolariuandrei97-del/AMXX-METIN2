#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <cstrike>
#include <engine>
#include <fun>
#include <xs>

#define PLUGIN  "RPG Pet System"
#define VERSION "1.6"
#define AUTHOR  "Grok"

#define MAX_PETS            61
#define MAX_PET_LEVEL       25
#define PET_CLASSNAME       "rpg_pet_entity"
#define TASK_BOT_ASSIGN     55300
#define TASK_DELAYED_SPAWN  55400
#define TASK_HUD            55500

enum _:PetData
{
    PET_NAME[32],
    PET_MODEL[64],
    PET_BONUS_TYPE,
    Float:PET_BASE_VALUE,
    PET_COST
}

new const g_Pets[MAX_PETS][PetData] =
{
    { "Polar Bear",            "models/bear_polarbear_sitting.mdl",              0,   5.0,    8000 },
    { "Black Cat",             "models/cat_black_animated.mdl",                  2,   6.0,    0    },
    { "Raptor",                "models/dinosaur_raptor_green.mdl",               3,   2.0,    200000},
    { "Stegosaurus",           "models/dinosaur_steggasaurus.mdl",               1,   8.0,    100000},
    { "Dark Horse",            "models/horse_darkbrown.mdl",                     2,   8.0,    30000 },
    { "Light Horse",           "models/horse_lightbrown.mdl",                    4,   0.08,   10000 },
    { "Giant Spider",          "models/spider_giant_brown.mdl",                  3,   2.5,    25000 },
    { "Scorpion",              "models/scorpion_large.mdl",                      5,   1.5,    10000 },
    { "Shark",                 "models/shark.mdl",                               0,   7.0,    8500 },
    { "Monkey",                "models/monkey_readingpaper.mdl",                 6,   100.0,  0    },
    { "Zombie Dog",            "models/dog_zombie.mdl",                          3,   3.0,    7500 },
    { "Brown Rabbit",          "models/rabbit_brown.mdl",                        2,   10.0,   0    },
    { "Deer",                  "models/deer_doe_animated.mdl",                   4,   0.10,   3000 },
    { "Cow",                   "models/cow_multicolored.mdl",                    1,   10.0,   0    },
    { "Penguin",               "models/bird_penguin_walking.mdl",                7,   3.0,    0    },
    { "Eagle",                 "models/bird_eagle_animated.mdl",                 2,   7.0,    4000 },
    { "Xenomorph",             "models/alien_xenomorph.mdl",                     3,   4.0,    15000},
    { "Alligator",             "models/alligator_green.mdl",                     0,   6.0,    5500 },
    { "Camel",                 "models/cheap_camel.mdl",                         1,   12.0,   0    },
    { "Green Dino",            "models/cheap_dinoaur_green.mdl",                 0,   9.0,    6500 },
    { "Husky",                 "models/cheap_dog_huskie.mdl",                    2,   9.0,    0    },
    { "Gold Fish",             "models/cheap_fish_gold.mdl",                     6,   80.0,   0    },
    { "Butterfly",             "models/insect_butterfly_flying.mdl",             4,   0.12,   0    },
    { "Dragonfly",             "models/insect_dragonfly_flying.mdl",             8,   80.0,   2500 },
    { "Lobster",               "models/lobster.mdl",                             1,   9.0,    3500 },
    { "Giant Red Spider",      "models/spider_giant_redpruple.mdl",              3,   3.5,    60000},
    { "Snake",                 "models/snake.mdl",                               5,   2.0,    0    },
    { "Goomba",                "models/goomba.mdl",                              7,   4.0,    0    },
    { "Alien Beast",           "models/alien_beast.mdl",                         0,   8.0,    30000},
    { "Alien Beast 2",         "models/alien_beast2.mdl",                        3,   3.0,    20000},
    { "Alien Bird",            "models/alien_bird.mdl",                          2,   8.0,    15000},
    { "Alien Fish",            "models/alien_fish.mdl",                          0,   6.0,    5000 },
    { "Baby Headcrab",         "models/alien_insect_babyheadcrab.mdl",           5,   1.8,    0    },
    { "Green Insect",          "models/alien_insect_green.mdl",                  3,   2.2,    6000 },
    { "Brown Alligator",       "models/alligator_brown.mdl",                     0,   6.5,    5500 },
    { "Bats",                  "models/bats.mdl",                                4,   0.09,   0    },
    { "Chicken",               "models/bird_chicken_pecking.mdl",                7,   3.5,    0    },
    { "Crane",                 "models/bird_crane.mdl",                          2,   7.5,    3500 },
    { "Crow",                  "models/bird_crow.mdl",                           2,   6.5,    0    },
    { "Crows Flock",           "models/bird_crows_animated.mdl",                 2,   7.0,    2000 },
    { "Quail",                 "models/bird_quail.mdl",                          7,   3.0,    0    },
    { "Seagull",               "models/bird_seagull_animated.mdl",               2,   6.0,    0    },
    { "Vulture",               "models/bird_vulture_flying.mdl",                 3,   2.0,    4000 },
    { "HQ Chicken",            "models/chicken_hq.mdl",                          1,   8.0,    0    },
    { "Herbivore Dino",        "models/dinosaur_herbivore_grey.mdl",             1,   11.0,   9000 },
    { "Blue Fish",             "models/fish_blue_swimming.mdl",                  6,   70.0,   0    },
    { "Grey Fish",             "models/fish_grey_animated.mdl",                  6,   60.0,   0    },
    { "Large Fish",            "models/fish_large.mdl",                          0,   5.5,    3000 },
    { "Pink Fish",             "models/fish_pink_swimming.mdl",                  6,   75.0,   0    },
    { "Piranha",               "models/fish_pirannah_animated.mdl",              3,   2.8,    6500 },
    { "Shark Fin",             "models/fish_shark_fin_swimming.mdl",             0,   4.0,    0    },
    { "Sheep",                 "models/cheap_sheep.mdl",                         1,   9.0,    0    },
    { "Roach",                 "models/cheap_insect_roach.mdl",                  5,   1.2,    0    },
    { "Brown Rat",             "models/rat_brown_animated.mdl",                  5,   1.5,    0    },
    { "Black Spider",          "models/spider_giant_black.mdl",                  3,   3.0,    8000 },
    { "Tiger Shark",           "models/sharkT.mdl",                              0,   8.0,    9500 },
    { "Cheap Horse",           "models/cheap_horse_brown.mdl",                   2,   7.0,    0    },
    { "Green Butterfly",       "models/insect_butterfly_green_flying.mdl",       4,   0.11,   0    },
    { "Pink Dragonfly",        "models/insect_dragonfly_pink_flying.mdl",        8,   70.0,   2000 },
    { "Green Dragonfly",       "models/insect_dragonfly_green_flying.mdl",       8,   70.0,   2000 },
    { "Landed Butterfly",      "models/insect_butterfly_landed.mdl",             4,   0.10,   0    }
}

new const g_BonusKeys[9][] =
{
    "PET_BONUS_HP", "PET_BONUS_ARMOR", "PET_BONUS_SPEED", "PET_BONUS_DAMAGE",
    "PET_BONUS_GRAVITY", "PET_BONUS_REGEN", "PET_BONUS_MONEY", "PET_BONUS_CLIP", "PET_BONUS_JUMP"
}

new const SOUND_SELECT[]     = "items/gunpickup2.wav"
new const SOUND_LEVELUP[]    = "plats/elevbell1.wav"
new const SOUND_SPAWN[]      = "items/suitchargeok1.wav"
new const SOUND_DENY[]       = "common/wpn_denyselect.wav"
new const SOUND_REMOVE[]     = "common/wpn_hudoff.wav"
new const SOUND_PET_ATTACK[] = "weapons/knife_hit3.wav"
new const SOUND_PET_DIE[]    = "common/bodydrop3.wav"
new const SOUND_PET_PAIN[]   = "player/pl_pain2.wav"

new g_iPetType[33]
new g_iPetLevel[33]
new g_iPetXP[33]
new g_iPetEntity[33]
new g_iPetEnemy[33]
new Float:g_flPetHealth[33]
new Float:g_flNextPetAttack[33]
new Float:g_flNextRegen[33]
new Float:g_flHudTime[33]
new bool:g_bHasChosen[33]
new bool:g_bPetAlive[33]

new cvar_enabled, cvar_bot_pets, cvar_max_level
new cvar_xp_per_kill, cvar_xp_base, cvar_xp_scale
new cvar_pet_distance, cvar_pet_speed, cvar_cost_multiplier
new cvar_pet_attack_range, cvar_pet_attack_delay
new cvar_pet_base_hp, cvar_pet_base_dmg
new cvar_pet_vision_range, cvar_pet_close_range, cvar_pet_fov

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)
    register_dictionary("rpg_pet_system.txt")
    
    register_clcmd("say /pet",       "Cmd_PetMenu")
    register_clcmd("say_team /pet",  "Cmd_PetMenu")
    register_clcmd("say /mypet",     "Cmd_MyPet")
    register_clcmd("say /petlevel",  "Cmd_PetLevel")
    register_clcmd("say /petinfo",   "Cmd_PetInfo")
    register_clcmd("say /removepet", "Cmd_RemovePet")
    register_clcmd("say /changepet", "Cmd_ChangePet")
    register_concmd("amx_petlevel", "Cmd_AdminPetLevel", ADMIN_KICK, "<name> <level 1-25>")
    
    RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn", 1)
    RegisterHam(Ham_Killed, "player", "OnPlayerKilled", 1)
    RegisterHam(Ham_TakeDamage, "player", "OnPlayerTakeDamage")
    
    register_forward(FM_TraceLine, "FW_TraceLine", 1)
    register_forward(FM_PlayerPreThink, "FW_PlayerPreThink")
    
    register_event("HLTV", "OnNewRound", "a", "1=0", "2=0")
    register_logevent("OnRoundStart", 2, "1=Round_Start")
    
    register_think(PET_CLASSNAME, "Pet_Think")
    
    cvar_enabled          = register_cvar("rpg_pet_enabled", "1")
    cvar_bot_pets         = register_cvar("rpg_pet_bots", "1")
    cvar_max_level        = register_cvar("rpg_pet_maxlevel", "25")
    cvar_xp_per_kill      = register_cvar("rpg_pet_xp_per_kill", "1")
    cvar_xp_base          = register_cvar("rpg_pet_xp_base", "5")
    cvar_xp_scale         = register_cvar("rpg_pet_xp_scale", "3")
    cvar_pet_distance     = register_cvar("rpg_pet_distance", "80.0")
    cvar_pet_speed        = register_cvar("rpg_pet_speed", "250.0")
    cvar_cost_multiplier  = register_cvar("rpg_pet_cost_mult", "1.0")
    cvar_pet_attack_range = register_cvar("rpg_pet_attack_range", "90.0")
    cvar_pet_attack_delay = register_cvar("rpg_pet_attack_delay", "0.9")
    cvar_pet_base_hp      = register_cvar("rpg_pet_base_hp", "40")
    cvar_pet_base_dmg     = register_cvar("rpg_pet_base_dmg", "5")
    cvar_pet_vision_range = register_cvar("rpg_pet_vision_range", "1200.0")
    cvar_pet_close_range  = register_cvar("rpg_pet_close_range", "350.0")
    cvar_pet_fov          = register_cvar("rpg_pet_fov", "90.0")
    
    set_task(1.0, "Task_ApplyRegen", _, _, _, "b")
}

public plugin_precache()
{
    for(new i = 0; i < MAX_PETS; i++)
    {
        if(file_exists(g_Pets[i][PET_MODEL]))
            precache_model(g_Pets[i][PET_MODEL])
        else
            log_amx("[RPG Pet] WARNING: Model not found: %s", g_Pets[i][PET_MODEL])
    }
    precache_sound(SOUND_SELECT)
    precache_sound(SOUND_LEVELUP)
    precache_sound(SOUND_SPAWN)
    precache_sound(SOUND_DENY)
    precache_sound(SOUND_REMOVE)
    precache_sound(SOUND_PET_ATTACK)
    precache_sound(SOUND_PET_DIE)
    precache_sound(SOUND_PET_PAIN)
    precache_model("sprites/steam1.spr")
}

public plugin_cfg()
{
    for(new i = 1; i <= 32; i++)
        ResetPlayerPet(i)
}

public client_putinserver(id)
{
    ResetPlayerPet(id)
    if(is_user_bot(id) && get_pcvar_num(cvar_bot_pets))
        set_task(2.0 + float(id) * 0.15, "Task_AssignBotPet", id + TASK_BOT_ASSIGN)
}

public client_disconnected(id)
{
    RemovePetEntity(id)
    ResetPlayerPet(id)
    remove_task(id + TASK_BOT_ASSIGN)
    remove_task(id + TASK_DELAYED_SPAWN)
}

stock ResetPlayerPet(id)
{
    g_iPetType[id] = -1
    g_iPetLevel[id] = 1
    g_iPetXP[id] = 0
    g_iPetEntity[id] = 0
    g_iPetEnemy[id] = 0
    g_flPetHealth[id] = 0.0
    g_bHasChosen[id] = false
    g_bPetAlive[id] = false
    g_flNextRegen[id] = 0.0
    g_flNextPetAttack[id] = 0.0
    g_flHudTime[id] = 0.0
}

public Task_AssignBotPet(taskid)
{
    new id = taskid - TASK_BOT_ASSIGN
    if(!is_user_connected(id) || !is_user_bot(id) || g_iPetType[id] != -1)
        return
    
    new freePets[MAX_PETS], freeCount
    for(new i = 0; i < MAX_PETS; i++)
        if(GetPetCost(i) == 0)
            freePets[freeCount++] = i
    
    if(freeCount < 1) return
    
    g_iPetType[id] = freePets[random_num(0, freeCount - 1)]
    g_iPetLevel[id] = random_num(3, 10)
    g_iPetXP[id] = 0
    g_bHasChosen[id] = true
    g_bPetAlive[id] = true
    
    if(is_user_alive(id))
    {
        SpawnPet(id)
        ApplyPetBonus(id)
    }
}

stock GetPetCost(pet)
{
    return floatround(float(g_Pets[pet][PET_COST]) * get_pcvar_float(cvar_cost_multiplier))
}

// HP = max(free_base, cost * 10%) * (1 + (level-1) * 0.15)
// DMG = max(free_base_dmg, cost * 1%) * (1 + (level-1) * 0.12)
// Example cost 1000: L1 = 100 HP / 10 DMG ; L10 ≈ 235 HP / 20 DMG
stock GetPetMaxHP(id)
{
    if(g_iPetType[id] < 0)
        return 50
    
    new cost = GetPetCost(g_iPetType[id])
    new level = g_iPetLevel[id]
    
    // 10% of price, minimum for free pets
    new baseHP = cost / 10
    if(baseHP < get_pcvar_num(cvar_pet_base_hp))
        baseHP = get_pcvar_num(cvar_pet_base_hp)
    
    // scale with level
    new Float:mult = 1.0 + float(level - 1) * 0.15
    return floatround(float(baseHP) * mult)
}

stock Float:GetPetDamage(id)
{
    if(g_iPetType[id] < 0)
        return 5.0
    
    new cost = GetPetCost(g_iPetType[id])
    new level = g_iPetLevel[id]
    
    // 1% of price, minimum for free pets
    new Float:baseDmg = float(cost) * 0.01
    new Float:minDmg = float(get_pcvar_num(cvar_pet_base_dmg))
    if(baseDmg < minDmg)
        baseDmg = minDmg
    
    new Float:mult = 1.0 + float(level - 1) * 0.12
    return baseDmg * mult
}

stock Pet_PrintLang(id, const key[], any:...)
{
    new szMsg[191], temp[191]
    LookupLangKey(temp, charsmax(temp), key, id)
    vformat(szMsg, charsmax(szMsg), temp, 3)
    replace_all(szMsg, charsmax(szMsg), "!g", "^4")
    replace_all(szMsg, charsmax(szMsg), "!y", "^1")
    replace_all(szMsg, charsmax(szMsg), "!t", "^3")
    message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("SayText"), _, id)
    write_byte(id)
    write_string(szMsg)
    message_end()
}

// ======================== COMMANDS ========================

public Cmd_PetMenu(id)
{
    if(!get_pcvar_num(cvar_enabled))
    {
        Pet_PrintLang(id, "PET_DISABLED")
        client_cmd(id, "spk %s", SOUND_DENY)
        return PLUGIN_HANDLED
    }
    if(g_bHasChosen[id] && g_iPetType[id] != -1)
    {
        Pet_PrintLang(id, "PET_ALREADY_CHOSEN")
        client_cmd(id, "spk %s", SOUND_DENY)
        ShowMyPetInfo(id)
        return PLUGIN_HANDLED
    }
    ShowPetSelectMenu(id, false)
    return PLUGIN_HANDLED
}

public Cmd_ChangePet(id)
{
    if(!get_pcvar_num(cvar_enabled))
    {
        Pet_PrintLang(id, "PET_DISABLED")
        return PLUGIN_HANDLED
    }
    ShowPetSelectMenu(id, true)
    return PLUGIN_HANDLED
}

public Cmd_RemovePet(id)
{
    if(g_iPetType[id] == -1)
    {
        Pet_PrintLang(id, "PET_NO_PET")
        client_cmd(id, "spk %s", SOUND_DENY)
        return PLUGIN_HANDLED
    }
    RemovePetEntity(id)
    g_iPetType[id] = -1
    g_iPetLevel[id] = 1
    g_iPetXP[id] = 0
    g_bHasChosen[id] = false
    g_bPetAlive[id] = false
    g_iPetEnemy[id] = 0
    Pet_PrintLang(id, "PET_REMOVED")
    client_cmd(id, "spk %s", SOUND_REMOVE)
    return PLUGIN_HANDLED
}

public Cmd_MyPet(id)
{
    ShowMyPetInfo(id)
    return PLUGIN_HANDLED
}

public Cmd_PetLevel(id)
{
    if(g_iPetType[id] == -1)
    {
        Pet_PrintLang(id, "PET_NO_PET")
        return PLUGIN_HANDLED
    }
    new needed = GetXPNeeded(g_iPetLevel[id])
    Pet_PrintLang(id, "PET_LEVEL_INFO", g_Pets[g_iPetType[id]][PET_NAME], g_iPetLevel[id], get_pcvar_num(cvar_max_level))
    Pet_PrintLang(id, "PET_XP_INFO", g_iPetXP[id], needed)
    return PLUGIN_HANDLED
}

public Cmd_PetInfo(id)
{
    Pet_PrintLang(id, "PET_HELP_1")
    Pet_PrintLang(id, "PET_HELP_2")
    Pet_PrintLang(id, "PET_HELP_3")
    Pet_PrintLang(id, "PET_HELP_4")
    return PLUGIN_HANDLED
}

public Cmd_AdminPetLevel(id, level, cid)
{
    if(!cmd_access(id, level, cid, 3))
        return PLUGIN_HANDLED
    
    new targetName[32], levelStr[8]
    read_argv(1, targetName, charsmax(targetName))
    read_argv(2, levelStr, charsmax(levelStr))
    
    new target = cmd_target(id, targetName, CMDTARGET_OBEY_IMMUNITY | CMDTARGET_ALLOW_SELF)
    if(!target) return PLUGIN_HANDLED
    
    new newLevel = clamp(str_to_num(levelStr), 1, get_pcvar_num(cvar_max_level))
    if(g_iPetType[target] == -1)
    {
        client_print(id, print_console, "[Pet] Target has no pet.")
        return PLUGIN_HANDLED
    }
    
    g_iPetLevel[target] = newLevel
    g_iPetXP[target] = 0
    g_flPetHealth[target] = float(GetPetMaxHP(target))
    ApplyPetBonus(target)
    
    Pet_PrintLang(target, "PET_LEVEL_UP", g_iPetLevel[target])
    client_cmd(target, "spk %s", SOUND_LEVELUP)
    client_print(id, print_console, "[Pet] Set pet level to %d", newLevel)
    return PLUGIN_HANDLED
}

stock GetXPNeeded(level)
{
    return get_pcvar_num(cvar_xp_base) + (level - 1) * get_pcvar_num(cvar_xp_scale)
}

stock AddPetXP(id, amount)
{
    if(g_iPetType[id] == -1 || g_iPetLevel[id] >= get_pcvar_num(cvar_max_level))
        return
    
    g_iPetXP[id] += amount
    new needed = GetXPNeeded(g_iPetLevel[id])
    
    while(g_iPetXP[id] >= needed && g_iPetLevel[id] < get_pcvar_num(cvar_max_level))
    {
        g_iPetXP[id] -= needed
        g_iPetLevel[id]++
        
        Pet_PrintLang(id, "PET_LEVEL_UP", g_iPetLevel[id])
        client_cmd(id, "spk %s", SOUND_LEVELUP)
        
        message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("ScreenFade"), _, id)
        write_short(1<<10)
        write_short(1<<10)
        write_short(0x0000)
        write_byte(0)
        write_byte(255)
        write_byte(100)
        write_byte(60)
        message_end()
        
        g_flPetHealth[id] = float(GetPetMaxHP(id))
        if(is_user_alive(id))
            ApplyPetBonus(id)
        
        needed = GetXPNeeded(g_iPetLevel[id])
    }
}

public ShowPetSelectMenu(id, bool:isChange)
{
    new title[64]
    formatex(title, charsmax(title), "%L", id, isChange ? "PET_MENU_CHANGE" : "PET_MENU_TITLE")
    new menu = menu_create(title, "Menu_PetSelect")
    new szItem[128], szNum[16], cost
    
    for(new i = 0; i < MAX_PETS; i++)
    {
        cost = GetPetCost(i)
        if(cost <= 0)
            formatex(szItem, charsmax(szItem), "%s  \y[%L] \r[FREE]", g_Pets[i][PET_NAME], id, g_BonusKeys[g_Pets[i][PET_BONUS_TYPE]])
        else
            formatex(szItem, charsmax(szItem), "%s  \y[%L] \r[$%d]", g_Pets[i][PET_NAME], id, g_BonusKeys[g_Pets[i][PET_BONUS_TYPE]], cost)
        formatex(szNum, charsmax(szNum), "%d %d", i, isChange ? 1 : 0)
        menu_additem(menu, szItem, szNum)
    }
    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
    menu_setprop(menu, MPROP_NUMBER_COLOR, "\y")
    menu_display(id, menu, 0)
}

public Menu_PetSelect(id, menu, item)
{
    if(item == MENU_EXIT || !is_user_connected(id))
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    
    new data[16], name[64], access, callback
    menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback)
    
    new sPet[8], sChange[8]
    parse(data, sPet, charsmax(sPet), sChange, charsmax(sChange))
    new pet = str_to_num(sPet)
    new isChange = str_to_num(sChange)
    
    if(!isChange && g_bHasChosen[id] && g_iPetType[id] != -1)
    {
        Pet_PrintLang(id, "PET_ALREADY_CHOSEN")
        client_cmd(id, "spk %s", SOUND_DENY)
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    
    new cost = GetPetCost(pet)
    if(cost > 0)
    {
        new money = cs_get_user_money(id)
        if(money < cost)
        {
            Pet_PrintLang(id, "PET_NOT_ENOUGH_MONEY", cost, money)
            client_cmd(id, "spk %s", SOUND_DENY)
            menu_destroy(menu)
            return PLUGIN_HANDLED
        }
        cs_set_user_money(id, money - cost)
        Pet_PrintLang(id, "PET_PAID", cost)
    }
    
    if(g_iPetType[id] != -1)
        RemovePetEntity(id)
    
    g_iPetType[id] = pet
    g_iPetLevel[id] = 1
    g_iPetXP[id] = 0
    g_bHasChosen[id] = true
    g_bPetAlive[id] = true
    g_iPetEnemy[id] = 0
    g_flPetHealth[id] = float(GetPetMaxHP(id))
    
    Pet_PrintLang(id, "PET_SELECTED", g_Pets[pet][PET_NAME])
    Pet_PrintLang(id, "PET_LEVEL_START", g_iPetLevel[id])
    client_cmd(id, "spk %s", SOUND_SELECT)
    
    if(is_user_alive(id))
    {
        SpawnPet(id)
        ApplyPetBonus(id)
        client_cmd(id, "spk %s", SOUND_SPAWN)
    }
    menu_destroy(menu)
    return PLUGIN_HANDLED
}

stock ShowMyPetInfo(id)
{
    if(g_iPetType[id] == -1)
    {
        Pet_PrintLang(id, "PET_NO_PET")
        return
    }
    new pet = g_iPetType[id]
    new level = g_iPetLevel[id]
    new Float:value = CalculateBonus(pet, level)
    new needed = GetXPNeeded(level)
    
    Pet_PrintLang(id, "PET_INFO_HEADER")
    Pet_PrintLang(id, "PET_INFO_NAME", g_Pets[pet][PET_NAME])
    Pet_PrintLang(id, "PET_INFO_LEVEL", level, get_pcvar_num(cvar_max_level))
    Pet_PrintLang(id, "PET_XP_INFO", g_iPetXP[id], needed)
    Pet_PrintLang(id, "PET_COMBAT_INFO", floatround(g_flPetHealth[id]), GetPetMaxHP(id), floatround(GetPetDamage(id)))
    
    switch(g_Pets[pet][PET_BONUS_TYPE])
    {
        case 0: Pet_PrintLang(id, "PET_BONUS_HP_VAL", floatround(value))
        case 1: Pet_PrintLang(id, "PET_BONUS_ARMOR_VAL", floatround(value))
        case 2: Pet_PrintLang(id, "PET_BONUS_SPEED_VAL", floatround(value))
        case 3: Pet_PrintLang(id, "PET_BONUS_DAMAGE_VAL", floatround(value))
        case 4: Pet_PrintLang(id, "PET_BONUS_GRAVITY_VAL", value)
        case 5: Pet_PrintLang(id, "PET_BONUS_REGEN_VAL", floatround(value))
        case 6: Pet_PrintLang(id, "PET_BONUS_MONEY_VAL", floatround(value))
        case 7: Pet_PrintLang(id, "PET_BONUS_CLIP_VAL", floatround(value))
        case 8: Pet_PrintLang(id, "PET_BONUS_JUMP_VAL", floatround(value))
    }
}

public OnPlayerSpawn(id)
{
    if(!is_user_alive(id) || g_iPetType[id] == -1)
        return
    g_bPetAlive[id] = true
    g_iPetEnemy[id] = 0
    g_flPetHealth[id] = float(GetPetMaxHP(id))
    set_task(0.35, "Task_DelayedSpawnPet", id + TASK_DELAYED_SPAWN)
}

public Task_DelayedSpawnPet(taskid)
{
    new id = taskid - TASK_DELAYED_SPAWN
    if(!is_user_alive(id) || g_iPetType[id] == -1 || !g_bPetAlive[id])
        return
    SpawnPet(id)
    ApplyPetBonus(id)
    client_cmd(id, "spk %s", SOUND_SPAWN)
}

public OnPlayerKilled(victim, attacker, shouldgib)
{
    RemovePetEntity(victim)
    g_iPetEnemy[victim] = 0
    
    // Clear this victim as enemy for all pets
    for(new i = 1; i <= 32; i++)
    {
        if(g_iPetEnemy[i] == victim)
            g_iPetEnemy[i] = 0
    }
    
    if(get_pcvar_num(cvar_xp_per_kill) && is_user_connected(attacker) && attacker != victim)
    {
        if(g_iPetType[attacker] != -1)
            AddPetXP(attacker, get_pcvar_num(cvar_xp_per_kill))
    }
}

public OnNewRound() {}
public OnRoundStart()
{
    for(new i = 1; i <= 32; i++)
        if(is_user_alive(i) && g_iPetType[i] != -1)
            ApplyPetBonus(i)
}

// ======================== SPAWN PET (NO COLLISION) ========================

stock SpawnPet(id)
{
    RemovePetEntity(id)
    if(g_iPetType[id] < 0 || g_iPetType[id] >= MAX_PETS)
        return
    
    new Float:origin[3], Float:angles[3]
    pev(id, pev_origin, origin)
    pev(id, pev_angles, angles)
    
    origin[0] -= floatcos(angles[1], degrees) * 50.0
    origin[1] -= floatsin(angles[1], degrees) * 50.0
    origin[2] += 5.0
    
    new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
    if(!pev_valid(ent))
        return
    
    set_pev(ent, pev_classname, PET_CLASSNAME)
    engfunc(EngFunc_SetModel, ent, g_Pets[g_iPetType[id]][PET_MODEL])
    engfunc(EngFunc_SetSize, ent, Float:{-16.0, -16.0, -8.0}, Float:{16.0, 16.0, 36.0})
    
    set_pev(ent, pev_origin, origin)
    set_pev(ent, pev_angles, angles)
    
    // NO collision with players - you walk through the pet
    set_pev(ent, pev_movetype, MOVETYPE_NOCLIP)
    set_pev(ent, pev_solid, SOLID_NOT)
    set_pev(ent, pev_takedamage, DAMAGE_NO)  // damage handled manually
    
    if(g_flPetHealth[id] <= 0.0)
        g_flPetHealth[id] = float(GetPetMaxHP(id))
    
    set_pev(ent, pev_owner, id)
    set_pev(ent, pev_sequence, 0)
    set_pev(ent, pev_framerate, 1.0)
    set_pev(ent, pev_animtime, get_gametime())
    set_pev(ent, pev_nextthink, get_gametime() + 0.1)
    
    g_iPetEntity[id] = ent
    g_bPetAlive[id] = true
}

stock RemovePetEntity(id)
{
    if(pev_valid(g_iPetEntity[id]))
    {
        set_pev(g_iPetEntity[id], pev_flags, FL_KILLME)
        engfunc(EngFunc_RemoveEntity, g_iPetEntity[id])
    }
    g_iPetEntity[id] = 0
}

// ======================== PET THINK ========================

public Pet_Think(ent)
{
    if(!pev_valid(ent))
        return
    
    new id = pev(ent, pev_owner)
    
    if(!is_user_connected(id) || !is_user_alive(id) || g_iPetEntity[id] != ent || !g_bPetAlive[id])
    {
        set_pev(ent, pev_flags, FL_KILLME)
        engfunc(EngFunc_RemoveEntity, ent)
        return
    }
    
    if(g_flPetHealth[id] <= 0.0)
    {
        KillPet(id, ent)
        return
    }
    
    new enemy = g_iPetEnemy[id]
    
    // Validate enemy - must be alive + opposite team
    if(enemy >= 1 && enemy <= 32)
    {
        if(!is_user_alive(enemy) || !is_user_connected(enemy) || cs_get_user_team(enemy) == cs_get_user_team(id))
        {
            g_iPetEnemy[id] = 0
            enemy = 0
        }
    }
    else
        enemy = 0
    
    // Auto-acquire target if none:
    // - enemies in visual FOV of owner
    // - OR enemies close to owner (even if not seen)
    if(enemy <= 0)
    {
        enemy = FindEnemyForPet(id)
        if(enemy > 0)
            g_iPetEnemy[id] = enemy
    }
    
    new Float:petOrigin[3], Float:targetOrigin[3], Float:dir[3], Float:velocity[3], Float:angles[3]
    pev(ent, pev_origin, petOrigin)
    
    new Float:speed = get_pcvar_float(cvar_pet_speed)
    new Float:desiredDist = get_pcvar_float(cvar_pet_distance)
    new Float:attackRange = get_pcvar_float(cvar_pet_attack_range)
    
    if(enemy > 0)
    {
        // ===== CHASE & ATTACK ENEMY =====
        pev(enemy, pev_origin, targetOrigin)
        xs_vec_sub(targetOrigin, petOrigin, dir)
        new Float:dist = xs_vec_len(dir)
        
        if(dist > 1.0)
            xs_vec_normalize(dir, dir)
        dir[2] = 0.0
        if(xs_vec_len(dir) > 0.1)
            xs_vec_normalize(dir, dir)
        
        if(dist > attackRange)
        {
            // Run toward enemy
            velocity[0] = dir[0] * speed * 1.2
            velocity[1] = dir[1] * speed * 1.2
            velocity[2] = (targetOrigin[2] + 12.0 - petOrigin[2]) * 3.0
        }
        else
        {
            // In range - attack
            velocity[0] = 0.0
            velocity[1] = 0.0
            velocity[2] = (targetOrigin[2] + 8.0 - petOrigin[2]) * 2.0
            
            if(get_gametime() >= g_flNextPetAttack[id])
            {
                new Float:dmg = GetPetDamage(id)
                
                // Deal real damage
                new Float:health = float(get_user_health(enemy))
                if(health > 0.0)
                {
                    // Use fakedamage / set health for reliability
                    new newhp = floatround(health - dmg)
                    if(newhp <= 0)
                    {
                        // Kill via Ham so it counts properly
                        ExecuteHamB(Ham_Killed, enemy, id, 0)
                    }
                    else
                    {
                        set_user_health(enemy, newhp)
                        // Blood effect
                        message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
                        write_byte(TE_BLOODSTREAM)
                        write_coord(floatround(targetOrigin[0]))
                        write_coord(floatround(targetOrigin[1]))
                        write_coord(floatround(targetOrigin[2] + 20.0))
                        write_coord(random_num(-20, 20))
                        write_coord(random_num(-20, 20))
                        write_coord(random_num(20, 50))
                        write_byte(70)
                        write_byte(floatround(dmg * 2.0))
                        message_end()
                    }
                }
                
                emit_sound(ent, CHAN_WEAPON, SOUND_PET_ATTACK, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
                g_flNextPetAttack[id] = get_gametime() + get_pcvar_float(cvar_pet_attack_delay)
            }
        }
        
        set_pev(ent, pev_velocity, velocity)
        vector_to_angle(dir, angles)
        angles[0] = 0.0
        set_pev(ent, pev_angles, angles)
    }
    else
    {
        // ===== FOLLOW OWNER =====
        pev(id, pev_origin, targetOrigin)
        xs_vec_sub(targetOrigin, petOrigin, dir)
        new Float:dist = xs_vec_len(dir)
        
        if(dist > 1.0)
            xs_vec_normalize(dir, dir)
        dir[2] = 0.0
        if(xs_vec_len(dir) > 0.1)
            xs_vec_normalize(dir, dir)
        
        if(dist > desiredDist + 10.0)
        {
            velocity[0] = dir[0] * speed
            velocity[1] = dir[1] * speed
            velocity[2] = (targetOrigin[2] + 10.0 - petOrigin[2]) * 2.0
        }
        else if(dist < desiredDist - 15.0)
        {
            velocity[0] = -dir[0] * (speed * 0.4)
            velocity[1] = -dir[1] * (speed * 0.4)
            velocity[2] = 0.0
        }
        else
        {
            velocity[0] = 0.0
            velocity[1] = 0.0
            velocity[2] = (targetOrigin[2] + 8.0 - petOrigin[2]) * 1.5
        }
        
        set_pev(ent, pev_velocity, velocity)
        vector_to_angle(dir, angles)
        angles[0] = 0.0
        set_pev(ent, pev_angles, angles)
    }
    
    set_pev(ent, pev_nextthink, get_gametime() + 0.1)
}


// Find best enemy for pet
stock FindEnemyForPet(id)
{
    if(!is_user_alive(id))
        return 0

    new Float:ownerOrigin[3]
    new Float:vForward[3]
    new Float:enemyOrigin[3]
    new Float:dir[3]
    new Float:dist
    new Float:dot
    new Float:visionRange
    new Float:closeRange
    new Float:fov
    new Float:halfFovCos
    new Float:bestVisibleDist
    new Float:bestCloseDist
    new bestVisible
    new bestClose
    new enemy

    pev(id, pev_origin, ownerOrigin)
    velocity_by_aim(id, 1, vForward)

    visionRange = get_pcvar_float(cvar_pet_vision_range)
    closeRange = get_pcvar_float(cvar_pet_close_range)
    fov = get_pcvar_float(cvar_pet_fov)
    halfFovCos = floatcos(fov * 3.14159265 / 360.0)

    bestVisible = 0
    bestClose = 0
    bestVisibleDist = 99999.0
    bestCloseDist = 99999.0

    for(enemy = 1; enemy <= 32; enemy++)
    {
        if(enemy == id)
            continue
        if(!is_user_connected(enemy))
            continue
        if(!is_user_alive(enemy))
            continue
        if(cs_get_user_team(enemy) == cs_get_user_team(id))
            continue

        pev(enemy, pev_origin, enemyOrigin)
        dist = get_distance_f(ownerOrigin, enemyOrigin)
        if(dist < 1.0)
            dist = 1.0

        if(dist <= closeRange)
        {
            if(dist < bestCloseDist)
            {
                bestCloseDist = dist
                bestClose = enemy
            }
        }

        if(dist <= visionRange)
        {
            dir[0] = (enemyOrigin[0] - ownerOrigin[0]) / dist
            dir[1] = (enemyOrigin[1] - ownerOrigin[1]) / dist
            dir[2] = (enemyOrigin[2] - ownerOrigin[2]) / dist

            dot = vForward[0] * dir[0] + vForward[1] * dir[1] + vForward[2] * dir[2]

            if(dot >= halfFovCos)
            {
                if(dist < bestVisibleDist)
                {
                    bestVisibleDist = dist
                    bestVisible = enemy
                }
            }
        }
    }

    if(bestVisible > 0)
        return bestVisible
    if(bestClose > 0)
        return bestClose

    return 0
}




// ======================== SET ENEMY WHEN OWNER ATTACKS ========================

public OnPlayerTakeDamage(victim, inflictor, attacker, Float:damage, damagebits)
{
    if(!is_user_connected(attacker) || attacker == victim)
        return HAM_IGNORED
    
    // Passive damage bonus from pet (attacker has pet with damage bonus)
    if(g_iPetType[attacker] != -1 && g_Pets[g_iPetType[attacker]][PET_BONUS_TYPE] == 3)
    {
        new Float:bonusPct = CalculateBonus(g_iPetType[attacker], g_iPetLevel[attacker])
        SetHamParamFloat(4, damage * (1.0 + bonusPct / 100.0))
    }
    
    if(!is_user_alive(victim) || !is_user_connected(victim))
        return HAM_IGNORED
    
    if(cs_get_user_team(victim) == cs_get_user_team(attacker))
        return HAM_IGNORED
    
    // 1) Owner attacks enemy → pet targets that enemy
    if(g_bPetAlive[attacker] && g_iPetType[attacker] != -1 && pev_valid(g_iPetEntity[attacker]))
        g_iPetEnemy[attacker] = victim
    
    // 2) Enemy shoots / damages owner → pet immediately targets that attacker
    if(g_bPetAlive[victim] && g_iPetType[victim] != -1 && pev_valid(g_iPetEntity[victim]))
        g_iPetEnemy[victim] = attacker
    
    return HAM_IGNORED
}

// ======================== DAMAGE PET WHEN SHOT (TraceLine) ========================

public FW_TraceLine(Float:start[3], Float:end[3], conditions, id, trace)
{
    if(id < 1 || id > 32)
        return FMRES_IGNORED
    if(!is_user_alive(id))
        return FMRES_IGNORED
    if(!(pev(id, pev_button) & IN_ATTACK))
        return FMRES_IGNORED
    
    // Rate limit per player so one bullet does not multi-hit every frame
    static Float:lastShot[33]
    new Float:now = get_gametime()
    if(now < lastShot[id] + 0.08)
        return FMRES_IGNORED
    
    new Float:hitOrigin[3]
    get_tr2(trace, TR_vecEndPos, hitOrigin)
    
    new weapon = get_user_weapon(id)
    new Float:dmg = GetWeaponPetDamage(weapon)
    
    new owner
    for(owner = 1; owner <= 32; owner++)
    {
        if(!g_bPetAlive[owner])
            continue
        if(g_iPetType[owner] == -1)
            continue
        if(!pev_valid(g_iPetEntity[owner]))
            continue
        if(owner == id)
            continue
        if(cs_get_user_team(owner) == cs_get_user_team(id))
            continue
        
        new Float:petOrigin[3]
        pev(g_iPetEntity[owner], pev_origin, petOrigin)
        petOrigin[2] += 16.0
        
        // 1) Near impact point
        new Float:dHit = get_distance_f(hitOrigin, petOrigin)
        
        // 2) Near the bullet line (start -> hit) - catches pets that bullets "pass near"
        new Float:dLine = DistancePointToLine(petOrigin, start, hitOrigin)
        
        if(dHit > 55.0 && dLine > 40.0)
            continue
        
        DamagePet(owner, id, dmg)
        lastShot[id] = now
        break
    }
    
    return FMRES_IGNORED
}

stock Float:GetWeaponPetDamage(weapon)
{
    switch(weapon)
    {
        case CSW_AWP: return 95.0
        case CSW_SCOUT: return 55.0
        case CSW_G3SG1, CSW_SG550: return 50.0
        case CSW_M249: return 28.0
        case CSW_AK47, CSW_M4A1, CSW_AUG, CSW_SG552, CSW_GALIL, CSW_FAMAS: return 24.0
        case CSW_MP5NAVY, CSW_MAC10, CSW_TMP, CSW_P90, CSW_UMP45: return 16.0
        case CSW_DEAGLE: return 40.0
        case CSW_USP, CSW_GLOCK18, CSW_P228, CSW_FIVESEVEN, CSW_ELITE: return 18.0
        case CSW_M3, CSW_XM1014: return 32.0
        case CSW_KNIFE: return 45.0
        case CSW_HEGRENADE: return 70.0
    }
    return 18.0
}

// Distance from point P to segment AB
stock Float:DistancePointToLine(Float:p[3], Float:a[3], Float:b[3])
{
    new Float:ab[3], Float:ap[3]
    ab[0] = b[0] - a[0]
    ab[1] = b[1] - a[1]
    ab[2] = b[2] - a[2]
    ap[0] = p[0] - a[0]
    ap[1] = p[1] - a[1]
    ap[2] = p[2] - a[2]
    
    new Float:abLen2 = ab[0]*ab[0] + ab[1]*ab[1] + ab[2]*ab[2]
    if(abLen2 < 1.0)
        return get_distance_f(p, a)
    
    new Float:t = (ap[0]*ab[0] + ap[1]*ab[1] + ap[2]*ab[2]) / abLen2
    if(t < 0.0) t = 0.0
    if(t > 1.0) t = 1.0
    
    new Float:closest[3]
    closest[0] = a[0] + ab[0] * t
    closest[1] = a[1] + ab[1] * t
    closest[2] = a[2] + ab[2] * t
    
    return get_distance_f(p, closest)
}

public FW_PlayerPreThink(id)
{
    if(!is_user_alive(id))
        return FMRES_IGNORED
    
    if(!(pev(id, pev_button) & IN_ATTACK))
        return FMRES_IGNORED
    
    if(get_user_weapon(id) != CSW_KNIFE)
        return FMRES_IGNORED
    
    static Float:lastKnife[33]
    if(get_gametime() < lastKnife[id] + 0.45)
        return FMRES_IGNORED
    
    new Float:origin[3]
    new Float:aim[3]
    new Float:end[3]
    pev(id, pev_origin, origin)
    origin[2] += 16.0
    velocity_by_aim(id, 70, aim)
    end[0] = origin[0] + aim[0]
    end[1] = origin[1] + aim[1]
    end[2] = origin[2] + aim[2]
    
    new owner
    for(owner = 1; owner <= 32; owner++)
    {
        if(!g_bPetAlive[owner] || !pev_valid(g_iPetEntity[owner]))
            continue
        if(cs_get_user_team(owner) == cs_get_user_team(id) || owner == id)
            continue
        
        new Float:petOrigin[3]
        pev(g_iPetEntity[owner], pev_origin, petOrigin)
        
        if(get_distance_f(end, petOrigin) < 55.0 || get_distance_f(origin, petOrigin) < 60.0)
        {
            DamagePet(owner, id, 45.0)
            lastKnife[id] = get_gametime()
            break
        }
    }
    
    return FMRES_IGNORED
}

stock DamagePet(owner, attacker, Float:dmg)
{
    if(!g_bPetAlive[owner] || g_flPetHealth[owner] <= 0.0)
        return
    
    g_flPetHealth[owner] -= dmg
    
    if(is_user_alive(attacker))
        g_iPetEnemy[owner] = attacker
    
    new Float:origin[3]
    if(pev_valid(g_iPetEntity[owner]))
    {
        pev(g_iPetEntity[owner], pev_origin, origin)
        emit_sound(g_iPetEntity[owner], CHAN_BODY, SOUND_PET_PAIN, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
        
        // Blood spray effect
        message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
        write_byte(TE_BLOODSTREAM)
        write_coord(floatround(origin[0]))
        write_coord(floatround(origin[1]))
        write_coord(floatround(origin[2] + 20.0))
        write_coord(random_num(-30, 30))
        write_coord(random_num(-30, 30))
        write_coord(random_num(20, 60))
        write_byte(70)
        write_byte(floatround(dmg * 1.5))
        message_end()
        
        // Sparks
        message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
        write_byte(TE_SPARKS)
        write_coord(floatround(origin[0]))
        write_coord(floatround(origin[1]))
        write_coord(floatround(origin[2] + 15.0))
        message_end()
    }
    
    ShowPetHud(attacker, owner)
    ShowPetHud(owner, owner)
    
    if(g_flPetHealth[owner] <= 0.0)
    {
        g_flPetHealth[owner] = 0.0
        if(pev_valid(g_iPetEntity[owner]))
            KillPet(owner, g_iPetEntity[owner])
    }
}

stock KillPet(id, ent)
{
    new Float:origin[3]
    if(pev_valid(ent))
    {
        pev(ent, pev_origin, origin)
        emit_sound(ent, CHAN_BODY, SOUND_PET_DIE, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
        
        // Big blood
        message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
        write_byte(TE_BLOODSTREAM)
        write_coord(floatround(origin[0]))
        write_coord(floatround(origin[1]))
        write_coord(floatround(origin[2] + 20.0))
        write_coord(0)
        write_coord(0)
        write_coord(80)
        write_byte(70)
        write_byte(150)
        message_end()
        
        // Smoke puff
        message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
        write_byte(TE_SMOKE)
        write_coord(floatround(origin[0]))
        write_coord(floatround(origin[1]))
        write_coord(floatround(origin[2]) + 10)
        write_short(engfunc(EngFunc_ModelIndex, "sprites/steam1.spr"))
        write_byte(12)
        write_byte(10)
        message_end()
        
        // Implosion
        message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
        write_byte(TE_IMPLOSION)
        write_coord(floatround(origin[0]))
        write_coord(floatround(origin[1]))
        write_coord(floatround(origin[2]) + 10)
        write_byte(50)
        write_byte(20)
        write_byte(5)
        message_end()
        
        set_pev(ent, pev_flags, FL_KILLME)
        engfunc(EngFunc_RemoveEntity, ent)
    }
    
    g_iPetEntity[id] = 0
    g_bPetAlive[id] = false
    g_iPetEnemy[id] = 0
    g_flPetHealth[id] = 0.0
    
    if(is_user_connected(id))
        Pet_PrintLang(id, "PET_DIED")
}

stock ShowPetHud(viewer, owner)
{
    if(!is_user_connected(viewer) || g_iPetType[owner] < 0)
        return
    
    if(get_gametime() < g_flHudTime[viewer] + 0.12)
        return
    g_flHudTime[viewer] = get_gametime()
    
    new maxhp = GetPetMaxHP(owner)
    new curhp = floatround(g_flPetHealth[owner])
    if(curhp < 0)
        curhp = 0
    
    set_hudmessage(255, 40, 40, -1.0, 0.32, 0, 0.0, 1.6, 0.05, 0.25, -1)
    show_hudmessage(viewer, "* %s^nLevel %d  |  HP %d / %d  |  DMG %d",
        g_Pets[g_iPetType[owner]][PET_NAME],
        g_iPetLevel[owner],
        curhp,
        maxhp,
        floatround(GetPetDamage(owner)))
}


// ======================== OWNER BONUSES ========================

stock Float:CalculateBonus(pet, level)
{
    return g_Pets[pet][PET_BASE_VALUE] * float(level)
}

stock ApplyPetBonus(id)
{
    if(!is_user_alive(id) || g_iPetType[id] == -1)
        return
    
    new pet = g_iPetType[id]
    new level = g_iPetLevel[id]
    new Float:value = CalculateBonus(pet, level)
    
    switch(g_Pets[pet][PET_BONUS_TYPE])
    {
        case 0:
            set_user_health(id, get_user_health(id) + floatround(value))
        case 1:
            set_user_armor(id, min(get_user_armor(id) + floatround(value), 200))
        case 2:
        {
            set_user_maxspeed(id, 250.0 + value)
            set_pev(id, pev_maxspeed, 250.0 + value)
        }
        case 3: { }
        case 4:
        {
            new Float:grav = 1.0 - value
            if(grav < 0.30) grav = 0.30
            set_pev(id, pev_gravity, grav)
        }
        case 5: { }
        case 6:
            cs_set_user_money(id, min(cs_get_user_money(id) + floatround(value), 16000))
        case 7:
        {
            new weapon = get_user_weapon(id)
            if(weapon > CSW_P228 && weapon != CSW_KNIFE && weapon != CSW_HEGRENADE && weapon != CSW_FLASHBANG && weapon != CSW_SMOKEGRENADE)
            {
                new clip, ammo
                get_user_ammo(id, weapon, clip, ammo)
                cs_set_user_bpammo(id, weapon, ammo + floatround(value))
            }
        }
        case 8:
        {
            new Float:grav = 1.0 - (value / 400.0)
            if(grav < 0.35) grav = 0.35
            set_pev(id, pev_gravity, grav)
        }
    }
}

public Task_ApplyRegen()
{
    if(!get_pcvar_num(cvar_enabled))
        return
    
    static Float:gt
    gt = get_gametime()
    
    for(new id = 1; id <= 32; id++)
    {
        if(!is_user_alive(id) || g_iPetType[id] == -1)
            continue
        if(g_Pets[g_iPetType[id]][PET_BONUS_TYPE] != 5)
            continue
        if(gt < g_flNextRegen[id])
            continue
        
        new Float:regen = CalculateBonus(g_iPetType[id], g_iPetLevel[id])
        new hp = get_user_health(id)
        if(hp < 160)
            set_user_health(id, min(hp + floatround(regen), 160))
        g_flNextRegen[id] = gt + 1.0
    }
}
