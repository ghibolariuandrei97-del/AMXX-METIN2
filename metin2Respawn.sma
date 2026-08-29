#include <amxmodx>
#include <reapi>

// Timpul în secunde până la respawn
new const Float:RESPAWN_DELAY = 1.5;

public plugin_init()
{
    register_plugin("AutoRespawn", "1.0", "AMXX");

    // Hook pe moartea jucătorilor via ReAPI
    RegisterHookChain(RG_CSGameRules_PlayerKilled, "OnPlayerKilled_Post", true);
}

public OnPlayerKilled_Post(const id, const attacker, const shared_rand)
{
    // Verificăm dacă 'id' este un index valid de jucător (1 -> MaxClients)
    if (is_user_index(id) && is_user_connected(id))
    {
        set_task(RESPAWN_DELAY, "Task_RespawnPlayer", id);
    }
}

public Task_RespawnPlayer(const id)
{
    // Ne asigurăm strict că indexul este de jucător, conectat și mort
    if (is_user_index(id) && is_user_connected(id) && !is_user_alive(id))
    {
        // Verificăm dacă se află într-o echipă validă (CT sau T)
        new TeamName:team = get_member(id, m_iTeam);
        if (team == TEAM_TERRORIST || team == TEAM_CT)
        {
            rg_round_respawn(id);
        }
    }
}

// Funcție helper pentru a valida că indexul aparține unui Player/Bot (1 <= index <= MaxClients)
stock bool:is_user_index(const id)
{
    return (1 <= id <= MaxClients);
}
