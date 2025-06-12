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
#include "MarginCalculator.mqh"
#include "RiskManager.mqh"

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
MarginCalculator* g_marginCalc = NULL;
RiskManager* g_riskManager = NULL;


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


   // ====== TEST DA TOGLIERE ======
   // Test base MARGIN CALULATOR
   TestMarginCalculatorComplete();

   // Inizializza RiskManager
   if(!InitializeRiskManager())
   {
      Print("ERROR: RiskManager initialization failed");
      return(INIT_FAILED);
   }

   TestRiskManagerComplete();
   // ====== FINE TEST DA TOGLIERE ======

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

   //====== TEST DA TOGLIERE ======
   CleanupMarginCalculatorTest();
   if(g_riskManager != NULL)
   {
      delete g_riskManager;
      g_riskManager = NULL;
   }
   //====== TEST DA TOGLIERE ======

   
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

//+------------------------------------------------------------------+
//| TEST COMPLETO MARGIN CALCULATOR - Sostituisci nel OnInit()     |
//+------------------------------------------------------------------+
void TestMarginCalculatorComplete()
{
   Print("\n");
   Print("🧪 ===============================================");
   Print("🧪 MARGIN CALCULATOR COMPLETE TEST SUITE");
   Print("🧪 ===============================================");
   
   // Inizializza MarginCalculator
   g_marginCalc = new MarginCalculator();
   if(g_marginCalc == NULL)
   {
      Print("❌ CRITICAL: Failed to create MarginCalculator");
      return;
   }
   
   // Configura safety settings
   g_marginCalc.SetSafetyMarginPercent(20.0);
   g_marginCalc.SetMaxMarginUtilization(80.0);
   
   Print("✅ MarginCalculator initialized with Safety: ", g_marginCalc.GetSafetyMarginPercent(), "%");
   
   // 1. TEST ACCOUNT INFO
   TestAccountInformation();
   
   // 2. TEST MULTI-SYMBOL
   TestMultipleSymbols();
   
   // 3. TEST POSITION SIZING
   TestPositionSizing();
   
   // 4. TEST MARGIN ANALYSIS
   TestMarginAnalysis();
   
   // 5. TEST ASSET DETECTION
   TestAssetDetection();
   
   // 6. TEST ERROR HANDLING
   TestErrorHandling();
   
   // 7. TEST PERFORMANCE
   TestPerformance();
   
   Print("🧪 ===============================================");
   Print("🧪 MARGIN CALCULATOR TEST SUITE COMPLETED");
   Print("🧪 ===============================================");
   Print("\n");
}

//+------------------------------------------------------------------+
//| Test 1: Account Information                                     |
//+------------------------------------------------------------------+
void TestAccountInformation()
{
   Print("\n📊 TEST 1: ACCOUNT INFORMATION");
   Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin = AccountInfoDouble(ACCOUNT_MARGIN);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   int leverage = (int)AccountInfoInteger(ACCOUNT_LEVERAGE);
   string currency = AccountInfoString(ACCOUNT_CURRENCY);
   
   Print("💰 Balance: ", DoubleToString(balance, 2), " ", currency);
   Print("💎 Equity: ", DoubleToString(equity, 2), " ", currency);
   Print("🔒 Used Margin: ", DoubleToString(margin, 2), " ", currency);
   Print("🆓 Free Margin: ", DoubleToString(freeMargin, 2), " ", currency);
   Print("📈 Margin Level: ", DoubleToString(marginLevel, 2), "%");
   Print("⚡ Leverage: 1:", leverage);
   
   // Test MarginCalculator method
   double availableFromCalc = g_marginCalc.GetAvailableMargin();
   Print("🧮 Available (Calc): ", DoubleToString(availableFromCalc, 2), " ", currency);
   
   if(MathAbs(availableFromCalc - freeMargin) < 0.01)
      Print("✅ Available margin calculation: CORRECT");
   else
      Print("❌ Available margin calculation: MISMATCH!");
}

//+------------------------------------------------------------------+
//| Test 2: Multiple Symbols                                       |
//+------------------------------------------------------------------+
void TestMultipleSymbols()
{
   Print("\n🌍 TEST 2: MULTIPLE SYMBOLS");
   Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   
   string symbols[] = {"EURUSD", "GBPUSD", "USDJPY", "DAX40", "SP500", "BTCUSD", "XAUUSD"};
   double testLots = 0.1;
   
   for(int i = 0; i < ArraySize(symbols); i++)
   {
      string symbol = symbols[i];
      
      Print("\n🔍 Testing: ", symbol);
      
      // Test asset detection
      AssetInfo info = g_marginCalc.GetAssetInfo(symbol);
      Print("  📋 Type: ", AssetTypeToString(info.type));
      Print("  📏 Contract Size: ", DoubleToString(info.contractSize, 0));
      Print("  🎯 Digits: ", info.digits);
      
      // Test margin calculation
      double required = g_marginCalc.GetRequiredMargin(symbol, testLots, ORDER_TYPE_BUY);
      if(required > 0)
      {
         Print("  💵 Required Margin: ", DoubleToString(required, 2), " USD");
         
         // Test can open
         bool canOpen = g_marginCalc.CanOpenPosition(symbol, testLots, ORDER_TYPE_BUY);
         Print("  ✅ Can Open: ", canOpen ? "YES" : "NO");
         
         // Test max lots
         double maxLots = g_marginCalc.CalculateMaxLotsForMargin(symbol, ORDER_TYPE_BUY, 50.0);
         Print("  📊 Max Lots (50%): ", DoubleToString(maxLots, 2));
      }
      else
      {
         Print("  ❌ Failed to calculate margin for ", symbol);
         Print("  📝 Error: ", g_marginCalc.GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| Test 3: Position Sizing                                        |
//+------------------------------------------------------------------+
void TestPositionSizing()
{
   Print("\n📏 TEST 3: POSITION SIZING");
   Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   
   string testSymbol = Symbol(); // Simbolo attuale
   double testSizes[] = {0.01, 0.1, 0.5, 1.0, 2.0, 5.0};
   
   Print("🎯 Testing position sizes for: ", testSymbol);
   
   for(int i = 0; i < ArraySize(testSizes); i++)
   {
      double lots = testSizes[i];
      
      Print("\n📦 Testing ", DoubleToString(lots, 2), " lots:");
      
      double required = g_marginCalc.GetRequiredMargin(testSymbol, lots, ORDER_TYPE_BUY);
      if(required > 0)
      {
         double utilization = g_marginCalc.GetMarginUtilizationPercent(testSymbol, lots, ORDER_TYPE_BUY);
         bool canOpen = g_marginCalc.CanOpenPosition(testSymbol, lots, ORDER_TYPE_BUY);
         
         Print("  💵 Required: ", DoubleToString(required, 2), " USD");
         Print("  📊 Utilization: ", DoubleToString(utilization, 1), "%");
         Print("  ✅ Can Open: ", canOpen ? "YES" : "NO");
         
         if(utilization > 100.0)
            Print("  ⚠️  WARNING: Exceeds available margin!");
      }
      else
      {
         Print("  ❌ Calculation failed");
      }
   }
}

//+------------------------------------------------------------------+
//| Test 4: Margin Analysis                                        |
//+------------------------------------------------------------------+
void TestMarginAnalysis()
{
   Print("\n🔬 TEST 4: MARGIN ANALYSIS");
   Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   
   string testSymbol = Symbol();
   double testLots = 1.0;
   
   MarginInfo analysis = g_marginCalc.GetMarginAnalysis(testSymbol, testLots, ORDER_TYPE_BUY);
   
   Print("🎯 Analysis for ", DoubleToString(testLots, 2), " lots of ", testSymbol, ":");
   Print("  💵 Required Margin: ", DoubleToString(analysis.requiredMargin, 2), " USD");
   Print("  🆓 Available Margin: ", DoubleToString(analysis.availableMargin, 2), " USD");
   Print("  📊 Utilization: ", DoubleToString(analysis.utilizationPercent, 1), "%");
   Print("  📈 Margin Level: ", DoubleToString(analysis.marginLevel, 2), "%");
   Print("  ✅ Can Open: ", analysis.canOpenPosition ? "YES" : "NO");
   
   if(!analysis.canOpenPosition && analysis.limitReason != "")
   {
      Print("  ⚠️  Reason: ", analysis.limitReason);
   }
   
   // Test graduali incrementi
   Print("\n📈 Testing graduated increases:");
   double testPercents[] = {10.0, 25.0, 50.0, 75.0, 90.0};
   
   for(int i = 0; i < ArraySize(testPercents); i++)
   {
      double percent = testPercents[i];
      double maxLots = g_marginCalc.CalculateMaxLotsForMargin(testSymbol, ORDER_TYPE_BUY, percent);
      
      Print("  ", DoubleToString(percent, 0), "% margin → Max lots: ", DoubleToString(maxLots, 3));
   }
}

//+------------------------------------------------------------------+
//| Test 5: Asset Detection                                        |
//+------------------------------------------------------------------+
void TestAssetDetection()
{
   Print("\n🔍 TEST 5: ASSET DETECTION");
   Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   
   // Test diversi pattern di simboli
   string testSymbols[] = {
      "EURUSD",     // Forex
      "GBPJPY",     // Forex
      "DAX40",      // Index  
      "SPX500",     // Index
      "NAS100",     // Index
      "BTCUSD",     // Crypto
      "ETHUSD",     // Crypto
      "XAUUSD",     // Commodity (Gold)
      "XAGUSD",     // Commodity (Silver)
      "CRUDE",      // Commodity (Oil)
      "UNKNOWN123"  // Unknown
   };
   
   for(int i = 0; i < ArraySize(testSymbols); i++)
   {
      string symbol = testSymbols[i];
      AssetInfo info = g_marginCalc.GetAssetInfo(symbol);
      
      Print("📋 ", symbol, " → Type: ", AssetTypeToString(info.type));
   }
}

//+------------------------------------------------------------------+
//| Test 6: Error Handling                                         |
//+------------------------------------------------------------------+
void TestErrorHandling()
{
   Print("\n🛡️ TEST 6: ERROR HANDLING");
   Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   
   // Test simbolo vuoto
   double result1 = g_marginCalc.GetRequiredMargin("", 1.0, ORDER_TYPE_BUY);
   Print("Empty symbol result: ", result1, " | Error: ", g_marginCalc.GetLastError());
   
   // Test lotti negativi
   double result2 = g_marginCalc.GetRequiredMargin("EURUSD", -1.0, ORDER_TYPE_BUY);
   Print("Negative lots result: ", result2, " | Error: ", g_marginCalc.GetLastError());
   
   // Test lotti zero
   double result3 = g_marginCalc.GetRequiredMargin("EURUSD", 0.0, ORDER_TYPE_BUY);
   Print("Zero lots result: ", result3, " | Error: ", g_marginCalc.GetLastError());
   
   // Test simbolo inesistente
   double result4 = g_marginCalc.GetRequiredMargin("FAKESYMBOL", 1.0, ORDER_TYPE_BUY);
   Print("Fake symbol result: ", result4, " | Error: ", g_marginCalc.GetLastError());
   
   Print("✅ Error handling tests completed");
}

//+------------------------------------------------------------------+
//| Test 7: Performance                                            |
//+------------------------------------------------------------------+
void TestPerformance()
{
   Print("\n⚡ TEST 7: PERFORMANCE");
   Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   
   string testSymbol = Symbol();
   int iterations = 1000;
   
   // Test performance calcoli multipli
   uint startTime = GetTickCount();
   
   for(int i = 0; i < iterations; i++)
   {
      double required = g_marginCalc.GetRequiredMargin(testSymbol, 0.1, ORDER_TYPE_BUY);
      bool canOpen = g_marginCalc.CanOpenPosition(testSymbol, 0.1, ORDER_TYPE_BUY);
   }
   
   uint endTime = GetTickCount();
   uint duration = endTime - startTime;
   
   Print("🔥 Performance test: ", iterations, " calculations in ", duration, " ms");
   Print("⚡ Average: ", DoubleToString((double)duration/iterations, 2), " ms per calculation");
   
   // Test cache effectiveness
   Print("\n💾 Testing cache effectiveness:");
   
   startTime = GetTickCount();
   for(int i = 0; i < 100; i++)
   {
      AssetInfo info = g_marginCalc.GetAssetInfo(testSymbol); // Dovrebbe usare cache
   }
   endTime = GetTickCount();
   
   Print("📈 100 cached AssetInfo calls: ", (endTime - startTime), " ms");
   
   // Clear cache e ri-test
   g_marginCalc.ClearCache();
   
   startTime = GetTickCount();
   AssetInfo info = g_marginCalc.GetAssetInfo(testSymbol); // Primo call, no cache
   endTime = GetTickCount();
   
   Print("🔄 First call (no cache): ", (endTime - startTime), " ms");
}

//+------------------------------------------------------------------+
//| Cleanup test resources - Aggiungi nel OnDeinit()              |
//+------------------------------------------------------------------+
void CleanupMarginCalculatorTest()
{
   if(g_marginCalc != NULL)
   {
      delete g_marginCalc;
      g_marginCalc = NULL;
      Print("🧪 MarginCalculator test resources cleaned up");
   }
}

// ============================================================================
// 🧪 FINE TEST MARGIN CALCULATOR - RIMUOVI TUTTO DOPO VALIDAZIONE
// ============================================================================

// ISTRUZIONI PER USARE IL TEST:
// 1. Sostituisci la sezione "Test base" nel OnInit() con: TestMarginCalculatorComplete();
// 2. Aggiungi nel OnDeinit(): CleanupMarginCalculatorTest();
// 3. Compila e testa su demo
// 4. Una volta validato, rimuovi tutto questo codice di test


// ============================================================================
// 🧪TEST MARGIN CALCULATOR - RIMUOVI TUTTO DOPO VALIDAZIONE
// ============================================================================
// 3. AGGIUNGI FUNZIONE DI INIZIALIZZAZIONE:
//+------------------------------------------------------------------+
//| Inizializza RiskManager                                         |
//+------------------------------------------------------------------+
bool InitializeRiskManager()
{
   g_riskManager = new RiskManager();
   if(g_riskManager == NULL) 
   {
      Print("ERROR: Failed to create RiskManager");
      return false;
   }
   
   // Inizializza con MarginCalculator (assumendo che g_marginCalc esista)
   if(!g_riskManager.Initialize(g_marginCalc))
   {
      Print("ERROR: RiskManager initialization failed - ", g_riskManager.GetLastError());
      return false;
   }
   
   // Configura parametri
   g_riskManager.SetMaxRiskPerTrade(2.0);        // Max 2% per trade
   g_riskManager.SetMaxMarginUtilization(80.0);  // Max 80% margine
   g_riskManager.SetUseEquityForRisk(false);     // Usa balance, non equity
   
   Print("✅ RiskManager initialized successfully");
   return true;
}

// 5. SOSTITUISCI I TEST COMMENTATI CON QUESTO TEST COMPLETO:
//+------------------------------------------------------------------+
//| 🧪 TEST RISK MANAGER - DA RIMUOVERE DOPO VALIDAZIONE           |
//+------------------------------------------------------------------+
void TestRiskManagerComplete()
{
   Print("\n");
   Print("🧪 ===============================================");
   Print("🧪 RISK MANAGER COMPLETE TEST SUITE");
   Print("🧪 ===============================================");
   
   if(g_riskManager == NULL)
   {
      Print("❌ CRITICAL: RiskManager not initialized");
      return;
   }
   
   // TEST 1: Account Info
   TestRiskManagerAccountInfo();
   
   // TEST 2: Position Sizing - Scenario Reale
   TestRiskManagerPositionSizing();
   
   // TEST 3: Multi-Asset
   TestRiskManagerMultiAsset();
   
   // TEST 4: Multi-Target Calculation  
   TestRiskManagerMultiTargets();
   
   // TEST 5: Error Handling
   TestRiskManagerErrorHandling();
   
   Print("🧪 ===============================================");
   Print("🧪 RISK MANAGER TEST SUITE COMPLETED");
   Print("🧪 ===============================================");
   Print("\n");
}

//+------------------------------------------------------------------+
//| Test 1: Account Information                                     |
//+------------------------------------------------------------------+
void TestRiskManagerAccountInfo()
{
   Print("\n💰 TEST 1: ACCOUNT INFO & RISK CALCULATION");
   Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   
   double balance = g_riskManager.GetAccountBalance();
   string currency = g_riskManager.GetAccountCurrency();
   
   Print("💰 Account Balance: ", DoubleToString(balance, 2), " ", currency);
   Print("⚡ Max Risk Per Trade: ", g_riskManager.GetMaxRiskPerTrade(), "%");
   
   // Test calcolo risk amount
   double risk05 = g_riskManager.CalculateRiskAmount(0.5);
   double risk10 = g_riskManager.CalculateRiskAmount(1.0);
   double risk20 = g_riskManager.CalculateRiskAmount(2.0);
   
   Print("💵 Risk 0.5%: ", DoubleToString(risk05, 2), " ", currency);
   Print("💵 Risk 1.0%: ", DoubleToString(risk10, 2), " ", currency);
   Print("💵 Risk 2.0%: ", DoubleToString(risk20, 2), " ", currency);
}

//+------------------------------------------------------------------+
//| Test 2: Position Sizing - SCENARIO REALE                       |
//+------------------------------------------------------------------+
void TestRiskManagerPositionSizing()
{
   Print("\n🎯 TEST 2: POSITION SIZING - SCENARIO REALE");
   Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   
   string testSymbol = Symbol(); // Simbolo attuale
   double riskPercent = 0.5;     // 0.5% risk come nel tuo esempio
   
   Print("📊 Testing with current symbol: ", testSymbol);
   Print("🎯 Risk percentage: ", riskPercent, "%");
   
   // Ottieni prezzo attuale
   MqlTick tick;
   if(!SymbolInfoTick(testSymbol, tick))
   {
      Print("❌ Cannot get tick data for ", testSymbol);
      return;
   }
   
   // DETECIONE ASSET TYPE E CALCOLO OFFSET INTELLIGENTE
   AssetInfo assetInfo = g_marginCalc.GetAssetInfo(testSymbol);
   double point = SymbolInfoDouble(testSymbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(testSymbol, SYMBOL_DIGITS);
   
   Print("🔍 Asset detection:");
   Print("  📋 Type: ", AssetTypeToString(assetInfo.type));
   Print("  🎯 Digits: ", digits);
   Print("  📏 Point: ", DoubleToString(point, 8));
   Print("  💎 Current Ask: ", DoubleToString(tick.ask, digits));
   
   // CALCOLO OFFSET DINAMICO BASATO SU ASSET TYPE
   double entryOffset, slOffset;
   
   switch(assetInfo.type)
   {
      case ASSET_FOREX:
         // Forex: 20-30 pips tipici
         entryOffset = 20 * point;   // 20 pips sopra
         slOffset = 37 * point;      // 37 pips sotto (come nel tuo esempio)
         Print("  🌍 FOREX mode: Using pip-based offsets");
         break;
         
      case ASSET_INDICES:
         // Indici: 20-50 punti tipici  
         entryOffset = 20.0;         // 20 punti sopra
         slOffset = 37.0;            // 37 punti sotto (come nel tuo esempio)
         Print("  📈 INDEX mode: Using point-based offsets");
         break;
         
      case ASSET_CRYPTO:
         // Crypto: percentuale del prezzo
         entryOffset = tick.ask * 0.002;  // +0.2%
         slOffset = tick.ask * 0.003;     // -0.3%
         Print("  🪙 CRYPTO mode: Using percentage-based offsets");
         break;
         
      case ASSET_COMMODITY:
      {
         // Commodity: basato su tick size
         double tickSize = SymbolInfoDouble(testSymbol, SYMBOL_TRADE_TICK_SIZE);
         entryOffset = tickSize * 20;     // 20 tick sopra
         slOffset = tickSize * 37;        // 37 tick sotto
         Print("  🥇 COMMODITY mode: Using tick-based offsets");
      }  
         break;
      default:
         // Fallback generico
         entryOffset = tick.ask * 0.001;  // +0.1%
         slOffset = tick.ask * 0.002;     // -0.2%
         Print("  ❓ UNKNOWN mode: Using generic percentage offsets");
         break;
   }
   
   Print("  ⚙️ Entry Offset: ", DoubleToString(entryOffset, digits));
   Print("  ⚙️ SL Offset: ", DoubleToString(slOffset, digits));
   
   // Test scenario BUY STOP
   Print("\n🟢 BUY STOP SCENARIO:");
   double buyEntry = tick.ask + entryOffset;
   double buySL = tick.ask - slOffset;
   
   // Normalizza ai decimali del simbolo
   buyEntry = NormalizeDouble(buyEntry, digits);
   buySL = NormalizeDouble(buySL, digits);
   
   Print("  📈 Entry: ", DoubleToString(buyEntry, digits));
   Print("  🛑 Stop Loss: ", DoubleToString(buySL, digits));
   
   // Verifica che entry != SL
   if(MathAbs(buyEntry - buySL) < point)
   {
      Print("  ⚠️  WARNING: Entry and SL too close, adjusting...");
      slOffset = entryOffset + (50 * point); // Forza distanza minima
      buySL = NormalizeDouble(tick.ask - slOffset, digits);
      Print("  🔧 Adjusted SL: ", DoubleToString(buySL, digits));
   }
   
   // Calcola position size
   PositionSizeInfo buyInfo = g_riskManager.CalculatePositionSize(testSymbol, buyEntry, buySL, riskPercent);
   
   if(buyInfo.isValid)
   {
      Print("  ✅ CALCULATION SUCCESS:");
      Print("    📦 Lots: ", DoubleToString(buyInfo.totalLots, 3));
      Print("    💵 Risk Amount: ", DoubleToString(buyInfo.riskAmount, 2), " USD");
      Print("    📏 SL Points: ", DoubleToString(buyInfo.stopLossPoints, 1));
      Print("    💎 Point Value: ", DoubleToString(buyInfo.pointValue, 4));
      
      // Verifica rischio effettivo
      double actualRisk = buyInfo.totalLots * buyInfo.stopLossPoints * buyInfo.pointValue;
      Print("    ✔️  Actual Risk: ", DoubleToString(actualRisk, 2), " USD");
      
      double riskDifference = MathAbs(actualRisk - buyInfo.riskAmount);
      bool riskMatch = riskDifference < 10.0; // Tolleranza 10 USD
      Print("    ✔️  Risk Match: ", riskMatch ? "YES" : "NO", 
            " (diff: ", DoubleToString(riskDifference, 2), " USD)");
   }
   else
   {
      Print("  ❌ CALCULATION FAILED: ", buyInfo.errorReason);
   }
   
   // Test scenario SELL STOP  
   Print("\n🔴 SELL STOP SCENARIO:");
   double sellEntry = tick.bid - entryOffset;
   double sellSL = tick.bid + slOffset;
   
   // Normalizza
   sellEntry = NormalizeDouble(sellEntry, digits);
   sellSL = NormalizeDouble(sellSL, digits);
   
   Print("  📉 Entry: ", DoubleToString(sellEntry, digits));
   Print("  🛑 Stop Loss: ", DoubleToString(sellSL, digits));
   
   PositionSizeInfo sellInfo = g_riskManager.CalculatePositionSize(testSymbol, sellEntry, sellSL, riskPercent);
   
   if(sellInfo.isValid)
   {
      Print("  ✅ CALCULATION SUCCESS:");
      Print("    📦 Lots: ", DoubleToString(sellInfo.totalLots, 3));
      Print("    💵 Risk Amount: ", DoubleToString(sellInfo.riskAmount, 2), " USD");
      
      // Confronta con scenario buy
      double lotsDifference = MathAbs(buyInfo.totalLots - sellInfo.totalLots);
      bool sameLots = lotsDifference < 0.001;
      Print("    ⚖️  Same lots as BUY: ", sameLots ? "YES" : "NO",
            " (diff: ", DoubleToString(lotsDifference, 3), ")");
   }
   else
   {
      Print("  ❌ CALCULATION FAILED: ", sellInfo.errorReason);
   }
   
   // SUMMARY
   Print("\n📊 TEST SUMMARY:");
   Print("  🎯 Asset Type: ", AssetTypeToString(assetInfo.type));
   Print("  📏 Distance Strategy: ", 
         (assetInfo.type == ASSET_FOREX) ? "Pip-based" :
         (assetInfo.type == ASSET_INDICES) ? "Point-based" :
         (assetInfo.type == ASSET_CRYPTO) ? "Percentage-based" :
         (assetInfo.type == ASSET_COMMODITY) ? "Tick-based" : "Generic");
   Print("  ✅ Buy Success: ", buyInfo.isValid ? "YES" : "NO");
   Print("  ✅ Sell Success: ", sellInfo.isValid ? "YES" : "NO");
}

//+------------------------------------------------------------------+
//| Test 3: Multi-Asset Testing                                    |
//+------------------------------------------------------------------+
void TestRiskManagerMultiAsset()
{
   Print("\n🌍 TEST 3: MULTI-ASSET TESTING");
   Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   
   string symbols[] = {"EURUSD", "GBPUSD", "USDJPY"};
   double riskPercent = 0.5;
   double testSLPoints = 200; // 20 pips for forex
   
   for(int i = 0; i < ArraySize(symbols); i++)
   {
      string symbol = symbols[i];
      Print("\n🔍 Testing: ", symbol);
      
      // Test calcolo lotti
      double lots = g_riskManager.CalculateLotsForRisk(symbol, riskPercent, testSLPoints);
      
      if(lots > 0)
      {
         Print("  ✅ Lots for ", riskPercent, "% risk: ", DoubleToString(lots, 3));
         
         // Test point value
         double pointValue = g_riskManager.GetPointValue(symbol);
         Print("  📊 Point Value: ", DoubleToString(pointValue, 4));
         
         // Test lot constraints
         double minLot = g_riskManager.GetMinLotSize(symbol);
         double maxLot = g_riskManager.GetMaxLotSize(symbol);
         double stepLot = g_riskManager.GetLotStep(symbol);
         
         Print("  📏 Lot Constraints: Min=", DoubleToString(minLot, 3), 
               " Max=", DoubleToString(maxLot, 0), " Step=", DoubleToString(stepLot, 3));
      }
      else
      {
         Print("  ❌ Failed: ", g_riskManager.GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| Test 4: Multi-Target Calculation                               |
//+------------------------------------------------------------------+
void TestRiskManagerMultiTargets()
{
   Print("\n🎯 TEST 4: MULTI-TARGET CALCULATION");
   Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   
   string testSymbol = Symbol();
   
   // Ottieni prezzo corrente
   MqlTick tick;
   if(!SymbolInfoTick(testSymbol, tick)) return;
   
   // STESSO SISTEMA DI OFFSET INTELLIGENTE
   AssetInfo assetInfo = g_marginCalc.GetAssetInfo(testSymbol);
   double point = SymbolInfoDouble(testSymbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(testSymbol, SYMBOL_DIGITS);
   
   double entryOffset, slOffset;
   
   switch(assetInfo.type)
   {
      case ASSET_FOREX:
         entryOffset = 20 * point;
         slOffset = 37 * point;
         break;
      case ASSET_INDICES:
         entryOffset = 20.0;
         slOffset = 37.0;
         break;
      case ASSET_CRYPTO:
         entryOffset = tick.ask * 0.002;
         slOffset = tick.ask * 0.003;
         break;
      case ASSET_COMMODITY:
      {
         double tickSize = SymbolInfoDouble(testSymbol, SYMBOL_TRADE_TICK_SIZE);
         entryOffset = tickSize * 20;
         slOffset = tickSize * 37;
      }
         break;
      default:
         entryOffset = tick.ask * 0.001;
         slOffset = tick.ask * 0.002;
         break;
   }
   
   double entryPrice = NormalizeDouble(tick.ask + entryOffset, digits);
   double stopLoss = NormalizeDouble(tick.ask - slOffset, digits);
   
   // Configura parametri strategia
   RiskParameters params;
   params.riskPercentage = 0.5;
   params.tp1RiskReward = 1.8;
   params.tp2RiskReward = 3.0;
   params.tp1VolumePercent = 50.0;
   params.tp2VolumePercent = 50.0;
   params.breakEvenAfterTP1 = true;
   
   Print("🎯 Multi-target scenario for: ", testSymbol, " (", AssetTypeToString(assetInfo.type), ")");
   Print("  📈 Entry: ", DoubleToString(entryPrice, digits));
   Print("  🛑 Stop Loss: ", DoubleToString(stopLoss, digits));
   Print("  📏 Distance: ", DoubleToString(MathAbs(entryPrice - stopLoss), digits));
   Print("  📊 TP1: ", params.tp1RiskReward, "R (", params.tp1VolumePercent, "%)");
   Print("  📊 TP2: ", params.tp2RiskReward, "R (", params.tp2VolumePercent, "%)");
   
   MultiTargetInfo targets = g_riskManager.CalculateMultiTargets(testSymbol, entryPrice, stopLoss, params);
   
   Print("  ✅ RESULTS:");
   Print("    🎯 TP1 Price: ", DoubleToString(targets.tp1Price, digits), " (", DoubleToString(targets.tp1Lots, 3), " lots)");
   Print("    🎯 TP2 Price: ", DoubleToString(targets.tp2Price, digits), " (", DoubleToString(targets.tp2Lots, 3), " lots)");
   Print("    📦 Remaining: ", DoubleToString(targets.remainingLots, 3), " lots");
}

//+------------------------------------------------------------------+
//| Test 5: Error Handling                                         |
//+------------------------------------------------------------------+
void TestRiskManagerErrorHandling()
{
   Print("\n🛡️ TEST 5: ERROR HANDLING");
   Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
   
   // Test simbolo vuoto
   double result1 = g_riskManager.CalculateLotsForRisk("", 0.5, 100);
   Print("Empty symbol: ", result1, " | Error: ", g_riskManager.GetLastError());
   
   // Test rischio eccessivo
   double result2 = g_riskManager.CalculateLotsForRisk("EURUSD", 5.0, 100);
   Print("Excessive risk (5%): ", result2, " | Error: ", g_riskManager.GetLastError());
   
   // Test SL zero
   double result3 = g_riskManager.CalculateLotsForRisk("EURUSD", 0.5, 0);
   Print("Zero SL points: ", result3, " | Error: ", g_riskManager.GetLastError());
   
   // Test rischio negativo
   double result4 = g_riskManager.CalculateLotsForRisk("EURUSD", -0.5, 100);
   Print("Negative risk: ", result4, " | Error: ", g_riskManager.GetLastError());
   
   Print("✅ Error handling tests completed");
}