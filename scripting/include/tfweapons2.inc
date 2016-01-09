/* 
Minimized version of the TFWeapons plugin, which is private.
Please don't use the code for making custom hats visible (which
means spawning official hats on yourself, which you don't have) 
or Valve again will make further restrictions on the attachments! 
Author: Naydef
Contact: naydef@abv.bg
*/

#if defined _TFWeapons_included
#endinput
#endif
#define _TFWeapons_included

#include <sourcemod>
#include <sdktools>

/**
* Spawn weapon to client!
*
* @param client	 		Client index
* @param index			    item definition index of the weapon
* @param classname		    Classname of the weapon
* @param level	            What level has the weapon in the description
* @param quality           What is the quality of the weapon
* @param visible           Not required: Is the weapon visible
* @param nodescription     Not required: If the weapon's description is removed
*
* @return					true - if the weapon is successfully created and equipped | false - Everything else
*/
stock bool:TFWeapons_Giveweapon(client, itemindex, String:classname[], level, quality, visible=true, nodescription=true)
{
	if(client<=0 || client>MaxClients || !IsClientInGame(client))
	{
		return false;
	}
	new weapon=CreateEntityByName(classname);
	if(!IsValidEntity(weapon))
	{
		return false;
	}
	SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", itemindex);
	SetEntProp(weapon, Prop_Send, "m_bInitialized", 1); // 3. Initialize the weapon.
	if(nodescription)
	{
		SetEntProp(weapon, Prop_Send, "m_iAccountID", FindAccountIdNumber(client)); // 5. Set their account id to the weapon.
	}
	SetEntProp(weapon, Prop_Send, "m_iItemIDLow", -1);
	SetEntProp(weapon, Prop_Send, "m_iItemIDHigh", -1);
	SetEntProp(weapon, Prop_Send, "m_iEntityLevel", level);
	SetEntProp(weapon, Prop_Send, "m_iEntityQuality", quality);
	DispatchSpawn(weapon);
	if(visible)
	{
		//Sorry. No one wants one more conflict with valve hats etc...
	}
	EquipPlayerWeapon(client, weapon);
	return true;
}

FindAccountIdNumber(client) //My first successful function which works with strings.
{
	new String:ID[64];
	new String:number[30];
	if(!GetClientAuthId(client, AuthId_Steam3, ID, sizeof(ID)))
	{
		return 0; //Bot weapons are visible anyway even if they have custom weapon.
	}
	new s;
	new b;
	for(new i=0; i<=63 ; i++)
	{
		if(ID[i]==':')
		{
			s++;
		}
		if(s==2)
		{
			b=i+1;
			break;
		}
	}
	strcopy(number, sizeof(number), ID[b]); 
	for(new d=0; d<=29 ; d++)
	{
		if(number[d]=='[' || number[d]==']')
		{
			number[d]=' ';
		}
	}
	return StringToInt(number);
}