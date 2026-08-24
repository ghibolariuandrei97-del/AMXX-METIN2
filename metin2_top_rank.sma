#include <amxmodx>
#include <amxmisc>
#include <metin2_api>

#define PLUGIN  "Metin2 Top & Rank"
#define VERSION "1.2"
#define AUTHOR  "Grok"

#define MAX_PLAYERS 32

new g_szMotd[2048];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_clcmd("say /xp",     "cmd_ShowTop");
	register_clcmd("say /level",  "cmd_ShowTop");
	register_clcmd("say /lvl",    "cmd_ShowTop");
	register_clcmd("say /lvls",   "cmd_ShowTop");
	register_clcmd("say /top",    "cmd_ShowTop");
	register_clcmd("say /rank",   "cmd_ShowRank");

	register_clcmd("say xp",      "cmd_ShowTop");
	register_clcmd("say level",   "cmd_ShowTop");
	register_clcmd("say lvl",     "cmd_ShowTop");
	register_clcmd("say lvls",    "cmd_ShowTop");
	register_clcmd("say top",     "cmd_ShowTop");
	register_clcmd("say rank",    "cmd_ShowRank");
}

public cmd_ShowTop(id)
{
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	static players[MAX_PLAYERS], levels[MAX_PLAYERS], races[MAX_PLAYERS];
	static names[MAX_PLAYERS][32];
	new num, i, pid;

	get_players(players, num, "h");

	if (num == 0)
	{
		client_print_color(id, print_team_default, "^4[Metin2] ^1Nu exista jucatori conectati.");
		return PLUGIN_HANDLED;
	}

	for (i = 0; i < num; i++)
	{
		pid = players[i];
		get_user_name(pid, names[i], charsmax(names[]));
		levels[i] = get_user_m2_level(pid);
		races[i]  = get_user_m2_race(pid);
	}

	// Sortare descrescatoare dupa level
	for (new a = 0; a < num - 1; a++)
	{
		for (new b = 0; b < num - a - 1; b++)
		{
			if (levels[b] < levels[b + 1])
			{
				new tmp = levels[b];
				levels[b] = levels[b + 1];
				levels[b + 1] = tmp;

				tmp = races[b];
				races[b] = races[b + 1];
				races[b + 1] = tmp;

				static temp_name[32];
				copy(temp_name, charsmax(temp_name), names[b]);
				copy(names[b], charsmax(names[]), names[b + 1]);
				copy(names[b + 1], charsmax(names[]), temp_name);

				tmp = players[b];
				players[b] = players[b + 1];
				players[b + 1] = tmp;
			}
		}
	}

	// === MOTD ultra-compact (incape 32 jucatori) ===
	new len = 0;

	len = formatex(g_szMotd[len], charsmax(g_szMotd) - len, "<body bgcolor=black><font color=white face=Tahoma size=1>");
	len += formatex(g_szMotd[len], charsmax(g_szMotd) - len, "<b><font color=yellow>TOP LEVEL</font></b> (%d)<br>", num);

	static race_name[16];
	new is_self;

	for (i = 0; i < num; i++)
	{
		switch (races[i])
		{
			case 1: copy(race_name, charsmax(race_name), "War");
			case 2: copy(race_name, charsmax(race_name), "Sura");
			case 3: copy(race_name, charsmax(race_name), "Ninja");
			case 4: copy(race_name, charsmax(race_name), "Sham");
			default: copy(race_name, charsmax(race_name), "-");
		}
	
		is_self = (players[i] == id);

		if (is_self)
			len += formatex(g_szMotd[len], charsmax(g_szMotd) - len, "<font color=yellow>%2d.%-12s %-5s L%d</font><br>", i+1, names[i], race_name, levels[i]);
		else
			len += formatex(g_szMotd[len], charsmax(g_szMotd) - len, "%2d.%-12s %-5s L%d<br>", i+1, names[i], race_name, levels[i]);
	}

	len += formatex(g_szMotd[len], charsmax(g_szMotd) - len, "<br><font color=gray>Scrie /rank</font></body>");

	show_motd(id, g_szMotd, "Top Level");
	return PLUGIN_HANDLED;
}

public cmd_ShowRank(id)
{
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	static players[MAX_PLAYERS];
	new num, i, pid;
	new my_level = get_user_m2_level(id);
	new my_rank = 1;
	new total = 0;

	get_players(players, num, "h");

	if (num == 0)
	{
		client_print_color(id, print_team_default, "^4[Metin2] ^1Nu exista jucatori conectati.");
		return PLUGIN_HANDLED;
	}

	for (i = 0; i < num; i++)
	{
		pid = players[i];
		if (!is_user_connected(pid))
			continue;

		total++;
		new lvl = get_user_m2_level(pid);

		if (lvl > my_level)
			my_rank++;
		else if (lvl == my_level && pid < id)
			my_rank++;
	}

	client_print_color(id, print_team_default, "^4[Metin2] ^1Esti pe locul ^3%d^1 din ^3%d^1 jucatori online (Level ^4%d^1).", my_rank, total, my_level);

	return PLUGIN_HANDLED;
}
