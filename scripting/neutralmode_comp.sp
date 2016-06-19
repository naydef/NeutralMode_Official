/*
	Plugin: [TF2] Afterlife: Friendly Fire
	Subplugin | Version: 0.3.2
	Description: Simply enables the ability, teammates from the neutral
	team to hurt their teammates! Perfect!
	New: Backstab detection

*/
#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <neutralteam_plugin>
#include <freak_fortress_2>

#define PLUGIN_VERSION "0.2"

public Plugin:myinfo =
{
	name = "[TF2] Afterlife-Freak Fortress 2 Compatibility", 
	author = "Naydef",
	description = "Compatibility subplugin",
	version = PLUGIN_VERSION,
	url = "https://github.com/naydef/Afterlife-plugin"
};

public Action:AL_OnNeutralRespawn(client, isAlready, &flags)
{
	new boss=FF2_GetBossIndex(client);
	if(GetClientOfUserId(FF2_GetBossUserId(boss))!=client)
	{
		return Plugin_Continue;
	}
	PrintToChatAll("%s You are the boss. You are not allowed to respawn into the neutral team right now!", SMTAG);
	return Plugin_Handled; // Ok, the client is boss
}