// Left4Dead Engine
// Handles L4D specific stuff 

#include <sourcemod>
#include "W3SIncs/War3Source_Interface"

#include <sdkhooks>

public Plugin:myinfo= 
{
	name = "W3S Engine Left4Dead",
	author = "Glider",
	description = "War3Source Core Plugins",
	version = "1.0",
	url = "http://war3source.com/"
};

new bool:g_bIsHelpless[MAXPLAYERS+1];
new Handle:g_hArrayOfKaboom = INVALID_HANDLE;

public APLRes:AskPluginLoad2Custom(Handle:plugin,bool:late,String:error[],err_max)
{
	if(!GameL4DAny())
		return APLRes_SilentFailure;
	return APLRes_Success;
}
public bool:InitNativesForwards()
{
	///LIST ALL THESE NATIVES IN INTERFACE
	CreateNative("War3_L4D_IsHelpless", Native_War3_L4D_IsHelpless);
	CreateNative("War3_L4D_Explode", Native_L4D_CauseExplosion);
	return true;
}

public OnPluginStart()
{
	if(!GameL4DAny())
		SetFailState("Only works in the L4D engine! %i", War3_GetGame());
	
	// Hunter
	HookEvent("lunge_pounce", Event_IsHelpless);
	HookEvent("pounce_stopped", Event_IsNoLongerHelpless);
	
	// Smoker
	HookEvent("tongue_grab", Event_IsHelpless);
	HookEvent("tongue_release", Event_IsNoLongerHelpless);
	
	// Charger
	HookEvent("charger_carry_start", Event_IsHelpless);
	HookEvent("charger_carry_end", Event_IsNoLongerHelpless);
	// Yes, there is a small time gap between carrying and pummeling that
	// is not accounted for.
	HookEvent("charger_pummel_start", Event_IsHelpless);
	HookEvent("charger_pummel_end", Event_IsNoLongerHelpless);
		
	// Jockey
	HookEvent("jockey_ride", Event_IsHelpless);
	HookEvent("jockey_ride_end", Event_IsNoLongerHelpless);
	
	HookEvent("round_start", Event_ResetHelplessAll);
	HookEvent("round_end", Event_ResetHelplessAll);
	
	HookEvent("player_spawn", Event_ResetHelplessUserID);
	HookEvent("player_death", Event_ResetHelplessUserID);
	HookEvent("player_connect_full", Event_ResetHelplessUserID);
	HookEvent("player_disconnect", Event_ResetHelplessUserID);
	
	g_hArrayOfKaboom = CreateArray();
}

// Make sure they are always precached!
public OnMapStart()
{
	PrecacheModel(MODEL_GASCAN, true);
	PrecacheModel(MODEL_PROPANE, true);
}

public Event_IsHelpless (Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	if (!victim) return;
	g_bIsHelpless[victim] = true;
}

public Event_IsNoLongerHelpless (Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "victim"));
	if (!victim) return;
	g_bIsHelpless[victim] = false;
}

public Event_ResetHelplessAll (Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i=1 ; i<=MaxClients ; i++)
	{
		g_bIsHelpless[i] = false;
	}
}

public Event_ResetHelplessUserID (Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client) return;
	g_bIsHelpless[client] = false;
}

public Native_War3_L4D_IsHelpless(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	return g_bIsHelpless[client];
}




public Native_L4D_CauseExplosion(Handle:plugin, numParams)
{
	decl Float:pos[3];
	
	new attacker = GetNativeCell(1);
	GetNativeArray(2, pos, sizeof(pos));
	new type = GetNativeCell(3);
			
	CauseExplosion(attacker, pos, type);
}

/* type == 0: Fire
 * type != 0: Explosion
 */
stock CauseExplosion(attacker, Float:pos[3], type)
{
	new entity = CreateEntityByName("prop_physics");
	if (IsValidEntity(entity))
	{
		PushArrayCell(g_hArrayOfKaboom, entity);
		SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmit);
		
		pos[2] += 10.0;
		if (type == 0)
			DispatchKeyValue(entity, "model", MODEL_GASCAN);
		else
			DispatchKeyValue(entity, "model", MODEL_PROPANE);
		DispatchSpawn(entity);
		TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
		SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", attacker);
	}
}

public Action:Hook_SetTransmit(temp_explosive, client)
{
	//return Plugin_Continue;
	return Plugin_Handled; 
}

/* Glider my good man - what the fuck are you doing?
 * Well you see, person reading this source code, when I called the explosion
 * code right after spawning the entity it wouldn't work. If I put a 0.1
 * timer in before it worked. Since 0.1 is too big of a delay, I'm just checking
 * OnGameFrame to make it explode as soon as possible. 
 * 
 * Is this dirty? Yes. Would I rather have it another way? Yes. Will I spend
 * months trying to come up with a better solution? Fuck no. Deal with it.
 */
public OnGameFrame()
{
	while(GetArraySize(g_hArrayOfKaboom))
	{
		new item = GetArrayCell(g_hArrayOfKaboom, 0);
		if(IsValidEntity(item))
		{
			ExplodeThisEntity(item);
		}
	
		RemoveFromArray(g_hArrayOfKaboom, 0);
	}
}

public ExplodeThisEntity(entity)
{
	new attacker = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");

	new pointHurt = CreateEntityByName("point_hurt");
	if(IsValidEntity(pointHurt))
	{
		DispatchKeyValue(entity, "targetname", "war3_hurtme");
		DispatchKeyValue(pointHurt, "Damagetarget","war3_hurtme");
		DispatchKeyValue(pointHurt, "Damage", "10000");
		DispatchKeyValue(pointHurt, "DamageType", "1");
		DispatchKeyValue(pointHurt, "classname", "war3_point_hurt");
		DispatchSpawn(pointHurt);
		
		AcceptEntityInput(pointHurt, "Hurt", attacker);
		DispatchKeyValue(entity, "targetname", "war3_donthurtme");
		RemoveEdict(pointHurt);
		//PrintToChatAll("Exploded %f", GetEngineTime());
	}
}

/*
public OnEntityCreated(entity, const String:classname[])
{
	if (StrEqual(classname, "pipe_bomb_projectile"))
	{
		PrintToChatAll("A PIPEBOMB!");
		new attacker = GetEntPropEnt(entity, Prop_Data, "m_hThrower");
		PrintToChatAll("Owned by %i", attacker);
	}
}
*/