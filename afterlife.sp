/*
			Welcome to the source code of the "[TF2] AfterLife" plugin.
			Version: 0.9.0 Beta 3 | Private semi-gamemode plugin. | Stable
			Inspired from Ghost Mode Redux by ReFlexPoison, but without 
			anything copied from his code.			
			Minimum Requirements: Sourcemod >=1.6 , SDKHooks 2.1, TFWeapons plugin 1.3
			Known bugs:
			Screwing team counts - Fixed
			Projectile explosion from team 2 at team 1 - Fixed
			Fix server crash, when player disconnects - Fixed
			Make bots from team 1 ignore team 2 and vice versa - Impossible for now
			Make sentries from both teams ignore players from both teams - Fixed
			Fix client crash due to changing team - Fixed
			Fix random crashes due to interfering plugins themselves - Stopped for now
			Fix double event issues - Fixed
			Fix the Neutral team cannot hurt themselves
			Improvements:
			Make it for regular players on the server - Ready
			On death, respawn the player in team 2 - Ready
			Improve the code - In beta stage
			New name - Ready
			Convert the syntax to Sourcemod 1.7=> - Far future
			Block sounds from team 2 to team 1 - Implemented
			Implement block death messages - Ready
			Implement API (Natives) - Ready
			Create SubPlugins - Implementing
			Translation Support - Near Future
*/
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <clientprefs>
#include <tfweapons> //My own give weapon plugin 
#include <afterlife_plugin> //s

#define PLUGIN_VERSION "0.9.0 Beta 3"
#define PLUGIN_AUTHOR "Naydef"

//Defines
#define VERYGRAVITY 12.5
#define MAXENTITIES 2048
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

new Handle:cvarEnabled=INVALID_HANDLE;               // Plugin Enabled by user
new Handle:cvarDebug=INVALID_HANDLE;                 // Debug cvar
new Handle:cvarSpectatorCanSee=INVALID_HANDLE;
new Handle:cvarAnnounceTime=INVALID_HANDLE;         // Announce time delay
new Handle:cvarRespawnDelay=INVALID_HANDLE;         // Respawn delay
new Handle:cvarPlayerTeleport=INVALID_HANDLE;       // Allow neutral team to use teleporters of the real team.
new Handle:cvarNoTriggerHurt=INVALID_HANDLE;        // No trigger_hurt for the neutral team!
new Handle:cvarOnlyArena=INVALID_HANDLE;
new Handle:cvarPunishment=INVALID_HANDLE;
new Handle:DGravity;                                 // Set the gravity of the player.

new bool:UserPluginEnabled;                         // Control variable for cvar
new bool:Enabled;                                    // Variable for enabled plugin
new bool:DebugEnabled;
new bool:SpectatorCanSee;
new bool:AllowNeutralTP;
new bool:NoTriggerHurt;
new bool:IsArenaFound;
new bool:OnlyArena;
new bool:PlayerEnabled[MAXPLAYERS+1];
new bool:TakeBlast[MAXPLAYERS+1];                    // Can they take blast force.
new bool:PreferencesMenu[MAXPLAYERS+1];             // Is panel to back.
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
	url = "http://ngeo.ftp.sh/development/"
};

public OnPluginStart()
{
	LogMessage("AfterLife plugin loading!!!");
	IsTF2(); //My stock!
	RegConsoleCmd("sm_neutral", Command_ScreenMenu, "Toggle the options menu to yourself.");
	RegAdminCmd("al_status", Command_PlayerStatus, ADMFLAG_GENERIC, "Check the players"); //I need to know everything.
	CreateConVar("afterlife_version", PLUGIN_VERSION, "AfterLife version cvar", FCVAR_NOTIFY|FCVAR_SPONLY|FCVAR_DONTRECORD);
	cvarEnabled=CreateConVar("al_enabled", "1", "1- The plugin is enabled 0- The plugin is disabled: Are you sure?", _, true, 0.0, true , 1.0);
	cvarSpectatorCanSee=CreateConVar("al_spcanseeneutral", "1", "Set if the spectators can see players from the neutral team.", _, true, 0.0, true , 1.0);
	cvarDebug=CreateConVar("al_debug", "0", "Enable debug messages.", _, true, 0.0, true , 1.0);
	cvarAnnounceTime=CreateConVar("al_announce_time", "145", "Amount of seconds to wait until AL info is displayed again | 0-disable it", _, true, 0.0);
	cvarRespawnDelay=CreateConVar("al_respawn_time", "7", "Seconds before the player respawns. Minimum delay: 1 second", _, true, 1.0);
	cvarPlayerTeleport=CreateConVar("al_neutral_tp", "1", "1- Allow the neutral team to use real team teleporters | 0-Otherwise ", _, true, 0.0, true, 1.0);
	cvarNoTriggerHurt=CreateConVar("al_notrhurt", "1", "1- No damage from the map except fall damage | 0-Otherwise!", _, true, 0.0, true, 1.0);
	cvarOnlyArena=CreateConVar("al_only_arena", "1", "1- The plugin will work only on arena maps (which have tf_arena_logic entity) | 0-Otherwise!", _, true, 0.0, true, 1.0);
	cvarPunishment=CreateConVar("al_airblast_punishment", "1", "Airblast punishment 0- Nothing 1-Warning message 2-Kick the player");
	HookConVarChange(cvarEnabled, CvarChange);
	HookConVarChange(cvarSpectatorCanSee, CvarChange);
	HookConVarChange(cvarDebug, CvarChange);
	HookConVarChange(cvarAnnounceTime, CvarChange);
	HookConVarChange(cvarRespawnDelay, CvarChange);
	HookConVarChange(cvarPlayerTeleport, CvarChange);
	HookConVarChange(cvarNoTriggerHurt, CvarChange);
	HookConVarChange(cvarOnlyArena, CvarChange);
	HookConVarChange(cvarPunishment, CvarChange);

	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("teamplay_round_start", Event_OnRoundStart, EventHookMode_Post);
	HookEvent("post_inventory_application", Event_OnPostInvertory, EventHookMode_Pre);
	HookEvent("player_sapped_object", Event_ObjectSapped, EventHookMode_Pre);
	HookEvent("object_deflected", Event_OnObjectDeflected, EventHookMode_Pre);
	
	HookUserMessage(GetUserMessageId("PlayerJarated"), Hook_OnJarate); //OK, this is from Freak Fortress 2 1.10.6
	
	AddCommandListener(CallBack_Jointeam, "jointeam");
	AutoExecConfig(true, "AfterLifePlugin");
	AddNormalSoundHook(Hook_EntitySound);
	
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
			ScreenMenuChoice(i, false);
			OnClientPutInServer(i);
		}
	}
	for(new i=1; i<=MaxClients; i++) //Also for cookies
	{
		if(AreClientCookiesCached(i))
		{
			OnClientCookiesCached(i);
		}
	}
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
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
	
	//Forwards
	g_hNRespawn=CreateGlobalForward("AL_OnNeutralRespawn", ET_Event, Param_Cell, Param_Cell);
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
	
	//Load plugins. This is also from Freak Fortress 2
	decl String:path[PLATFORM_MAX_PATH];
	decl FileType:filetype;
	decl String:filename[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "plugins/afterlife_pl");
	new Handle:directory=OpenDirectory(path);
	directory=OpenDirectory(path);
	while(ReadDirEntry(directory, filename, PLATFORM_MAX_PATH, filetype))
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
			SetEntProp(i, Prop_Send, "m_lifeState", 2);
			SetMeToMyTeam(i);
			ChangeClientTeam(i, LastTeam[i]); // This surely make ghost players
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
	while(ReadDirEntry(directory, filename, PLATFORM_MAX_PATH, filetype))
	{
		if(filetype==FileType_File && StrContains(filename, ".smx", false)!=-1)
		{
			ServerCommand("sm plugins unload afterlife_pl/%s", filename);
		}
	}
}

public OnClientPutInServer(client)
{
	if(client<=0 || client>MaxClients) //Just to be sure!
	{
		return;
	}
	SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
	SDKHook(client, SDKHook_SetTransmit, Hook_Transmit);
	ALFlags[client]=0;
}

public OnClientDisconnect(client)
{
	if(client<=0 || client>MaxClients) //Just to be sure!
	{
		return;
	}
	CacheCookieValues(client);
	SDKUnhook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
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
	
	GetClientCookie(client, g_hCookieEnabled, sValue, sizeof(sValue));
	if(sValue[0]=='\0')
	{
		PlayerEnabled[client]=true;
	}
	else
	{
		PlayerEnabled[client]=bool:StringToInt(sValue);
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
	if(preferencesmenu)
	{
		PreferencesMenu[client]=true;
	}
	new Handle:menu = CreateMenu(AfterLifeMenuHandler, MENU_ACTIONS_DEFAULT);
	SetMenuTitle(menu, "Do you want to respawn into the Neutral team, after you die?");
	if(!preferencesmenu)
	{
		new String:sValue[12];
		GetClientCookie(client, g_hCookieEnabled, sValue, sizeof(sValue));
		if(!(sValue[0]=='\0'))
		{
			AddMenuItem(menu, CHOICE1, "My default preference");
		}
	}
	AddMenuItem(menu, CHOICE2, "Yes");
	AddMenuItem(menu, CHOICE3, "No");
	DisplayMenu(menu, client, 30);
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
				Debug("Client: %N Value: %s", client, value);
				PlayerEnabled[client]=bool:StringToInt(value);
			}
			PrintToChat(client, "%s You will %s after you die!", SMTAG, (PlayerEnabled[client]==false) ? "not respawn into the neutral team" : "respawn into the neutral team");
			PrintToChat(client, "%s Of course, you can change this by writing \"!neutral\" into chat!", SMTAG);
			if(PreferencesMenu[client])
			{
				PreferencesMenu[client]=false;
				OptionsMenu(client);
			}
		}
	}
	return 0;
}

public Action:Command_PlayerStatus(client, args) //To-do: This will be removed in the official version
{
	if(client==0)
	{
		PrintToServer("Major report.");
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

public Action:Command_ScreenMenu(client, args)
{
	if(!Enabled)
	{
		return Plugin_Continue;
	}
	
	if(client<=0 || IsFakeClient(client))
	{
		PrintToServer("%s Server/Bot cannot run this command!", SMTAG); //Apparently, bot cannot joint team 0 and 1. 
		return Plugin_Handled;
	}
	OptionsMenu(client);
	return Plugin_Handled;
}

public OptionsMenu(client)
{
	new Handle:menu = CreateMenu(OptionHandler, MENU_ACTIONS_DEFAULT);
	new String:buffer[128];
	Format(buffer, sizeof(buffer), "Player Preferences");
	SetMenuTitle(menu, buffer);
	Format(buffer, sizeof(buffer), "What's this?");
	AddMenuItem(menu, CHOICE4, buffer);
	Format(buffer, sizeof(buffer), "Toggle respawning in the neutral team. Enabled: %s", (PlayerEnabled[client]) ? "Yes" : "No");
	AddMenuItem(menu, CHOICE1, buffer);
	Format(buffer, sizeof(buffer), "Change your gravity while in the neutral team. Gravity: %.1f", CGravity[client]);
	AddMenuItem(menu, CHOICE3, buffer);
	Format(buffer, sizeof(buffer), "Take knockback from blast damage. Enabled: %s", (TakeBlast[client]) ? "Yes" : "No");
	AddMenuItem(menu, CHOICE2, buffer);
	if(IsValidClient && !IsPlayerAlive(client) && !InTeamN[client]) //Only dead and non-neutral players, fix an exploit
	{
		Format(buffer, sizeof(buffer), "Respawn me into the neutral team.");
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
				PlayerEnabled[client]=true; // Required.
				CreateTimer(0.1, Timer_Spawn, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE); //Use the plugin's own function.
			}
		}
	}
	return 0;
}

public GeneralInformation(client)
{
	new String:text[64];
	new Handle:panel=CreatePanel();
	Format(text, sizeof(text), "[TF2] Afterlife plugin");
	DrawPanelText(panel, text);
	Format(text, sizeof(text), "Version: %s Developed by %s", PLUGIN_VERSION, PLUGIN_AUTHOR);
	DrawPanelText(panel, text);
	Format(text, sizeof(text), "--------------------------------------------------");
	DrawPanelText(panel, text);
	Format(text, sizeof(text), "AfterLife is a Team Fortress 2 mod, which puts the");
	DrawPanelText(panel, text);
	Format(text, sizeof(text), "dead players in neutral team, where they respawn");
	DrawPanelText(panel, text);
	Format(text, sizeof(text), "and can do anything they want! But they cannot hurt");
	DrawPanelText(panel, text);
	Format(text, sizeof(text), "real team players. Also they are invisible for them.");
	DrawPanelText(panel, text);
	Format(text, sizeof(text), "Subplugins can give further functionalities to the plugin");
	DrawPanelText(panel, text);
	Format(text, sizeof(text), "Oh, also you can RPS or High-Five real players");
	DrawPanelText(panel, text);
	Format(text, sizeof(text), "Back");
	DrawPanelItem(panel, text);
	SendPanelToClient(panel, client, ExitButton, MENU_TIME_FOREVER);
	CloseHandle(panel);
}

public ExitButton(Handle:menu, MenuAction:action, client, selection)
{
	OptionsMenu(client);
	return 0;
}

public GravitySettings(client)
{
	//CacheCookieValues(client);
	new Handle:menu = CreateMenu(GravityHandler, MENU_ACTIONS_DEFAULT);
	SetMenuTitle(menu, "Your Gravity Multiplier: %.1f Default Server Gravity Multiplier: %.1f", CGravity[client], float(GetConVarInt(DGravity)/800));
	AddMenuItem(menu, CHOICE1, "+0.1");
	AddMenuItem(menu, CHOICE2, "-0.1");
	AddMenuItem(menu, CHOICE3, "Back");
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
			if(InTeamN[client])
			{
				ApplyGravityClient(client, CGravity[client]);
			}
			decl String:info[32];
			GetMenuItem(menu, param2, info, sizeof(info));
			if(StrEqual(CHOICE1, info, false))
			{
				CGravity[client]+=0.1;
				if(RoundToNearest(CGravity[client])>=VERYGRAVITY)
				{
					PrintToChat(client, "%s Warning: Your gravity multiplier is too high!!!",SMTAG);
				}
				GravitySettings(client);
			}
			else if(StrEqual(CHOICE2, info, false))
			{
				Debug("Client: %N CGravity: %f RoundNearest: %i RoundFloat: %i", client, CGravity[client], RoundToNearest(CGravity[client]), RoundFloat(CGravity[client]));
				if(CGravity[client]<=0.0 || RoundFloat(CGravity[client])<=0.0) //This is the end.
				{
					PrintToChat(client, "%s Sorry! You cannot go below zero. Capping to 0.0", SMTAG);
					CGravity[client]=0.0000000000000000001; //This value affects the prediction of the client!
				}
				else
				{
					CGravity[client]-=0.1;
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
	new String:value[25];
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
	if(!Enabled || GetRoundState()==2 || GetRoundState()==0)
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
		PrintToChat(deathplayer, "%s You will respawn in the Neutral Team after %i seconds!!", SMTAG, RespawnTime);
		CreateTimer(float(RespawnTime), Timer_Spawn, GetClientUserId(deathplayer), TIMER_FLAG_NO_MAPCHANGE);
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
	if(Arena_GetClientTeam(client)!=NTEAM) //Always know their team. Save their team even if they are not toggled to be from the neutral team.
	{
		LastTeam[client]=Arena_GetClientTeam(client);
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
			new ragdoll=GetEntPropEnt(i, Prop_Send, "m_hRagdoll");
			if(IsValidEntity(ragdoll))
			{
				RemoveEdict(ragdoll); // There is a reason to use RemoveEdict!
			}
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
	SetEntProp(client, Prop_Send, "m_lifeState", 2);
	ChangeClientTeam(client, LastTeam[client]);
	TF2_RespawnPlayer(client);
	RequestFrame(Frame_TestForLS, userid);
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
	}
	return Plugin_Continue;
}

public Action:Event_ObjectSapped(Handle:event, const String:name[], bool:dontBroadcast) // Goodbye sappers!
{
	if(!Enabled || !GetRoundState())
	{
		return Plugin_Continue;
	}
	
	new client = GetClientOfUserId(GetEventInt(event, "ownerid"));
	new spy = GetClientOfUserId(GetEventInt(event, "userid"));
	new sapper = GetEventInt(event, "sapperid");
	
	if(InTeamN[spy] && !InTeamN[client])
	{
		AcceptEntityInput(sapper, "Kill");
		return Plugin_Handled;
	}
	else if(!InTeamN[spy] && InTeamN[client])
	{
		AcceptEntityInput(sapper, "Kill");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:Event_OnObjectDeflected(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!Enabled || GetEventInt(event, "weaponid") || !GetRoundState())  //0 means that the client was airblasted
	{
		return Plugin_Continue;
	}
	new pushed=GetClientOfUserId(GetEventInt(event, "ownerid"));
	new pusher=GetClientOfUserId(GetEventInt(event, "userid"));
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
				PrintToChat(pusher, "%s Don't AIRBLAST real players!!!", SMTAG);
			}
		case 2:
			{
				KickClient(pusher, "You have been kicked for AIRBLASTING real players!!!");
			}
		default:
			{
				return Plugin_Handled;
			}
		}	
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
		Debug("Index: %i", enemy);
		if(InTeamN[enemy] && !InTeamN[index] && IsValidClient(enemy))
		{
			Debug("Sentry index: %i has target index %i", index, enemy);
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
	new Action:result;
	if(!Enabled || !IsValidClient(client))
	{
		return Plugin_Stop;
	}
	if(IsPlayerAlive(client)) //If the player is already alive, don't move them into the  neutral team.
	{
		PrintHintText(client, "You are alive. Respawning cancelled!");
		return Plugin_Stop;
	}

	if(GetRoundState()==0 || GetRoundState()==2) //Deny them to respawn when the round ends or setup timer for while.
	{
		if(GetRoundState()==2)
		{
			PrintHintText(client, "Round ended. Respawning cancelled!");
		}
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
	
	Call_StartForward(g_hNRespawn);
	Call_PushCell(client);
	Call_PushCell(ALFlags[client] & ALFLAG_NDEAD);
	Call_Finish(_:result);
	if(result==Plugin_Handled || result==Plugin_Stop)
	{
		return result;
	}
	
	
	if(PlayerEnabled[client])
	{
		InTeamN[client]=true;
		SetMeToOtherTeam(client);
		PrintToChat(client, "%s You have just respawned into the neutral team", SMTAG);
		RequestFrame(Frame_Teleport, GetClientUserId(client));
		CreateTimer(0.2, Timer_Info, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(0.1, Timer_CheckItems, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}

public Frame_Teleport(userid)
{
	new client=GetClientOfUserId(userid);
	if(!IsValidClient(client))
	{
		return;
	}
	TeleportToSpawn(client, GetRandomInt(2, 3));
}

public Action:Timer_Info(Handle:htimer, userid)
{
	new client=GetClientOfUserId(userid);
	if(!IsValidClient(client))
	{
		return Plugin_Stop;
	}
	PrintHintText(client, "To adjust your preferences, write !neutral in chat");
	return Plugin_Continue;
}

public Action:Timer_CheckItems(Handle:htimer, userid) //Filtering weapons.
{
	new client=GetClientOfUserId(userid);
	if(!IsValidClient(client) || !IsPlayerAlive(client))
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
		switch(itemindex) //Sniper's jarates was whitelisted in version 0.5.1
		{
		case 222, 1121: //Scout
			{
				TF2_RemoveWeaponSlot(client, i);
				TFWeapons_Giveweapon(client, 23, "tf_weapon_pistol", 1, 8); //Valve developer level.
				PrintToChat(client, "%s Your secondary weapon was stripped and replaced with a pistol!", SMTAG); 
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
		DispatchSpawn(entity);
		RequestFrame(Frame_RagdollCheck, EntIndexToEntRef(entity));
		return;
	}
	else if(StrEqual(classname, "tf_logic_arena", false)) // The plugin will load only on arena maps.
	{
		IsArenaFound=true;
		return;
	}
	SDKHook(entity, SDKHook_Spawn, Entity_SpawnPost);
}

public Frame_RagdollCheck(ref) // Wow, i can change ragdoll properties here! Do everything fast!
{
	new entity=EntRefToEntIndex(ref);
	//SetEntProp(entity, Prop_Send, "m_bGib", 0);
	//SetEntProp(entity, Prop_Send, "m_bGoldRagdoll", 1);
	//SetEntProp(entity, Prop_Send, "m_iTeam", GetRandomInt(2, 3));
	//SetEntProp(entity, Prop_Send, "m_bIceRagdoll", 1);
	if(!IsValidEntity(entity))
	{
		return;
	}
	if(GetEntProp(entity, Prop_Send, "m_iTeam")==NTEAM) //General functions
	{
		SetEntProp(entity, Prop_Send, "m_iTeam", GetRandomInt(2, 3));
		SetEntProp(entity, Prop_Send, "m_bGib", 0);
		SetEntProp(entity, Prop_Send, "m_bGoldRagdoll", 1);
		InTeamN[entity]=true; //Register anyway the entity
		RemoveEdict(entity);
		Debug("Ragdoll on neutral team!");
	}
	Debug("Ragdoll!! Team: %i", GetEntProp(entity, Prop_Send, "m_iTeam"));
}

public Action:Entity_SpawnPost(entity)
{
	if(!Enabled)
	{
		return Plugin_Continue;
	}
	new String:classname[64];
	new owner;
	if(!IsValidEdict(entity))
	{
		return Plugin_Continue;
	}
	GetEdictClassname(entity, classname, sizeof(classname));
	if(StrContains(classname, "tf_projectile_", false)>-1)
	{
		owner=GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		if(!IsValidEntity(owner))
		{
			return Plugin_Continue;
		}
		if(InTeamN[owner])
		{
			Debug("Entity classname: %s Entity index: %i Owner: %i", classname, entity, owner);
			if(IsValidClient(owner) && (ALFlags[owner] & ALFLAG_NOPROJCOLLIDE) && InTeamN[owner])
			{
				Debug("1. Object flagged with NoProjCollide");
				SDKHook(entity, SDKHook_Touch, Hook_OnProjectileTouch);
			}
			if(IsValidClient(owner) && (ALFlags[owner] & ALFLAG_INVISIBLE) && InTeamN[owner])
			{
				Debug("1. Object flagged with SetTransmit");
				SDKHook(entity, SDKHook_SetTransmit, Hook_Transmit);
			}
			GetEdictClassname(owner, classname, sizeof(classname));
			if(StrContains(classname, "obj_", false)>-1)
			{
				new owner2=GetEntPropEnt(owner, Prop_Send, "m_hBuilder");
				if(IsValidClient(owner2) && InTeamN[owner2])
				{
					Debug("2. Entity classname: %s Entity index: %i Owner: %i", classname, entity, owner);
					if(ALFlags[owner2] & ALFLAG_NOPROJCOLLIDE)
					{
						Debug("1. Object flagged with NoProjCollide");
						SDKHook(entity, SDKHook_Touch, Hook_OnProjectileTouch);
					}
					if(ALFlags[owner2] & ALFLAG_INVISIBLE)
					{
						Debug("1. Object flagged with SetTransmit");
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
			SetEntProp(entity, Prop_Send, "m_usSolidFlags", 22);
			InTeamN[entity]=true;
		}
		SDKHook(entity, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
	}
	/*
	else if(StrEqual(classname, "tf_taunt_prop", false))
	{
		Debug("TauntProp: %i", entity);
		Debug("InitTeamNum: %i TeamNum: %i", GetEntProp(entity, Prop_Data, "m_iInitialTeamNum"), GetEntProp(entity, Prop_Send, "m_iTeamNum"));
		CreateTimer(0.1, Timer_Data, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
		if(NTEAM)
		{
			SDKHook(entity, SDKHook_SetTransmit, Hook_Transmit);
			InTeamN[entity]=true;
		}
	}
	*/
	return Plugin_Continue;
}

/*
public Action:Timer_Data(Handle:htimer, ref) //Test
{
	new entity=EntRefToEntIndex(ref);
	if(!IsValidEntity(entity))
	{
		return;
	}
	Debug("TauntProp: %i InitTeamNum: %i TeamNum: %i", entity, GetEntProp(entity, Prop_Data, "m_iInitialTeamNum"), GetEntProp(entity, Prop_Data, "m_iTeamNum"));
}
*/

public OnEntityDestroyed(entity) //Deinitialize entity.
{
	if(entity<=MAXENTITIES && entity>MaxClients)
	{
		InTeamN[entity]=false;
	}
}

public Action:Timer_Announce(Handle:htimer) //To-do: More details and information
{
	if(!Enabled) //Changes
	{
		return Plugin_Stop;
	}
	switch(GetRandomInt(0, 5)) //Random
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
	if(!Enabled || !GetRoundState() || other<=0)
	{
		return Plugin_Continue;
	}
	if(!InTeamN[other] && InTeamN[entity])
	{
		new String:classname[64];
		GetEdictClassname(other, classname, sizeof(classname));
		if(StrContains(classname, "obj_", false)>-1 || IsValidClient(other))
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
	if(IsValidClient(entity) && !IsPlayerAlive(entity) && InTeamN[objs])
	{
		if(SpectatorCanSee)
		{
			return Plugin_Continue;
		}
		else
		{
			return Plugin_Handled;
		}
	}
	if(!InTeamN[entity] && InTeamN[objs])
	{
		if(!IsValidClient(objs))
		{
			return Plugin_Handled;
		}
		
		new item=-1;
		while((item=FindEntityByClassname2(item, "tf_wearable"))!=-1) // 1step. Scan every player wearable
		{
			if(GetEntPropEnt(item, Prop_Send, "m_hOwnerEntity")==objs)
			{
				if(GetEdictFlags(item) & FL_EDICT_ALWAYS)
				{
					Debug("Found FL_EDICT_ALWAYS on entity %i", item);
					Debug("Item def index: %i", GetEntProp(item, Prop_Send, "m_iItemDefinitionIndex"));
					SetEdictFlags(item, GetEdictFlags(item) ^ FL_EDICT_ALWAYS); //The flag is removed.
				}
			}
		}
		
		for(new i=0; i<=WSLOTS; i++) // 2step. Scan every player weapon
		{
			new weapon=GetPlayerWeaponSlot(objs, i); //Need to fix Heavy minigun. Need to remove the flag always transmit , or he will be visible.
			if(!IsValidEntity(weapon))
			{
				continue;
			}
			//Debug("Scanning slot %i of client %i", i, objs);
			if(GetEdictFlags(weapon) & FL_EDICT_ALWAYS)
			{
				Debug("Found FL_EDICT_ALWAYS on entity %i", weapon);
				Debug("Item def index: %i", GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"));
				SetEdictFlags(weapon, GetEdictFlags(weapon) ^ FL_EDICT_ALWAYS); //The flag is removed.
			}
		}
		
		if(ALFlags[objs] & ALFLAG_INVISIBLE)
		{
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action:Hook_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if(!Enabled)
	{
		return Plugin_Continue;
	}
	
	if(InTeamN[victim] && NoTriggerHurt && !IsValidClient(attacker)) //"and can do anything they want!" sentence is a promise
	{
		if(attacker>MaxClients) //This will be fixed further!
		{
			return Plugin_Handled;
		}
	}
	
	if(InTeamN[victim] && victim==attacker)
	{
		if(IsValidClient(victim) && TakeBlast[victim])
		{
			if(damagetype & DMG_BLAST) // Give a chance for the soldiers, demomans and pyros. Or for everyone with a rocket launcher
			{
				//damagetype|=DMG_NEVERGIB;
				ScaleVector(damageForce, 0.1); // Scale it
				TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, damageForce); // I want to them to jump.
				if(ALFlags[victim] & ALFLAG_TAKEDMG)
				{
					return Plugin_Changed;
				}
				else
				{
					damage=0.0;
					return Plugin_Changed; //return Plugin_Handled;
				}
			}
		}
		return Plugin_Handled;
	}
	
	if(InTeamN[victim] && InTeamN[attacker])
	{
		return Plugin_Continue;
	}

	if(InTeamN[victim] || InTeamN[attacker])
	{
		if(IsValidClient(victim) && IsValidClient(attacker) && InTeamN[attacker] && (ALFlags[attacker] & ALFLAG_DONTSTUN))
		{
			RequestFrame(Frame_RemoveStun, GetClientUserId(victim));
		}
		if(IsValidClient(victim) && !(ALFlags[victim] & ALFLAG_TAKEDMG) && InTeamN[victim])
		{
			return Plugin_Handled;
		}
		else if(IsValidClient(victim) && InTeamN[victim])
		{
			return Plugin_Continue;
		}
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Frame_RemoveStun(userid) //Remove stun from taunts!
{
	new client=GetClientOfUserId(userid);
	if(!IsValidClient(client))
	{
		return;
	}
	if(TF2_IsPlayerInCondition(client, TFCond_Dazed))
	{
		TF2_RemoveCondition(client, TFCond_Dazed);
	}
	return;
}

public Action:Hook_OnJarate(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable, bool:init) //The code is from Freak Fortress 1.10.6
{
	if(!Enabled || !GetRoundState())
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

SetMeToOtherTeam(client)
{
	if(!IsValidClient(client))
	{
		return -1;
	}
	ChangeClientTeam(client, NTEAM);
	Debug("Client: %N IsValidClient: %i IsPlayerAlive: %i Index: %i IsClientInGame: %i", client, IsValidClient(client), IsPlayerAlive(client), client, IsClientInGame(client));
	TF2_RespawnPlayer(client); // To-do: File a bug report!
	RequestFrame(Frame_TestForLS, GetClientUserId(client));
	SetEntProp(client, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);               // Set their collision group to debris but triggers.
	TF2_RegeneratePlayer(client); // Fix civilian bug, because of TF2Items!
	CreateTimer(0.1, Timer_SetGravity, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	return 1;
}

SetMeToMyTeam(client)
{
	if(!IsValidClient(client))
	{
		return -1;
	}
	RequestFrame(Frame_TestForLS, GetClientUserId(client));
	ApplyGravityClient(client, float(GetConVarInt(DGravity)/800)); // Note: This is a handle to the current value of the gravity of the server convar!
	SetEntProp(client, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_PLAYER); // Set their normal collision.
	return 1;
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
		ApplyGravityClient(client, float(GetConVarInt(DGravity)/800));
	}
	return Plugin_Continue;
}

public Action:TF2_OnPlayerTeleport(client, teleporter, &bool:result)
{
	if(!Enabled || !GetRoundState())
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
		return Plugin_Changed;
	}
	return Plugin_Continue;
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
				Debug("Emitted sound. Entity: %i Client: %N Sample: %s", entity, clients[i], sound);
				clients[i]=0; // Exception
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}

public Frame_TestForLS(userid)
{
	new client=GetClientOfUserId(userid);
	if(!IsValidClient(client))
	{
		return;
	}
	LivingSpectatorTest(client);
	return;
}

/*                                    Natives                                    */
public Native_IsEnabled(Handle:plugin, numParams)
{
	return _:Enabled;
}

public Native_IsPlayerEnabled(Handle:plugin, numParams)
{
	new client=GetNativeCell(1);
	if(!IsValidClient(client))
	{
		return false;
	}
	return _:PlayerEnabled[client];
}

public Native_SetPlayerInNeutral(Handle:plugin, numParams)
{
	new client=GetNativeCell(1);
	new bool:option=GetNativeCell(2);
	if(!IsValidClient(client))
	{
		return -1;
	}
	PlayerEnabled[client]=option;
	return 1;
}

public Native_IsInNeutralTeam(Handle:plugin, numParams)
{
	return _:InTeamN[GetNativeCell(1)];
}

public Native_GetGravityNeutral(Handle:plugin, numParams)
{
	new client=GetNativeCell(1);
	if(!IsValidClient(client))
	{
		return -1;
	}
	return _:CGravity[client];
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
	if(GetEngineVersion()==Engine_TF2)
	{
		return true;
	}
	else
	{
		SetFailState("[SM] This plugin is only for Team Fortress 2. Remove the plugin now!");
		return false;
	}
}

TeleportToSpawn(iClient, iTeam = 0) //Chdata and VS SAXTON HALE 1.53
{
	new iEnt = -1;
	decl Float:vPos[3];
	decl Float:vAng[3];
	new Handle:hArray = CreateArray();
	while ((iEnt = FindEntityByClassname2(iEnt, "info_player_teamspawn")) != -1)
	{
		if (iTeam <= 1) // Not RED (2) nor BLu (3)
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

FindEntityByClassname2(startEnt, const  String:classname[]) //From VS SAXTON HALE
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

bool:LivingSpectatorTest(client)
{
	if(!IsValidClient(client))
	{
		return false;
	}
	if(GetEntProp(client, Prop_Send, "m_iObserverMode") && IsPlayerAlive(client))
	{
		PrintToChat(client, "%s You are a living spectator!!", SMTAG);
		PrintToChat(client, "%s Don't worry. It will be fixed now.", SMTAG);
		SetEntProp(client, Prop_Send, "m_lifeState", 2);
		if(TF2_GetPlayerClass(client)==TFClass_Unknown)
		{
			PrintToChat(client, "%s You don't have a class assigned");
			TF2_SetPlayerClass(client, TFClassType:GetRandomInt(1, 9));
		}
		TF2_RespawnPlayer(client); // To-do: File a bug report!
		return true;
	}
	return false;
}

SetNoTarget(ent, bool:apply) //From Friendly Mode
{
	new flags;
	if(apply)
	{
		flags = GetEntityFlags(ent)|FL_NOTARGET;
	}
	else
	{
		flags = GetEntityFlags(ent)&~FL_NOTARGET;
	}
	SetEntityFlags(ent, flags);
}

Arena_GetClientTeam(entity) //Also works on entities!
{
	return GetEntProp(entity, Prop_Send, "m_iTeamNum");
}


Float:ApplyGravityClient(client, Float:gravity)
{
	if(!IsValidClient(client))
	{
		return -1.0;
	}
	SetEntityGravity(client, gravity); 
	return gravity;
}

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

/*
	Return values:
	!GetRoundState == The round has not started
	(GetRoundState==2) == When the round ended 
	!(GetRoundState==2) == When the round is running or not started
*/