//+------------------------------------------------------------------+
//|                                               BreakoutEA.mq5    |
//|                                  SOLID Principles Applied Correctly |
//|                                      Clean Architecture MQL5     |
//+------------------------------------------------------------------+
#property copyright "BreakoutEA Team"
#property version   "1.00"
#property description "Strategia Breakout Bidirezionale - SOLID Architecture"
#property strict

//+------------------------------------------------------------------+
//| Include Headers - Dependency Inversion Principle                |
//+------------------------------------------------------------------+
#include "Enums.mqh"

// Interfaces (Dependency Inversion Principle)
// #include "Interfaces/IConfigManager.mqh"
// #include "Interfaces/ISessionManager.mqh"
// #include "Interfaces/IRiskManager.mqh"
// #include "Interfaces/IOrderManager.mqh"
// #include "Interfaces/ITimeManager.mqh"
// #include "Interfaces/ITelegramLogger.mqh"

// Concrete Implementations
// #include "ConfigManager.mqh"
// #include "SessionManager.mqh"
// #include "RiskManager.mqh"
// etc...

//+------------------------------------------------------------------+
//| Input Parameters - Interface Segregation Principle             |
//+------------------------------------------------------------------+
input group "=== 📊 CANDELE DI RIFERIMENTO ==="
input int CandeleRiferimento_Ora1 = 8;           
input int CandeleRiferimento_Minuti1 = 45;       
input int CandeleRiferimento_Ora2 = 14;          
input int CandeleRiferimento_Minuti2 = 45;       
input ENUM_TIMEFRAMES TimeframeRiferimento = PERIOD_M15;

input group "=== ⚖️ GESTIONE DEL RISCHIO ==="
input double RischioPercentuale = 0.5;           
input int LevaBroker = 100;                      
input double SpreadBufferPips = 2.0;            
input double MaxSpreadPips = 10.0;              

input group "=== 🎯 TAKE PROFIT ==="
input int NumeroTakeProfit = 2;                 
input double TP1_RiskReward = 2.0;              
input double TP1_PercentualeVolume = 50.0;      
input double TP2_RiskReward = 3.0;              
input double TP2_PercentualeVolume = 50.0;      

input group "=== 📱 TELEGRAM ==="
input bool AbilitaTelegram = false;             
input string TelegramBotToken = "";             
input string TelegramChatID = "";               

//+------------------------------------------------------------------+
//| Dependency Injection Container - Dependency Inversion           |
//+------------------------------------------------------------------+
class DIContainer
{
private:
   // Interfaces - not concrete classes (Dependency Inversion)
   // IConfigManager*     m_configManager;
   // ISessionManager*    m_sessionManager;
   // IRiskManager*       m_riskManager;
   // IOrderManager*      m_orderManager;
   // ITimeManager*       m_timeManager;
   // ITelegramLogger*    m_telegramLogger;
   
public:
   DIContainer() { /* Initialize interfaces */ }
   ~DIContainer() { /* Cleanup interfaces */ }
   
   // Factory methods (Open/Closed Principle)
   // IConfigManager* GetConfigManager() { return m_configManager; }
   // ISessionManager* GetSessionManager() { return m_sessionManager; }
   // etc...
   
   bool InitializeServices()
   {
      // TODO: Initialize all services through interfaces
      return true;
   }
   
   void CleanupServices()
   {
      // TODO: Cleanup all services
   }
};

//+------------------------------------------------------------------+
//| System Initializer - Single Responsibility Principle           |
//+------------------------------------------------------------------+
class SystemInitializer
{
public:
   // SRP: Only responsible for system initialization
   static bool Initialize(DIContainer* container)
   {
      Print("🔧 SystemInitializer: Starting initialization...");
      
      if(!container.InitializeServices())
      {
         Print("❌ SystemInitializer: Service initialization failed");
         return false;
      }
      
      Print("✅ SystemInitializer: Initialization completed");
      return true;
   }
};

//+------------------------------------------------------------------+
//| Parameter Validator - Single Responsibility Principle          |
//+------------------------------------------------------------------+
class ParameterValidator
{
public:
   // SRP: Only responsible for parameter validation
   static bool ValidateAll()
   {
      Print("🔍 ParameterValidator: Starting validation...");
      
      if(!ValidateRiskParameters()) return false;
      if(!ValidateTimeParameters()) return false;
      if(!ValidateTPParameters()) return false;
      
      Print("✅ ParameterValidator: All parameters valid");
      return true;
   }
   
private:
   // Interface Segregation: Separate validation methods
   static bool ValidateRiskParameters()
   {
      if(RischioPercentuale <= 0 || RischioPercentuale > 10)
      {
         Print("❌ ParameterValidator: Invalid RischioPercentuale");
         return false;
      }
      
      if(LevaBroker <= 0 || LevaBroker > 1000)
      {
         Print("❌ ParameterValidator: Invalid LevaBroker");
         return false;
      }
      
      return true;
   }
   
   static bool ValidateTimeParameters()
   {
      if(CandeleRiferimento_Ora1 < 0 || CandeleRiferimento_Ora1 > 23)
      {
         Print("❌ ParameterValidator: Invalid session 1 hour");
         return false;
      }
      
      if(CandeleRiferimento_Ora2 < 0 || CandeleRiferimento_Ora2 > 23)
      {
         Print("❌ ParameterValidator: Invalid session 2 hour");
         return false;
      }
      
      return true;
   }
   
   static bool ValidateTPParameters()
   {
      if(NumeroTakeProfit < 1 || NumeroTakeProfit > 10)
      {
         Print("❌ ParameterValidator: Invalid NumeroTakeProfit");
         return false;
      }
      
      if(TP1_PercentualeVolume + TP2_PercentualeVolume > 100)
      {
         Print("❌ ParameterValidator: TP percentages exceed 100%");
         return false;
      }
      
      return true;
   }
};

//+------------------------------------------------------------------+
//| Environment Validator - Single Responsibility Principle        |
//+------------------------------------------------------------------+
class EnvironmentValidator
{
public:
   // SRP: Only responsible for environment validation
   static bool ValidateEnvironment()
   {
      Print("🌍 EnvironmentValidator: Checking environment...");
      
      if(!ValidateConnection()) return false;
      if(!ValidatePermissions()) return false;
      if(!ValidateAccount()) return false;
      
      Print("✅ EnvironmentValidator: Environment valid");
      return true;
   }
   
private:
   static bool ValidateConnection()
   {
      if(!TerminalInfoInteger(TERMINAL_CONNECTED))
      {
         Print("❌ EnvironmentValidator: Terminal not connected");
         return false;
      }
      return true;
   }
   
   static bool ValidatePermissions()
   {
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      {
         Print("❌ EnvironmentValidator: Trading not allowed in terminal");
         return false;
      }
      
      if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
      {
         Print("❌ EnvironmentValidator: EA trading not allowed");
         return false;
      }
      
      return true;
   }
   
   static bool ValidateAccount()
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(balance <= 0)
      {
         Print("❌ EnvironmentValidator: Invalid account balance");
         return false;
      }
      
      Print("💰 EnvironmentValidator: Account Balance: ", balance);
      return true;
   }
};

//+------------------------------------------------------------------+
//| System Monitor - Single Responsibility Principle               |
//+------------------------------------------------------------------+
class SystemMonitor
{
private:
   static datetime s_lastHeartbeat;
   static datetime s_lastLog;
   
public:
   // SRP: Only responsible for system monitoring
   static void UpdateHeartbeat()
   {
      s_lastHeartbeat = TimeCurrent();
      
      // Log hourly heartbeat
      if(TimeCurrent() - s_lastLog > 3600)
      {
         Print("💓 SystemMonitor: Heartbeat at ", TimeToString(s_lastHeartbeat));
         s_lastLog = TimeCurrent();
      }
   }
   
   static datetime GetLastHeartbeat() { return s_lastHeartbeat; }
   
   static bool IsSystemHealthy()
   {
      // Check if heartbeat is recent (within 5 minutes)
      return (TimeCurrent() - s_lastHeartbeat) < 300;
   }
};

// Static variable initialization
datetime SystemMonitor::s_lastHeartbeat = 0;
datetime SystemMonitor::s_lastLog = 0;

//+------------------------------------------------------------------+
//| Main EA Class - Single Responsibility (Orchestration Only)     |
//+------------------------------------------------------------------+
class BreakoutEAController
{
private:
   DIContainer* m_container;
   bool m_isInitialized;
   
public:
   BreakoutEAController() : m_container(NULL), m_isInitialized(false) {}
   ~BreakoutEAController() { Cleanup(); }
   
   // SRP: Only orchestrates, doesn't do the work
   bool Initialize()
   {
      Print("🚀 BreakoutEAController: Starting initialization...");
      
      // Step 1: Validate parameters (delegated)
      if(!ParameterValidator::ValidateAll())
         return false;
      
      // Step 2: Validate environment (delegated)  
      if(!EnvironmentValidator::ValidateEnvironment())
         return false;
      
      // Step 3: Initialize container (delegated)
      m_container = new DIContainer();
      if(!SystemInitializer::Initialize(m_container))
         return false;
      
      m_isInitialized = true;
      SystemMonitor::UpdateHeartbeat();
      
      Print("✅ BreakoutEAController: Initialization successful");
      return true;
   }
   
   void ProcessTick()
   {
      if(!m_isInitialized) return;
      
      SystemMonitor::UpdateHeartbeat();
      
      // TODO: Delegate to appropriate managers
      // m_container.GetSessionManager().ProcessTick();
   }
   
   void ProcessTimer()
   {
      if(!m_isInitialized) return;
      
      // TODO: Delegate timer operations
      // m_container.GetSessionManager().ProcessTimer();
   }
   
   void Cleanup()
   {
      Print("🧹 BreakoutEAController: Cleaning up...");
      
      if(m_container != NULL)
      {
         m_container.CleanupServices();
         delete m_container;
         m_container = NULL;
      }
      
      m_isInitialized = false;
      Print("✅ BreakoutEAController: Cleanup completed");
   }
};

//+------------------------------------------------------------------+
//| Global Controller Instance                                       |
//+------------------------------------------------------------------+
BreakoutEAController* g_controller = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("🚀 BreakoutEA v1.0 - SOLID Architecture");
   Print("📊 Symbol: ", Symbol(), " | Timeframe: ", EnumToString(Period()));
   
   // Single Responsibility: Only create and initialize controller
   g_controller = new BreakoutEAController();
   
   if(!g_controller.Initialize())
   {
      Print("❌ Controller initialization failed");
      delete g_controller;
      g_controller = NULL;
      return(INIT_FAILED);
   }
   
   EventSetTimer(60);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("🛑 BreakoutEA - Shutting down...");
   Print("📝 Reason: ", GetDeinitReasonText(reason));
   
   EventKillTimer();
   
   // Single Responsibility: Only cleanup controller
   if(g_controller != NULL)
   {
      delete g_controller;
      g_controller = NULL;
   }
   
   Print("✅ BreakoutEA shutdown completed");
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   // Single Responsibility: Only delegate to controller
   if(g_controller != NULL)
      g_controller.ProcessTick();
}

//+------------------------------------------------------------------+
//| Timer function                                                  |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Single Responsibility: Only delegate to controller
   if(g_controller != NULL)
      g_controller.ProcessTimer();
}

//+------------------------------------------------------------------+
//| Utility function                                               |
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