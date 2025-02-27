//Food items that are eaten normally and don't leave anything behind.
/obj/item/reagent_containers/food/snacks
	name = "snack"
	desc = "yummy"
	icon = 'icons/obj/items/food.dmi'
	icon_state = null
	var/bitesize = 1
	var/bitecount = 0
	var/trash = null
	var/slice_path
	var/slices_num
	var/package = FALSE
	center_of_mass = list("x"=15, "y"=15)
	var/list/tastes // for example list("crisps" = 2, "salt" = 1)

/obj/item/reagent_containers/food/snacks/create_reagents(max_vol, new_flags, list/init_reagents, data)
	if(!length(tastes) || !length(init_reagents))
		return ..()
	if(reagents)
		qdel(reagents)
	reagents = new (max_vol, new_flags)
	reagents.my_atom = src
	for(var/rid in init_reagents)
		var/amount = list_reagents[rid]
		if(type == /datum/reagent/consumable/nutriment)
			reagents.add_reagent(rid, amount, tastes.Copy())
		else
			reagents.add_reagent(rid, amount, data)

/obj/item/reagent_containers/food/snacks/proc/On_Consume(mob/M)
	if(!usr)
		return

	if(reagents.total_volume)
		return

	if(M == usr)
		to_chat(usr, span_notice("You finish eating \the [src]."))
	else
		M.visible_message(span_notice("[M] finishes eating \the [src]."))

	usr.dropItemToGround(src)	//so icons update :[

	if(trash)
		var/obj/item/T = new trash
		usr.put_in_hands(T)

	qdel(src)

/obj/item/reagent_containers/food/snacks/attack_self(mob/user as mob)
	return

/obj/item/reagent_containers/food/snacks/attack(mob/M, mob/user, def_zone)
	if(!reagents.total_volume)						//Shouldn't be needed but it checks to see if it has anything left in it.
		to_chat(user, span_warning("None of [src] left, oh no!"))
		M.dropItemToGround(src)	//so icons update :[
		qdel(src)
		return FALSE

	if(package)
		to_chat(M, span_warning("How do you expect to eat this with the package still on?"))
		return FALSE

	if(iscarbon(M))
		var/mob/living/carbon/C = M
		var/fullness = C.nutrition + (C.reagents.get_reagent_amount(/datum/reagent/consumable/nutriment) * 25)
		if(M == user)								//If you're eating it yourself
			var/mob/living/carbon/H = M
			if(ishuman(H) && (H.species.species_flags & ROBOTIC_LIMBS))
				to_chat(H, span_warning("You have a monitor for a head, where do you think you're going to put that?"))
				return
			if (fullness <= 50)
				to_chat(M, span_warning("You hungrily chew out a piece of \the [src] and gobble it!"))
			if (fullness > 50 && fullness <= 150)
				to_chat(M, span_warning("You hungrily begin to eat \the [src]."))
			if (fullness > 150 && fullness <= 350)
				to_chat(M, span_warning("You take a bite of \the [src]."))
			if (fullness > 350 && fullness <= 550)
				to_chat(M, span_warning("You unwillingly chew a bit of \the [src]."))
			if (fullness > (550 * (1 + C.overeatduration / 2000)))	// The more you eat - the more you can eat
				to_chat(M, span_warning("You cannot force any more of \the [src] to go down your throat."))
				return FALSE
		else
			var/mob/living/carbon/H = M
			if(ishuman(H) && (H.species.species_flags & ROBOTIC_LIMBS))
				to_chat(user, span_warning("They have a monitor for a head, where do you think you're going to put that?"))
				return
			if (fullness <= (550 * (1 + C.overeatduration / 1000)))
				M.visible_message(span_warning("[user] attempts to feed \the [M] [src]."))
			else
				M.visible_message(span_warning("[user] cannot force anymore of \the [src] down [M]'s throat."))
				return FALSE

			if(!do_mob(user, M, 30, BUSY_ICON_FRIENDLY))
				return

			var/rgt_list_text = get_reagent_list_text()

			log_combat(user, M, "fed", src, "Reagents: [rgt_list_text]")

			M.visible_message(span_warning("[user] feeds [M] [src]."))


		if(reagents)								//Handle ingestion of the reagent.
			playsound(M.loc,'sound/items/eatfood.ogg', 15, 1)
			if(reagents.total_volume)
				reagents.reaction(M, INGEST)
				if(reagents.total_volume > bitesize)
					/*
					* I totally cannot understand what this code supposed to do.
					* Right now every snack consumes in 2 bites, my popcorn does not work right, so I simplify it. -- rastaf0
					var/temp_bitesize =  max(reagents.total_volume /2, bitesize)
					reagents.trans_to(M, temp_bitesize)
					*/
					reagents.trans_to(M, bitesize)
				else
					reagents.trans_to(M, reagents.total_volume)
				bitecount++
				On_Consume(M)
			return TRUE

	return FALSE

/obj/item/reagent_containers/food/snacks/afterattack(obj/target, mob/user, proximity)
	return ..()

/obj/item/reagent_containers/food/snacks/examine(mob/user)
	..()
	if (!(user in range(0)) && user != loc)
		return
	if (bitecount==0)
		return
	else if (bitecount==1)
		to_chat(user, span_notice("\The [src] was bitten by someone!"))
	else if (bitecount<=3)
		to_chat(user, span_notice("\The [src] was bitten [bitecount] times!"))
	else
		to_chat(user, span_notice("\The [src] was bitten multiple times!"))

/obj/item/reagent_containers/food/snacks/attackby(obj/item/I, mob/user, params)
	. = ..()

	if(istype(I, /obj/item/tool/kitchen/utensil))
		var/obj/item/tool/kitchen/utensil/U = I

		if(!U.reagents)
			U.create_reagents(5)

		if(U.reagents.total_volume > 0)
			to_chat(user, span_warning("You already have something on your [U]."))
			return

		user.visible_message("[user] scoops up some [src] with \the [U]!", \
			span_notice("You scoop up some [src] with \the [U]!"))

		bitecount++
		U.overlays.Cut()
		U.loaded = "[src]"
		var/image/IM = new(U.icon, "loadedfood")
		IM.color = filling_color
		U.overlays += IM

		reagents.trans_to(U, min(reagents.total_volume, 5))

		if(reagents.total_volume <= 0)
			qdel(src)


/obj/item/reagent_containers/food/snacks/sliceable/attackby(obj/item/I, mob/user, params)
	. = ..()

	if(I.sharp == IS_NOT_SHARP_ITEM)
		if(I.w_class >= WEIGHT_CLASS_SMALL)
			return
		if(!user.transferItemToLoc(I, src))
			return
		if(length(contents) > max_items)
			to_chat(user, span_warning("[src] is full, you can't stuff [I] inside."))
			return
		to_chat(user, span_notice("You slip [I] inside of [src]."))
		return

	if(!isturf(loc) || !(locate(/obj/structure/table) in loc))
		to_chat(user, span_warning("You cannot slice [src] here! You need a table or at least a tray to do it."))
		return

	user.visible_message(span_notice("[user] slices \the [src] with [I]!"), \
		span_notice("You crudely slice \the [src] with your [I]!"))

	var/reagents_per_slice = reagents.total_volume / slices_num

	for(var/i in 1 to slices_num)
		var/obj/slice = new slice_path(loc)
		reagents.trans_to(slice,reagents_per_slice)

	qdel(src)
	return TRUE


/obj/item/reagent_containers/food/snacks/Destroy()
	for(var/i in contents)
		var/atom/movable/AM = i
		AM.forceMove(get_turf(src))
	return ..()

/obj/item/reagent_containers/food/snacks/attack_animal(mob/M)
	if(isanimal(M))
		if(iscorgi(M))
			var/mob/living/L = M
			if(bitecount == 0 || prob(50))
				M.emote("nibbles away at the [src]")
			bitecount++
			L.taste(reagents) //why should carbons get all the fun?
			if(bitecount >= 5)
				var/sattisfaction_text = pick("burps from enjoyment", "yaps for more", "woofs twice", "looks at the area where the [src] was")
				if(sattisfaction_text)
					M.emote("[sattisfaction_text]")
				qdel(src)
		if(ismouse(M))
			var/mob/living/simple_animal/mouse/N = M
			to_chat(N, span_notice("You nibble away at [src]."))
			N.taste(reagents) // ratatouilles
			if(prob(50))
				N.visible_message(span_warning("[N] nibbles away at [src]."), "")
			//N.emote("nibbles away at the [src]")
			N.health = min(N.health + 1, N.maxHealth)


////////////////////////////////////////////////////////////////////////////////
/// FOOD END
////////////////////////////////////////////////////////////////////////////////











//////////////////////////////////////////////////
////////////////////////////////////////////Snacks
//////////////////////////////////////////////////
//Items in the "Snacks" subcategory are food items that people actually eat. The key points are that they are created
//	already filled with reagents and are destroyed when empty. Additionally, they make a "munching" noise when eaten.

//Notes by Darem: Food in the "snacks" subtype can hold a maximum of 50 units Generally speaking, you don't want to go over 40
//	total for the item because you want to leave space for extra condiments. If you want effect besides healing, add a reagent for
//	it. Try to stick to existing reagents when possible (so if you want a stronger healing effect, just use Tricordrazine). On use
//	effect (such as the old officer eating a donut code) requires a unique reagent (unless you can figure out a better way).

//The nutriment reagent and bitesize variable replace the old heal_amt and amount variables. Each unit of nutriment is equal to
//	2 of the old heal_amt variable. Bitesize is the rate at which the reagents are consumed. So if you have 6 nutriment and a
//	bitesize of 2, then it'll take 3 bites to eat. Unlike the old system, the contained reagents are evenly spread among all
//	the bites. No more contained reagents = no more bites.

//Here is an example of the new formatting for anyone who wants to add more food items.
///obj/item/reagent_containers/food/snacks/xenoburger			//Identification path for the object.
//	 name = "Xenoburger"												//Name that displays in the UI.
//	 desc = "Smells caustic. Tastes like heresy."						//Duh
//	 icon_state = "xburger"												//Refers to an icon in food.dmi
//	 list_reagents = list(/datum/reagent/consumable/nutriment = 2)			//This is what is in the food item. you may copy/paste
//	 tastes = list("dough" = 2, "heresy" = 1)							//This is the flavour of the food
//	 bitesize = 3														//This is the amount each bite consumes.


///obj/item/reagent_containers/food/snacks/xenoburger/Initialize()		//Absolute pathing for procs, please.
//	 . = ..()															//Calls the parent proc, don't forget to add this.


/obj/item/reagent_containers/food/snacks/honeycomb
	name = "honeycomb"
	icon_state = "honeycomb"
	desc = "Dripping with sugary sweetness."
	list_reagents = list(/datum/reagent/consumable/honey = 10, /datum/reagent/consumable/nutriment = 0.5, /datum/reagent/consumable/sugar = 2)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/aesirsalad
	name = "Aesir salad"
	desc = "Probably too incredible for mortal men to fully enjoy."
	icon_state = "aesirsalad"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#468C00"
	list_reagents = list(/datum/reagent/consumable/nutriment = 8, /datum/reagent/consumable/drink/doctor_delight = 8, /datum/reagent/medicine/tricordrazine = 8)
	bitesize = 3
	tastes = list("leaves" = 1)

/obj/item/reagent_containers/food/snacks/candy
	name = "candy"
	desc = "Nougat, love it or hate it."
	icon_state = "candy"
	trash = /obj/item/trash/candy
	filling_color = "#7D5F46"
	list_reagents = list(/datum/reagent/consumable/nutriment = 1, /datum/reagent/consumable/sugar = 3)
	tastes = list("candy" = 1)

/obj/item/reagent_containers/food/snacks/candy/donor
	name = "Donor Candy"
	desc = "A little treat for blood donors."
	trash = /obj/item/trash/candy
	list_reagents = list(/datum/reagent/consumable/nutriment = 2, /datum/reagent/consumable/sugar = 3, /datum/reagent/medicine/tricordrazine = 1, /datum/reagent/iron = 5) //Honk
	bitesize = 2


/obj/item/reagent_containers/food/snacks/candy_corn
	name = "candy corn"
	desc = "It's a handful of candy corn. Cannot be stored in a detective's hat, alas."
	icon_state = "candy_corn"
	filling_color = "#FFFCB0"
	list_reagents = list(/datum/reagent/consumable/nutriment = 4, /datum/reagent/consumable/sugar = 2)
	bitesize = 2
	tastes = list("candy corn" = 1)

/obj/item/reagent_containers/food/snacks/chips
	name = "chips"
	desc = "Commander Riker's What-The-Crisps"
	icon_state = "chips"
	trash = /obj/item/trash/chips
	filling_color = "#E8C31E"
	list_reagents = list(/datum/reagent/consumable/nutriment = 1, /datum/reagent/consumable/sugar = 3, /datum/reagent/consumable/sodiumchloride = 1)
	tastes = list("salt" = 1, "crisps" = 1)

/obj/item/reagent_containers/food/snacks/cookie
	name = "cookie"
	desc = "COOKIE!!!"
	icon_state = "COOKIE!!!"
	filling_color = "#DBC94F"
	list_reagents = list(/datum/reagent/consumable/nutriment = 5)
	tastes = list("cookie" = 1)

/obj/item/reagent_containers/food/snacks/chocolatebar
	name = "Chocolate Bar"
	desc = "Such sweet, fattening food."
	icon_state = "chocolatebar"
	filling_color = "#7D5F46"
	list_reagents = list(/datum/reagent/consumable/nutriment = 2, /datum/reagent/consumable/sugar = 2, /datum/reagent/consumable/coco = 2)
	bitesize = 2
	tastes = list("chocolate" = 1)

/obj/item/reagent_containers/food/snacks/chocolateegg
	name = "Chocolate Egg"
	desc = "Such sweet, fattening food."
	icon_state = "chocolateegg"
	filling_color = "#7D5F46"
	list_reagents = list(/datum/reagent/consumable/nutriment = 3, /datum/reagent/consumable/sugar = 2, /datum/reagent/consumable/coco = 2)
	bitesize = 2
	tastes = list("chocolate" = 4, "sweetness" = 1)

/obj/item/reagent_containers/food/snacks/donut
	name = "donut"
	desc = "A donut pastry, which is a common snack on Earth. Goes great with coffee."
	icon_state = "donut1"
	filling_color = "#D9C386"
	var/overlay_state = "donut"
	tastes = list("donut" = 1)

/obj/item/reagent_containers/food/snacks/donut/normal
	name = "donut"
	desc = "A donut. Rare on the frontier, so take care of it."
	icon_state = "donut1"
	tastes = list("donut" = 1)
	list_reagents = list (/datum/reagent/consumable/nutriment = 3)
	bitesize = 3


/obj/item/reagent_containers/food/snacks/donut/normal/Initialize()
	. = ..()
	if(prob(40))
		icon_state = "donut2"
		overlay_state = "fdonut"
		name = "frosted donut"
		desc = "A pink frosted donut. Even more rare on the frontier."
		reagents.add_reagent(/datum/reagent/consumable/sprinkles, 2)

/obj/item/reagent_containers/food/snacks/donut/chaos
	name = "Chaos Donut"
	desc = "Like life, it never quite tastes the same."
	icon_state = "donut1"
	filling_color = "#ED11E6"
	tastes = list("donut" = 3, "chaos" = 1)
	list_reagents = list (/datum/reagent/consumable/nutriment = 2, /datum/reagent/consumable/sprinkles = 1)
	bitesize = 10


/obj/item/reagent_containers/food/snacks/donut/chaos/Initialize()
	. = ..()
	var/chaosselect = pick(1,2,3,4,5,6,7,8,9)
	switch(chaosselect)
		if(1)
			reagents.add_reagent(/datum/reagent/consumable/nutriment, 3)
		if(2)
			reagents.add_reagent(/datum/reagent/consumable/capsaicin, 3)
		if(3)
			reagents.add_reagent(/datum/reagent/consumable/frostoil, 3)
		if(4)
			reagents.add_reagent(/datum/reagent/consumable/sprinkles, 3)
		if(5)
			reagents.add_reagent(/datum/reagent/toxin/phoron, 3)
		if(6)
			reagents.add_reagent(/datum/reagent/consumable/coco, 3)
		if(7)
			reagents.add_reagent(/datum/reagent/consumable/drink/banana, 3)
		if(8)
			reagents.add_reagent(/datum/reagent/consumable/drink/berryjuice, 3)
		if(9)
			reagents.add_reagent(/datum/reagent/medicine/tricordrazine, 3)
	if(prob(30))
		icon_state = "donut2"
		overlay_state = "box-donut2"
		name = "Frosted Chaos Donut"
		reagents.add_reagent(/datum/reagent/consumable/sprinkles, 2)


/obj/item/reagent_containers/food/snacks/donut/jelly
	name = "Jelly Donut"
	desc = "You jelly?"
	icon_state = "jdonut1"
	filling_color = "#ED1169"
	tastes = list("jelly" = 1, "donut" = 3)
	bitesize = 5
	list_reagents = list (/datum/reagent/consumable/nutriment = 3, /datum/reagent/consumable/sprinkles = 1, /datum/reagent/consumable/drink/berryjuice = 5)


/obj/item/reagent_containers/food/snacks/donut/jelly/Initialize()
	. = ..()
	if(prob(30))
		icon_state = "jdonut2"
		overlay_state = "box-donut2"
		name = "Frosted Jelly Donut"
		reagents.add_reagent(/datum/reagent/consumable/sprinkles, 2)

/obj/item/reagent_containers/food/snacks/donut/cherryjelly
	name = "Jelly Donut"
	desc = "You jelly?"
	icon_state = "jdonut1"
	filling_color = "#ED1169"
	list_reagents = list (/datum/reagent/consumable/nutriment = 3, /datum/reagent/consumable/sprinkles = 1, /datum/reagent/consumable/cherryjelly = 5)


/obj/item/reagent_containers/food/snacks/donut/cherryjelly/Initialize()
	. = ..()
	if(prob(30))
		icon_state = "jdonut2"
		overlay_state = "box-donut2"
		name = "Frosted Jelly Donut"
		reagents.add_reagent(/datum/reagent/consumable/sprinkles, 2)

/obj/item/reagent_containers/food/snacks/egg
	name = "egg"
	desc = "An egg!"
	icon_state = "egg"
	filling_color = "#FDFFD1"
	var/egg_color
	list_reagents = list(/datum/reagent/consumable/nutriment = 2)
	tastes = list("egg" = 1)

/obj/item/reagent_containers/food/snacks/egg/throw_impact(atom/hit_atom)
	..()
	new/obj/effect/decal/cleanable/egg_smudge(src.loc)
	src.reagents.reaction(hit_atom, TOUCH)
	src.visible_message(span_warning(" [src.name] has been squashed."),span_warning(" You hear a smack."))
	qdel(src)

/obj/item/reagent_containers/food/snacks/egg/attackby(obj/item/I, mob/user, params)
	. = ..()

	if(istype(I, /obj/item/toy/crayon))
		var/obj/item/toy/crayon/C = I
		var/clr = C.colourName

		if(!(clr in list("blue", "green", "mime", "orange", "purple", "rainbow", "red", "yellow")))
			to_chat(user, span_notice("The egg refuses to take on this color!"))
			return

		to_chat(user, span_notice("You color \the [src] [clr]"))
		icon_state = "egg-[clr]"
		egg_color = clr


/obj/item/reagent_containers/food/snacks/egg/blue
	icon_state = "egg-blue"
	egg_color = "blue"

/obj/item/reagent_containers/food/snacks/egg/green
	icon_state = "egg-green"
	egg_color = "green"

/obj/item/reagent_containers/food/snacks/egg/mime
	icon_state = "egg-mime"
	egg_color = "mime"

/obj/item/reagent_containers/food/snacks/egg/orange
	icon_state = "egg-orange"
	egg_color = "orange"

/obj/item/reagent_containers/food/snacks/egg/purple
	icon_state = "egg-purple"
	egg_color = "purple"

/obj/item/reagent_containers/food/snacks/egg/rainbow
	icon_state = "egg-rainbow"
	egg_color = "rainbow"

/obj/item/reagent_containers/food/snacks/egg/red
	icon_state = "egg-red"
	egg_color = "red"

/obj/item/reagent_containers/food/snacks/egg/yellow
	icon_state = "egg-yellow"
	egg_color = "yellow"

/obj/item/reagent_containers/food/snacks/friedegg
	name = "Fried egg"
	desc = "A fried egg, with a touch of salt and pepper."
	icon_state = "friedegg"
	filling_color = "#FFDF78"
	list_reagents = list(/datum/reagent/consumable/nutriment = 2, /datum/reagent/consumable/sodiumchloride = 1, /datum/reagent/consumable/blackpepper = 1)
	tastes = list("egg" = 4, "salt" = 1, "pepper" = 1)

/obj/item/reagent_containers/food/snacks/boiledegg
	name = "Boiled egg"
	desc = "A hard boiled egg."
	icon_state = "egg"
	filling_color = "#FFFFFF"
	list_reagents = list(/datum/reagent/consumable/nutriment = 2)
	tastes = list("egg" = 1)

/obj/item/reagent_containers/food/snacks/flour
	name = "flour"
	desc = "A small bag filled with some flour."
	icon_state = "flour"
	list_reagents = list(/datum/reagent/consumable/nutriment = 2)
	tastes = list("chalky wheat" = 1)


/obj/item/reagent_containers/food/snacks/organ

	name = "organ"
	desc = "It's good for you."
	icon = 'icons/obj/items/organs.dmi'
	icon_state = "appendix"
	filling_color = "#E00D34"
	bitesize = 3


/obj/item/reagent_containers/food/snacks/organ/Initialize()
	list_reagents = list(/datum/reagent/consumable/nutriment = rand(3,5), /datum/reagent/toxin = rand(1,3))
	return ..()


/obj/item/reagent_containers/food/snacks/worm
	name = "worm"
	icon = 'icons/obj/items/items.dmi'
	icon_state = "worm"
	desc = "A small worm. It looks a bit lonely."
	list_reagents = list(/datum/reagent/consumable/nutriment = 5)
	bitesize = 2
	tastes = list("dirt" = 1)
	attack_verb = list("touched")

/obj/item/reagent_containers/food/snacks/tofu
	name = "Tofu"
	icon_state = "tofu"
	desc = "We all love tofu."
	filling_color = "#FFFEE0"
	list_reagents = list(/datum/reagent/consumable/nutriment = 3)
	bitesize = 3
	tastes = list("tofu" = 1)

/obj/item/reagent_containers/food/snacks/tofurkey
	name = "Tofurkey"
	desc = "A fake turkey made from tofu."
	icon_state = "tofurkey"
	filling_color = "#FFFEE0"
	list_reagents = list(/datum/reagent/consumable/nutriment = 12, /datum/reagent/toxin/sleeptoxin = 3)
	bitesize = 3
	tastes = list("tofu" = 3, "breadcrumbs" = 1)

/obj/item/reagent_containers/food/snacks/stuffing
	name = "Stuffing"
	desc = "Moist, peppery breadcrumbs for filling the body cavities of dead birds. Dig in!"
	icon_state = "stuffing"
	filling_color = "#C9AC83"
	list_reagents = list(/datum/reagent/consumable/nutriment = 3)
	tastes = list("breadcrumbs" = 3, "pepper" = 1)

/obj/item/reagent_containers/food/snacks/carpmeat
	name = "carp fillet"
	desc = "A fillet of spess carp meat"
	icon_state = "fishfillet"
	filling_color = "#FFDEFE"
	list_reagents = list(/datum/reagent/consumable/nutriment = 3, /datum/reagent/toxin/carpotoxin = 3)
	bitesize = 6
	tastes = list("fish" = 1)

/obj/item/reagent_containers/food/snacks/fishfingers
	name = "Fish Fingers"
	desc = "A finger of fish."
	icon_state = "fishfingers"
	filling_color = "#FFDEFE"
	list_reagents = list(/datum/reagent/consumable/nutriment = 4, /datum/reagent/toxin/carpotoxin = 3)
	bitesize = 3
	tastes = list("fish" = 1, "breadcrumbs" = 1)

/obj/item/reagent_containers/food/snacks/hugemushroomslice
	name = "huge mushroom slice"
	desc = "A slice from a huge mushroom."
	icon_state = "hugemushroomslice"
	filling_color = "#E0D7C5"
	list_reagents = list(/datum/reagent/consumable/nutriment = 3, /datum/reagent/consumable/psilocybin = 3)
	bitesize = 6
	tastes = list("mushroom" = 1)

/obj/item/reagent_containers/food/snacks/tomatomeat
	name = "tomato slice"
	desc = "A slice from a huge tomato"
	icon_state = "tomatomeat"
	filling_color = "#DB0000"
	list_reagents = list(/datum/reagent/consumable/nutriment = 3)
	tastes = list("tomato" = 1)
	bitesize = 6

/obj/item/reagent_containers/food/snacks/bearmeat
	name = "bear meat"
	desc = "A very manly slab of meat."
	icon_state = "bearmeat"
	filling_color = "#DB0000"
	list_reagents = list(/datum/reagent/consumable/nutriment = 12, /datum/reagent/toxin/sleeptoxin = 3)
	tastes = list("meat" = 1, "salmon" = 1)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/xenomeat
	name = "meat"
	desc = "A slab of meat"
	icon_state = "xenomeat"
	filling_color = "#43DE18"
	list_reagents = list(/datum/reagent/consumable/nutriment = 3)
	tastes = list("meat" = 1, "acid" = 1)
	bitesize = 6

/obj/item/reagent_containers/food/snacks/meatball
	name = "meatball"
	desc = "A great meal all round."
	icon_state = "meatball"
	filling_color = "#DB0000"
	list_reagents = list(/datum/reagent/consumable/nutriment = 3)
	tastes = list("meat" = 1)
	bitesize = 1

/obj/item/reagent_containers/food/snacks/sausage
	name = "Sausage"
	desc = "A piece of mixed, long meat."
	icon_state = "sausage"
	filling_color = "#DB0000"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6)
	tastes = list("meat" = 1)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/donkpocket
	name = "Donk-pocket"
	desc = "The food of choice for the seasoned traitor."
	icon_state = "donkpocket"
	filling_color = "#DEDEAB"
	list_reagents = list(/datum/reagent/consumable/nutriment = 4)
	var/warm = 0
	tastes = list("meat" = 2, "dough" = 2, "laziness" = 1)

/obj/item/reagent_containers/food/snacks/donkpocket/proc/cooltime()
	if(warm)
		spawn( 4200 )
			if(!gc_destroyed) //not cdel'd
				warm = 0
				reagents.del_reagent(/datum/reagent/medicine/tricordrazine)
				name = "donk-pocket"

/obj/item/reagent_containers/food/snacks/brainburger
	name = "brainburger"
	desc = "A strange looking burger. It looks almost sentient."
	icon_state = "brainburger"
	filling_color = "#F2B6EA"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6, /datum/reagent/medicine/alkysine = 6)
	bitesize = 2
	tastes = list("bun" = 4, "brains" = 2)

/obj/item/reagent_containers/food/snacks/ghostburger
	name = "Ghost Burger"
	desc = "Spooky! It doesn't look very filling."
	icon_state = "ghostburger"
	filling_color = "#FFF2FF"
	list_reagents = list(/datum/reagent/consumable/nutriment = 2)
	bitesize = 2
	tastes = list("bun" = 4, "ectoplasm" = 2)


/obj/item/reagent_containers/food/snacks/human
	var/hname = ""
	var/job = null
	filling_color = "#D63C3C"

/obj/item/reagent_containers/food/snacks/human/burger
	name = "burger"
	desc = "A bloody burger."
	icon_state = "hamburger"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6)
	tastes = list("bun" = 4, "tender meat" = 2)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/cheeseburger
	name = "cheeseburger"
	desc = "The cheese adds a good flavor."
	icon_state = "hamburger"
	list_reagents = list(/datum/reagent/consumable/nutriment = 8)
	bitesize = 2
	tastes = list("bun" = 4, "cheese" = 2)

/obj/item/reagent_containers/food/snacks/monkeyburger
	name = "burger"
	desc = "The cornerstone of every nutritious breakfast."
	icon_state = "hburger"
	filling_color = "#D63C3C"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6)
	tastes = list("bun" = 4, "meat" = 2)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/fishburger
	name = "Fillet -o- Carp Sandwich"
	desc = "Almost like a carp is yelling somewhere... Give me back that fillet -o- carp, give me that carp."
	icon_state = "fishburger"
	filling_color = "#FFDEFE"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6, /datum/reagent/toxin/carpotoxin = 3)
	bitesize = 3
	tastes = list("bun" = 4, "fish" = 4)

/obj/item/reagent_containers/food/snacks/tofuburger
	name = "Tofu Burger"
	desc = "What.. is that meat?"
	icon_state = "tofuburger"
	filling_color = "#FFFEE0"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6)
	bitesize = 2
	tastes = list("bun" = 4, "tofu" = 4)

/obj/item/reagent_containers/food/snacks/roburger
	name = "roburger"
	desc = "The lettuce is the only organic component. Beep."
	icon_state = "roburger"
	filling_color = "#CCCCCC"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6)
	bitesize = 2
	tastes = list("bun" = 4, "lettuce" = 2, "sludge" = 1)

/obj/item/reagent_containers/food/snacks/roburgerbig
	name = "roburger"
	desc = "This massive patty looks like poison. Beep."
	icon_state = "roburger"
	filling_color = "#CCCCCC"
	volume = 120
	list_reagents = list(/datum/reagent/consumable/nutriment = 10)
	tastes = list("bun" = 4, "lettuce" = 2, "sludge" = 1)

/obj/item/reagent_containers/food/snacks/xenoburger
	name = "xenoburger"
	desc = "Smells caustic. Tastes like heresy."
	icon_state = "xburger"
	filling_color = "#43DE18"
	list_reagents = list(/datum/reagent/consumable/nutriment = 8)
	bitesize = 2
	tastes = list("bun" = 4, "acid" = 4)

/obj/item/reagent_containers/food/snacks/clownburger
	name = "Clown Burger"
	desc = "This tastes funny..."
	icon_state = "clownburger"
	filling_color = "#FF00FF"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6)
	bitesize = 2
	tastes = list("bun" = 4)


/obj/item/reagent_containers/food/snacks/mimeburger
	name = "Mime Burger"
	desc = "Its taste defies language."
	icon_state = "mimeburger"
	filling_color = "#FFFFFF"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6)
	bitesize = 2
	tastes = list("bun" = 4)

/obj/item/reagent_containers/food/snacks/omelette
	name = "Omelette Du Fromage"
	desc = "That's all you can say!"
	icon_state = "omelette"
	trash = /obj/item/trash/plate
	filling_color = "#FFF9A8"
	list_reagents = list(/datum/reagent/consumable/nutriment = 8)
	tastes = list("egg" = 1, "cheese" = 1)


/obj/item/reagent_containers/food/snacks/muffin
	name = "Muffin"
	desc = "A delicious and spongy little cake"
	icon_state = "muffin"
	filling_color = "#E0CF9B"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6)
	bitesize = 2
	tastes = list("muffin" = 1)

/obj/item/reagent_containers/food/snacks/pie
	name = "Banana Cream Pie"
	desc = "Just like back home, on clown planet! HONK!"
	icon_state = "pie"
	trash = /obj/item/trash/plate
	filling_color = "#FBFFB8"
	list_reagents = list(/datum/reagent/consumable/nutriment = 4, /datum/reagent/consumable/drink/banana = 5)
	tastes = list("pie" = 1)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/pie/throw_impact(atom/hit_atom)
	..()
	new /obj/effect/decal/cleanable/pie_smudge(loc)
	visible_message(span_warning(" [src.name] splats."),span_warning(" You hear a splat."))
	qdel(src)

/obj/item/reagent_containers/food/snacks/berryclafoutis
	name = "Berry Clafoutis"
	desc = "No black birds, this is a good sign."
	icon_state = "berryclafoutis"
	trash = /obj/item/trash/plate
	list_reagents = list(/datum/reagent/consumable/nutriment = 4, /datum/reagent/consumable/drink/berryjuice = 5)
	tastes = list("pie" = 1, "blackberries" = 1)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/waffles
	name = "waffles"
	desc = "Mmm, waffles"
	icon_state = "waffles"
	trash = /obj/item/trash/waffles
	filling_color = "#E6DEB5"
	list_reagents = list(/datum/reagent/consumable/nutriment = 8)
	bitesize = 2
	tastes = list("waffles" = 1)

/obj/item/reagent_containers/food/snacks/eggplantparm
	name = "Eggplant Parmigiana"
	desc = "The only good recipe for eggplant."
	icon_state = "eggplantparm"
	trash = /obj/item/trash/plate
	filling_color = "#4D2F5E"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6)
	bitesize = 2
	tastes = list("eggplant" = 3, "cheese" = 1)

/obj/item/reagent_containers/food/snacks/soylentgreen
	name = "Soylent Green"
	desc = "Not made of people. Honest." //Totally people.
	icon_state = "soylent_green"
	trash = /obj/item/trash/waffles
	filling_color = "#B8E6B5"
	list_reagents = list(/datum/reagent/consumable/nutriment = 10)
	bitesize = 2
	tastes = list("waffles" = 7, "people" = 1)

/obj/item/reagent_containers/food/snacks/soylenviridians
	name = "Soylen Virdians"
	desc = "Not made of people. Honest." //Actually honest for once.
	icon_state = "soylent_yellow"
	trash = /obj/item/trash/waffles
	filling_color = "#E6FA61"
	list_reagents = list(/datum/reagent/consumable/nutriment = 10)
	bitesize = 2
	tastes = list("waffles" = 7, "the colour green" = 1)

/obj/item/reagent_containers/food/snacks/meatpie
	name = "Meat-pie"
	icon_state = "meatpie"
	desc = "An old barber recipe, very delicious!"
	trash = /obj/item/trash/plate
	filling_color = "#948051"
	list_reagents = list(/datum/reagent/consumable/nutriment = 10)
	tastes = list("pie" = 1, "meat" = 1)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/tofupie
	name = "Tofu-pie"
	icon_state = "meatpie"
	desc = "A delicious tofu pie."
	trash = /obj/item/trash/plate
	filling_color = "#FFFEE0"
	list_reagents = list(/datum/reagent/consumable/nutriment = 10)
	tastes = list("pie" = 1, "tofu" = 1)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/amanita_pie
	name = "amanita pie"
	desc = "Sweet and tasty poison pie."
	icon_state = "amanita_pie"
	filling_color = "#FFCCCC"
	tastes = list("pie" = 1, "mushroom" = 1)
	list_reagents = list(/datum/reagent/consumable/nutriment = 5, /datum/reagent/toxin/amatoxin = 3, /datum/reagent/consumable/psilocybin = 1)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/plump_pie
	name = "plump pie"
	desc = "I bet you love stuff made out of plump helmets!"
	icon_state = "plump_pie"
	filling_color = "#B8279B"
	list_reagents = list(/datum/reagent/consumable/nutriment = 8)
	tastes = list("pie" = 1, "mushroom" = 1)
	bitesize = 2


/obj/item/reagent_containers/food/snacks/plump_pie/Initialize()
	. = ..()
	var/fey = prob(10)
	if(fey)
		name = "exceptional plump pie"
		desc = "Microwave is taken by a fey mood! It has cooked an exceptional plump pie!"
		reagents.add_reagent(/datum/reagent/medicine/tricordrazine, 5)

/obj/item/reagent_containers/food/snacks/xemeatpie
	name = "Xeno-pie"
	icon_state = "xenomeatpie"
	desc = "A delicious meatpie. Probably heretical."
	trash = /obj/item/trash/plate
	filling_color = "#43DE18"
	list_reagents = list(/datum/reagent/consumable/nutriment = 10)
	tastes = list("pie" = 1, "meat" = 1, "acid" = 1)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/wingfangchu
	name = "Wing Fang Chu"
	desc = "A savory dish of alien wing wang in soy."
	icon_state = "wingfangchu"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#43DE18"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6)
	tastes = list("soy" = 1)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/human/kabob
	name = "-kabob"
	icon_state = "kabob"
	desc = "A human meat, on a stick."
	trash = /obj/item/stack/rods
	filling_color = "#A85340"
	list_reagents = list(/datum/reagent/consumable/nutriment = 8)
	tastes = list("tender meat" = 3, "metal" = 1)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/monkeykabob
	name = "Meat-kabob"
	icon_state = "kabob"
	desc = "Delicious meat, on a stick."
	trash = /obj/item/stack/rods
	filling_color = "#A85340"
	list_reagents = list(/datum/reagent/consumable/nutriment = 8)
	tastes = list("meat" = 3, "metal" = 1)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/tofukabob
	name = "Tofu-kabob"
	icon_state = "kabob"
	desc = "Vegan meat, on a stick."
	trash = /obj/item/stack/rods
	filling_color = "#FFFEE0"
	list_reagents = list(/datum/reagent/consumable/nutriment = 8)
	tastes = list("tofu" = 3, "metal" = 1)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/cubancarp
	name = "Cuban Carp"
	desc = "A grifftastic sandwich that burns your tongue and then leaves it numb!"
	icon_state = "cubancarp"
	trash = /obj/item/trash/plate
	filling_color = "#E9ADFF"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6, /datum/reagent/toxin/carpotoxin = 3, /datum/reagent/consumable/capsaicin = 3)
	tastes = list("fish" = 4, "batter" = 1, "hot peppers" = 1)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/popcorn
	name = "Popcorn"
	desc = "Now let's find some cinema."
	icon_state = "popcorn"
	trash = /obj/item/trash/popcorn
	var/unpopped = 0
	filling_color = "#FFFAD4"
	list_reagents = list(/datum/reagent/consumable/nutriment = 2)
	bitesize = 0.1  //this snack is supposed to be eating during looooong time. And this it not dinner food! --rastaf0
	tastes = list("popcorn" = 3, "butter" = 1)


/obj/item/reagent_containers/food/snacks/popcorn/Initialize()
	. = ..()
	unpopped = rand(1,10)

/obj/item/reagent_containers/food/snacks/popcorn/On_Consume()
	if(prob(unpopped))	//lol ...what's the point?
		to_chat(usr, span_warning("You bite down on an un-popped kernel!"))
		unpopped = max(0, unpopped-1)
	return ..()


/obj/item/reagent_containers/food/snacks/sosjerky
	name = "Scaredy's Private Reserve Beef Jerky"
	icon_state = "sosjerky"
	desc = "Beef jerky made from the finest space cows."
	trash = /obj/item/trash/sosjerky
	filling_color = "#631212"
	list_reagents = list(/datum/reagent/consumable/nutriment = 1, /datum/reagent/consumable/sugar = 3, /datum/reagent/consumable/sodiumchloride = 2)
	bitesize = 2
	tastes = list("dried meat" = 1)

/obj/item/reagent_containers/food/snacks/no_raisin
	name = "4no Raisins"
	icon_state = "4no_raisins"
	desc = "Best raisins in the universe. Not sure why."
	trash = /obj/item/trash/raisins
	filling_color = "#343834"
	list_reagents = list(/datum/reagent/consumable/nutriment = 2, /datum/reagent/consumable/sugar = 4)
	tastes = list("dried raisins" = 1)

/obj/item/reagent_containers/food/snacks/spacetwinkie
	name = "Space Twinkie"
	icon_state = "space_twinkie"
	desc = "Guaranteed to survive longer than you will."
	filling_color = "#FFE591"
	list_reagents = list(/datum/reagent/consumable/sugar = 4)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/cheesiehonkers
	name = "Cheesie Honkers"
	icon_state = "cheesie_honkers"
	desc = "Bite sized cheesie snacks that will honk all over your mouth"
	trash = /obj/item/trash/cheesie
	filling_color = "#FFA305"
	list_reagents = list(/datum/reagent/consumable/nutriment = 1, /datum/reagent/consumable/sugar = 3)
	bitesize = 2
	tastes = list("cheese" = 5, "crisps" = 2)

/obj/item/reagent_containers/food/snacks/syndicake
	name = "Syndi-Cakes"
	icon_state = "syndi_cakes"
	desc = "An extremely moist snack cake that tastes just as good after being nuked."
	filling_color = "#FF5D05"
	list_reagents = list(/datum/reagent/consumable/nutriment = 4, /datum/reagent/consumable/drink/doctor_delight = 5)
	trash = /obj/item/trash/syndi_cakes
	bitesize = 3
	tastes = list("sweetness" = 3, "cake" = 1)

/obj/item/reagent_containers/food/snacks/loadedbakedpotato
	name = "Loaded Baked Potato"
	desc = "Totally baked."
	icon_state = "loadedbakedpotato"
	filling_color = "#9C7A68"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6)
	bitesize = 2
	tastes = list("nutriment" = 1)

/obj/item/reagent_containers/food/snacks/fries
	name = "Space Fries"
	desc = "AKA: French Fries, Freedom Fries, etc."
	icon_state = "fries"
	trash = /obj/item/trash/plate
	filling_color = "#EDDD00"
	list_reagents = list(/datum/reagent/consumable/nutriment = 4)
	bitesize = 2
	tastes = list("fries" = 3, "salt" = 1)

/obj/item/reagent_containers/food/snacks/soydope
	name = "Soy Dope"
	desc = "Dope from a soy."
	icon_state = "soydope"
	trash = /obj/item/trash/plate
	filling_color = "#C4BF76"
	list_reagents = list(/datum/reagent/consumable/nutriment = 2)
	bitesize = 2
	tastes = list("soy" = 1)

/obj/item/reagent_containers/food/snacks/spagetti
	name = "Spaghetti"
	desc = "A bundle of raw spaghetti."
	icon_state = "spagetti"
	filling_color = "#EDDD00"
	list_reagents = list(/datum/reagent/consumable/nutriment = 1)
	bitesize = 1
	tastes = list("raw pasta" = 1)

/obj/item/reagent_containers/food/snacks/cheesyfries
	name = "Cheesy Fries"
	desc = "Fries. Covered in cheese. Duh."
	icon_state = "cheesyfries"
	trash = /obj/item/trash/plate
	filling_color = "#EDDD00"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6)
	bitesize = 2
	tastes = list("fries" = 3, "cheese" = 1)

/obj/item/reagent_containers/food/snacks/fortunecookie
	name = "Fortune cookie"
	desc = "A true prophecy in each cookie!"
	icon_state = "fortune_cookie"
	filling_color = "#E8E79E"
	trash = /obj/item/trash/fortunecookie
	list_reagents = list(/datum/reagent/consumable/nutriment = 3)
	bitesize = 2
	tastes = list("cookie" = 1)

/obj/item/reagent_containers/food/snacks/badrecipe
	name = "Burned mess"
	desc = "Someone should be demoted from chef for this."
	icon_state = "badrecipe"
	filling_color = "#211F02"
	list_reagents = list(/datum/reagent/carbon = 1, /datum/reagent/carbon = 3)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/meatsteak
	name = "Meat steak"
	desc = "A piece of hot spicy meat."
	icon_state = "meatsteak"
	trash = /obj/item/trash/plate
	filling_color = "#7A3D11"
	list_reagents = list(/datum/reagent/consumable/nutriment = 4, /datum/reagent/consumable/sodiumchloride = 1, /datum/reagent/consumable/blackpepper = 1)
	bitesize = 3
	tastes = list("meat" = 1)

/obj/item/reagent_containers/food/snacks/spacylibertyduff
	name = "Spacy Liberty Duff"
	desc = "Jello gelatin, from Alfred Hubbard's cookbook"
	icon_state = "spacylibertyduff"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#42B873"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6, /datum/reagent/consumable/psilocybin = 6)
	bitesize = 3
	tastes = list("jelly" = 1, "mushroom" = 1)

/obj/item/reagent_containers/food/snacks/amanitajelly
	name = "Amanita Jelly"
	desc = "Looks curiously toxic"
	icon_state = "amanitajelly"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#ED0758"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6, /datum/reagent/toxin/amatoxin = 6, /datum/reagent/consumable/psilocybin = 3)
	bitesize = 3
	tastes = list("jelly" = 1, "mushroom" = 1)

/obj/item/reagent_containers/food/snacks/meatballsoup
	name = "Meatball soup"
	desc = "You've got balls kid, BALLS!"
	icon_state = "meatballsoup"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#785210"
	list_reagents = list(/datum/reagent/consumable/nutriment = 8, /datum/reagent/consumable/drink/tomatojuice = 3)
	bitesize = 5
	tastes = list("meat" = 1)

/obj/item/reagent_containers/food/snacks/bloodsoup
	name = "Tomato soup"
	desc = "Smells like copper"
	icon_state = "tomatosoup"
	filling_color = "#FF0000"
	list_reagents = list(/datum/reagent/consumable/nutriment = 2, /datum/reagent/blood = 10, /datum/reagent/water= 5)
	bitesize = 5
	tastes = list("iron" = 1)

/obj/item/reagent_containers/food/snacks/clownstears
	name = "Clown's Tears"
	desc = "Not very funny."
	icon_state = "clownstears"
	filling_color = "#C4FBFF"
	list_reagents = list(/datum/reagent/consumable/nutriment = 4, /datum/reagent/consumable/drink/banana = 5, /datum/reagent/water = 10)
	bitesize = 5
	tastes = list("a bad joke" = 1)

/obj/item/reagent_containers/food/snacks/vegetablesoup
	name = "Vegetable soup"
	desc = "A true vegan meal" //TODO
	icon_state = "vegetablesoup"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#AFC4B5"
	list_reagents = list(/datum/reagent/consumable/nutriment = 8, /datum/reagent/water = 5)
	bitesize = 5
	tastes = list("vegetables" = 1)

/obj/item/reagent_containers/food/snacks/nettlesoup
	name = "Nettle soup"
	desc = "To think, the botanist would've beat you to death with one of these."
	icon_state = "nettlesoup"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#AFC4B5"
	list_reagents = list(/datum/reagent/consumable/nutriment = 8, /datum/reagent/water = 5, /datum/reagent/medicine/tricordrazine = 5)
	bitesize = 5
	tastes = list("nettles" = 1)

/obj/item/reagent_containers/food/snacks/mysterysoup
	name = "Mystery soup"
	desc = "The mystery is, why aren't you eating it?"
	icon_state = "mysterysoup"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#F082FF"
	bitesize = 5
	tastes = list("chaos" = 1)


/obj/item/reagent_containers/food/snacks/mysterysoup/Initialize()
	. = ..()
	var/mysteryselect = pick(1,2,3,4,5,6,7,8,9)
	switch(mysteryselect)
		if(1)
			reagents.add_reagent(/datum/reagent/consumable/nutriment, 6)
			reagents.add_reagent(/datum/reagent/consumable/capsaicin, 3)
			reagents.add_reagent(/datum/reagent/consumable/drink/tomatojuice, 2)
		if(2)
			reagents.add_reagent(/datum/reagent/consumable/nutriment, 6)
			reagents.add_reagent(/datum/reagent/consumable/frostoil, 3)
			reagents.add_reagent(/datum/reagent/consumable/drink/tomatojuice, 2)
		if(3)
			reagents.add_reagent(/datum/reagent/consumable/nutriment, 5)
			reagents.add_reagent(/datum/reagent/water, 5)
			reagents.add_reagent(/datum/reagent/medicine/tricordrazine, 5)
		if(4)
			reagents.add_reagent(/datum/reagent/consumable/nutriment, 5)
			reagents.add_reagent(/datum/reagent/water, 10)
		if(5)
			reagents.add_reagent(/datum/reagent/consumable/nutriment, 2)
			reagents.add_reagent(/datum/reagent/consumable/drink/banana,, 10)
		if(6)
			reagents.add_reagent(/datum/reagent/consumable/nutriment, 6)
			reagents.add_reagent(/datum/reagent/blood, 10)
		if(7)
			reagents.add_reagent(/datum/reagent/carbon, 10)
			reagents.add_reagent(/datum/reagent/toxin, 10)
		if(8)
			reagents.add_reagent(/datum/reagent/consumable/nutriment, 5)
			reagents.add_reagent(/datum/reagent/consumable/drink/tomatojuice, 10)
		if(9)
			reagents.add_reagent(/datum/reagent/consumable/nutriment, 6)
			reagents.add_reagent(/datum/reagent/consumable/drink/tomatojuice, 5)
			reagents.add_reagent(/datum/reagent/medicine/imidazoline, 5)

/obj/item/reagent_containers/food/snacks/wishsoup
	name = "Wish Soup"
	desc = "I wish this was soup."
	icon_state = "wishsoup"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#D1F4FF"
	list_reagents = list(/datum/reagent/water = 10)
	bitesize = 5
	tastes = list("wishes" = 1)


/obj/item/reagent_containers/food/snacks/wishsoup/Initialize()
	. = ..()
	var/wish = prob(25)
	if(wish)
		desc = "A wish come true!"
		reagents.add_reagent(/datum/reagent/consumable/nutriment, 8)

/obj/item/reagent_containers/food/snacks/larvasoup
	name = "Larva Soup"
	desc = "Liquified larva."
	icon_state = "larvasoup"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#66801e"
	list_reagents = list(/datum/reagent/consumable/larvajellyprepared = 1, /datum/reagent/consumable/nutriment = 4)
	bitesize = 5
	tastes = list("burning" = 1)

/obj/item/reagent_containers/food/snacks/hotchili
	name = "Hot Chili"
	desc = "A five alarm Texan Chili!"
	icon_state = "hotchili"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#FF3C00"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6, /datum/reagent/consumable/drink/tomatojuice = 2, /datum/reagent/consumable/capsaicin = 3)
	bitesize = 5
	tastes = list("hot peppers" = 1)


/obj/item/reagent_containers/food/snacks/coldchili
	name = "Cold Chili"
	desc = "This slush is barely a liquid!"
	icon_state = "coldchili"
	filling_color = "#2B00FF"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6, /datum/reagent/consumable/drink/tomatojuice = 2, /datum/reagent/consumable/frostoil = 3)
	trash = /obj/item/trash/snack_bowl
	bitesize = 5
	tastes = list("tomato" = 1, "mint" = 1)


/obj/item/reagent_containers/food/snacks/monkeycube
	name = "monkey cube"
	desc = "Just add water!"
	icon_state = "monkeycube"
	bitesize = 12
	filling_color = "#ADAC7F"
	var/monkey_type = /mob/living/carbon/human/species/monkey
	list_reagents = list(/datum/reagent/consumable/nutriment = 10)
	tastes = list("the jungle" = 1, "bananas" = 1)

/obj/item/reagent_containers/food/snacks/monkeycube/examine(mob/user)
	. = ..()
	if(package)
		to_chat(user, "It is wrapped in waterproof cellophane. Maybe using it in your hand would tear it off?")

/obj/item/reagent_containers/food/snacks/monkeycube/afterattack(obj/O, mob/user, proximity)
	if(!proximity)
		return
	if(istype(O,/obj/structure/sink) && !package)
		to_chat(user, "You place \the [name] under a stream of water...")
		user.drop_held_item()
		return Expand()
	return ..()

/obj/item/reagent_containers/food/snacks/monkeycube/attack_self(mob/user)
	if(!package)
		return
	icon_state = "monkeycube"
	user.visible_message(span_notice("[user] unwraps [src]"), span_notice("You unwrap [src]."))
	package = FALSE

/obj/item/reagent_containers/food/snacks/monkeycube/On_Consume(mob/M)
	to_chat(M, "<span class = 'warning'>Something inside of you suddently expands!</span>")

	if(!ishuman(M))
		return ..()
	//Do not try to understand.
	var/obj/item/surprise = new(M)
	var/mob/ook = monkey_type
	surprise.icon = initial(ook.icon)
	surprise.icon_state = initial(ook.icon_state)
	surprise.name = "malformed [initial(ook.name)]"
	surprise.desc = "Looks like \a very deformed [initial(ook.name)], a little small for its kind. It shows no signs of life."
	surprise.transform *= 0.6
	surprise.add_mob_blood(M)
	var/mob/living/carbon/human/H = M
	var/datum/limb/E = H.get_limb("chest")
	E.fracture()
	for (var/datum/internal_organ/I in E.internal_organs)
		I.take_damage(rand(I.min_bruised_damage, I.min_broken_damage+1))
	if (!E.hidden && prob(60)) //set it snuggly
		E.hidden = surprise
		E.cavity = 0
	else 		//someone is having a bad day
		E.createwound(CUT, 30)
		surprise.embed_into(M, E)

/obj/item/reagent_containers/food/snacks/monkeycube/proc/Expand()
	visible_message(span_warning("\The [src] expands!"))
	var/turf/T = get_turf(src)
	if(T)
		new monkey_type(T)
	qdel(src)


/obj/item/reagent_containers/food/snacks/monkeycube/wrapped
	desc = "Still wrapped in some paper."
	icon_state = "monkeycubewrap"
	package = TRUE


/obj/item/reagent_containers/food/snacks/monkeycube/farwacube
	name = "farwa cube"
	monkey_type = /mob/living/carbon/human/species/monkey/farwa

/obj/item/reagent_containers/food/snacks/monkeycube/wrapped/farwacube
	name = "farwa cube"
	monkey_type = /mob/living/carbon/human/species/monkey/farwa


/obj/item/reagent_containers/food/snacks/monkeycube/stokcube
	name = "stok cube"
	monkey_type = /mob/living/carbon/human/species/monkey/stok

/obj/item/reagent_containers/food/snacks/monkeycube/wrapped/stokcube
	name = "stok cube"
	monkey_type = /mob/living/carbon/human/species/monkey/stok


/obj/item/reagent_containers/food/snacks/monkeycube/neaeracube
	name = "neaera cube"
	monkey_type = /mob/living/carbon/human/species/monkey/naera
/obj/item/reagent_containers/food/snacks/monkeycube/wrapped/neaeracube
	name = "neaera cube"
	monkey_type = /mob/living/carbon/human/species/monkey/naera


/obj/item/reagent_containers/food/snacks/spellburger
	name = "Spell Burger"
	desc = "This is absolutely Ei Nath."
	icon_state = "spellburger"
	filling_color = "#D505FF"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6)
	bitesize = 2
	tastes = list("bun" = 4, "magic" = 2)

/obj/item/reagent_containers/food/snacks/bigbiteburger
	name = "Big Bite Burger"
	desc = "Forget the Big Mac. THIS is the future!"
	icon_state = "bigbiteburger"
	filling_color = "#E3D681"
	list_reagents = list(/datum/reagent/consumable/nutriment = 14, /datum/reagent/consumable/sodiumchloride = 2)
	bitesize = 3
	tastes = list("bun" = 4)

/obj/item/reagent_containers/food/snacks/enchiladas
	name = "Enchiladas"
	desc = "Viva La Mexico!"
	icon_state = "enchiladas"
	trash = /obj/item/trash/tray
	filling_color = "#A36A1F"
	list_reagents = list(/datum/reagent/consumable/nutriment = 8, /datum/reagent/consumable/capsaicin = 6)
	bitesize = 4
	tastes = list("hot peppers" = 1, "meat" = 3, "cheese" = 1, "sour cream" = 1)

/obj/item/reagent_containers/food/snacks/monkeysdelight
	name = "monkey's Delight"
	desc = "Eeee Eee!"
	icon_state = "monkeysdelight"
	trash = /obj/item/trash/tray
	filling_color = "#5C3C11"
	list_reagents = list(/datum/reagent/consumable/nutriment = 10, /datum/reagent/consumable/drink/banana = 5, /datum/reagent/consumable/blackpepper = 1, /datum/reagent/consumable/sodiumchloride = 1)
	bitesize = 6
	tastes = list("the jungle" = 1, "banana" = 1)

/obj/item/reagent_containers/food/snacks/baguette
	name = "Baguette"
	desc = "Bon appetit!"
	icon_state = "baguette"
	filling_color = "#E3D796"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6, /datum/reagent/consumable/blackpepper = 1, /datum/reagent/consumable/sodiumchloride = 1)
	bitesize = 3
	tastes = list("bread" = 1)

/obj/item/reagent_containers/food/snacks/fishandchips
	name = "Fish and Chips"
	desc = "I do say so myself chap."
	icon_state = "fishandchips"
	filling_color = "#E3D796"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6, /datum/reagent/toxin/carpotoxin = 3)
	bitesize = 3
	tastes = list("fish" = 1, "chips" = 1)

/obj/item/reagent_containers/food/snacks/sandwich
	name = "Sandwich"
	desc = "A grand creation of meat, cheese, bread, and several leaves of lettuce! Arthur Dent would be proud."
	icon_state = "sandwich"
	trash = /obj/item/trash/plate
	filling_color = "#D9BE29"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6)
	bitesize = 2
	tastes = list("meat" = 2, "cheese" = 1, "bread" = 2, "lettuce" = 1)

/obj/item/reagent_containers/food/snacks/toastedsandwich
	name = "Toasted Sandwich"
	desc = "Now if you only had a pepper bar."
	icon_state = "toastedsandwich"
	trash = /obj/item/trash/plate
	filling_color = "#D9BE29"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6, /datum/reagent/carbon = 2)
	bitesize = 2
	tastes = list("toast" = 1)

/obj/item/reagent_containers/food/snacks/grilledcheese
	name = "Grilled Cheese Sandwich"
	desc = "Goes great with Tomato soup!"
	icon_state = "toastedsandwich"
	trash = /obj/item/trash/plate
	filling_color = "#D9BE29"
	list_reagents = list(/datum/reagent/consumable/nutriment = 7)
	bitesize = 2
	tastes = list("toast" = 1, "cheese" = 1)

/obj/item/reagent_containers/food/snacks/tomatosoup
	name = "Tomato Soup"
	desc = "Drinking this feels like being a vampire! A tomato vampire..."
	icon_state = "tomatosoup"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#D92929"
	list_reagents = list(/datum/reagent/consumable/nutriment = 5, /datum/reagent/consumable/drink/tomatojuice = 10)
	bitesize = 3
	tastes = list("tomato" = 1)

/obj/item/reagent_containers/food/snacks/rofflewaffles
	name = "Roffle Waffles"
	desc = "Waffles from Roffle. Co."
	icon_state = "rofflewaffles"
	trash = /obj/item/trash/waffles
	filling_color = "#FF00F7"
	list_reagents = list(/datum/reagent/consumable/nutriment = 8, /datum/reagent/consumable/psilocybin = 8)
	bitesize = 4
	tastes = list("waffle" = 1, "mushrooms" = 1)

/obj/item/reagent_containers/food/snacks/stew
	name = "Stew"
	desc = "A nice and warm stew. Healthy and strong."
	icon_state = "stew"
	filling_color = "#9E673A"
	list_reagents = list(/datum/reagent/consumable/nutriment = 10, /datum/reagent/consumable/drink/tomatojuice = 5, /datum/reagent/consumable/drink/carrotjuice = 5, /datum/reagent/water = 5)
	bitesize = 7
	volume = 100
	tastes = list("tomato" = 1, "carrot" = 1)

/obj/item/reagent_containers/food/snacks/jelliedtoast
	name = "Jellied Toast"
	desc = "A slice of bread covered with delicious jam."
	icon_state = "jellytoast"
	trash = /obj/item/trash/plate
	filling_color = "#B572AB"
	list_reagents = list(/datum/reagent/consumable/nutriment = 2, /datum/reagent/consumable/sugar = 2)
	bitesize = 3
	tastes = list("bread" = 1, "jelly" = 1)

/obj/item/reagent_containers/food/snacks/jelliedtoast/cherry
	list_reagents = list(/datum/reagent/consumable/nutriment = 2, /datum/reagent/consumable/cherryjelly = 5)

/obj/item/reagent_containers/food/snacks/jellyburger
	name = "Jelly Burger"
	desc = "Culinary delight..?"
	icon_state = "jellyburger"
	filling_color = "#B572AB"
	list_reagents = list(/datum/reagent/consumable/nutriment = 5, /datum/reagent/consumable/sugar = 2)
	bitesize = 2
	tastes = list("bun" = 4, "jelly" = 2)

/obj/item/reagent_containers/food/snacks/jellyburger/cherry
	list_reagents = list(/datum/reagent/consumable/nutriment = 5, /datum/reagent/consumable/cherryjelly = 5)

/obj/item/reagent_containers/food/snacks/milosoup
	name = "Milosoup"
	desc = "The universes best soup! Yum!!!"
	icon_state = "milosoup"
	trash = /obj/item/trash/snack_bowl
	list_reagents = list(/datum/reagent/consumable/nutriment = 8, /datum/reagent/water = 5)
	bitesize = 4
	tastes = list("milo" = 1) // wtf is milo

/obj/item/reagent_containers/food/snacks/stewedsoymeat
	name = "Stewed Soy Meat"
	desc = "Even non-vegetarians will LOVE this!"
	icon_state = "stewedsoymeat"
	trash = /obj/item/trash/plate
	list_reagents = list(/datum/reagent/consumable/nutriment = 8)
	tastes = list("soy" = 1, "vegetables" = 1)

/obj/item/reagent_containers/food/snacks/boiledspagetti
	name = "Boiled Spaghetti"
	desc = "A plain dish of noodles, this sucks."
	icon_state = "spagettiboiled"
	trash = /obj/item/trash/plate
	filling_color = "#FCEE81"
	list_reagents = list(/datum/reagent/consumable/nutriment = 2)
	bitesize = 2
	tastes = list("pasta" = 1)

/obj/item/reagent_containers/food/snacks/boiledrice
	name = "Boiled Rice"
	desc = "A boring dish of boring rice."
	icon_state = "boiledrice"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#FFFBDB"
	list_reagents = list(/datum/reagent/consumable/nutriment = 2)
	bitesize = 2
	tastes = list("rice" = 1)

/obj/item/reagent_containers/food/snacks/ricepudding
	name = "Rice Pudding"
	desc = "Where's the Jam!"
	icon_state = "rpudding"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#FFFBDB"
	list_reagents = list(/datum/reagent/consumable/nutriment = 4)
	bitesize = 2
	tastes = list("rice" = 1, "sweetness" = 1)

/obj/item/reagent_containers/food/snacks/pastatomato
	name = "Spaghetti"
	desc = "Spaghetti and crushed tomatoes. Just like your abusive father used to make!"
	icon_state = "pastatomato"
	trash = /obj/item/trash/plate
	filling_color = "#DE4545"
	list_reagents = list(/datum/reagent/consumable/nutriment = 6, /datum/reagent/consumable/drink/tomatojuice = 10)
	bitesize = 4
	tastes = list("pasta" = 1, "tomato" = 1)

/obj/item/reagent_containers/food/snacks/meatballspagetti
	name = "Spaghetti & Meatballs"
	desc = "Now thats a nic'e meatball!"
	icon_state = "meatballspagetti"
	trash = /obj/item/trash/plate
	filling_color = "#DE4545"
	list_reagents = list(/datum/reagent/consumable/nutriment = 8)
	bitesize = 3
	tastes = list("pasta" = 1, "tomato" = 1, "meat" = 1)

/obj/item/reagent_containers/food/snacks/spesslaw
	name = "Spesslaw"
	desc = "A lawyers favourite"
	icon_state = "spesslaw"
	filling_color = "#DE4545"
	list_reagents = list(/datum/reagent/consumable/nutriment = 10)
	bitesize = 3
	tastes = list("pasta" = 1, "tomato" = 1, "meat" = 1)

/obj/item/reagent_containers/food/snacks/poppypretzel
	name = "Poppy Pretzel"
	desc = "A large soft pretzel full of POP!"
	icon_state = "poppypretzel"
	filling_color = "#AB7D2E"
	list_reagents = list(/datum/reagent/consumable/nutriment = 5)
	bitesize = 2
	tastes = list("pretzel" = 1)

/obj/item/reagent_containers/food/snacks/carrotfries
	name = "Carrot Fries"
	desc = "Tasty fries from fresh Carrots."
	icon_state = "carrotfries"
	trash = /obj/item/trash/plate
	filling_color = "#FAA005"
	list_reagents = list(/datum/reagent/consumable/nutriment = 3, /datum/reagent/consumable/drink/carrotjuice = 3)
	bitesize = 2
	tastes = list("carrots" = 3, "salt" = 1)

/obj/item/reagent_containers/food/snacks/superbiteburger
	name = "Super Bite Burger"
	desc = "This is a mountain of a burger. FOOD!"
	icon_state = "superbiteburger"
	filling_color = "#CCA26A"
	list_reagents = list(/datum/reagent/consumable/nutriment = 40)
	bitesize = 7
	volume = 100
	tastes = list("bun" = 4, "type two diabetes" = 10)

/obj/item/reagent_containers/food/snacks/candiedapple
	name = "Candied Apple"
	desc = "An apple coated in sugary sweetness."
	icon_state = "candiedapple"
	filling_color = "#F21873"
	list_reagents = list(/datum/reagent/consumable/nutriment = 2, /datum/reagent/consumable/sugar = 2)
	bitesize = 3
	tastes = list("carrots" = 3, "salt" = 1)

/obj/item/reagent_containers/food/snacks/applepie
	name = "Apple Pie"
	desc = "A pie containing sweet sweet love... or apple."
	icon_state = "applepie"
	filling_color = "#E0EDC5"
	list_reagents = list(/datum/reagent/consumable/nutriment = 4)
	bitesize = 3
	tastes = list("pie" = 1, "apple" = 1)


/obj/item/reagent_containers/food/snacks/cherrypie
	name = "Cherry Pie"
	desc = "Taste so good, make a grown man cry."
	icon_state = "cherrypie"
	filling_color = "#FF525A"
	list_reagents = list(/datum/reagent/consumable/nutriment = 4, /datum/reagent/consumable/cherryjelly = 4)
	bitesize = 3
	tastes = list("pie" = 7, "Nicole Paige Brooks" = 2)

/obj/item/reagent_containers/food/snacks/twobread
	name = "Two Bread"
	desc = "It is very bitter and winy."
	icon_state = "twobread"
	filling_color = "#DBCC9A"
	list_reagents = list(/datum/reagent/consumable/nutriment = 2)
	bitesize = 3
	tastes = list("bread" = 2)

/obj/item/reagent_containers/food/snacks/jellysandwich
	name = "Jelly Sandwich"
	desc = "You wish you had some peanut butter to go with this..."
	icon_state = "jellysandwich"
	trash = /obj/item/trash/plate
	filling_color = "#9E3A78"
	list_reagents = list(/datum/reagent/consumable/nutriment = 3)
	bitesize = 3
	tastes = list("bread" = 1, "jelly" = 1)

/obj/item/reagent_containers/food/snacks/jellysandwich/cherry
	list_reagents = list(/datum/reagent/consumable/nutriment = 3, /datum/reagent/consumable/cherryjelly = 3)

/obj/item/reagent_containers/food/snacks/mint
	name = "mint"
	desc = "it is only wafer thin."
	icon_state = "mint"
	filling_color = "#F2F2F2"
	list_reagents = list(/datum/reagent/toxin/minttoxin = 1)

/obj/item/reagent_containers/food/snacks/mushroomsoup
	name = "chantrelle soup"
	desc = "A delicious and hearty mushroom soup."
	icon_state = "mushroomsoup"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#E386BF"
	list_reagents = list(/datum/reagent/consumable/nutriment = 8)
	bitesize = 3
	tastes = list("mushroom" = 1)

/obj/item/reagent_containers/food/snacks/plumphelmetbiscuit
	name = "plump helmet biscuit"
	desc = "This is a finely-prepared plump helmet biscuit. The ingredients are exceptionally minced plump helmet, and well-minced dwarven wheat flour."
	icon_state = "phelmbiscuit"
	filling_color = "#CFB4C4"
	list_reagents = list(/datum/reagent/consumable/nutriment = 5)
	bitesize = 2
	tastes = list("mushroom" = 1, "biscuit" = 1)


/obj/item/reagent_containers/food/snacks/plumphelmetbiscuit/Initialize()
	if(prob(10))
		name = "exceptional plump helmet biscuit"
		desc = "Microwave is taken by a fey mood! It has cooked an exceptional plump helmet biscuit!"
		list_reagents = list(/datum/reagent/consumable/nutriment = 8, /datum/reagent/medicine/tricordrazine = 5)
	return ..()

/obj/item/reagent_containers/food/snacks/chawanmushi
	name = "chawanmushi"
	desc = "A legendary egg custard that makes friends out of enemies. Probably too hot for a cat to eat."
	icon_state = "chawanmushi"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#F0F2E4"
	list_reagents = list(/datum/reagent/consumable/nutriment = 5)
	tastes = list("custard" = 1)

/obj/item/reagent_containers/food/snacks/beetsoup
	name = "beet soup"
	desc = "Wait, how do you spell it again..?"
	icon_state = "beetsoup"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#FAC9FF"
	list_reagents = list(/datum/reagent/consumable/nutriment = 8)
	tastes = list("tasteless soup" = 1)


/obj/item/reagent_containers/food/snacks/beetsoup/Initialize()
	. = ..()
	name = pick("borsch","bortsch","borstch","borsh","borshch","borscht")
	tastes = list(name = 1)

/obj/item/reagent_containers/food/snacks/tossedsalad
	name = "tossed salad"
	desc = "A proper salad, basic and simple, with little bits of carrot, tomato and apple intermingled. Vegan!"
	icon_state = "herbsalad"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#76B87F"
	list_reagents = list(/datum/reagent/consumable/nutriment = 8)
	bitesize = 3
	tastes = list("leaves" = 1, "vegetables" = 1, "apple" = 1)

/obj/item/reagent_containers/food/snacks/validsalad
	name = "valid salad"
	desc = "It's just a salad of questionable 'herbs' with meatballs and fried potato slices. Nothing suspicious about it."
	icon_state = "validsalad"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#76B87F"
	list_reagents = list(/datum/reagent/consumable/nutriment = 8)
	bitesize = 3
	tastes = list("leaves" = 1, "nutriment" = 1, "meat" = 1, "valids" = 1)

/obj/item/reagent_containers/food/snacks/appletart
	name = "golden apple streusel tart"
	desc = "A tasty dessert that won't make it through a metal detector."
	icon_state = "gappletart"
	trash = /obj/item/trash/plate
	filling_color = "#FFFF00"
	list_reagents = list(/datum/reagent/consumable/nutriment = 8, /datum/reagent/gold = 5)
	bitesize = 3
	tastes = list("pie" = 1, "apple" = 1, "expensive metal" = 1)

/////////////////////////////////////////////////Sliceable////////////////////////////////////////
// All the food items that can be sliced into smaller bits like Meatbread and Cheesewheels

// sliceable is just an organization type path, it doesn't have any additional code or variables tied to it.
/obj/item/reagent_containers/food/snacks/sliceable
	name = "sliceable food"
	bitesize = 1
	slices_num = 5
	var/max_items = 4

/obj/item/reagent_containers/food/snacks/sliceable/meatbread
	name = "meatbread loaf"
	desc = "The culinary base of every self-respecting eloquen/tg/entleman."
	icon_state = "meatbread"
	slice_path = /obj/item/reagent_containers/food/snacks/meatbreadslice
	list_reagents = list(/datum/reagent/consumable/nutriment = 30)
	filling_color = "#FF7575"
	tastes = list("bread" = 10, "meat" = 10)

/obj/item/reagent_containers/food/snacks/meatbreadslice
	name = "meatbread slice"
	desc = "A slice of delicious meatbread."
	icon_state = "meatbreadslice"
	trash = /obj/item/trash/plate
	filling_color = "#FF7575"
	bitesize = 2
	tastes = list("bread" = 10, "meat" = 10)

/obj/item/reagent_containers/food/snacks/sliceable/xenomeatbread
	name = "xenomeatbread loaf"
	desc = "The culinary base of every self-respecting eloquent gentleman. Extra Heretical."
	icon_state = "xenomeatbread"
	slice_path = /obj/item/reagent_containers/food/snacks/xenomeatbreadslice
	list_reagents = list(/datum/reagent/consumable/nutriment = 30)
	filling_color = "#8AFF75"
	tastes = list("bread" = 10, "acid" = 10)


/obj/item/reagent_containers/food/snacks/xenomeatbreadslice
	name = "xenomeatbread slice"
	desc = "A slice of delicious meatbread. Extra Heretical."
	icon_state = "xenobreadslice"
	trash = /obj/item/trash/plate
	filling_color = "#8AFF75"
	bitesize = 2
	tastes = list("bread" = 10, "acid" = 10)

/obj/item/reagent_containers/food/snacks/sliceable/bananabread
	name = "Banana-nut bread"
	desc = "A heavenly and filling treat."
	icon_state = "bananabread"
	slice_path = /obj/item/reagent_containers/food/snacks/bananabreadslice
	list_reagents = list(/datum/reagent/consumable/nutriment = 20, /datum/reagent/consumable/drink/banana = 20)
	filling_color = "#EDE5AD"
	tastes = list("bread" = 10) // bananjuice will also flavour

/obj/item/reagent_containers/food/snacks/bananabreadslice
	name = "Banana-nut bread slice"
	desc = "A slice of delicious banana bread."
	icon_state = "bananabreadslice"
	trash = /obj/item/trash/plate
	filling_color = "#EDE5AD"
	bitesize = 2
	tastes = list("bread" = 10)

/obj/item/reagent_containers/food/snacks/sliceable/tofubread
	name = "Tofubread"
	icon_state = "Like meatbread but for vegetarians. Not guaranteed to give superpowers."
	icon_state = "tofubread"
	slice_path = /obj/item/reagent_containers/food/snacks/tofubreadslice
	list_reagents = list(/datum/reagent/consumable/nutriment = 30)
	filling_color = "#F7FFE0"
	tastes = list("bread" = 10, "tofu" = 10)

/obj/item/reagent_containers/food/snacks/tofubreadslice
	name = "Tofubread slice"
	desc = "A slice of delicious tofubread."
	icon_state = "tofubreadslice"
	trash = /obj/item/trash/plate
	filling_color = "#F7FFE0"
	bitesize = 2
	tastes = list("bread" = 10, "tofu" = 10)


/obj/item/reagent_containers/food/snacks/sliceable/carrotcake
	name = "Carrot Cake"
	desc = "A favorite desert of a certain wascally wabbit. Not a lie."
	icon_state = "carrotcake"
	slice_path = /obj/item/reagent_containers/food/snacks/carrotcakeslice
	list_reagents = list(/datum/reagent/consumable/nutriment = 25, /datum/reagent/consumable/drink/carrotjuice = 10)
	filling_color = "#FFD675"
	tastes = list("cake" = 5, "sweetness" = 2, "carrot" = 1)

/obj/item/reagent_containers/food/snacks/carrotcakeslice
	name = "Carrot Cake slice"
	desc = "Carrotty slice of Carrot Cake, carrots are good for your eyes! Also not a lie."
	icon_state = "carrotcake_slice"
	trash = /obj/item/trash/plate
	filling_color = "#FFD675"
	bitesize = 2
	tastes = list("cake" = 5, "sweetness" = 2, "carrot" = 1)

/obj/item/reagent_containers/food/snacks/sliceable/braincake
	name = "Brain Cake"
	desc = "A squishy cake-thing."
	icon_state = "braincake"
	slice_path = /obj/item/reagent_containers/food/snacks/braincakeslice
	list_reagents = list(/datum/reagent/consumable/nutriment = 25, /datum/reagent/medicine/alkysine = 10)
	filling_color = "#E6AEDB"
	tastes = list("cake" = 5, "sweetness" = 2, "brains" = 1)

/obj/item/reagent_containers/food/snacks/braincakeslice
	name = "Brain Cake slice"
	desc = "Lemme tell you something about prions. THEY'RE DELICIOUS."
	icon_state = "braincakeslice"
	trash = /obj/item/trash/plate
	filling_color = "#E6AEDB"
	bitesize = 2
	tastes = list("cake" = 5, "sweetness" = 2, "brains" = 1)

/obj/item/reagent_containers/food/snacks/sliceable/cheesecake
	name = "Cheese Cake"
	desc = "DANGEROUSLY cheesy."
	icon_state = "cheesecake"
	slice_path = /obj/item/reagent_containers/food/snacks/cheesecakeslice
	list_reagents = list(/datum/reagent/consumable/nutriment = 25)
	filling_color = "#FAF7AF"
	tastes = list("cake" = 4, "cream cheese" = 3)

/obj/item/reagent_containers/food/snacks/cheesecakeslice
	name = "Cheese Cake slice"
	desc = "Slice of pure cheestisfaction"
	icon_state = "cheesecake_slice"
	trash = /obj/item/trash/plate
	filling_color = "#FAF7AF"
	bitesize = 2
	tastes = list("cake" = 4, "cream cheese" = 3)

/obj/item/reagent_containers/food/snacks/sliceable/plaincake
	name = "Vanilla Cake"
	desc = "A plain cake, not a lie."
	icon_state = "plaincake"
	slice_path = /obj/item/reagent_containers/food/snacks/plaincakeslice
	list_reagents = list(/datum/reagent/consumable/nutriment = 20)
	filling_color = "#F7EDD5"
	tastes = list("vanilla" = 1, "sweetness" = 2,"cake" = 5)

/obj/item/reagent_containers/food/snacks/plaincakeslice
	name = "Vanilla Cake slice"
	desc = "Just a slice of cake, it is enough for everyone."
	icon_state = "plaincake_slice"
	trash = /obj/item/trash/plate
	filling_color = "#F7EDD5"
	bitesize = 2
	tastes = list("vanilla" = 1, "sweetness" = 2,"cake" = 5)

/obj/item/reagent_containers/food/snacks/sliceable/orangecake
	name = "Orange Cake"
	desc = "A cake with added orange."
	icon_state = "orangecake"
	slice_path = /obj/item/reagent_containers/food/snacks/orangecakeslice
	list_reagents = list(/datum/reagent/consumable/nutriment = 20)
	filling_color = "#FADA8E"
	tastes = list("cake" = 5, "sweetness" = 2, "oranges" = 2)

/obj/item/reagent_containers/food/snacks/orangecakeslice
	name = "Orange Cake slice"
	desc = "Just a slice of cake, it is enough for everyone."
	icon_state = "orangecake_slice"
	trash = /obj/item/trash/plate
	filling_color = "#FADA8E"
	bitesize = 2
	tastes = list("cake" = 5, "sweetness" = 2, "oranges" = 2)

/obj/item/reagent_containers/food/snacks/sliceable/limecake
	name = "Lime Cake"
	desc = "A cake with added lime."
	icon_state = "limecake"
	slice_path = /obj/item/reagent_containers/food/snacks/limecakeslice
	list_reagents = list(/datum/reagent/consumable/nutriment = 20)
	filling_color = "#CBFA8E"
	tastes = list("cake" = 5, "sweetness" = 2, "unbearable sourness" = 2)

/obj/item/reagent_containers/food/snacks/limecakeslice
	name = "Lime Cake slice"
	desc = "Just a slice of cake, it is enough for everyone."
	icon_state = "limecake_slice"
	trash = /obj/item/trash/plate
	filling_color = "#CBFA8E"
	bitesize = 2
	tastes = list("cake" = 5, "sweetness" = 2, "unbearable sourness" = 2)

/obj/item/reagent_containers/food/snacks/sliceable/lemoncake
	name = "Lemon Cake"
	desc = "A cake with added lemon."
	icon_state = "lemoncake"
	slice_path = /obj/item/reagent_containers/food/snacks/lemoncakeslice
	list_reagents = list(/datum/reagent/consumable/nutriment = 20)
	filling_color = "#FAFA8E"
	tastes = list("cake" = 5, "sweetness" = 2, "sourness" = 2)

/obj/item/reagent_containers/food/snacks/lemoncakeslice
	name = "Lemon Cake slice"
	desc = "Just a slice of cake, it is enough for everyone."
	icon_state = "lemoncake_slice"
	trash = /obj/item/trash/plate
	filling_color = "#FAFA8E"
	bitesize = 2
	tastes = list("cake" = 5, "sweetness" = 2, "sourness" = 2)

/obj/item/reagent_containers/food/snacks/sliceable/chocolatecake
	name = "Chocolate Cake"
	desc = "A cake with added chocolate"
	icon_state = "chocolatecake"
	slice_path = /obj/item/reagent_containers/food/snacks/chocolatecakeslice
	list_reagents = list(/datum/reagent/consumable/nutriment = 20)
	filling_color = "#805930"
	tastes = list("cake" = 5, "sweetness" = 1, "chocolate" = 4)

/obj/item/reagent_containers/food/snacks/chocolatecakeslice
	name = "Chocolate Cake slice"
	desc = "Just a slice of cake, it is enough for everyone."
	icon_state = "chocolatecake_slice"
	trash = /obj/item/trash/plate
	filling_color = "#805930"
	bitesize = 2
	tastes = list("cake" = 5, "sweetness" = 1, "chocolate" = 4)

/obj/item/reagent_containers/food/snacks/sliceable/cheesewheel
	name = "Cheese wheel"
	desc = "A big wheel of delcious Cheddar."
	icon_state = "cheesewheel"
	slice_path = /obj/item/reagent_containers/food/snacks/cheesewedge
	list_reagents = list(/datum/reagent/consumable/nutriment = 20)
	filling_color = "#FFF700"
	tastes = list("cheese" = 1)

/obj/item/reagent_containers/food/snacks/cheesewedge
	name = "Cheese wedge"
	desc = "A wedge of delicious Cheddar. The cheese wheel it was cut from can't have gone far."
	icon_state = "cheesewedge"
	filling_color = "#FFF700"
	bitesize = 2
	tastes = list("cheese" = 1)

/obj/item/reagent_containers/food/snacks/sliceable/birthdaycake
	name = "Birthday Cake"
	desc = "Happy Birthday..."
	icon_state = "birthdaycake"
	slice_path = /obj/item/reagent_containers/food/snacks/birthdaycakeslice
	list_reagents = list(/datum/reagent/consumable/nutriment = 20, /datum/reagent/consumable/sprinkles = 10)
	filling_color = "#FFD6D6"
	tastes = list("cake" = 5, "sweetness" = 1)

/obj/item/reagent_containers/food/snacks/birthdaycakeslice
	name = "Birthday Cake slice"
	desc = "A slice of your birthday"
	icon_state = "birthdaycakeslice"
	trash = /obj/item/trash/plate
	filling_color = "#FFD6D6"
	bitesize = 2
	tastes = list("cake" = 5, "sweetness" = 1)

/obj/item/reagent_containers/food/snacks/sliceable/bread
	name = "Bread"
	icon_state = "Some plain old Earthen bread."
	icon_state = "bread"
	slice_path = /obj/item/reagent_containers/food/snacks/breadslice
	list_reagents = list(/datum/reagent/consumable/nutriment = 6)
	filling_color = "#FFE396"
	tastes = list("bread" = 10)

/obj/item/reagent_containers/food/snacks/breadslice
	name = "Bread slice"
	desc = "A slice of home."
	icon_state = "breadslice"
	trash = /obj/item/trash/plate
	filling_color = "#D27332"
	bitesize = 2
	tastes = list("bread" = 10)


/obj/item/reagent_containers/food/snacks/sliceable/creamcheesebread
	name = "Cream Cheese Bread"
	desc = "Yum yum yum!"
	icon_state = "creamcheesebread"
	slice_path = /obj/item/reagent_containers/food/snacks/creamcheesebreadslice
	list_reagents = list(/datum/reagent/consumable/nutriment = 20)
	filling_color = "#FFF896"
	tastes = list("bread" = 10, "cheese" = 10)

/obj/item/reagent_containers/food/snacks/creamcheesebreadslice
	name = "Cream Cheese Bread slice"
	desc = "A slice of yum!"
	icon_state = "creamcheesebreadslice"
	trash = /obj/item/trash/plate
	filling_color = "#FFF896"
	bitesize = 2
	tastes = list("bread" = 10, "cheese" = 10)

/obj/item/reagent_containers/food/snacks/marinebread //meme bread for breadify smite
	name = "Bread"
	desc = "Some plain old Earthen bread. An air of penance surrounds it."
	icon_state = "breadtg"
	list_reagents = list(/datum/reagent/consumable/nutriment = 60)
	filling_color = "#FFF896"
	bitesize = 2
	tastes = list("guilt" = 1, "salt" = 1)

/obj/item/reagent_containers/food/snacks/marinebread/Destroy() //delete the marine trapped inside, tasty!
	for(var/i in contents)
		qdel(i)
	return ..()

/obj/item/reagent_containers/food/snacks/watermelonslice
	name = "Watermelon Slice"
	desc = "A slice of watery goodness."
	icon_state = "watermelonslice"
	filling_color = "#FF3867"
	bitesize = 2
	tastes = list("watermelon" = 1)


/obj/item/reagent_containers/food/snacks/sliceable/applecake
	name = "Apple Cake"
	desc = "A cake centred with Apple"
	icon_state = "applecake"
	slice_path = /obj/item/reagent_containers/food/snacks/applecakeslice
	list_reagents = list(/datum/reagent/consumable/nutriment = 15)
	filling_color = "#EBF5B8"
	tastes = list ("cake" = 5, "sweetness" = 1, "apple" = 1)

/obj/item/reagent_containers/food/snacks/applecakeslice
	name = "Apple Cake slice"
	desc = "A slice of heavenly cake."
	icon_state = "applecakeslice"
	trash = /obj/item/trash/plate
	filling_color = "#EBF5B8"
	bitesize = 2
	tastes = list("cake" = 5, "sweetness" = 1, "apple" = 1)

/obj/item/reagent_containers/food/snacks/sliceable/pumpkinpie
	name = "Pumpkin Pie"
	desc = "A delicious treat for the autumn months."
	icon_state = "pumpkinpie"
	slice_path = /obj/item/reagent_containers/food/snacks/pumpkinpieslice
	list_reagents = list(/datum/reagent/consumable/nutriment = 15)
	filling_color = "#F5B951"
	tastes = list("pie" = 1, "pumpkin" = 1)

/obj/item/reagent_containers/food/snacks/pumpkinpieslice
	name = "Pumpkin Pie slice"
	desc = "A slice of pumpkin pie, with whipped cream on top. Perfection."
	icon_state = "pumpkinpieslice"
	trash = /obj/item/trash/plate
	filling_color = "#F5B951"
	bitesize = 2
	tastes = list("pie" = 1, "pumpkin" = 1)

/obj/item/reagent_containers/food/snacks/cracker
	name = "Cracker"
	desc = "It's a salted cracker."
	icon_state = "cracker"
	filling_color = "#F5DEB8"
	list_reagents = list(/datum/reagent/consumable/nutriment = 1)
	tastes = list("cracker" = 1)



/////////////////////////////////////////////////PIZZA////////////////////////////////////////

/obj/item/reagent_containers/food/snacks/sliceable/pizza
	slices_num = 6
	bitesize = 1
	filling_color = "#BAA14C"
	tastes = list("crust" = 1, "tomato" = 1, "cheese" = 1)

/obj/item/reagent_containers/food/snacks/sliceable/pizza/margherita
	name = "Margherita"
	desc = "The golden standard of pizzas."
	icon_state = "margheritapizza"
	slice_path = /obj/item/reagent_containers/food/snacks/margheritaslice
	list_reagents = list(/datum/reagent/consumable/nutriment = 40, /datum/reagent/consumable/drink/tomatojuice = 6)
	tastes = list("crust" = 1, "tomato" = 1, "cheese" = 1)

/obj/item/reagent_containers/food/snacks/margheritaslice
	name = "Margherita slice"
	desc = "A slice of the classic pizza."
	icon_state = "margheritapizzaslice"
	filling_color = "#BAA14C"
	bitesize = 2
	tastes = list("crust" = 1, "tomato" = 1, "cheese" = 1)

/obj/item/reagent_containers/food/snacks/sliceable/pizza/meatpizza
	name = "Meatpizza"
	desc = "A pizza with meat topping."
	icon_state = "meatpizza"
	slice_path = /obj/item/reagent_containers/food/snacks/meatpizzaslice
	list_reagents = list(/datum/reagent/consumable/nutriment = 50, /datum/reagent/consumable/drink/tomatojuice = 6)
	tastes = list("crust" = 1, "tomato" = 1, "cheese" = 1, "meat" = 1)

/obj/item/reagent_containers/food/snacks/meatpizzaslice
	name = "Meatpizza slice"
	desc = "A slice of a meaty pizza."
	icon_state = "meatpizzaslice"
	filling_color = "#BAA14C"
	bitesize = 2
	tastes = list("crust" = 1, "tomato" = 1, "cheese" = 1, "meat" = 1)

/obj/item/reagent_containers/food/snacks/sliceable/pizza/mushroompizza
	name = "Mushroompizza"
	desc = "Very special pizza"
	icon_state = "mushroompizza"
	slice_path = /obj/item/reagent_containers/food/snacks/mushroompizzaslice
	list_reagents = list(/datum/reagent/consumable/nutriment = 35)
	tastes = list("crust" = 1, "tomato" = 1, "cheese" = 1, "mushroom" = 1)

/obj/item/reagent_containers/food/snacks/mushroompizzaslice
	name = "Mushroompizza slice"
	desc = "Maybe it is the last slice of pizza in your life."
	icon_state = "mushroompizzaslice"
	filling_color = "#BAA14C"
	bitesize = 2
	tastes = list("crust" = 1, "tomato" = 1, "cheese" = 1, "mushroom" = 1)

/obj/item/reagent_containers/food/snacks/sliceable/pizza/vegetablepizza
	name = "Vegetable pizza"
	desc = "No one of Tomato Sapiens were harmed during making this pizza"
	icon_state = "vegetablepizza"
	slice_path = /obj/item/reagent_containers/food/snacks/vegetablepizzaslice
	list_reagents = list(/datum/reagent/consumable/nutriment = 30, /datum/reagent/consumable/drink/tomatojuice = 6, /datum/reagent/medicine/imidazoline = 12)
	tastes = list("crust" = 1, "tomato" = 2, "cheese" = 1, "carrot" = 1)

/obj/item/reagent_containers/food/snacks/vegetablepizzaslice
	name = "Vegetable pizza slice"
	desc = "A slice of the most green pizza of all pizzas not containing green ingredients "
	icon_state = "vegetablepizzaslice"
	filling_color = "#BAA14C"
	bitesize = 2
	tastes = list("crust" = 1, "tomato" = 2, "cheese" = 1, "carrot" = 1)

/obj/item/pizzabox
	name = "pizza box"
	desc = "A box suited for pizzas."
	icon = 'icons/obj/items/food.dmi'
	icon_state = "pizzabox1"

	var/open = 0 // Is the box open?
	var/ismessy = 0 // Fancy mess on the lid
	var/obj/item/reagent_containers/food/snacks/sliceable/pizza/pizza // Content pizza
	var/list/boxes = list() // If the boxes are stacked, they come here
	var/boxtag = ""

/obj/item/pizzabox/update_icon()

	overlays = list()

	// Set appropriate description
	if( open && pizza )
		desc = "A box suited for pizzas. It appears to have a [pizza.name] inside."
	else if( boxes.len > 0 )
		desc = "A pile of boxes suited for pizzas. There appears to be [boxes.len + 1] boxes in the pile."

		var/obj/item/pizzabox/topbox = boxes[boxes.len]
		var/toptag = topbox.boxtag
		if( toptag != "" )
			desc = "[desc] The box on top has a tag, it reads: '[toptag]'."
	else
		desc = "A box suited for pizzas."

		if( boxtag != "" )
			desc = "[desc] The box has a tag, it reads: '[boxtag]'."

	// Icon states and overlays
	if( open )
		if( ismessy )
			icon_state = "pizzabox_messy"
		else
			icon_state = "pizzabox_open"

		if( pizza )
			var/image/pizzaimg = image("food.dmi", icon_state = pizza.icon_state)
			pizzaimg.pixel_y = -3
			overlays += pizzaimg

		return
	else
		// Stupid code because byondcode sucks
		var/doimgtag = 0
		if( boxes.len > 0 )
			var/obj/item/pizzabox/topbox = boxes[boxes.len]
			if( topbox.boxtag != "" )
				doimgtag = 1
		else
			if( boxtag != "" )
				doimgtag = 1

		if( doimgtag )
			var/image/tagimg = image("food.dmi", icon_state = "pizzabox_tag")
			tagimg.pixel_y = boxes.len * 3
			overlays += tagimg

	icon_state = "pizzabox[boxes.len+1]"

//ATTACK HAND IGNORING PARENT RETURN VALUE
/obj/item/pizzabox/attack_hand(mob/living/user)
	if( open && pizza )
		user.put_in_hands( pizza )

		to_chat(user, span_warning("You take the [src.pizza] out of the [src]."))
		src.pizza = null
		update_icon()
		return

	else if( boxes.len > 0 )
		if( user.get_inactive_held_item() != src )
			return ..()

		var/obj/item/pizzabox/box = boxes[boxes.len]
		boxes -= box

		user.put_in_hands( box )
		to_chat(user, span_warning("You remove the topmost [src] from your hand."))
		box.update_icon()
		update_icon()

	else
		return ..()

/obj/item/pizzabox/attack_self( mob/user as mob )

	if( boxes.len > 0 )
		return

	open = !open

	if( open && pizza )
		ismessy = 1

	update_icon()

/obj/item/pizzabox/attackby(obj/item/I, mob/user, params)
	. = ..()

	if(istype(I, /obj/item/pizzabox))
		var/obj/item/pizzabox/box = I

		if(box.open || open)
			to_chat(user, span_warning("Close the [box] first!"))
			return

		// Make a list of all boxes to be added
		var/list/boxestoadd = list()
		boxestoadd += box
		for(var/obj/item/pizzabox/i in box.boxes)
			boxestoadd += i

		if((length(boxes) + 1) + length(boxestoadd) > 5)
			to_chat(user, span_warning("The stack is too high!"))
			return

		user.transferItemToLoc(box, src)
		box.boxes = list()
		boxes.Add(boxestoadd)

		box.update_icon()
		update_icon()

		to_chat(user, span_warning("You put the [box] ontop of the [src]!"))

	else if(istype(I, /obj/item/reagent_containers/food/snacks/sliceable/pizza))
		if(!open)
			to_chat(user, span_warning("You try to push the [I] through the lid but it doesn't work!"))
			return

		user.transferItemToLoc(I, src)
		pizza = I

		update_icon()

		to_chat(user, span_warning("You put the [I] in the [src]!"))

	else if(istype(I, /obj/item/tool/pen))
		if(open)
			return

		var/t = stripped_input(user, "Enter what you want to add to the tag:", "Write", "", 30)

		boxtag = "[boxtag][t]"

		update_icon()


/obj/item/pizzabox/margherita/Initialize()
	. = ..()
	pizza = new /obj/item/reagent_containers/food/snacks/sliceable/pizza/margherita(src)
	boxtag = "Margherita Deluxe"


/obj/item/pizzabox/vegetable/Initialize()
	. = ..()
	pizza = new /obj/item/reagent_containers/food/snacks/sliceable/pizza/vegetablepizza(src)
	boxtag = "Gourmet Vegatable"


/obj/item/pizzabox/mushroom/Initialize()
	. = ..()
	pizza = new /obj/item/reagent_containers/food/snacks/sliceable/pizza/mushroompizza(src)
	boxtag = "Mushroom Special"


/obj/item/pizzabox/meat/Initialize()
	. = ..()
	pizza = new /obj/item/reagent_containers/food/snacks/sliceable/pizza/meatpizza(src)
	boxtag = "Meatlover's Supreme"

///////////////////////////////////////////
// new old food stuff from bs12
///////////////////////////////////////////

// Flour + egg = dough
/obj/item/reagent_containers/food/snacks/flour/attackby(obj/item/I, mob/user, params)
	. = ..()

	if(istype(I, /obj/item/reagent_containers/food/snacks/egg))
		new /obj/item/reagent_containers/food/snacks/dough(src)
		to_chat(user, "You make some dough.")
		qdel(I)
		qdel(src)

// Egg + flour = dough
/obj/item/reagent_containers/food/snacks/egg/attackby(obj/item/I, mob/user, params)
	. = ..()

	if(istype(I, /obj/item/reagent_containers/food/snacks/flour))
		new /obj/item/reagent_containers/food/snacks/dough(src)
		to_chat(user, "You make some dough.")
		qdel(I)
		qdel(src)

/obj/item/reagent_containers/food/snacks/dough
	name = "dough"
	desc = "A piece of dough."
	icon = 'icons/obj/items/food_ingredients.dmi'
	icon_state = "dough"
	list_reagents = list(/datum/reagent/consumable/nutriment = 2)
	bitesize = 2
	tastes = list("dough" = 1)

// Dough + rolling pin = flat dough
/obj/item/reagent_containers/food/snacks/dough/attackby(obj/item/I, mob/user, params)
	. = ..()

	if(istype(I, /obj/item/tool/kitchen/rollingpin))
		new /obj/item/reagent_containers/food/snacks/sliceable/flatdough(src)
		to_chat(user, "You flatten the dough.")
		qdel(src)

// slicable into 3xdoughslices
/obj/item/reagent_containers/food/snacks/sliceable/flatdough
	name = "flat dough"
	desc = "A flattened dough."
	icon = 'icons/obj/items/food_ingredients.dmi'
	icon_state = "flat dough"
	slice_path = /obj/item/reagent_containers/food/snacks/doughslice
	slices_num = 3
	list_reagents = list(/datum/reagent/consumable/nutriment = 3)
	tastes = list("dough" = 1)

/obj/item/reagent_containers/food/snacks/doughslice
	name = "dough slice"
	desc = "A building block of an impressive dish."
	icon = 'icons/obj/items/food_ingredients.dmi'
	icon_state = "doughslice"
	bitesize = 2
	list_reagents = list(/datum/reagent/consumable/nutriment = 1)
	tastes = list("dough" = 1)

/obj/item/reagent_containers/food/snacks/bun
	name = "bun"
	desc = "A base for any self-respecting burger."
	icon = 'icons/obj/items/food_ingredients.dmi'
	icon_state = "bun"
	bitesize = 2
	list_reagents = list(/datum/reagent/consumable/nutriment = 4)
	tastes = list("bun" = 1) // the bun tastes of bun.

/obj/item/reagent_containers/food/snacks/bun/attackby(obj/item/I, mob/user, params)
	. = ..()
	// Bun + meatball = burger
	if(istype(I, /obj/item/reagent_containers/food/snacks/meatball))
		new /obj/item/reagent_containers/food/snacks/monkeyburger(src)
		to_chat(user, "You make a burger.")
		qdel(I)
		qdel(src)

	// Bun + cutlet = hamburger
	else if(istype(I, /obj/item/reagent_containers/food/snacks/cutlet))
		new /obj/item/reagent_containers/food/snacks/monkeyburger(src)
		to_chat(user, "You make a burger.")
		qdel(I)
		qdel(src)

	// Bun + sausage = hotdog
	else if(istype(I,/obj/item/reagent_containers/food/snacks/sausage))
		new /obj/item/reagent_containers/food/snacks/hotdog(src)
		to_chat(user, "You make a hotdog.")
		qdel(I)
		qdel(src)

// Burger + cheese wedge = cheeseburger
/obj/item/reagent_containers/food/snacks/monkeyburger/attackby(obj/item/I, mob/user, params)
	. = ..()

	if(istype(I, /obj/item/reagent_containers/food/snacks/cheesewedge))
		new /obj/item/reagent_containers/food/snacks/cheeseburger(src)
		to_chat(user, "You make a cheeseburger.")
		qdel(I)
		qdel(src)

// Human Burger + cheese wedge = cheeseburger
/obj/item/reagent_containers/food/snacks/human/burger/attackby(obj/item/I, mob/user, params)
	. = ..()

	if(istype(I, /obj/item/reagent_containers/food/snacks/cheesewedge))
		new /obj/item/reagent_containers/food/snacks/cheeseburger(src)
		to_chat(user, "You make a cheeseburger.")
		qdel(I)
		qdel(src)

/obj/item/reagent_containers/food/snacks/taco
	name = "taco"
	desc = "Take a bite!"
	icon_state = "taco"
	bitesize = 3
	list_reagents = list(/datum/reagent/consumable/nutriment = 7)

/obj/item/reagent_containers/food/snacks/meat
	name = "meat"
	desc = "A slab of meat"
	icon_state = "meat"
	max_integrity = 180
	filling_color = "#FF1C1C"
	list_reagents = list(/datum/reagent/consumable/nutriment = 3)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/meat/attackby(obj/item/I, mob/user, params)
	. = ..()

	if(istype(I, /obj/item/tool/kitchen/knife))
		new /obj/item/reagent_containers/food/snacks/rawcutlet(src)
		new /obj/item/reagent_containers/food/snacks/rawcutlet(src)
		new /obj/item/reagent_containers/food/snacks/rawcutlet(src)
		to_chat(user, "You cut the meat in thin strips.")
		qdel(src)

/obj/item/reagent_containers/food/snacks/meat/syntiflesh
	name = "synthetic meat"
	desc = "A synthetic slab of flesh."

/obj/item/reagent_containers/food/snacks/meat/human
	name = "-meat"
	var/subjectname = ""
	var/subjectjob = null


/obj/item/reagent_containers/food/snacks/meat/monkey
	//same as plain meat

/obj/item/reagent_containers/food/snacks/meat/corgi
	name = "Corgi meat"
	desc = "Tastes like... well you know..."

/obj/item/reagent_containers/food/snacks/rawcutlet
	name = "raw cutlet"
	desc = "A thin piece of raw meat."
	icon = 'icons/obj/items/food_ingredients.dmi'
	icon_state = "rawcutlet"
	bitesize = 1
	list_reagents = list(/datum/reagent/consumable/nutriment = 1)
	tastes = list("meat" = 1)

/obj/item/reagent_containers/food/snacks/cutlet
	name = "cutlet"
	desc = "A tasty meat slice."
	icon = 'icons/obj/items/food_ingredients.dmi'
	icon_state = "cutlet"
	bitesize = 2
	list_reagents = list(/datum/reagent/consumable/nutriment = 2)
	tastes = list("meat" = 1)


/obj/item/reagent_containers/food/snacks/rawmeatball
	name = "raw meatball"
	desc = "A raw meatball."
	icon = 'icons/obj/items/food_ingredients.dmi'
	icon_state = "rawmeatball"
	bitesize = 2
	list_reagents = list(/datum/reagent/consumable/nutriment = 2)

/obj/item/reagent_containers/food/snacks/hotdog
	name = "hotdog"
	desc = "Unrelated to dogs, maybe."
	icon_state = "hotdog"
	bitesize = 2
	list_reagents = list(/datum/reagent/consumable/nutriment = 6)
	tastes = list("bun" = 3, "meat" = 2)

/obj/item/reagent_containers/food/snacks/flatbread
	name = "flatbread"
	desc = "Bland but filling."
	icon = 'icons/obj/items/food_ingredients.dmi'
	icon_state = "flatbread"
	bitesize = 2
	list_reagents = list(/datum/reagent/consumable/nutriment = 3)

// potato + knife = raw sticks
/obj/item/reagent_containers/food/snacks/grown/potato/attackby(obj/item/I, mob/user, params)
	. = ..()

	if(istype(I, /obj/item/tool/kitchen/utensil/knife))
		new /obj/item/reagent_containers/food/snacks/rawsticks(src)
		to_chat(user, "You cut the potato.")
		qdel(src)

/obj/item/reagent_containers/food/snacks/rawsticks
	name = "raw potato sticks"
	desc = "Raw fries, not very tasty."
	icon = 'icons/obj/items/food_ingredients.dmi'
	icon_state = "rawsticks"
	bitesize = 2
	list_reagents = list(/datum/reagent/consumable/nutriment = 3)
	tastes = list("potatoes" = 3, "salt" = 1)

/obj/item/reagent_containers/food/snacks/packaged_burrito
	name = "Packaged Burrito"
	desc = "A hard microwavable burrito. There's no time given for how long to cook it. Packaged by the Nanotrasen Corporation."
	icon_state = "burrito"
	bitesize = 2
	package = TRUE
	list_reagents = list(/datum/reagent/consumable/nutriment = 5)
	tastes = list("tortilla" = 2, "beans" = 2)

/obj/item/reagent_containers/food/snacks/packaged_burrito/attack_self(mob/user as mob)
	if(package)
		playsound(src.loc,'sound/effects/pageturn2.ogg', 15, 1)
		to_chat(user, span_notice("You pull off the wrapping from the squishy burrito!"))
		package = FALSE
		icon_state = "openburrito"

/obj/item/reagent_containers/food/snacks/packaged_burger
	name = "Packaged Cheeseburger"
	desc = "A soggy microwavable burger. There's no time given for how long to cook it. Packaged by the Nanotrasen Corporation."
	icon_state = "burger"
	bitesize = 3
	package = TRUE
	list_reagents = list(/datum/reagent/consumable/nutriment = 5, /datum/reagent/consumable/sodiumchloride = 2)
	tastes = list("bun" = 4, "soy protein" = 2) //Cheap fridge burgers.


/obj/item/reagent_containers/food/snacks/packaged_burger/attack_self(mob/user as mob)
	if (package)
		playsound(src.loc,'sound/effects/pageturn2.ogg', 15, 1)
		to_chat(user, span_notice("You pull off the wrapping from the squishy hamburger!"))
		package = FALSE
		icon_state = "hburger"

/obj/item/reagent_containers/food/snacks/packaged_hdogs
	name = "Packaged Hotdog"
	desc = "A singular squishy, room temperature, hot dog. There's no time given for how long to cook it, so you assume its probably good to go. Packaged by the Nanotrasen Corporation."
	icon_state = "hot_dogs"
	bitesize = 2
	package = TRUE
	list_reagents = list(/datum/reagent/consumable/nutriment = 3, /datum/reagent/consumable/sodiumchloride = 2)
	tastes = list("dough" = 1, "chicken" = 1)

/obj/item/reagent_containers/food/snacks/packaged_hdogs/attack_self(mob/user as mob)
	if (package)
		playsound(src.loc,'sound/effects/pageturn2.ogg', 15, 1)
		to_chat(user, span_notice("You pull off the wrapping from the squishy hotdog!"))
		package = FALSE
		icon_state = "hotdog"

/obj/item/reagent_containers/food/snacks/upp
	name = "\improper USL ration"
	desc = "A sealed, freeze-dried, compressed package containing a single item of food. Commonplace in the USL pirate band and even those who live on Mars, especially those stationed on far-flung colonies. This one is was packaged in 2415."
	icon_state = "upp_ration"
	bitesize = 2
	package = TRUE
	list_reagents = list(/datum/reagent/consumable/nutriment = 4, /datum/reagent/consumable/sodiumchloride = 0.5)
	var/variation = null


/obj/item/reagent_containers/food/snacks/upp/Initialize()
	if(!variation)
		variation = pick("fish","rice")

	switch(variation)
		if("fish")
			tastes = list("dried [pick("carp", "shark", "tuna", "fish")]" = 1, "[pick("potatoes", "borsch", "borshch", "bortsch", "hardtack")]" = 1)
		if("rice")
			tastes = list("[pick("rice", "rye", "starch")]" = 1, "[pick("sawdust", "beans", "chicken")]" = 1)

	return ..()

/obj/item/reagent_containers/food/snacks/upp/attack_self(mob/user as mob)
	if (package)
		playsound(src.loc,'sound/effects/pageturn2.ogg', 15, 1)
		to_chat(user, span_notice("You tear off the ration seal and pull out the contents!"))
		package = FALSE
		desc = "An extremely dried item of food, with little flavoring or coloration. Looks to be prepped for long term storage, but will expire without the packaging. Best to eat it now to avoid waste. At least things are equal."
		switch(variation)
			if("fish")
				name = "rationed fish"
				icon_state = "upp_1"
			if("rice")
				name = "rationed rice"
				icon_state = "upp_2"

/obj/item/reagent_containers/food/snacks/upp/fish
	name = "\improper UPP ration (fish)"
	variation = "fish"

/obj/item/reagent_containers/food/snacks/upp/rice
	name = "\improper UPP ration (cereal)"
	variation = "rice"

/obj/item/reagent_containers/food/snacks/enrg_bar
	name = "EnrG Bar"
	desc = "A calorie-dense bar made with ingredients with unpronounceable names. Somehow, even the packaging is edible."
	icon_state = "energybar"
	bitesize = 2
	w_class = WEIGHT_CLASS_TINY
	trash = /obj/item/trash/eat
	//no taste, default to "something indescribable"
	list_reagents = list(/datum/reagent/consumable/nutriment = 3)


/obj/item/reagent_containers/food/snacks/kepler_crisps
	name = "Kepler Crisps"
	desc = "'They're disturbingly good!' Now with 0% trans fat."
	icon_state = "kepler"
	bitesize = 2
	trash = /obj/item/trash/kepler
	list_reagents = list(/datum/reagent/consumable/nutriment = 3, /datum/reagent/consumable/sodiumchloride = 1)
	tastes = list("chips" = 2)

//Wrapped candy bars

/obj/item/reagent_containers/food/snacks/wrapped
	package = TRUE
	bitesize = 3
	var/obj/item/trash/wrapper = null //Why this and not trash? Because it pulls the wrapper off when you unwrap it as a trash item.

/obj/item/reagent_containers/food/snacks/wrapped/attack_self(mob/user as mob)
	if (package)
		to_chat(user, span_notice("You pull open the package of [src]!"))
		playsound(loc,'sound/effects/pageturn2.ogg', 15, 1)

		new wrapper (user.loc)
		icon_state = "[initial(icon_state)]-o"
		package = FALSE


/obj/item/reagent_containers/food/snacks/wrapped/booniebars
	name = "Boonie Bars"
	desc = "Two delicious bars of minty chocolate. <i>\"Sometimes things are just... out of reach.\"</i>"
	icon_state = "boonie"
	bitesize = 2 //Two bars
	wrapper = /obj/item/trash/boonie
	list_reagents = list(/datum/reagent/consumable/nutriment = 4, /datum/reagent/consumable/coco = 4)
	tastes = list("peppermint" = 3, "falling into the sun" = 1)

/obj/item/reagent_containers/food/snacks/wrapped/chunk
	name = "CHUNK box"
	desc = "A bar of \"The <b>CHUNK</b>\" brand chocolate. <i>\"The densest chocolate permitted to exist according to federal law. We are legally required to ask you not to use this blunt object for anything other than nutrition.\"</i>"
	icon_state = "chunk"
	force = 35 //LEGAL LIMIT OF CHOCOLATE
	bitesize = 3
	wrapper = /obj/item/trash/chunk
	list_reagents = list(/datum/reagent/consumable/nutriment = 5, /datum/reagent/consumable/coco = 10)
	tastes = list("compressed matter" = 1)

/obj/item/reagent_containers/food/snacks/wrapped/barcardine
	name = "Barcardine Bars"
	desc = "A bar of chocolate, it smells like the medical bay. <i>\"Chocolate always helps the pain go away.\"</i>"
	icon_state = "barcardine"
	wrapper = /obj/item/trash/barcardine
	list_reagents = list(/datum/reagent/consumable/nutriment = 3, /datum/reagent/consumable/coco = 2, /datum/reagent/medicine/tramadol = 1, /datum/reagent/medicine/tramadol = 1)
	tastes = list("cough syrup" = 1)

//MREs

/obj/item/reagent_containers/food/snacks/packaged_meal
	name = "\improper MRE component"
	package = TRUE
	bitesize = 1
	icon_state = "entree"
	var/flavor = "boneless pork ribs"//default value


/obj/item/reagent_containers/food/snacks/packaged_meal/Initialize(mapload, newflavor)
	tastes = list("[pick(SSstrings.get_list_from_file("names/food_adjectives"))]" = 1) //idea, list, gimmick
	determinetype(newflavor)
	desc = "A packaged [icon_state] from a Meal Ready-to-Eat, there is a lengthy list of [pick("obscure", "arcane", "unintelligible", "revolutionary", "sophisticated", "unspellable")] ingredients and addictives printed on the back.</i>"
	return ..()

/obj/item/reagent_containers/food/snacks/packaged_meal/attack_self(mob/user as mob)
	if (package)
		to_chat(user, span_notice("You pull open the MRE package!"))
		playsound(loc,'sound/effects/pageturn2.ogg', 15, 1)
		name = "\improper" + flavor
		desc = "The contents of a standard issue MRE. This one is " + flavor + "."
		icon_state = flavor
		package = FALSE

/obj/item/reagent_containers/food/snacks/packaged_meal/proc/determinetype(newflavor)
	name = "\improper MRE component" + " (" + newflavor + ")"
	flavor = newflavor

	switch(newflavor)
		if("boneless pork ribs", "grilled chicken", "pizza square", "spaghetti", "chicken tenders")
			icon_state = "entree"
			list_reagents = list(/datum/reagent/consumable/nutriment = 5, /datum/reagent/consumable/sodiumchloride = 1)
		if("meatballs", "cheese spread", "beef turnover", "mashed potatoes")
			icon_state = "side"
			list_reagents = list(/datum/reagent/consumable/nutriment = 3, /datum/reagent/consumable/sodiumchloride = 1)
		if("biscuit", "pretzels", "peanuts", "cracker")
			icon_state = "snack"
			list_reagents = list(/datum/reagent/consumable/nutriment = 2, /datum/reagent/consumable/sodiumchloride = 1)
		if("spiced apples", "chocolate brownie", "sugar cookie", "choco bar", "crayon")
			icon_state = "dessert"
			list_reagents = list(/datum/reagent/consumable/nutriment = 2, /datum/reagent/consumable/sugar = 1)


/obj/item/reagent_containers/food/snacks/lollipop
	name = "lollipop"
	desc = "A delicious lollipop."
	icon = 'icons/obj/items/lollipop.dmi'
	icon_state = "lollipop_stick"
	item_state = "lollipop_stick"
	flags_equip_slot = ITEM_SLOT_MASK
	w_class = WEIGHT_CLASS_TINY
	list_reagents = list(/datum/reagent/consumable/nutriment = 1, /datum/reagent/consumable/sugar = 4)
	tastes = list("candy" = 1)
	var/mutable_appearance/head
	var/headcolor = rgb(0, 0, 0)
	var/succ_int = 100
	var/next_succ = 0
	var/mob/living/carbon/owner

/obj/item/reagent_containers/food/snacks/lollipop/Initialize()
	. = ..()
	head = mutable_appearance('icons/obj/items/lollipop.dmi', "lollipop_head")
	change_head_color(rgb(rand(0, 255), rand(0, 255), rand(0, 255)))

//makes lollipops actually wearable as masks and still edible the old fashioned way.
/obj/item/reagent_containers/food/snacks/lollipop/proc/handle_reagents()
	var/fraction = min(FOOD_METABOLISM/reagents.total_volume, 1)
	reagents.reaction(owner, INGEST, fraction)
	if(!reagents.trans_to(owner, FOOD_METABOLISM))
		reagents.remove_any(FOOD_METABOLISM)

/obj/item/reagent_containers/food/snacks/lollipop/process()
	if(!owner)
		stack_trace("lollipop processing without an owner")
		return PROCESS_KILL
	if(!reagents)
		stack_trace("lollipop processing without a reagents datum")
		return PROCESS_KILL
	if(owner.stat == DEAD)
		return PROCESS_KILL
	if(!reagents.total_volume)
		qdel(src)
		return
	if(next_succ <= world.time)
		handle_reagents()
		next_succ = world.time + succ_int

/obj/item/reagent_containers/food/snacks/lollipop/equipped(mob/user, slot)
	. = ..()
	if(!iscarbon(user))
		return
	if(slot != SLOT_WEAR_MASK)
		owner = null
		STOP_PROCESSING(SSobj, src) //equipped is triggered when moving from hands to mouth and vice versa
		return
	owner = user
	START_PROCESSING(SSobj, src)

/obj/item/reagent_containers/food/snacks/lollipop/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/item/reagent_containers/food/snacks/lollipop/proc/change_head_color(C)
	headcolor = C
	cut_overlay(head)
	head.color = C
	add_overlay(head)

//med pop
/obj/item/reagent_containers/food/snacks/lollipop/tramadol
	name = "Tram-pop"
	desc = "Your reward for behaving so well in the medbay. Can be eaten or put in the mask slot."
	list_reagents = list(/datum/reagent/consumable/sugar = 1, /datum/reagent/medicine/tramadol = 4)
	tastes = list("cough syrup" = 1, "artificial sweetness" = 1)

/obj/item/reagent_containers/food/snacks/lollipop/tramadol/combat
	desc = "A lolipop devised after realizations that a massive amount of marines end up with a crippling opiod addiction, meant to fight against that. Whether it works or not is up to you, really. Can be eaten or put in the mask slot"
	list_reagents = list(/datum/reagent/consumable/sugar = 1, /datum/reagent/medicine/tramadol = 10)
	tastes = list("cough syrup" = 1, "artificial sweetness" = 1)

/obj/item/reagent_containers/food/snacks/lollipop/combat
	name = "Commed-pop"
	desc = "A lolipop devised to heal wounds overtime, with a slower amount of reagent use. Can be eaten or put in the mask slot"
	list_reagents = list(/datum/reagent/consumable/sugar = 1, /datum/reagent/medicine/bicaridine = 5, /datum/reagent/medicine/kelotane = 5)

/obj/item/reagent_containers/food/snacks/lollipop/tricord
	name = "Tricord-pop"
	desc = "A lolipop laced with tricordazine, a slow healing reagent. Can be eaten or put in the mask slot."
	list_reagents = list(/datum/reagent/consumable/sugar = 1, /datum/reagent/medicine/tricordrazine = 10)
	tastes = list("cough syrup" = 1, "artificial sweetness" = 1)
