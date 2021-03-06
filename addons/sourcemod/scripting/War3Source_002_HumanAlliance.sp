#pragma semicolon 1

#include <sourcemod>
#include "W3SIncs/War3Source_Interface"

public Plugin:myinfo = 
{
    name = "War3Source - Race - Human Alliance",
    author = "War3Source Team",
    description = "The Human Alliance race for War3Source."
};

new thisRaceID;
new Handle:ultCooldownCvar;
new Handle:invisCooldownCvar;

// Chance/Info Arrays
new Float:BashChance[5]={0.0,0.07,0.13,0.19,0.25};
new Float:TeleportDistance[5]={0.0,600.0,700.0,850.0,10000.0};
new Float:InvisibilityAlphaTF[5]={1.0,0.84,0.68,0.56,0.40};
new Float:InvisibilityAlphaCS[5]={1.0,0.90,0.8,0.7,0.6};
new Float:InvisibilityDuration[5]={3.0,3.5,4.0,4.5,5.0};
new DevotionHealth[5]={0,15,25,35,45};

// Effects
new BeamSprite,HaloSprite;

// Skills
new GENERIC_SKILL_TELEPORT;
new SKILL_INVIS, SKILL_BASH, SKILL_HEALTH,ULT_TELEPORT;


new ClientTracer;
new Float:emptypos[3];
new Float:oldpos[MAXPLAYERSCUSTOM][3];
new Float:teleportpos[MAXPLAYERSCUSTOM][3];
new bool:inteleportcheck[MAXPLAYERSCUSTOM];

//new String:teleportSound[]="war3source/blinkarrival.wav";
new String:teleportSound[256];
new String:stealthSound[256];

public OnPluginStart()
{
    ultCooldownCvar = CreateConVar("war3_human_teleport_cooldown","30.0","Cooldown between teleports");
    invisCooldownCvar = CreateConVar("war3_human_invis_cooldown","30.0","Cooldown between invisibilities");
    
    LoadTranslations("w3s.race.human.phrases");
}

public OnWar3LoadRaceOrItemOrdered(num)
{
    if(num == 1)
    {
        GENERIC_SKILL_TELEPORT=War3_CreateGenericSkill("g_teleport");
    }
    if(num == 20)
    {
        thisRaceID=War3_CreateNewRaceT("human");
        SKILL_INVIS=War3_AddRaceSkillT(thisRaceID,"Invisibility",false,4,"100%");
        SKILL_HEALTH=War3_AddRaceSkillT(thisRaceID,"DevotionAura",false,4,"15/25/35/45");
        SKILL_BASH=War3_AddRaceSkillT(thisRaceID,"Bash",false,4,"7/13/19/25%","0.2");
        new Handle:genericSkillOptions=CreateArray(5,2); //block size, 5 can store an array of 5 cells
        SetArrayArray(genericSkillOptions,0,TeleportDistance,sizeof(TeleportDistance));
        SetArrayCell(genericSkillOptions,1,ultCooldownCvar);
        ULT_TELEPORT=War3_UseGenericSkill(thisRaceID,"g_teleport",genericSkillOptions,"Teleport","",true,true);
        W3SkillCooldownOnSpawn(thisRaceID,ULT_TELEPORT,10.0,_);
        War3_CreateRaceEnd(thisRaceID);
        War3_AddSkillBuff(thisRaceID, SKILL_BASH, fBashChance, BashChance);
        War3_AddSkillBuff(thisRaceID, SKILL_INVIS, fInvisibilitySkill, GameTF() ? InvisibilityAlphaTF : InvisibilityAlphaCS);
        War3_AddSkillBuff(thisRaceID, SKILL_HEALTH, iAdditionalMaxHealth, DevotionHealth);
    }
}

public OnMapStart()
{
    War3_AddSoundFolder(teleportSound, sizeof(teleportSound), "blinkarrival.mp3");
    War3_AddSoundFolder(stealthSound, sizeof(stealthSound), "stealth.mp3");
    BeamSprite=War3_PrecacheBeamSprite();
    HaloSprite=War3_PrecacheHaloSprite();
    
    War3_AddCustomSound(teleportSound);
    War3_AddCustomSound(stealthSound);
}


public OnWar3EventSpawn(client)
{
    ActivateSkills(client); //DO NOT OPTIMIZE, ActivateSkills checks for skill level
}
public ActivateSkills(client)
{
    new skill_devo=War3_GetSkillLevel(client,thisRaceID,SKILL_HEALTH);
    if(skill_devo)
    {
        // Devotion Aura
        new Float:vec[3];
        GetClientAbsOrigin(client,vec);
        vec[2]+=20.0;
        new ringColor[4]={0,0,0,0};
        new team=GetClientTeam(client);
        if(team==2)
        {
            ringColor={255,0,0,255};
        }
        else if(team==3)
        {
            ringColor={0,0,255,255};
        }
        TE_SetupBeamRingPoint(vec,40.0,10.0,BeamSprite,HaloSprite,0,15,1.0,15.0,0.0,ringColor,10,0);
        TE_SendToAll();
        
    }
}


public OnGenericSkillLevelChanged(client,generic_skill_id,newlevel,Handle:generic_Skill_Options,customer_race,customer_skill)
{
    //new String:name[32];
    //GetClientName(client,name,sizeof(name));
    //DP("client %d %s genericskill %d level %d, cus %d %d",client,name,generic_skill_id,newlevel,customer_race,customer_skill);
}

new TPFailCDResetToRace[MAXPLAYERSCUSTOM];
new TPFailCDResetToSkill[MAXPLAYERSCUSTOM];

public OnUltimateCommand(client,race,bool:pressed)
{
    //DP("ult pressed");
    if( pressed  && ValidPlayer(client,true) && !Silenced(client))
    {
        new Handle:genericSkillOptions;
        new Float:distances[5];
        new customerrace,customerskill;
    
        new level=W3_GenericSkillLevel(client,GENERIC_SKILL_TELEPORT,genericSkillOptions,customerrace,customerskill);
        //DP("level CUSrace CUSskill %d %d %d",level,customerrace,customerskill);
        if(level)
        {
            GetArrayArray(genericSkillOptions,    0,distances);
            new Float:cooldown=GetConVarFloat(GetArrayCell(genericSkillOptions,1));
            //DP("cool %f",cooldown);
            if(War3_SkillNotInCooldown(client,customerrace,customerskill,true)) //not in the 0.2 second delay when we check stuck via moving
            {
                TPFailCDResetToRace[client]=customerrace;
                TPFailCDResetToSkill[client]=customerskill;
                new bool:success = Teleport(client,distances[level]);
                if(success)
                {
                    //new Float:cooldown=GetConVarFloat(ultCooldownCvar);
                    War3_CooldownMGR(client,cooldown,customerrace,customerskill,_,_);
                }
            }
        
        }
        else if(War3_GetRace(client)==customerrace)
        {
            W3MsgUltNotLeveled(client);
        }
    }

}

public OnAbilityCommand(client,ability,bool:pressed)
{
    if(War3_GetRace(client)==thisRaceID && ability==0 && pressed && IsPlayerAlive(client))
    {
        new skill_level=War3_GetSkillLevel(client,thisRaceID,SKILL_INVIS);
	if(skill_level>0)
        {
             if(!Silenced(client))
	     {
                 if(War3_SkillNotInCooldown(client,thisRaceID,SKILL_INVIS,true))
                 {
                     SetEntityRenderMode(client, RENDER_NONE);
                     EmitSoundToAll(stealthSound,client);
                     PrintToChat(client, "Invisibility: You are now Invisible!");
                     new Float:cooldown=GetConVarFloat(invisCooldownCvar);
                     War3_CooldownMGR(client,cooldown,thisRaceID,SKILL_INVIS,_,_);
                     CreateTimer(InvisibilityDuration[skill_level],EndInvisibility,client);
                 }
             }
             else
             {
                 PrintToChat(client, "Invisibility: You are silenced!");
             }
        }
    }
}

public Action:EndInvisibility(Handle:timer,any:client)
{
    if(ValidPlayer(client,true))
    {
	PrintToChat(client, "Invisibility: You are now Visible!");
	SetEntityRenderMode(client, RENDER_NORMAL);
    }
}


public OnSkillLevelChanged(client,race,skill,newskilllevel)
{
    if(race==thisRaceID)
    {
        ActivateSkills(client); //on a race change, this is called 4 times, but that performance hit is insignificant
    }
}





//Teleportation





bool:Teleport(client,Float:distance)
{
    if(!inteleportcheck[client])
    {
        
        new Float:angle[3];
        GetClientEyeAngles(client,angle);
        new Float:endpos[3];
        new Float:startpos[3];
        GetClientEyePosition(client,startpos);
        new Float:dir[3];
        GetAngleVectors(angle, dir, NULL_VECTOR, NULL_VECTOR);
        
        ScaleVector(dir, distance);
        
        AddVectors(startpos, dir, endpos);
        
        GetClientAbsOrigin(client,oldpos[client]);
        
        
        ClientTracer=client;
        TR_TraceRayFilter(startpos,endpos,MASK_ALL,RayType_EndPoint,AimTargetFilter);
        TR_GetEndPosition(endpos);
        
        if(enemyImmunityInRange(client,endpos)){
            W3MsgEnemyHasImmunity(client);
            return false;
        }
        
        new Float:distanceteleport=GetVectorDistance(startpos,endpos);
        if(distanceteleport<200.0){
            new String:buffer[100];
            Format(buffer, sizeof(buffer), "%T", "Distance too short.", client);
            PrintHintText(client,buffer);
            return false;
        }
        GetAngleVectors(angle, dir, NULL_VECTOR, NULL_VECTOR);///get dir again
        ScaleVector(dir, distanceteleport-33.0);
        
        AddVectors(startpos,dir,endpos);
        emptypos[0]=0.0;
        emptypos[1]=0.0;
        emptypos[2]=0.0;
        
        endpos[2]-=30.0;
        getEmptyLocationHull(client,endpos);
        
        if(GetVectorLength(emptypos)<1.0){
            new String:buffer[100];
            Format(buffer, sizeof(buffer), "%T", "NoEmptyLocation", client);
            PrintHintText(client,buffer);
            return false; //it returned 0 0 0
        }
        
        TeleportEntity(client,emptypos,NULL_VECTOR,NULL_VECTOR);
	W3FlashScreen(client, RGBA_COLOR_WHITE, 0.3, _, FFADE_OUT);
        EmitSoundToAll(teleportSound,client);
        EmitSoundToAll(teleportSound,client);
        
        teleportpos[client][0]=emptypos[0];
        teleportpos[client][1]=emptypos[1];
        teleportpos[client][2]=emptypos[2];
        
        inteleportcheck[client]=true;
        CreateTimer(0.14,checkTeleport,client);
        
        return true;
    }

    return false;
}
public Action:checkTeleport(Handle:h,any:client){
    inteleportcheck[client]=false;
    new Float:pos[3];
    
    GetClientAbsOrigin(client,pos);
    
    if(GetVectorDistance(teleportpos[client],pos)<0.001)//he didnt move in this 0.1 second
    {
        TeleportEntity(client,oldpos[client],NULL_VECTOR,NULL_VECTOR);
        PrintHintText(client,"%T","CantTeleportHere",client);
        War3_CooldownReset(client,TPFailCDResetToRace[client],TPFailCDResetToSkill[client]);
        
        
    }
    else{
        
        
        PrintHintText(client,"%T","Teleported",client);
        
    }
}
public bool:AimTargetFilter(entity,mask)
{
    return !(entity==ClientTracer);
}


new absincarray[]={0,4,-4,8,-8,12,-12,18,-18,22,-22,25,-25};//,27,-27,30,-30,33,-33,40,-40}; //for human it needs to be smaller

public bool:getEmptyLocationHull(client,Float:originalpos[3]){
    
    
    new Float:mins[3];
    new Float:maxs[3];
    GetClientMins(client,mins);
    GetClientMaxs(client,maxs);
    
    new absincarraysize=sizeof(absincarray);
    
    new limit=5000;
    for(new x=0;x<absincarraysize;x++){
        if(limit>0){
            for(new y=0;y<=x;y++){
                if(limit>0){
                    for(new z=0;z<=y;z++){
                        new Float:pos[3]={0.0,0.0,0.0};
                        AddVectors(pos,originalpos,pos);
                        pos[0]+=float(absincarray[x]);
                        pos[1]+=float(absincarray[y]);
                        pos[2]+=float(absincarray[z]);
                        
                        TR_TraceHullFilter(pos,pos,mins,maxs,MASK_SOLID,CanHitThis,client);
                        //new ent;
                        if(!TR_DidHit(_))
                        {
                            AddVectors(emptypos,pos,emptypos); ///set this gloval variable
                            limit=-1;
                            break;
                        }
                        
                        if(limit--<0){
                            break;
                        }
                    }
                    
                    if(limit--<0){
                        break;
                    }
                }
            }
            
            if(limit--<0){
                break;
            }
            
        }
        
    }
    
} 

public bool:CanHitThis(entityhit, mask, any:data)
{
    if(entityhit == data )
    {// Check if the TraceRay hit the itself.
        return false; // Don't allow self to be hit, skip this result
    }
    if(ValidPlayer(entityhit)&&ValidPlayer(data)&&War3_GetGame()==Game_TF&&GetClientTeam(entityhit)==GetClientTeam(data)){
        return false; //skip result, prend this space is not taken cuz they on same team
    }
    return true; // It didn't hit itself
}


public bool:enemyImmunityInRange(client,Float:playerVec[3])
{
    //ELIMINATE ULTIMATE IF THERE IS IMMUNITY AROUND
    new Float:otherVec[3];
    new team = GetClientTeam(client);
    
    for(new i=1;i<=MaxClients;i++)
    {
        if(ValidPlayer(i,true)&&GetClientTeam(i)!=team&&W3HasImmunity(i,Immunity_Ultimates))
        {
            GetClientAbsOrigin(i,otherVec);
            if(GetVectorDistance(playerVec,otherVec)<350)
            {
                return true;
            }
        }
    }
    return false;
}             

    
