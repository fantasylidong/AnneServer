#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define CVAR_FLAGS		FCVAR_NOTIFY

#define PLUGIN_VERSION "1.5"
ConVar 	g_hCvarEnable;
ConVar 	g_hCvarStuckInterval;
ConVar 	g_hCvarNonStuckRadius;
ConVar  g_hCvarRusherPunish;
ConVar  g_hCvarRusherDist;
ConVar  g_hCvarRusherCheckTimes;
ConVar  g_hCvarRusherCheckInterv;
ConVar  g_hCvarRusherMinPlayers;

Handle 	g_hTimerRusher = INVALID_HANDLE;

float 	g_pos[MAXPLAYERS+1][3];
float	g_fTankClawRange;

int  	g_iSurvivorNum = 0,g_iSurvivors[MAXPLAYERS + 1] = {0};
int 	g_bEnabled;
int 	g_iTimes[MAXPLAYERS+1];
int 	g_iStuckTimes[MAXPLAYERS+1];
int 	g_iRushTimes[MAXPLAYERS+1];
int		g_iTanksCount;
/*
	ChangeLog:
	1.5
		修改tank传送可能被卡住的情况
		
	1.4
		救援关不启动rush传送，修改Tank流程检测.生还者进度超过98%的也不会传送（防止传送到安全门内）
	 
	1.3 
		增加倒地被控玩家不进入检测
	
	1.2 
	    增加tank流程检测
	
	1.1 (01-Mar-2019)
	 	修改tank传送逻辑
	
	1.0 (12-4-2022)
	    版本发布
	
*/
public Plugin myinfo = 
{
	name = "Anne Stuck Tank Teleport System",
	author = "东",
	description = "当tank卡住时传送tank到靠近玩家但是玩家看不到的地方，有求生跑男时会传送到跑男位置",
	version = PLUGIN_VERSION,
	url = "https://github.com/fantasylidong/anne"
}

public void OnPluginStart()
{
	CreateConVar(							"l4d2_Anne_stuck_tank_teleport",				PLUGIN_VERSION,	"Plugin version", FCVAR_DONTRECORD );
	g_hCvarEnable = CreateConVar(			"l4d2_Anne_stuck_tank_teleport_enable",					"1",		"Enable plugin (1 - On / 0 - Off)", CVAR_FLAGS );	
	g_hCvarStuckInterval = CreateConVar(	"l4d2_Anne_stuck_tank_teleport_check_interval",			"3",		"Time intervals (in sec.) tank stuck should be checked", CVAR_FLAGS );
	g_hCvarNonStuckRadius = CreateConVar(	"l4d2_Anne_stuck_tank_teleport_non_stuck_radius",		"15",		"Maximum radius where tank is cosidered non-stucked when not moved during X (9) sec. (see l4d2_Anne_stuck_tank_teleport_check_interval ConVar)", CVAR_FLAGS );
	g_hCvarRusherPunish = CreateConVar(		"l4d2_Anne_stuck_tank_teleport_rusher_punish",			"1",		"Punish the player who rush too far from the nearest tank by teleporting tank to him? (0 - No / 1 - Yes)", CVAR_FLAGS );
	g_hCvarRusherDist = CreateConVar(		"l4d2_Anne_stuck_tank_teleport_rusher_dist",			"3000",		"Maximum distance to the nearest tank considered as rusher", CVAR_FLAGS );
	g_hCvarRusherCheckTimes = CreateConVar(	"l4d2_Anne_stuck_tank_teleport_rusher_check_times",		"3",		"Number of checks before finally considering player as rusher", CVAR_FLAGS );
	g_hCvarRusherCheckInterv = CreateConVar("l4d2_Anne_stuck_tank_teleport_rusher_check_interval",	"5",		"Interval (in sec.) between each check for rusher", CVAR_FLAGS );	
	g_hCvarRusherMinPlayers = CreateConVar(	"l4d_TankAntiStuck_rusher_minplayers",		"2",		"Minimum living players allowed for 'Rusher player' rule to work", CVAR_FLAGS );
	HookEvent("tank_spawn",       		Event_TankSpawn,  	EventHookMode_Post);
	HookEvent("player_death",   		Event_PlayerDeath,	EventHookMode_Pre);
	HookEvent("round_start", 			Event_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("round_end", 				Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("finale_win", 			Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("mission_lost", 			Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("map_transition", 		Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("player_disconnect", 		Event_PlayerDisconnect, EventHookMode_Pre);	
	AutoExecConfig(true,			"l4d2_Anne_stuck_tank_teleport");
	
	HookConVarChange(g_hCvarEnable,				ConVarChanged);
	HookConVarChange(g_hCvarRusherPunish,		ConVarChanged);
	
	GetCvars();
	
	for (int i = 1; i <= MaxClients; i++) {
		if (i != 0 && IsClientInGame(i)) {
			if (IsTank(i))
				BeginTankTracing(i);
		}
	}
}
void BeginTankTracing(int client)
{
	g_iStuckTimes[client] = 0;
	GetClientAbsOrigin(client, g_pos[client]);
	//3s种检查一次tank的移动距离
	CreateTimer(g_hCvarStuckInterval.FloatValue, Timer_CheckPos, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}
bool IsValidSurvivor(int client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR)
	{
		return true;
	}
	else
	{
		return false;
	}
}
bool TraceFilter(int entity, int contentsMask)
{
	if (entity || entity <= MaxClients || !IsValidEntity(entity))
	{
		return false;
	}
	else
	{
		static char sClassName[9];
		GetEntityClassname(entity, sClassName, sizeof(sClassName));
		if (strcmp(sClassName, "infected") == 0 || strcmp(sClassName, "witch") == 0|| strcmp(sClassName, "prop_physics") == 0)
		{
			return false;
		}
	}
	return true;
}
public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bEnabled = g_hCvarEnable.BoolValue;	
	if (g_hTimerRusher != INVALID_HANDLE) {
		CloseHandle (g_hTimerRusher);
		g_hTimerRusher = INVALID_HANDLE;
	}
}

//判断该坐标是否可以看到生还或者距离小于300码
bool PlayerVisibleTo(float spawnpos[3])
{
	float pos[3];
	g_iSurvivorNum = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidSurvivor(i) && IsPlayerAlive(i))
		{
			g_iSurvivors[g_iSurvivorNum] = i;
			g_iSurvivorNum++;
			GetClientEyePosition(i, pos);
			if(PosIsVisibleTo(i, spawnpos) || GetVectorDistance(spawnpos, pos) < 300.0)
			{
				return true;
			}
		}	
	}
	return false;
}
//判断从该坐标发射的射线是否击中目标
bool PosIsVisibleTo(int client, const float targetposition[3])
{
	float position[3], vAngles[3], vLookAt[3], spawnPos[3];
	GetClientEyePosition(client, position);
	MakeVectorFromPoints(targetposition, position, vLookAt);
	GetVectorAngles(vLookAt, vAngles);
	Handle trace = TR_TraceRayFilterEx(targetposition, vAngles, MASK_VISIBLE, RayType_Infinite, TraceFilter, client);
	bool isVisible;
	isVisible = false;
	if(TR_DidHit(trace))
	{
		static float vStart[3];
		TR_GetEndPosition(vStart, trace);
		if((GetVectorDistance(targetposition, vStart, false) + 75.0) >= GetVectorDistance(position, targetposition))
		{
			isVisible = true;
		}
		else
		{
			spawnPos = targetposition;
			spawnPos[2] += 40.0;
			MakeVectorFromPoints(spawnPos, position, vLookAt);
			GetVectorAngles(vLookAt, vAngles);
			Handle trace2 = TR_TraceRayFilterEx(spawnPos, vAngles, MASK_VISIBLE, RayType_Infinite, TraceFilter, client);
			if(TR_DidHit(trace2))
			{
				TR_GetEndPosition(vStart, trace2);
				if((GetVectorDistance(spawnPos, vStart, false) + 75.0) >= GetVectorDistance(position, spawnPos))
				isVisible = true;
			}
			else
			{
				isVisible = true;
			}
			delete trace2;
//			CloseHandle(trace2);
		}
	}
	else
	{
		isVisible = true;
	}
	delete trace;
//	CloseHandle(trace);
	return isVisible;
}

bool IsOnValidMesh(float fReferencePos[3])
{
	Address pNavArea = L4D2Direct_GetTerrorNavArea(fReferencePos);
	if (pNavArea != Address_Null)
	{
		return true;
	}
	else
	{
		return false;
	}
}
bool IsPlayerStuck(float fSpawnPos[3],int client)
{
	bool IsStuck = true;
	float fMins[3] = {0.0}, fMaxs[3] = {0.0}, fNewPos[3] = {0.0};
	GetClientMaxs(client,fMaxs);
	GetClientMins(client,fMins);
	fNewPos = fSpawnPos;
	fNewPos[2] += 80.0;
	TR_TraceHullFilter(fSpawnPos, fNewPos, fMins, fMaxs, MASK_NPCSOLID_BRUSHONLY, TraceRay_NoPlayers, client);
	IsStuck = TR_DidHit();
	return IsStuck;
}
public bool TraceRay_NoPlayers(int entity, int mask, any data)
{
    if(entity == data || (entity >= 1 && entity <= MaxClients))
    {
        return false;
    }
    return true;
}
public void TeleportTank(int client){
		static float fEyePos[3] = {0.0}, fSelfEyePos[3] = {0.0};
		GetClientEyePosition(client, fEyePos);
		float fSpawnPos[3] = {0.0}, fSurvivorPos[3] = {0.0}, fDirection[3] = {0.0}, fEndPos[3] = {0.0}, fMins[3] = {0.0}, fMaxs[3] = {0.0};
		int g_iTargetSurvivor=GetRandomSurvivor();
		if (IsValidSurvivor(g_iTargetSurvivor))
		{
			GetClientEyePosition(g_iTargetSurvivor, fSurvivorPos);
			GetClientEyePosition(client, fSelfEyePos);
			fMins[0] = fSurvivorPos[0] - 800;
			fMaxs[0] = fSurvivorPos[0] + 800;
			fMins[1] = fSurvivorPos[1] - 800;
			fMaxs[1] = fSurvivorPos[1] + 800;
			fMaxs[2] = fSurvivorPos[2] + 800;
			fDirection[0] = 90.0;
			fDirection[1] = fDirection[2] = 0.0;
			fSpawnPos[0] = GetRandomFloat(fMins[0], fMaxs[0]);
			fSpawnPos[1] = GetRandomFloat(fMins[1], fMaxs[1]);
			fSpawnPos[2] = GetRandomFloat(fSurvivorPos[2], fMaxs[2]);
			int count2=0;
			//PrintToConsoleAll("Tank找位置传送中.");
			while (PlayerVisibleTo(fSpawnPos) || !IsOnValidMesh(fSpawnPos)|| IsPlayerStuck(fSpawnPos,client))
			{
				count2 ++;
				if(count2 > 50)
				{
					break;
				}
				fSpawnPos[0] = GetRandomFloat(fMins[0], fMaxs[0]);
				fSpawnPos[1] = GetRandomFloat(fMins[1], fMaxs[1]);
				fSpawnPos[2] = GetRandomFloat(fSurvivorPos[2], fMaxs[2]);
				TR_TraceRay(fSpawnPos, fDirection, MASK_NPCSOLID_BRUSHONLY, RayType_Infinite);
				if(TR_DidHit())
				{
					TR_GetEndPosition(fEndPos);
					if(!IsOnValidMesh(fEndPos))
					{
						fSpawnPos[2] = fSurvivorPos[2] + 20.0;
						TR_TraceRay(fSpawnPos, fDirection, MASK_NPCSOLID_BRUSHONLY, RayType_Infinite);
						if(TR_DidHit())
						{
							TR_GetEndPosition(fEndPos);
							fSpawnPos = fEndPos;
							fSpawnPos[2] += 20.0;
						}
					}
					else
					{
						fSpawnPos = fEndPos;
						fSpawnPos[2] += 20.0;
					}
				}
			}
			if (count2<=50)
			{
				for (int count = 0; count < g_iSurvivorNum; count++)
				{
					int index = g_iSurvivors[count];
					if (IsClientInGame(index))
					{
						GetClientEyePosition(index, fSurvivorPos);
						fSurvivorPos[2] -= 40.0;
						if (L4D2_VScriptWrapper_NavAreaBuildPath(fSpawnPos, fSurvivorPos, 1500.0, false, false, TEAM_INFECTED, false))
						{
							//fSpawnPos[2] += 70.0;
							TeleportEntity(client, fSpawnPos, NULL_VECTOR, NULL_VECTOR);
							PrintToChatAll("\x03Tank被卡住了开始传送.");
						}
					}
				}
			}else{
				//PrintToConsoleAll("Tank没找到位置复活.");
			}
		}
}
public void Event_TankSpawn(Event hEvent, const char[] name, bool dontBroadcast) 
{
	if (!g_bEnabled) return;
	
	static int client;
	client = GetClientOfUserId(hEvent.GetInt("userid"));
	BeginTankTracing(client);
	BeginRusherTracing();		
}
public void Event_PlayerDeath(Event hEvent, const char[] name, bool dontBroadcast) 
{
	if (!g_bEnabled) return;
	
	static int client;
	client = GetClientOfUserId(hEvent.GetInt("userid"));
	
	if (client != 0) {
		if (IsTank(client)) {
			CreateTimer(1.0, Timer_UpdateTankCount, _, TIMER_FLAG_NO_MAPCHANGE);
		}
		else {
			if (GetClientTeam(client) == 2) {
				ResetClientStat(client);
			}
		}
	}
}
void ResetClientStat(int client)
{
	g_pos[client][0] = 0.0;
	g_pos[client][1] = 0.0;
	g_pos[client][2] = 0.0;
	g_iRushTimes[client] = 0;
}
public Action Event_RoundStart(Event hEvent, const char[] name, bool dontBroadcast) 
{
	OnMapStart();
}
public Action Event_RoundEnd(Event hEvent, const char[] name, bool dontBroadcast) 
{
	OnMapEnd();
}
public void Event_PlayerDisconnect(Event hEvent, const char[] name, bool dontBroadcast) 
{
	ResetClientStat(GetClientOfUserId(hEvent.GetInt("userid")));
}
public Action Timer_UpdateTankCount(Handle timer) {
	UpdateTankCount();
}

void UpdateTankCount() {
	static int cnt;
	cnt = 0;
	for (int i = 1; i <= MaxClients; i++)
		if (IsTank(i))
			cnt++;
	
	g_iTanksCount = cnt;
	
	if (cnt == 0) {
		if (g_hTimerRusher != INVALID_HANDLE) {
			CloseHandle (g_hTimerRusher);
			g_hTimerRusher = INVALID_HANDLE;
		}
	}
}
void BeginRusherTracing(bool bResetStat = true)
{
	if (g_hCvarRusherPunish.BoolValue) {
		
		if (bResetStat) {
			for (int i = 1; i <= MaxClients; i++) {
				if (IsClientInGame(i) && GetClientTeam(i) == 2 && !IsFakeClient(i)) {
					GetClientAbsOrigin(i, g_pos[i]);
					g_iRushTimes[i] = 0;
				}
			}
		}
		if (g_hCvarRusherPunish.BoolValue) {
			if (g_hTimerRusher == INVALID_HANDLE)
				g_hTimerRusher = CreateTimer(g_hCvarRusherCheckInterv.FloatValue, Timer_CheckRusher, _, TIMER_REPEAT);
		}
	}
}
public Action Timer_CheckRusher(Handle timer) {
	//PrintToConsoleAll("检测是否有跑男");
	static float pos[3], postank[3], distance;
	static int tank, i;
	
	if (g_iTanksCount == 1)
		return Plugin_Continue;
	
	
	for (i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && !IsFakeClient(i) && IsPlayerAlive(i))
		{
			GetClientAbsOrigin(i, pos);
			if (L4D_IsPlayerIncapacitated(i)||L4D_IsPlayerPinned(i)) {
				break;
			}
			
			if (GetSurvivorCountAlive() >= g_hCvarRusherMinPlayers.IntValue) {
				
				tank = GetNearestTank(i);
				
				if (tank != 0) {
					GetClientAbsOrigin(tank, postank);
				
					distance = GetVectorDistance(pos, postank, false);
					//增加限制条件，tank的路程图不能在生还者前面，否则会碰到刷tank后生还者距离过远，直接传送到生还者附近
					if (distance > g_hCvarRusherDist.FloatValue) {
						
						if (g_iRushTimes[i] >= g_hCvarRusherCheckTimes.IntValue && L4D2Direct_GetFlowDistance(tank)<L4D2Direct_GetFlowDistance(i) && !L4D_IsMissionFinalMap() && GetPlayerflowPercent(i)<98.0) {
							PrintToConsoleAll("tank与\x03%N的距离为：%f，坦克的路程为:%f，生还者的路程为:%f,生还者进度为：%f",distance,L4D2Direct_GetFlowDistance(tank),L4D2Direct_GetFlowDistance(i),GetPlayerflowPercent(i));
							TeleportToSurvivorInPlace(tank, i);
							PrintToChatAll("\x03%N \x04 因为当求生跑男，Tank开始传送惩罚.", i);
														
							g_iRushTimes[i] = 0;
						}
						else {
							g_iRushTimes[i]++;
						}
					}
					else {
						g_iRushTimes[i] = 0;
					}
				}
			}
		}
	}
	return Plugin_Continue;
}
float GetPlayerflowPercent(int client){
	return (L4D2Direct_GetFlowDistance(client)/L4D2Direct_GetMapMaxFlowDistance())*100.0;
}
/*
float GetFurthestUncappedSurvivorFlow(){
	float HighestFlow=0.0;
	for(int i=1;i<=MaxClients;i++)
		if(IsValidSurvivor(i))
			if(!L4D_IsPlayerIncapacitated(i)||!L4D_IsPlayerPinned(i)){
			float tmp=L4D2Direct_GetFlowDistance(i);
			if(tmp>HighestFlow)
				HighestFlow=tmp;
		}
	return HighestFlow;
}
*/
int GetNearestTank(int client) {
	static float tpos[3], spos[3], dist, mindist;
	static int iNearClient;
	iNearClient = 0;
	mindist = 0.0;
	GetClientAbsOrigin(client, tpos);
	
	for (int i = 1; i <= MaxClients; i++) {
		if (i != client && IsTank(i)) {
			GetClientAbsOrigin(i, spos);
			dist = GetVectorDistance(tpos, spos, false);
			if (dist < mindist || mindist < 0.1) {
				mindist = dist;
				iNearClient = i;
			}
		}
	}
	return iNearClient;
}
int GetSurvivorCountAlive() {
	static int cnt, i;
	cnt = 0;
	for (i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			cnt++;
	}
	return cnt;
}
void TeleportToSurvivorInPlace(int client, int survivor) {
	
	static float pos[3];
	GetClientAbsOrigin(survivor, pos);
	pos[0] += 10.0;
	pos[1] += 5.0;
	pos[2] += 5.0;
	
	TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR);
}
stock bool IsTank(int client)
{
	if( client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3 )
	{
		int class = GetEntProp(client, Prop_Send, "m_zombieClass");
		if( class == 8)
			return true;
	}
	return false;
}

public void OnMapStart() {
	static int i;
	g_hTimerRusher = INVALID_HANDLE;
	for (i = 1; i < MaxClients; i++)
		g_iTimes[i] = 0;
}
public void OnMapEnd() {
	g_iTanksCount = 0;
}

stock bool IsOnLadder(int entity)
{
	return GetEntityMoveType(entity) == MOVETYPE_LADDER;
}
public Action Timer_CheckPos(Handle timer, int UserId)
{
	//PrintToConsoleAll("开始检查tank是否卡住");
	static int tank;
	tank = GetClientOfUserId(UserId);
	if (tank != 0 && IsClientInGame(tank) && IsPlayerAlive(tank)) {
		
		static float pos[3];
		GetClientAbsOrigin(tank, pos);
		
		static float distance;
		distance = GetVectorDistance(pos, g_pos[tank], false);
		//PrintToConsoleAll("tank目前位置和前位置相差:%f",distance);
		if (distance < g_hCvarNonStuckRadius.FloatValue && !IsIncappedNearBy(pos) && !IsTankAttacking(tank)&&!IsOnLadder(tank)) {
			
			if ( g_iStuckTimes[tank] > 2) {
				TeleportTank(tank);
			}
			g_iStuckTimes[tank]++;
			//PrintToConsoleAll("tank检测卡住次数:%d",g_iStuckTimes[tank]);
		}
		else {
			g_iStuckTimes[tank] = 0;
		}
		
		g_pos[tank] = pos;
	}
	else
		return Plugin_Stop;
	
	return Plugin_Continue;
}
bool IsTankAttacking(int tank)
{
	return GetEntProp(tank, Prop_Send, "m_fireLayerSequence") > 0;
}
bool IsIncappedNearBy(float vOrigin[3])
{
	static int i;
	static float vOriginPlayer[3];
	
	for (i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && IsIncapped(i))
		{
			GetClientAbsOrigin(i, vOriginPlayer);
			if (GetVectorDistance(vOriginPlayer, vOrigin) <= g_fTankClawRange)
				return true;
		}
	}
	return false;
}


stock bool IsIncapped(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) == 1;
}
