//+------------------------------------------------------------------+
//|                                               BEN Strategy.mq5    |
//|                                  Strategia Breakout Bidirezionale |
//|                                  Minimal Working Version         |
//+------------------------------------------------------------------+
#property copyright "Ben Team"
#property version   "1.14"
#property description "Strategia Breakout Bidirezionale - Minimal Working"
#property strict

//+------------------------------------------------------------------+
//| Include Headers (SOLO QUELLI CHE COMPILANO)                    |
//+------------------------------------------------------------------+
#include "Enums.mqh"
#include "ConfigManager.mqh"
#include "ChartVisualizer.mqh"
#include "TelegramLogger.mqh"
#include "MarginCalculator.mqh"      
#include "AssetDetector.mqh"         
#include "RiskManager.mqh"           
// ❌ TEMPORANEAMENTE DISABILITATI per far compilare:
// #include "CandleAnalyzer.mqh"        
// #include "OrderManager.mqh"           

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== SESSIONI (Orario Base Inverno) ==="
input int Session1_Hour = 8;                    
input int Session1_Minute = 45;       
input int Session2_Hour = 14;                   
input int Session2_Minute = 45;       
input ENUM_TIMEFRAMES TimeframeRiferimento = PERIOD_M15;
input bool IsSummerTime = true;                 

input group "=== GESTIONE DEL RISCHIO ==="
input double RischioPercentuale = 0.5;           
input int LevaBroker = 100;                      
input double SpreadBufferPips = 2.0;            
input double MaxSpreadPips = 10.0;              

input group "=== FILTRI CANDELA DI RIFERIMENTO ==="
input bool FiltroCorporeAttivo = false;         
input double ForexCorpoMinimoPips = 5.0;        
input double IndiciCorpoMinimoPunti = 3.0;      
input double CryptoCorpoMinimoPunti = 50.0;     
input double CommodityCorpoMinimoPunti = 5.0;   
input double DistanzaEntryPunti = 1.0;          
input double DistanzaSLPunti = 1.0;             

input group "=== TAKE PROFIT ==="
input int NumeroTakeProfit = 2;                 
input double TP1_RiskReward = 2.0;              
input double TP1_PercentualeVolume = 50.0;      
input double TP2_RiskReward = 3.0;              
input double TP2_PercentualeVolume = 50.0;      
input bool AttivareBreakevenDopoTP = true;      

input group "=== GIORNI DI TRADING ==="
input bool TradingLunedi = true;                
input bool TradingMartedi = true;               
input bool TradingMercoledi = true;             
input bool TradingGiovedi = true;               
input bool TradingVenerdi = true;               
input bool TradingSabato = false;               
input bool TradingDomenica = false;             

input group "=== VISUALIZZAZIONE CANDELA RIFERIMENTO ==="
input int LineWidth = 1;                        
input ENUM_LINE_STYLE LineStyle = STYLE_SOLID;
input color ColoreLineaVerticale = clrRed;

input group "=== TELEGRAM NOTIFICATIONS ==="
input bool AbilitaTelegram = false;             
input string TelegramBotToken = "7707070116:AAFSBXAHULIq0z17osNdRq75YS7ckI2uCEQ";             
input string TelegramChatID = "-1002804238340";               
input bool LogServerTimeCheck = true;           
input bool LogSessionAlerts = true;             
input bool LogCandleOHLC = true;                
input bool LogSystemHealth = true;              

input group "=== TRADE REALI ==="
input bool AbilitaTradeReali = false;           // ❌ DISABILITATO per ora
input int MaxSecondiRitardoApertura = 10;       
input int MaxTentativiOrdine = 3;               

//+------------------------------------------------------------------+
//| Global Variables (SOLO QUELLI CHE COMPILANO)                   |
//+------------------------------------------------------------------+
ConfigManager* g_configManager = NULL;
ChartVisualizer* g_chartVisualizer = NULL;
TelegramLogger* g_telegramLogger = NULL;
MarginCalculator* g_marginCalc = NULL;          
AssetDetector* g_assetDetector = NULL;          
RiskManager* g_riskManager = NULL;              
// ❌ TEMPORANEAMENTE DISABILITATI:
// CandleAnalyzer* g_candleAnalyzer = NULL;        
// OrderManager* g_orderManager = NULL;            

bool g_isInitialized = false;
datetime g_lastVisualizationUpdate = 0;
datetime g_lastCleanupCheck = 0;
datetime g_lastServerTimeCheck = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("🚀 BenStrategy v1.14 - Minimal Working Version");
   Print("Symbol: ", Symbol(), " | Timeframe: ", EnumToString(Period()));
   Print("⚠️  CandleAnalyzer & OrderManager temporaneamente disabilitati");
   
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

   // Inizializza MarginCalculator
   if(!InitializeMarginCalculator())
   {
      Print("ERROR: MarginCalculator initialization failed");
      return(INIT_FAILED);
   }

   // Inizializza AssetDetector
   if(!InitializeAssetDetector())
   {
      Print("ERROR: AssetDetector initialization failed");
      return(INIT_FAILED);
   }

   // Inizializza RiskManager
   if(!InitializeRiskManagerWithAssetDetector())
   {
      Print("ERROR: RiskManager initialization failed");
      return(INIT_FAILED);
   }
   
   // Disegna righe di riferimento iniziali
   DrawInitialReferenceLines();
   
   // Inizializza TelegramLogger
   if(!InitializeTelegramLogger())
   {
      Print("ERROR: TelegramLogger initialization failed");
      return(INIT_FAILED);
   }
   
   // Invia messaggio di avvio sistema
   SendSystemStartupMessage();
   
   // Setup timer per cleanup periodico
   EventSetTimer(3600); // Timer ogni ora
   
   g_isInitialized = true;
   g_lastVisualizationUpdate = TimeCurrent();
   g_lastCleanupCheck = TimeCurrent();
   g_lastServerTimeCheck = TimeCurrent();
   
   Print("✅ BreakoutEA initialized successfully (MINIMAL MODE)");

   // Solo broker & symbol info
   LogBrokerAndSymbolInfo();

   if(g_telegramLogger.IsEnabled())
   {
      string serverTime = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES);
      g_telegramLogger.SendTelegramMessage("EA started successfully - MINIMAL MODE - Server time: " + serverTime);
   }
   
   return(INIT_SUCCEEDED);
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
   if(g_riskManager != NULL)
   {
      delete g_riskManager;
      g_riskManager = NULL;
   }
   
   if(g_assetDetector != NULL)
   {
      delete g_assetDetector;
      g_assetDetector = NULL;
   }
   
   if(g_marginCalc != NULL)
   {
      delete g_marginCalc;
      g_marginCalc = NULL;
   }
   
   if(g_chartVisualizer != NULL)
   {
      g_chartVisualizer.CleanupAllLines();
      delete g_chartVisualizer;
      g_chartVisualizer = NULL;
   }
   
   if(g_telegramLogger != NULL)
   {
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
   
   // ⚠️ TODO: Aggiungere CandleAnalyzer e OrderManager quando compilano
   static int tickCount = 0;
   tickCount++;
   
   if(tickCount % 5000 == 0)
   {
      Print("💡 Minimal Mode - Waiting for CandleAnalyzer & OrderManager integration");
      Print("   Current time: ", TimeToString(currentTime, TIME_DATE | TIME_MINUTES));
      Print("   Next session 1: ", CalculateNextSessionTime(1));
      Print("   Next session 2: ", CalculateNextSessionTime(2));
   }
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
//| ⚠️ PLACEHOLDER: Calcola prossima sessione                      |
//+------------------------------------------------------------------+
string CalculateNextSessionTime(int sessionNumber)
{
   datetime currentTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   
   int targetHour = (sessionNumber == 1) ? 
                   (Session1_Hour + (IsSummerTime ? 1 : 0)) % 24 : 
                   (Session2_Hour + (IsSummerTime ? 1 : 0)) % 24;
   int targetMinute = (sessionNumber == 1) ? Session1_Minute : Session2_Minute;
   
   dt.hour = targetHour;
   dt.min = targetMinute;
   dt.sec = 0;
   
   datetime sessionTime = StructToTime(dt);
   
   // Se è già passata oggi, calcola per domani
   if(sessionTime <= currentTime)
   {
      sessionTime += 86400; // +1 giorno
   }
   
   return TimeToString(sessionTime, TIME_DATE | TIME_MINUTES);
}

// ============================================================================
// EXISTING FUNCTIONS (mantenute invariate)
// ============================================================================

//+------------------------------------------------------------------+
//| Inizializza MarginCalculator                                   |
//+------------------------------------------------------------------+
bool InitializeMarginCalculator()
{
   g_marginCalc = new MarginCalculator();
   if(g_marginCalc == NULL) 
   {
      Print("ERROR: Failed to create MarginCalculator");
      return false;
   }
   
   g_marginCalc.SetSafetyMarginPercent(20.0);
   g_marginCalc.SetMaxMarginUtilization(80.0);
   
   Print("✅ MarginCalculator initialized successfully");
   return true;
}

//+------------------------------------------------------------------+
//| Inizializza AssetDetector                                      |
//+------------------------------------------------------------------+
bool InitializeAssetDetector()
{
   g_assetDetector = new AssetDetector();
   if(g_assetDetector == NULL) 
   {
      Print("ERROR: Failed to create AssetDetector");
      return false;
   }
   
   g_assetDetector.SetCacheTimeout(300);
   
   Print("✅ AssetDetector initialized successfully");
   return true;
}

//+------------------------------------------------------------------+
//| Inizializza RiskManager                                        |
//+------------------------------------------------------------------+
bool InitializeRiskManagerWithAssetDetector()
{
   g_riskManager = new RiskManager();
   if(g_riskManager == NULL) 
   {
      Print("ERROR: Failed to create RiskManager");
      return false;
   }
   
   if(!g_riskManager.Initialize(g_marginCalc, g_assetDetector))
   {
      Print("ERROR: RiskManager initialization failed - ", g_riskManager.GetLastError());
      return false;
   }
   
   g_riskManager.SetMaxRiskPerTrade(2.0);
   g_riskManager.SetMaxMarginUtilization(80.0);
   g_riskManager.SetUseEquityForRisk(false);
   
   Print("✅ RiskManager initialized successfully");
   return true;
}

//+------------------------------------------------------------------+
//| Log configurazione sessioni                                    |
//+------------------------------------------------------------------+
void LogSessionConfiguration()
{
   Print("=== SESSION CONFIGURATION ===");
   Print("DST Status: ", IsSummerTime ? "SUMMER (+1h)" : "WINTER (base)");
   Print("Current Broker Time: ", TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES));
   
   int session1ActualHour = (Session1_Hour + (IsSummerTime ? 1 : 0)) % 24;
   int session2ActualHour = (Session2_Hour + (IsSummerTime ? 1 : 0)) % 24;
   
   Print("Session 1 - Base: ", IntegerToString(Session1_Hour), ":", StringFormat("%02d", Session1_Minute),
         " | Actual: ", IntegerToString(session1ActualHour), ":", StringFormat("%02d", Session1_Minute), " broker time");
   Print("Session 2 - Base: ", IntegerToString(Session2_Hour), ":", StringFormat("%02d", Session2_Minute),
         " | Actual: ", IntegerToString(session2ActualHour), ":", StringFormat("%02d", Session2_Minute), " broker time");
}

//+------------------------------------------------------------------+
//| Inizializza ConfigManager                                       |
//+------------------------------------------------------------------+
bool InitializeConfigManager()
{
   g_configManager = new ConfigManager();
   if(g_configManager == NULL) return false;
   
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
   
   TelegramConfig config;
   config.botToken = TelegramBotToken;
   config.chatID = TelegramChatID;
   config.enabled = AbilitaTelegram;
   config.maxRetries = 3;
   config.retryDelay = 1000;
   
   if(!g_telegramLogger.Initialize(config))
   {
      Print("TelegramLogger: Configuration invalid, running without notifications");
      return true;
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
                   " | DST: " + (IsSummerTime ? "SUMMER (+1h)" : "WINTER (base)") +
                   " | Mode: MINIMAL (CandleAnalyzer/OrderManager disabled)";
   
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
   
   if(dt.hour == 2 && dt.min <= 5)
   {
      if(currentTime - g_lastServerTimeCheck > 82800)
      {
         datetime expectedTime = currentTime;
         g_telegramLogger.SendServerTimeCheck(currentTime, expectedTime);
         g_lastServerTimeCheck = currentTime;
         
         Print("Server time check sent at 2:00 AM");
      }
   }
}

//+------------------------------------------------------------------+
//| Disegna righe di riferimento iniziali                          |
//+------------------------------------------------------------------+
void DrawInitialReferenceLines()
{
   if(g_configManager == NULL || g_chartVisualizer == NULL) return;
   
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

//+------------------------------------------------------------------+
//| 🔍 BROKER & SYMBOL DEBUG INFO                                  |
//+------------------------------------------------------------------+
void LogBrokerAndSymbolInfo()
{
   Print("=== BROKER INFORMATION ===");
   Print("Broker Name: ", AccountInfoString(ACCOUNT_COMPANY));
   Print("Account Number: ", IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)));
   Print("Account Currency: ", AccountInfoString(ACCOUNT_CURRENCY));
   Print("Account Leverage: ", IntegerToString(AccountInfoInteger(ACCOUNT_LEVERAGE)));
   Print("Account Balance: ", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
   Print("Server Name: ", AccountInfoString(ACCOUNT_SERVER));
   
   Print("\n=== SYMBOL INFORMATION ===");
   string symbol = Symbol();
   
   Print("Symbol: ", symbol);
   Print("Description: ", SymbolInfoString(symbol, SYMBOL_DESCRIPTION));
   Print("Currency Base: ", SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE));
   Print("Currency Profit: ", SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT));
   Print("Currency Margin: ", SymbolInfoString(symbol, SYMBOL_CURRENCY_MARGIN));
   
   Print("Contract Size: ", DoubleToString(SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE), 0));
   Print("Tick Size: ", DoubleToString(SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE), _Digits));
   Print("Tick Value: ", DoubleToString(SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE), 2));
   Print("Point: ", DoubleToString(SymbolInfoDouble(symbol, SYMBOL_POINT), _Digits + 1));
   Print("Digits: ", IntegerToString(SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
   
   Print("Volume Min: ", DoubleToString(SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN), 2));
   Print("Volume Max: ", DoubleToString(SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX), 2));
   Print("Volume Step: ", DoubleToString(SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP), 2));
   
   Print("Margin Initial: ", DoubleToString(SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL), 2));
   Print("Margin Maintenance: ", DoubleToString(SymbolInfoDouble(symbol, SYMBOL_MARGIN_MAINTENANCE), 2));
   
   MqlTick tick;
   if(SymbolInfoTick(symbol, tick))
   {
      Print("Current Bid: ", DoubleToString(tick.bid, _Digits));
      Print("Current Ask: ", DoubleToString(tick.ask, _Digits));
      Print("Current Spread: ", DoubleToString((tick.ask - tick.bid) / SymbolInfoDouble(symbol, SYMBOL_POINT), 1));
   }
}