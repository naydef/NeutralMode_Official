/*
			Welcome to the source code of the "[TF2] AfterLife" plugin.
			Version: 0.9.1 Final | Private semi-gamemode plugin. | Stable
			Inspired from Ghost Mode Redux by ReFlexPoison, but without 
			anything copied from his code.			
			Minimum Requirements: Sourcemod >=1.6.0 , SDKHooks 2.1, TFWeapons include file
			Known bugs:
			Screwing team counts - Fixed
			Projectile explosion from team 2 at team 1 - Fixed
			Fix server crash when player disconnects - Fixed
			Make bots from team 1 ignore team 2 and vice versa - Impossible for now
			Make sentries from both teams ignore players from both teams - Fixed
			Fix client crash due to changing teams - Fixed
			Fix random crashes due to interfering plugins - Stopped for now
			Fix double event issues - Fixed
			Fix the Neutral team cannot hurt themselves - Subplugin
			Improvements:
			Make it for regular players on the server - Ready
			On death, respawn the player in team 2 - Ready
			Improve the code - Ready
			New name - Ready
			Convert the syntax to Sourcemod 1.7=> - Far future
			Block sounds from team 2 to team 1 - Implemented (Need more testing)
			Implement block death messages - Ready
			Implement API (Natives) - Ready
			Create SubPlugins - Implementing
			Translation Support - Implementing
*/
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <clientprefs>
#include <tfweapons2> //My own give weapon include
#include <afterlife_plugin>

#define PLUGIN_VERSION "0.9.1 Final"
#define PLUGIN_AUTHOR "Naydef"

//Defines
#define VERYGRAVITY 10.0
#define MAXENTITIES 2049
#define NTEAM 0            // The Neutral team number.
#define WSLOTS 6           // Max weapon slots

#define CHOICE1 "#choice1"
#define CHOICE2 "#choice2"
#define CHOICE3 "#choice3"
#define CHOICE4 "#choice4"
#define CHOICE5 "#choice5"

//Creating variables and etc
new ALFlags[MAXPLAYERS+1];                           // Player Flags. Make it like Freak Fortress 2. 

new bool:InTeamN[MAXENTITIES];                       // Registers entities which are in the Neutral team at the moment.
new LastTeam[MAXPLAYERS+1];                           // Last team of the player

new Handle:cvarEnabled;               // Plugin Enabled by user
new Handle:cvarDebug;                 // Debug cvar
new Handle:cvarSpectatorCanSee;
new Handle:cvarAnnounceTime;         // Announce time delay
new Handle:cvarRespawnDelay;         // Respawn delay
new Handle:cvarPlayerTeleport;       // Allow neutral team to use teleporters of the playing team.
new Handle:cvarNoTriggerHurt;        // No trigger_hurt for the neutral team!
new Handle:cvarOnlyArena;
new Handle:cvarPunishment;
new Handle:cvarPluginSilence;
new Handle:cvarSolidTP;
new Handle:cvarBlockBlood;
new Handle:DGravity;                  // Set the gravity of the player.
new Handle:RTimer[MAXPLAYERS];        // Fix respawn timer bypass exploit

new bool:UserPluginEnabled;          // Control variable for cvar
new bool:Enabled;                     // Variable for enabled plugin
new bool:DebugEnabled;               // Debug message enabler cvar
new bool:SpectatorCanSee;
new bool:AllowNeutralTP;
new bool:NoTriggerHurt;
new bool:IsArenaFound;
new bool:OnlyArena;
new bool:PluginSilence;
new bool:SolidTP;
new bool:BlockBlood;
new bool:PlayerEnabled[MAXPLAYERS+1];
new bool:TakeBlast[MAXPLAYERS+1];                    // Can they take blast force.
new bool:PreferencesMenu[MAXPLAYERS+1];             // Is panel to back (I think this has to be removed somehow).
new Float:CGravity[MAXPLAYERS+1];                    // Current gravity.
new Float:AnnounceTime;
new RespawnTime;                                     //This doesn't need to be a float number
new AirBlastPunish;

//Cookie handles
new Handle:g_hCookieGravity;
new Handle:g_hCookieEnabled;
new Handle:g_hCookieBlastSelf;

//Global forwards
new Handle:g_hNRespawn;

public Plugin:myinfo =
{
	name = "[TF2] AfterLife", 
	author = PLUGIN_AUTHOR,
	description = "Welcome to the Neutral team.",
	version = PLUGIN_VERSION,
	url = "https://github.com/naydef/Afterlife-plugin"
};

public OnPluginStart()
{
	LogMessage("AfterLife plugin loading!!!");
	LoadTranslations("common.phrases");
	LoadTranslations("afterlife.phrases");
	RegConsoleCmd("sm_neutral", Command_ScreenMenu, "Toggle the options menu to yourself.");
	RegAdminCmd("al_status", Command_PlayerStatus, ADMFLAG_GENERIC, "Check the players"); //I need to know everything.
	RegAdminCmd("al_toggle", Command_TogglePlayer, ADMFLAG_CHEATS, "Toggle respawning in the neutral team to someone");
	CreateConVar("afterlife_version", PLUGIN_VERSION, "AfterLife version cvar", FCVAR_NOTIFY|FCVAR_SPONLY|FCVAR_DONTRECORD);
	cvarEnabled=CreateConVar("al_enabled", "1", "1- The plugin is enabled 0- The plugin is disabled: Are you sure?", _, true, 0.0, true , 1.0);
	cvarSpectatorCanSee=CreateConVar("al_spcanseeneutral", "1", "Set if the spectators can see players from the neutral team.", _, true, 0.0, true , 1.0);
	cvarDebug=CreateConVar("al_debug", "0", "Enable debug messages.", _, true, 0.0, true , 1.0);
	cvarAnnounceTime=CreateConVar("al_announce_time", "145", "Amount of seconds to wait until AL info is displayed again | 0-disable it", _, true, 0.0);
	cvarRespawnDelay=CreateConVar("al_respawn_time", "7", "Seconds before the player respawns. Minimum delay: 1 second", _, true, 1.0);
	cvarPlayerTeleport=CreateConVar("al_neutral_tp", "1", "1- Allow the neutral team to use playing team teleporters | 0-Otherwise ", _, true, 0.0, true, 1.0);
	cvarNoTriggerHurt=CreateConVar("al_notrhurt", "1", "1- No damage from the map except fall damage | 0-Otherwise!", _, true, 0.0, true, 1.0);
	cvarOnlyArena=CreateConVar("al_only_arena", "1", "1- The plugin will work only on arena maps (which have tf_arena_logic entity) | 0-Otherwise!", _, true, 0.0, true, 1.0);
	cvarPunishment=CreateConVar("al_airblast_punishment", "1", "Airblast punishment 0- Nothing 1-Warning message 2-Kick the player");
	cvarPluginSilence=CreateConVar("al_plugin_silence", "1", "1-Other plugins will not detects some common player events like respawning or gettting new set of weapons. Recommended for servers, which their bosses have long lastman music (Freak Fortress 2) | 0-Otherwise", _, true, 0.0, true, 1.0);
	cvarSolidTP=CreateConVar("al_solidtp", "1", "1-Teleporters will be solid, as in the game | 0-Teleporters will be made as the sentries and the dispensers", _, true, 0.0, true, 1.0);
	cvarBlockBlood=CreateConVar("al_blockblood", "1", "1-No blood will be emitted by the neutral team | 0-Otherwise", _, true, 0.0, true, 1.0);
	HookConVarChange(cvarEnabled, CvarChange);
	HookConVarChange(cvarSpectatorCanSee, CvarChange);
	HookConVarChange(cvarDebug, CvarChange);
	HookConVarChange(cvarAnnounceTime, CvarChange);
	HookConVarChange(cvarRespawnDelay, CvarChange);
	HookConVarChange(cvarPlayerTeleport, CvarChange);
	HookConVarChange(cvarNoTriggerHurt, CvarChange);
	HookConVarChange(cvarOnlyArena, CvarChange);
	HookConVarChange(cvarPunishment, CvarChange);
	HookConVarChange(cvarPluginSilence, CvarChange);
	HookConVarChange(cvarSolidTP, CvarChange);
	HookConVarChange(cvarBlockBlood, CvarChange);

	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
	HookEvent("teamplay_round_start", Event_OnRoundStart, EventHookMode_Post);
	HookEvent("post_inventory_application", Event_OnPostInvertory, EventHookMode_Pre);
	HookEvent("player_sapped_object", Event_ObjectSapped, EventHookMode_Pre);
	HookEvent("object_deflected", Event_OnObjectDeflected, EventHookMode_Pre);
	
	HookUserMessage(GetUserMessageId("PlayerJarated"), Hook_OnJarate); //OK, this is from Freak Fortress 2 1.10.6
	
	AddCommandListener(CallBack_Jointeam, "jointeam");
	AutoExecConfig(true, "AfterLifePlugin");
	AddNormalSoundHook(Hook_EntitySound);
	AddTempEntHook("TFBlood", Hook_TempEntHook);
	
	g_hCookieGravity = RegClientCookie("afterlife_gravity_cookie", "AGC", CookieAccess_Public);
	g_hCookieEnabled = RegClientCookie("afterlife_enabled_cookie", "AEC", CookieAccess_Public);
	g_hCookieBlastSelf = RegClientCookie("afterlife_blast_cookie", "ABC", CookieAccess_Public);
	
	for(new i=1; i<=MaxClients; i++) //Full compatibility in case of late load.
	{
		if(IsValidClient(i))
		{
			if(!InTeamN[i] && Arena_GetClientTeam(i)!=NTEAM)
			{
				LastTeam[i]=Arena_GetClientTeam(i);
			}
			if(AreClientCookiesCached(i))
			{
				OnClientCookiesCached(i);
			}
			ScreenMenuChoice(i, false);
			OnClientPutInServer(i);
		}
	}
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	if(!IsTF2())
	{
		strcopy(error, err_max, "The plugin Afterlife is only for Team Fortress 2. Remove the plugin please!");
		return APLRes_Failure;
	}
	CreateNative("AL_IsEnabled", Native_IsEnabled);
	CreateNative("AL_IsPlayerEnabled", Native_IsPlayerEnabled);
	CreateNative("AL_TogglePlayerInNeutralTeam", Native_SetPlayerInNeutral);
	CreateNative("AL_IsInTheNeutralTeam", Native_IsInNeutralTeam);
	CreateNative("AL_GetPlayerGravity", Native_GetGravityNeutral);
	CreateNative("AL_SetPlayerGravity", Native_SetGravityNeutral);
	CreateNative("AL_GetBlastEnabled", Native_IsBlastEnabled);
	CreateNative("AL_SetBlast", Native_SetBlast);
	CreateNative("AL_GetFlags", Native_GetFlags);
	CreateNative("AL_SetFlags", Native_SetFlags);
	CreateNative("AL_IsDebugEnabled", Native_IsDebugEnabled);
	CreateNative("AL_GetNeutralTeamNum", Native_GetNeutralTeamNum);
	
	RegPluginLibrary("afterlife_plugin"); //Needed so other plugins can interact safely
	
	//Forwards
	g_hNRespawn=CreateGlobalForward("AL_OnNeutralRespawn", ET_Event, Param_Cell, Param_Cell, Param_CellByRef);
	return APLRes_Success;
}

public OnConfigsExecuted()
{
	SyncConVarValuesLoadPlugins();
	EnableAL();
}

public SyncConVarValuesLoadPlugins()
{
	//Cache the cvars.
	UserPluginEnabled=bool:GetConVarBool(cvarEnabled);
	SpectatorCanSee=bool:GetConVarBool(cvarSpectatorCanSee);
	DebugEnabled=bool:GetConVarBool(cvarDebug);
	AnnounceTime=Float:GetConVarFloat(cvarAnnounceTime);
	RespawnTime=GetConVarInt(cvarRespawnDelay);
	AllowNeutralTP=bool:GetConVarBool(cvarPlayerTeleport);
	NoTriggerHurt=bool:GetConVarBool(cvarNoTriggerHurt);
	OnlyArena=bool:GetConVarBool(cvarOnlyArena);
	AirBlastPunish=GetConVarInt(cvarPunishment);
	PluginSilence=bool:GetConVarBool(cvarPluginSilence);
	SolidTP=bool:GetConVarBool(cvarSolidTP);
	BlockBlood=bool:GetConVarBool(cvarBlockBlood);
	
	//Load plugins. This is also from Freak Fortress 2
	decl String:path[PLATFORM_MAX_PATH];
	decl FileType:filetype;
	decl String:filename[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "plugins/afterlife_pl");
	new Handle:directory=OpenDirectory(path);
	directory=OpenDirectory(path);
	while(ReadDirEntry(directory, filename, sizeof(filename), filetype))
	{
		if(filetype==FileType_File && StrContains(filename, ".smx", false)!=-1)
		{
			ServerCommand("sm plugins load afterlife_pl/%s", filename);
		}
	}
}

public OnPluginEnd()
{
	DisableAL();
}

public OnMapStart()
{
	DGravity=FindConVar("sv_gravity");
}

public CvarChange(Handle:cvar, const String:oldVal[], const String:newVal[]) //To-do: Use newVal value to set the variables
{
	if(cvar==cvarEnabled)
	{
		UserPluginEnabled=bool:GetConVarBool(cvar);
		switch(UserPluginEnabled)
		{
		case true:
			{
				EnableAL();
			}
		case false:
			{
				DisableAL();
			}
		}
	}
	else if(cvar==cvarSpectatorCanSee)
	{
		SpectatorCanSee=bool:GetConVarBool(cvar);
	}
	else if(cvar==cvarDebug)
	{
		DebugEnabled=bool:GetConVarBool(cvar);
	}
	else if(cvar==cvarAnnounceTime)
	{
		AnnounceTime=Float:GetConVarFloat(cvar);
	}
	else if(cvar==cvarRespawnDelay)
	{
		RespawnTime=GetConVarInt(cvar);
	}
	else if(cvar==cvarPlayerTeleport)
	{
		AllowNeutralTP=bool:GetConVarBool(cvarPlayerTeleport);
	}
	else if(cvar==cvarNoTriggerHurt)
	{
		NoTriggerHurt=bool:GetConVarBool(cvarNoTriggerHurt);
	}
	else if(cvar==cvarOnlyArena)
	{
		OnlyArena=bool:GetConVarBool(cvarOnlyArena);
	}
	else if(cvar==cvarPunishment)
	{
		AirBlastPunish=GetConVarInt(cvarPunishment);
	}
	else if(cvar==cvarPluginSilence)
	{
		PluginSilence=bool:GetConVarBool(cvarPluginSilence);
	}
	else if(cvar==cvarSolidTP)
	{
		SolidTP=bool:GetConVarBool(cvarSolidTP);
	}
	else if(cvar==cvarBlockBlood)
	{
		BlockBlood=bool:GetConVarBool(cvarBlockBlood);
	}
}

public EnableAL()
{
	new entity = -1;
	while((entity=FindEntityByClassname2(entity, "tf_logic_arena"))!=-1)
	{
		IsArenaFound=true;
	}
	
	
	if(UserPluginEnabled) //To-do: Remove this structure and use something better
	{
		if(OnlyArena)
		{
			if(IsArenaFound)
			{
				Enabled=true;
			}
			else
			{
				Enabled=false;
			}
		}
		else
		{
			Enabled=true;
		}
	}
	else
	{
		Enabled=false;
	}
	
	if(AnnounceTime>0.0) // Of course you can switch self-advertisement off
	{
		CreateTimer(AnnounceTime, Timer_Announce, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE); //Self-Advertising. With a specified time
	}
}

public DisableAL()
{
	LogMessage("AfterLife plugin unloading!!!");
	for(new i=1; i<=MaxClients; i++)
	{
		if(IsValidClient(i) && InTeamN[i])
		{
			SetMeToMyTeam(i, true);
			OnClientDisconnect(i);
		}
	}
	// Unload plugins. This is also from Freak Fortress 2
	decl String:path[PLATFORM_MAX_PATH];
	decl String:filename[PLATFORM_MAX_PATH];
	decl FileType:filetype;
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "plugins/afterlife_pl");
	new Handle:directory=OpenDirectory(path);
	directory=OpenDirectory(path);
	while(ReadDirEntry(directory, filename, sizeof(filename), filetype))
	{
		if(filetype==FileType_File && StrContains(filename, ".smx", false)!=-1)
		{
			ServerCommand("sm plugins unload afterlife_pl/%s", filename);
		}
	}
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, Hook_TakeDamage);
	SDKHook(client, SDKHook_SetTransmit, Hook_Transmit);
}

public OnClientDisconnect(client)
{
	CacheCookieValues(client);
	SDKUnhook(client, SDKHook_OnTakeDamage, Hook_TakeDamage);
	SDKUnhook(client, SDKHook_SetTransmit, Hook_Transmit);
	InTeamN[client]=false;
	PlayerEnabled[client]=false;
	PreferencesMenu[client]=false;
	ALFlags[client]=0;
}

public OnClientCookiesCached(client)
{
	new String:sValue[32];
	GetClientCookie(client, g_hCookieGravity, sValue, sizeof(sValue));
	if(sValue[0]=='\0') //A new client
	{
		CGravity[client]=1.0;
	}
	else
	{
		CGravity[client]=StringToFloat(sValue);
	}
	GetClientCookie(client, g_hCookieBlastSelf, sValue, sizeof(sValue));
	if(sValue[0]=='\0')
	{
		TakeBlast[client]=true;
	}
	else
	{
		TakeBlast[client]=bool:StringToInt(sValue);
	}
}

public Action:CallBack_Jointeam(client, const String:command[], argc)
{
	if(!IsValidClient(client) || IsFakeClient(client)) //Just to be sure.
	{
		return Plugin_Continue;
	}
	ScreenMenuChoice(client, false);
	return Plugin_Continue;
}

public ScreenMenuChoice(client, preferencesmenu)
{
	new String:buffer[128];
	SetGlobalTransTarget(client);
	if(preferencesmenu)
	{
		PreferencesMenu[client]=true;
	}
	new Handle:menu = CreateMenu(AfterLifeMenuHandler, MENU_ACTIONS_DEFAULT);
	SetMenuTitle(menu, "%t", "T_StartChoice");
	if(!preferencesmenu)
	{
		new String:sValue[12];
		GetClientCookie(client, g_hCookieEnabled, sValue, sizeof(sValue));
		if(!(sValue[0]=='\0'))
		{
			Format(buffer, sizeof(buffer), "%t", "T_MyDPref");
			AddMenuItem(menu, CHOICE1, buffer);
		}
	}
	Format(buffer, sizeof(buffer), "%t", "Yes");
	AddMenuItem(menu, CHOICE2, buffer);
	Format(buffer, sizeof(buffer), "%t", "No");
	AddMenuItem(menu, CHOICE3, buffer);
	DisplayMenu(menu, client, 50);
	return; 
}

public AfterLifeMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	new client=param1;
	switch(action)
	{
	case MenuAction_Select:
		{
			new String:info[32];
			GetMenuItem(menu, param2, info, sizeof(info));
			if(StrEqual(info, CHOICE3))
			{
				PlayerEnabled[client]=false;
			}
			else if(StrEqual(info, CHOICE2))
			{
				PlayerEnabled[client]=true;
			}
			else
			{
				new String:value[3];
				GetClientCookie(client, g_hCookieEnabled, value, sizeof(value));
				PlayerEnabled[client]=bool:StringToInt(value);
			}
			if(PlayerEnabled[client])
			{
				PrintToChat(client, "%s %t", SMTAG, "T_WillRespawn");
			}
			else
			{
				PrintToChat(client, "%s %t", SMTAG, "T_NoRespawn");
			}
			PrintToChat(client, "%s %t", SMTAG, "T_InfoChange");
			if(PreferencesMenu[client])
			{
				PreferencesMenu[client]=false;
				OptionsMenu(client);
			}
		}
	case MenuAction_Cancel:
		{
			if(param2==MenuCancel_Disconnected)
			{
				return 0;
			}
			new String:sValue[25];
			GetClientCookie(client, g_hCookieEnabled, sValue, sizeof(sValue));
			if(sValue[0]=='\0')
			{
				PlayerEnabled[client]=true;
			}
			else
			{
				PlayerEnabled[client]=bool:StringToInt(sValue);
			}
			if(PlayerEnabled[client])
			{
				PrintToChat(client, "%s %t", SMTAG, "T_WillRespawn");
			}
			else
			{
				PrintToChat(client, "%s %t", SMTAG, "T_NoRespawn");
			}
			PrintToChat(client, "%s %t", SMTAG, "T_InfoChange");
		}
	}
	return 0;
}

public Action:Command_PlayerStatus(client, args) //To-do: This will be removed in the official version
{
	if(client==0)
	{
		PrintToServer("Player Report:");
		PrintToServer("Data about the players and their status.");
		for(new i=0; i<=MaxClients; i++)
		{
			if(!IsValidClient(i))
			{
				continue;
			}
			new String:ID[64];
			GetClientAuthId(i, AuthId_Steam3, ID, sizeof(ID));
			PrintToServer("Client: %N Index: %i Alive: %i SteamID3: %s Enabled: %i In the Neutral Team: %i Gravity: %f TakeBlast: %i", i, i, IsPlayerAlive(i), ID, PlayerEnabled[i], InTeamN[i], CGravity[i], TakeBlast[i]);
		}
	}
	else if(IsValidClient(client))
	{
		PrintToConsole(client, "%s Major report.", SMTAG);
		PrintToConsole(client, "Data about the players and their status.", SMTAG);
		for(new i=0; i<=MaxClients; i++)
		{
			if(!IsValidClient(i))
			{
				continue;
			}
			new String:ID[64];
			GetClientAuthId(i, AuthId_Steam3, ID, sizeof(ID));
			PrintToConsole(client, "Client: %N Index: %i Alive: %i SteamID3: %s Enabled: %i In the Neutral Team: %i Gravity: %f TakeBlast: %i", i, i, IsPlayerAlive(i), ID, PlayerEnabled[i], InTeamN[i], CGravity[i], TakeBlast[i]);
		}
	}
	return Plugin_Handled;
}

public Action:Command_TogglePlayer(client, args)
{
	if(args<2)
	{
		ReplyToCommand(client, "Example: al_toggle <target> <1/0>");
		return Plugin_Handled;
	}
	new String:arg1[32];
	new String:arg2[10];
	new bool:enabled;
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	enabled=bool:StringToInt(arg2);
	
	
	/**
	* target_name - stores the noun identifying the target(s)
	* target_list - array to store clients
	* target_count - variable to store number of clients
	* tn_is_ml - stores whether the noun must be translated
	*/
	new String:target_name[MAX_TARGET_LENGTH];
	new target_list[MAXPLAYERS], target_count;
	new bool:tn_is_ml;

	if ((target_count = ProcessTargetString(
					arg1,
					client,
					target_list,
					MAXPLAYERS,
					COMMAND_FILTER_CONNECTED, /* Only allow alive players */
					target_name,
					sizeof(target_name),
					tn_is_ml)) <= 0)
	{
		/* This function replies to the admin with a failure message */
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (new i = 0; i < target_count; i++)
	{
		PlayerEnabled[target_list[i]]=enabled;
	}
	ReplyToCommand(client, "%s You have successfully toggled respawning of %s to %i", SMTAG, target_name, enabled); // This is not finished!
	ShowActivity2(client, "[AL] Toggled %s with value %i", target_name, enabled);
	return Plugin_Handled;
}

public Action:Command_ScreenMenu(client, args)
{
	if(!Enabled)
	{
		return Plugin_Continue;
	}
	
	if(client<=0 || IsFakeClient(client))
	{
		PrintToServer("[AL] Server/Bot cannot run this command!"); //Apparently, bot cannot joint team 0 and 1. 
		return Plugin_Handled;
	}
	OptionsMenu(client);
	return Plugin_Handled;
}

public OptionsMenu(client)
{
	new Handle:menu = CreateMenu(OptionHandler, MENU_ACTIONS_DEFAULT);
	SetGlobalTransTarget(client);
	new String:buffer[128];
	Format(buffer, sizeof(buffer), "%t", "T_TPreferences");
	SetMenuTitle(menu, buffer);
	Format(buffer, sizeof(buffer), "%t", "T_WThis");
	AddMenuItem(menu, CHOICE4, buffer);
	Format(buffer, sizeof(buffer), "%t", "T_CRPreferences", (PlayerEnabled[client]) ? "Yes" : "No");
	AddMenuItem(menu, CHOICE1, buffer);
	Format(buffer, sizeof(buffer), "%t %.1f", "T_CGravity", CGravity[client]);
	AddMenuItem(menu, CHOICE3, buffer);
	Format(buffer, sizeof(buffer), "%t", "T_BlastKnockBack", (TakeBlast[client]) ? "Yes" : "No");
	AddMenuItem(menu, CHOICE2, buffer);
	if(IsValidClient(client) && IsLegidToSpawn(client)) //Only dead and non-neutral players, fix an exploit
	{
		Format(buffer, sizeof(buffer), "%t", "T_RespawnMe");
		AddMenuItem(menu, CHOICE5, buffer);
	}
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 50);
	return 0;
}

public OptionHandler(Handle:menu, MenuAction:action, param1, param2)
{
	new client=param1;
	switch(action)
	{
	case MenuAction_Select:
		{
			decl String:info[32];
			GetMenuItem(menu, param2, info, sizeof(info));
			if(StrEqual(CHOICE1, info, false))
			{
				ScreenMenuChoice(client, true);
			}
			else if(StrEqual(CHOICE2, info, false))
			{
				TakeBlast[client]=!TakeBlast[client];
				OptionsMenu(client);
			}
			else if(StrEqual(CHOICE3, info, false))
			{
				GravitySettings(client);
			}
			else if(StrEqual(CHOICE4, info, false))
			{
				GeneralInformation(client);
			}
			else if(StrEqual(CHOICE5, info, false)) //Force them into the neutral team.
			{
				if(IsLegidToSpawn(client))
				{
					PlayerEnabled[client]=true; // Required.
					if(Arena_GetClientTeam(client)!=NTEAM && !InTeamN[client]) // Get their team before respawn
					{
						LastTeam[client]=Arena_GetClientTeam(client);
					}
					CreateTimer(0.1, Timer_Spawn, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE); //Use the plugin's own function.
				}
			}
		}
	}
	return 0;
}

public GeneralInformation(client) //To-do: Add this to the translation file!
{
	new String:text[128];
	new Handle:panel=CreatePanel();
	SetGlobalTransTarget(client);
	Format(text, sizeof(text), "[TF2] Afterlife plugin");
	DrawPanelText(panel, text);
	Format(text, sizeof(text), "Version: %s | Developed by %s", PLUGIN_VERSION, PLUGIN_AUTHOR);
	DrawPanelText(panel, text);
	Format(text, sizeof(text), "--------------------------------------------------");
	DrawPanelText(panel, text);
	Format(text, sizeof(text), "AfterLife is a Team Fortress 2 mod, which puts the");
	DrawPanelText(panel, text);
	Format(text, sizeof(text), "dead players in neutral team, where they respawn");
	DrawPanelText(panel, text);
	Format(text, sizeof(text), "and can do anything they want! But they cannot hurt");
	DrawPanelText(panel, text);
	Format(text, sizeof(text), "playing team players. Also they are invisible for them.");
	DrawPanelText(panel, text);
	Format(text, sizeof(text), "Subplugins can give further functionalities to the plugin");
	DrawPanelText(panel, text);
	Format(text, sizeof(text), "Oh, also you can RPS or High-Five the playing players");
	DrawPanelText(panel, text);
	Format(text, sizeof(text), "Back");
	DrawPanelItem(panel, text);
	SendPanelToClient(panel, client, ExitButton, 50);
	CloseHandle(panel);
}

public ExitButton(Handle:menu, MenuAction:action, client, selection)
{
	OptionsMenu(client);
	return 0;
}

public GravitySettings(client)
{
	SetGlobalTransTarget(client);
	new String:buffer[64];
	new Handle:menu = CreateMenu(GravityHandler, MENU_ACTIONS_DEFAULT);
	SetMenuTitle(menu, "%t", "T_GChange", CGravity[client], float(GetConVarInt(DGravity))/800.0);
	AddMenuItem(menu, CHOICE1, "+0.1");
	AddMenuItem(menu, CHOICE2, "-0.1");
	Format(buffer, sizeof(buffer), "%t", "Back");
	AddMenuItem(menu, CHOICE3, buffer);
	DisplayMenu(menu, client, 50);
	return 0;
}

public GravityHandler(Handle:menu, MenuAction:action, param1, param2)
{
	new client=param1;
	switch(action)
	{
	case MenuAction_Select:
		{
			decl String:info[32];
			GetMenuItem(menu, param2, info, sizeof(info));
			if(StrEqual(CHOICE1, info, false))
			{
				CGravity[client]+=0.1;
				if(RoundToNearest(CGravity[client])>=VERYGRAVITY)
				{
					PrintToChat(client, "%s %t",SMTAG, "T_GravityTooHigh");
				}
				if(InTeamN[client])
				{
					ApplyGravityClient(client, CGravity[client]);
				}
				GravitySettings(client);
			}
			else if(StrEqual(CHOICE2, info, false))
			{
				if(CGravity[client]<0.1)
				{
					PrintToChat(client, "%s %t", SMTAG, "T_NoNegGravity");
					CGravity[client]=0.0;
				}
				else
				{
					CGravity[client]-=0.1;
				}
				if(InTeamN[client])
				{
					ApplyGravityClient(client, CGravity[client]);
				}
				GravitySettings(client);
			}
			else if(StrEqual(CHOICE3, info, false))
			{
				OptionsMenu(client);
			}
		}
	}
	return 0;
}

CacheCookieValues(client)
{
	new String:value[10];
	IntToString(TakeBlast[client], value, sizeof(value));
	SetClientCookie(client, g_hCookieBlastSelf, value);
	FloatToString(CGravity[client], value, sizeof(value));
	SetClientCookie(client, g_hCookieGravity, value);
	IntToString(PlayerEnabled[client], value, sizeof(value));
	SetClientCookie(client, g_hCookieEnabled, value);
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) //Neutral team respawn system
{
	new deathplayer=GetClientOfUserId(GetEventInt(event, "userid"));
	if(!Enabled || !(GetRoundState()==1))
	{
		return Plugin_Continue;
	}
	if(GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER)
	{
		return Plugin_Continue;
	}
	if(InTeamN[deathplayer] && !PlayerEnabled[deathplayer])
	{
		ChangeClientTeam(deathplayer, LastTeam[deathplayer]);
		return Plugin_Continue;
	}
	if(PlayerEnabled[deathplayer])
	{
		PrintToChat(deathplayer, "%s %t", SMTAG, "T_YouRespawn", RespawnTime);
		RTimer[deathplayer]=CreateTimer(float(RespawnTime), Timer_Spawn, GetClientUserId(deathplayer), TIMER_FLAG_NO_MAPCHANGE);
		if(InTeamN[deathplayer])
		{
			ALFlags[deathplayer]|=ALFLAG_NDEAD;
			return Plugin_Handled; // Block the announcement
		}
	}
	return Plugin_Continue;
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) //Change their team to normal.
{
	new client=GetClientOfUserId(GetEventInt(event, "userid"));
	if(!Enabled ||	!IsValidClient(client))
	{
		return Plugin_Continue;
	}
	if(Arena_GetClientTeam(client)!=NTEAM && !InTeamN[client]) //Always know their team. Save their team even if they are not toggled to be from the neutral team.
	{
		LastTeam[client]=Arena_GetClientTeam(client);
	}
	if(InTeamN[client]) //Force stop announcing to another plugins for respawned player (Freak Fortress 2 and VSH related)!
	{
		return (PluginSilence) ? Plugin_Stop : Plugin_Handled; // Freak Fortress 2 and VSH will not detect airblasts any more!
	}
	return Plugin_Continue;
}

public Action:Event_OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!Enabled)
	{
		return Plugin_Continue;
	}
	for(new i=1; i<=MaxClients; i++)
	{
		if(IsValidClient(i) && InTeamN[i])
		{
			CreateTimer(0.1, Timer_RoundReady, GetClientUserId(i), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	return Plugin_Continue;
}

public Action:Timer_RoundReady(Handle:htimer, userid)
{
	new client=GetClientOfUserId(userid);
	if(!IsValidClient(client))
	{
		return Plugin_Stop;
	}
	InTeamN[client]=false;
	SetMeToMyTeam(client);
	return Plugin_Continue;
}

public Action:Event_OnPostInvertory(Handle:event, const String:name[], bool:dontBroadcast) //This is the best way to strip blacklisted items from the players
{
	if(!Enabled)
	{
		return Plugin_Continue;
	}
	new client=GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}
	if(InTeamN[client]) //Test for everything.
	{
		CreateTimer(0.1, Timer_CheckItems, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		return (PluginSilence) ? Plugin_Stop : Plugin_Handled; // Freak Fortress 2 and VSH will not detect airblasts any more!
	}
	return Plugin_Continue;
}

public Action:Event_ObjectSapped(Handle:event, const String:name[], bool:dontBroadcast) // Goodbye sappers!
{
	if(!Enabled)
	{
		return Plugin_Continue;
	}
	
	new client = GetClientOfUserId(GetEventInt(event, "ownerid"));
	new spy = GetClientOfUserId(GetEventInt(event, "userid"));
	new sapper = GetEventInt(event, "sapperid");
	AL_Debug("SapperID: %i EntIndex: %i", sapper, EntRefToEntIndex(sapper));
	
	if(InTeamN[spy] || !InTeamN[client])
	{
		RequestFrame(Frame_RemoveSapper, EntIndexToEntRef(sapper));
		AL_Debug("1. The sapper will be removed now!");
		AcceptEntityInput(sapper, "Kill");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Frame_RemoveSapper(ref)
{
	new entity=EntRefToEntIndex(ref);
	if(!IsValidEntity(entity))
	{
		return;
	}
	AcceptEntityInput(EntRefToEntIndex(ref), "Kill");
}

public Action:Event_OnObjectDeflected(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!Enabled || GetEventInt(event, "weaponid") || !GetRoundState())  //0 means that the client was airblasted
	{
		return Plugin_Continue;
	}
	new pushed = GetClientOfUserId(GetEventInt(event, "ownerid"));
	new pusher = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsValidClient(pushed) || !IsValidClient(pusher))
	{
		return Plugin_Continue;
	}
	if(InTeamN[pusher] && !InTeamN[pushed] && !(ALFlags[pusher] & ALFLAG_CANAIRBLAST))
	{
		new Float:Vel[3]; //This from the forum.
		TeleportEntity(pushed, NULL_VECTOR, NULL_VECTOR, Vel); // Stops knockback
		TF2_RemoveCondition(pushed, TFCond_Dazed); // Stops slowdown
		SetEntPropVector(pushed, Prop_Send, "m_vecPunchAngle", Vel);
		SetEntPropVector(pushed, Prop_Send, "m_vecPunchAngleVel", Vel); // Stops screen shake 
		switch(AirBlastPunish)
		{
		case 1: 
			{
				CreateTFStypeMessage(pusher, "Don't AIRBLAST playing players!!", "ico_ghost", 2);
			}
		case 2:
			{
				KickClient(pusher, "You have been kicked for AIRBLASTING playing players!!!");
			}
		}
		return (PluginSilence) ? Plugin_Stop : Plugin_Handled; // Freak Fortress 2 and VSH will not detect airblasts any more!
	}
	return Plugin_Continue;
}

public OnGameFrame()
{
	new index;
	while((index = FindEntityByClassname2(index, "obj_sentrygun"))!=-1)
	{
		new enemy=GetEntPropEnt(index, Prop_Send, "m_hEnemy");
		if(!IsValidClient(enemy))
		{
			SetNoTarget(index, false);
			return;
		}
		if(InTeamN[enemy] && !InTeamN[index])
		{
			SetNoTarget(index, true);
			return;
		}
		else
		{
			SetNoTarget(index, false);
			return;
		}
	}
}

public Action:Timer_Spawn(Handle:htimer, userid)
{
	new client=GetClientOfUserId(userid);
	if(!Enabled || !IsValidClient(client) || IsPlayerAlive(client))
	{
		return Plugin_Stop;
	}
	
	new Action:result;
	new flags;
	RTimer[client]=INVALID_HANDLE;
	if(GetRoundState()==0 || GetRoundState()==2) //Deny them to respawn when the round ends or setup timer for while.
	{
		return Plugin_Stop;
	}

	if(ALFlags[client] & ALFLAG_NDEAD)
	{
		ALFlags[client] &=~ ALFLAG_NDEAD;
	}
	
	if(!InTeamN[client])
	{
		InTeamN[client]=true;
		ALFlags[client]=ALFLAGS_GENERAL;
	}
	
	flags=ALFlags[client];
	Call_StartForward(g_hNRespawn);
	Call_PushCell(client);
	Call_PushCell(ALFlags[client] & ALFLAG_NDEAD);
	Call_PushCellRef(flags);
	Call_Finish(_:result);
	if(result==Plugin_Handled || result==Plugin_Stop)
	{
		return result;
	}
	if(result==Plugin_Changed)
	{
		ALFlags[client]=flags;
	}
	
	
	if(PlayerEnabled[client])
	{
		SetGlobalTransTarget(client);
		InTeamN[client]=true;
		SetMeToOtherTeam(client);
		PrintToChat(client, "%s %t", SMTAG, "T_JustRespawned");
		TeleportToSpawn(client, 0);
		CreateTimer(0.1, Timer_CheckItems, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		new String:buffer[128];
		Format(buffer, sizeof(buffer), "%t", "T_JyourPref");
		CreateTFStypeMessage(client, buffer);
	}
	return Plugin_Continue;
}

public Action:Timer_CheckItems(Handle:htimer, userid) //Filtering weapons.
{
	new client=GetClientOfUserId(userid);
	if(!IsValidClient(client) || !IsPlayerAlive(client) || !Enabled)
	{
		return Plugin_Stop;
	}
	if(!(ALFlags[client] & ALFLAG_CHECKITEMS) || !InTeamN[client])
	{
		return Plugin_Stop;
	}
	for(new i=0; i<=WSLOTS; i++)
	{
		new weapon=GetPlayerWeaponSlot(client, i);
		if(!IsValidEntity(weapon))
		{
			continue;
		}
		new itemindex=GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		switch(itemindex) // Sniper's jarates was whitelisted in version 0.5.1
		{
		case 222, 1121: // Scout - The Mad Milk
			{
				TF2_RemoveWeaponSlot(client, i);
				TFWeapons_Giveweapon(client, 23, "tf_weapon_pistol", 1, 8);
				PrintToChat(client, "%s Your secondary weapon was stripped and replaced with the pistol!", SMTAG); 
			}
		case 528: // Engineer - The Short Circuit
			{
				TF2_RemoveWeaponSlot(client, i);
				TFWeapons_Giveweapon(client, 30666, "tf_weapon_pistol", 1, 8);
				PrintToChat(client, "%s Your secondary weapon was stripped and replaced with the C.A.P.P.E.R.!", SMTAG);
			}
		}
	}
	return Plugin_Continue;
}

public OnEntityCreated(entity, const String:classname[]) //Hook them even if the plugin is not active.
{
	if(StrEqual(classname, "player", false) || StrEqual(classname, "instanced_scripted_scene", false) || StrEqual(classname, "tf_viewmodel", false)) //Some exceptions
	{
		return;
	}
	else if(StrEqual(classname, "tf_ragdoll", false)) //It seems that tf_ragdoll doesn't fire the spawn hook. Maybe only on my own server
	{
		RequestFrame(Frame_RagdollCheck, EntIndexToEntRef(entity));
		return;
	}
	else if(StrEqual(classname, "tf_logic_arena", false)) // The plugin will load only on arena maps.
	{
		IsArenaFound=true;
		return;
	}
	SDKHook(entity, SDKHook_SpawnPost, Entity_SpawnPost);
}

public Frame_RagdollCheck(ref) // Wow, i can change ragdoll properties here! Do everything fast!
{
	new entity=EntRefToEntIndex(ref);
	if(!IsValidEntity(entity))
	{
		return;
	}
	for(new i=1; i<=MaxClients; i++)
	{
		if(!IsValidClient(i))
		{
			continue;
		}
		if(GetEntPropEnt(i, Prop_Send, "m_hRagdoll")==entity)
		{
			if(InTeamN[i])
			{
				RemoveEdict(entity);
			}
		}
	}
}

public Action:Entity_SpawnPost(entity)
{
	if(!Enabled)
	{
		return Plugin_Continue;
	}
	new String:classname[64];
	new owner;
	GetEntityClassname(entity, classname, sizeof(classname));
	if((StrContains(classname, "tf_projectile_", false)>-1) || (StrEqual(classname, "tf_flame", false))) //Cover tf_flame projectiles!
	{
		if(StrEqual(classname, "tf_flame", false)) // Every energy weapon projectile except the cow mangler and the short circuit has classname tf_flame
		{
			owner=GetEntPropEnt(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity"), Prop_Send, "m_hOwnerEntity");
		}
		else
		{
			owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		}
		if(!IsValidEntity(owner))
		{
			return Plugin_Continue;
		}
		if(InTeamN[owner])
		{
			if(IsValidClient(owner) && (ALFlags[owner] & ALFLAG_NOPROJCOLLIDE))
			{
				SDKHook(entity, SDKHook_StartTouch, Hook_OnProjectileTouch);
				SDKHook(entity, SDKHook_Touch, Hook_OnProjectileTouch);
			}
			if(IsValidClient(owner) && (ALFlags[owner] & ALFLAG_INVISIBLE))
			{
				SDKHook(entity, SDKHook_SetTransmit, Hook_Transmit);
			}
			GetEntityClassname(owner, classname, sizeof(classname));
			if(StrContains(classname, "obj_", false)>-1)
			{
				new owner2=GetEntPropEnt(owner, Prop_Send, "m_hBuilder");
				if(IsValidClient(owner2) && InTeamN[owner2])
				{
					if(ALFlags[owner2] & ALFLAG_NOPROJCOLLIDE)
					{
						SDKHook(entity, SDKHook_StartTouch, Hook_OnProjectileTouch);
						SDKHook(entity, SDKHook_Touch, Hook_OnProjectileTouch);
					}
					if(ALFlags[owner2] & ALFLAG_INVISIBLE)
					{
						SDKHook(entity, SDKHook_SetTransmit, Hook_Transmit);
					}
				}
			}
			InTeamN[entity]=true;
		}
	}
	else if(StrContains(classname, "obj_", false)>-1)
	{
		owner=GetEntPropEnt(entity, Prop_Send, "m_hBuilder");
		if(!IsValidClient(owner))
		{
			return Plugin_Continue;
		}
		if(InTeamN[owner])
		{
			if(ALFlags[owner] & ALFLAG_INVISIBLE)
			{
				SDKHook(entity, SDKHook_SetTransmit, Hook_Transmit);
			}
			if(!StrEqual(classname, "obj_teleporter") || !SolidTP)
			{
				SetEntProp(entity, Prop_Send, "m_usSolidFlags", 22);
			}
			InTeamN[entity]=true;
		}
		SDKHook(entity, SDKHook_OnTakeDamage, Hook_TakeDamage);
	}
	else if(StrContains(classname, "prop_", false)>-1) //Compatibility with Building Hats plugin: https://forums.alliedmods.net/showthread.php?t=243705
	{
		RequestFrame(Frame_ProcessBHats, EntIndexToEntRef(entity));
	}
	else if(StrEqual(classname, "tf_taunt_prop", false)) // Using heuristic way to find the owner of tauntprop
	{
		RequestFrame(Frame_HandleTauntProps, EntIndexToEntRef(entity));
	}
	return Plugin_Continue;
}

public Frame_HandleTauntProps(ref)
{
	new entity=EntRefToEntIndex(ref);
	if(!IsValidEntity(entity))
	{
		return;
	}
	new Float:entityOrigin[3], Float:searchOrigin[3], Float:distance, Float:near, nearest;
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityOrigin);
	for(new search=1; search<=MaxClients; search++) // 1. Find the nearest player
	{
		if(IsValidClient(search) && IsPlayerAlive(search))
		{
			GetEntPropVector(search, Prop_Send, "m_vecOrigin", searchOrigin);
			distance=GetVectorDistance(entityOrigin, searchOrigin);
			AL_Debug("Client: %N Distance: %f", search, distance);
			if(near==0.0)
			{
				near=distance;
				nearest=search;
			}
			if(distance<near)
			{
				near=distance;
				nearest=search;
				AL_Debug("Found near player: %N", nearest);
			}
		}
	}
	AL_Debug("Found nearest player: %N", nearest);
	// 2. Test if the player taunts
	if(InTeamN[nearest] && TF2_IsPlayerInCondition(nearest, TFCond_Taunting))
	{
		AL_Debug("The player is in taunt condition: %N", nearest);
		AL_Debug("Taunt index: %i", GetEntProp(nearest, Prop_Send, "m_iTauntItemDefIndex"));
		switch (GetEntProp(nearest, Prop_Send, "m_iTauntItemDefIndex"))
		{
		case 30570, 1115: //Pool party - Pyro, Rancho Relaxo - Engineer
			{
				AL_Debug("Success. The plugin found the owner of the tauntprop: %N Flagging!", nearest);
				if(ALFlags[nearest] & ALFLAG_INVISIBLE)
				{
					AL_Debug("Flagged entity for invisibility!");
					SDKHook(entity, SDKHook_SetTransmit, Hook_Transmit);
				}
				InTeamN[entity]=true;
				AL_Debug("Entity is registered!");
			}
		}
	}
}

public Frame_ProcessBHats(ref)
{
	new entity=EntRefToEntIndex(ref);
	if(!IsValidEntity(entity))
	{
		return;
	}
	new owner;
	new String:classname[64];
	owner=GetEntPropEnt(entity, Prop_Send, "moveparent");
	if(IsValidEntity(owner))
	{
		GetEntityClassname(owner, classname, sizeof(classname));
		if(StrContains(classname, "obj_", false)>-1)
		{
			if(InTeamN[owner])
			{
				new owner2=GetEntPropEnt(owner, Prop_Send, "m_hBuilder");
				{
					if(IsValidClient(owner2) && (ALFlags[owner2] & ALFLAG_INVISIBLE))
					{
						SDKHook(entity, SDKHook_SetTransmit, Hook_Transmit);
					}
				}
				InTeamN[entity]=true;
			}
		}
	}
}

public OnEntityDestroyed(entity) //Deinitialize entity.
{
	if(entity<=MAXENTITIES && entity>MaxClients)
	{
		InTeamN[entity]=false;
	}
}

public Action:Timer_Announce(Handle:htimer) //To-do: More details and information
{
	if(!Enabled)
	{
		return Plugin_Stop;
	}
	switch(GetRandomInt(0, 5))
	{
	case 1, 2:
		{
			PrintToChatAll("\x03 If you want to respawn into the neutral team or want to \x01", SMTAG);
			PrintToChatAll("\x03 change your gravity write \x077FFF00!neutral\x03 into chat! \x01", SMTAG);
		}
	case 3, 0:
		{   // Now, I know how to works with colors without include files: \x07*hexcode*
			PrintToChatAll("\x03 This server is running the plugin \"AfterLife\"");
			PrintToChatAll("\x03 Developed by \x07FF8C00Naydef\x03. Current version: %s", PLUGIN_VERSION);
		}
	case 4, 5:
		{
			PrintToChatAll("%s To Change your neutral team preferences, write \x077FFF00!neutral\x01 in chat!", SMTAG); 
		}
	}
	return Plugin_Continue;
}

public Action:Hook_OnProjectileTouch(entity, other) //Tested and works!
{
	if(!Enabled || other<=0)
	{
		return Plugin_Continue;
	}
	if(!InTeamN[other] && InTeamN[entity])
	{
		new String:classname[64];
		GetEntityClassname(other, classname, sizeof(classname));
		if(StrContains(classname, "obj_", false)>-1 || StrEqual(classname, "player", false))
		{
			AcceptEntityInput(entity, "Kill");  //Be silent.
			InTeamN[entity]=false;
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action:Hook_Transmit(objs, entity) //CPU expensive processes!
{
	if(!Enabled || objs==entity)
	{
		return Plugin_Continue;
	}
	if(!InTeamN[entity] && InTeamN[objs])
	{
		new item=-1;
		while((item=FindEntityByClassname2(item, "tf_wea*"))!=-1) // 1. Scan every player item
		{
			if(GetEntPropEnt(item, Prop_Send, "m_hOwnerEntity")==objs)
			{
				if(GetEdictFlags(item) & FL_EDICT_ALWAYS)
				{
					SetEdictFlags(item, GetEdictFlags(item) ^ FL_EDICT_ALWAYS);
				}
			}
		}
		
		// Do you know: Particle systems have FL_EDICT_ALWAYS flag, which will make every entity parented to them visible
		while((item=FindEntityByClassname2(item, "info_particle_system"))!=-1) // 2. Scan every particle with owner neutral object
		{
			if(GetEntPropEnt(item, Prop_Send, "moveparent")==objs)
			{
				if(GetEdictFlags(item) & FL_EDICT_ALWAYS)
				{
					SetEdictFlags(item, GetEdictFlags(item) ^ FL_EDICT_ALWAYS);
				}
			}
		}
		if(GetEdictFlags(objs) & FL_EDICT_ALWAYS)
		{
			SetEdictFlags(objs, GetEdictFlags(objs) ^ FL_EDICT_ALWAYS); //The flag is removed.
		}
		
		// Process with the logic!
		if(IsValidClient(entity) && !IsPlayerAlive(entity) && InTeamN[objs])
		{
			return (SpectatorCanSee) ? Plugin_Continue : Plugin_Handled;
		}
		
		if(IsValidClient(objs))
		{
			return (ALFlags[objs] & ALFLAG_INVISIBLE) ? Plugin_Handled : Plugin_Continue;
		}
		return Plugin_Handled; //For every other entity!
	}
	return Plugin_Continue;
}

public Action:Hook_TakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if(!Enabled)
	{
		return Plugin_Continue;
	}
	
	if(InTeamN[victim] && !IsValidClient(attacker)  && !(ALFlags[victim] & ALFLAG_TAKEDMG)) //"and can do anything they want!" sentence is a promise
	{
		new String:classname[64];
		GetEntityClassname(attacker, classname, sizeof(classname));
		if(!attacker || StrEqual(classname, "trigger_hurt", false) || (StrContains(classname, "func_", false)>-1))
		{
			if(NoTriggerHurt)
			{
				AL_Debug("Procedure 1 reached!");
				return Plugin_Handled;
			}
			else
			{
				AL_Debug("Procedure 2 reached!");
				damagetype|=DMG_REMOVENORAGDOLL;
				return Plugin_Changed;
			}
		}
	}
	
	if(InTeamN[victim] && victim==attacker)
	{
		if(IsValidClient(victim) && TakeBlast[victim])
		{
			if(damagetype & DMG_BLAST) // Give a chance for the soldiers, demomans and pyros. Or for everyone with a rocket launcher
			{
				ScaleVector(damageForce, 0.1);
				TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, damageForce); // I want to them to jump.
				if(ALFlags[victim] & ALFLAG_TAKEDMG)
				{
					damagetype|=DMG_REMOVENORAGDOLL;
					AL_Debug("Procedure 3 reached!");
					return Plugin_Changed;
				}
				else
				{
					AL_Debug("Procedure 4 reached!");
					return Plugin_Handled;
				}
			}
		}
		AL_Debug("Procedure 10 reached!");
		return Plugin_Handled;
	}
	
	if(InTeamN[victim] && InTeamN[attacker])
	{
		AL_Debug("Procedure 5 reached!");
		damagetype|=DMG_REMOVENORAGDOLL;
		return Plugin_Changed;
	}

	if(InTeamN[victim] || InTeamN[attacker])
	{
		if(IsValidClient(victim) && IsValidClient(attacker) && InTeamN[attacker] && (ALFlags[attacker] & ALFLAG_DONTSTUN))
		{
			RequestFrame(Frame_FilterCondition, GetClientUserId(victim));
		}
		if(IsValidClient(victim) && !(ALFlags[victim] & ALFLAG_TAKEDMG) && InTeamN[victim])
		{
			AL_Debug("Procedure 6 reached!");
			return Plugin_Handled;
		}
		else if(IsValidClient(victim) && InTeamN[victim])
		{
			AL_Debug("Procedure 7 reached!");
			damagetype|=DMG_REMOVENORAGDOLL;
			return Plugin_Changed;
		}
		AL_Debug("Procedure 8 reached!");
		return Plugin_Handled;
	}
	//PrintToServer("Procedure 9 reached!");
	//LogMessage("Procedure 9 reached");
	return Plugin_Continue;
}

public Frame_FilterCondition(userid)
{
	new client=GetClientOfUserId(userid);
	if(!IsValidClient(client))
	{
		return;
	}
	TF2_RemoveCondition(client, TFCond_Dazed);
	TF2_RemoveCondition(client, TFCond_OnFire);
	TF2_RemoveCondition(client, TFCond_Bleeding);
}

public Action:Hook_OnJarate(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable, bool:init) //The code is from Freak Fortress 1.10.6
{
	if(!Enabled)
	{
		return Plugin_Continue;
	}
	new client=BfReadByte(bf);
	new victim=BfReadByte(bf);
	if(InTeamN[client] && !InTeamN[victim])
	{
		if(ALFlags[client] & ALFLAG_JRTAMM)
		{
			RequestFrame(Frame_RemoveJar, GetClientUserId(victim));
		}
	}
	return Plugin_Continue;
}

public Frame_RemoveJar(userid)
{
	new client=GetClientOfUserId(userid);
	if(!IsValidClient(client))
	{
		return;
	}
	TF2_RemoveCondition(client, TFCond_Jarated);
}

bool:SetMeToOtherTeam(client)
{
	if(!IsValidClient(client))
	{
		return false;
	}
	SetEntProp(client, Prop_Send, "m_lifeState", 2);
	ChangeClientTeam(client, NTEAM);
	TF2_RespawnPlayer(client);
	SetEntProp(client, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);               // Set their collision group to debris but triggers.
	TF2_RegeneratePlayer(client); // Fix civilian bug, because of TF2Items!
	TeleportToSpawn(client, 0);
	CreateTimer(0.1, Timer_SetGravity, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	return true;
}

bool:SetMeToMyTeam(client, dontrespawn=false)
{
	if(!IsValidClient(client))
	{
		return false;
	}
	SetEntProp(client, Prop_Send, "m_lifeState", 2);
	ChangeClientTeam(client, LastTeam[client]);
	if(dontrespawn)
	{
		TF2_RespawnPlayer(client);
		TF2_RegeneratePlayer(client);
	}
	ApplyGravityClient(client, float(GetConVarInt(DGravity))/800.0); // Note: This is a handle to the current value of the gravity of the server convar!
	SetEntProp(client, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_PLAYER); // Set their normal collision.
	return true;
}

public Action:Timer_SetGravity(Handle:htimer, userid) //Something useful
{
	new client=GetClientOfUserId(userid);
	if(!IsValidClient(client))
	{
		return Plugin_Stop;
	}
	if(GetEntityFlags(client) & FL_ONGROUND)
	{
		ApplyGravityClient(client, CGravity[client]);
		return Plugin_Stop;
	}
	else
	{
		ApplyGravityClient(client, float(GetConVarInt(DGravity))/800.0);
	}
	return Plugin_Continue;
}

public Action:TF2_OnPlayerTeleport(client, teleporter, &bool:result)
{
	if(!Enabled)
	{
		return Plugin_Continue;
	}
	if(!InTeamN[client])
	{
		return Plugin_Continue;
	}
	if(AllowNeutralTP)
	{
		result=true;
		if(!InTeamN[teleporter])
		{
			RequestFrame(Frame_SetFullChargeTP, EntIndexToEntRef(teleporter));
		}
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Frame_SetFullChargeTP(ref)
{
	new entity=EntRefToEntIndex(ref);
	if(!IsValidEntity(entity))
	{
		return;
	}
	SetEntPropFloat(entity, Prop_Send, "m_flRechargeTime", GetGameTime()+0.1);
}

#if SOURCEMOD_V_MAJOR==1 && SOURCEMOD_V_MINOR>=8
public Action:Hook_EntitySound(clients[64], &numClients, String:sound[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags, String:soundEntry[PLATFORM_MAX_PATH], &seed)
#else
public Action:Hook_EntitySound(clients[64], &numClients, String:sound[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
#endif
{
	if(!Enabled)
	{
		return Plugin_Continue;
	}
	for(new i=0; i<numClients; i++)
	{
		if(IsValidClient(i) && InTeamN[entity])
		{
			if(!InTeamN[clients[i]] && IsPlayerAlive(clients[i]))
			{
				//AL_Debug("Exception to client %N from entity %i File: %s", clients[i], entity, sound);
				clients[i]=0; // Exception
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}

public Action:Hook_TempEntHook(const String:te_name[], const Players[], numClients,  Float:delay) //From be the skeleton plugin
{
	new client=TE_ReadNum("entindex");
	if(IsValidClient(client) && InTeamN[client] && BlockBlood)
	{
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

bool:IsLegidToSpawn(client)
{
	if(!Enabled || !IsValidClient(client) || InTeamN[client] || IsPlayerAlive(client))
	{
		return false;
	}
	if(!GetEntProp(client, Prop_Send, "m_iDesiredPlayerClass"))
	{
		return false;
	}
	if(RTimer[client]!=INVALID_HANDLE)
	{
		return false;
	}
	return true;
}  


/*                                    Natives                                    */
public Native_IsEnabled(Handle:plugin, numParams)
{
	return _:Enabled;
}

public Native_IsPlayerEnabled(Handle:plugin, numParams)
{
	return _:PlayerEnabled[GetNativeCell(1)];
}

public Native_SetPlayerInNeutral(Handle:plugin, numParams)
{
	PlayerEnabled[GetNativeCell(1)]=GetNativeCell(2);
	return 1;
}

public Native_IsInNeutralTeam(Handle:plugin, numParams)
{
	return _:InTeamN[GetNativeCell(1)];
}

public Native_GetGravityNeutral(Handle:plugin, numParams)
{
	return _:CGravity[GetNativeCell(1)];
}

public Native_SetGravityNeutral(Handle:plugin, numParams)
{
	CGravity[GetNativeCell(1)]=GetNativeCell(2);
	return;
}

public Native_IsBlastEnabled(Handle:plugin, numParams)
{
	return _:TakeBlast[GetNativeCell(1)];
}

public Native_SetBlast(Handle:plugin, numParams)
{
	return TakeBlast[GetNativeCell(1)]=GetNativeCell(2);
	
}

public Native_GetFlags(Handle:plugin, numParams)
{
	return ALFlags[GetNativeCell(1)];
}

public Native_SetFlags(Handle:plugin, numParams)
{
	return ALFlags[GetNativeCell(1)]=GetNativeCell(2);
}

public Native_IsDebugEnabled(Handle:plugin, numParams)
{
	return _:DebugEnabled;
}

public Native_GetNeutralTeamNum(Handle:plugin, numParams)
{
	return NTEAM;
}

/*                                     Stocks                                    */
bool:IsTF2() //My stock
{
	return (GetEngineVersion()==Engine_TF2) ? true : false;
}

TeleportToSpawn(iClient, iTeam = 0) //Chdata and VS SAXTON HALE 1.53
{
	new iEnt = -1;
	decl Float:vPos[3];
	decl Float:vAng[3];
	new Handle:hArray = CreateArray();
	while ((iEnt = FindEntityByClassname2(iEnt, "info_player_teamspawn")) != -1)
	{
		if (iTeam <= 1) // Not RED (2) nor BLU (3)
		{
			PushArrayCell(hArray, iEnt);
		}
		else
		{
			new iSpawnTeam = GetEntProp(iEnt, Prop_Send, "m_iTeamNum");
			if (iSpawnTeam == iTeam)
			{
				PushArrayCell(hArray, iEnt);
			}
		}
	}
	iEnt = GetArrayCell(hArray, GetRandomInt(0, GetArraySize(hArray) - 1));
	CloseHandle(hArray);
	// Technically you'll never find a map without a spawn point. Not a good map at least.
	GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vPos);
	GetEntPropVector(iEnt, Prop_Send, "m_angRotation", vAng);
	TeleportEntity(iClient, vPos, vAng, NULL_VECTOR);
}

FindEntityByClassname2(startEnt, const  String:classname[])
{
	/* If startEnt isn't valid shifting it back to the nearest valid one */
	while (startEnt > -1 && !IsValidEntity(startEnt))
	startEnt--;
	return FindEntityByClassname(startEnt, classname);
}

bool:IsValidClient(client, bool:replaycheck=true)//From Freak Fortress 2
{
	if(client<=0 || client>MaxClients)
	{
		return false;
	}

	if(!IsClientInGame(client))
	{
		return false;
	}

	if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
	{
		return false;
	}

	if(replaycheck)
	{
		if(IsClientSourceTV(client) || IsClientReplay(client))
		{
			return false;
		}
	}
	return true;
}

SetNoTarget(ent, bool:apply) //From Friendly Mode plugin
{
	new flags;
	if(apply)
	{
		flags=GetEntityFlags(ent)|FL_NOTARGET;
	}
	else
	{
		flags=GetEntityFlags(ent)&~FL_NOTARGET;
	}
	SetEntityFlags(ent, flags);
}

Arena_GetClientTeam(entity) //Also works on entities!
{
	return (IsValidEntity(entity)) ? GetEntProp(entity, Prop_Send, "m_iTeamNum") : -1;
}


Float:ApplyGravityClient(client, Float:gravity)  //This value affects the prediction of the client!
{
	if(!IsValidClient(client))
	{
		return -1.0;
	}
	if(gravity==0.0)
	{
		SetEntityGravity(client, 0.0000000000001); 
	}
	else
	{
		SetEntityGravity(client, gravity);
	}
	return gravity;
}

/*
	Return values:
	!GetRoundState == The round has not started
	(GetRoundState==2) == When the round ended 
	!(GetRoundState==2) == When the round is running or not started
	!(GetRoundState==1) == The round is not running
*/

GetRoundState()
{
	switch(GameRules_GetRoundState())
	{
	case RoundState_Pregame, RoundState_StartGame, RoundState_Preround:
		{
			return 0;
		}
	case RoundState_RoundRunning, RoundState_Stalemate:
		{
			return 1;
		}
	case RoundState_TeamWin, RoundState_GameOver, RoundState_Bonus:
		{
			return 2;
		}
	default:
		{
			return -1;
		}
	}
	return -1;
}

// Modified tf2 style message for this plugin!
bool:CreateTFStypeMessage(client, const String:message[], const String:icon[]="leaderboard_streak", color = 0)
{
	if(client<=0 || client>MaxClients || !IsClientInGame(client))
	{
		return false;
	}
	new Handle:bf = StartMessageOne("HudNotifyCustom", client);
	BfWriteString(bf, message);
	BfWriteString(bf, icon);
	BfWriteByte(bf, color);
	EndMessage();
	return true;
}