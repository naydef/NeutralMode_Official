#if defined _AF_included
 #endinput
#endif
#define _AF_included

#define SMTAG "\x03[AL]\x01"
#define DEBUGTAG "\x03[AL \x07FF0000DEBUG\x03]\x01"

//There flags are used in version 0.5.2 and above
#define ALFLAG_TAKEDMG				    (1<<1)		// The player can accept damage from any source
#define ALFLAG_NOSOUND				    (1<<2)		// Block voice
#define ALFLAG_INVISIBLE 	            (1<<3)		// The player is invisible.
#define ALFLAG_NOPROJCOLLIDE 	        (1<<4)		// Projectiles and buildings from the player will not collide and will be destroyed.
#define ALFLAG_NDEAD                   (1<<5)      // When the player is from the neutral team and is dead
#define ALFLAG_CHECKITEMS              (1<<6)      // Used for checking players for blacklisted items
#define ALFLAG_DONTSTUN                (1<<7)      // Don't stun the player from any attacks in the neutral team.
#define ALFLAG_JRTAMM                  (1<<8)      // Used if the player is jarated or etc.
#define ALFLAL_NORAGDOLL               (1<<9)      // On damage kill, remove the ragdoll
#define ALFLAG_CANAIRBLAST             (1<<10)     // The player can't airblast real players! Added in v0.9.0
#define ALFLAGS_GENERAL                 ALFLAG_NOSOUND|ALFLAG_INVISIBLE|ALFLAG_NOPROJCOLLIDE|ALFLAG_CHECKITEMS|ALFLAG_DONTSTUN|ALFLAL_NORAGDOLL|ALFLAG_JRTAMM

enum
{
	COLLISION_GROUP_NONE  = 0,
	COLLISION_GROUP_DEBRIS,			// Collides with nothing but world and static stuff
	COLLISION_GROUP_DEBRIS_TRIGGER, // Same as debris, but hits triggers
	COLLISION_GROUP_INTERACTIVE_DEBRIS,	// Collides with everything except other interactive debris or debris
	COLLISION_GROUP_INTERACTIVE,	// Collides with everything except interactive debris or debris
	COLLISION_GROUP_PLAYER,
	COLLISION_GROUP_BREAKABLE_GLASS,
	COLLISION_GROUP_VEHICLE,
	COLLISION_GROUP_PLAYER_MOVEMENT,  // For HL2, same as Collision_Group_Player, for
										// TF2, this filters out other players and CBaseObjects
	COLLISION_GROUP_NPC,			// Generic NPC group
	COLLISION_GROUP_IN_VEHICLE,		// for any entity inside a vehicle
	COLLISION_GROUP_WEAPON,			// for any weapons that need collision detection
	COLLISION_GROUP_VEHICLE_CLIP,	// vehicle clip brush to restrict vehicle movement
	COLLISION_GROUP_PROJECTILE,		// Projectiles!
	COLLISION_GROUP_DOOR_BLOCKER,	// Blocks entities not permitted to get near moving doors
	COLLISION_GROUP_PASSABLE_DOOR,	// Doors that the player shouldn't collide with
	COLLISION_GROUP_DISSOLVING,		// Things that are dissolving are in this group
	COLLISION_GROUP_PUSHAWAY,		// Nonsolid on client and server, pushaway in player code

	COLLISION_GROUP_NPC_ACTOR,		// Used so NPCs in scripts ignore the player.
	COLLISION_GROUP_NPC_SCRIPTED,	// USed for NPCs in scripts that should not collide with each other

	LAST_SHARED_COLLISION_GROUP
}


/**
 * Is AfterLife Mod loaded?
 *
 * @return	False if AL is disabled
 *			True if AL is enabled
 */
native bool:AL_IsEnabled();

/**
 * Is the player will spawn in the neutral team, after he die?
 *
 * @return	False if player won't respawn
 *			True otherwise
 */
native bool:AL_IsPlayerEnabled(client);

/**
 * Toggle player to spawn in the neutral team, after he die
 *
 * @return	-1 if the player is not valid
 *			
 */
native AL_TogglePlayerInNeutralTeam(client, bool:enable);

/**
 * Is the entity in the neutral team at the moment?
 * @Note: Works for every entity!
 * @param entity The entity to test
 * @return	true-If is in the neutral team
 *			false-No otherwise
 */
native bool:AL_IsInTheNeutralTeam(entity);

/**
 * Get the gravity of client, when is in the neutral team.
 *
 * @return	Player gravity. Default: 1.0
 *
 */
native Float:AL_GetPlayerGravity(client);

/**
 * Set the gravity of client, when is in the neutral team.
 *
 * @return	nothing
 *
 */
native AL_SetPlayerGravity(client, Float:gravity);

/**
 * If the blast will knockback the player, while he is in the neutral team.
 *
 * @return	bool for enabled or disabled
 *
 */
native bool:AL_GetBlastEnabled(client);

/**
 * Set the player to or not knockback, while he is in the neutral team
 *
 * @noreturn
 *
 */
native AL_SetBlast(client, enabled);

/**
 * Get the player flags.
 *
 * @return bitwise flags or -1 if the client is not valid
 *
 */
native AL_GetFlags(client);

/**
 * Set the player flags.
 *
 * @noreturn
 *
 */
native AL_SetFlags(client, flags);

/**
 * Is Debug enabled?
 *
 * @return true on enabled or false otherwise
 *
 */
 native bool:AL_IsDebugEnabled();
 
 /**
 * Get the current defined neutral team number.
 *
 * @return the team number
 *
 */
  native AL_GetNeutralTeamNum();
 
 /**
 * Called when a player is respawning in the neutral team.
 * Note: Here you can freely change flags of the player.
 *
 * @param client    The client who is respawning in the team
 * @param isAlready Is the player already in the neutral team?
 * @return			Plugin_Stop or Plugin_Handled to prevent changing the team and setting the collision groups of the player!
 */
forward Action:AL_OnNeutralRespawn(client, isAlready);

/**
 * Print and log debug information.
 *
 * @return 1-on success or 0 otherwise
 *
 */
stock Debug(const String:message[]="", any:...) //For debug.
{
	if(AL_IsDebugEnabled())
	{
		decl String:text[512];
		VFormat(text, sizeof(text), message, 2);
		PrintToChatAll("%s %s", DEBUGTAG, text);
		LogMessage("%s", text);
		PrintToServer(text);
		return 1;
	}
	return 0;
}

/*
public SharedPlugin:__pl_AL_SetNTVOptional=
{
	name="[TF2] AfterLife",
	file="afterlife.smx",
	#if defined REQUIRE_PLUGIN
		required=1,
	#else
		required=0,
	#endif
};
*/

#if !defined REQUIRE_PLUGIN
public __pl_AfterLife_SetNTVOptional()
{
    MarkNativeAsOptional("AL_IsEnabled");
	MarkNativeAsOptional("AL_IsPlayerEnabled");
	MarkNativeAsOptional("AL_TogglePlayerInNeutralTeam");
	MarkNativeAsOptional("AL_IsInTheNeutralTeam");
	MarkNativeAsOptional("AL_GetPlayerGravity");
	MarkNativeAsOptional("AL_SetPlayerGravity");
	MarkNativeAsOptional("AL_GetBlastEnabled");
	MarkNativeAsOptional("AL_SetBlast");
	MarkNativeAsOptional("AL_GetFlags");
	MarkNativeAsOptional("AL_SetFlags");
	MarkNativeAsOptional("AL_IsDebugEnabled");
	MarkNativeAsOptional("AL_GetNeutralTeamNum");
	MarkNativeAsOptional("Debug");
}
#endif