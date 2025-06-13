   //+------------------------------------------------------------------+
   //|                                               BEN Strategy.mq5    |
   //|                                  Strategia Breakout Bidirezionale |
   //|                                  Broker Time System + CandleAnalyzer |
   //+------------------------------------------------------------------+
   #property copyright "Ben Team"
   #property version   "0.12"
   #property description "Strategia Breakout Bidirezionale - Broker Time System + CandleAnalyzer"
   #property strict

   //+------------------------------------------------------------------+
   //| Include Headers (ORDINE CORRETTO per Dependencies)             |
   //+------------------------------------------------------------------+
   #include "Enums.mqh"
   #include "ConfigManager.mqh"
   #include "ChartVisualizer.mqh"
   #include "TelegramLogger.mqh"
   #include "MarginCalculator.mqh"      
   #include "AssetDetector.mqh"         
   #include "RiskManager.mqh"           
   #include "CandleAnalyzer.mqh"        // ✅ NUOVO: Analisi candele

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

   input group "=== FILTRI CANDELA DI RIFERIMENTO ==="
   input bool FiltroCorporeAttivo = false;         // ✅ NUOVO: Abilita filtro corpo (default OFF)
   input double ForexCorpoMinimoPips = 5.0;        // ✅ NUOVO: Corpo minimo Forex (pips)
   input double IndiciCorpoMinimoPunti = 3.0;      // ✅ NUOVO: Corpo minimo Indici (punti)
   input double CryptoCorpoMinimoPunti = 50.0;     // ✅ NUOVO: Corpo minimo Crypto (punti)
   input double CommodityCorpoMinimoPunti = 5.0;   // ✅ NUOVO: Corpo minimo Commodity (punti)
   input double DistanzaEntryPunti = 1.0;          // ✅ NUOVO: Distanza aggiuntiva entry (punti)
   input double DistanzaSLPunti = 1.0;             // ✅ NUOVO: Distanza aggiuntiva SL (punti)

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
   input bool AbilitaTelegram = false;             // Abilita notifiche Telegram
   input string TelegramBotToken = "7707070116:AAFSBXAHULIq0z17osNdRq75YS7ckI2uCEQ";             
   input string TelegramChatID = "-1002804238340";               
   input bool LogServerTimeCheck = true;           
   input bool LogSessionAlerts = true;             
   input bool LogCandleOHLC = true;                
   input bool LogSystemHealth = true;              

   //+------------------------------------------------------------------+
   //| Global Variables                                                 |
   //+------------------------------------------------------------------+
   ConfigManager* g_configManager = NULL;
   ChartVisualizer* g_chartVisualizer = NULL;
   TelegramLogger* g_telegramLogger = NULL;
   MarginCalculator* g_marginCalc = NULL;          
   AssetDetector* g_assetDetector = NULL;          
   RiskManager* g_riskManager = NULL;              
   CandleAnalyzer* g_candleAnalyzer = NULL;        // ✅ NUOVO: CandleAnalyzer

   bool g_isInitialized = false;
   datetime g_lastVisualizationUpdate = 0;
   datetime g_lastCleanupCheck = 0;
   datetime g_lastServerTimeCheck = 0;

   //+------------------------------------------------------------------+
   //| Expert initialization function                                   |
   //+------------------------------------------------------------------+
   int OnInit()
   {
      Print("🚀 BenStrategy v0.12 - Broker Time System + CandleAnalyzer");
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
      
      // ✅ NUOVO: Inizializza CandleAnalyzer
      if(!InitializeCandleAnalyzer())
      {
         Print("ERROR: CandleAnalyzer initialization failed");
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

      // ✅ SOLO: Broker & Symbol Info (NESSUN TEST)
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
      
      // ✅ CLEANUP IN REVERSE ORDER (incluso CandleAnalyzer)
      if(g_candleAnalyzer != NULL)
      {
         delete g_candleAnalyzer;
         g_candleAnalyzer = NULL;
      }
      
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
      
      // Controlla se siamo in un orario di sessione
   datetime currentTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);

   // Calcola orari sessioni con DST
   int session1Hour = (Session1_Hour + (IsSummerTime ? 1 : 0)) % 24;
   int session2Hour = (Session2_Hour + (IsSummerTime ? 1 : 0)) % 24;

   // Verifica se siamo ESATTAMENTE negli orari di sessione
   if((dt.hour == session1Hour && dt.min == Session1_Minute) ||
      (dt.hour == session2Hour && dt.min == Session2_Minute))
   {
      // Controlla se non abbiamo già testato questa sessione
      static datetime lastTestedSession = 0;
      datetime currentSessionTime = StructToTime(dt);
      
      if(currentSessionTime != lastTestedSession)
      {
         // 🎯 TEST DELLA SESSIONE REALE
         TestSessionCandleReference(currentSessionTime);
         lastTestedSession = currentSessionTime;
      }
   }
      
      
      // TODO: Implementare logica trading principale
      // 1. Verifica se è orario di apertura sessione
      // 2. Analizza candela di riferimento con CandleAnalyzer
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
   //| ✅ NUOVO: Inizializza CandleAnalyzer                           |
   //+------------------------------------------------------------------+
   bool InitializeCandleAnalyzer()
   {
      g_candleAnalyzer = new CandleAnalyzer();
      if(g_candleAnalyzer == NULL) 
      {
         Print("ERROR: Failed to create CandleAnalyzer");
         return false;
      }
      
      // ✅ Configura filtri dalla input configuration
      CandleFilters filters;
      filters.corpoFilterActive = FiltroCorporeAttivo;           // Default: false
      filters.forexCorpoMinPips = ForexCorpoMinimoPips;          // Default: 5.0
      filters.indicesCorpoMinPoints = IndiciCorpoMinimoPunti;    // Default: 3.0
      filters.cryptoCorpoMinPoints = CryptoCorpoMinimoPunti;     // Default: 50.0
      filters.commodityCorpoMinPoints = CommodityCorpoMinimoPunti; // Default: 5.0
      
      if(!g_candleAnalyzer.Initialize(Symbol(), TimeframeRiferimento, filters))
      {
         Print("ERROR: CandleAnalyzer initialization failed - ", g_candleAnalyzer.GetLastError());
         return false;
      }
      
      Print("✅ CandleAnalyzer initialized successfully");
      Print("  🔍 Asset Type: ", AssetTypeToString(g_candleAnalyzer.GetAssetType()));
      Print("  📊 Filtro Corpo: ", FiltroCorporeAttivo ? "ATTIVATO" : "DISATTIVATO");
      Print("  📏 Point Value: ", DoubleToString(g_candleAnalyzer.GetPointValue(), 6));
      Print("  💱 Pip Value: ", DoubleToString(g_candleAnalyzer.GetPipValue(), 6));
      
      return true;
   }

   //+------------------------------------------------------------------+
   //| ✅ NUOVO: Test CandleAnalyzer su candela corrente              |
   //+------------------------------------------------------------------+
   void TestCandleAnalysisOnCurrentCandle()
   {
      if(g_candleAnalyzer == NULL) return;
      
      Print("\n🕯️ === CANDLEANALYZER TEST ===");
      
      // Prendi ultima candela completa
      datetime lastCandleTime = iTime(Symbol(), TimeframeRiferimento, 1);
      
      if(lastCandleTime == 0)
      {
         Print("❌ Cannot get last candle time");
         return;
      }
      
      // Analizza candela
      CandleData candle = g_candleAnalyzer.GetReferenceCandleData(lastCandleTime);
      
      if(!g_candleAnalyzer.IsCandleValid(candle))
      {
         Print("❌ Invalid candle data");
         return;
      }
      
      // Log dettagli candela
      g_candleAnalyzer.LogCandleDetails(candle, "TEST");
      
      // Test filtro corpo
      bool passesFilter = g_candleAnalyzer.PassesCorporeFilter(candle);
      Print("🔍 Passa filtro corpo: ", passesFilter ? "✅ SÌ" : "❌ NO");
      
      if(FiltroCorporeAttivo && !passesFilter)
      {
         double requiredMinimum = g_candleAnalyzer.GetCorpoMinimumForAsset(g_candleAnalyzer.GetAssetType());
         Print("   📏 Corpo richiesto: ", DoubleToString(requiredMinimum, 2), " (", AssetTypeToString(g_candleAnalyzer.GetAssetType()), ")");
         Print("   📏 Corpo attuale: ", DoubleToString(candle.GetBody() / g_candleAnalyzer.GetPointValue(), 2));
      }
      
      // Test calcolo livelli solo se passa filtro (o filtro disattivato)
      if(passesFilter)
      {
         EntryLevels levels = g_candleAnalyzer.CalculateEntryLevels(candle, 
                                                                  SpreadBufferPips, 
                                                                  DistanzaEntryPunti, 
                                                                  DistanzaSLPunti);
         
         if(levels.valid)
         {
            Print("✅ SETUP VALIDO:");
            Print("   📈 Buy Entry: ", DoubleToString(levels.buyEntry, _Digits), " | SL: ", DoubleToString(levels.buySL, _Digits));
            Print("   📉 Sell Entry: ", DoubleToString(levels.sellEntry, _Digits), " | SL: ", DoubleToString(levels.sellSL, _Digits));
            
            // Calcola distanze SL
            double buySlDistance = MathAbs(levels.buyEntry - levels.buySL);
            double sellSlDistance = MathAbs(levels.sellEntry - levels.sellSL);
            Print("   📏 Distanza SL - Buy: ", DoubleToString(buySlDistance, _Digits));
            Print("   📏 Distanza SL - Sell: ", DoubleToString(sellSlDistance, _Digits));
            
            // Test spread validation
            double currentSpread = SymbolInfoDouble(Symbol(), SYMBOL_SPREAD) * SymbolInfoDouble(Symbol(), SYMBOL_POINT);
            double maxSpreadPrice = MaxSpreadPips * SymbolInfoDouble(Symbol(), SYMBOL_POINT);
            bool validSpread = g_candleAnalyzer.ValidateSpread(currentSpread, maxSpreadPrice);
            Print("   💱 Spread valido: ", validSpread ? "✅ SÌ" : "❌ NO");
         }
         else
         {
            Print("❌ Setup non valido - ", g_candleAnalyzer.GetLastError());
         }
      }
      
      Print("🕯️ === FINE TEST ===\n");
   }

   // ============================================================================
   // INITIALIZATION FUNCTIONS (Mantenute invariate)
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
      
      Print("✅ RiskManager initialized successfully with AssetDetector integration");
      return true;
   }

   // ============================================================================
   // EXISTING FUNCTIONS (mantenute invariate)
   // ============================================================================

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
      
      Print("\n=== SYMBOL INFORMATION ===");
      string symbol = Symbol();
      
      Print("Symbol: ", symbol);
      Print("Description: ", SymbolInfoString(symbol, SYMBOL_DESCRIPTION));
      Print("Currency Base: ", SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE));
      Print("Currency Profit: ", SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT));
      Print("Currency Margin: ", SymbolInfoString(symbol, SYMBOL_CURRENCY_MARGIN));
      
      Print("Contract Size: ", SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE));
      Print("Tick Size: ", SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE));
      Print("Tick Value: ", SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE));
      Print("Point: ", SymbolInfoDouble(symbol, SYMBOL_POINT));
      Print("Digits: ", SymbolInfoInteger(symbol, SYMBOL_DIGITS));
      
      Print("Volume Min: ", SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN));
      Print("Volume Max: ", SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX));
      Print("Volume Step: ", SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP));
      
      Print("Margin Initial: ", SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL));
      Print("Margin Maintenance: ", SymbolInfoDouble(symbol, SYMBOL_MARGIN_MAINTENANCE));
      
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