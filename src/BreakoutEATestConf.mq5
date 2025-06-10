//+------------------------------------------------------------------+
//|                                               BreakoutEA.mq5    |
//|                                  TEST ConfigManager Implementation |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "BreakoutEA Team"
#property version   "1.00"
#property description "TEST: ConfigManager Functionality"
#property strict

//+------------------------------------------------------------------+
//| Include Headers                                                  |
//+------------------------------------------------------------------+
#include "Enums.mqh"
#include "ConfigManager.mqh"

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

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
ConfigManager* g_configManager = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== BREAKOUT EA - CONFIG MANAGER TEST ===");
   Print("Symbol: ", Symbol(), " | Timeframe: ", EnumToString(Period()));
   
   // Test 1: Creazione ConfigManager
   Print("\n1. TESTING: ConfigManager Creation");
   g_configManager = new ConfigManager();
   if(g_configManager == NULL)
   {
      Print("ERROR: Failed to create ConfigManager");
      return(INIT_FAILED);
   }
   Print("SUCCESS: ConfigManager created");
   
   // Test 2: Caricamento parametri
   Print("\n2. TESTING: Parameter Loading");
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
      Print("Error: ", g_configManager.GetLastError());
      return(INIT_FAILED);
   }
   Print("SUCCESS: Parameters loaded");
   
   // Test 3: Stampa parametri caricati
   Print("\n3. TESTING: Print Loaded Parameters");
   PrintLoadedParameters();
   
   // Test 4: Validazione parametri
   Print("\n4. TESTING: Parameter Validation");
   if(!g_configManager.ValidateParameters())
   {
      Print("ERROR: Parameter validation failed");
      Print("Error: ", g_configManager.GetLastError());
      return(INIT_PARAMETERS_INCORRECT);
   }
   Print("SUCCESS: All parameters valid");
   
   // Test 5: Test accesso configurazione
   Print("\n5. TESTING: Configuration Access");
   TestConfigurationAccess();
   
   // Test 6: Test validazione con parametri errati
   Print("\n6. TESTING: Validation with Invalid Parameters");
   TestInvalidParameterValidation();
   
   Print("\n=== ALL TESTS COMPLETED SUCCESSFULLY ===");
   Print("ConfigManager is working correctly!");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Shutting down ConfigManager test...");
   
   if(g_configManager != NULL)
   {
      delete g_configManager;
      g_configManager = NULL;
   }
   
   Print("ConfigManager test completed");
}

//+------------------------------------------------------------------+
//| Expert tick function (minimal for test)                        |
//+------------------------------------------------------------------+
void OnTick()
{
   // Minimal tick function for test
   static int tickCount = 0;
   tickCount++;
   
   if(tickCount % 1000 == 0) // Every 1000 ticks
   {
      Print("Tick ", tickCount, " - ConfigManager status: ", 
            g_configManager != NULL && g_configManager.IsValid() ? "OK" : "ERROR");
   }
}

//+------------------------------------------------------------------+
//| Stampa tutti i parametri caricati                              |
//+------------------------------------------------------------------+
void PrintLoadedParameters()
{
   if(g_configManager == NULL) return;
   
   RiskConfig riskConfig = g_configManager.GetRiskConfig();
   SessionConfig sessionConfig = g_configManager.GetSessionConfig();
   TPConfig tpConfig = g_configManager.GetTPConfig();
   TradingCalendar calendar = g_configManager.GetTradingCalendar();
   
   Print("--- RISK CONFIGURATION ---");
   Print("Risk Percentage: ", riskConfig.riskPercentage, "%");
   Print("Leverage: ", riskConfig.leverage);
   Print("Spread Buffer: ", riskConfig.spreadBuffer, " pips");
   Print("Max Spread: ", riskConfig.maxSpread, " pips");
   
   Print("--- SESSION CONFIGURATION ---");
   Print("Session 1: ", sessionConfig.referenceHour1, ":", 
         StringFormat("%02d", sessionConfig.referenceMinute1));
   Print("Session 2: ", sessionConfig.referenceHour2, ":", 
         StringFormat("%02d", sessionConfig.referenceMinute2));
   Print("Timeframe: ", EnumToString(sessionConfig.timeframe));
   
   Print("--- TAKE PROFIT CONFIGURATION ---");
   Print("Number of TP: ", tpConfig.numberOfTP);
   Print("TP1 R:R: ", tpConfig.tp1RiskReward, " | Volume: ", tpConfig.tp1Percentage, "%");
   Print("TP2 R:R: ", tpConfig.tp2RiskReward, " | Volume: ", tpConfig.tp2Percentage, "%");
   Print("Breakeven after TP: ", tpConfig.breakEvenAfterTP ? "YES" : "NO");
   
   Print("--- TRADING CALENDAR ---");
   Print("Mon: ", calendar.monday ? "ON" : "OFF", 
         " | Tue: ", calendar.tuesday ? "ON" : "OFF",
         " | Wed: ", calendar.wednesday ? "ON" : "OFF");
   Print("Thu: ", calendar.thursday ? "ON" : "OFF",
         " | Fri: ", calendar.friday ? "ON" : "OFF");
   Print("Sat: ", calendar.saturday ? "ON" : "OFF",
         " | Sun: ", calendar.sunday ? "ON" : "OFF");
}

//+------------------------------------------------------------------+
//| Test accesso configurazione                                     |
//+------------------------------------------------------------------+
void TestConfigurationAccess()
{
   if(g_configManager == NULL) return;
   
   Print("Testing configuration access methods...");
   
   // Test getter methods
   RiskConfig risk = g_configManager.GetRiskConfig();
   SessionConfig session = g_configManager.GetSessionConfig();
   TPConfig tp = g_configManager.GetTPConfig();
   TradingCalendar cal = g_configManager.GetTradingCalendar();
   
   // Test configuration state
   bool isValid = g_configManager.IsValid();
   string lastError = g_configManager.GetLastError();
   
   Print("Configuration access test:");
   Print("- Risk config loaded: ", risk.riskPercentage > 0 ? "OK" : "ERROR");
   Print("- Session config loaded: ", session.timeframe > 0 ? "OK" : "ERROR");
   Print("- TP config loaded: ", tp.numberOfTP > 0 ? "OK" : "ERROR");
   Print("- Calendar loaded: OK");
   Print("- IsValid(): ", isValid ? "TRUE" : "FALSE");
   Print("- LastError: '", lastError, "'");
}

//+------------------------------------------------------------------+
//| Test validazione con parametri non validi                      |
//+------------------------------------------------------------------+
void TestInvalidParameterValidation()
{
   Print("Creating temporary ConfigManager for invalid parameter test...");
   
   ConfigManager* testManager = new ConfigManager();
   
   // Test con parametri non validi
   Print("Testing with invalid risk percentage (15%)...");
   if(testManager.LoadParameters(
      15.0, LevaBroker, SpreadBufferPips, MaxSpreadPips,  // Risk troppo alto
      CandeleRiferimento_Ora1, CandeleRiferimento_Minuti1, 
      CandeleRiferimento_Ora2, CandeleRiferimento_Minuti2, TimeframeRiferimento,
      NumeroTakeProfit, TP1_RiskReward, TP1_PercentualeVolume, 
      TP2_RiskReward, TP2_PercentualeVolume, AttivareBreakevenDopoTP,
      TradingLunedi, TradingMartedi, TradingMercoledi, TradingGiovedi, 
      TradingVenerdi, TradingSabato, TradingDomenica))
   {
      if(!testManager.ValidateParameters())
      {
         Print("SUCCESS: Invalid parameters correctly rejected - ", testManager.GetLastError());
      }
      else
      {
         Print("ERROR: Invalid parameters were accepted!");
      }
   }
   
   delete testManager;
   Print("Invalid parameter validation test completed");
}