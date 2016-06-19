/*
			Welcome to the source code of the "[TF2] Neutral Team Mode" plugin (Previous names: Afterlife, Second Dimension).
			Version: 1.1.1 | Public gamemode plugin | Stable
			Inspired from Ghost Mode Redux by ReFlexPoison.
			Sourcemod forum page: *none*
			Github development page: https://github.com/naydef/Afterlife-plugin
			Minimum Requirements:
			Sourcemod >=1.6.0,
			SDKHooks 2.1,
			TFWeapons include file
			Maybe will be changed to use TF2Items
*/
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <clientprefs>
#include <tfweapons2> //My own give weapon include
#include <neutralteam_plugin>

#define PLUGIN_VERSION "1.1.1"
#define PLUGIN_AUTHOR "Naydef"

//Defines
#define VERYGRAVITY 10.0
#define MAXENTITIES 2048
#define NTEAM       TFTeam_Unassigned                // The Neutral team number, which is 0.
#define WSLOTS      6                                 // Max weapon slots

// Some sounds!
#define SOUND_SAPPER_NOISE      "weapons/sapper_timer.wav"
#define SOUND_SAPPER_NOISE2     "player/invulnerable_off.wav"
#define SOUND_SAPPER_PLANT      "weapons/sapper_plant.wav"

//Creating variables and etc
new NTFlags[MAXPLAYERS+1];                            // Player Flags. Make it like Freak Fortress 2. 

new bool:InTeamN[MAXENTITIES+1];                       // Registers entities which are in the Neutral team at the moment.
new TFTeam:LastTeam[MAXPLAYERS+1];                    // Last team of the player
new i_Collision[MAXPLAYERS+1];

new Handle:cvarEnabled;               // Plugin Enabled by user
new Handle:cvarDebug;                 // Debug cvar
new Handle:cvarAnnounceTime;         // Announce time delay
new Handle:cvarRespawnDelay;         // Respawn delay
new Handle:cvarPlayerTeleport;       // Allow neutral team to use teleporters of the playing team.
new Handle:cvarNoTriggerHurt;        // No trigger_hurt for the neutral team!
new Handle:cvarPunishment;
new Handle:cvarPluginSilence;
new Handle:cvarSolidTP;
new Handle:cvarBlockBlood;
new Handle:cvarGravMenu;
new Handle:cvarPopupMenu;
new Handle:cvarnoPickups;
new Handle:DGravity;                  // Set the gravity of the player.
new Handle:RTimer[MAXPLAYERS];        // Fix respawn timer bypass exploit

new bool:UserPluginEnabled;          // Control variable for cvar
new bool:Enabled;                     // Variable for enabled plugin
new bool:DebugEnabled;               // Debug message enabler cvar
new bool:AllowNeutralTP;
new bool:NoTriggerHurt;
new bool:IsArenaFound;
new bool:PluginSilence;
new bool:SolidTP;
new bool:BlockBlood;
new bool:GravMenu;
new bool:PopupMenu;
new bool:noPickups;
new bool:PlayerEnabled[MAXPLAYERS+1];
new bool:TakeBlast[MAXPLAYERS+1];                    // Can they take blast force.
new bool:askMeN[MAXPLAYERS+1];
new Float:CGravity[MAXPLAYERS+1];                    // Current gravity.
new Float:AnnounceTime;
new RespawnTime;                                     //This doesn't need to be a float number
new SapBlastPunish;

//Cookie handles
new Handle:g_hCookieGravity;
new Handle:g_hCookieEnabled;
new Handle:g_hCookieBlastSelf;
new Handle:g_hCookieAskMeNTeam;

//Global forwards
new Handle:g_hNRespawn;
new Handle:g_hNRespawnPost;

public Plugin:myinfo =
{
	name = "[TF2] Neutral Team Mode", 
	author = PLUGIN_AUTHOR,
	description = "When a player dies, it will be respawned in the neutral team",
	version = PLUGIN_VERSION,
	url = "https://github.com/naydef/Afterlife-plugin"
};

public OnPluginStart()
{
	LogMessage("Neutral Team Mode plugin loading!!!");
	LoadTranslations("common.phrases");
	LoadTranslations("neutral.phrases");
	RegConsoleCmd("sm_neutral", Command_ScreenMenu, "Toggle the options menu to yourself.");
	RegAdminCmd("al_toggle", Command_TogglePlayer, ADMFLAG_CHEATS, "Toggle respawning in the neutral team to someone");
	CreateConVar("neutralmode_version", PLUGIN_VERSION, "Neutral Team Mode version cvar", FCVAR_NOTIFY|FCVAR_SPONLY|FCVAR_DONTRECORD);
	cvarEnabled=CreateConVar("al_enabled", "1", "1- The plugin is enabled 0- The plugin is disabled: Are you sure?", _, true, 0.0, true , 1.0);
	cvarDebug=CreateConVar("al_debug", "0", "Enable debug messages.", _, true, 0.0, true , 1.0);
	cvarAnnounceTime=CreateConVar("al_announce_time", "145", "Amount of seconds to wait until AL info is displayed again | 0-disable it", _, true, 0.0);
	cvarRespawnDelay=CreateConVar("al_respawn_time", "7", "Seconds before the player respawns. Minimum delay: 1 second", _, true, 1.0);
	cvarPlayerTeleport=CreateConVar("al_neutral_tp", "1", "1- Allow the neutral team to use playing team teleporters | 0-Otherwise ", _, true, 0.0, true, 1.0);
	cvarNoTriggerHurt=CreateConVar("al_notrhurt", "1", "1- No damage from the map except fall damage | 0-Otherwise!", _, true, 0.0, true, 1.0);
	cvarPunishment=CreateConVar("al_airandsap_punishment", "1", "Airblast and Sap attempt punishment 0- Nothing 1-Warning message 2-Kick the player");
	cvarPluginSilence=CreateConVar("al_plugin_silence", "1", "1-Other plugins will not detects some common player events like respawning or gettting new set of weapons. Recommended for servers, which their bosses have long lastman music (Freak Fortress 2) | 0-Otherwise", _, true, 0.0, true, 1.0);
	cvarSolidTP=CreateConVar("al_solidtp", "1", "1-Teleporters will be solid, as in the game | 0-Teleporters will be made as the sentries and the dispensers", _, true, 0.0, true, 1.0);
	cvarBlockBlood=CreateConVar("al_blockblood", "1", "1-No blood will be emitted by the neutral team | 0-Otherwise", _, true, 0.0, true, 1.0);
	cvarGravMenu=CreateConVar("al_gravmenu", "1", "1-The gravity menu is enabled | 0-The menu is disabled", _, true, 0.0, true, 1.0);
	cvarPopupMenu=CreateConVar("al_popupmenu", "1", "1-Menu for selection spawn preferences is enabled | 0-The menu is disabled", _, true, 0.0, true, 1.0);
	cvarnoPickups=CreateConVar("al_nopickups", "0", "1-The players won't be able to pick up health/ammo packs and etc. | 0-The menu is disabled", _, true, 0.0, true, 1.0);
	HookConVarChange(cvarEnabled, CvarChange);
	HookConVarChange(cvarDebug, CvarChange);
	HookConVarChange(cvarAnnounceTime, CvarChange);
	HookConVarChange(cvarRespawnDelay, CvarChange);
	HookConVarChange(cvarPlayerTeleport, CvarChange);
	HookConVarChange(cvarNoTriggerHurt, CvarChange);
	HookConVarChange(cvarPunishment, CvarChange);
	HookConVarChange(cvarPluginSilence, CvarChange);
	HookConVarChange(cvarSolidTP, CvarChange);
	HookConVarChange(cvarBlockBlood, CvarChange);
	HookConVarChange(cvarGravMenu, CvarChange);
	HookConVarChange(cvarPopupMenu, CvarChange);
	HookConVarChange(cvarnoPickups, CvarChange);

	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
	HookEvent("teamplay_round_start", Event_OnRoundStart, EventHookMode_Post);
	HookEvent("post_inventory_application", Event_OnPostInvertory, EventHookMode_Pre);
	HookEvent("player_sapped_object", Event_ObjectSapped, EventHookMode_Pre);
	HookEvent("object_deflected", Event_OnObjectDeflected, EventHookMode_Pre);
	
	HookUserMessage(GetUserMessageId("PlayerJarated"), Hook_OnJarate); //OK, this is from Freak Fortress 2 1.10.6
	
	AddCommandListener(CallBack_Jointeam, "jointeam");
	AddCommandListener(CallBack_JoinClass, "changeclass");
	AutoExecConfig(true, "NeutralTeamMode");
	AddNormalSoundHook(Hook_EntitySound);
	
	//Hook many tempents!!
	AddTempEntHook("TFBlood", Hook_TempEntHook);
	AddTempEntHook("Blood Sprite", Hook_TempEntHook);
	AddTempEntHook("Blood Stream", Hook_TempEntHook);
	
	// Cookies are old-named. Save previous data!
	g_hCookieGravity = RegClientCookie("afterlife_gravity_cookie", "AGC", CookieAccess_Public);
	g_hCookieEnabled = RegClientCookie("afterlife_enabled_cookie", "AEC", CookieAccess_Public);
	g_hCookieBlastSelf = RegClientCookie("afterlife_blast_cookie", "ABC", CookieAccess_Public);
	g_hCookieAskMeNTeam = RegClientCookie("afterlife_askmenteam_cookie", "AAC", CookieAccess_Public);
	
	for(new i=1; i<=MaxClients; i++) //Full compatibility in case of late load.
	{
		if(IsValidClient(i))
		{
			OnClientPutInServer(i);
			if(AreClientCookiesCached(i))
			{
				OnClientCookiesCached(i);
			}
			if(!InTeamN[i] && Arena_GetClientTeam(i)!=NTEAM)
			{
				LastTeam[i]=Arena_GetClientTeam(i);
			}
			ScreenMenuChoice(i);
		}
	}
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	if(!IsTF2())
	{
		strcopy(error, err_max, "This plugin is only for the game Team Fortress 2. Remove the plugin please!");
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
	
	RegPluginLibrary("neutralmode_plugin");
	RegPluginLibrary("afterlife_plugin"); //Retain compatibility with still existing subplugins
	
	//Forwards
	g_hNRespawn=CreateGlobalForward("AL_OnNeutralRespawn", ET_Event, Param_Cell, Param_Cell, Param_CellByRef);
	g_hNRespawnPost=CreateGlobalForward("AL_OnNeutralRespawnPost", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	return APLRes_Success;
}

public OnConfigsExecuted()
{
	SyncConVarValues();
	EnableAL();
}

public SyncConVarValues()
{
	//Cache the cvars.
	UserPluginEnabled=bool:GetConVarBool(cvarEnabled);
	DebugEnabled=bool:GetConVarBool(cvarDebug);
	AnnounceTime=Float:GetConVarFloat(cvarAnnounceTime);
	RespawnTime=GetConVarInt(cvarRespawnDelay);
	AllowNeutralTP=bool:GetConVarBool(cvarPlayerTeleport);
	NoTriggerHurt=bool:GetConVarBool(cvarNoTriggerHurt);
	SapBlastPunish=GetConVarInt(cvarPunishment);
	PluginSilence=bool:GetConVarBool(cvarPluginSilence);
	SolidTP=bool:GetConVarBool(cvarSolidTP);
	BlockBlood=bool:GetConVarBool(cvarBlockBlood);
	GravMenu=bool:GetConVarBool(cvarGravMenu);
	PopupMenu=bool:GetConVarBool(cvarPopupMenu);
	noPickups=bool:GetConVarBool(cvarnoPickups);
}

public OnPluginEnd()
{
	DisableAL();
}

public OnMapStart()
{
	DGravity=FindConVar("sv_gravity");
}

public CvarChange(Handle:cvar, const String:oldVal[], const String:newVal[]) //To-do: Use newVal value to set the variables and try to remove this
{
	if(cvar==cvarEnabled)
	{
		UserPluginEnabled=bool:StringToInt(newVal);
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
	else if(cvar==cvarDebug)
	{
		DebugEnabled=bool:StringToInt(newVal);
	}
	else if(cvar==cvarAnnounceTime)
	{
		AnnounceTime=Float:StringToFloat(newVal);
	}
	else if(cvar==cvarRespawnDelay)
	{
		RespawnTime=StringToInt(newVal);
	}
	else if(cvar==cvarPlayerTeleport)
	{
		AllowNeutralTP=bool:StringToInt(newVal);
	}
	else if(cvar==cvarNoTriggerHurt)
	{
		NoTriggerHurt=bool:StringToInt(newVal);
	}
	else if(cvar==cvarPunishment)
	{
		SapBlastPunish=StringToInt(newVal);
	}
	else if(cvar==cvarPluginSilence)
	{
		PluginSilence=bool:StringToInt(newVal);
	}
	else if(cvar==cvarSolidTP)
	{
		SolidTP=bool:StringToInt(newVal);
	}
	else if(cvar==cvarBlockBlood)
	{
		BlockBlood=bool:StringToInt(newVal);
	}
	else if(cvar==cvarGravMenu)
	{
		GravMenu=bool:StringToInt(newVal);
	}
	else if(cvar==cvarPopupMenu)
	{
		PopupMenu=bool:StringToInt(newVal);
	}
	else if(cvar==cvarnoPickups)
	{
		noPickups=bool:StringToInt(newVal);
	}
}

public EnableAL()
{
	new entity = -1;
	while((entity=FindEntityByClassname2(entity, "tf_logic_arena"))!=-1)
	{
		IsArenaFound=true;
		break;
	}
	(UserPluginEnabled) ? ((IsArenaFound) ? (Enabled=true) : (Enabled=false)) : (Enabled=false);
	if(!Enabled)
	{
		LogMessage("The current map is not arena map! Disabling plugin!");
		SetFailState("The current map is not arena map! Disabling plugin!");
		return; //The plugin will not continue!
	}
	
	if(AnnounceTime>0.0)
	{
		CreateTimer(AnnounceTime, Timer_Announce, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE); //Self-Advertising. With a specified time
	}
}

public DisableAL()
{
	LogMessage("Neutral Team Mode plugin unloading!!!");
	for(new i=1; i<=MaxClients; i++)
	{
		if(IsValidClient(i) && InTeamN[i])
		{
			SetMeToMyTeam(i, false);
			OnClientDisconnect(i);
		}
	}
	Enabled=false; //For future safety!
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, Hook_TakeDamage);
	SDKHook(client, SDKHook_SetTransmit, Hook_Transmit);
}

public OnClientDisconnect(client)
{
	SaveCookieValues(client);
	InTeamN[client]=false;
	PlayerEnabled[client]=false;
	askMeN[client]=false;
	NTFlags[client]=0;
}

public OnClientCookiesCached(client)
{
	new String:sValue[16];
	GetClientCookie(client, g_hCookieGravity, sValue, sizeof(sValue));
	(sValue[0]=='\0') ? (CGravity[client]=1.0) : (CGravity[client]=StringToFloat(sValue));
	GetClientCookie(client, g_hCookieBlastSelf, sValue, sizeof(sValue));
	(sValue[0]=='\0') ? (TakeBlast[client]=true) : (TakeBlast[client]=bool:StringToInt(sValue));
	GetClientCookie(client, g_hCookieAskMeNTeam, sValue, sizeof(sValue));
	(sValue[0]=='\0') ? (askMeN[client]=true) : (askMeN[client]=bool:StringToInt(sValue));
}

public Action:CallBack_Jointeam(client, const String:command[], argc)
{
	if(!Enabled || !IsValidClient(client) || IsFakeClient(client) || !PopupMenu || !askMeN[client])
	{
		return Plugin_Continue;
	}
	ScreenMenuChoice(client);
	return Plugin_Continue;
}

public Action:CallBack_JoinClass(client, const String:command[], argc)
{
	if(!Enabled || !IsValidClient(client) || IsFakeClient(client))
	{
		return Plugin_Continue;
	}
	
	AL_Debug("Executed %s for %N", command, client);
	if(InTeamN[client] && !IsPlayerAlive(client))
	{
		AL_Debug("Valid!");
		(LastTeam[client]==TFTeam_Red) ? ShowVGUIPanel(client, "class_red") : ShowVGUIPanel(client, "class_blue");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public ScreenMenuChoice(client)
{
	new String:buffer[128];
	SetGlobalTransTarget(client);
	new Handle:menu = CreateMenu(AfterLifeMenuHandler, MENU_ACTIONS_DEFAULT);
	SetMenuTitle(menu, "%t", "T_StartChoice");

	new String:sValue[12];
	GetClientCookie(client, g_hCookieEnabled, sValue, sizeof(sValue));
	if(!(sValue[0]=='\0'))
	{
		Format(buffer, sizeof(buffer), "%t", "T_MyDPref");
		AddMenuItem(menu, "1", buffer);
	}
	Format(buffer, sizeof(buffer), "%t", "Yes");
	AddMenuItem(menu, "2", buffer);
	Format(buffer, sizeof(buffer), "%t", "No");
	AddMenuItem(menu, "3", buffer);
	DisplayMenu(menu, client, 50);
}

public AfterLifeMenuHandler(Handle:menu, MenuAction:action, client, param2)
{
	switch(action)
	{
	case MenuAction_Select:
		{
			new String:info[2];
			GetMenuItem(menu, param2, info, sizeof(info));
			switch(info[0])
			{
			case '1':
				{
					new String:value[3];
					GetClientCookie(client, g_hCookieEnabled, value, sizeof(value));
					PlayerEnabled[client]=bool:StringToInt(value);
				}
			case '2':
				{
					PlayerEnabled[client]=true;
				}
			case '3':
				{
					PlayerEnabled[client]=false;
				}
			}
			(PlayerEnabled[client]) ? PrintToChat(client, "%s %t", SMTAG, "T_WillRespawn") : PrintToChat(client, "%s %t", SMTAG, "T_NoRespawn");
			PrintToChat(client, "%s %t", SMTAG, "T_InfoChange");
		}
	case MenuAction_Cancel:
		{
			if(param2==MenuCancel_Disconnected)
			{
				return 0;
			}
			new String:sValue[10];
			GetClientCookie(client, g_hCookieEnabled, sValue, sizeof(sValue));
			(sValue[0]=='\0') ? (PlayerEnabled[client]=true) : (PlayerEnabled[client]=bool:StringToInt(sValue));
			(PlayerEnabled[client]) ? PrintToChat(client, "%s %t", SMTAG, "T_WillRespawn") : PrintToChat(client, "%s %t", SMTAG, "T_NoRespawn");
			PrintToChat(client, "%s %t", SMTAG, "T_InfoChange");
		}
	case MenuAction_End:
		{
			AL_Debug("23. Closing handle for client %N", client);
			CloseHandle(menu);
		}
	}
	return 0;
}

public Action:Command_TogglePlayer(client, args)
{
	if(args<2)
	{
		ReplyToCommand(client, "Example: al_toggle <target> <1/0>");
		return Plugin_Handled;
	}
	new String:arg1[32];
	new String:arg2[8];
	new bool:enabled;
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	enabled=bool:StringToInt(arg2);
	
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
	ReplyToCommand(client, "%s You toggled respawning of %s to %i", SMTAG, target_name, enabled); // This is not finished!
	ShowActivity2(client, "[AL] Toggled %s with value %i", target_name, enabled);
	return Plugin_Handled;
}

public Action:Command_ScreenMenu(client, args)
{
	if(!Enabled)
	{
		return Plugin_Continue;
	}
	
	if(!IsValidClient(client) || IsFakeClient(client))
	{
		PrintToServer("[AL] Server/Bot cannot run this command!"); //Apparently, bot cannot joint team 0 and 1. 
		return Plugin_Handled;
	}
	OptionsMenu(client);
	return Plugin_Handled;
}

public OptionsMenu(client)
{
	new Handle:menu=CreateMenu(OptionHandler, MENU_ACTIONS_DEFAULT);
	SetGlobalTransTarget(client);
	decl String:buffer[256];
	Format(buffer, sizeof(buffer), "%t", "T_TPreferences");
	SetMenuTitle(menu, buffer);
	Format(buffer, sizeof(buffer), "%t", "T_WThis");
	AddMenuItem(menu, "1", buffer);
	Format(buffer, sizeof(buffer), "%t %s", "T_CRPreferences", (PlayerEnabled[client]) ? "[X]" : "[ ]");
	AddMenuItem(menu, "2", buffer);
	Format(buffer, sizeof(buffer), "%t %.1f", "T_CGravity", CGravity[client]);
	AddMenuItem(menu, "3", buffer);
	Format(buffer, sizeof(buffer), "%t", "T_BlastKnockBack", (TakeBlast[client]) ? "[X]" : "[ ]");
	AddMenuItem(menu, "4", buffer);
	Format(buffer, sizeof(buffer), "%t %s", "T_YouAsked", (askMeN[client]) ? "[X]" : "[ ]");
	AddMenuItem(menu, "5", buffer);
	if(IsValidClient(client) && IsLegidToSpawn(client)) //Only dead and non-neutral players, fix an exploit
	{
		Format(buffer, sizeof(buffer), "%t", "T_RespawnMe");
		AddMenuItem(menu, "6", buffer);
	}
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public OptionHandler(Handle:menu, MenuAction:action, client, param2)
{
	switch(action)
	{
	case MenuAction_Select:
		{
			new String:choice[4];
			GetMenuItem(menu, param2, choice, sizeof(choice));
			switch(StringToInt(choice))
			{
			case 1:
				{
					GeneralInformation(client);
				}
			case 2:
				{
					ScreenMenuChoice(client);
				}
			case 3:
				{
					GravitySettings(client);
				}
			case 4:
				{
					TakeBlast[client]=!TakeBlast[client];
					OptionsMenu(client);
				}
			case 5:
				{
					askMeN[client]=!askMeN[client];
					OptionsMenu(client);
				}
			case 6:
				{
					if(IsLegidToSpawn(client))
					{
						//PlayerEnabled[client]=true; // Not more required!
						if(Arena_GetClientTeam(client)!=NTEAM && !InTeamN[client]) // Save their previous team!
						{
							LastTeam[client]=Arena_GetClientTeam(client);
						}
						CreateTimer(0.1, Timer_Spawn, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE); //Use the plugin's own function.
					}
				}
			}
		}
	case MenuAction_End:
		{
			AL_Debug("Menu Handle destroyed for client %N", client);
			CloseHandle(menu);
		}
	}
	return 0;
}

public GeneralInformation(client)
{
	decl String:text[2048]; // This is enough big!
	new Handle:panel=CreatePanel();
	SetGlobalTransTarget(client);
	Format(text, sizeof(text), "%t", "T_PlIntro", PLUGIN_VERSION, PLUGIN_AUTHOR);
	DrawPanelText(panel, text);
	Format(text, sizeof(text), "%t", "Back");
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
	if(!GravMenu)
	{
		PrintToChat(client, "%s %t", SMTAG, "T_NoGravMenu");
		return 0;
	}
	SetGlobalTransTarget(client);
	new String:buffer[64];
	new Handle:panel=CreatePanel();
	Format(buffer, sizeof(buffer), "%t", "T_GChange", CGravity[client], float(GetConVarInt(DGravity))/800.0);
	SetPanelTitle(panel, buffer);
	DrawPanelItem(panel, "+0.1");
	DrawPanelItem(panel, "-0.1");
	Format(buffer, sizeof(buffer), "%t", "Back");
	DrawPanelItem(panel, buffer);
	SendPanelToClient(panel, client, GravityHandler, MENU_TIME_FOREVER);
	CloseHandle(panel);
	return 0;
}

public GravityHandler(Handle:menu, MenuAction:action, client, selection)
{
	switch(action)
	{
	case MenuAction_Select:
		{
			switch(selection)
			{
			case 1:
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
			case 2:
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
			case 3:
				{
					OptionsMenu(client);
				}
			}
		}
	}
	return 0;
}

SaveCookieValues(client)
{
	new String:value[10];
	IntToString(TakeBlast[client], value, sizeof(value));
	SetClientCookie(client, g_hCookieBlastSelf, value);
	FloatToString(CGravity[client], value, sizeof(value));
	SetClientCookie(client, g_hCookieGravity, value);
	IntToString(PlayerEnabled[client], value, sizeof(value));
	SetClientCookie(client, g_hCookieEnabled, value);
	IntToString(askMeN[client], value, sizeof(value));
	SetClientCookie(client, g_hCookieAskMeNTeam, value);
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
		SetMeToMyTeam(deathplayer, true);
		InTeamN[deathplayer]=false;
		return Plugin_Continue;
	}
	if(PlayerEnabled[deathplayer])
	{
		PrintToChat(deathplayer, "%s %t", SMTAG, "T_YouRespawn", RespawnTime);
		RTimer[deathplayer]=CreateTimer(float(RespawnTime), Timer_Spawn, GetClientUserId(deathplayer), TIMER_FLAG_NO_MAPCHANGE);
		if(InTeamN[deathplayer])
		{
			NTFlags[deathplayer]|=ALFLAG_NDEAD;
			return (PluginSilence) ? Plugin_Stop : Plugin_Handled; // Freak Fortress 2 and VSH thing
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
		i_Collision[client]=GetEntProp(client, Prop_Send, "m_CollisionGroup");
		LastTeam[client]=Arena_GetClientTeam(client);
	}
	if(InTeamN[client]) //Force stop announcing to another plugins for respawned player (Freak Fortress 2 and VSH related)!
	{
		SetEventBroadcast(event, false);
		return (PluginSilence) ? Plugin_Stop : Plugin_Handled; // Freak Fortress 2 and VSH will not detect respawns any more!
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
	SetMeToMyTeam(client, false);
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
	
	if(InTeamN[spy] && !InTeamN[client])
	{
		new String:buffer[128];
		SetGlobalTransTarget(spy);
		switch(SapBlastPunish)
		{
		case 1: 
			{
				Format(buffer, sizeof(buffer), "%t", "T_NoSap");
				CreateTFStypeMessage(spy, buffer, "ico_ghost", 2);
			}
		case 2:
			{
				KickClient(spy, "%t", "T_KickNoSap"); // Is this enough brutal?
			}
		case 0:
			{
				//Nothing?
			}
		}
		SetEventBroadcast(event, false);
		InTeamN[sapper]=true;
		AcceptEntityInput(sapper, "Disable");
		AcceptEntityInput(sapper, "Kill");
		return (PluginSilence) ? Plugin_Stop : Plugin_Handled; // Freak Fortress 2 and VSH thing
	}
	return Plugin_Continue;
}

public Action:Event_OnObjectDeflected(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!Enabled)
	{
		return Plugin_Continue;
	}
	new pusher = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!GetEventInt(event, "weaponid"))
	{
		new pushed = GetClientOfUserId(GetEventInt(event, "ownerid"));
		if(!IsValidClient(pushed) || !IsValidClient(pusher))
		{
			return Plugin_Continue;
		}
		if(InTeamN[pusher] && !InTeamN[pushed] && !(NTFlags[pusher] & ALFLAG_CANAIRBLAST))
		{
			new Float:Vel[3]; //This from the forum.
			TeleportEntity(pushed, NULL_VECTOR, NULL_VECTOR, Vel); // Stops knockback
			TF2_RemoveCondition(pushed, TFCond_Dazed); // Stops slowdown
			SetEntPropVector(pushed, Prop_Send, "m_vecPunchAngle", Vel);
			SetEntPropVector(pushed, Prop_Send, "m_vecPunchAngleVel", Vel); // Stops screen shake 
			switch(SapBlastPunish)
			{
			case 1: 
				{
					new String:buffer[64];
					Format(buffer, sizeof(buffer), "%t", "T_NoAIR");
					CreateTFStypeMessage(pusher, buffer, "ico_ghost", 2);
				}
			case 2:
				{
					KickClient(pusher, "%t", "T_KickNoAir");
				}
			case 0:
				{
					//Nothing?
				}
			}
			SetEventBroadcast(event, false);
			return (PluginSilence) ? Plugin_Stop : Plugin_Handled; // Freak Fortress 2 and VSH will not detect airblasts any more!
		}
	}
	return Plugin_Continue;
}

// I don't think this is necessary!
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
	
	RTimer[client]=INVALID_HANDLE;
	if(GetRoundState()==0 || GetRoundState()==2) //Deny them to respawn when the round ends or setup timer for while.
	{
		return Plugin_Stop;
	}

	if(NTFlags[client] & ALFLAG_NDEAD)
	{
		NTFlags[client] &=~ ALFLAG_NDEAD;
	}
	
	if(PlayerEnabled[client])
	{
		new Action:result;
		new flags;
		flags=NTFlags[client];
		Call_StartForward(g_hNRespawn);
		Call_PushCell(client);
		Call_PushCell(NTFlags[client] & ALFLAG_NDEAD);
		Call_PushCellRef(flags);
		Call_Finish(_:result);
		if(result==Plugin_Handled || result==Plugin_Stop)
		{
			return result;
		}
		if(result==Plugin_Changed)
		{
			NTFlags[client]=flags;
		}
		
		Call_StartForward(g_hNRespawnPost); // The post forward
		Call_PushCell(client);
		Call_PushCell(NTFlags[client] & ALFLAG_NDEAD);
		Call_PushCell(flags);
		Call_Finish();
		
		SetGlobalTransTarget(client);
		if(!InTeamN[client])
		{
			InTeamN[client]=true;
			NTFlags[client]=ALFLAGS_GENERAL;
		}
		
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
	if(!(NTFlags[client] & ALFLAG_CHECKITEMS) || !InTeamN[client])
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
		switch(GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex")) // Sniper's jarates was whitelisted in version 0.5.1
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
			if(InTeamN[i] && (NTFlags[i] & ALFLAL_NORAGDOLL))
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
	new owner;
	decl String:classname[64];
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
		if(StrEqual(classname, "tf_projectile_pipe_remote", false) && !InTeamN[owner]) //Let's hook the remote pipebombs because neutral team players can destroy them! 
		{
			SDKHook(entity, SDKHook_OnTakeDamage, Hook_TakeDamage);
		}
		if(InTeamN[owner])
		{
			if(IsValidClient(owner) && (NTFlags[owner] & ALFLAG_NOPROJCOLLIDE))
			{
				SDKHook(entity, SDKHook_Touch, Hook_OnEntityTouch);
			}
			if(IsValidClient(owner) && (NTFlags[owner] & ALFLAG_INVISIBLE))
			{
				SDKHook(entity, SDKHook_SetTransmit, Hook_Transmit);
			}
			GetEntityClassname(owner, classname, sizeof(classname));
			if(StrContains(classname, "obj_", false)>-1)
			{
				new owner2=GetEntPropEnt(owner, Prop_Send, "m_hBuilder");
				if(IsValidClient(owner2) && InTeamN[owner2])
				{
					if(NTFlags[owner2] & ALFLAG_NOPROJCOLLIDE)
					{
						SDKHook(entity, SDKHook_Touch, Hook_OnEntityTouch);
					}
					if(NTFlags[owner2] & ALFLAG_INVISIBLE)
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
			if(NTFlags[owner] & ALFLAG_INVISIBLE)
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
		RequestFrame(Frame_HandleTauntProps, EntIndexToEntRef(entity)); // The tauntprop here is at position: x=0.0 | y=0.0 | z=0.0 |. So one frame later process! 
	}
	else if(StrContains(classname, "item_ammopack_", false)>-1 || StrContains(classname, "tf_ammo_", false)>-1 || StrContains(classname, "health", false)>-1 || StrContains(classname, "spell", false)>-1)
	{
		SDKHook(entity, SDKHook_StartTouch, Hook_GroundEntTouch);
		SDKHook(entity, SDKHook_Touch, Hook_GroundEntTouch);
		AL_Debug("Hooked entity with classname %s", classname);
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
	new Float:entityOrigin[3], Float:searchOrigin[3], Float:distance,  nearest;
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", entityOrigin);
	for(new search=1; search<=MaxClients; search++) // 1. Find the nearest player
	{
		if(IsValidClient(search) && IsPlayerAlive(search))
		{
			GetClientAbsOrigin(search, searchOrigin);
			distance=GetVectorDistance(entityOrigin, searchOrigin);
			if(distance==0.0)
			{
				nearest=search;
				break;
			}
		}
	}
	// 2. Test if the player taunts
	if(InTeamN[nearest] && TF2_IsPlayerInCondition(nearest, TFCond_Taunting))
	{
		if(GetEntProp(nearest, Prop_Send, "m_iTauntItemDefIndex")!=-1 && GetEntProp(nearest, Prop_Send, "m_iTauntItemDefIndex")!=0)
		{
			if(NTFlags[nearest] & ALFLAG_INVISIBLE)
			{
				SDKHook(entity, SDKHook_SetTransmit, Hook_Transmit);
			}
			InTeamN[entity]=true;
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
					if(IsValidClient(owner2) && (NTFlags[owner2] & ALFLAG_INVISIBLE))
					{
						SDKHook(entity, SDKHook_SetTransmit, Hook_Transmit);
					}
				}
				InTeamN[entity]=true;
			}
		}
	}
}

//From here: https://forums.alliedmods.net/showthread.php?t=231757
public OnEntityDestroyed(entity) //Deinitialize entity.
{
	if(entity<=MAXENTITIES && entity>MaxClients)
	{
		decl String:classname[64];
		GetEntityClassname(entity, classname, sizeof(classname));
		if((StrContains(classname, "obj_", false)>-1) && InTeamN[entity])
		{
			StopSound(entity, 0, SOUND_SAPPER_NOISE);
			StopSound(entity, 0, SOUND_SAPPER_NOISE2);                 // So, if the entity destroyed was targeted by someone's sapper
			StopSound(entity, 0, SOUND_SAPPER_PLANT); 
		}
		InTeamN[entity]=false;
	}
}

public Action:Timer_Announce(Handle:htimer) //To-do: More details and information
{
	if(!Enabled)
	{
		return Plugin_Stop;
	}
	switch(GetRandomInt(0, 7))
	{
	case 1, 2, 5:
		{
			PrintToChatAll("\x03 If you want to respawn into the neutral team or want to \x01", SMTAG);
			PrintToChatAll("\x03 change your gravity write \x077FFF00!neutral\x03 into chat! \x01", SMTAG);
		}
		/*
	case 3, 0, 4:
		{   // Now, I know how to works with colors without include files: \x07*hexcode*
			PrintToChatAll("\x03 This server is running the Neutral Team Mode plugin");
			PrintToChatAll("\x03 Developed by \x07FF8C00Naydef\x03. Current version: %s", PLUGIN_VERSION);
			PrintToChatAll("\x03 If you find some bug in the plugin, go to this page and post:");
			PrintToChatAll("\x07FF8C00https://forums.alliedmods.net/showthread.php?p=2377802");
			PrintToChatAll("\x03Thank you");
		}
		*/
	default:
		{
			PrintToChatAll("%s To Change your neutral team preferences, write \x077FFF00!neutral\x01 in chat!", SMTAG); 
		}
	}
	return Plugin_Continue;
}

public Action:Hook_OnEntityTouch(entity, other) //Tested and works!
{
	if(!Enabled || other<=0)
	{
		return Plugin_Continue;
	}
	if(!InTeamN[other] && InTeamN[entity])
	{
		// Projectile collision handling part
		new String:classname[64];
		GetEntityClassname(entity, classname, sizeof(classname));
		if(StrContains(classname, "tf_proj", false)>-1 || StrEqual(classname, "tf_flame"))
		{
			GetEntityClassname(other, classname, sizeof(classname));
			if(StrContains(classname, "obj_", false)>-1 || IsValidClient(other))
			{
				AcceptEntityInput(entity, "Kill");  //Be silent.
				InTeamN[entity]=false;
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

public Action:Hook_GroundEntTouch(entity, client)
{
	if(IsValidClient(client) && InTeamN[client] && noPickups)
	{
		return Plugin_Handled;
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
		//Procedure 1: Scan every wearable and weapon for force visibility flag! Warning: CPU expensive (but I have to say that my server with 2.29ghz dual-core processor doesn't have any lag)
		new item=-1;
		while((item=FindEntityByClassname2(item, "tf_wea*"))!=-1)
		{
			if(GetEntPropEnt(item, Prop_Send, "m_hOwnerEntity")==objs)
			{
				if(GetEdictFlags(item) & FL_EDICT_ALWAYS)
				{
					SetEdictFlags(item, GetEdictFlags(item) ^ FL_EDICT_ALWAYS);
				}
			}
		}
		
		//Procedure 2: Scan every particle with owner registered neutral entity
		//Do you know: Particle systems have FL_EDICT_ALWAYS flag, which will make every entity parented to them visible (compatible with Building Hats plugin)
		item=-1;
		while((item=FindEntityByClassname2(item, "info_particle_system"))!=-1)
		{
			if(GetEntPropEnt(item, Prop_Send, "moveparent")==objs)
			{
				if(GetEdictFlags(item) & FL_EDICT_ALWAYS)
				{
					SetEdictFlags(item, GetEdictFlags(item) ^ FL_EDICT_ALWAYS);
				}
			}
		}
		
		//Procedure 3: Remove the flag if there is from the actual entity
		if(GetEdictFlags(objs) & FL_EDICT_ALWAYS)
		{
			SetEdictFlags(objs, GetEdictFlags(objs) ^ FL_EDICT_ALWAYS); //The flag is removed.
		}
		
		//Continue with the logic
		if(IsValidClient(entity) && !IsPlayerAlive(entity) && InTeamN[objs])
		{
			return Plugin_Continue;
		}
		
		if(IsValidClient(objs))
		{
			return (NTFlags[objs] & ALFLAG_INVISIBLE) ? Plugin_Handled : Plugin_Continue;
		}
		return Plugin_Handled; //For every other non-player entity which is hooked!
	}
	return Plugin_Continue;
}

public Action:Hook_TakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if(!Enabled)
	{
		return Plugin_Continue;
	}
	if(InTeamN[victim] && !IsValidClient(attacker)  && !(NTFlags[victim] & ALFLAG_TAKEDMG))
	{
		new String:classname[64];
		GetEntityClassname(attacker, classname, sizeof(classname));
		if(StrEqual(classname, "trigger_hurt", false) || (StrContains(classname, "func_", false)>-1))
		{
			damagetype|=DMG_REMOVENORAGDOLL;
			return (NoTriggerHurt) ? Plugin_Handled : Plugin_Changed;
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
				if(NTFlags[victim] & ALFLAG_TAKEDMG)
				{
					damagetype|=DMG_REMOVENORAGDOLL;
					return Plugin_Changed;
				}
				else
				{
					return Plugin_Handled;
				}
			}
		}
		return Plugin_Handled;
	}
	if(InTeamN[victim] && InTeamN[attacker])
	{
		damagetype|=DMG_REMOVENORAGDOLL;
		return Plugin_Changed;
	}
	
	if(InTeamN[victim] || InTeamN[attacker])
	{
		if(IsValidClient(victim) && IsValidClient(attacker) && InTeamN[attacker] && (NTFlags[attacker] & ALFLAG_DONTSTUN))
		{
			/*
				We test here if the player has one of the conditions
				before the damage. If he has, we don't remove the
				conditions. Prevent neutral players attacking playing
				players to remove condition (For "illegal" advantage!).
			*/
			new Handle:DataCond=CreateDataPack();
			WritePackCell(DataCond, GetClientUserId(victim));
			WritePackCell(DataCond, GetEntProp(victim, Prop_Send, "m_nPlayerCond")|GetEntProp(victim, Prop_Send, "_condition_bits")); // Is is worth bypassing this warning for deprecated function?
			RequestFrame(Frame_FilterCondition, DataCond);
		}
		if(IsValidClient(victim) && !(NTFlags[victim] & ALFLAG_TAKEDMG) && InTeamN[victim])
		{
			return Plugin_Handled;
		}
		else if(IsValidClient(victim) && InTeamN[victim])
		{
			damagetype|=DMG_REMOVENORAGDOLL;
			return Plugin_Changed;
		}
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Frame_FilterCondition(Handle:pack) // I hope this work.
{
	ResetPack(pack);
	new client=GetClientOfUserId(ReadPackCell(pack));
	if(!IsValidClient(client))
	{
		return;
	}
	new conditions=ReadPackCell(pack);
	if(!(conditions & TF_CONDFLAG_BLEEDING))
	{
		TF2_RemoveCondition(client, TFCond_Bleeding);
	}
	if(!(conditions & TF_CONDFLAG_DAZED))
	{
		TF2_RemoveCondition(client, TFCond_Dazed);
	}
	if(!(conditions & TF_CONDFLAG_ONFIRE))
	{
		TF2_RemoveCondition(client, TFCond_OnFire);
	}
	if(!(conditions & TF_CONDFLAG_TAUNTING))
	{
		TF2_RemoveCondition(client, TFCond_Taunting);
	}
	CloseHandle(pack);
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
		if(NTFlags[client] & ALFLAG_JRTAMM)
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

public bool:SetMeToOtherTeam(client)
{
	if(!IsValidClient(client))
	{
		return false;
	}
	SetEntProp(client, Prop_Send, "m_lifeState", 2);
	TF2_ChangeClientTeam(client, NTEAM);
	TF2_RespawnPlayer(client);
	SetEntProp(client, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);               // Set their collision group to debris but triggers.
	TF2_RegeneratePlayer(client); // Fix civilian bug, because of TF2Items!
	TeleportToSpawn(client, 0);
	for(new i=0; i<=WSLOTS; i++)
	{
		new weapon=GetPlayerWeaponSlot(client, i);
		if(!IsValidEntity(weapon))
		{
			continue;
		}
		InTeamN[weapon]=true;
	}
	CreateTimer(0.1, Timer_SetGravity, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	return true;
}

public bool:SetMeToMyTeam(client, norespawn)
{
	if(!IsValidClient(client))
	{
		return false;
	}
	SetEntProp(client, Prop_Send, "m_lifeState", 2);
	TF2_ChangeClientTeam(client, LastTeam[client]);
	if(!norespawn)
	{
		TF2_RespawnPlayer(client);
	}
	for(new i=0; i<=WSLOTS; i++)
	{
		new weapon=GetPlayerWeaponSlot(client, i);
		if(!IsValidEntity(weapon))
		{
			continue;
		}
		InTeamN[weapon]=false;
	}
	ApplyGravityClient(client, float(GetConVarInt(DGravity))/800.0); // Note: This is a handle to the current value of the gravity of the server convar!
	SetEntProp(client, Prop_Send, "m_CollisionGroup", i_Collision[client]);
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
	if(!Enabled || !InTeamN[client])
	{
		return Plugin_Continue;
	}
	if(AllowNeutralTP)
	{
		result=true;
		if(!InTeamN[teleporter])
		{
			CreateTimer(0.1, Timer_SetFullChargeTP, EntIndexToEntRef(teleporter));
		}
		return Plugin_Changed;
	}
	else
	{
		result=false;
	}
	return Plugin_Continue;
}

public Action:Timer_SetFullChargeTP(Handle:htimer, ref)
{
	new entity=EntRefToEntIndex(ref);
	if(!IsValidEntity(entity))
	{
		return Plugin_Stop;
	}
	SetEntPropFloat(entity, Prop_Send, "m_flRechargeTime", GetGameTime());
	SetEntProp(entity, Prop_Send, "m_iTimesUsed", (GetEntProp(entity, Prop_Send, "m_iTimesUsed")<=0) ? 0 : GetEntProp(entity, Prop_Send, "m_iTimesUsed")-1);
	return Plugin_Continue;
}

#if SOURCEMOD_V_MAJOR==1 && SOURCEMOD_V_MINOR>=8
public Action:Hook_EntitySound(clients[MAXPLAYERS], &numClients, String:sound[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags, String:soundEntry[PLATFORM_MAX_PATH], &seed)
#else
public Action:Hook_EntitySound(clients[64], &numClients, String:sound[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
#endif
{
	if(!Enabled || !InTeamN[entity])
	{
		return Plugin_Continue;
	}
	
	if(IsValidClient(entity) && !(NTFlags[entity] & ALFLAG_NOSOUND))
	{
		return Plugin_Continue;
	}
	
	for(new i=0; i<numClients; i++) // Answer from user Disowned
	{
		if(IsValidClient(clients[i]) && !InTeamN[clients[i]] && IsPlayerAlive(clients[i]))
		{
			for(new j=i; j<numClients-1; j++)
			{
				clients[j]=clients[j+1];
			}
			numClients--;
			i--;
		}
	}
	return (numClients > 0) ? Plugin_Changed : Plugin_Handled;
}


public Action:Hook_TempEntHook(const String:te_name[], const Players[], numClients,  Float:delay) //From be the skeleton plugin
{
	//AL_Debug("Temporary entity name: %s", te_name);
	if(StrEqual(te_name, "TFBlood"))
	{
		new emitter=TE_ReadNum("entindex");
		if(!IsValidClient(emitter))
		{
			return Plugin_Continue;
		}
		//AL_Debug("Owner entity index: %i", emitter);
		//if(IsValidClient(emitter)) AL_Debug("Blood emitted by %N", emitter);
		if(InTeamN[emitter] && BlockBlood)
		{
			//AL_Debug("Stop!");
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

bool:IsLegidToSpawn(client)
{
	if(!Enabled || !IsValidClient(client) || InTeamN[client] || IsPlayerAlive(client))
	{
		return false;
	}
	if(!GetEntProp(client, Prop_Send, "m_iDesiredPlayerClass")) // The important thing is that m_iDesiredPlayerClass ALWAYS have to be valid, this requirement doesn't apply for m_iClass
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
}

public Native_IsBlastEnabled(Handle:plugin, numParams)
{
	return _:TakeBlast[GetNativeCell(1)];
}

public Native_SetBlast(Handle:plugin, numParams)
{
	TakeBlast[GetNativeCell(1)]=GetNativeCell(2);
}

public Native_GetFlags(Handle:plugin, numParams)
{
	return NTFlags[GetNativeCell(1)];
}

public Native_SetFlags(Handle:plugin, numParams)
{
	return NTFlags[GetNativeCell(1)]=GetNativeCell(2);
}

public Native_IsDebugEnabled(Handle:plugin, numParams)
{
	return _:DebugEnabled;
}

public Native_GetNeutralTeamNum(Handle:plugin, numParams)
{
	return _:NTEAM;
}

/*                                Stocks                                         */
bool:IsTF2()
{
	return (GetEngineVersion()==Engine_TF2) ? true : false;
}

TeleportToSpawn(iClient, iTeam = 0) // From VS SAXTON HALE 1.53
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
	(apply) ? (flags=GetEntityFlags(ent)|FL_NOTARGET) : (flags=GetEntityFlags(ent)&~FL_NOTARGET);
	SetEntityFlags(ent, flags);
}

TFTeam:Arena_GetClientTeam(entity) //Also works on entities!
{
	return (IsValidEntity(entity)) ? (TFTeam:GetEntProp(entity, Prop_Send, "m_iTeamNum")) : (TFTeam:-1); //Ops, what will happen?
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
	if(bf==INVALID_HANDLE)
	{
		return false;
	}
	BfWriteString(bf, message);
	BfWriteString(bf, icon);
	BfWriteByte(bf, color);
	EndMessage();
	return true;
}