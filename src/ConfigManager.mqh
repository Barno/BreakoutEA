//+------------------------------------------------------------------+
//|                                               ConfigManager.mqh |
//|                                    Gestione Configurazione EA   |
//|                                              Single Responsibility |
//+------------------------------------------------------------------+

#ifndef CONFIG_MANAGER_MQH
#define CONFIG_MANAGER_MQH

#include "Enums.mqh"

//+------------------------------------------------------------------+
//| Strutture Configurazione                                        |
//+------------------------------------------------------------------+

struct RiskConfig
{
    double riskPercentage;      // % capitale da rischiare
    int    leverage;            // Leva broker
    double spreadBuffer;        // Buffer spread (pips)
    double maxSpread;           // Spread massimo accettabile
    
    RiskConfig() : riskPercentage(0.5), leverage(100), spreadBuffer(2.0), maxSpread(10.0) {}
};

struct SessionConfig
{
    int referenceHour1;         // Ora sessione 1
    int referenceMinute1;       // Minuto sessione 1
    int referenceHour2;         // Ora sessione 2
    int referenceMinute2;       // Minuto sessione 2
    ENUM_TIMEFRAMES timeframe;  // Timeframe riferimento
    
    SessionConfig() : referenceHour1(8), referenceMinute1(45), 
                     referenceHour2(14), referenceMinute2(45), 
                     timeframe(PERIOD_M15) {}
};

struct TPConfig
{
    int    numberOfTP;          // Numero take profit
    double tp1RiskReward;       // TP1 R:R
    double tp1Percentage;       // TP1 % volume
    double tp2RiskReward;       // TP2 R:R  
    double tp2Percentage;       // TP2 % volume
    bool   breakEvenAfterTP;    // Breakeven dopo primo TP
    
    TPConfig() : numberOfTP(2), tp1RiskReward(2.0), tp1Percentage(50.0),
                tp2RiskReward(3.0), tp2Percentage(50.0), breakEvenAfterTP(true) {}
};

struct TradingCalendar
{
    bool monday;
    bool tuesday; 
    bool wednesday;
    bool thursday;
    bool friday;
    bool saturday;
    bool sunday;
    
    TradingCalendar() : monday(true), tuesday(true), wednesday(true), 
                       thursday(true), friday(true), saturday(false), sunday(false) {}
};


input int OffsetBroker_Ore = 0; // Fallback manuale classe TimeManager

//+------------------------------------------------------------------+
//| ConfigManager Class                                             |
//+------------------------------------------------------------------+
class ConfigManager
{
private:
    RiskConfig       m_riskConfig; //variabile membro
    SessionConfig    m_sessionConfig;
    TPConfig         m_tpConfig;
    TradingCalendar  m_calendar;
    bool             m_isValid;
    string           m_lastError;

public:
    ConfigManager();
    ~ConfigManager();
    
    // Main interface
    bool LoadParameters(double riskPercentage, int leverage, double spreadBuffer, double maxSpread,
                       int refHour1, int refMinute1, int refHour2, int refMinute2, ENUM_TIMEFRAMES timeframe,
                       int numberOfTP, double tp1RR, double tp1Pct, double tp2RR, double tp2Pct, bool breakEven,
                       bool mon, bool tue, bool wed, bool thu, bool fri, bool sat, bool sun);
    bool ValidateParameters();
    bool IsValid() const { return m_isValid; }
    string GetLastError() const { return m_lastError; }
    
    // Getters
    RiskConfig GetRiskConfig() const { return m_riskConfig; }
    SessionConfig GetSessionConfig() const { return m_sessionConfig; }
    TPConfig GetTPConfig() const { return m_tpConfig; }
    TradingCalendar GetTradingCalendar() const { return m_calendar; }

private:
    bool ValidateRiskConfig();
    bool ValidateSessionConfig();
    bool ValidateTPConfig();
    void SetError(const string error);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
ConfigManager::ConfigManager() : m_isValid(false), m_lastError("")
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
ConfigManager::~ConfigManager()
{
}

//+------------------------------------------------------------------+
//| Carica parametri passati dall'EA                               |
//+------------------------------------------------------------------+
bool ConfigManager::LoadParameters(double riskPercentage, int leverage, double spreadBuffer, double maxSpread,
                                  int refHour1, int refMinute1, int refHour2, int refMinute2, ENUM_TIMEFRAMES timeframe,
                                  int numberOfTP, double tp1RR, double tp1Pct, double tp2RR, double tp2Pct, bool breakEven,
                                  bool mon, bool tue, bool wed, bool thu, bool fri, bool sat, bool sun)
{
    Print("ConfigManager: Loading parameters...");
    
    // Risk Config
    m_riskConfig.riskPercentage = riskPercentage;
    m_riskConfig.leverage = leverage;
    m_riskConfig.spreadBuffer = spreadBuffer;
    m_riskConfig.maxSpread = maxSpread;
    
    // Session Config
    m_sessionConfig.referenceHour1 = refHour1;
    m_sessionConfig.referenceMinute1 = refMinute1;
    m_sessionConfig.referenceHour2 = refHour2;
    m_sessionConfig.referenceMinute2 = refMinute2;
    m_sessionConfig.timeframe = timeframe;
    
    // TP Config
    m_tpConfig.numberOfTP = numberOfTP;
    m_tpConfig.tp1RiskReward = tp1RR;
    m_tpConfig.tp1Percentage = tp1Pct;
    m_tpConfig.tp2RiskReward = tp2RR;
    m_tpConfig.tp2Percentage = tp2Pct;
    m_tpConfig.breakEvenAfterTP = breakEven;
    
    // Trading Calendar
    m_calendar.monday = mon;
    m_calendar.tuesday = tue;
    m_calendar.wednesday = wed;
    m_calendar.thursday = thu;
    m_calendar.friday = fri;
    m_calendar.saturday = sat;
    m_calendar.sunday = sun;
    
    Print("ConfigManager: Parameters loaded successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Valida tutti i parametri                                        |
//+------------------------------------------------------------------+
bool ConfigManager::ValidateParameters()
{
    Print("ConfigManager: Validating parameters...");
    
    m_isValid = false;
    m_lastError = "";
    
    if(!ValidateRiskConfig()) return false;
    if(!ValidateSessionConfig()) return false;
    if(!ValidateTPConfig()) return false;
    
    m_isValid = true;
    Print("ConfigManager: All parameters valid");
    return true;
}

//+------------------------------------------------------------------+
//| Valida configurazione rischio                                   |
//+------------------------------------------------------------------+
bool ConfigManager::ValidateRiskConfig()
{
    // Validazione risk percentage
    if(m_riskConfig.riskPercentage <= 0 || m_riskConfig.riskPercentage > 10)
    {
        SetError("Risk percentage must be between 0.1 and 10.0");
        return false;
    }
    
    // Validazione leverage
    if(m_riskConfig.leverage <= 0 || m_riskConfig.leverage > 1000)
    {
        SetError("Leverage must be between 1 and 1000");
        return false;
    }
    
    // Validazione spread buffer
    if(m_riskConfig.spreadBuffer < 0)
    {
        SetError("Spread buffer cannot be negative");
        return false;
    }
    
    // Validazione max spread
    if(m_riskConfig.maxSpread <= 0)
    {
        SetError("Max spread must be positive");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Valida configurazione sessioni                                  |
//+------------------------------------------------------------------+
bool ConfigManager::ValidateSessionConfig()
{
    // Validazione ore
    if(m_sessionConfig.referenceHour1 < 0 || m_sessionConfig.referenceHour1 > 23)
    {
        SetError("Session 1 hour must be between 0 and 23");
        return false;
    }
    
    if(m_sessionConfig.referenceHour2 < 0 || m_sessionConfig.referenceHour2 > 23)
    {
        SetError("Session 2 hour must be between 0 and 23");
        return false;
    }
    
    // Validazione minuti
    if(m_sessionConfig.referenceMinute1 < 0 || m_sessionConfig.referenceMinute1 > 59)
    {
        SetError("Session 1 minute must be between 0 and 59");
        return false;
    }
    
    if(m_sessionConfig.referenceMinute2 < 0 || m_sessionConfig.referenceMinute2 > 59)
    {
        SetError("Session 2 minute must be between 0 and 59");
        return false;
    }
    
    // Validazione timeframe
    if(m_sessionConfig.timeframe <= 0)
    {
        SetError("Invalid timeframe");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Valida configurazione take profit                               |
//+------------------------------------------------------------------+
bool ConfigManager::ValidateTPConfig()
{
    // Validazione numero TP
    if(m_tpConfig.numberOfTP < 1 || m_tpConfig.numberOfTP > MAX_TAKEPROFIT)
    {
        SetError("Number of TP must be between 1 and " + IntegerToString(MAX_TAKEPROFIT));
        return false;
    }
    
    // Validazione risk/reward ratios
    if(m_tpConfig.tp1RiskReward <= 0)
    {
        SetError("TP1 Risk/Reward must be positive");
        return false;
    }
    
    if(m_tpConfig.tp2RiskReward <= 0)
    {
        SetError("TP2 Risk/Reward must be positive");
        return false;
    }
    
    // Validazione percentuali
    if(m_tpConfig.tp1Percentage < 0 || m_tpConfig.tp1Percentage > 100)
    {
        SetError("TP1 percentage must be between 0 and 100");
        return false;
    }
    
    if(m_tpConfig.tp2Percentage < 0 || m_tpConfig.tp2Percentage > 100)
    {
        SetError("TP2 percentage must be between 0 and 100");
        return false;
    }
    
    // Validazione somma percentuali
    if(m_tpConfig.tp1Percentage + m_tpConfig.tp2Percentage > 100)
    {
        SetError("Sum of TP percentages cannot exceed 100");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Imposta errore di validazione                                   |
//+------------------------------------------------------------------+
void ConfigManager::SetError(const string error)
{
    m_lastError = error;
    Print("ConfigManager ERROR: ", error);
}

#endif // CONFIG_MANAGER_MQH