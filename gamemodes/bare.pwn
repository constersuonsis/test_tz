#include <a_samp>
#include <sscanf2>
#include <streamer>
#include <Pawn.CMD>

#define MAX_BIKER_CLUBS 10
#define EVENT_DURATION 1800000
#define EVENT_COOLDOWN_MIN 5400000
#define EVENT_COOLDOWN_MAX 9000000
#define FACTION_ID_START 11

#define COLOR_LIGHTBLUE 0x5DADE2FF
#define COLOR_WHITE     0xFFFFFFFF
#define COLOR_RED       0xFF0000FF
#define STR_LIGHTBLUE   "{5DADE2}"
#define STR_WHITE       "{FFFFFF}"

main() {}

enum E_PLAYER_DATA {
    pMember,
    pRating,
    pAdmin
}
new PlayerInfo[MAX_PLAYERS][E_PLAYER_DATA];

enum E_FACTION_DATA {
    fBank,
    fMats,
    fRating
}
new FactionData[MAX_BIKER_CLUBS + FACTION_ID_START][E_FACTION_DATA];

new BikerClubNames[MAX_BIKER_CLUBS][] = {
    "Hells Angels MC",
    "Mongols MC",
    "Pagans MC",
    "Outlaws MC",
    "Sons of Silence MC",
    "Warlocks MC",
    "Highwaymen MC",
    "Bandidos MC",
    "Free Souls MC",
    "Vagos MC"
};

new Float:SpawnPoints[8][4] = {
    {2081.8970,-2006.9373,13.9873,269.4189},
    {2080.1389,-2019.8335,13.9837,269.6956},
    {2080.1313,-2033.3491,13.9844,270.4236},
    {2080.1367,-2046.9878,13.9845,268.8507},
    {-2449.1304,-120.7151,26.5687,93.3258},
    {-2447.6011,-125.1134,26.5827,93.3922},
    {1681.7417,2318.3223,11.2570,270.1104},
    {1680.8486,2358.8562,11.2536,270.8129}
};

new Float:DeliveryPoints[MAX_BIKER_CLUBS][4] = {
    {701.1597,-446.3981,16.3359,1.7994},
    {-1295.5288,2710.1636,50.0625,4.2569},
    {-2120.5686,-2496.7698,30.6250,49.8619},
    {-300.7595,1319.7745,54.2191,353.7889},
    {1238.4785,180.2144,20.0276,155.2165},
    {658.0650,1692.3461,6.9922,309.7694},
    {34.9405,-2639.2678,40.4264,274.4541},
    {-1941.2568,2402.6355,49.4922,291.1896},
    {-203.3469,2602.5283,62.7031,266.9708},
    {-314.6039,1753.0490,42.7547,91.2220}
};

new EventVehicle = INVALID_VEHICLE_ID;
new Text3D:EventLabel = Text3D:INVALID_3DTEXT_ID;
new EventActive = 0;
new EventStartTime;
new EventSpawnIndex;
new EventCurrentClub = -1;
new EventReminderTimer;
new EventMapIconTimer;
new EventTimeoutTimer;
new EventDriverID = INVALID_PLAYER_ID;

forward StartDeliveryEvent();
forward CheckDeliveryTimeout();
forward UpdateVehicleMapIcon();
forward CheckEventReminders();

public OnGameModeInit()
{
    SetTimer("StartDeliveryEvent", random(EVENT_COOLDOWN_MAX - EVENT_COOLDOWN_MIN) + EVENT_COOLDOWN_MIN, 0);
    return 1;
}

public OnPlayerConnect(playerid)
{
    PlayerInfo[playerid][pMember] = 0;
    PlayerInfo[playerid][pRating] = 0;
    PlayerInfo[playerid][pAdmin] = 0;
    return 1;
}

public OnPlayerCommandReceived(playerid, cmd[], params[], flags)
{
    return 1;
}

public OnPlayerCommandPerformed(playerid, cmd[], params[], result, flags)
{
    if(result == -1)
    {
        SendClientMessage(playerid, COLOR_RED, "Неизвестная команда!");
        return 0;
    }
    return 1;
}

CMD:startevent(playerid, params[])
{
    if(PlayerInfo[playerid][pAdmin] < 1)
    {
        SendClientMessage(playerid, COLOR_RED, "У вас нет прав на использование этой команды!");
        return 1;
    }
    
    if(PlayerInfo[playerid][pMember] < 1)
    {
        SendClientMessage(playerid, COLOR_RED, "Вы находитесь не в Байкерах!");
        return 1;
    }

    if(EventActive)
    {
        SendClientMessage(playerid, COLOR_RED, "Событие уже идет!");
        return 1;
    }
    
    StartDeliveryEvent();
    SendClientMessage(playerid, 0x00FF00FF, "Вы запустили событие 'Доставка деталей'.");
    return 1;
}

CMD:stopevent(playerid, params[])
{
    if(PlayerInfo[playerid][pAdmin] < 1)
    {
        SendClientMessage(playerid, COLOR_RED, "У вас нет прав на использование этой команды!");
        return 1;
    }
    
    if(!EventActive)
    {
        SendClientMessage(playerid, COLOR_RED, "Событие не активно.");
        return 1;
    }
    
    EndDeliveryEvent();
    SendClientMessage(playerid, 0x00FF00FF, "Вы остановили событие.");
    return 1;
}

CMD:setbiker(playerid, params[])
{
    if(PlayerInfo[playerid][pAdmin] < 1)
    {
        SendClientMessage(playerid, COLOR_RED, "У вас нет прав на использование этой команды!");
        return 1;
    }
    
    if(isnull(params))
    {
        SendClientMessage(playerid, 0xFFFFFFFF, "Использование: /setbiker [0-9]");
        return 1;
    }
    
    new club_idx = strval(params);
    if(club_idx < 0 || club_idx >= MAX_BIKER_CLUBS)
    {
        SendClientMessage(playerid, COLOR_RED, "Неверный ID клуба. Используйте от 0 до 9.");
        return 1;
    }
    
    PlayerInfo[playerid][pMember] = FACTION_ID_START + club_idx;
    
    new string[128];
    format(string, sizeof(string), "Вы установили себе фракцию: %s (ID: %d)", BikerClubNames[club_idx], club_idx);
    SendClientMessage(playerid, 0x00FF00FF, string);
    return 1;
}

CMD:setadmin(playerid, params[])
{
    new level;
    if(sscanf(params, "d", level)) level = 1;
    
    PlayerInfo[playerid][pAdmin] = level;
    
    new string[64];
    format(string, sizeof(string), "Вы установили себе админ уровень: %d", level);
    SendClientMessage(playerid, 0x00FF00FF, string);
    return 1;
}

CMD:veh(playerid, params[])
{
    if(PlayerInfo[playerid][pAdmin] < 1)
    {
        SendClientMessage(playerid, COLOR_RED, "У вас нет прав на использование этой команды!");
        return 1;
    }
    
    if(isnull(params))
    {
        SendClientMessage(playerid, 0xFFFFFFFF, "Использование: /veh [id модели]");
        return 1;
    }
    
    new modelid = strval(params);
    if(modelid < 400 || modelid > 611)
    {
        SendClientMessage(playerid, COLOR_RED, "Неверный ID модели транспорта (400-611)");
        return 1;
    }
    
    new Float:x, Float:y, Float:z, Float:a;
    GetPlayerPos(playerid, x, y, z);
    GetPlayerFacingAngle(playerid, a);
    
    new vehicleid = CreateVehicle(modelid, x, y, z + 1.0, a, -1, -1, -1);
    PutPlayerInVehicle(playerid, vehicleid, 0);
    
    new string[64];
    format(string, sizeof(string), "Создан транспорт ID: %d (модель: %d)", vehicleid, modelid);
    SendClientMessage(playerid, 0x00FF00FF, string);
    return 1;
}

CMD:eventstatus(playerid, params[])
{
    if(EventActive)
    {
        new string[256];
        format(string, sizeof(string), "Событие активно. Район спавна: %d. Клуб-владелец: %s", 
            EventSpawnIndex + 1, 
            EventCurrentClub == -1 ? "никто" : BikerClubNames[EventCurrentClub]);
        SendClientMessage(playerid, COLOR_LIGHTBLUE, string);
        
        new elapsed = (GetTickCount() - EventStartTime) / 60000;
        format(string, sizeof(string), "Прошло времени: %d минут. Осталось: %d минут", elapsed, 30 - elapsed);
        SendClientMessage(playerid, COLOR_WHITE, string);
    }
    else
    {
        SendClientMessage(playerid, COLOR_WHITE, "Событие не активно.");
    }
    return 1;
}

public StartDeliveryEvent()
{
    if(EventActive) return;
    
    EventActive = 1;
    EventSpawnIndex = random(sizeof(SpawnPoints));
    EventStartTime = GetTickCount();
    EventCurrentClub = -1;
    
    EventVehicle = CreateVehicle(455, SpawnPoints[EventSpawnIndex][0], SpawnPoints[EventSpawnIndex][1], 
                                  SpawnPoints[EventSpawnIndex][2], SpawnPoints[EventSpawnIndex][3], 0, 0, -1);
    
    EventLabel = CreateDynamic3DTextLabel("ГРУЗ С ДЕТАЛЯМИ\n(( Только для байкеров ))", COLOR_LIGHTBLUE, 0.0, 0.0, 0.0, 20.0, INVALID_PLAYER_ID, EventVehicle, 1);
    
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(IsPlayerConnected(i) && IsBiker(i))
        {
            SetPlayerMapIcon(i, 50, SpawnPoints[EventSpawnIndex][0], SpawnPoints[EventSpawnIndex][1], 
                           SpawnPoints[EventSpawnIndex][2], 51, 0, MAPICON_GLOBAL);
        }
    }
    
    new string[144];
    format(string, sizeof(string), STR_LIGHTBLUE "[Событие] " STR_WHITE "Начато событие: " STR_LIGHTBLUE "\"Доставка деталей\"" STR_WHITE ". Flatbed припаркован в районе " STR_LIGHTBLUE "%d", EventSpawnIndex + 1);
    SendMessageToAllBikers(string);
    SendMessageToAllBikers(STR_LIGHTBLUE "[Событие] " STR_WHITE "Заберите и доставьте груз в течение " STR_LIGHTBLUE "30" STR_WHITE " минут. Установлена метка на карте");
    
    EventMapIconTimer = SetTimer("UpdateVehicleMapIcon", 3000, 1);
    EventReminderTimer = SetTimer("CheckEventReminders", 60000, 1);
    EventTimeoutTimer = SetTimer("CheckDeliveryTimeout", EVENT_DURATION, 0);
}

public UpdateVehicleMapIcon()
{
    if(!EventActive || EventVehicle == INVALID_VEHICLE_ID) return;
    
    new Float:x, Float:y, Float:z;
    GetVehiclePos(EventVehicle, x, y, z);
    
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(IsPlayerConnected(i) && IsBiker(i))
        {
            SetPlayerMapIcon(i, 50, x, y, z, 51, 0, MAPICON_GLOBAL);
        }
    }
}

public CheckEventReminders()
{
    if(!EventActive) return;

    if(EventDriverID != INVALID_PLAYER_ID) return;

    new elapsedMinutes = (GetTickCount() - EventStartTime) / 60000;
    new remaining = 30 - elapsedMinutes;

    if(remaining == 20 || remaining == 10 || remaining == 5)
    {
        new string[144];
        format(string, sizeof(string), STR_LIGHTBLUE "[Событие] " STR_WHITE "Действует событие: " STR_LIGHTBLUE "\"Доставка деталей\"" STR_WHITE ". Flatbed припаркован в районе " STR_LIGHTBLUE "%d", EventSpawnIndex + 1);
        SendMessageToAllBikers(string);
        
        format(string, sizeof(string), STR_LIGHTBLUE "[Событие] " STR_WHITE "Заберите и доставьте груз в течение " STR_LIGHTBLUE "%d" STR_WHITE " минут. Установлена метка на карте", remaining);
        SendMessageToAllBikers(string);
    }
}

public CheckDeliveryTimeout()
{
    if(!EventActive) return;
    SendMessageToAllBikers(STR_LIGHTBLUE "[Событие] " STR_WHITE "Завершено событие: " STR_LIGHTBLUE "\"Доставка деталей\"" STR_WHITE ". Flatbed не был доставлен");
    EndDeliveryEvent();
}

public OnVehicleDeath(vehicleid, killerid)
{
    if(vehicleid == EventVehicle && EventActive)
    {
        SendMessageToAllBikers(STR_LIGHTBLUE "[Событие] " STR_WHITE "Завершено событие: " STR_LIGHTBLUE "\"Доставка деталей\"" STR_WHITE ". Flatbed был уничтожен");
        EndDeliveryEvent();
    }
    return 1;
}

public OnPlayerStateChange(playerid, newstate, oldstate)
{
    if(newstate == PLAYER_STATE_DRIVER && GetPlayerVehicleID(playerid) == EventVehicle && EventActive)
    {
        if(!IsBiker(playerid))
        {
            SendClientMessage(playerid, -1, STR_WHITE "Вы не байкер и не можете управлять этим транспортом!");
            RemovePlayerFromVehicle(playerid);
            return 1;
        }
        
        new club_idx = GetPlayerClubIndex(playerid);
        if(club_idx == -1) return 1;

        SetPlayerCheckpoint(playerid, DeliveryPoints[club_idx][0], DeliveryPoints[club_idx][1], DeliveryPoints[club_idx][2], 6.0);
        
        if(EventCurrentClub != -1 && EventCurrentClub != club_idx)
        {
            SendMessageToAllBikers(STR_LIGHTBLUE "[Событие] " STR_WHITE "Действует событие: " STR_LIGHTBLUE "\"Доставка деталей\"" STR_WHITE ".");
            
            new string[144];
            format(string, sizeof(string), STR_LIGHTBLUE "[Событие] " STR_WHITE "Flatbed перехвачен клубом " STR_LIGHTBLUE "%s" STR_WHITE ". Перехватите или уничтожьте транспорт", BikerClubNames[club_idx]);
            SendMessageToAllBikers(string);
        }
        else
        {
            new name[MAX_PLAYER_NAME];
            GetPlayerName(playerid, name, sizeof(name));
            SendMessageToClub(club_idx, STR_LIGHTBLUE "[Событие] " STR_WHITE "Действует событие: " STR_LIGHTBLUE "\"Доставка деталей\"" STR_WHITE ".");
            
            new string[144];
            format(string, sizeof(string), STR_LIGHTBLUE "[Событие] " STR_LIGHTBLUE "%s " STR_WHITE "находится за рулем Flatbed с деталями. Помогите в доставке деталей на склад фракции", name);
            SendMessageToClub(club_idx, string);
        }
        
        EventCurrentClub = club_idx;
        EventDriverID = playerid;
    }

    if(oldstate == PLAYER_STATE_DRIVER && GetPlayerVehicleID(playerid) == EventVehicle)
    {
        DisablePlayerCheckpoint(playerid);
    }
    return 1;
}

public OnPlayerExitVehicle(playerid, vehicleid)
{
    if(vehicleid == EventVehicle && playerid == EventDriverID)
    {
        EventDriverID = INVALID_PLAYER_ID;
    }
    return 1;
}

public OnPlayerEnterCheckpoint(playerid)
{
    if(EventActive && GetPlayerVehicleID(playerid) == EventVehicle && GetPlayerState(playerid) == PLAYER_STATE_DRIVER)
    {
        new club_idx = GetPlayerClubIndex(playerid);
        if(club_idx == -1) return 1;

        if(IsPlayerInRangeOfPoint(playerid, 8.0, DeliveryPoints[club_idx][0], DeliveryPoints[club_idx][1], DeliveryPoints[club_idx][2]))
        {
            new name[MAX_PLAYER_NAME];
            GetPlayerName(playerid, name, sizeof(name));
            new string[144];
            
            format(string, sizeof(string), STR_LIGHTBLUE "[Событие] " STR_WHITE "Завершено событие: " STR_LIGHTBLUE "\"Доставка деталей\"" STR_WHITE ". Груз был доставлен клубом %s", BikerClubNames[club_idx]);
            SendMessageToAllBikers(string);

            SendMessageToClub(club_idx, STR_LIGHTBLUE "[Событие] " STR_WHITE "Ваша фракция получила: 200000$ на банк клуба / 1500 рейтинга / 30000 материалов");
            
            format(string, sizeof(string), STR_LIGHTBLUE "[Событие] " STR_WHITE "Игрок %s получил за доставку груза: 100000$ / 1500 рейтинга", name);
            SendMessageToClub(club_idx, string);
            
            GivePlayerMoney(playerid, 100000);
            AddFactionBank(club_idx, 200000);
            AddFactionMaterials(club_idx, 30000);
            AddFactionRating(club_idx, 1500);
            AddPlayerRating(playerid, 1500);
            
            DisablePlayerCheckpoint(playerid);
            EndDeliveryEvent();
            
            SetTimer("StartDeliveryEvent", random(EVENT_COOLDOWN_MAX - EVENT_COOLDOWN_MIN) + EVENT_COOLDOWN_MIN, 0);
        }
    }
    return 1;
}

public OnPlayerClickMap(playerid, Float:fX, Float:fY, Float:fZ)
{
    if(GetPlayerState(playerid) == PLAYER_STATE_DRIVER) SetVehiclePos(GetPlayerVehicleID(playerid), fX, fY, fZ); else SetPlayerPos(playerid, fX, fY, fZ);
    return 1;
}

stock EndDeliveryEvent()
{
    if(EventVehicle != INVALID_VEHICLE_ID)
    {
        DestroyVehicle(EventVehicle);
        EventVehicle = INVALID_VEHICLE_ID;
    }
    
    if(IsValidDynamic3DTextLabel(EventLabel))
    {
        DestroyDynamic3DTextLabel(EventLabel);
        EventLabel = Text3D:INVALID_3DTEXT_ID;
    }
    
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(IsPlayerConnected(i))
        {
            if(IsBiker(i)) RemovePlayerMapIcon(i, 50);
            DisablePlayerCheckpoint(i);
        }
    }
    
    KillTimer(EventMapIconTimer);
    KillTimer(EventReminderTimer);
    KillTimer(EventTimeoutTimer);
    
    EventActive = 0;
    EventCurrentClub = -1;
    EventDriverID = INVALID_PLAYER_ID;
}

stock SendMessageToAllBikers(const text[])
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(IsPlayerConnected(i) && IsBiker(i)) SendClientMessage(i, -1, text);
    }
}

stock SendMessageToClub(club_idx, const text[])
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(IsPlayerConnected(i) && GetPlayerClubIndex(i) == club_idx) SendClientMessage(i, -1, text);
    }
}

// Был вариант еще такой, но при каждом вызове получается лишнаяя нагрузка, поэтому выбо принято решение в глобальную переменную засунуть.
/* stock GetVehicleDriver(vehicleid)
{
    for(new i = 0; i < MAX_PLAYERS; i++)
    {
        if(IsPlayerConnected(i) && GetPlayerState(i) == PLAYER_STATE_DRIVER && GetPlayerVehicleID(i) == vehicleid) return i;
    }
    return INVALID_PLAYER_ID;
} */

stock IsBiker(playerid)
{
    if(PlayerInfo[playerid][pMember] >= FACTION_ID_START && PlayerInfo[playerid][pMember] < FACTION_ID_START + MAX_BIKER_CLUBS)
    {
        return 1;
    }
    return 0;
}

stock GetPlayerClubIndex(playerid)
{
    if(!IsBiker(playerid)) return -1;
    return PlayerInfo[playerid][pMember] - FACTION_ID_START;
}

stock AddFactionBank(club_idx, amount)
{
    new real_faction_id = FACTION_ID_START + club_idx;
    FactionData[real_faction_id][fBank] += amount;
    return 1;
}

stock AddFactionMaterials(club_idx, amount)
{
    new real_faction_id = FACTION_ID_START + club_idx;
    FactionData[real_faction_id][fMats] += amount;
    return 1;
}

stock AddFactionRating(club_idx, amount)
{
    new real_faction_id = FACTION_ID_START + club_idx;
    FactionData[real_faction_id][fRating] += amount;
    return 1;
}

stock AddPlayerRating(playerid, amount)
{
    PlayerInfo[playerid][pRating] += amount;
    return 1;
}