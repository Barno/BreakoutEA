//+------------------------------------------------------------------+
//|                                                 RiskManager.mqh |
//|                                     Position Sizing & Risk Control |
//|                                              SOLID Architecture  |
//+------------------------------------------------------------------+

#ifndef RISK_MANAGER_MQH
#define RISK_MANAGER_MQH

#include "Enums.mqh"
#include "MarginCalculator.mqh"

//+------------------------------------------------------------------+
//| Strutture per Risk Management                                   |
//+------------------------------------------------------------------+
struct PositionSizeInfo
{
    double totalLots;           // Lotti totali da aprire
    double riskAmount;          // USD di rischio
    double stopLossPoints;      // Punti di Stop Loss
    double pointValue;          // Valore monetario per punto
    bool isValid;               // Se il calcolo è valido
    string errorReason;         // Motivo errore se any
    
    PositionSizeInfo() : totalLots(0), riskAmount(0), stopLossPoints(0), 
                        pointValue(0), isValid(false), errorReason("") {}
};

struct MultiTargetInfo
{
    double tp1Lots;             // Lotti per TP1
    double tp2Lots;             // Lotti per TP2
    double tp3Lots;             // Lotti per TP3 (opzionale)
    double tp1Price;            // Prezzo TP1
    double tp2Price;            // Prezzo TP2  
    double tp3Price;            // Prezzo TP3 (opzionale)
    double remainingLots;       // Lotti rimanenti dopo TP
    
    MultiTargetInfo() : tp1Lots(0), tp2Lots(0), tp3Lots(0),
                       tp1Price(0), tp2Price(0), tp3Price(0), remainingLots(0) {}
};

struct RiskParameters
{
    double riskPercentage;      // % capitale da rischiare
    double tp1RiskReward;       // TP1 Risk/Reward ratio
    double tp2RiskReward;       // TP2 Risk/Reward ratio
    double tp1VolumePercent;    // % volume da chiudere al TP1
    double tp2VolumePercent;    // % volume da chiudere al TP2
    bool breakEvenAfterTP1;     // Breakeven dopo TP1
    
    RiskParameters() : riskPercentage(0.5), tp1RiskReward(1.8), tp2RiskReward(3.0),
                      tp1VolumePercent(50.0), tp2VolumePercent(50.0), breakEvenAfterTP1(true) {}
};

//+------------------------------------------------------------------+
//| Interface per Risk Manager (SOLID - Dependency Inversion)      |
//+------------------------------------------------------------------+
class IRiskManager
{
public:
    virtual double CalculateLotsForRisk(const string symbol, double riskPercent, double stopLossPoints) = 0;
    virtual PositionSizeInfo CalculatePositionSize(const string symbol, double entryPrice, double stopLoss, double riskPercent) = 0;
    virtual MultiTargetInfo CalculateMultiTargets(const string symbol, double entryPrice, double stopLoss, const RiskParameters& params) = 0;
    virtual bool ValidatePositionRisk(const string symbol, double lots, double stopLossPoints) = 0;
};

//+------------------------------------------------------------------+
//| RiskManager Class - Main Implementation                        |
//+------------------------------------------------------------------+
class RiskManager : public IRiskManager
{
private:
    string m_lastError;                    // Ultimo errore
    MarginCalculator* m_marginCalc;        // Riferimento a MarginCalculator
    double m_accountBalance;               // Balance account
    string m_accountCurrency;              // Valuta account
    
    // Configuration
    double m_maxRiskPerTrade;              // Max rischio per trade %
    double m_maxMarginUtilization;         // Max utilizzo margine %
    bool m_useEquityForRisk;               // Usa equity invece di balance
    
public:
    RiskManager();
    ~RiskManager();
    
    // Initialization
    bool Initialize(MarginCalculator* marginCalculator);
    
    // Main Interface Implementation (IRiskManager)
    virtual double CalculateLotsForRisk(const string symbol, double riskPercent, double stopLossPoints) override;
    virtual PositionSizeInfo CalculatePositionSize(const string symbol, double entryPrice, double stopLoss, double riskPercent) override;
    virtual MultiTargetInfo CalculateMultiTargets(const string symbol, double entryPrice, double stopLoss, const RiskParameters& params) override;
    virtual bool ValidatePositionRisk(const string symbol, double lots, double stopLossPoints) override;
    
    // Enhanced Features
    double CalculateRiskAmount(double riskPercent);
    double GetPointValue(const string symbol);
    double GetMinLotSize(const string symbol);
    double GetMaxLotSize(const string symbol);
    double GetLotStep(const string symbol);
    double NormalizeLots(const string symbol, double lots);
    
    // Multi-Asset Point Value Calculation
    double CalculateForexPointValue(const string symbol);
    double CalculateIndexPointValue(const string symbol);
    double CalculateCryptoPointValue(const string symbol);
    double CalculateCommodityPointValue(const string symbol);
    
    // Risk Validation
    bool IsWithinRiskLimits(double riskPercent);
    bool HasSufficientMargin(const string symbol, double lots);
    bool IsLotSizeValid(const string symbol, double lots);
    
    // Configuration
    void SetMaxRiskPerTrade(double percent) { m_maxRiskPerTrade = percent; }
    void SetMaxMarginUtilization(double percent) { m_maxMarginUtilization = percent; }
    void SetUseEquityForRisk(bool useEquity) { m_useEquityForRisk = useEquity; }
    
    // Getters
    double GetMaxRiskPerTrade() const { return m_maxRiskPerTrade; }
    double GetAccountBalance() const { return m_accountBalance; }
    string GetAccountCurrency() const { return m_accountCurrency; }
    string GetLastError() const { return m_lastError; }

private:
    // Core Calculation Methods
    double CalculateStopLossPoints(double entryPrice, double stopLoss, const string symbol);
    AssetType GetAssetType(const string symbol);
    
    // Validation & Error Handling
    bool ValidateInputs(const string symbol, double riskPercent, double stopLossPoints);
    bool ValidatePrices(double entryPrice, double stopLoss);
    void SetError(const string error);
    void UpdateAccountInfo();
    
    // Utility Methods
    double RoundToLotStep(const string symbol, double lots);
    double ApplySafetyMargin(double calculatedLots, const string symbol);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
RiskManager::RiskManager() : m_lastError(""),
                            m_marginCalc(NULL),
                            m_accountBalance(0),
                            m_accountCurrency(""),
                            m_maxRiskPerTrade(2.0),
                            m_maxMarginUtilization(80.0),
                            m_useEquityForRisk(false)
{
    Print("RiskManager: Initializing...");
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
RiskManager::~RiskManager()
{
    // Non eliminiamo m_marginCalc perché non è di nostra proprietà
    m_marginCalc = NULL;
}

//+------------------------------------------------------------------+
//| Inizializza RiskManager                                         |
//+------------------------------------------------------------------+
bool RiskManager::Initialize(MarginCalculator* marginCalculator)
{
    Print("RiskManager: Initializing with MarginCalculator...");
    
    if(marginCalculator == NULL)
    {
        SetError("MarginCalculator reference is NULL");
        return false;
    }
    
    m_marginCalc = marginCalculator;
    
    // Aggiorna info account
    UpdateAccountInfo();
    
    if(m_accountBalance <= 0)
    {
        SetError("Invalid account balance");
        return false;
    }
    
    Print("RiskManager: Initialized successfully");
    Print("Account Balance: ", DoubleToString(m_accountBalance, 2), " ", m_accountCurrency);
    Print("Max Risk Per Trade: ", m_maxRiskPerTrade, "%");
    Print("Max Margin Utilization: ", m_maxMarginUtilization, "%");
    
    return true;
}

//+------------------------------------------------------------------+
//| Calcola lotti per percentuale rischio (FUNZIONE PRINCIPALE)    |
//+------------------------------------------------------------------+
double RiskManager::CalculateLotsForRisk(const string symbol, double riskPercent, double stopLossPoints)
{
    // Validazione input
    if(!ValidateInputs(symbol, riskPercent, stopLossPoints))
    {
        return 0;
    }
    
    // Calcola importo rischio in USD
    double riskAmount = CalculateRiskAmount(riskPercent);
    if(riskAmount <= 0)
    {
        SetError("Invalid risk amount calculated");
        return 0;
    }
    
    // Ottieni point value per il simbolo
    double pointValue = GetPointValue(symbol);
    if(pointValue <= 0)
    {
        SetError("Cannot determine point value for symbol: " + symbol);
        return 0;
    }
    
    // Formula principale: Lotti = Risk USD / (SL Points × Point Value)
    double calculatedLots = riskAmount / (stopLossPoints * pointValue);
    
    // Normalizza ai vincoli del broker
    double normalizedLots = NormalizeLots(symbol, calculatedLots);
    
    // Applica safety margin se necessario
    double finalLots = ApplySafetyMargin(normalizedLots, symbol);
    
    // Validazione finale
    if(!IsLotSizeValid(symbol, finalLots))
    {
        SetError("Final lot size validation failed");
        return 0;
    }
    
    // Verifica margine sufficiente
    if(!HasSufficientMargin(symbol, finalLots))
    {
        SetError("Insufficient margin for calculated position size");
        return 0;
    }
    
    Print("RiskManager: Calculated lots for ", symbol);
    Print("  Risk: ", DoubleToString(riskPercent, 2), "% (", DoubleToString(riskAmount, 2), " USD)");
    Print("  SL Points: ", DoubleToString(stopLossPoints, 1));
    Print("  Point Value: ", DoubleToString(pointValue, 4));
    Print("  Final Lots: ", DoubleToString(finalLots, 3));
    
    return finalLots;
}

//+------------------------------------------------------------------+
//| Calcola informazioni complete position size                    |
//+------------------------------------------------------------------+
PositionSizeInfo RiskManager::CalculatePositionSize(const string symbol, double entryPrice, double stopLoss, double riskPercent)
{
    PositionSizeInfo info;
    
    // Validazione prezzi
    if(!ValidatePrices(entryPrice, stopLoss))
    {
        info.errorReason = "Invalid entry or stop loss prices";
        return info;
    }
    
    // Calcola punti stop loss
    double stopLossPoints = CalculateStopLossPoints(entryPrice, stopLoss, symbol);
    if(stopLossPoints <= 0)
    {
        info.errorReason = "Invalid stop loss distance";
        return info;
    }
    
    // Calcola lotti
    double lots = CalculateLotsForRisk(symbol, riskPercent, stopLossPoints);
    if(lots <= 0)
    {
        info.errorReason = m_lastError;
        return info;
    }
    
    // Popola struttura
    info.totalLots = lots;
    info.riskAmount = CalculateRiskAmount(riskPercent);
    info.stopLossPoints = stopLossPoints;
    info.pointValue = GetPointValue(symbol);
    info.isValid = true;
    
    return info;
}

//+------------------------------------------------------------------+
//| Calcola target multipli per strategia                          |
//+------------------------------------------------------------------+
MultiTargetInfo RiskManager::CalculateMultiTargets(const string symbol, double entryPrice, double stopLoss, const RiskParameters& params)
{
    MultiTargetInfo info;
    
    // Calcola position size base
    PositionSizeInfo posInfo = CalculatePositionSize(symbol, entryPrice, stopLoss, params.riskPercentage);
    if(!posInfo.isValid)
    {
        Print("RiskManager: Failed to calculate base position size for multi-targets");
        return info;
    }
    
    double totalLots = posInfo.totalLots;
    double stopLossPoints = posInfo.stopLossPoints;
    
    // Calcola prezzi target
    bool isLong = (entryPrice > stopLoss);
    double targetDirection = isLong ? 1.0 : -1.0;
    
    info.tp1Price = entryPrice + (targetDirection * stopLossPoints * params.tp1RiskReward);
    info.tp2Price = entryPrice + (targetDirection * stopLossPoints * params.tp2RiskReward);
    
    // Calcola allocazione volume
    info.tp1Lots = totalLots * (params.tp1VolumePercent / 100.0);
    info.tp2Lots = totalLots * (params.tp2VolumePercent / 100.0);
    
    // Normalizza lotti ai vincoli broker
    info.tp1Lots = NormalizeLots(symbol, info.tp1Lots);
    info.tp2Lots = NormalizeLots(symbol, info.tp2Lots);
    
    // Calcola rimanente
    info.remainingLots = totalLots - info.tp1Lots - info.tp2Lots;
    info.remainingLots = NormalizeLots(symbol, info.remainingLots);
    
    Print("RiskManager: Multi-target calculation for ", symbol);
    Print("  Total Lots: ", DoubleToString(totalLots, 3));
    Print("  TP1 (", DoubleToString(params.tp1RiskReward, 1), "R): ", 
          DoubleToString(info.tp1Lots, 3), " lots @ ", DoubleToString(info.tp1Price, _Digits));
    Print("  TP2 (", DoubleToString(params.tp2RiskReward, 1), "R): ",
          DoubleToString(info.tp2Lots, 3), " lots @ ", DoubleToString(info.tp2Price, _Digits));
    Print("  Remaining: ", DoubleToString(info.remainingLots, 3), " lots");
    
    return info;
}

//+------------------------------------------------------------------+
//| Valida rischio posizione                                       |
//+------------------------------------------------------------------+
bool RiskManager::ValidatePositionRisk(const string symbol, double lots, double stopLossPoints)
{
    if(lots <= 0 || stopLossPoints <= 0) return false;
    
    // Calcola rischio effettivo
    double pointValue = GetPointValue(symbol);
    double riskAmount = lots * stopLossPoints * pointValue;
    double riskPercent = (riskAmount / m_accountBalance) * 100.0;
    
    // Verifica limiti
    if(!IsWithinRiskLimits(riskPercent))
    {
        SetError("Position risk exceeds maximum allowed");
        return false;
    }
    
    if(!HasSufficientMargin(symbol, lots))
    {
        SetError("Insufficient margin for position");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Calcola importo rischio in USD                                 |
//+------------------------------------------------------------------+
double RiskManager::CalculateRiskAmount(double riskPercent)
{
    double baseAmount = m_useEquityForRisk ? AccountInfoDouble(ACCOUNT_EQUITY) : m_accountBalance;
    return baseAmount * (riskPercent / 100.0);
}

//+------------------------------------------------------------------+
//| Ottiene point value per simbolo (MULTI-ASSET)                  |
//+------------------------------------------------------------------+
double RiskManager::GetPointValue(const string symbol)
{
    AssetType assetType = GetAssetType(symbol);
    
    switch(assetType)
    {
        case ASSET_FOREX:
            return CalculateForexPointValue(symbol);
        case ASSET_INDICES:
            return CalculateIndexPointValue(symbol);
        case ASSET_CRYPTO:
            return CalculateCryptoPointValue(symbol);
        case ASSET_COMMODITY:
            return CalculateCommodityPointValue(symbol);
        default:
            // Fallback: usa tick value di MT5
            return SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    }
}

//+------------------------------------------------------------------+
//| Calcola point value Forex                                      |
//+------------------------------------------------------------------+
double RiskManager::CalculateForexPointValue(const string symbol)
{
    // Per Forex: point value dipende da valuta account e cross rate
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tickSize > 0)
    {
        // Point value = Tick Value / Tick Size (per normalizzare al punto)
        return tickValue / tickSize;
    }
    
    return tickValue; // Fallback
}

//+------------------------------------------------------------------+
//| Calcola point value Indici                                     |
//+------------------------------------------------------------------+
double RiskManager::CalculateIndexPointValue(const string symbol)
{
    // Per Indici: di solito 1 punto = tick value
    return SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
}

//+------------------------------------------------------------------+
//| Calcola point value Crypto                                     |
//+------------------------------------------------------------------+
double RiskManager::CalculateCryptoPointValue(const string symbol)
{
    // Per Crypto: simile a Forex ma può avere scaling diverso
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tickSize > 0)
    {
        return tickValue / tickSize;
    }
    
    return tickValue;
}

//+------------------------------------------------------------------+
//| Calcola point value Commodity                                  |
//+------------------------------------------------------------------+
double RiskManager::CalculateCommodityPointValue(const string symbol)
{
    // Per Commodity: di solito tick value è già corretto
    return SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
}

//+------------------------------------------------------------------+
//| Normalizza lotti ai vincoli broker                             |
//+------------------------------------------------------------------+
double RiskManager::NormalizeLots(const string symbol, double lots)
{
    double minLot = GetMinLotSize(symbol);
    double maxLot = GetMaxLotSize(symbol);
    double stepLot = GetLotStep(symbol);
    
    // Arrotonda al step più vicino
    lots = RoundToLotStep(symbol, lots);
    
    // Applica limiti
    lots = MathMax(lots, minLot);
    lots = MathMin(lots, maxLot);
    
    return lots;
}

//+------------------------------------------------------------------+
//| Implementazione metodi di supporto                             |
//+------------------------------------------------------------------+

double RiskManager::GetMinLotSize(const string symbol)
{
    return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
}

double RiskManager::GetMaxLotSize(const string symbol)
{
    return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
}

double RiskManager::GetLotStep(const string symbol)
{
    return SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
}

double RiskManager::RoundToLotStep(const string symbol, double lots)
{
    double stepLot = GetLotStep(symbol);
    if(stepLot > 0)
    {
        return MathRound(lots / stepLot) * stepLot;
    }
    return lots;
}

double RiskManager::CalculateStopLossPoints(double entryPrice, double stopLoss, const string symbol)
{
    return MathAbs(entryPrice - stopLoss) / SymbolInfoDouble(symbol, SYMBOL_POINT);
}

AssetType RiskManager::GetAssetType(const string symbol)
{
    // Usa MarginCalculator per rilevare tipo asset
    if(m_marginCalc != NULL)
    {
        AssetInfo info = m_marginCalc.GetAssetInfo(symbol);
        return info.type;
    }
    
    return ASSET_UNKNOWN;
}

bool RiskManager::ValidateInputs(const string symbol, double riskPercent, double stopLossPoints)
{
    if(symbol == "")
    {
        SetError("Empty symbol");
        return false;
    }
    
    if(!IsWithinRiskLimits(riskPercent))
    {
        SetError("Risk percentage exceeds maximum allowed");
        return false;
    }
    
    if(stopLossPoints <= 0)
    {
        SetError("Stop loss points must be positive");
        return false;
    }
    
    return true;
}

bool RiskManager::ValidatePrices(double entryPrice, double stopLoss)
{
    return (entryPrice > 0 && stopLoss > 0 && entryPrice != stopLoss);
}

bool RiskManager::IsWithinRiskLimits(double riskPercent)
{
    return (riskPercent > 0 && riskPercent <= m_maxRiskPerTrade);
}

bool RiskManager::HasSufficientMargin(const string symbol, double lots)
{
    if(m_marginCalc == NULL) return true; // Non possiamo verificare
    
    return m_marginCalc.CanOpenPosition(symbol, lots, ORDER_TYPE_BUY);
}

bool RiskManager::IsLotSizeValid(const string symbol, double lots)
{
    double minLot = GetMinLotSize(symbol);
    double maxLot = GetMaxLotSize(symbol);
    
    return (lots >= minLot && lots <= maxLot);
}

double RiskManager::ApplySafetyMargin(double calculatedLots, const string symbol)
{
    // Per ora, nessun safety margin aggiuntivo
    // Potrebbe essere implementato in futuro
    return calculatedLots;
}

void RiskManager::UpdateAccountInfo()
{
    m_accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    m_accountCurrency = AccountInfoString(ACCOUNT_CURRENCY);
}

void RiskManager::SetError(const string error)
{
    m_lastError = error;
    Print("RiskManager ERROR: ", error);
}

#endif // RISK_MANAGER_MQH