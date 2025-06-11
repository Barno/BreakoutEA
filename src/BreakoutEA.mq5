//+------------------------------------------------------------------+
//|                                               BreakoutEA.mq5    |
//|                                  Strategia Breakout Bidirezionale |
//|                                      Con ChartVisualizer Integrato |
//+------------------------------------------------------------------+
#property copyright "BreakoutEA Team"
#property version   "1.00"
#property description "Strategia Breakout Bidirezionale con Visualizzazione"
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
input group "=== CANDELE DI RIFERIMENTO ==="
input int CandeleRiferimento_Ora1 = 8;           
input int CandeleRiferimento_Minuti1 = 45;       
input int CandeleRiferimento_Ora2 = 14;          
input int CandeleRiferimento_Minuti2 = 45;       
input ENUM_TIMEFRAMES TimeframeRiferimento = PERIOD_M15;
input color ColoreLineaVerticale = clrRed;        // Colore righe di riferimento

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
input int LineWidth = 1;                        // Spessore righe verticali
input ENUM_LINE_STYLE LineStyle = STYLE_SOLID;  // Stile righe verticali

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
   Print("=== BREAKOUT EA WITH CHART VISUALIZER ===");
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
   
   // Step 2: Inizializza ChartVisualizer  
   Print("\n2. INITIALIZING: ChartVisualizer");
   if(!InitializeChartVisualizer())
   {
      Print("ERROR: ChartVisualizer initialization failed");
      return(INIT_FAILED);
   }
   Print("SUCCESS: ChartVisualizer initialized");
   
   // Step 3: Disegna righe iniziali
   Print("\n3. DRAWING: Initial Reference Lines");
   DrawInitialReferenceLines();
   
   // Step 4: Setup timer per operazioni periodiche
   EventSetTimer(3600); // Timer ogni ora per cleanup
   
   g_isInitialized = true;
   g_lastVisualizationUpdate = TimeCurrent();
   g_lastCleanupCheck = TimeCurrent();

   // In OnInit():
g_timeManager = new TimeManager();
g_timeManager.Initialize(OffsetBroker_Ore);
   
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
   
   // Cleanup ChartVisualizer
   if(g_chartVisualizer != NULL)
   {
      g_chartVisualizer.CleanupAllLines();
      delete g_chartVisualizer;
      g_chartVisualizer = NULL;
   }
   
   // Cleanup ConfigManager
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
   
   // Check se serve aggiornare visualizzazione (ogni nuovo giorno)
   datetime currentTime = TimeCurrent();
   if(ShouldUpdateVisualization(currentTime))
   {
      UpdateReferenceLines();
      g_lastVisualizationUpdate = currentTime;
   }
   
   // TODO: Aggiungere logica trading principale qui
   // ProcessMainTradingLogic();
}

//+------------------------------------------------------------------+
//| Timer function                                                  |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(!g_isInitialized) return;
   
   datetime currentTime = TimeCurrent();
   
   // Cleanup periodico (ogni 24 ore)
   if(currentTime - g_lastCleanupCheck > 86400) // 24 ore in secondi
   {
      Print("Timer: Performing periodic cleanup...");
      if(g_chartVisualizer != NULL)
      {
         g_chartVisualizer.CleanupPreviousDayLines();
      }
      g_lastCleanupCheck = currentTime;
   }
   
   // Log heartbeat
   Print("Timer: BreakoutEA heartbeat - Visualization objects: ", 
         g_chartVisualizer != NULL ? g_chartVisualizer.GetObjectCount() : 0);
}

//+------------------------------------------------------------------+
//| Inizializza ConfigManager                                       |
//+------------------------------------------------------------------+
bool InitializeConfigManager()
{
   g_configManager = new ConfigManager();
   if(g_configManager == NULL)
   {
      Print("ERROR: Failed to create ConfigManager");
      return false;
   }
   
   // Carica parametri
   if(!g_configManager.LoadParameters(
      RischioPercentuale, LevaBroker, SpreadBufferPips, MaxSpreadPips,
      CandeleRiferimento_Ora1, CandeleRiferimento_Minuti1, 
      CandeleRiferimento_Ora2, CandeleRiferimento_Minuti2, TimeframeRiferimento,
      NumeroTakeProfit, TP1_RiskReward, TP1_PercentualeVolume, 
      TP2_RiskReward, TP2_PercentualeVolume, AttivareBreakevenDopoTP,
      TradingLunedi, TradingMartedi, TradingMercoledi, TradingGiovedi, 
      TradingVenerdi, TradingSabato, TradingDomenica))
   {
      Print("ERROR: Failed to load parameters");
      return false;
   }
   
   // Valida parametri
   if(!g_configManager.ValidateParameters())
   {
      Print("ERROR: Parameter validation failed - ", g_configManager.GetLastError());
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Inizializza ChartVisualizer                                     |
//+------------------------------------------------------------------+
bool InitializeChartVisualizer()
{
   g_chartVisualizer = new ChartVisualizer();
   if(g_chartVisualizer == NULL)
   {
      Print("ERROR: Failed to create ChartVisualizer");
      return false;
   }
   
   // Inizializza con parametri da input (NO hardcoded!)
   if(!g_chartVisualizer.Initialize(ColoreLineaVerticale, LineWidth, LineStyle))
   {
      Print("ERROR: Failed to initialize ChartVisualizer");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Disegna righe di riferimento iniziali                          |
//+------------------------------------------------------------------+
void DrawInitialReferenceLines()
{
   if(g_configManager == NULL || g_chartVisualizer == NULL) return;
   
   // Ottieni configurazione sessioni (NO hardcoded!)
   SessionConfig sessionConfig = g_configManager.GetSessionConfig();
   
   // Disegna riga per sessione 1
   datetime session1Time = CalculateReferenceCandleTime(
      sessionConfig.referenceHour1,
      sessionConfig.referenceMinute1
   );
   
   if(session1Time > 0)
   {
      g_chartVisualizer.DrawReferenceCandle(session1Time, "Session1");
      Print("Reference line drawn for Session1 at ", TimeToString(session1Time, TIME_DATE | TIME_MINUTES));
   }
   
   // Disegna riga per sessione 2
   datetime session2Time = CalculateReferenceCandleTime(
      sessionConfig.referenceHour2,
      sessionConfig.referenceMinute2
   );
   
   if(session2Time > 0)
   {
      g_chartVisualizer.DrawReferenceCandle(session2Time, "Session2");
      Print("Reference line drawn for Session2 at ", TimeToString(session2Time, TIME_DATE | TIME_MINUTES));
   }
}

//+------------------------------------------------------------------+
//| Calcola tempo candela di riferimento                           |
//+------------------------------------------------------------------+
datetime CalculateReferenceCandleTime(int hour, int minute)
{
   // Validazione parametri
   if(hour < 0 || hour > 23 || minute < 0 || minute > 59)
   {
      Print("ERROR: Invalid time parameters - Hour: ", hour, " Minute: ", minute);
      return 0;
   }
   
   datetime currentTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   
   // Imposta orario sessione (NO hardcoded!)
   dt.hour = hour;
   dt.min = minute;
   dt.sec = 0;
   
   return StructToTime(dt);
}

//+------------------------------------------------------------------+
//| Determina se serve aggiornare visualizzazione                  |
//+------------------------------------------------------------------+
bool ShouldUpdateVisualization(datetime currentTime)
{
   // Se è il primo tick del giorno, aggiorna
   MqlDateTime currentDt, lastUpdateDt;
   TimeToStruct(currentTime, currentDt);
   TimeToStruct(g_lastVisualizationUpdate, lastUpdateDt);
   
   // Nuovo giorno = nuovo update
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
   
   // Cleanup righe del giorno precedente
   g_chartVisualizer.CleanupPreviousDayLines();
   
   // Disegna nuove righe per oggi
   DrawInitialReferenceLines();
   
   Print("Reference lines updated successfully");
}

//+------------------------------------------------------------------+
//| Ottiene descrizione motivo deinit                              |
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