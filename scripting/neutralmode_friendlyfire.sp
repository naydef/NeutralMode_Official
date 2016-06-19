/*
	Plugin: [TF2] Afterlife: Friendly Fire
	Subplugin | Version: 0.2
	Description: Simply enables the ability, teammates from the neutral
	team to hurt their teammates! Perfect!
	New: Backstab detection

*/
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <afterlife_plugin>
#include <tf2_stocks>

#define PLUGIN_VERSION "0.3.1"
#define PLUGIN_AUTHOR "Naydef"

//Handle
new Handle:hCvarFriendly=INVALID_HANDLE;


public Plugin:myinfo =
{
	name = "[TF2] AfterLife: Friendly Fire", 
	author = PLUGIN_AUTHOR,
	description = "Hurt your neutral team mates!",
	version = PLUGIN_VERSION,
	url = "http://ngeo.ftp.sh/development/"
};

public OnPluginStart()
{
	hCvarFriendly = FindConVar("mp_friendlyfire");
	new flags = GetConVarFlags(hCvarFriendly);
	flags &=~ FCVAR_NOTIFY  & ~ FCVAR_REPLICATED;
	SetConVarFlags(hCvarFriendly, flags &=~ FCVAR_NOTIFY);
	SetConVarFlags(hCvarFriendly, flags);
	SetConVarBool(hCvarFriendly, true);
	for(new i=1; i<=MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			OnClientPutInServer(i);
		}
	}
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
	SDKHook(client, SDKHook_StartTouch, Hook_StartTouch);
}

public OnClientDisconnect(client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
	SDKUnhook(client, SDKHook_StartTouch, Hook_StartTouch);
}

public OnEntityCreated(entity, const String:classname[])
{
	SDKHook(entity, SDKHook_SpawnPost, Hook_SpawnPost);
}

public Action:Hook_SpawnPost(entity)
{
	if(entity<=0 || entity>=2049)
	{
		return Plugin_Continue;
	}
	SDKHook(entity, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
	SDKHook(entity, SDKHook_StartTouch, Hook_StartTouch);
	new String:buffer[64];
	GetEdictClassname(entity, buffer, sizeof(buffer));
	if(!((StrContains(buffer, "tf_projectile", false)>-1 || StrContains(buffer, "tf_flame", false)>-1)))
	{
		return Plugin_Continue;
	}
	if(AL_IsInTheNeutralTeam(GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")))
	{
		SetEntProp(entity, Prop_Send, "m_iTeamNum", 1);
		SetEntProp(entity, Prop_Data, "m_iInitialTeamNum", 1);
	}
	return Plugin_Continue;
}

public Action:Hook_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if(!AL_IsEnabled())
	{
		return Plugin_Continue;
	}
	if(!IsValidClient(victim) || !IsValidClient(attacker))
	{
		return Plugin_Continue;
	}
	if(victim==attacker)
	{
		return Plugin_Continue;
	}
	if(!IsValidEdict(weapon) || (weapon==-1))
	{
		return Plugin_Continue;
	}
	if(AL_IsInTheNeutralTeam(victim) && AL_IsInTheNeutralTeam(attacker))
	{
	    damagetype|=DMG_NEVERGIB; // Fix more crashes
		new String:sWeaponClass[64];
		GetEdictClassname(weapon, sWeaponClass, sizeof(sWeaponClass));
		if((StrEqual(sWeaponClass, "tf_weapon_knife", false) || (TF2_GetPlayerClass(attacker) == TFClass_Spy && StrEqual(sWeaponClass, "saxxy", false))) && (damagecustom != TF_CUSTOM_TAUNT_FENCING)) //Copy, pasted from slender fortress 2
		{
			decl Float:flMyPos[3], Float:flHisPos[3], Float:flMyDirection[3];
			GetClientAbsOrigin(victim, flMyPos);
			GetClientAbsOrigin(attacker, flHisPos);
			GetClientEyeAngles(victim, flMyDirection);
			GetAngleVectors(flMyDirection, flMyDirection, NULL_VECTOR, NULL_VECTOR);
			NormalizeVector(flMyDirection, flMyDirection);
			ScaleVector(flMyDirection, 32.0);
			AddVectors(flMyDirection, flMyPos, flMyDirection);
			
			decl Float:p[3], Float:s[3];
			MakeVectorFromPoints(flMyPos, flHisPos, p);
			MakeVectorFromPoints(flMyPos, flMyDirection, s);
			if(GetVectorDotProduct(p, s) <= 0.0)
			{
				damage = float(GetEntProp(victim, Prop_Send, "m_iHealth")) * 2.0;
				
				new Handle:hCvar = FindConVar("tf_weapon_criticals");
				if (hCvar != INVALID_HANDLE && GetConVarBool(hCvar)) damagetype |= DMG_ACID;
				return Plugin_Changed;
			}
			return Plugin_Continue;
		}	
	}
	else if((Arena_GetClientTeam(victim)==Arena_GetClientTeam(attacker)) || (AL_IsInTheNeutralTeam(victim) && !AL_IsInTheNeutralTeam(attacker)))
	{
		return Plugin_Handled;
	}
	else
	{
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

public Action:Hook_StartTouch(entity, other)
{
	//Debug("1. StartCollision with entity %i and entity %i", entity, other);
	if(!AL_IsEnabled() || other<=0)
	{
		return Plugin_Continue;
	}
	if(AL_IsInTheNeutralTeam(entity) && AL_IsInTheNeutralTeam(other))
	{
		Debug("2. StartCollision with entity %i and entity %i", entity, other);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:AL_OnNeutralRespawn(client, isAlready) //Normally, this will not be called if the main plugin is disabled
{
	if(!isAlready)
	{
		RequestFrame(Frame_Announce, GetClientUserId(client));
	}
	AL_SetFlags(client, AL_GetFlags(client)|ALFLAG_TAKEDMG);
	return Plugin_Continue;
}

public Frame_Announce(userid)
{
	new client=GetClientOfUserId(userid);
	if(!IsValidClient(client))
	{
		return;
	}
	PrintToChat(client, "%s Now go and FIGHT versus your neutral TEAMMATES!!!", SMTAG);
	return;
}

public OnPluginEnd()
{
	SetConVarFlags(hCvarFriendly, GetConVarFlags(hCvarFriendly)|FCVAR_NOTIFY|FCVAR_REPLICATED);
	SetConVarBool(hCvarFriendly, false);
}

//Stocks
Arena_GetClientTeam(entity) //Also works on entities!
{
	return GetEntProp(entity, Prop_Send, "m_iTeamNum");
}


stock bool:IsValidClient(client, bool:replaycheck=true)//From Freak Fortress 2
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
