//+------------------------------------------------------------------+
//|                                          BreakoutEATimeTest.mq5 |
//|                                  TEST TimeManager Implementation |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "BreakoutEA Team"
#property version   "1.00"
#property description "TEST: TimeManager Functionality with Timezone Detection"
#property strict

//+------------------------------------------------------------------+
//| Include Headers                                                  |
//+------------------------------------------------------------------+
#include "Enums.mqh"
#include "ConfigManager.mqh"
#include "TimeManager.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== CANDELE DI RIFERIMENTO ==="
input int CandeleRiferimento_Ora1 = 8;           
input int CandeleRiferimento_Minuti1 = 45;       
input int CandeleRiferimento_Ora2 = 14;          
input int CandeleRiferimento_Minuti2 = 45;       
input ENUM_TIMEFRAMES TimeframeRiferimento = PERIOD_M15;

input group "=== GESTIONE DEL RISCHIO ==="
input double RischioPercentuale = 0.5;           
input int LevaBroker = 100;                      
input double SpreadBufferPips = 2.0;            
input double MaxSpreadPips = 10.0;              

input group "=== TAKE PROFIT ==="
input int NumeroTakeProfit = 2;                 
input double TP1_RiskReward = 2.0;              
input double TP1_PercentualeVolume = 50.0;      
input double TP2_RiskReward = 3.0;              
input double TP2_PercentualeVolume = 50.0;      
input bool AttivareBreakevenDopoTP = true;      

input group "=== CALENDARIO TRADING ==="
input bool TradingLunedi = true;                
input bool TradingMartedi = true;               
input bool TradingMercoledi = true;             
input bool TradingGiovedi = true;               
input bool TradingVenerdi = true;               
input bool TradingSabato = false;               
input bool TradingDomenica = false;             

input group "=== TIME MANAGEMENT ==="
input int OffsetBroker_Ore = 0;                 // Offset manuale broker (fallback)

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
ConfigManager* g_configManager = NULL;
TimeManager* g_timeManager = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== BREAKOUT EA - TIMEMANAGER TEST ===");
   Print("Symbol: ", Symbol(), " | Timeframe: ", EnumToString(Period()));
   
   // Test 1: Inizializza ConfigManager
   Print("\n1. TESTING: ConfigManager Creation");
   if(!InitializeConfigManager())
   {
      Print("ERROR: ConfigManager initialization failed");
      return(INIT_FAILED);
   }
   Print("SUCCESS: ConfigManager initialized");
   
   // Test 2: Inizializza TimeManager
   Print("\n2. TESTING: TimeManager Creation");
   if(!InitializeTimeManager())
   {
      Print("ERROR: TimeManager initialization failed");
      return(INIT_FAILED);
   }
   Print("SUCCESS: TimeManager initialized");
   
   // Test 3: Test conversioni temporali
   Print("\n3. TESTING: Time Conversions");
   TestTimeConversions();
   
   // Test 4: Test timezone detection
   Print("\n4. TESTING: Timezone Detection");
   TestTimezoneDetection();
   
   // Test 5: Test orari trading
   Print("\n5. TESTING: Trading Hours Validation");
   TestTradingHours();
   
   // Test 6: Test ora legale
   Print("\n6. TESTING: DST Management");
   TestDSTManagement();
   
   // Test 7: Test orari sessioni
   Print("\n7. TESTING: Session Times");
   TestSessionTimes();
   
   Print("\n=== ALL TIMEMANAGER TESTS COMPLETED ===");
   
   // Timer per log continuo
   EventSetTimer(300); // Log ogni 5 minuti
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("=== TIMEMANAGER TEST SHUTDOWN ===");
   
   EventKillTimer();
   
   if(g_timeManager != NULL)
   {
      delete g_timeManager;
      g_timeManager = NULL;
   }
   
   if(g_configManager != NULL)
   {
      delete g_configManager;
      g_configManager = NULL;
   }
   
   Print("TimeManager test completed");
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   // Test minimale tick
   static int tickCount = 0;
   tickCount++;
   
   if(tickCount % 5000 == 0) // Ogni 5000 tick
   {
      Print("=== REALTIME TIME STATUS ===");
      LogCurrentTimeStatus();
   }
}

//+------------------------------------------------------------------+
//| Timer function - Log continuo                                  |
//+------------------------------------------------------------------+
void OnTimer()
{
   Print("\n=== TIMER: TIME STATUS UPDATE ===");
   LogCurrentTimeStatus();
   LogTradingStatus();
}

//+------------------------------------------------------------------+
//| Inizializza ConfigManager                                       |
//+------------------------------------------------------------------+
bool InitializeConfigManager()
{
   g_configManager = new ConfigManager();
   if(g_configManager == NULL) return false;
   
   if(!g_configManager.LoadParameters(
      RischioPercentuale, LevaBroker, SpreadBufferPips, MaxSpreadPips,
      CandeleRiferimento_Ora1, CandeleRiferimento_Minuti1, 
      CandeleRiferimento_Ora2, CandeleRiferimento_Minuti2, TimeframeRiferimento,
      NumeroTakeProfit, TP1_RiskReward, TP1_PercentualeVolume, 
      TP2_RiskReward, TP2_PercentualeVolume, AttivareBreakevenDopoTP,
      TradingLunedi, TradingMartedi, TradingMercoledi, TradingGiovedi, 
      TradingVenerdi, TradingSabato, TradingDomenica))
      return false;
   
   return g_configManager.ValidateParameters();
}

//+------------------------------------------------------------------+
//| Inizializza TimeManager                                         |
//+------------------------------------------------------------------+
bool InitializeTimeManager()
{
   g_timeManager = new TimeManager();
   if(g_timeManager == NULL) return false;
   
   // Usa parametro offset manuale dal ConfigManager
   return g_timeManager.Initialize(OffsetBroker_Ore);
}

//+------------------------------------------------------------------+
//| Test conversioni temporali                                      |
//+------------------------------------------------------------------+
void TestTimeConversions()
{
   if(g_timeManager == NULL) return;
   
   Print("--- TIME CONVERSIONS TEST ---");
   
   // Ottieni tempi attuali
   datetime brokerTime = g_timeManager.GetBrokerTime();
   datetime italianTime = g_timeManager.GetItalianTime();
   
   Print("Broker Time (Server): ", TimeToString(brokerTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS));
   Print("Italian Time (Converted): ", TimeToString(italianTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS));
   
   // Test conversione italiano → broker
   datetime testItalianTime = StringToTime("2025-06-10 15:30:00");
   datetime convertedToBroker = g_timeManager.ConvertItalianToBroker(testItalianTime);
   
   Print("Test IT→Broker: ", TimeToString(testItalianTime, TIME_DATE | TIME_MINUTES), 
         " → ", TimeToString(convertedToBroker, TIME_DATE | TIME_MINUTES));
   
   // Test conversione broker → italiano
   datetime testBrokerTime = TimeCurrent();
   datetime convertedToItalian = g_timeManager.ConvertBrokerToItalian(testBrokerTime);
   
   Print("Test Broker→IT: ", TimeToString(testBrokerTime, TIME_DATE | TIME_MINUTES),
         " → ", TimeToString(convertedToItalian, TIME_DATE | TIME_MINUTES));
}

//+------------------------------------------------------------------+
//| Test rilevamento timezone                                       |
//+------------------------------------------------------------------+
void TestTimezoneDetection()
{
   if(g_timeManager == NULL) return;
   
   Print("--- TIMEZONE DETECTION TEST ---");
   
   TimeZoneInfo italianTZ = g_timeManager.GetItalianTimeZone();
   TimeZoneInfo brokerTZ = g_timeManager.GetBrokerTimeZone();
   
   Print("=== ITALIAN TIMEZONE ===");
   Print("Name: ", italianTZ.timeZoneName);
   Print("Offset: GMT", italianTZ.offsetHours > 0 ? "+" : "", italianTZ.offsetHours);
   Print("DST Active: ", italianTZ.isDSTActive ? "YES" : "NO");
   
   Print("=== BROKER TIMEZONE ===");
   Print("Name: ", brokerTZ.timeZoneName);
   Print("Offset: GMT", brokerTZ.offsetHours > 0 ? "+" : "", brokerTZ.offsetHours);
   Print("DST Active: ", brokerTZ.isDSTActive ? "YES" : "NO");
   
   // Calcola differenza
   int timeDiff = brokerTZ.offsetHours - (italianTZ.offsetHours + (italianTZ.isDSTActive ? 1 : 0));
   Print("Time Difference: Broker is ", MathAbs(timeDiff), " hours ", 
         timeDiff > 0 ? "ahead of" : "behind", " Italy");
}

//+------------------------------------------------------------------+
//| Test orari di trading                                          |
//+------------------------------------------------------------------+
void TestTradingHours()
{
   if(g_timeManager == NULL) return;
   
   Print("--- TRADING HOURS TEST ---");
   
   datetime currentTime = g_timeManager.GetItalianTime();
   
   // Test giorno trading
   bool isTradingDay = g_timeManager.IsTradingDay(currentTime);
   Print("Is Trading Day: ", isTradingDay ? "YES" : "NO");
   
   // Test mercato aperto
   bool isMarketOpen = g_timeManager.IsMarketOpen(currentTime);
   Print("Is Market Open: ", isMarketOpen ? "YES" : "NO");
   
   // Test orari personalizzati
   TradingHours customHours(9, 0, 17, 30); // 9:00 - 17:30
   bool isWithinCustomHours = g_timeManager.IsWithinTradingHours(customHours, currentTime);
   Print("Within Custom Hours (9:00-17:30): ", isWithinCustomHours ? "YES" : "NO");
   
   // Test orari sessioni
   SessionConfig sessionConfig = g_configManager.GetSessionConfig();
   TradingHours session1Hours(sessionConfig.referenceHour1, sessionConfig.referenceMinute1,
                             sessionConfig.referenceHour1 + 1, sessionConfig.referenceMinute1);
   bool isSession1Time = g_timeManager.IsWithinTradingHours(session1Hours, currentTime);
   Print("Within Session1 Hours: ", isSession1Time ? "YES" : "NO");
}

//+------------------------------------------------------------------+
//| Test gestione ora legale                                       |
//+------------------------------------------------------------------+
void TestDSTManagement()
{
   if(g_timeManager == NULL) return;
   
   Print("--- DST MANAGEMENT TEST ---");
   
   datetime currentTime = g_timeManager.GetItalianTime();
   
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   
   // Test DST corrente
   bool isDSTActive = g_timeManager.IsDSTActive(currentTime);
   Print("Current DST Status: ", isDSTActive ? "ACTIVE (Summer Time)" : "INACTIVE (Winter Time)");
   
   // Test date DST anno corrente
   datetime dstStart = g_timeManager.GetDSTStartDate(dt.year);
   datetime dstEnd = g_timeManager.GetDSTEndDate(dt.year);
   
   Print("DST ", dt.year, " Period:");
   Print("  Start: ", TimeToString(dstStart, TIME_DATE | TIME_MINUTES), " (Last Sunday of March)");
   Print("  End: ", TimeToString(dstEnd, TIME_DATE | TIME_MINUTES), " (Last Sunday of October)");
   
   // Test posizione corrente nel periodo DST
   if(currentTime < dstStart)
      Print("  Current: BEFORE DST period (Winter Time)");
   else if(currentTime >= dstStart && currentTime < dstEnd)
      Print("  Current: WITHIN DST period (Summer Time)");
   else
      Print("  Current: AFTER DST period (Winter Time)");
}

//+------------------------------------------------------------------+
//| Test orari sessioni configurate                                |
//+------------------------------------------------------------------+
void TestSessionTimes()
{
   if(g_configManager == NULL || g_timeManager == NULL) return;
   
   Print("--- SESSION TIMES TEST ---");
   
   SessionConfig sessionConfig = g_configManager.GetSessionConfig();
   
   // Calcola tempi sessioni in italiano
   datetime session1TimeIT = CalculateSessionTime(sessionConfig.referenceHour1, sessionConfig.referenceMinute1);
   datetime session2TimeIT = CalculateSessionTime(sessionConfig.referenceHour2, sessionConfig.referenceMinute2);
   
   // Converti in orario broker
   datetime session1TimeBroker = g_timeManager.ConvertItalianToBroker(session1TimeIT);
   datetime session2TimeBroker = g_timeManager.ConvertItalianToBroker(session2TimeIT);
   
   Print("=== SESSION 1 ===");
   Print("Italian Time: ", TimeToString(session1TimeIT, TIME_DATE | TIME_MINUTES));
   Print("Broker Time: ", TimeToString(session1TimeBroker, TIME_DATE | TIME_MINUTES));
   
   Print("=== SESSION 2 ===");
   Print("Italian Time: ", TimeToString(session2TimeIT, TIME_DATE | TIME_MINUTES));
   Print("Broker Time: ", TimeToString(session2TimeBroker, TIME_DATE | TIME_MINUTES));
}

//+------------------------------------------------------------------+
//| Calcola tempo sessione                                         |
//+------------------------------------------------------------------+
datetime CalculateSessionTime(int hour, int minute)
{
   datetime currentTime = g_timeManager.GetItalianTime();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   
   dt.hour = hour;
   dt.min = minute;
   dt.sec = 0;
   
   return StructToTime(dt);
}

//+------------------------------------------------------------------+
//| Log status temporale corrente                                  |
//+------------------------------------------------------------------+
void LogCurrentTimeStatus()
{
   if(g_timeManager == NULL) return;
   
   datetime brokerTime = g_timeManager.GetBrokerTime();
   datetime italianTime = g_timeManager.GetItalianTime();
   
   TimeZoneInfo brokerTZ = g_timeManager.GetBrokerTimeZone();
   TimeZoneInfo italianTZ = g_timeManager.GetItalianTimeZone();
   
   Print(">>> CURRENT TIME STATUS <<<");
   Print("Broker Server Time: ", TimeToString(brokerTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS));
   Print("Broker Timezone: ", brokerTZ.timeZoneName, " (GMT", 
         brokerTZ.offsetHours > 0 ? "+" : "", brokerTZ.offsetHours, ")");
   Print("Italian Time (Converted): ", TimeToString(italianTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS));
   Print("Italian Timezone: ", italianTZ.timeZoneName, " (GMT", 
         italianTZ.offsetHours > 0 ? "+" : "", italianTZ.offsetHours,
         ", DST: ", italianTZ.isDSTActive ? "ON" : "OFF", ")");
}

//+------------------------------------------------------------------+
//| Log status trading                                             |
//+------------------------------------------------------------------+
void LogTradingStatus()
{
   if(g_timeManager == NULL) return;
   
   datetime italianTime = g_timeManager.GetItalianTime();
   
   Print(">>> TRADING STATUS <<<");
   Print("Trading Day: ", g_timeManager.IsTradingDay(italianTime) ? "YES" : "NO");
   Print("Market Open: ", g_timeManager.IsMarketOpen(italianTime) ? "YES" : "NO");
   Print("DST Active: ", g_timeManager.IsDSTActive(italianTime) ? "YES (Summer)" : "NO (Winter)");
}