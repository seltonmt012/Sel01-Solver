#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>

public Plugin myinfo =
{
	name = "R8 Buy",
	author = "Selt",
	description = "Buy the R8 Revolver with !r8",
	version = "1.0"
};

ConVar g_Enabled;
ConVar g_Price;
ConVar g_RequireBuyzone;

public void OnPluginStart()
{
	g_Enabled = CreateConVar("sm_r8_enabled", "1", "Enable plugin", _, true, 0.0, true, 1.0);
	g_Price = CreateConVar("sm_r8_price", "600", "Buy price", _, true, 0.0);
	g_RequireBuyzone = CreateConVar("sm_r8_require_buyzone", "1", "Require buy zone", _, true, 0.0, true, 1.0);

	RegConsoleCmd("sm_r8", Cmd_R8);

	AutoExecConfig(true, "r8buy");
}

public Action Cmd_R8(int client, int args)
{
	if (!g_Enabled.BoolValue)
		return Plugin_Handled;

	if (client <= 0 || !IsClientInGame(client))
		return Plugin_Handled;

	if (!IsPlayerAlive(client))
	{
		PrintToChat(client, "[R8] You must be alive.");
		return Plugin_Handled;
	}

	if (g_RequireBuyzone.BoolValue && !GetEntProp(client, Prop_Send, "m_bInBuyZone"))
	{
		PrintToChat(client, "[R8] Only in the buy zone.");
		return Plugin_Handled;
	}

	int price = g_Price.IntValue;
	int money = GetEntProp(client, Prop_Send, "m_iAccount");
	if (money < price)
	{
		PrintToChat(client, "[R8] Not enough money (need $%d).", price);
		return Plugin_Handled;
	}

	int sec = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
	if (sec != -1)
	{
		RemovePlayerItem(client, sec);
		RemoveEntity(sec);
	}

	GivePlayerItem(client, "weapon_revolver");
	SetEntProp(client, Prop_Send, "m_iAccount", money - price);

	PrintToChat(client, "[R8] R8 purchased (-$%d).", price);
	return Plugin_Handled;
}
