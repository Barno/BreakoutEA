//+------------------------------------------------------------------+
//|                                               BEN Strategy.mq5    |
//|                                  Strategia Breakout Bidirezionale |
//|                                  Broker Time System - Simplified |
//+------------------------------------------------------------------+
#property copyright "Ben Team"
#property version   "0.11"
#property description "Strategia Breakout Bidirezionale - Broker Time System"
#property strict

//+------------------------------------------------------------------+
//| Include Headers (ORDINE CORRETTO per Dependencies)             |
//+------------------------------------------------------------------+
#include "Enums.mqh"
#include "ConfigManager.mqh"
#include "ChartVisualizer.mqh"
#include "TelegramLogger.mqh"
#include "MarginCalculator.mqh"      // ✅ PRIMA di AssetDetector (AssetDetector usa AssetInfo)
#include "AssetDetector.mqh"         // ✅ DOPO MarginCalculator
#include "RiskManager.mqh"           // ✅ ULTIMO (usa entrambi)

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
input bool AbilitaTelegram = false;             // Abilita notifiche Telegram
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
MarginCalculator* g_marginCalc = NULL;          // ✅ PRIMA
AssetDetector* g_assetDetector = NULL;          // ✅ DOPO MarginCalculator
RiskManager* g_riskManager = NULL;              // ✅ ULTIMO

bool g_isInitialized = false;
datetime g_lastVisualizationUpdate = 0;
datetime g_lastCleanupCheck = 0;
datetime g_lastServerTimeCheck = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   
   Print("🚀 BenStrategy v1.21 - Broker Time System + AssetDetector");
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

   // ✅ ORDINE CORRETTO: MarginCalculator PRIMA
   if(!InitializeMarginCalculator())
   {
      Print("ERROR: MarginCalculator initialization failed");
      return(INIT_FAILED);
   }

   // ✅ ORDINE CORRETTO: AssetDetector DOPO MarginCalculator
   if(!InitializeAssetDetector())
   {
      Print("ERROR: AssetDetector initialization failed");
      return(INIT_FAILED);
   }

   // ✅ ORDINE CORRETTO: RiskManager ULTIMO
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
   
   Print("✅ BreakoutEA initialized successfully");

   string serverTime = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES);

   // ====== TEST COMPLETO - DA RIMUOVERE DOPO VALIDAZIONE ======
   TestCompleteSystem();
   // ====== FINE TEST ======

   LogBrokerAndSymbolInfo();

   if(g_telegramLogger.IsEnabled())
   {
      g_telegramLogger.SendTelegramMessage("EA started successfully - Server time: " + serverTime);
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
   
   // ✅ CLEANUP IN REVERSE ORDER
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
//| ✅ NUOVO: Inizializza MarginCalculator                         |
//+------------------------------------------------------------------+
bool InitializeMarginCalculator()
{
   g_marginCalc = new MarginCalculator();
   if(g_marginCalc == NULL) 
   {
      Print("ERROR: Failed to create MarginCalculator");
      return false;
   }
   
   // Configura safety settings
   g_marginCalc.SetSafetyMarginPercent(20.0);
   g_marginCalc.SetMaxMarginUtilization(80.0);
   
   Print("✅ MarginCalculator initialized successfully");
   return true;
}

//+------------------------------------------------------------------+
//| ✅ NUOVO: Inizializza AssetDetector                           |
//+------------------------------------------------------------------+
bool InitializeAssetDetector()
{
   g_assetDetector = new AssetDetector();
   if(g_assetDetector == NULL) 
   {
      Print("ERROR: Failed to create AssetDetector");
      return false;
   }
   
   // Configura cache timeout (opzionale)
   g_assetDetector.SetCacheTimeout(300); // 5 minuti
   
   Print("✅ AssetDetector initialized successfully");
   return true;
}

//+------------------------------------------------------------------+
//| ✅ AGGIORNATO: RiskManager con AssetDetector               |
//+------------------------------------------------------------------+
bool InitializeRiskManagerWithAssetDetector()
{
   g_riskManager = new RiskManager();
   if(g_riskManager == NULL) 
   {
      Print("ERROR: Failed to create RiskManager");
      return false;
   }
   
   // ✅ NUOVO: Initialize con AssetDetector
   if(!g_riskManager.Initialize(g_marginCalc, g_assetDetector))
   {
      Print("ERROR: RiskManager initialization failed - ", g_riskManager.GetLastError());
      return false;
   }
   
   // Configura parametri (invariato)
   g_riskManager.SetMaxRiskPerTrade(2.0);
   g_riskManager.SetMaxMarginUtilization(80.0);
   g_riskManager.SetUseEquityForRisk(false);
   
   Print("✅ RiskManager initialized successfully with AssetDetector integration");
   return true;
}

//+------------------------------------------------------------------+
//| ✅ NUOVO: Test Sistema Completo                               |
//+------------------------------------------------------------------+
void TestCompleteSystem()
{
   Print("\n🧪 ==============================================");
   Print("🧪 COMPLETE SYSTEM TEST SUITE");
   Print("🧪 ==============================================");
   
   // Test 1: MarginCalculator
   TestMarginCalculatorBasic();
   
   // Test 2: AssetDetector
   TestAssetDetectorBasic();
   
   // Test 3: RiskManager
   TestRiskManagerBasic();
   
   // Test 4: Integration Test
   TestSystemIntegration();
   
   Print("🧪 ==============================================");
   Print("🧪 COMPLETE SYSTEM TEST COMPLETED");
   Print("🧪 ==============================================\n");
}

//+------------------------------------------------------------------+
//| Test MarginCalculator Basic                                    |
//+------------------------------------------------------------------+
void TestMarginCalculatorBasic()
{
   Print("\n📊 TEST: MarginCalculator Basic");
   Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   
   string testSymbol = Symbol();
   double testLots = 0.1;
   
   double required = g_marginCalc.GetRequiredMargin(testSymbol, testLots, ORDER_TYPE_BUY);
   bool canOpen = g_marginCalc.CanOpenPosition(testSymbol, testLots, ORDER_TYPE_BUY);
   
   Print("✅ Required Margin: ", DoubleToString(required, 2), " USD");
   Print("✅ Can Open: ", canOpen ? "YES" : "NO");
}

//+------------------------------------------------------------------+
//| Test AssetDetector Basic                                       |
//+------------------------------------------------------------------+
void TestAssetDetectorBasic()
{
   Print("\n🔍 TEST: AssetDetector Basic");
   Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   
   string testSymbol = Symbol();
   
   AssetInfo info = g_assetDetector.DetectAsset(testSymbol);
   
   Print("✅ Asset Type: ", AssetTypeToString(info.type));
   Print("✅ Base Symbol: ", info.baseSymbol);
   Print("✅ Quote Symbol: ", info.quoteSymbol);
   Print("✅ Point Value: ", DoubleToString(info.pointValue, 4));
}

//+------------------------------------------------------------------+
//| Test RiskManager Basic                                         |
//+------------------------------------------------------------------+
void TestRiskManagerBasic()
{
   Print("\n🎯 TEST: RiskManager Basic");
   Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   
   string testSymbol = Symbol();
   double riskPercent = 0.5;
   double stopLossPoints = 200; // 20 pips for most forex pairs
   
   double lots = g_riskManager.CalculateLotsForRisk(testSymbol, riskPercent, stopLossPoints);
   double riskAmount = g_riskManager.CalculateRiskAmount(riskPercent);
   
   Print("✅ Risk Amount: ", DoubleToString(riskAmount, 2), " USD");
   Print("✅ Calculated Lots: ", DoubleToString(lots, 3));
}

//+------------------------------------------------------------------+
//| Test System Integration                                        |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| ✅ FIXED: Integration Test (in BreakoutEA.mq5)                |
//+------------------------------------------------------------------+
void TestSystemIntegration()
{
   Print("\n🔗 TEST: System Integration");
   Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   
   string testSymbol = Symbol();
   
   // Test integration: AssetDetector → RiskManager
   AssetType detectedType = g_assetDetector.GetAssetType(testSymbol);
   double pointValue = g_riskManager.GetPointValue(testSymbol);
   
   Print("✅ Detected Asset Type: ", AssetTypeToString(detectedType));
   Print("✅ Point Value (via RiskManager): ", DoubleToString(pointValue, 4));
   
   // ✅ FIX: Test scenario REALISTICO invece di lotti fissi
   MqlTick tick;
   if(SymbolInfoTick(testSymbol, tick))
   {
      // ✅ Usa prezzi reali per calcolo SL corretto
      double entryPrice = tick.ask;
      double stopLoss = tick.ask - (20 * SymbolInfoDouble(testSymbol, SYMBOL_POINT)); // 20 punti SL
      double riskPercent = 0.5; // 0.5% come configurato
      
      PositionSizeInfo posInfo = g_riskManager.CalculatePositionSize(testSymbol, entryPrice, stopLoss, riskPercent);
      
      if(posInfo.isValid)
      {
         Print("✅ Integration Test SUCCESS:");
         Print("  📦 Position Size: ", DoubleToString(posInfo.totalLots, 3), " lots");
         Print("  💵 Risk Amount: ", DoubleToString(posInfo.riskAmount, 2), " USD");
         Print("  📏 SL Points: ", DoubleToString(posInfo.stopLossPoints, 1));
         Print("  📊 Entry: ", DoubleToString(entryPrice, _Digits));
         Print("  🛑 Stop Loss: ", DoubleToString(stopLoss, _Digits));
      }
      else
      {
         Print("❌ Integration Test FAILED: ", posInfo.errorReason);
      }
   }
   else
   {
      Print("❌ Cannot get current price for integration test");
   }
}

// ============================================================================
// EXISTING FUNCTIONS (mantenuti invariati)
// ============================================================================

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


//+------------------------------------------------------------------+
//| 🔍 BROKER & SYMBOL DEBUG INFO                                  |
//+------------------------------------------------------------------+

void LogBrokerAndSymbolInfo()
{
   Print("=== BROKER INFORMATION ===");
   Print("Broker Name: ", AccountInfoString(ACCOUNT_COMPANY));
   Print("Account Number: ", AccountInfoInteger(ACCOUNT_LOGIN));
   Print("Account Currency: ", AccountInfoString(ACCOUNT_CURRENCY));
   Print("Account Leverage: ", AccountInfoInteger(ACCOUNT_LEVERAGE));
   Print("Account Balance: ", AccountInfoDouble(ACCOUNT_BALANCE));
   Print("Server Name: ", AccountInfoString(ACCOUNT_SERVER));
   
   Print("\n=== DAX40 SYMBOL INFORMATION ===");
   string symbol = "DAX40";
   
   // Basic Info
   Print("Symbol: ", symbol);
   Print("Description: ", SymbolInfoString(symbol, SYMBOL_DESCRIPTION));
   Print("Currency Base: ", SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE));
   Print("Currency Profit: ", SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT));
   Print("Currency Margin: ", SymbolInfoString(symbol, SYMBOL_CURRENCY_MARGIN));
   
   // Trading Info
   Print("Contract Size: ", SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE));
   Print("Tick Size: ", SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE));
   Print("Tick Value: ", SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE));
   Print("Point: ", SymbolInfoDouble(symbol, SYMBOL_POINT));
   Print("Digits: ", SymbolInfoInteger(symbol, SYMBOL_DIGITS));
   
   // Volume Info
   Print("Volume Min: ", SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN));
   Print("Volume Max: ", SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX));
   Print("Volume Step: ", SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP));
   
   // Margin Info
   Print("Margin Initial: ", SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL));
   Print("Margin Maintenance: ", SymbolInfoDouble(symbol, SYMBOL_MARGIN_MAINTENANCE));
   
   // Current Prices
   MqlTick tick;
   if(SymbolInfoTick(symbol, tick))
   {
      Print("Current Bid: ", tick.bid);
      Print("Current Ask: ", tick.ask);
      Print("Current Spread: ", (tick.ask - tick.bid) / SymbolInfoDouble(symbol, SYMBOL_POINT));
   }
   
   // ✅ CALCOLO POINT VALUE ALTERNATIVO
   Print("\n=== ALTERNATIVE POINT VALUE CALCULATION ===");
   double alternativePointValue = CalculateAlternativePointValue(symbol);
   Print("Alternative Point Value: ", alternativePointValue);
   
   // ✅ TEST CON I TUOI DATI REALI
   Print("\n=== REAL TRADE VERIFICATION ===");
   double yourLots = 10.55;
   double yourRisk = 250.0;
   double slPoints = 18.7;
   double impliedPointValue = yourRisk / (yourLots * slPoints);
   Print("Your Lots: ", yourLots);
   Print("Your Risk: ", yourRisk, " USD");
   Print("SL Points: ", slPoints);
   Print("Implied Point Value: ", impliedPointValue, " USD per point");
}

//+------------------------------------------------------------------+
//| 🧮 CALCOLO POINT VALUE ALTERNATIVO                             |
//+------------------------------------------------------------------+
double CalculateAlternativePointValue(string symbol)
{
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   Print("Raw Tick Value: ", tickValue);
   Print("Raw Tick Size: ", tickSize);
   Print("Raw Point: ", point);
   
   // Se tick value è 0, prova calcolo alternativo
   if(tickValue == 0)
   {
      Print("Tick Value is 0 - trying alternative calculation...");
      
      // Per CFD EUR-based, spesso point value = 1 EUR = ~1.1 USD
      double eurToUsd = 1.10; // Approssimativo
      return eurToUsd; // 1 punto = 1 EUR ≈ 1.1 USD
   }
   
   // Calcolo normale
   if(tickSize > 0)
      return tickValue / tickSize * point;
   else
      return tickValue;
}