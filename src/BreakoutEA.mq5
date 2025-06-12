//+------------------------------------------------------------------+
//|                                               BreakoutEA.mq5    |
//|                                  Strategia Breakout Bidirezionale |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "BreakoutEA Team"
#property version   "1.00"
#property description "Strategia Breakout Bidirezionale"
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
   Print("🚀 BreakoutEA v1.0 - Initializing...");
   Print("Symbol: ", Symbol(), " | Timeframe: ", EnumToString(Period()));
   
   g_isInitialized = false;
   
   // Inizializza ConfigManager
   if(!InitializeConfigManager())
   {
      Print("ERROR: ConfigManager initialization failed");
      return(INIT_FAILED);
   }
   
   // Inizializza TimeManager
   if(!InitializeTimeManager())
   {
      Print("ERROR: TimeManager initialization failed");
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
   
   // Setup timer per cleanup periodico
   EventSetTimer(3600); // Timer ogni ora
   
   g_isInitialized = true;
   g_lastVisualizationUpdate = TimeCurrent();
   g_lastCleanupCheck = TimeCurrent();
   
   Print("✅ BreakoutEA initialized successfully");
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
//| Disegna righe di riferimento iniziali                          |
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
   
   // Disegna le righe
   if(session1TimeBroker > 0)
   {
      g_chartVisualizer.DrawReferenceCandle(session1TimeBroker, "Session1");
   }
   
   if(session2TimeBroker > 0)
   {
      g_chartVisualizer.DrawReferenceCandle(session2TimeBroker, "Session2");
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
   
   g_chartVisualizer.CleanupPreviousDayLines();
   DrawInitialReferenceLines();
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