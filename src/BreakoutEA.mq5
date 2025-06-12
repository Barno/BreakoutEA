//+------------------------------------------------------------------+
//|                                               BEN Strategy.mq5    |
//|                                  Strategia Breakout Bidirezionale |
//|                                  Broker Time System - Simplified |
//+------------------------------------------------------------------+
#property copyright "Ben Team"
#property version   "0.10"
#property description "Strategia Breakout Bidirezionale - Broker Time System"
#property strict

//+------------------------------------------------------------------+
//| Include Headers                                                  |
//+------------------------------------------------------------------+
#include "Enums.mqh"
#include "ConfigManager.mqh"
#include "ChartVisualizer.mqh"
#include "TelegramLogger.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== SESSIONI (Orario Base Inverno) ==="
input int Session1_Hour = 8;                    
input int Session1_Minute = 45;       
input int Session2_Hour = 14;                   
input int Session2_Minute = 45;       
input ENUM_TIMEFRAMES TimeframeRiferimento = PERIOD_M15;
input bool IsSummerTime = true;                 // Flag: +1 ora per ora legale (Estate)

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

input group "=== GIORNI DI TRADING TRADING ==="
input bool TradingLunedi = true;                
input bool TradingMartedi = true;               
input bool TradingMercoledi = true;             
input bool TradingGiovedi = true;               
input bool TradingVenerdi = true;               
input bool TradingSabato = false;               
input bool TradingDomenica = false;             

input group "=== VISUALIZZAZIONE CANDELA RIFERIMENTO==="
input int LineWidth = 1;                        
input ENUM_LINE_STYLE LineStyle = STYLE_SOLID;
input color ColoreLineaVerticale = clrRed;

input group "=== TELEGRAM NOTIFICATIONS ==="
input bool AbilitaTelegram = true;             // Abilita notifiche Telegram
input string TelegramBotToken = "7707070116:AAFSBXAHULIq0z17osNdRq75YS7ckI2uCEQ";             // Token bot Telegram  
input string TelegramChatID = "-1002804238340";               // Chat ID per messaggi
input bool LogServerTimeCheck = true;           // Log controllo orario server (2:00 AM)
input bool LogSessionAlerts = true;             // Log alert sessioni
input bool LogCandleOHLC = true;                // Log dati OHLC candele
input bool LogSystemHealth = true;              // Log stato sistema    

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
ConfigManager* g_configManager = NULL;
ChartVisualizer* g_chartVisualizer = NULL;
TelegramLogger* g_telegramLogger = NULL;
MarginCalculator* calc = new MarginCalculator();


bool g_isInitialized = false;
datetime g_lastVisualizationUpdate = 0;
datetime g_lastCleanupCheck = 0;
datetime g_lastServerTimeCheck = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   
   Print("🚀 BenStrategy v1.20 - Broker Time System");
   Print("Symbol: ", Symbol(), " | Timeframe: ", EnumToString(Period()));
   
   g_isInitialized = false;
   
   // Log configurazione sessioni
   LogSessionConfiguration();
   
   // Inizializza ConfigManager
   if(!InitializeConfigManager())
   {
      Print("ERROR: ConfigManager initialization failed");
      return(INIT_FAILED);
   }
   
   // Inizializza ChartVisualizer
   if(!InitializeChartVisualizer())
   {
      Print("ERROR: ChartVisualizer initialization failed");
      return(INIT_FAILED);
   }
   
   
   // Disegna righe di riferimento iniziali
   DrawInitialReferenceLines();
   
   // Invia messaggio di avvio sistema
   SendSystemStartupMessage();
   
   // Setup timer per cleanup periodico
   EventSetTimer(3600); // Timer ogni ora
   
   g_isInitialized = true;
   g_lastVisualizationUpdate = TimeCurrent();
   g_lastCleanupCheck = TimeCurrent();
   g_lastServerTimeCheck = TimeCurrent();
   
   Print("✅ BreakoutEA initialized successfully");
   
   // Inizializza TelegramLogger
   if(!InitializeTelegramLogger())
   {
      Print("ERROR: TelegramLogger initialization failed");
      return(INIT_FAILED);
   }

   string serverTime = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES);


   // Test base
double required = calc.GetRequiredMargin("EURUSD", 0.1, ORDER_TYPE_BUY);
bool canOpen = calc.CanOpenPosition("EURUSD", 0.1, ORDER_TYPE_BUY);

// Test avanzato
MarginInfo analysis = calc.GetMarginAnalysis("DAX40", 0.1, ORDER_TYPE_BUY);
double maxLots = calc.CalculateMaxLotsForMargin("EURUSD", ORDER_TYPE_BUY, 80.0);

// Debug output
Print("Required: ", required, " | Can Open: ", canOpen);
Print("Max Lots for 80% margin: ", maxLots);

   g_telegramLogger.SendTelegramMessage("EA started successfully - Server time: " + serverTime);   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("🛑 BreakoutEA - Shutting down...");
   Print("Reason: ", GetDeinitReasonText(reason));
   
   EventKillTimer();
   
   // Cleanup in reverse order
   if(g_chartVisualizer != NULL)
   {
      g_chartVisualizer.CleanupAllLines();
      delete g_chartVisualizer;
      g_chartVisualizer = NULL;
   }
   
   if(g_telegramLogger != NULL)
   {
      // Invia messaggio di shutdown
      if(g_telegramLogger.IsEnabled())
      {
         g_telegramLogger.SendSystemHealth("SHUTDOWN", "EA shutting down - Reason: " + GetDeinitReasonText(reason));
      }
      delete g_telegramLogger;
      g_telegramLogger = NULL;
   }
   
   if(g_configManager != NULL)
   {
      delete g_configManager;
      g_configManager = NULL;
   }
   
   g_isInitialized = false;
   
   Print("✅ BreakoutEA shutdown completed");
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_isInitialized) return;
   
   // Aggiorna visualizzazione se necessario
   datetime currentTime = TimeCurrent();
   if(ShouldUpdateVisualization(currentTime))
   {
      UpdateReferenceLines();
      g_lastVisualizationUpdate = currentTime;
   }
   
   // TODO: Implementare logica trading principale
   // 1. Verifica se è orario di apertura sessione
   // 2. Analizza candela di riferimento
   // 3. Calcola livelli entry/SL
   // 4. Gestisci ordini e posizioni
   // 5. Monitora take profit
}

//+------------------------------------------------------------------+
//| Timer function                                                  |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(!g_isInitialized) return;
   
   datetime currentTime = TimeCurrent();
   
   // Cleanup periodico righe vecchie
   if(currentTime - g_lastCleanupCheck > 86400) // 24 ore
   {
      if(g_chartVisualizer != NULL)
      {
         g_chartVisualizer.CleanupPreviousDayLines();
      }
      g_lastCleanupCheck = currentTime;
   }
   
   // Server time check alle 2:00 AM
   CheckServerTimeAlert(currentTime);
}

//+------------------------------------------------------------------+
//| Log configurazione sessioni                                    |
//+------------------------------------------------------------------+
void LogSessionConfiguration()
{
   Print("=== SESSION CONFIGURATION ===");
   Print("DST Status: ", IsSummerTime ? "SUMMER (+1h)" : "WINTER (base)");
   Print("Current Broker Time: ", TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES));
   
   // Log calcoli
   int session1ActualHour = (Session1_Hour + (IsSummerTime ? 1 : 0)) % 24;
   int session2ActualHour = (Session2_Hour + (IsSummerTime ? 1 : 0)) % 24;
   
   Print("Session 1 - Base: ", Session1_Hour, ":", StringFormat("%02d", Session1_Minute),
         " | Actual: ", session1ActualHour, ":", StringFormat("%02d", Session1_Minute), " broker time");
   Print("Session 2 - Base: ", Session2_Hour, ":", StringFormat("%02d", Session2_Minute),
         " | Actual: ", session2ActualHour, ":", StringFormat("%02d", Session2_Minute), " broker time");
}

//+------------------------------------------------------------------+
//| Inizializza ConfigManager                                       |
//+------------------------------------------------------------------+
bool InitializeConfigManager()
{
   g_configManager = new ConfigManager();
   if(g_configManager == NULL) return false;
   
   // Usa orari effettivi (con DST applicato)
   int session1Hour = (Session1_Hour + (IsSummerTime ? 1 : 0)) % 24;
   int session1Minute = Session1_Minute;
   int session2Hour = (Session2_Hour + (IsSummerTime ? 1 : 0)) % 24;
   int session2Minute = Session2_Minute;
   
   if(!g_configManager.LoadParameters(
      RischioPercentuale, LevaBroker, SpreadBufferPips, MaxSpreadPips,
      session1Hour, session1Minute, session2Hour, session2Minute, TimeframeRiferimento,
      NumeroTakeProfit, TP1_RiskReward, TP1_PercentualeVolume, 
      TP2_RiskReward, TP2_PercentualeVolume, AttivareBreakevenDopoTP,
      TradingLunedi, TradingMartedi, TradingMercoledi, TradingGiovedi, 
      TradingVenerdi, TradingSabato, TradingDomenica))
      return false;
   
   return g_configManager.ValidateParameters();
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
//| Inizializza TelegramLogger                                      |
//+------------------------------------------------------------------+
bool InitializeTelegramLogger()
{
   g_telegramLogger = new TelegramLogger();
   if(g_telegramLogger == NULL) return false;
   
   // Configura TelegramLogger
   TelegramConfig config;
   config.botToken = TelegramBotToken;
   config.chatID = TelegramChatID;
   config.enabled = AbilitaTelegram;
   config.maxRetries = 3;
   config.retryDelay = 1000;
   
   if(!g_telegramLogger.Initialize(config))
   {
      Print("TelegramLogger: Configuration invalid, running without notifications");
      return true; // Non è un errore fatale
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Invia messaggio di avvio sistema                               |
//+------------------------------------------------------------------+
void SendSystemStartupMessage()
{
   if(g_telegramLogger == NULL || !g_telegramLogger.IsEnabled()) return;
   
   string details = "Symbol: " + Symbol() + " | Timeframe: " + EnumToString(Period()) + 
                   " | DST: " + (IsSummerTime ? "SUMMER (+1h)" : "WINTER (base)");
   
   g_telegramLogger.SendSystemHealth("STARTUP", details);
}

//+------------------------------------------------------------------+
//| Controlla e invia server time check alle 2:00 AM              |
//+------------------------------------------------------------------+
void CheckServerTimeAlert(datetime currentTime)
{
   if(g_telegramLogger == NULL || !g_telegramLogger.IsEnabled() || !LogServerTimeCheck) return;
   
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   
   // Verifica se sono le 2:00 AM e non abbiamo già inviato oggi
   if(dt.hour == 2 && dt.min <= 5) // Finestra di 5 minuti
   {
      // Calcola se abbiamo già inviato nelle ultime 23 ore
      if(currentTime - g_lastServerTimeCheck > 82800) // 23 ore
      {
         datetime expectedTime = currentTime; // Per ora, expected = current
         g_telegramLogger.SendServerTimeCheck(currentTime, expectedTime);
         g_lastServerTimeCheck = currentTime;
         
         Print("Server time check sent at 2:00 AM");
      }
   }
}

//+------------------------------------------------------------------+
//| Invia alert formazione sessione                                |
//+------------------------------------------------------------------+
void SendSessionFormingAlert(const string sessionName, datetime sessionTime)
{
   if(g_telegramLogger == NULL || !g_telegramLogger.IsEnabled() || !LogSessionAlerts) return;
   
   g_telegramLogger.SendSessionAlert(sessionName, sessionTime, true);
}

//+------------------------------------------------------------------+
//| Invia alert chiusura sessione con OHLC                        |
//+------------------------------------------------------------------+
void SendSessionClosedAlert(const string sessionName, datetime sessionTime, double open, double high, double low, double close)
{
   if(g_telegramLogger == NULL || !g_telegramLogger.IsEnabled()) return;
   
   if(LogSessionAlerts)
   {
      g_telegramLogger.SendSessionAlert(sessionName, sessionTime, false);
   }
   
   if(LogCandleOHLC)
   {
      g_telegramLogger.SendCandleOHLC(sessionName, open, high, low, close);
   }
}

//+------------------------------------------------------------------+
//| Disegna righe di riferimento iniziali                          |
//+------------------------------------------------------------------+
void DrawInitialReferenceLines()
{
   if(g_configManager == NULL || g_chartVisualizer == NULL) return;
   
   // Usa il nuovo metodo del ChartVisualizer
   g_chartVisualizer.DrawSessionReferences(
      Session1_Hour, Session1_Minute,
      Session2_Hour, Session2_Minute, 
      IsSummerTime);
}

//+------------------------------------------------------------------+
//| Verifica se aggiornare visualizzazione                         |
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

//+------------------------------------------------------------------+
//| Aggiorna righe di riferimento                                  |
//+------------------------------------------------------------------+
void UpdateReferenceLines()
{
   if(g_chartVisualizer == NULL) return;
   
   Print("Updating reference lines for new day...");
   g_chartVisualizer.CleanupPreviousDayLines();
   DrawInitialReferenceLines();
   Print("Reference lines updated successfully");
}

//+------------------------------------------------------------------+
//| Ottiene testo motivo deinit                                    |
//+------------------------------------------------------------------+
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