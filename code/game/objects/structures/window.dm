/obj/structure/window
	name = "window"
	desc = "A glass window. It looks thin and flimsy. A few knocks with anything should shatter it."
	icon = 'icons/obj/structures/windows.dmi'
	icon_state = "window"
	hit_sound = 'sound/effects/Glasshit.ogg'
	density = TRUE
	anchored = TRUE
	layer = WINDOW_LAYER
	flags_atom = ON_BORDER
	resistance_flags = XENO_DAMAGEABLE | DROPSHIP_IMMUNE
	coverage = 20
	var/dismantle = FALSE //If we're dismantling the window properly no smashy smashy
	max_integrity = 15
	var/state = 2
	var/reinf = FALSE
	var/basestate = "window"
	var/shardtype = /obj/item/shard
	var/windowknock_cooldown = 0
	var/static_frame = FALSE //If true, can't move the window
	var/junction = 0 //Because everything is terrible, I'm making this a window-level var
	var/damageable = TRUE
	var/deconstructable = TRUE

//I hate this as much as you do
/obj/structure/window/full
	dir = 10

/obj/structure/window/Initialize(mapload, start_dir, constructed)
	..()

	//player-constructed windows
	if(constructed)
		anchored = FALSE
		state = 0

	if(start_dir)
		setDir(start_dir)

	return INITIALIZE_HINT_LATELOAD


/obj/structure/window/LateInitialize()
	. = ..()
	update_nearby_icons()


/obj/structure/window/Destroy()
	density = FALSE
	update_nearby_icons()
	return ..()


/obj/structure/window/ex_act(severity)
	switch(severity)
		if(EXPLODE_DEVASTATE)
			take_damage(rand(125, 250))
		if(EXPLODE_HEAVY)
			take_damage(rand(75, 125))
		if(EXPLODE_LIGHT)
			take_damage(rand(25, 75))

//TODO: Make full windows a separate type of window.
//Once a full window, it will always be a full window, so there's no point
//having the same type for both.
/obj/structure/window/proc/is_full_window()
	if(!(flags_atom & ON_BORDER) || ISDIAGONALDIR(dir))
		return TRUE
	return FALSE


/obj/structure/window/CanAllowThrough(atom/movable/mover, turf/target)
	. = ..()
	if(CHECK_BITFIELD(mover.flags_pass, PASSGLASS))
		return TRUE
	if(!is_full_window() && !(get_dir(loc, target) == dir))
		return TRUE

/obj/structure/window/CheckExit(atom/movable/mover, direction)
	. = ..()
	if(CHECK_BITFIELD(mover.flags_pass, PASSGLASS))
		return TRUE

/obj/structure/window/attack_hand(mob/living/user)
	. = ..()
	if(.)
		return
	if(user.a_intent == INTENT_HARM)

		if(istype(user,/mob/living/carbon/human))
			var/mob/living/carbon/human/H = user
			if(H.species.can_shred(H))
				attack_generic(H, 25)
				return

		if(windowknock_cooldown > world.time)
			return
		playsound(loc, 'sound/effects/glassknock.ogg', 25, 1)
		user.visible_message(span_warning("[user] bangs against [src]!"),
		span_warning("You bang against [src]!"),
		span_warning("You hear a banging sound."))
		windowknock_cooldown = world.time + 100
	else
		if(windowknock_cooldown > world.time)
			return
		playsound(loc, 'sound/effects/glassknock.ogg', 15, 1)
		user.visible_message(span_notice("[user] knocks on [src]."),
		span_notice("You knock on [src]."),
		span_notice("You hear a knocking sound."))
		windowknock_cooldown = world.time + 100

/obj/structure/window/attackby(obj/item/I, mob/user, params)
	. = ..()

	if(istype(I, /obj/item/grab) && get_dist(src, user) < 2)
		if(isxeno(user))
			return
		var/obj/item/grab/G = I
		if(!isliving(G.grabbed_thing))
			return

		var/mob/living/M = G.grabbed_thing
		var/state = user.grab_state
		user.drop_held_item()
		switch(state)
			if(GRAB_PASSIVE)
				M.visible_message(span_warning("[user] slams [M] against \the [src]!"))
				log_combat(user, M, "slammed", "", "against \the [src]")
				M.apply_damage(7)
				UPDATEHEALTH(M)
				take_damage(10)
			if(GRAB_AGGRESSIVE)
				M.visible_message(span_danger("[user] bashes [M] against \the [src]!"))
				log_combat(user, M, "bashed", "", "against \the [src]")
				if(prob(50))
					M.Paralyze(20)
				M.apply_damage(10)
				UPDATEHEALTH(M)
				take_damage(25)
			if(GRAB_NECK)
				M.visible_message(span_danger("<big>[user] crushes [M] against \the [src]!</big>"))
				log_combat(user, M, "crushed", "", "against \the [src]")
				M.Paralyze(10 SECONDS)
				M.apply_damage(20)
				UPDATEHEALTH(M)
				take_damage(50)

	else if(I.flags_item & NOBLUDGEON)
		return

	else if(isscrewdriver(I) && deconstructable)
		dismantle = TRUE
		if(reinf && state >= 1)
			state = 3 - state
			playsound(loc, 'sound/items/screwdriver.ogg', 25, 1)
			to_chat(user, (state == 1 ? span_notice("You have unfastened the window from the frame.") : span_notice("You have fastened the window to the frame.")))
		else if(reinf && state == 0 && !static_frame)
			anchored = !anchored
			update_nearby_icons()
			playsound(loc, 'sound/items/screwdriver.ogg', 25, 1)
			to_chat(user, (anchored ? span_notice("You have fastened the frame to the floor.") : span_notice("You have unfastened the frame from the floor.")))
		else if(!reinf && !static_frame)
			anchored = !anchored
			update_nearby_icons()
			playsound(loc, 'sound/items/screwdriver.ogg', 25, 1)
			to_chat(user, (anchored ? span_notice("You have fastened the window to the floor.") : span_notice("You have unfastened the window.")))
		else if(!reinf || (static_frame && state == 0))
			deconstruct(TRUE)

	else if(iscrowbar(I) && reinf && state <= 1 && deconstructable)
		dismantle = TRUE
		state = 1 - state
		playsound(loc, 'sound/items/crowbar.ogg', 25, 1)
		to_chat(user, (state ? span_notice("You have pried the window into the frame.") : span_notice("You have pried the window out of the frame.")))


/obj/structure/window/deconstruct(disassembled = TRUE)
	if(disassembled)
		if(reinf)
			new /obj/item/stack/sheet/glass/reinforced(loc, 2)
		else
			new /obj/item/stack/sheet/glass(loc, 2)
	else
		new shardtype(loc)
		if(is_full_window())
			new shardtype(loc)
		if(reinf)
			new /obj/item/stack/rods(loc)
	return ..()


/obj/structure/window/verb/rotate()
	set name = "Rotate Window Counter-Clockwise"
	set category = "Object"
	set src in oview(1)

	if(static_frame)
		return FALSE
	if(!deconstructable)
		return FALSE
	if(anchored)
		to_chat(usr, span_warning("It is fastened to the floor, you can't rotate it!"))
		return FALSE

	setDir(turn(dir, 90))



/obj/structure/window/verb/revrotate()
	set name = "Rotate Window Clockwise"
	set category = "Object"
	set src in oview(1)

	if(static_frame)
		return FALSE
	if(!deconstructable)
		return FALSE
	if(anchored)
		to_chat(usr, span_warning("It is fastened to the floor, you can't rotate it!"))
		return FALSE

	setDir(turn(dir, 270))

/obj/structure/window/Move()
	var/ini_dir = dir
	. = ..()
	setDir(ini_dir)

//This proc is used to update the icons of nearby windows.
/obj/structure/window/proc/update_nearby_icons()
	update_icon()
	for(var/direction in GLOB.cardinals)
		for(var/obj/structure/window/W in get_step(src, direction))
			INVOKE_NEXT_TICK(W, /atom/movable.proc/update_icon)

//merges adjacent full-tile windows into one (blatant ripoff from game/smoothwall.dm)
/obj/structure/window/update_icon()
	//A little cludge here, since I don't know how it will work with slim windows. Most likely VERY wrong.
	//this way it will only update full-tile ones
	if(!src)
		return
	if(!is_full_window())
		icon_state = "[basestate]"
		return
	if(anchored)
		for(var/obj/structure/window/W in orange(src, 1))
			if(W.anchored && W.density	&& W.is_full_window()) //Only counts anchored, not-destroyed fill-tile windows.
				if(abs(x - W.x) - abs(y - W.y)) //Doesn't count windows, placed diagonally to src
					junction |= get_dir(src, W)
	if(opacity)
		icon_state = "[basestate][junction]"
	else
		if(reinf)
			icon_state = "[basestate][junction]"
		else
			icon_state = "[basestate][junction]"

/obj/structure/window/fire_act(exposed_temperature, exposed_volume)
	if(exposed_temperature > T0C + 800)
		take_damage(round(exposed_volume / 100), BURN, "fire")
	return ..()

/obj/structure/window/GetExplosionBlock(explosion_dir)
	return (!explosion_dir || ISDIAGONALDIR(dir) || dir & explosion_dir || REVERSE_DIR(dir) & explosion_dir) ? real_explosion_block : 0

/obj/structure/window/phoronbasic
	name = "phoron window"
	desc = "A phoron-glass alloy window. It looks insanely tough to break. It appears it's also insanely tough to burn through."
	basestate = "phoronwindow"
	icon_state = "phoronwindow"
	shardtype = /obj/item/shard/phoron
	max_integrity = 120
	explosion_block = EXPLOSION_BLOCK_PROC
	real_explosion_block = 2

/obj/structure/window/phoronbasic/fire_act(exposed_temperature, exposed_volume)
	if(exposed_temperature > T0C + 32000)
		take_damage(round(exposed_volume / 1000), BURN, "fire")
	return ..()

/obj/structure/window/phoronreinforced
	name = "reinforced phoron window"
	desc = "A phoron-glass alloy window with a rod matrice. It looks hopelessly tough to break. It also looks completely fireproof, considering how basic phoron windows are insanely fireproof."
	basestate = "phoronrwindow"
	icon_state = "phoronrwindow"
	shardtype = /obj/item/shard/phoron
	reinf = TRUE
	max_integrity = 160
	explosion_block = EXPLOSION_BLOCK_PROC
	real_explosion_block = 4

/obj/structure/window/phoronreinforced/fire_act(exposed_temperature, exposed_volume)
	return

/obj/structure/window/reinforced
	name = "reinforced window"
	desc = "A glass window with a rod matrice. It looks rather strong. Might take a few good hits to shatter it."
	icon_state = "rwindow"
	basestate = "rwindow"
	max_integrity = 40
	reinf = TRUE
	explosion_block = EXPLOSION_BLOCK_PROC
	real_explosion_block = 2

/obj/structure/window/reinforced/toughened
	name = "safety glass"
	desc = "A very tough looking glass window with a special rod matrice, probably bullet proof."
	icon_state = "rwindow"
	basestate = "rwindow"
	max_integrity = 300
	reinf = TRUE

//For the sulaco and POS AI core.
/obj/structure/window/reinforced/extratoughened
	name = "protective AI glass"
	desc = "Heavily reinforced glass with many layers of a rod matrice. This is rarely used for anything but the most important windows"
	icon_state = "rwindow"
	basestate = "rwindow"
	max_integrity = 1500
	reinf = TRUE
	resistance_flags = 10 // I have no clue what those are.

/obj/structure/window/reinforced/tinted
	name = "tinted window"
	desc = "A glass window with a rod matrice. It looks rather strong and opaque. Might take a few good hits to shatter it."
	icon_state = "twindow"
	basestate = "twindow"
	opacity = TRUE

/obj/structure/window/reinforced/tinted/frosted
	name = "frosted window"
	desc = "A glass window with a rod matrice. It looks rather strong and frosted over. Looks like it might take a few less hits then a normal reinforced window."
	icon_state = "fwindow"
	basestate = "fwindow"
	max_integrity = 30

/obj/structure/window/shuttle
	name = "shuttle window"
	desc = "A shuttle glass window with a rod matrice specialised for heat resistance. It looks rather strong. Might take a few good hits to shatter it."
	icon = 'icons/obj/podwindows.dmi'
	icon_state = "window"
	basestate = "window"
	max_integrity = 40
	reinf = TRUE
	flags_atom = NONE

/obj/structure/window/shuttle/update_icon() //icon_state has to be set manually
	return

//Framed windows

/obj/structure/window/framed
	name = "theoretical window"
	layer = TABLE_LAYER
	static_frame = TRUE
	flags_atom = NONE //This is not a border object; it takes up the entire tile.
	explosion_block = 2
	var/window_frame //For perspective windows,so the window frame doesn't magically dissapear
	var/list/tiles_special = list(/obj/machinery/door/airlock,
		/obj/structure/window/framed,
		/obj/structure/girder,
		/obj/structure/window_frame)
	tiles_with = list(
		/turf/closed/wall,
	)

/obj/structure/window/framed/Initialize()
	relativewall()
	relativewall_neighbours()
	. = ..()

/obj/structure/window/framed/update_nearby_icons()
	relativewall_neighbours()

/obj/structure/window/framed/update_icon()
	relativewall()


/obj/structure/window/framed/deconstruct(disassembled = TRUE)
	if(window_frame)
		var/obj/structure/window_frame/WF = new window_frame(loc)
		WF.icon_state = "[WF.basestate][junction]_frame"
		WF.setDir(dir)
	return ..()


/obj/structure/window/framed/mainship
	name = "reinforced window"
	desc = "A glass window with a special rod matrice inside a wall frame. It looks rather strong. Might take a few good hits to shatter it."
	icon_state = "ship_rwindow0"
	basestate = "ship_rwindow"
	max_integrity = 100 //Was 600
	reinf = TRUE
	dir = 5
	window_frame = /obj/structure/window_frame/mainship

/obj/structure/window/framed/mainship/canterbury //So we can wallsmooth properly.

/obj/structure/window/framed/mainship/toughened
	name = "safety glass"
	desc = "A very tough looking glass window with a special rod matrice, probably bullet proof."
	max_integrity = 300

/obj/structure/window/framed/mainship/spaceworthy
	name = "cockpit window"
	desc = "A very tough looking glass window with a special rod matrice, made to be space worthy."
	max_integrity = 500
	icon_state = "gray_window0_frame"
	basestate = "gray_window"

/obj/structure/window/framed/mainship/spaceworthy/Initialize()
	. = ..()
	AddElement(/datum/element/windowshutter/cokpitshutters)

/obj/structure/window/framed/mainship/hull
	name = "hull window"
	desc = "A glass window with a special rod matrice inside a wall frame. This one was made out of exotic materials to prevent hull breaches. No way to get through here."
	//icon_state = "rwindow0_debug" //Uncomment to check hull in the map editor
	damageable = FALSE
	deconstructable = FALSE
	resistance_flags = RESIST_ALL
	max_integrity = 1000000 //Failsafe, shouldn't matter

/obj/structure/window/framed/mainship/hull/canterbury //So we can wallsmooth properly.
	tiles_with = list(/turf/closed/wall/mainship/outer/canterbury)
	tiles_special = list(/obj/structure/window/framed/mainship/hull/canterbury)

/obj/structure/window/framed/mainship/requisitions
	name = "kevlar-weave infused bulletproof window"
	desc = "A borosilicate glass window infused with kevlar fibres and mounted within a special shock-absorbing frame, this is gonna be seriously hard to break through."
	max_integrity = 1000
	deconstructable = FALSE

/obj/structure/window/framed/mainship/white
	icon_state = "white_rwindow0"
	basestate = "white_rwindow"
	window_frame = /obj/structure/window_frame/mainship/white

/obj/structure/window/framed/mainship/white/canterbury //So we can wallsmooth properly.

/obj/structure/window/framed/mainship/gray
	icon_state = "gray_window0"
	basestate = "gray_window"
	window_frame = /obj/structure/window_frame/mainship/gray
	reinf = FALSE

/obj/structure/window/framed/mainship/gray/toughened
	name = "safety glass"
	desc = "A very tough looking glass window with a special rod matrice, probably bullet proof."
	max_integrity = 300
	reinf = TRUE
	icon_state = "gray_rwindow0"
	basestate = "gray_rwindow"

/obj/structure/window/framed/mainship/gray/toughened/hull
	name = "hull window"
	desc = "A glass window with a special rod matrice inside a wall frame. This one was made out of exotic materials to prevent hull breaches. No way to get through here."
	damageable = FALSE
	deconstructable = FALSE
	resistance_flags = RESIST_ALL
/obj/structure/window/framed/colony
	name = "window"
	icon_state = "col_window0"
	basestate = "col_window"
	window_frame = /obj/structure/window_frame/colony

/obj/structure/window/framed/colony/reinforced
	name = "reinforced window"
	icon_state = "col_rwindow0"
	basestate = "col_rwindow"
	desc = "A glass window with a special rod matrice inside a wall frame. It looks rather strong. Might take a few good hits to shatter it."
	max_integrity = 100
	reinf = 1
	window_frame = /obj/structure/window_frame/colony/reinforced

/obj/structure/window/framed/colony/reinforced/tinted
	name =  "tinted reinforced window"
	desc = "A glass window with a special rod matrice inside a wall frame. It looks rather strong. Might take a few good hits to shatter it. This one is opaque. You have an uneasy feeling someone might be watching from the other side."
	opacity = TRUE

/obj/structure/window/framed/colony/reinforced/hull
	name = "hull window"
	desc = "A glass window with a special rod matrice inside a wall frame. This one was made out of exotic materials to prevent hull breaches. No way to get through here."
	//icon_state = "rwindow0_debug" //Uncomment to check hull in the map editor
	damageable = FALSE
	deconstructable = FALSE
	resistance_flags = RESIST_ALL
	max_integrity = 1000000 //Failsafe, shouldn't matter



//Chigusa windows

/obj/structure/window/framed/chigusa
	name = "reinforced window"
	icon_state = "chig_rwindow0"
	basestate = "chig_rwindow"
	desc = "A glass window with a special rod matrice inside a wall frame. It looks rather strong. Might take a few good hits to shatter it."
	max_integrity = 100
	reinf = TRUE
	window_frame = /obj/structure/window_frame/chigusa



/obj/structure/window/framed/wood
	name = "window"
	icon_state = "wood_window0"
	basestate = "wood_window"
	window_frame = /obj/structure/window_frame/wood

/obj/structure/window/framed/wood/reinforced
	name = "reinforced window"
	desc = "A glass window with a special rod matrice inside a wall frame. It looks rather strong. Might take a few good hits to shatter it."
	max_integrity = 100
	reinf = TRUE
	icon_state = "wood_rwindow0"
	basestate = "wood_rwindow"
	window_frame = /obj/structure/window_frame/wood

//Prison windows


/obj/structure/window/framed/prison
	name = "window"
	icon_state = "wood_window0"
	basestate = "wood_window"
	window_frame = /obj/structure/window_frame/prison

/obj/structure/window/framed/prison/reinforced
	name = "reinforced window"
	desc = "A glass window with a special rod matrice inside a wall frame. It looks rather strong. Might take a few good hits to shatter it."
	max_integrity = 100
	reinf = TRUE
	icon_state = "prison_rwindow0"
	basestate = "prison_rwindow"
	window_frame = /obj/structure/window_frame/prison/reinforced

/obj/structure/window/framed/prison/reinforced/hull
	name = "hull window"
	desc = "A glass window with a special rod matrice inside a wall frame. This one has an automatic shutter system to prevent any atmospheric breach."
	max_integrity = 200
	//icon_state = "rwindow0_debug" //Uncomment to check hull in the map editor

/obj/structure/window/framed/prison/reinforced/hull/Initialize()
	. = ..()
	AddElement(/datum/element/windowshutter)

// dont even ask
/obj/structure/window/framed/prison/reinforced/hull/tyson
	icon_state = "col_window0"
	basestate = "col_window"
	window_frame = /obj/structure/window_frame/colony

// no really
/obj/structure/window/framed/prison/reinforced/hull/tyson/reinforced
	icon_state = "col_rwindow0"
	basestate = "col_rwindow"
	window_frame = /obj/structure/window_frame/colony/reinforced

/obj/structure/window/framed/prison/cell
	name = "cell window"
	icon_state = "prison_cellwindow0"
	basestate = "prison_cellwindow"
	desc = "A glass window with a special rod matrice inside a wall frame. Has no reachable screws to prevent enterprising prisoners from deconstructing it."
	//icon_state = "rwindow0_debug" //Uncomment to check hull in the map editor
	deconstructable = FALSE
	max_integrity = 300
