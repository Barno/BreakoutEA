//+------------------------------------------------------------------+
//|                                               BreakoutEA.mq5    |
//|                                  Strategia Breakout Bidirezionale |
//|                                      Con TimeManager e ChartVisualizer |
//+------------------------------------------------------------------+
#property copyright "BreakoutEA Team"
#property version   "1.00"
#property description "Strategia Breakout Bidirezionale con Timezone Detection"
#property strict

//+------------------------------------------------------------------+
//| Include Headers                                                  |
//+------------------------------------------------------------------+
#include "Enums.mqh"
#include "ConfigManager.mqh"
#include "ChartVisualizer.mqh"
#include "TimeManager.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== CANDELE DI RIFERIMENTO ORARIO ITA ==="
input int CandeleRiferimento_Ora1 = 8;           
input int CandeleRiferimento_Minuti1 = 45;       
input int CandeleRiferimento_Ora2 = 15;          
input int CandeleRiferimento_Minuti2 = 15;       
input ENUM_TIMEFRAMES TimeframeRiferimento = PERIOD_M15;
input color ColoreLineaVerticale = clrRed;        

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

input group "=== VISUALIZZAZIONE ==="
input int LineWidth = 1;                        
input ENUM_LINE_STYLE LineStyle = STYLE_SOLID;  

input group "=== TIME MANAGEMENT ==="
input int OffsetBroker_Ore = 0;                 // Offset manuale broker (fallback)
input bool EnableAutoDetection = true;          // Abilita auto-detection timezone

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
ConfigManager* g_configManager = NULL;
ChartVisualizer* g_chartVisualizer = NULL;
TimeManager* g_timeManager = NULL;

bool g_isInitialized = false;
datetime g_lastVisualizationUpdate = 0;
datetime g_lastCleanupCheck = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== BREAKOUT EA WITH TIMEZONE DETECTION ===");
   Print("Symbol: ", Symbol(), " | Timeframe: ", EnumToString(Period()));
   
   g_isInitialized = false;
   
   // Step 1: Inizializza ConfigManager
   Print("\n1. INITIALIZING: ConfigManager");
   if(!InitializeConfigManager())
   {
      Print("ERROR: ConfigManager initialization failed");
      return(INIT_FAILED);
   }
   Print("SUCCESS: ConfigManager initialized");
   
   // Step 2: Inizializza TimeManager
   Print("\n2. INITIALIZING: TimeManager");
   if(!InitializeTimeManager())
   {
      Print("ERROR: TimeManager initialization failed");
      return(INIT_FAILED);
   }
   Print("SUCCESS: TimeManager initialized");
   
   // Step 3: Test timezone detection
   Print("\n3. TESTING: Timezone Detection");
   TestBrokerTimezoneDetection();
   
   // Step 4: Inizializza ChartVisualizer  
   Print("\n4. INITIALIZING: ChartVisualizer");
   if(!InitializeChartVisualizer())
   {
      Print("ERROR: ChartVisualizer initialization failed");
      return(INIT_FAILED);
   }
   Print("SUCCESS: ChartVisualizer initialized");
   
   // Step 5: Disegna righe iniziali
   Print("\n5. DRAWING: Initial Reference Lines");
   DrawInitialReferenceLines();
   
   // Step 6: Setup timer
   EventSetTimer(300); // Timer ogni 5 minuti
   
   g_isInitialized = true;
   g_lastVisualizationUpdate = TimeCurrent();
   g_lastCleanupCheck = TimeCurrent();
   
   Print("\n=== BREAKOUT EA INITIALIZED SUCCESSFULLY ===");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("=== BREAKOUT EA SHUTTING DOWN ===");
   Print("Reason: ", GetDeinitReasonText(reason));
   
   EventKillTimer();
   
   // Cleanup in reverse order
   if(g_chartVisualizer != NULL)
   {
      g_chartVisualizer.CleanupAllLines();
      delete g_chartVisualizer;
      g_chartVisualizer = NULL;
   }
   
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
   
   g_isInitialized = false;
   
   Print("=== BREAKOUT EA SHUTDOWN COMPLETED ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_isInitialized) return;
   
   // Check aggiornamento visualizzazione
   datetime currentTime = TimeCurrent();
   if(ShouldUpdateVisualization(currentTime))
   {
      UpdateReferenceLines();
      g_lastVisualizationUpdate = currentTime;
   }
   
   // TODO: Logica trading principale
}

//+------------------------------------------------------------------+
//| Timer function                                                  |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(!g_isInitialized) return;
   
   datetime currentTime = TimeCurrent();
   
   // Cleanup periodico
   if(currentTime - g_lastCleanupCheck > 86400) // 24 ore
   {
      Print("Timer: Performing periodic cleanup...");
      if(g_chartVisualizer != NULL)
      {
         g_chartVisualizer.CleanupPreviousDayLines();
      }
      g_lastCleanupCheck = currentTime;
   }
   
   // Log timezone status periodico
   Print("\n=== TIMER: TIMEZONE STATUS UPDATE ===");
   LogCurrentTimezoneStatus();
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
   
   g_timeManager.EnableAutoDetection(EnableAutoDetection);
   return g_timeManager.Initialize(OffsetBroker_Ore);
}

//+------------------------------------------------------------------+
//| Inizializza ChartVisualizer                                     |
//+------------------------------------------------------------------+
bool InitializeChartVisualizer()
{
   g_chartVisualizer = new ChartVisualizer();
   if(g_chartVisualizer == NULL) return false;
   
   return g_chartVisualizer.Initialize(ColoreLineaVerticale, LineWidth, LineStyle);
}

//+------------------------------------------------------------------+
//| Test rilevamento timezone broker                               |
//+------------------------------------------------------------------+
void TestBrokerTimezoneDetection()
{
   if(g_timeManager == NULL) return;
   
   Print("\n--- BROKER TIMEZONE DETECTION (Enhanced) ---");
   
   // Dati temporali raw con TimeTradeServer (più preciso)
   MqlDateTime serverDt;
   datetime serverTime = TimeTradeServer(serverDt);
   datetime currentTime = TimeCurrent();
   datetime gmtTime = TimeGMT();
   
   Print("=== RAW TIME DATA (Enhanced Detection) ===");
   Print("Server Time (TimeTradeServer): ", TimeToString(serverTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS));
   Print("Current Time (TimeCurrent): ", TimeToString(currentTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS));
   Print("GMT Time: ", TimeToString(gmtTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS));
   
   // Mostra differenza tra TimeTradeServer e TimeCurrent
   int diffSeconds = (int)(serverTime - currentTime);
   if(diffSeconds != 0)
   {
      Print("IMPORTANT: TimeTradeServer vs TimeCurrent difference: ", diffSeconds, " seconds");
      Print("Using TimeTradeServer for more accurate timezone detection");
   }
   else
   {
      Print("TimeTradeServer and TimeCurrent are synchronized");
   }
   
   // Calcolo offset dettagliato
   if(gmtTime > 0)
   {
      int offsetSeconds = (int)(serverTime - gmtTime);
      int offsetHours = offsetSeconds / 3600;
      int offsetMinutes = MathAbs(offsetSeconds % 3600) / 60;
      
      Print("\nOFFSET CALCULATION DETAILS:");
      Print("Raw offset (seconds): ", offsetSeconds);
      Print("Calculated offset: GMT", offsetHours > 0 ? "+" : "", offsetHours, 
            ":", StringFormat("%02d", offsetMinutes));
   }
   
   // Timezone rilevate
   TimeZoneInfo brokerTZ = g_timeManager.GetBrokerTimeZone();
   TimeZoneInfo italianTZ = g_timeManager.GetItalianTimeZone();
   
   Print("\n=== DETECTED BROKER TIMEZONE ===");
   Print("Timezone Name: ", brokerTZ.timeZoneName);
   Print("GMT Offset: ", brokerTZ.offsetHours > 0 ? "+" : "", brokerTZ.offsetHours, " hours");
   Print("DST Status: ", brokerTZ.isDSTActive ? "ACTIVE" : "INACTIVE");
   
   Print("\n=== ITALIAN TIMEZONE ===");
   Print("Timezone Name: ", italianTZ.timeZoneName);
   Print("GMT Offset: ", italianTZ.offsetHours > 0 ? "+" : "", italianTZ.offsetHours, " hours");  
   Print("DST Status: ", italianTZ.isDSTActive ? "ACTIVE (Summer)" : "INACTIVE (Winter)");
   
   // Mostra dettagli struttura MqlDateTime del server
   Print("\n=== SERVER TIME DETAILS (MqlDateTime) ===");
   Print("Year: ", serverDt.year);
   Print("Month: ", StringFormat("%02u", serverDt.mon));
   Print("Day: ", StringFormat("%02u", serverDt.day));
   Print("Hour: ", StringFormat("%02u", serverDt.hour));
   Print("Minute: ", StringFormat("%02u", serverDt.min));
   Print("Second: ", StringFormat("%02u", serverDt.sec));
   Print("Day of Week: ", serverDt.day_of_week, " (", GetDayOfWeekName(serverDt.day_of_week), ")");
   Print("Day of Year: ", serverDt.day_of_year);
   
   // Analisi geografica
   AnalyzeBrokerLocation(brokerTZ);
   
   // Test conversioni
   TestTimeConversions();
   
   // Differenza temporale
   CalculateTimeDifference(brokerTZ, italianTZ);
}

//+------------------------------------------------------------------+
//| Ottiene nome giorno della settimana                            |
//+------------------------------------------------------------------+
string GetDayOfWeekName(int dayOfWeek)
{
   switch(dayOfWeek)
   {
      case 0: return "SUNDAY";
      case 1: return "MONDAY";
      case 2: return "TUESDAY";
      case 3: return "WEDNESDAY";
      case 4: return "THURSDAY";
      case 5: return "FRIDAY";
      case 6: return "SATURDAY";
      default: return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Analizza posizione geografica broker                           |
//+------------------------------------------------------------------+
void AnalyzeBrokerLocation(const TimeZoneInfo& brokerTZ)
{
   Print("\n=== BROKER GEOGRAPHIC ANALYSIS ===");
   
   string timezoneName = brokerTZ.timeZoneName;
   
   if(StringFind(timezoneName, "Israel") >= 0)
   {
      Print("🇮🇱 BROKER SERVERS LIKELY IN ISRAEL");
      Print("   Location: Tel Aviv / Jerusalem area");
      Print("   Many Forex brokers use Israeli data centers");
      Print("   IST (Winter): GMT+2 | IDT (Summer): GMT+3");
   }
   else if(StringFind(timezoneName, "Cyprus") >= 0 || StringFind(timezoneName, "Eastern Europe") >= 0)
   {
      Print("🇨🇾 BROKER SERVERS LIKELY IN CYPRUS");
      Print("   Location: Nicosia / Limassol area");
      Print("   EU-regulated brokers often use Cyprus servers");
      Print("   EET (Winter): GMT+2 | EEST (Summer): GMT+3");
   }
   else if(StringFind(timezoneName, "London") >= 0 || StringFind(timezoneName, "GMT") >= 0)
   {
      Print("🇬🇧 BROKER SERVERS LIKELY IN UNITED KINGDOM");
      Print("   Location: London area");
   }
   else if(StringFind(timezoneName, "Central Europe") >= 0)
   {
      Print("🇪🇺 BROKER SERVERS LIKELY IN CENTRAL EUROPE");
      Print("   Location: Germany, France, or Netherlands");
   }
   else
   {
      Print("🌍 BROKER TIMEZONE: ", timezoneName);
      Print("   Offset: GMT", brokerTZ.offsetHours > 0 ? "+" : "", brokerTZ.offsetHours);
   }
}

//+------------------------------------------------------------------+
//| Test conversioni temporali                                      |
//+------------------------------------------------------------------+
void TestTimeConversions()
{
   if(g_timeManager == NULL) return;
   
   Print("\n=== TIME CONVERSION TESTS ===");
   
   datetime currentBroker = g_timeManager.GetBrokerTime();
   datetime currentItalian = g_timeManager.GetItalianTime();
   
   Print("Current Broker Time: ", TimeToString(currentBroker, TIME_DATE | TIME_MINUTES));
   Print("Current Italian Time: ", TimeToString(currentItalian, TIME_DATE | TIME_MINUTES));
   
   // Test conversione sessione 8:45
   SessionConfig sessionConfig = g_configManager.GetSessionConfig();
   datetime italianSession = CalculateItalianSessionTime(sessionConfig.referenceHour1, sessionConfig.referenceMinute1);
   datetime brokerSession = g_timeManager.ConvertItalianToBroker(italianSession);
   
   Print("\nSESSION TIME CONVERSION:");
   Print("Italian ", sessionConfig.referenceHour1, ":", StringFormat("%02d", sessionConfig.referenceMinute1),
         " = ", TimeToString(italianSession, TIME_DATE | TIME_MINUTES));
   Print("Broker equivalent = ", TimeToString(brokerSession, TIME_DATE | TIME_MINUTES));
}

//+------------------------------------------------------------------+
//| Calcola differenza temporale                                   |
//+------------------------------------------------------------------+
void CalculateTimeDifference(const TimeZoneInfo& brokerTZ, const TimeZoneInfo& italianTZ)
{
   Print("\n=== TIME DIFFERENCE CALCULATION ===");
   
   int italianCurrentOffset = italianTZ.offsetHours + (italianTZ.isDSTActive ? 1 : 0);
   int brokerCurrentOffset = brokerTZ.offsetHours + (brokerTZ.isDSTActive ? 1 : 0);
   int timeDiff = brokerCurrentOffset - italianCurrentOffset;
   
   if(timeDiff == 0)
   {
      Print("✅ BROKER AND ITALY: SAME TIMEZONE");
      Print("   No time conversion needed");
   }
   else if(timeDiff > 0)
   {
      Print("⏰ BROKER IS ", timeDiff, " HOUR(S) AHEAD OF ITALY");
      SessionConfig config = g_configManager.GetSessionConfig();
      Print("   Italian ", config.referenceHour1, ":45 = Broker ", (config.referenceHour1 + timeDiff) % 24, ":45");
   }
   else
   {
      Print("⏰ BROKER IS ", MathAbs(timeDiff), " HOUR(S) BEHIND ITALY");
      SessionConfig config = g_configManager.GetSessionConfig();
      Print("   Italian ", config.referenceHour1, ":45 = Broker ", (config.referenceHour1 + timeDiff + 24) % 24, ":45");
   }
}

//+------------------------------------------------------------------+
//| Disegna righe di riferimento                                   |
//+------------------------------------------------------------------+
void DrawInitialReferenceLines()
{
   if(g_configManager == NULL || g_chartVisualizer == NULL || g_timeManager == NULL) return;
   
   SessionConfig sessionConfig = g_configManager.GetSessionConfig();
   
   // Calcola tempi sessioni in orario italiano
   datetime session1TimeIT = CalculateItalianSessionTime(sessionConfig.referenceHour1, sessionConfig.referenceMinute1);
   datetime session2TimeIT = CalculateItalianSessionTime(sessionConfig.referenceHour2, sessionConfig.referenceMinute2);
   
   // Converti in orario broker per il disegno
   datetime session1TimeBroker = g_timeManager.ConvertItalianToBroker(session1TimeIT);
   datetime session2TimeBroker = g_timeManager.ConvertItalianToBroker(session2TimeIT);
   
   // Disegna le righe (usando orario broker perché il grafico è in orario broker)
   if(session1TimeBroker > 0)
   {
      g_chartVisualizer.DrawReferenceCandle(session1TimeBroker, "Session1");
      Print("Reference line drawn for Session1 - IT: ", TimeToString(session1TimeIT, TIME_MINUTES),
            " | Broker: ", TimeToString(session1TimeBroker, TIME_MINUTES));
   }
   
   if(session2TimeBroker > 0)
   {
      g_chartVisualizer.DrawReferenceCandle(session2TimeBroker, "Session2");
      Print("Reference line drawn for Session2 - IT: ", TimeToString(session2TimeIT, TIME_MINUTES),
            " | Broker: ", TimeToString(session2TimeBroker, TIME_MINUTES));
   }
}

//+------------------------------------------------------------------+
//| Calcola tempo sessione italiana                                |
//+------------------------------------------------------------------+
datetime CalculateItalianSessionTime(int hour, int minute)
{
   datetime currentItalian = g_timeManager.GetItalianTime();
   MqlDateTime dt;
   TimeToStruct(currentItalian, dt);
   
   dt.hour = hour;
   dt.min = minute;
   dt.sec = 0;
   
   return StructToTime(dt);
}

//+------------------------------------------------------------------+
//| Log status timezone corrente                                   |
//+------------------------------------------------------------------+
void LogCurrentTimezoneStatus()
{
   if(g_timeManager == NULL) return;
   
   datetime brokerTime = g_timeManager.GetBrokerTime();
   datetime italianTime = g_timeManager.GetItalianTime();
   TimeZoneInfo brokerTZ = g_timeManager.GetBrokerTimeZone();
   
   Print(">>> REALTIME TIMEZONE STATUS <<<");
   Print("Broker: ", TimeToString(brokerTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS),
         " (", brokerTZ.timeZoneName, ")");
   Print("Italy: ", TimeToString(italianTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS),
         " (Europe/Rome)");
   
   bool isTradingDay = g_timeManager.IsTradingDay(italianTime);
   bool isMarketOpen = g_timeManager.IsMarketOpen(italianTime);
   
   Print("Trading Day: ", isTradingDay ? "YES" : "NO");
   Print("Market Open: ", isMarketOpen ? "YES" : "NO");
}

//+------------------------------------------------------------------+
//| Altri metodi esistenti                                         |
//+------------------------------------------------------------------+
bool ShouldUpdateVisualization(datetime currentTime)
{
   MqlDateTime currentDt, lastUpdateDt;
   TimeToStruct(currentTime, currentDt);
   TimeToStruct(g_lastVisualizationUpdate, lastUpdateDt);
   
   return (currentDt.day != lastUpdateDt.day || 
           currentDt.mon != lastUpdateDt.mon || 
           currentDt.year != lastUpdateDt.year);
}

void UpdateReferenceLines()
{
   if(g_chartVisualizer == NULL) return;
   
   Print("Updating reference lines for new day...");
   g_chartVisualizer.CleanupPreviousDayLines();
   DrawInitialReferenceLines();
   Print("Reference lines updated successfully");
}

string GetDeinitReasonText(const int reason)
{
   switch(reason)
   {
      case REASON_PROGRAM:      return "Expert removed from chart";
      case REASON_REMOVE:       return "Expert removed manually";
      case REASON_RECOMPILE:    return "Expert recompiled";
      case REASON_CHARTCHANGE:  return "Symbol or timeframe changed";
      case REASON_CHARTCLOSE:   return "Chart closed";
      case REASON_PARAMETERS:   return "Parameters changed";
      case REASON_ACCOUNT:      return "Account changed";
      case REASON_TEMPLATE:     return "Template applied";
      case REASON_INITFAILED:   return "Initialization failed";
      case REASON_CLOSE:        return "Terminal closed";
      default:                  return "Unknown (" + IntegerToString(reason) + ")";
   }
}