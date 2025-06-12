//+------------------------------------------------------------------+
//|                                                  TimeManager.mqh |
//|                                    Broker Time System - Simplified |
//|                                              Single Responsibility |
//+------------------------------------------------------------------+

#ifndef TIME_MANAGER_MQH
#define TIME_MANAGER_MQH

#include "Enums.mqh"

//+------------------------------------------------------------------+
//| Strutture per gestione tempo                                    |
//+------------------------------------------------------------------+
struct TradingHours
{
    int startHour;          // Ora inizio trading
    int startMinute;        // Minuto inizio trading
    int endHour;            // Ora fine trading  
    int endMinute;          // Minuto fine trading
    bool isActive;          // Se questo orario è attivo
    
    TradingHours() : startHour(0), startMinute(0), endHour(23), endMinute(59), isActive(true) {}
    TradingHours(int sH, int sM, int eH, int eM) : startHour(sH), startMinute(sM), endHour(eH), endMinute(eM), isActive(true) {}
};

//+------------------------------------------------------------------+
//| TimeManager Class - Broker Time System                         |
//+------------------------------------------------------------------+
class TimeManager
{
public:
    TimeManager();
    ~TimeManager();
    
    // Main DST Session Functions
    int GetActualSessionHour(int baseHour, bool isSummerTime);
    int GetActualSessionMinute(int baseMinute);
    datetime CreateBrokerSessionTime(int baseHour, int baseMinute, bool isSummerTime);
    
    // Broker Time Functions
    datetime GetBrokerTime();
    
    // Validation Functions
    bool IsWithinTradingHours(const TradingHours& hours, datetime timeToCheck = 0);
    bool IsTradingDay(datetime timeToCheck = 0);
    bool IsMarketOpen(datetime timeToCheck = 0);
    
    // Utility Functions
    void LogSessionTime(const string sessionName, int baseHour, int baseMinute, bool isSummerTime);

private:
    datetime CreateDateTime(int year, int month, int day, int hour = 0, int minute = 0);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
TimeManager::TimeManager()
{
    // Costruttore semplificato - no timezone detection
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
TimeManager::~TimeManager()
{
}

//+------------------------------------------------------------------+
//| Calcola ora sessione effettiva con DST                         |
//+------------------------------------------------------------------+
int TimeManager::GetActualSessionHour(int baseHour, bool isSummerTime)
{
    return (baseHour + (isSummerTime ? 1 : 0)) % 24;
}

//+------------------------------------------------------------------+
//| Calcola minuto sessione (invariato)                            |
//+------------------------------------------------------------------+
int TimeManager::GetActualSessionMinute(int baseMinute)
{
    return baseMinute; // Minuti non cambiano con DST
}

//+------------------------------------------------------------------+
//| Crea datetime sessione in orario broker diretto                |
//+------------------------------------------------------------------+
datetime TimeManager::CreateBrokerSessionTime(int baseHour, int baseMinute, bool isSummerTime)
{
    int actualHour = GetActualSessionHour(baseHour, isSummerTime);
    
    datetime currentBrokerTime = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(currentBrokerTime, dt);
    
    dt.hour = actualHour;
    dt.min = baseMinute;
    dt.sec = 0;
    
    return StructToTime(dt);
}

//+------------------------------------------------------------------+
//| Ottiene orario corrente del broker                             |
//+------------------------------------------------------------------+
datetime TimeManager::GetBrokerTime()
{
    return TimeCurrent(); // MT5 restituisce sempre orario broker
}

//+------------------------------------------------------------------+
//| Log informazioni sessione                                      |
//+------------------------------------------------------------------+
void TimeManager::LogSessionTime(const string sessionName, int baseHour, int baseMinute, bool isSummerTime)
{
    int actualHour = GetActualSessionHour(baseHour, isSummerTime);
    datetime sessionTime = CreateBrokerSessionTime(baseHour, baseMinute, isSummerTime);
    
    Print("=== ", sessionName, " ===");
    Print("Base Time: ", baseHour, ":", StringFormat("%02d", baseMinute), " (winter)");
    Print("Actual Time: ", actualHour, ":", StringFormat("%02d", baseMinute), " (broker)");
    Print("DST Applied: ", isSummerTime ? "YES (+1h)" : "NO");
    Print("Session DateTime: ", TimeToString(sessionTime, TIME_DATE | TIME_MINUTES));
}

//+------------------------------------------------------------------+
//| Verifica se siamo negli orari di trading                       |
//+------------------------------------------------------------------+
bool TimeManager::IsWithinTradingHours(const TradingHours& hours, datetime timeToCheck = 0)
{
    if(!hours.isActive) return false;
    
    if(timeToCheck == 0) timeToCheck = GetBrokerTime();
    
    MqlDateTime dt;
    TimeToStruct(timeToCheck, dt);
    
    // Converti orari in minuti per confronto semplice
    int currentMinutes = dt.hour * 60 + dt.min;
    int startMinutes = hours.startHour * 60 + hours.startMinute;
    int endMinutes = hours.endHour * 60 + hours.endMinute;
    
    // Gestione orari che attraversano mezzanotte
    if(endMinutes < startMinutes)
    {
        return (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
    }
    else
    {
        return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
    }
}

//+------------------------------------------------------------------+
//| Verifica se è un giorno di trading                             |
//+------------------------------------------------------------------+
bool TimeManager::IsTradingDay(datetime timeToCheck = 0)
{
    if(timeToCheck == 0) timeToCheck = GetBrokerTime();
    
    MqlDateTime dt;
    TimeToStruct(timeToCheck, dt);
    
    // Lunedì = 1, Domenica = 0
    // Trading: Lunedì-Venerdì (1-5)
    return (dt.day_of_week >= 1 && dt.day_of_week <= 5);
}

//+------------------------------------------------------------------+
//| Verifica se il mercato è aperto (semplificato)                 |
//+------------------------------------------------------------------+
bool TimeManager::IsMarketOpen(datetime timeToCheck = 0)
{
    if(timeToCheck == 0) timeToCheck = GetBrokerTime();
    
    // Controlla se è giorno di trading
    if(!IsTradingDay(timeToCheck)) return false;
    
    // Orari standard Forex approssimativi in broker time
    // Questa è una validazione base - può essere customizzata
    MqlDateTime dt;
    TimeToStruct(timeToCheck, dt);
    
    // Evita orari di chiusura tipici (es. 22:00-00:00 broker time)
    // Questa logica può essere personalizzata in base al broker
    if(dt.hour >= 22 || dt.hour < 1)
        return false;
        
    return true;
}

//+------------------------------------------------------------------+
//| Crea datetime da componenti                                    |
//+------------------------------------------------------------------+
datetime TimeManager::CreateDateTime(int year, int month, int day, int hour = 0, int minute = 0)
{
    MqlDateTime dt;
    dt.year = year;
    dt.mon = month;
    dt.day = day;
    dt.hour = hour;
    dt.min = minute;
    dt.sec = 0;
    
    return StructToTime(dt);
}

#endif // TIME_MANAGER_MQH