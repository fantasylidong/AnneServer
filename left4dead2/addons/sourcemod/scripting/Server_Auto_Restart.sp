#include <sourcemod>

new Handle:g_ConVarHibernate;

static bool:Isl4d2;

public Plugin:myinfo =
{
	name = "[L4D2]Server_Auto_Restart",
	author = "BeefJerky331",
	description = "当最后一个玩家离开服务器时自动重启",
	version = "0.1",
	url	= ""
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) 
{
	decl String:GameName[64];
	GetGameFolderName(GameName, sizeof(GameName));
	if (StrContains(GameName, "left4dead", false) == -1)
		Isl4d2 = false;
	else if (StrEqual(GameName, "left4dead2", false))
		Isl4d2 = true;
	
	return APLRes_Success; 
}

public OnPluginStart()
{
	g_ConVarHibernate = FindConVar("sv_hibernate_when_empty");
	
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);	
}

public Event_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!client || (IsClientConnected(client)&&!IsClientInGame(client))) return;
	if(client&&!IsFakeClient(client)&&!checkrealplayerinSV(client))
	{
		if(Isl4d2)
			ServerCommand("sm_cvar sb_all_bot_game 1");
		else
			ServerCommand("sm_cvar sb_all_bot_team 1");
		SetConVarInt(g_ConVarHibernate,0);
		CreateTimer(20.0,COLD_DOWN);
	}
}

public Action:COLD_DOWN(Handle:timer,any:client)
{
	if(checkrealplayerinSV(0)) return;
	LogMessage("最后一个玩家已经离开了服务器，正在重启服务端...");
	SetCommandFlags("crash", GetCommandFlags("crash") &~ FCVAR_CHEAT);
	ServerCommand("crash");
	SetCommandFlags("sv_crash", GetCommandFlags("sv_crash") &~ FCVAR_CHEAT);
	ServerCommand("sv_crash");
}

bool:checkrealplayerinSV(client)
{
	for (new i = 1; i < MaxClients+1; i++)
		if(IsClientConnected(i)&&!IsFakeClient(i)&&i!=client)
			return true;
	return false;
}