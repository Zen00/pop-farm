/***********************************************\
					Pop-Farm
	
				Written by Zen00
	(with much copying from Banana Lord's Harvest)

\***********************************************/

script "Pop-Farm";
notify Zen00;
import <EatDrink.ash>;

//Don't modify below here
int [string, effect] buffbot_data;
file_to_map("HAR_Buffbot_Info.txt", buffbot_data);
SIM_CONSUME = false;
string ROLLOVER_OUTFIT = setvar("pop_rollover_outfit", "");
string ICING_FARMING_OUTFIT = setvar("pop_icing_farming_outfit", "");

effect cheapest_at_buff()
	{
	/*	Returns the least valuable AT buff you have active based on number of turns, MP cost and your
		ability to cast the skill (it's more important to preserve turns of effects you can only get
		from a buffbot) */
	
	effect cheapest;
	int temp_cost = 999999;
	
	for skill_num from 6001 to 6040
		{
		skill the_skill = skill_num.to_skill();
		effect the_effect = the_skill.to_effect();
		int num_turns = have_effect(the_effect);
		
		if(the_skill != $skill[none] && skill_num != 6025 && num_turns > 0)
			{
			// Inserting Theraze's fix (#324), keeping old code for now, just in case
			###int cost = num_turns/turns_per_cast(the_skill) * mp_cost(the_skill);
			int cost = num_turns/(turns_per_cast(the_skill) > 0 ? turns_per_cast(the_skill) : 1) * mp_cost(the_skill);
			
			if(have_skill(the_skill))
				cost -= 50000; // If you can cast it yourself it's less important to preserve remaining turns
			if($effect[ode to booze] == the_effect)
				cost += 100000; // Don't shrug a buff you want to get
			if($effects[chorale of companionship, The Ballad of Richie Thingfinder] contains the_effect)
				cost += 5000; // Hobo buffs are harder to acquire
			
			if(cost < temp_cost)
				{
				cheapest = the_effect;
				temp_cost = cost;
				}
			}
		}

	return cheapest;
	}

int active_at_songs()
	{
	/* Returns the number of AT songs you currently have active */
	
	int num_at_songs = 0;
	for skill_num from 6001 to 6040
		{
		skill the_skill = skill_num.to_skill();
		effect the_effect = the_skill.to_effect();
		int num_turns = have_effect(the_effect);
		
		if(the_skill != $skill[none] && skill_num != 6025 && num_turns > 0)
			num_at_songs += 1;
		}
	
	print(3, "You have "+ num_at_songs +" AT songs active");
	return num_at_songs;
	}
	
int max_at_songs()
	{
	/* Returns the maximum number of AT songs you can currently hold in your head */
	
	boolean four_songs = boolean_modifier("four songs");
	boolean extra_song = boolean_modifier("additional song");
	int max_songs = 3 + to_int(four_songs) + to_int(extra_song);
	
	print(3, "You can currently hold "+ max_songs +" AT songs in your head");
	return max_songs;
	}
	
boolean head_full()
	{
	/* Returns true if you have no slots free for AT songs */
	return active_at_songs() == max_at_songs();
	}
	
boolean equip_song_raisers()
	{
	/* Equips items to raise the number of songs you can hold in your head */
	
	boolean result = false;
	
	if(!boolean_modifier("Four Songs")) 
		result = maximize("Four Songs -tie", false); 
	if(!boolean_modifier("Additional Song")) 
		result = result || maximize("Additional Song -tie", false);
		
	return result;
	}
	
boolean has_buff(string buffbot, effect buff)
	{
	/* Returns true if the specified buffbot can give the specified buff */
	return buffbot_data [buffbot, buff].to_boolean();
	}

boolean buffbot_online(string buffbot)
	{
	/* Returns true if the specified buffbot is online */
		
	string [string] offline_buffbots;

	if(offline_buffbots contains buffbot) // If the bot was previously offline
		return false;
	else if(is_online(buffbot)) // Make sure bot is still online
		{
		print(buffbot +" is online", "blue");
		return true;
		}
	else // Bot wasn't previously seen as being offline but is now
		{
		offline_buffbots [buffbot] = "";
		print(buffbot +" is offline", "red");
		return false;
		}
	}	

void request_buff(effect the_effect, int turns_needed)
	{
	/*	Attempts to get <my_adventures()> turns of the specified buff from a buffbot
		Will not shrug AT buffs if you have too many to receive the effect */
	
	int max_time = 60; // The max time to wait for a buffbot to respond
	int pause = 5; // How long to wait before checking if a buffbot has responded
	int turns_still_needed;
	
	refresh_status();
	
	if(have_effect(the_effect) < my_adventures() || the_effect == $effect[Ode to Booze])
		{
		skill the_skill = the_effect.to_skill();
		
		// Inserting Theraze's fix (#326)
		int casts_needed = ceil(turns_needed / (turns_per_cast(the_skill) > 0 ? turns_per_cast(the_skill) : 1).to_float());
	
		if(have_skill(the_skill)) // Don't be lazy - Cast the buff yourself if you have the skill
			{
			print("You can cast "+ the_effect +" yourself so you probably shouldn't mooch off a bot");
			use_skill(casts_needed, the_skill);
			}
		else
			{
			// Find a buffbot from which to acquire the buff
			foreach buffbot in buffbot_data
				{
				turns_still_needed = turns_needed - have_effect(the_effect);
				
				if(turns_still_needed > 0 && has_buff(buffbot, the_effect) && buffbot_online(buffbot))
					{
					print("Attempting to get "+ turns_still_needed +" turns of "+ the_effect +" from "+ buffbot);
					
					int meat = max(0, buffbot_data [buffbot, the_effect]);
					string message = "";
					if(buffbot == "buffy")
						message = turns_still_needed +" "+ the_effect.to_string();
					
					int initial_turns = have_effect(the_effect);
					kmail(buffbot, message, meat);
					int time_waited = 0;
					boolean buffbot_responded = false;
					
					while(!buffbot_responded && time_waited < max_time)
						{
						waitq(pause);
						time_waited += pause;
						refresh_status();
						buffbot_responded = have_effect(the_effect) > initial_turns;
						
						switch (time_waited)
							{
							case 10:
								print(". . .");
								break;
							case 20:
								print("Hmm, that buffbot sure is taking its time");
								break;
							case 30:
								print(". . .");
								break;
							case 40:
								print("Still waiting...");
								break;
							case 50:
								print(". . .");
								break;
							case 60:
								print("OK, I give up, let's try another bot");
							}						
						}
						
					if(buffbot_responded)
						{
						if(have_effect(the_effect) < turns_needed)
							print(1, buffbot +" responded but you still need more turns");
						else
							print(1, "Buffbot request successful");
						}
					}				
				}
			}
		}
	else
		print("Didn't try to get "+ the_effect +", already had "+ have_effect(the_effect) +" turns");
	}

void fill_organs()
	{
	if(my_fullness() < fullness_limit() || my_inebriety() < inebriety_limit() || my_spleen_use() < spleen_limit())
		{
		// Get ode if necessary
		if(have_effect($effect[Ode to Booze]) < (inebriety_limit() - my_inebriety()))
			{
			// Make room
			if(head_full())
				if(!equip_song_raisers())
					cli_execute("shrug "+ cheapest_at_buff().to_string());
			
			if(!have_skill($skill[The Ode to Booze]))
				request_buff($effect[Ode to Booze], inebriety_limit());
			}
		
		eatdrink(fullness_limit(), inebriety_limit(), spleen_limit(), false);
		
		if(my_fullness() < fullness_limit() || my_inebriety() < inebriety_limit() || my_spleen_use() < spleen_limit())
			abort("Failed to fill your organs completely!");	
			
		if(have_effect($effect[Ode to Booze]) > 0)
			cli_execute("shrug ode to booze");
		}
	else
		print("Your organs are already full", "blue");
	}
	
void overdrink() {
	/*	Drinks a nightcap using your consumption script. Will make space for ode by shrugging an AT
		buff if necessary, and will attempt to get a shot of ode from a buffbot if you cannot cast it
		yourself (but will NOT cast ode if you can cast it yourself - that's up to the consumption
		script) */
	
	// Get ode if necessary
	if(have_effect($effect[Ode to Booze]) < (inebriety_limit() + 10 - my_inebriety())) {
		// Make room
		if(head_full())
			if(!equip_song_raisers())
				cli_execute("shrug "+ cheapest_at_buff());
		
		if(!have_skill($skill[The Ode to Booze]))
			request_buff($effect[Ode to Booze], inebriety_limit() + 10 - my_inebriety() - have_effect($effect[Ode to Booze]));
		}

	eatdrink(fullness_limit(), inebriety_limit(), spleen_limit(), true);
		
	if(my_inebriety() <= inebriety_limit())
		print("Failed to overdrink!", "red");
	}
	
boolean have_foldable(string foldable) {
	/* Returns true if you have any of the forms of the foldable related to <foldable>.
	"Putty" for spooky putty, "cheese" for stinky cheese, "origami" for naughty origami, 
	"doh" for Rain-Doh. */

	int count;
	switch (foldable) {
		case "putty":
			foreach putty_form in get_related($item[Spooky Putty sheet], "fold")
				if(available_amount(putty_form) > 0)
					count += available_amount(putty_form);
			break;
		case "cheese":
			foreach cheese_form in get_related($item[stinky cheese eye], "fold")
				if(available_amount(cheese_form) > 0)
					count += available_amount(cheese_form);
			break;
		case "origami":
			foreach origami_form in get_related($item[origami pasties], "fold")
				if(available_amount(origami_form) > 0)
					count += available_amount(origami_form);
			break;
		case "doh":
			int doh_count = available_amount($item[Rain-Doh black box]) + available_amount($item[Rain-Doh box full of monster]);
			if(doh_count > 0)
				count += doh_count;
			break;
		}

	return count > 0;
	}
	
boolean get_foldable(item goal) {
	/*	Attempts to get a given form of a foldable by first retrieving it from your closet 
	or display case and then folding it into the desired form */
	
	boolean look_get(item it, boolean DC) { 
		if(DC)
			return(display_amount(it) > 0 && take_display(1, it)); 
		
		return(available_amount(it) > 0 && retrieve_item(1, it)); 
		} 
	
	if(item_amount(goal) == 0 && !have_equipped(goal)) {
		foreach DC in $booleans[false, true] { 
			if(look_get(goal, DC))
				return true;
				
			foreach form in get_related(goal, "fold") { 
				if(look_get(form, DC)) { 
					cli_execute("fold " + goal); 
					if(item_amount(goal) > 0)
						return true; 
					} 
				} 
			}
		}
	
	return item_amount(goal) > 0; 
	}
	
void equip_rollover_gear()
	{
	/*	Equips the most optimal rollover gear you have in your inventory and saves this as your 
		specified rollover outfit */
	
	if(have_foldable("cheese"))
		get_foldable($item[stinky cheese diaper]);
	
	if(outfit(ROLLOVER_OUTFIT))
		outfit(ROLLOVER_OUTFIT);
	
	maximize("adv, switch Disembodied Hand", false);
	    
    cli_execute("outfit save "+ ROLLOVER_OUTFIT);
	}
	
void equipFarmingGear()
	{
	/*	Equips the most optimal food drop gear you have in your inventory and saves this as your 
		specified farming outfit */
	
	if(outfit(ICING_FARMING_OUTFIT))
		outfit(ICING_FARMING_OUTFIT);
	
	maximize("food drop, item drop", false);
	    
    cli_execute("outfit save "+ ICING_FARMING_OUTFIT);
	}

void doStuff()
{
	fill_organs();
	equipFarmingGear();
	while(my_adventures() > 0)
	{
		cli_execute("refresh inventory");
		if(item_amount($item[strawberry]) < 2)
		{
			buy(10, $item[strawberry]);
		}
		if(item_amount($item[Glob of enchanted icing]) > 0)
		{
			set_property("choiceAdventure1061", 3);
			set_property("choiceAdventure1084", 1);
		} else
		{
			set_property("choiceAdventure1061", 5);
		}
		adv1($location[Madness Bakery], -1, "");
	}
	overdrink();
	equip_rollover_gear();
}

void main()
{
	doStuff();
}
