/*================================================================================
	Metin2 RPG - Pergamentul Binecuvantarii
	AMX Mod X 1.10+ | ReAPI | metin2_rpg API
	
	Inregistreaza un item tip Potion (custom) care, la folosire,
	activeaza m2_set_force_upgrade() => urmatorul upgrade are 100% sanse.
	Poate fi cumparat de cate ori vrei din /shop (daca ai Yang).
================================================================================*/

#include <amxmodx>
#include <metin2_api>

#define PLUGIN  "Metin2 Pergament Binecuvantarii"
#define VERSION "1.0"
#define AUTHOR  "Craxor"

// Tip custom de potiune (1=HP, 2=MP, 3+ = custom -> doar forward m2_item_used)
#define POTION_TYPE_BLESS_SCROLL  3

// Pret in Yang (modificabil)
#define BLESS_SCROLL_PRICE        30000

new g_ItemId_BlessScroll = -1;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	// Inregistram itemul dupa ce core-ul e incarcat (natives disponibile)
	// Folosim task scurt ca sa fim siguri ca metin2_rpg a terminat RegisterDefaultItems()
	set_task(1.0, "Task_RegisterItem");
}

public Task_RegisterItem()
{
	// m2_register_item(
	//   name, type, req_level, race_req,
	//   str, hp, dex, intt, crit, speed,
	//   price, potion_type
	// )
	g_ItemId_BlessScroll = m2_register_item(
		"Pergamentul Binecuvantarii", // nume
		ITEM_POTION,                  // tip
		1,                            // level minim (nefolosit momentan)
		0,                            // orice rasa
		0, 0, 0, 0, 0, 0,             // fara bonusuri de stats
		BLESS_SCROLL_PRICE,           // pret in magazin
		POTION_TYPE_BLESS_SCROLL      // tip custom
	);
	
	if (g_ItemId_BlessScroll == -1)
	{
		log_amx("[Metin2][Pergament] EROARE: Nu s-a putut inregistra itemul! (limita MAX_ITEMS atinsa?)");
		return;
	}
	
	log_amx("[Metin2][Pergament] Item inregistrat cu succes: ID = %d | Pret = %d Yang", 
		g_ItemId_BlessScroll, BLESS_SCROLL_PRICE);
}

// ======================== FORWARD: cand cineva foloseste o potiune ========================
public m2_item_used(id, itemid, potion_type)
{
	// Verificam fie dupa ID (cel mai sigur), fie dupa tipul custom
	if (itemid != g_ItemId_BlessScroll && potion_type != POTION_TYPE_BLESS_SCROLL)
		return;
	
	if (!is_user_connected(id))
		return;
	
	// Activeaza succesul garantat la urmatorul upgrade
	m2_set_force_upgrade(id, true);
	
	client_print_color(id, print_team_default, 
		"^4[Metin2]^1 Ai folosit ^3Pergamentul Binecuvantarii^1!");
	client_print_color(id, print_team_default, 
		"^4[Metin2]^1 Urmatorul upgrade va avea ^3succes garantat 100%%^1.");
	
	// Optional: mesaj global (poti comenta daca nu vrei)
	// client_print_color(0, print_team_default, 
	// 	"^4[Metin2]^1 %n a folosit un ^3Pergament al Binecuvantarii^1!", id);
}
