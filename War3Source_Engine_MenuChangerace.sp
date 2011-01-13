



#include <sourcemod>
#include "W3SIncs/War3Source_Interface"







public Plugin:myinfo= 
{
	name="War3Source Menus changerace",
	author="Ownz",
	description="War3Source Core Plugins",
	version="1.0",
	url="http://war3source.com/"
};



public APLRes:AskPluginLoad2(Handle:myself,bool:late,String:error[],err_max)
{
	if(!InitNativesForwards())
	{
		LogError("[War3Source] There was a failure in creating the native / forwards based functions, definately halting.");
		return APLRes_Failure;
	}
	return APLRes_Success;
}

public OnPluginStart()
{

}

bool:InitNativesForwards()
{

	return true;
}
public OnWar3Event(W3EVENT:event,client){
	if(event==DoShowChangeRaceMenu){
		War3Source_ChangeRaceMenu(client);
	}
}

War3Source_ChangeRaceMenu(client)
{
	if(W3IsPlayerXPLoaded(client))
	{
		SetTrans(client);
		new Handle:crMenu=CreateMenu(War3Source_CRMenu_Selected);
		SetMenuExitButton(crMenu,true);
		
		new String:title[400];
		//if(strlen(dbErrorMsg)){
		//	Format(title,sizeof(title),"%s\n \n",dbErrorMsg);
		//}
		Format(title,sizeof(title),"%s%T",title,"[War3Source] Select your desired race",GetTrans()) ;
		if(W3GetLevelBank(client)>0){
			Format(title,sizeof(title),"%s\n%T\n",title,"You Have {amount} levels in levelbank. Say levelbank to use it",GetTrans(), W3GetLevelBank(client));
		}
		SetMenuTitle(crMenu,"%s\n \n",title);
		// Iteriate through the races and print them out
		
		decl String:rbuf[4];
		decl String:rname[64];
		decl String:rdisp[128];
		
		
		new racelist[MAXRACES];
		new racedisplay=W3GetRaceList(racelist);
		//if(GetConVarInt(W3GetVar(hSortByMinLevelCvar))<1){
		//	for(new x=0;x<War3_GetRacesLoaded();x++){//notice this starts at zero!
		//		racelist[x]=x+1;
		//	}
		//}
		
		
			
			
		for(new i=0;i<racedisplay;i++) //notice this starts at zero!
		{
			new	x=racelist[i];
			
			Format(rbuf,sizeof(rbuf),"%d",x); //DATA FOR MENU!
			
			War3_GetRaceName(x,rname,sizeof(rname));
			new yourteam,otherteam;
			for(new y=1;y<=MaxClients;y++)
			{
				
				if(ValidPlayer(y,false))
				{
					if(War3_GetRace(y)==x)
					{
						if(GetClientTeam(client)==GetClientTeam(y))
						{
							++yourteam;
						}
						else
						{
							++otherteam;
						}
					}
				}
			}
			new String:extra[3];
			if(War3_GetRace(client)==x)
			{
				Format(extra,sizeof(extra),">");
				
			}
			else if(W3GetPendingRace(client)==x){
				Format(extra,sizeof(extra),"<");
				
			}
			Format(rdisp,sizeof(rdisp),"%s%T",extra,"{racename} [L {amount}]",GetTrans(),rname,War3_GetLevel(client,x));
			new minlevel=W3GetRaceMinLevelRequired(x);
			if(minlevel<0) minlevel=0;
			if(minlevel)
			{
				Format(rdisp,sizeof(rdisp),"%s %T",rdisp,"reqlvl {amount}",GetTrans(),minlevel);
			}
			//if(!HasRaceAccess(client,race)){ //show that it is restricted?
			//	Format(rdisp,sizeof(rdisp),"%s\nRestricted",rdisp);
			//}
			
			
			
			AddMenuItem(crMenu,rbuf,rdisp,(minlevel<=W3GetTotalLevels(client)||W3IsDeveloper(client))?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
		}
		DisplayMenu(crMenu,client,MENU_TIME_FOREVER);
	}
	else{
		War3_ChatMessage(client,"%T","Your XP Has not been fully loaded yet",GetTrans());
	}
	
}

public War3Source_CRMenu_Selected(Handle:menu,MenuAction:action,client,selection)
{
	if(action==MenuAction_Select)
	{
		if(ValidPlayer(client))
		{
			SetTrans(client);
			new racechosen=selection+1;
			if(racechosen>0&&racechosen<=War3_GetRacesLoaded())
			{
				decl String:SelectionInfo[4];
				decl String:SelectionDispText[256];
				
				new bool:allowChooseRace=true;
				
				new SelectionStyle;
				GetMenuItem(menu,selection,SelectionInfo,sizeof(SelectionInfo),SelectionStyle, SelectionDispText,sizeof(SelectionDispText));
				new race_selected=StringToInt(SelectionInfo);
				
				
				// Minimum level?
				
				new total_level=0;
				for(new x=1;x<=War3_GetRacesLoaded();x++)
				{
					total_level+=War3_GetLevel(client,x);
				}
				new min_level=W3GetRaceMinLevelRequired(race_selected);
				if(min_level<0) min_level=0;
				
				if(min_level!=0&&min_level>total_level&&!W3IsDeveloper(client))
				{
					War3_ChatMessage(client,"%T","You need {amount} more total levels to use this race",GetTrans(),min_level-total_level);
					War3Source_ChangeRaceMenu(client);
					allowChooseRace=false;
				}
				
				
				// GetUserFlagBits(client)&ADMFLAG_ROOT??
				
				new String:requiredflagstr[32];
				
				W3GetRaceAccessFlagStr(race_selected,requiredflagstr,sizeof(requiredflagstr));  ///14 = index, see races.inc
				
				if(!StrEqual(requiredflagstr, "0", false)&&!StrEqual(requiredflagstr, "", false)&&!W3IsDeveloper(client)){
					
					new AdminId:admin = GetUserAdmin(client);
					if(admin == INVALID_ADMIN_ID) //flag is required and this client is not admin
					{
						allowChooseRace=false;
						War3_ChatMessage(client,"%T","Restricted Race. Ask an admin on how to unlock",GetTrans());
						PrintToConsole(client,"%T","No Admin ID found",client);
						War3Source_ChangeRaceMenu(client);
						
					}
					else{
						decl AdminFlag:flag;
						if (!FindFlagByChar(requiredflagstr[0], flag)) //this gets the flag class from the string
						{
							War3_ChatMessage(client,"%T","ERROR on admin flag check {flag}",client,requiredflagstr);
							allowChooseRace=false;
						}
						else
						{
							if (!GetAdminFlag(admin, flag)){
								allowChooseRace=false;
								War3_ChatMessage(client,"%T","Restricted race, ask an admin on how to unlock",GetTrans());
								PrintToConsole(client,"%T","Admin ID found, but no required flag",client);
								War3Source_ChangeRaceMenu(client);
							}
						}
					}
				}
				
				
				
				if(allowChooseRace)
				{
					W3SetPlayerProp(client,RaceChosenTime,GetGameTime());
					W3SetPlayerProp(client,RaceSetByAdmin,false);
					
					
					decl String:buf[192];
					War3_GetRaceName(race_selected,buf,sizeof(buf));
					if(race_selected==War3_GetRace(client)&&(   W3GetPendingRace(client)<1||W3GetPendingRace(client)==War3_GetRace(client)    )){ //has no other pending race, cuz user might wana switch back
						
						War3_ChatMessage(client,"%T","You are already {racename}",GetTrans(),buf);
						if(W3GetPendingRace(client)){
							W3SetPendingRace(client,-1);
						}
						
					}
					else if(GetConVarInt(W3GetVar(hRaceLimitEnabledCvar))>0){
						if(GetRacesOnTeam(racechosen,GetClientTeam(client))>=W3GetRaceMaxLimitTeam(racechosen,GetClientTeam(client))){ //already at limit
							if(!W3IsDeveloper(client)){   
								War3_ChatMessage(client,"%T","Race limit for your team has been reached, please select a different race. (MAX {amount})",GetTrans(),W3GetRaceMaxLimitTeam(racechosen,GetClientTeam(client)));
								W3Log("race %d blocked on client %d due to restrictions limit %d (select changeracemenu)",racechosen,client,W3GetRaceMaxLimitTeam(racechosen,GetClientTeam(client)));
								War3Source_ChangeRaceMenu(client);
								allowChooseRace=false;
								
							}
						}
					}
				
					//SCHEDULE
					else if(War3_GetRace(client)>0&&IsPlayerAlive(client)&&!W3IsDeveloper(client)) //developer direct set (for testing purposes)
					{
						W3SetPendingRace(client,race_selected);
						
						War3_ChatMessage(client,"%T","You will be {racename} after death or spawn",GetTrans(),buf);
					}
					//HAS NO RACE, CHANGE NOW
					else //schedule the race change
					{
						W3SetPendingRace(client,-1);
						War3_SetRace(client,race_selected);
						
						//print is in setrace
						//War3_ChatMessage(client,"You are now %s",buf);
						
						W3DoLevelCheck(client);
					}
				}
			}
		}
	}
	if(action==MenuAction_End)
	{
		CloseHandle(menu);
	}
}


