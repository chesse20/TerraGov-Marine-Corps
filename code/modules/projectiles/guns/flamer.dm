#define FLAMER_WATER 200

//FLAMETHROWER

/obj/item/weapon/gun/flamer
	name = "flamer"
	desc = "flame go froosh"
	flags_equip_slot = ITEM_SLOT_BACK
	w_class = WEIGHT_CLASS_BULKY
	force = 15
	fire_sound = "gun_flamethrower"
	dry_fire_sound = 'sound/weapons/guns/fire/flamethrower_empty.ogg'
	unload_sound = 'sound/weapons/guns/interact/flamethrower_unload.ogg'
	reload_sound = 'sound/weapons/guns/interact/flamethrower_reload.ogg'
	aim_slowdown = 1.75
	current_mag = /obj/item/ammo_magazine/flamer_tank
	var/lit = 0 //Turn the flamer on/off
	general_codex_key = "flame weapons"

	attachable_allowed = list( //give it some flexibility.
						/obj/item/attachable/flashlight,
						/obj/item/attachable/magnetic_harness,
						/obj/item/attachable/motiondetector,
						/obj/item/attachable/buildasentry,
						)
	flags_gun_features = GUN_UNUSUAL_DESIGN|GUN_AMMO_COUNTER|GUN_WIELDED_FIRING_ONLY|GUN_WIELDED_STABLE_FIRING_ONLY
	gun_skill_category = GUN_SKILL_HEAVY_WEAPONS
	attachable_offset = list("rail_x" = 12, "rail_y" = 23)
	fire_delay = 4

	placed_overlay_iconstate = "flamer"

/obj/item/weapon/gun/flamer/big_flamer
	name = "\improper M240A1 incinerator unit"
	desc = "The M240A1 has proven to be one of the most effective weapons at clearing out soft-targets. This is a weapon to be feared and respected as it is quite deadly."
	icon_state = "m240"
	item_state = "m240"

/obj/item/weapon/gun/flamer/mini_flamer
	name = "mini flamethrower"
	desc = "A weapon-mounted refillable flamethrower attachment.\nIt is designed for short bursts."
	icon = 'icons/Marine/marine-weapons.dmi'
	icon_state = "flamethrower"

	flags_gun_features = GUN_UNUSUAL_DESIGN|GUN_AMMO_COUNTER|GUN_WIELDED_FIRING_ONLY|GUN_WIELDED_STABLE_FIRING_ONLY|GUN_IS_ATTACHMENT|GUN_ATTACHMENT_FIRE_ONLY
	w_class = WEIGHT_CLASS_BULKY
	fire_delay = 2.5 SECONDS
	fire_sound = 'sound/weapons/guns/fire/flamethrower3.ogg'

	current_mag = /obj/item/ammo_magazine/flamer_tank/mini
	attachable_allowed = list()
	slot = ATTACHMENT_SLOT_UNDER
	attach_delay = 3 SECONDS
	detach_delay = 3 SECONDS
	pixel_shift_x = 15
	pixel_shift_y = 18

/obj/item/weapon/gun/flamer/mini_flamer/unremovable
	flags_attach_features = NONE


/obj/item/weapon/gun/flamer/mini_flamer/light_pilot(mob/user, mustlit)
	if (lit == mustlit)//You can't lit what is already lit
		return
	lit = mustlit
	playsound(user, lit ? 'sound/weapons/guns/interact/flamethrower_off.ogg' : 'sound/weapons/guns/interact/flamethrower_on.ogg', 25, 1)
	update_icon(user)

	return TRUE

/obj/item/weapon/gun/flamer/Initialize()
	. = ..()
	if (current_mag) //A flamer spawing with a mag will be lit up
		light_pilot(null,TRUE)

/obj/item/weapon/gun/flamer/examine_ammo_count(mob/user)
	if(current_mag)
		to_chat(user, "The fuel gauge shows the current tank is [round(current_mag.get_ammo_percent())]% full!")
	else
		to_chat(user, "[src] has no fuel tank!")

/obj/item/weapon/gun/flamer/able_to_fire(mob/user)
	. = ..()
	if(.)
		if(!current_mag || !current_mag.current_rounds)
			return

/**
 * Light the pilot light of a flamer
 *
 * mob/user if not null will play a sound and add an overlay
 * mustlit boolean, if true the pilot light will be lit
 */
/obj/item/weapon/gun/flamer/proc/light_pilot(mob/user,mustlit)
	if (lit == mustlit)//You can't lit what is already lit
		return
	lit = mustlit
	playsound(user, lit ? 'sound/weapons/guns/interact/flamethrower_off.ogg' : 'sound/weapons/guns/interact/flamethrower_on.ogg', 25, 1)

	var/image/I = image('icons/obj/items/gun.dmi', src, "+lit")
	I.pixel_x += 3

	if (lit)
		overlays += I
	else
		overlays -= I
		qdel(I)

	return TRUE


/obj/item/weapon/gun/flamer/Fire()
	if((!CHECK_BITFIELD(flags_item, IS_DEPLOYED) && !able_to_fire(gun_user)))
		return

	if(gun_on_cooldown(gun_user))
		return

	var/turf/curloc = get_turf(src) //In case the target or we are expired.
	var/turf/targloc = get_turf(target)
	if(!targloc || !curloc)
		return //Something has gone wrong...


	if(!current_mag)
		return

	if(current_mag.current_rounds <= 0)
		click_empty(gun_user)
	else
		INVOKE_ASYNC(src, .proc/unleash_flame, target, gun_user)

/obj/item/weapon/gun/flamer/reload(mob/user, obj/item/ammo_magazine/magazine)
	if(!magazine || !istype(magazine))
		to_chat(user, span_warning("That's not a magazine!"))
		return

	if(magazine.current_rounds <= 0)
		to_chat(user, span_warning("That [magazine.name] is empty!"))
		return

	if(!istype(src, magazine.gun_type) || istype(magazine, /obj/item/ammo_magazine/flamer_tank/backtank))
		to_chat(user, span_warning("That magazine doesn't fit in there!"))
		return

	if(istype(magazine, /obj/item/ammo_magazine/flamer_tank/large))
		to_chat(user, span_warning("That tank is too large for this model!"))
		return

	if(!isnull(current_mag) && current_mag.loc == src)
		to_chat(user, span_warning("It's still got something loaded!"))
		return


	if(user)
		if(magazine.reload_delay > 1)
			to_chat(user, span_notice("You begin reloading [src]. Hold still..."))
			if(!do_after(user,magazine.reload_delay, TRUE, src, BUSY_ICON_GENERIC))
				to_chat(user, span_warning("Your reload was interrupted!"))
				return
		replace_magazine(user, magazine)
		light_pilot(user,TRUE)
	else
		current_mag = magazine
		magazine.loc = src
		replace_ammo(,magazine)
		light_pilot(user,TRUE)

	update_icon()
	user.hud_used.update_ammo_hud(user, src)
	return TRUE

/obj/item/weapon/gun/flamer/unload(mob/user, reload_override = 0, drop_override = 0)
	if(!current_mag)
		return FALSE //no magazine to unload
	if(istype(current_mag, /obj/item/ammo_magazine/flamer_tank/backtank))
		detach_fueltank(user)
		return
	if(drop_override || !user) //If we want to drop it on the ground or there's no user.
		current_mag.forceMove(get_turf(src)) //Drop it on the ground.
	else
		user.put_in_hands(current_mag)

	playsound(user, unload_sound, 25, 1)
	light_pilot(user,FALSE)
	user.visible_message(span_notice("[user] unloads [current_mag] from [src]."),
	span_notice("You unload [current_mag] from [src]."))
	current_mag.update_icon()
	current_mag = null
	update_icon()
	return TRUE

/**Attach a back fuel tank to the flamer, wich will use it a standard magazine
 * mob/user if not null, will play sound and update hud
 * obj/item/ammo_magazine/flamer_tank/backtank/fueltank the back tank that is gonna be linked
 */
/obj/item/weapon/gun/flamer/proc/attach_fueltank(mob/user, obj/item/ammo_magazine/flamer_tank/backtank/fueltank)
	if (!istype(fueltank))
		to_chat(user, span_warning("That's not an attachable fuel tank!"))
		return

	if(fueltank.current_rounds <= 0)
		to_chat(user, span_warning("That [fueltank.name] is empty!"))
		return

	to_chat(user, span_notice("You begin linking [src] with the [fueltank.name]. Hold still..."))
	if(!do_after(user,fueltank.reload_delay, TRUE, src, BUSY_ICON_GENERIC))
		to_chat(user, span_warning("Your action was interrupted!"))
		return
	if (current_mag)
		if(istype(current_mag,/obj/item/ammo_magazine/flamer_tank/backtank))
			detach_fueltank(user,FALSE)
		else
			user.put_in_hands(current_mag)//We remove the fuel tank if there is one
	current_mag = fueltank
	fueltank.attached_flamer = src
	replace_ammo(user, fueltank)
	light_pilot(user,TRUE)
	playsound(user, reload_sound, 25, 1, 5)
	update_icon(user)
	user?.hud_used.update_ammo_hud(user, src)


/**Proced when unlinking the back fuel tank, making the flamer unlit and unable to fire
 * mob/user if not null, will allow to play sound and update icons / hud
 * voluntary if TRUE, will span a notice describing the action
 */
/obj/item/weapon/gun/flamer/proc/detach_fueltank(mob/user, voluntary = TRUE)
	var/obj/item/ammo_magazine/flamer_tank/backtank/fueltank = current_mag
	current_mag = null
	fueltank?.attached_flamer = null
	if (voluntary)
		to_chat(user, span_notice("You detach the fuel tank"))
	playsound(user, unload_sound, 25, 1)
	light_pilot(user,FALSE)
	update_icon(user)
	user?.hud_used.update_ammo_hud(user, src)

/obj/item/weapon/gun/flamer/removed_from_inventory(mob/user)
	. = ..()
	if (istype(current_mag,/obj/item/ammo_magazine/flamer_tank/backtank)) //Dropping the flamer unlink it from the tank
		var/obj/item/ammo_magazine/flamer_tank/backtank/backfueltank = current_mag;
		backfueltank.attached_flamer=null
		current_mag = null
		light_pilot(null,FALSE)
	update_icon()

/obj/item/weapon/gun/flamer/proc/unleash_flame(atom/target, mob/living/user)
	set waitfor = 0

	last_fired = world.time

	if(!istype(ammo, /datum/ammo/flamethrower))
		CRASH("flamerthrower loaded with non-flamerthrower ammo")

	var/datum/ammo/flamethrower/loaded_ammo = ammo

	var/burnlevel = loaded_ammo.burnlevel
	var/burntime = loaded_ammo.burntime
	var/fire_color = loaded_ammo.fire_color
	fire_delay = loaded_ammo.fire_delay

	var/list/turf/turfs = getline(get_turf(src), target)
	playsound(loc, fire_sound, 50, 1)
	var/distance = 1
	var/turf/prev_T

	for(var/F in turfs)
		var/turf/T = F

		if(T == get_turf(src))
			prev_T = T
			continue
		if((T.density && !istype(T, /turf/closed/wall/resin)) || isspaceturf(T))
			break
		if(!CHECK_BITFIELD(flags_item, IS_DEPLOYED) && loc != user && !master_gun)
			break
		if(!current_mag?.current_rounds)
			break
		var/range = istype(src, /obj/item/weapon/gun/flamer/mini_flamer) ? 4 : loaded_ammo.max_range //Temporary hardcode range of miniflamer.
		if(distance > range)
			break

		var/blocked = FALSE
		for(var/obj/O in T)
			if(O.density && !O.throwpass && !(O.flags_atom & ON_BORDER) && !istype(O, /obj/structure/mineral_door/resin))
				blocked = TRUE
				break

		var/turf/TF
		if(!prev_T.Adjacent(T) && (T.x != prev_T.x || T.y != prev_T.y)) //diagonally blocked, it will seek for a cardinal turf by the former target.
			blocked = TRUE
			var/turf/Ty = locate(prev_T.x, T.y, prev_T.z)
			var/turf/Tx = locate(T.x, prev_T.y, prev_T.z)
			for(var/turf/TB in shuffle(list(Ty, Tx)))
				if(prev_T.Adjacent(TB) && ((!TB.density && !isspaceturf(T)) || istype(T, /turf/closed/wall/resin)))
					TF = TB
					break
			if(!TF)
				break
		else
			TF = T

		current_mag.current_rounds--
		if (current_mag.current_rounds<=0)
			light_pilot(user,FALSE)
			break
		flame_turf(TF,user, burntime, burnlevel, fire_color)
		if(blocked)
			break
		distance++
		prev_T = T
		sleep(1)
	if(!user)
		return
	user.hud_used.update_ammo_hud(user, src)

/obj/item/weapon/gun/flamer/proc/flame_turf(turf/T, mob/living/user, heat, burn, f_color = "red")
	if(!istype(T))
		return

	T.ignite(heat, burn, f_color)

	// Melt a single layer of snow
	if(istype(T, /turf/open/floor/plating/ground/snow))
		var/turf/open/floor/plating/ground/snow/S = T

		if (S.slayer > 0)
			S.slayer -= 1
			S.update_icon(1, 0)

	for(var/obj/structure/jungle/vines/V in T)
		qdel(V)

	var/fire_mod
	for(var/mob/living/M in T) //Deal bonus damage if someone's caught directly in initial stream
		if(M.stat == DEAD)
			continue

		fire_mod = 1

		if(isxeno(M))
			var/mob/living/carbon/xenomorph/X = M
			if(X.xeno_caste.caste_flags & CASTE_FIRE_IMMUNE)
				continue
			fire_mod = X.get_fire_resist()
		else if(ishuman(M))
			var/mob/living/carbon/human/H = M //fixed :s

			if(user)
				if(!user.mind?.bypass_ff && !H.mind?.bypass_ff && user.faction == H.faction)
					log_combat(user, H, "flamed", src)
					user.ff_check(30, H) // avg between 20/40 dmg
					log_ffattack("[key_name(user)] flamed [key_name(H)] with \a [name] in [AREACOORD(T)].")
					msg_admin_ff("[ADMIN_TPMONTY(user)] flamed [ADMIN_TPMONTY(H)] with \a [name] in [ADMIN_VERBOSEJMP(T)].")
				else
					log_combat(user, H, "flamed", src)

			if(H.hard_armor.getRating("fire") >= 100)
				continue

		M.take_overall_damage_armored(rand(burn,(burn*2))* fire_mod, BURN, "fire", updating_health = TRUE) // Make it so its the amount of heat or twice it for the initial blast.
		M.adjust_fire_stacks(rand(5,burn*2))
		M.IgniteMob()

		to_chat(M, "[isxeno(M)?"<span class='xenodanger'>":"<span class='highdanger'>"]Augh! You are roasted by the flames!")

/obj/item/weapon/gun/flamer/get_ammo_type()
	if(!ammo)
		return list("unknown", "unknown")
	else
		return list(ammo.hud_state, ammo.hud_state_empty)

/obj/item/weapon/gun/flamer/get_ammo_count()
	if(!current_mag)
		return 0
	else
		return current_mag.current_rounds


/obj/item/weapon/gun/flamer/big_flamer/marinestandard
	name = "\improper TL-84 flamethrower"
	desc = "The TL-84 flamethrower is the current standard issue flamethrower of the TGMC, and is used for area control and urban combat. Use unique action to use hydro cannon"
	current_mag = /obj/item/ammo_magazine/flamer_tank/large
	icon_state = "tl84"
	item_state = "tl84"
	flags_gun_features = GUN_UNUSUAL_DESIGN|GUN_WIELDED_FIRING_ONLY|GUN_AMMO_COUNTER|GUN_WIELDED_STABLE_FIRING_ONLY
	attachable_offset = list("rail_x" = 10, "rail_y" = 23, "stock_x" = 16, "stock_y" = 13)
	starting_attachment_types = list(
		/obj/item/attachable/stock/t84stock,
		/obj/item/attachable/hydro_cannon,
	)
	var/last_use
	///If we are using the hydro cannon when clicking
	var/hydro_active = FALSE
	///How much water the hydro cannon has
	var/water_count = 0

/obj/item/weapon/gun/flamer/big_flamer/marinestandard/Initialize()
	. = ..()
	reagents = new /datum/reagents(FLAMER_WATER)
	reagents.my_atom = src
	reagents.add_reagent(/datum/reagent/water, reagents.maximum_volume)
	water_count = reagents.maximum_volume

/obj/item/weapon/gun/flamer/big_flamer/marinestandard/reload(mob/user, obj/item/ammo_magazine/magazine)
	if(!magazine || !istype(magazine))
		to_chat(user, span_warning("That's not a magazine!"))
		return

	if(magazine.current_rounds <= 0)
		to_chat(user, span_warning("That [magazine.name] is empty!"))
		return

	if(!istype(src, magazine.gun_type) || istype(magazine, /obj/item/ammo_magazine/flamer_tank/backtank))
		to_chat(user, span_warning("That magazine doesn't fit in there!"))
		return

	if(!isnull(current_mag) && current_mag.loc == src)
		to_chat(user, span_warning("It's still got something loaded!"))
		return

	if(user)
		if(magazine.reload_delay > 1)
			to_chat(user, span_notice("You begin reloading [src]. Hold still..."))
			if(!do_after(user,magazine.reload_delay, TRUE, src, BUSY_ICON_GENERIC))
				to_chat(user, span_warning("Your reload was interrupted!"))
				return
		replace_magazine(user, magazine)
		light_pilot(user,TRUE)
	else
		current_mag = magazine
		magazine.loc = src
		replace_ammo(,magazine)
		light_pilot(user,TRUE)

	update_icon()
	return TRUE

/obj/item/weapon/gun/flamer/big_flamer/marinestandard/wield(mob/user)//Auto linking
	if (!current_mag)
		var/mob/living/carbon/human/human_user = user
		var/obj/item/ammo_magazine/flamer_tank/backtank/back_tank = human_user.get_type_in_slots(/obj/item/ammo_magazine/flamer_tank/backtank)
		if (back_tank)
			attach_fueltank(user, back_tank)
	return ..()

/obj/item/weapon/gun/flamer/big_flamer/marinestandard/able_to_fire(mob/user)
	. = ..()
	if(.)
		if(!current_mag || !current_mag.current_rounds)
			return

/obj/item/weapon/gun/flamer/big_flamer/marinestandard/examine(mob/user)
	. = ..()
	to_chat(user, span_notice("Its hydro cannon contains [reagents.get_reagent_amount(/datum/reagent/water)]/[reagents.maximum_volume] units of water!"))

/obj/item/weapon/gun/flamer/big_flamer/marinestandard/cock(mob/user)
	return TRUE

/obj/item/weapon/gun/flamer/big_flamer/marinestandard/unique_action(mob/user)
	. = ..()
	if(!.)
		return
	var/obj/item/attachable/hydro_cannon/hydro = LAZYACCESS(attachments_by_slot, ATTACHMENT_SLOT_UNDER)
	if(!istype(hydro))
		return FALSE
	playsound(user, hydro.activation_sound, 15, 1)
	if (hydro.activate(user))
		hydro_active = TRUE
		light_pilot(user, FALSE)
	else
		hydro_active = FALSE
		if (current_mag?.current_rounds > 0)
			light_pilot(user, TRUE)
	user.hud_used.update_ammo_hud(user, src)
	SEND_SIGNAL(src, COMSIG_ITEM_HYDRO_CANNON_TOGGLED)
	return TRUE

/obj/item/weapon/gun/flamer/big_flamer/marinestandard/attach_fueltank(mob/user, obj/item/ammo_magazine/flamer_tank/backtank/fueltank)
	if (!istype(fueltank))
		to_chat(user, span_warning("That's not an attachable fuel tank!"))
		return

	if(fueltank.current_rounds <= 0)
		to_chat(user, span_warning("That [fueltank.name] is empty!"))
		return

	to_chat(user, span_notice("You begin linking [src] with the [fueltank.name]. Hold still..."))
	if(!do_after(user,fueltank.reload_delay, TRUE, src, BUSY_ICON_GENERIC))
		to_chat(user, span_warning("Your action was interrupted!"))
		return
	if (current_mag)
		if(istype(current_mag,/obj/item/ammo_magazine/flamer_tank/backtank))
			detach_fueltank(user,FALSE)
		else
			user.put_in_hands(current_mag)//We remove the fuel tank if there is one
	current_mag = fueltank
	fueltank.attached_flamer = src
	replace_ammo(user, fueltank)
	if (!hydro_active)
		light_pilot(user,TRUE)
	playsound(user, reload_sound, 25, 1, 5)
	update_icon(user)
	user.hud_used.update_ammo_hud(user, src)

/obj/item/weapon/gun/flamer/big_flamer/marinestandard/Fire()
	if(!target)
		return
	if(hydro_active && (world.time > last_use + 10))
		INVOKE_ASYNC(src, .proc/extinguish, target, gun_user) //Fire it.
		water_count -= 7//reagents is not updated in this proc, we need water_count for a updated HUD
		last_fired = world.time
		last_use = world.time
		gun_user.hud_used.update_ammo_hud(gun_user, src)
		return
	if(gun_user?.skills.getRating("firearms") < 0)
		switch(windup_checked)
			if(WEAPON_WINDUP_NOT_CHECKED)
				INVOKE_ASYNC(src, .proc/do_windup)
				return
			if(WEAPON_WINDUP_CHECKING)
				return
	return ..()

///Flamer windup called before firing
/obj/item/weapon/gun/flamer/big_flamer/marinestandard/proc/do_windup()
	windup_checked = WEAPON_WINDUP_CHECKING
	if(!do_after(gun_user, 1 SECONDS, TRUE, src))
		windup_checked = WEAPON_WINDUP_NOT_CHECKED
		return
	windup_checked = WEAPON_WINDUP_CHECKED
	Fire()

/obj/item/weapon/gun/flamer/big_flamer/marinestandard/afterattack(atom/target, mob/user)
	. = ..()
	if(istype(target, /obj/structure/reagent_dispensers/watertank) && get_dist(user,target) <= 1)
		var/obj/o = target
		o.reagents.trans_to(src, reagents.maximum_volume)
		water_count = reagents.maximum_volume
		to_chat(user, span_notice("\The [src]'s hydro cannon is refilled with water."))
		playsound(src.loc, 'sound/effects/refill.ogg', 25, 1, 3)
		user.hud_used.update_ammo_hud(user, src)
		return

/obj/item/weapon/gun/flamer/big_flamer/marinestandard/get_ammo_count()
	if (hydro_active)
		return max(water_count,0)
	return ..()

/obj/item/weapon/gun/flamer/big_flamer/marinestandard/get_ammo_type()
	if (hydro_active)
		return list("water","water_empty")
	return ..()

/turf/proc/ignite(fire_lvl, burn_lvl, f_color, fire_stacks = 0, fire_damage = 0)
	//extinguish any flame present
	var/obj/flamer_fire/F = locate(/obj/flamer_fire) in src
	if(F)
		qdel(F)

	new /obj/flamer_fire(src, fire_lvl, burn_lvl, f_color, fire_stacks, fire_damage)

//////////////////////////////////////////////////////////////////////////////////////////////////
//Time to redo part of abby's code.
//Create a flame sprite object. Doesn't work like regular fire, ie. does not affect atmos or heat
/obj/flamer_fire
	name = "fire"
	desc = "Ouch!"
	anchored = TRUE
	mouse_opacity = 0
	icon = 'icons/effects/fire.dmi'
	icon_state = "red_2"
	layer = BELOW_OBJ_LAYER
	light_system = MOVABLE_LIGHT
	light_mask_type = /atom/movable/lighting_mask/flicker
	light_on = TRUE
	light_range = 3
	light_power = 3
	light_color = LIGHT_COLOR_LAVA
	var/firelevel = 12 //Tracks how much "fire" there is. Basically the timer of how long the fire burns
	var/burnlevel = 10 //Tracks how HOT the fire is. This is basically the heat level of the fire and determines the temperature.
	var/flame_color = "red"

/obj/flamer_fire/Initialize(mapload, fire_lvl, burn_lvl, f_color, fire_stacks = 0, fire_damage = 0)
	. = ..()

	if(f_color)
		flame_color = f_color

	icon_state = "[flame_color]_2"
	if(fire_lvl)
		firelevel = fire_lvl
	if(burn_lvl)
		burnlevel = burn_lvl
	if(fire_stacks || fire_damage)
		for(var/mob/living/C in get_turf(src))
			C.flamer_fire_act(fire_stacks)

			C.take_overall_damage_armored(fire_damage, BURN, "fire", updating_health = TRUE)
			if(C.IgniteMob())
				C.visible_message(span_danger("[C] bursts into flames!"), isxeno(C) ? span_xenodanger("You burst into flames!") : span_highdanger("You burst into flames!"))

	START_PROCESSING(SSobj, src)

/obj/flamer_fire/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/flamer_fire/Crossed(mob/living/M) //Only way to get it to reliable do it when you walk into it.
	. = ..()
	if(istype(M))
		M.flamer_fire_crossed(burnlevel, firelevel)

// override this proc to give different walking-over-fire effects
/mob/living/proc/flamer_fire_crossed(burnlevel, firelevel, fire_mod = 1)
	if(status_flags & (INCORPOREAL|GODMODE))
		return FALSE
	if(!CHECK_BITFIELD(flags_pass, PASSFIRE)) //Pass fire allow to cross fire without being ignited
		adjust_fire_stacks(burnlevel) //Make it possible to light them on fire later.
		IgniteMob()
	take_overall_damage_armored(round(burnlevel*0.5)* fire_mod, BURN, "fire", updating_health = TRUE)
	to_chat(src, span_danger("You are burned!"))

/obj/flamer_fire/effect_smoke(obj/effect/particle_effect/smoke/S)
	. = ..()
	if(!CHECK_BITFIELD(S.smoke_traits, SMOKE_EXTINGUISH)) //Fire suppressing smoke
		return

	firelevel -= 20 //Water level extinguish
	updateicon()
	if(firelevel < 1) //Extinguish if our firelevel is less than 1
		qdel(src)

/mob/living/carbon/human/flamer_fire_crossed(burnlevel, firelevel, fire_mod = 1)
	if(hard_armor.getRating("fire") >= 100)
		take_overall_damage_armored(round(burnlevel * 0.2) * fire_mod, BURN, "fire", updating_health = TRUE)
		return
	. = ..()
	if(isxeno(pulledby))
		var/mob/living/carbon/xenomorph/X = pulledby
		X.flamer_fire_crossed(burnlevel, firelevel)

/mob/living/carbon/xenomorph/flamer_fire_crossed(burnlevel, firelevel, fire_mod = 1)
	if(xeno_caste.caste_flags & CASTE_FIRE_IMMUNE)
		return
	fire_mod = get_fire_resist()
	return ..()


/obj/flamer_fire/proc/updateicon()
	var/light_color = "LIGHT_COLOR_LAVA"
	var/light_intensity = 3
	switch(flame_color)
		if("red")
			light_color = LIGHT_COLOR_LAVA
		if("blue")
			light_color = LIGHT_COLOR_CYAN
		if("green")
			light_color = LIGHT_COLOR_GREEN
	switch(firelevel)
		if(1 to 9)
			icon_state = "[flame_color]_1"
			light_intensity = 2
		if(10 to 25)
			icon_state = "[flame_color]_2"
			light_intensity = 4
		if(25 to INFINITY) //Change the icons and luminosity based on the fire's intensity
			icon_state = "[flame_color]_3"
			light_intensity = 6
	set_light_range_power_color(light_intensity, light_power, light_color)

/obj/flamer_fire/process()
	var/turf/T = loc
	firelevel = max(0, firelevel)
	if(!istype(T)) //Is it a valid turf?
		qdel(src)
		return

	updateicon()

	if(!firelevel)
		qdel(src)
		return

	T.flamer_fire_act(burnlevel, firelevel)

	var/j = 0
	for(var/i in T)
		if(++j >= 11)
			break
		var/atom/A = i
		if(QDELETED(A)) //The destruction by fire of one atom may destroy others in the same turf.
			continue
		A.flamer_fire_act(burnlevel, firelevel)

	firelevel -= 2 //reduce the intensity by 2 per tick


// override this proc to give different idling-on-fire effects
/mob/living/flamer_fire_act(burnlevel, firelevel)
	if(!burnlevel)
		return
	if(status_flags & (INCORPOREAL|GODMODE)) //Ignore incorporeal/invul targets
		return
	if(hard_armor.getRating("fire") >= 100)
		to_chat(src, span_warning("Your suit protects you from most of the flames."))
		adjustFireLoss(rand(0, burnlevel * 0.25)) //Does small burn damage to a person wearing one of the suits.
		return
	adjust_fire_stacks(burnlevel) //If i stand in the fire i deserve all of this. Also Napalm stacks quickly.
	IgniteMob()
	adjustFireLoss(rand(10 , burnlevel)) //Including the fire should be way stronger.
	to_chat(src, span_warning("You are burned!"))


/mob/living/carbon/xenomorph/flamer_fire_act(burnlevel, firelevel)
	if(xeno_caste.caste_flags & CASTE_FIRE_IMMUNE)
		return
	burnlevel *= get_fire_resist()
	. = ..()
	updatehealth()

/mob/living/carbon/xenomorph/queen/flamer_fire_act(burnlevel, firelevel)
	to_chat(src, span_xenowarning("Our extra-thick exoskeleton protects us from the flames."))

/mob/living/carbon/xenomorph/ravager/flamer_fire_act(burnlevel, firelevel)
	if(stat)
		return
	plasma_stored = xeno_caste.plasma_max
	var/datum/action/xeno_action/charge = actions_by_path[/datum/action/xeno_action/activable/charge]
	if(charge)
		charge.clear_cooldown() //Reset charge cooldown
	to_chat(src, span_xenodanger("The heat of the fire roars in our veins! KILL! CHARGE! DESTROY!"))
	if(prob(70))
		emote("roar")

#undef FLAMER_WATER
