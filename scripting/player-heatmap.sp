/* ****************************************************************
    player-heatmap: Draw player heatmaps in Team Fortress 2.
    See: https://github.com/laurirasanen/demo-heatmap

    Copyright (C) 2020  Lauri Räsänen

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
**************************************************************** */

#include <sourcemod>
#include <sdktools>
#include <morecolors>
#include <string>

#pragma semicolon 1
#pragma newdecls required

#define MAX_TICKS 40000 // 10 minutes
#define MAX_LINE (MAX_TICKS * 8 * 4) // wild guess
#define MAX_TE 32
#define MAX_VEL 91 // sqrt( (sqrt(3500^2 + 3500^2))^2 + 3500^2) / 66.666666
#define MAX_VEL_AXIS 52.5 // 3500 / 66.666666

char g_cPrintPrefix[] = "[{orange}heatmap{white}]";

float g_fPositions[64][MAX_TICKS][3];
float g_fBeamPoints[MAX_TICKS][2][3];

int g_iTicks[64][MAX_TICKS];
int g_iBeamModel;
int g_iBeamColors[MAX_TICKS][4];

bool g_bSpawning;

public Plugin myinfo =
{
    name = "player-heatmap",
    author = "laurirasanen",
    description = "Draw player positions from demo-heatmap output",
    version = "1.0.0",
    url = "https://github.com/laurirasanen"
};

public void OnPluginStart()
{
	g_iBeamModel = PrecacheModel("materials/sprites/laserbeam.vmt", true);
    RegConsoleCmd("hm_load", CmdLoad, "");
}

public void OnGameFrame()
{
	if (g_bSpawning)
	{
		int spawned = 0;
		for (int i = 0; i < MAX_TICKS; i++)
		{
			if (g_iBeamColors[i][0] != -1)
			{
				TE_SetupBeamPoints(g_fBeamPoints[i][0], g_fBeamPoints[i][1], g_iBeamModel, g_iBeamModel, 0, 0, 0, 4.0, 4.0, 1, 0.0, g_iBeamColors[i], 0);
				TE_SendToAll();
				/*PrintToServer("Drawing from (%f, %f, %f) to (%f, %f, %f), color: (%d, %d, %d, %d)", 
					g_fBeamPoints[i][0][0], g_fBeamPoints[i][0][1], g_fBeamPoints[i][0][2], 
					g_fBeamPoints[i][1][0], g_fBeamPoints[i][1][1], g_fBeamPoints[i][1][2], 
					g_iBeamColors[i][0], g_iBeamColors[i][1], g_iBeamColors[i][2], g_iBeamColors[i][3]);*/
				spawned++;

				g_iBeamColors[i] = {-1, -1, -1, -1};

				if (spawned >= MAX_TE)
				{
					return;
				}
			}

			if (i == MAX_TICKS - 1)
			{
				g_bSpawning = false;
				CPrintToChatAll("%s Done spawning!", g_cPrintPrefix);
			}
		}
	}	
}

public Action CmdLoad(int client, int args)
{
	if (g_bSpawning)
	{
		CPrintToChat(client, "%s Can not load more data while still spawning old TEs", g_cPrintPrefix);
        return Plugin_Handled;
	}

    if(args < 1)
    {
        CPrintToChat(client, "%s Missing file name argument", g_cPrintPrefix);
        return Plugin_Handled;
    }

    // Get file name
    char arg[64];
    GetCmdArg(1, arg, sizeof(arg));

    char cPath[64] = "/heatmaps/";
    StrCat(cPath, sizeof(cPath), arg);

    if (!FileExists(cPath))
    {
    	CPrintToChat(client, "%s Could not find file '%s'", g_cPrintPrefix, cPath);
    	return Plugin_Handled;
    }

    for (int i = 0; i < MaxClients; i++)
    {
    	for (int j = 0; j < MAX_TICKS; j++)
    	{
    		g_iTicks[i][j] = -1;
    	}
    }

    File hFile = OpenFile(cPath, "r");
	char[] cLine = new char[MAX_LINE];
	int player = 0;

	// Comma delimited format:
	// <int> tick, <float> x, <float> y, <float> z, ...
	
	// Each new line is another player 

	while(hFile.ReadLine(cLine, MAX_LINE))
	{
		char buffer[MAX_TICKS * 4][8];
		int n = ExplodeString(cLine, ",", buffer, MAX_TICKS * 4, 8);

		int tick = -1;
		for (int i = 0; i < n; i++)
		{
			int j = i % 4;

			if (j == 0)
			{
				tick++;
				g_iTicks[player][tick] = StringToInt(buffer[i]);
			}
			else
			{
				g_fPositions[player][tick][j-1] = StringToFloat(buffer[i]);
			}
		}

		player++;
	}
	
	DrawLines();

    return Plugin_Handled;
}

public void GetColor(float velocity, int[] velocityColor)
{
	// Shift from red to green while velocity is between 0 and 0.5 of max,
	// shift from green to blue while velocity is between 0.5 and 1.0 of max.
	int fSpeedColor = RoundFloat(2.0 * 255.0 * velocity / MAX_VEL_AXIS);

	if (fSpeedColor <= 255)
	{
		// Reduce red, increase green
		velocityColor[0] = 255 - fSpeedColor;
		velocityColor[1] = fSpeedColor;
		velocityColor[2] = 0;
	}
	else if (fSpeedColor > 255 && fSpeedColor <= 510)
	{
		// Reduce green, increase blue
		velocityColor[0] = 0;
		velocityColor[1] = 510 - fSpeedColor;
		velocityColor[2] = fSpeedColor - 255;
	}
	else
	{
		velocityColor[0] = 0;
		velocityColor[1] = 0;
		velocityColor[2] = 255;
	}
	
	// Full alpha
	velocityColor[3] = 255;
}

public void DrawLines() 
{
	int players = 0;
	int positions = 0;

	for (int i = 0; i < MaxClients; i++)
	{
		if (g_iTicks[i][0] == -1)
		{
			break;
		}

		for (int j = 1; j < MAX_TICKS; j++)
		{
			float start[3];
			start[0] = g_fPositions[i][j - 1][0];
			start[1] = g_fPositions[i][j - 1][1];
			start[2] = g_fPositions[i][j - 1][2];

			float end[3];
			end[0] = g_fPositions[i][j][0];
			end[1] = g_fPositions[i][j][1];
			end[2] = g_fPositions[i][j][2];

			int prevTick = g_iTicks[i][j - 1];
			int tick = g_iTicks[i][j];
			if (tick == -1)
			{
				break;
			}

			int time = tick - prevTick;
			if (time > 4)
			{
				// STV demos record positions every 4 ticks,
				// player died, respawned, etc..
				continue;
			}

			float distance = GetVectorDistance(start, end, false);
			if (distance <= 0.1)
			{
				// Not moving
				continue;
			}

			float velocity = distance / time;

			if (velocity > MAX_VEL)
			{
				// Over max vel, teleported?
				continue;
			}			

			int c[4];
			GetColor(velocity, c);

			// https://developer.valvesoftware.com/wiki/Temporary_entity
			// TEs are unreliable and get dropped if too many are created at once.
			// The maximum per update is 32 in multiplayer and 255 in single player.

			// Add points to a list to spawn every frame until empty
			g_fBeamPoints[j][0] = start;
			g_fBeamPoints[j][1] = end;
			g_iBeamColors[j] = c;
			g_bSpawning = true;
			positions++;			
		}

		players++;
	}

	CPrintToChatAll("%s Loaded {lightgreen}%d{white} positions from {lightgreen}%d{white} players!", g_cPrintPrefix, positions, players);
	CPrintToChatAll("%s Spawning {lightgreen}%d{white} TEs per frame... ETA: {lightgreen}%d{white}s", g_cPrintPrefix, MAX_TE, RoundFloat(positions / (MAX_TE / GetTickInterval())));
}