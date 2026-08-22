/*
 * ============================================================================
 * Plugin: Admin Hierarchy + Chat Prefix (Metin2 Style)
 * Versiune: 3.0
 * ============================================================================
 * Ranguri Metin2:
 * 1. [GO]     Game Owner
 * 2. [DEV]    Developer
 * 3. [SA]     Server Admin
 * 4. [GA]     Game Administrator
 * 5. [SGM]    Super Game Master
 * 6. [GM]     Game Master
 * 7. [TGM]    Trial Game Master
 *
 * NOU (v3.0):
 * - Chat-ul (say / say_team) e reformatat automat:
 *     * Non-admin: "[Rasa Lvl X] Nume: mesaj"
 *     * Admin/GM:  "[TAG] [Rasa Lvl X] Nume: mesaj"   (TAG = ce e intre [] in who.ini)
 * - Comenzile /who /gm /admins raman functionale, prinse acum direct din Hook_Say.
 * - Chat-ul foloseste doar cele 3 culori suportate nativ de SayText (grey/team/green),
 *   engine-ul HL nu suporta hex custom in chat text (doar in MOTD).
 * ============================================================================
 */

#include <amxmodx>
#include <amxmisc>
#include <metin2_api>

#define PLUGIN  "Admin Hierarchy Metin2"
#define VERSION "1.1"
#define AUTHOR  "ClauAI"

#define MAX_RANKS     32
#define MAX_MOTD_LEN  1535

new g_RankNames[MAX_RANKS][32];
new g_RankColors[MAX_RANKS][32];
new g_RankFlags[MAX_RANKS];
new g_RankCount = 0;

new g_MsgSayText;

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    // Comenzi server-side (nu trec prin say)
    register_clcmd("amx_who",    "cmd_who");
    register_clcmd("amx_admins", "cmd_who");
    register_clcmd("amx_gm",     "cmd_who");

    // Hook central pe chat - aici se prind si comenzile /who /gm /admins si se reformateaza mesajele normale
    register_clcmd("say",      "Hook_Say");
    register_clcmd("say_team", "Hook_SayTeam");

    g_MsgSayText = get_user_msgid("SayText");

    LoadRanks();
}

public LoadRanks()
{
    new configdir[128], filepath[128];
    get_configsdir(configdir, charsmax(configdir));
    formatex(filepath, charsmax(filepath), "%s/who.ini", configdir);

    // Generăm fișierul default cu rangurile Metin2 dacă nu există
    if (!file_exists(filepath))
    {
        new f = fopen(filepath, "w");
        if (f)
        {
            fputs(f, "; =====================================================^n");
            fputs(f, ";  Admin Hierarchy - Metin2 Style^n");
            fputs(f, ";  Format: Culoare   ^"Nume Rang^"   ^"flaguri^"^n");
            fputs(f, ";  Culori: Red, Yellow, Gold, #FFD700, #00BFFF etc.^n");
            fputs(f, "; =====================================================^n^n");

            // De la cel mai mare la cel mai mic
            fputs(f, "#FF0000   ^"[GO] Game Owner^"              ^"abcdefghijklmnopqrstu^"^n");
            fputs(f, "#FF4500   ^"[DEV] Developer^"            ^"abcdefghijklmnopqrst^"^n");
            fputs(f, "#FF8C00   ^"[SA] Server Admin^"          ^"abcdefghijklmnopqrs^"^n");
            fputs(f, "#FFD700   ^"[GA] Game Administrator^"    ^"abcdefghijklmnopqr^"^n");
            fputs(f, "#00BFFF   ^"[SGM] Super Game Master^"    ^"abcdefghijklmnopq^"^n");
            fputs(f, "#32CD32   ^"[GM] Game Master^"           ^"abcdefghijklmno^"^n");
            fputs(f, "#ADFF2F   ^"[TGM] Trial Game Master^"    ^"abcdefghijklm^"^n");

            fclose(f);
        }
    }

    // Citim rangurile
    new f = fopen(filepath, "rt");
    if (!f) return;

    new line[128], color[32], name[32], flags[32];

    while (!feof(f) && g_RankCount < MAX_RANKS)
    {
        fgets(f, line, charsmax(line));
        trim(line);

        if (!line[0] || line[0] == ';' || line[0] == '/')
            continue;

        parse(line, color, charsmax(color), name, charsmax(name), flags, charsmax(flags));

        copy(g_RankColors[g_RankCount], 31, color);
        copy(g_RankNames[g_RankCount], 31, name);
        g_RankFlags[g_RankCount] = read_flags(flags);

        g_RankCount++;
    }

    fclose(f);
}

public cmd_who(id)
{
    new motd[MAX_MOTD_LEN + 1], len = 0;

    // Header stil Metin2 / dark fantasy
    len += formatex(motd[len], MAX_MOTD_LEN - len,
        "<style>\
        body{background:#0f172a;color:#e2e8f0;font-family:Tahoma,Arial,sans-serif;margin:12px}\
        h2{text-align:center;color:#f8fafc;border-bottom:2px solid #334155;padding-bottom:8px;margin:0 0 12px 0;font-size:20px}\
        .r{margin-top:14px;padding:7px 12px;background:#1e293b;border-radius:5px;font-weight:bold;font-size:15px;text-transform:uppercase;box-shadow:0 3px 6px rgba(0,0,0,0.4)}\
        .p{margin:3px 0 0 12px;padding:5px 10px;background:#0f172a;border-left:3px solid #475569;font-size:13px;color:#cbd5e1}\
        .empty{color:#f87171;text-align:center;margin-top:20px;font-size:14px}\
        </style>\
        <h2>Game Masters Online</h2>");

    new bool:has_admins = false;
    new players[32], pnum, player;
    get_players(players, pnum, "ch");

    for (new i = 0; i < g_RankCount; i++)
    {
        if (len >= MAX_MOTD_LEN - 180)
            break;

        new bool:rank_displayed = false;

        for (new j = 0; j < pnum; j++)
        {
            player = players[j];

            new pflags = get_user_flags(player);

            // Eliminăm flag-ul de user normal dacă există
            if (pflags & ADMIN_USER)
                pflags &= ~ADMIN_USER;

            // Verificăm dacă flagurile se potrivesc exact cu rangul
            if (pflags == g_RankFlags[i])
            {
                if (len >= MAX_MOTD_LEN - 120)
                    break;

                if (!rank_displayed)
                {
                    len += formatex(motd[len], MAX_MOTD_LEN - len,
                        "<div class='r' style='color:%s;border-left:5px solid %s'>%s</div>",
                        g_RankColors[i], g_RankColors[i], g_RankNames[i]);

                    rank_displayed = true;
                    has_admins = true;
                }

                new name[32];
                get_user_name(player, name, charsmax(name));

                // Protecție XSS
                replace_all(name, charsmax(name), "<", "&lt;");
                replace_all(name, charsmax(name), ">", "&gt;");

                len += formatex(motd[len], MAX_MOTD_LEN - len,
                    "<div class='p'>&#8227; %s</div>", name);
            }
        }
    }

    if (!has_admins)
    {
        len += formatex(motd[len], MAX_MOTD_LEN - len,
            "<div class='empty'>Nu este niciun Game Master online.</div>");
    }

    show_motd(id, motd, "Metin2 Staff");
    return PLUGIN_HANDLED;
}

// ============================================================================
// CHAT PREFIX SYSTEM
// ============================================================================

bool:IsWhoCommand(const text[])
{
    static const cmds[][] = { "/who", "who", "/admins", "/admin", "/gm", "gm" };

    for (new i = 0; i < sizeof cmds; i++)
    {
        if (equali(text, cmds[i]))
            return true;
    }

    return false;
}

// Returneaza tag-ul de rang (ex: "[GM]") daca playerul are un rang din who.ini, altfel string gol
GetRankTag(id, output[], len)
{
    output[0] = EOS;

    new pflags = get_user_flags(id);
    if (pflags & ADMIN_USER)
        pflags &= ~ADMIN_USER;

    if (!pflags)
        return;

    for (new i = 0; i < g_RankCount; i++)
    {
        if (pflags == g_RankFlags[i])
        {
            new close_pos = contain(g_RankNames[i], "]");

            if (close_pos != -1)
            {
                new take = close_pos + 1;
                if (take > len) take = len;
                copy(output, take, g_RankNames[i]);
            }
            else
            {
                copy(output, len, g_RankNames[i]);
            }
            return;
        }
    }
}

// Construieste prefixul complet: "[TAG] [Rasa Lvl X]" sau doar "[Rasa Lvl X]"
BuildChatPrefix(id, output[], len)
{
    new rank_tag[32];
    GetRankTag(id, rank_tag, charsmax(rank_tag));

    new race = get_user_m2_race(id);
    new level = get_user_m2_level(id);

    new race_level[48];
    if (race != M2_RACE_NONE)
    {
        new race_name[24];
        m2_get_race_name(race, race_name, charsmax(race_name));
        formatex(race_level, charsmax(race_level), "[%s Lvl %d]", race_name, level);
    }
    else
    {
        formatex(race_level, charsmax(race_level), "[Lvl %d]", level);
    }

    if (rank_tag[0])
        formatex(output, len, "%s %s", rank_tag, race_level);
    else
        copy(output, len, race_level);
}

BroadcastChat(id, const text[], bool:team_only)
{
    if (!g_MsgSayText)
        return;

    new prefix[80];
    BuildChatPrefix(id, prefix, charsmax(prefix));

    new name[32];
    get_user_name(id, name, charsmax(name));

    new msg[192];

    if (team_only)
        formatex(msg, charsmax(msg), "%c(Echipa) %s %c%s%c: %s", 3, prefix, 4, name, 1, text);
    else
        formatex(msg, charsmax(msg), "%c%s %c%s%c: %s", 3, prefix, 4, name, 1, text);

    if (team_only)
    {
        new sender_team = get_user_team(id);
        new players[32], pnum, player;
        get_players(players, pnum);

        for (new i = 0; i < pnum; i++)
        {
            player = players[i];
            if (get_user_team(player) != sender_team)
                continue;

            message_begin(MSG_ONE_UNRELIABLE, g_MsgSayText, _, player);
            write_byte(id);
            write_string(msg);
            message_end();
        }
    }
    else
    {
        message_begin(MSG_ALL, g_MsgSayText);
        write_byte(id);
        write_string(msg);
        message_end();
    }
}

public Hook_Say(id)
{
    if (!is_user_connected(id))
        return PLUGIN_CONTINUE;

    new args[192];
    read_args(args, charsmax(args));
    remove_quotes(args);
    trim(args);

    if (!args[0])
        return PLUGIN_HANDLED;

    if (IsWhoCommand(args))
    {
        cmd_who(id);
        return PLUGIN_HANDLED;
    }

    // Comenzile care incep cu '/' sunt lasate sa treaca mai departe catre alte plugin-uri
    // (ex: /check, /restore) - nu le trimitem ca mesaj normal de chat.
    if (args[0] == '/')
        return PLUGIN_CONTINUE;

    BroadcastChat(id, args, false);
    return PLUGIN_HANDLED;
}

public Hook_SayTeam(id)
{
    if (!is_user_connected(id))
        return PLUGIN_CONTINUE;

    new args[192];
    read_args(args, charsmax(args));
    remove_quotes(args);
    trim(args);

    if (!args[0])
        return PLUGIN_HANDLED;

    if (IsWhoCommand(args))
    {
        cmd_who(id);
        return PLUGIN_HANDLED;
    }

    BroadcastChat(id, args, true);
    return PLUGIN_HANDLED;
}
