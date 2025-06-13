//+------------------------------------------------------------------+
//|                                         MarginCalculator.mqh    |
//|                              Enhanced Position Sizing Engine     |
//|                              Based on EarnForex Position Sizer   |
//|                              HYBRID APPROACH - Risk Management   |
//+------------------------------------------------------------------+

#ifndef MARGIN_CALCULATOR_MQH
#define MARGIN_CALCULATOR_MQH

#include "Enums.mqh"

//+------------------------------------------------------------------+
//| ✅ RIMOSSE STRUCT DUPLICATE (ora in Enums.mqh)                 |
//+------------------------------------------------------------------+
// MarginInfo, PositionSizeInfo ora in Enums.mqh

//+------------------------------------------------------------------+
//| Enhanced MarginCalculator Class                                 |
//+------------------------------------------------------------------+
class MarginCalculator
{
private:
    string m_lastError;          // Ultimo errore
    double m_lastCalculation;    // Ultimo calcolo position size
    datetime m_lastUpdateTime;   // Ultimo aggiornamento
    
    // Cache per performance
    double m_cachedTickValue;
    double m_cachedTickSize;
    string m_cachedSymbol;
    datetime m_cacheTime;
    
    // ✅ AGGIUNTO: Safety settings
    double m_safetyMarginPercent;
    double m_maxMarginUtilization;

public:
    MarginCalculator();
    ~MarginCalculator();
    
    // === MAIN POSITION SIZING (EarnForex Style) ===
    double CalculatePositionSize(const string symbol, double riskPercent, double slPips, double accountSize = 0);
    double CalculatePositionSizeMoney(const string symbol, double riskMoney, double slPips);
    PositionSizeInfo GetPositionSizeInfo(const string symbol, double riskPercent, double slPips, double accountSize = 0);
    
    // === MARGIN ANALYSIS ===
    MarginInfo GetMarginAnalysis(const string symbol, double lots, ENUM_ORDER_TYPE orderType);
    double GetRequiredMargin(const string symbol, double lots, ENUM_ORDER_TYPE orderType);
    double GetAvailableMargin();
    bool CanOpenPosition(const string symbol, double lots, ENUM_ORDER_TYPE orderType);
    double CalculateMaxLotsForMargin(const string symbol, ENUM_ORDER_TYPE orderType, double marginPercent = 80.0);
    
    // === SYMBOL ANALYSIS ===
    double GetTickValue(const string symbol);
    double GetTickSize(const string symbol);
    double GetPipValue(const string symbol, double lots = 1.0);
    AssetType DetectAssetType(const string symbol);
    
    // === VALIDATION & UTILITIES ===
    double NormalizeVolume(const string symbol, double volume);
    bool ValidatePositionSize(const string symbol, double lots);
    double ConvertSLPipsToPoints(const string symbol, double slPips);
    
    // ✅ AGGIUNTO: Safety Configuration
    void SetSafetyMarginPercent(double percent) { m_safetyMarginPercent = percent; }
    void SetMaxMarginUtilization(double percent) { m_maxMarginUtilization = percent; }
    double GetSafetyMarginPercent() const { return m_safetyMarginPercent; }
    double GetMaxMarginUtilization() const { return m_maxMarginUtilization; }
    
    // === INFO ===
    string GetLastError() const { return m_lastError; }
    double GetLastCalculation() const { return m_lastCalculation; }
    datetime GetLastUpdateTime() const { return m_lastUpdateTime; }

private:
    // === CORE CALCULATIONS (EarnForex Formula) ===
    double CalculateRiskAndPositionSize(const string symbol, double riskMoney, double slDistance);
    bool UpdateSymbolCache(const string symbol);
    void SetError(const string error);
    double GetAccountSize();
    bool IsValidSymbol(const string symbol);
    double CalculateSlDistanceInPoints(const string symbol, double slPips);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
MarginCalculator::MarginCalculator() : m_lastError(""),
                                      m_lastCalculation(0),
                                      m_lastUpdateTime(0),
                                      m_cachedTickValue(0),
                                      m_cachedTickSize(0),
                                      m_cachedSymbol(""),
                                      m_cacheTime(0),
                                      m_safetyMarginPercent(20.0),
                                      m_maxMarginUtilization(80.0)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
MarginCalculator::~MarginCalculator()
{
}

//+------------------------------------------------------------------+
//| MAIN: Calcola position size basato su risk % (EarnForex Style) |
//+------------------------------------------------------------------+
double MarginCalculator::CalculatePositionSize(const string symbol, double riskPercent, double slPips, double accountSize = 0)
{
    if(accountSize == 0) accountSize = GetAccountSize();
    if(accountSize <= 0)
    {
        SetError("Invalid account size");
        return 0;
    }
    
    // Calcola importo rischio in denaro
    double riskMoney = accountSize * riskPercent / 100.0;
    
    return CalculatePositionSizeMoney(symbol, riskMoney, slPips);
}

//+------------------------------------------------------------------+
//| MAIN: Calcola position size basato su importo fisso           |
//+------------------------------------------------------------------+
double MarginCalculator::CalculatePositionSizeMoney(const string symbol, double riskMoney, double slPips)
{
    if(riskMoney <= 0)
    {
        SetError("Risk money must be positive");
        return 0;
    }
    
    if(slPips <= 0)
    {
        SetError("Stop loss pips must be positive");
        return 0;
    }
    
    // Converti SL da pips a points
    double slDistance = CalculateSlDistanceInPoints(symbol, slPips);
    if(slDistance <= 0)
    {
        SetError("Invalid SL distance calculation");
        return 0;
    }
    
    // Usa formula EarnForex
    double positionSize = CalculateRiskAndPositionSize(symbol, riskMoney, slDistance);
    
    if(positionSize > 0)
    {
        // Normalizza volume secondo vincoli del simbolo
        positionSize = NormalizeVolume(symbol, positionSize);
        m_lastCalculation = positionSize;
        m_lastUpdateTime = TimeCurrent();
    }
    
    return positionSize;
}

//+------------------------------------------------------------------+
//| Ottiene informazioni complete position sizing                  |
//+------------------------------------------------------------------+
PositionSizeInfo MarginCalculator::GetPositionSizeInfo(const string symbol, double riskPercent, double slPips, double accountSize = 0)
{
    PositionSizeInfo info;
    
    if(accountSize == 0) accountSize = GetAccountSize();
    info.riskAmount = accountSize * riskPercent / 100.0;
    info.stopLossPoints = CalculateSlDistanceInPoints(symbol, slPips);
    info.tickValue = GetTickValue(symbol);
    info.tickSize = GetTickSize(symbol);
    
    info.totalLots = CalculatePositionSize(symbol, riskPercent, slPips, accountSize);
    
    if(info.totalLots > 0)
    {
        info.isValid = true;
        info.SyncFields(); // ✅ Sync compatibility fields
    }
    else
    {
        info.errorReason = m_lastError;
        info.SyncFields(); // ✅ Sync compatibility fields
    }
    
    return info;
}

//+------------------------------------------------------------------+
//| CORE: Formula EarnForex Position Sizer                         |
//+------------------------------------------------------------------+
double MarginCalculator::CalculateRiskAndPositionSize(const string symbol, double riskMoney, double slDistance)
{
    if(!UpdateSymbolCache(symbol)) return 0;
    
    double tickValue = m_cachedTickValue;
    double tickSize = m_cachedTickSize;
    
    if(tickValue <= 0 || tickSize <= 0)
    {
        SetError("Invalid tick value or tick size for symbol: " + symbol);
        return 0;
    }
    
    // FORMULA EARNFOREX:
    // PositionSize = RiskMoney / (StopLoss * UnitCost / TickSize)
    double positionSize = riskMoney / (slDistance * tickValue / tickSize);
    
    if(positionSize < 0 || !MathIsValidNumber(positionSize))
    {
        SetError("Invalid position size calculation result");
        return 0;
    }
    
    return positionSize;
}

//+------------------------------------------------------------------+
//| Analisi margine completa                                       |
//+------------------------------------------------------------------+
MarginInfo MarginCalculator::GetMarginAnalysis(const string symbol, double lots, ENUM_ORDER_TYPE orderType)
{
    MarginInfo info;
    
    info.requiredMargin = GetRequiredMargin(symbol, lots, orderType);
    info.availableMargin = GetAvailableMargin();
    
    double currentUsedMargin = AccountInfoDouble(ACCOUNT_MARGIN);
    info.futureUsedMargin = currentUsedMargin + info.requiredMargin;
    
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    if(equity > 0)
    {
        info.marginUtilization = (info.futureUsedMargin / equity) * 100.0;
    }
    
    info.canOpenPosition = CanOpenPosition(symbol, lots, orderType);
    
    if(!info.canOpenPosition)
    {
        info.lastError = m_lastError;
    }
    
    return info;
}

//+------------------------------------------------------------------+
//| Calcola margine richiesto per posizione                       |
//+------------------------------------------------------------------+
double MarginCalculator::GetRequiredMargin(const string symbol, double lots, ENUM_ORDER_TYPE orderType)
{
    if(!IsValidSymbol(symbol))
    {
        SetError("Invalid symbol: " + symbol);
        return 0;
    }
    
    if(lots <= 0)
    {
        SetError("Lots must be positive");
        return 0;
    }
    
    // Usa OrderCalcMargin per calcolo preciso
    double margin = 0;
    double price = (orderType == ORDER_TYPE_BUY) ? 
                   SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                   SymbolInfoDouble(symbol, SYMBOL_BID);
    
    if(price <= 0)
    {
        SetError("Invalid price for symbol: " + symbol);
        return 0;
    }
    
    if(!OrderCalcMargin(orderType, symbol, lots, price, margin))
    {
        SetError("OrderCalcMargin failed for " + symbol + " error: " + IntegerToString(GetLastError()));
        return 0;
    }
    
    return margin;
}

//+------------------------------------------------------------------+
//| Ottiene margine disponibile                                    |
//+------------------------------------------------------------------+
double MarginCalculator::GetAvailableMargin()
{
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double usedMargin = AccountInfoDouble(ACCOUNT_MARGIN);
    
    return MathMax(0, equity - usedMargin);
}

//+------------------------------------------------------------------+
//| Verifica se posizione può essere aperta                       |
//+------------------------------------------------------------------+
bool MarginCalculator::CanOpenPosition(const string symbol, double lots, ENUM_ORDER_TYPE orderType)
{
    double requiredMargin = GetRequiredMargin(symbol, lots, orderType);
    if(requiredMargin <= 0) return false;
    
    double availableMargin = GetAvailableMargin();
    
    // Safety margin: usa solo % configurabile del margine disponibile
    bool canOpen = (requiredMargin <= availableMargin * (100.0 - m_safetyMarginPercent) / 100.0);
    
    if(!canOpen)
    {
        SetError(StringFormat("Insufficient margin. Required: %.2f, Available: %.2f (Safety: %.1f%%)", 
                              requiredMargin, availableMargin, m_safetyMarginPercent));
    }
    
    return canOpen;
}

//+------------------------------------------------------------------+
//| Calcola massimi lotti per percentuale margine                 |
//+------------------------------------------------------------------+
double MarginCalculator::CalculateMaxLotsForMargin(const string symbol, ENUM_ORDER_TYPE orderType, double marginPercent = 80.0)
{
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double maxMargin = equity * marginPercent / 100.0;
    
    // Prova con 1 lotto per ottenere margine base
    double marginPerLot = GetRequiredMargin(symbol, 1.0, orderType);
    if(marginPerLot <= 0) return 0;
    
    double maxLots = maxMargin / marginPerLot;
    
    return NormalizeVolume(symbol, maxLots);
}

//+------------------------------------------------------------------+
//| Ottiene tick value con cache                                  |
//+------------------------------------------------------------------+
double MarginCalculator::GetTickValue(const string symbol)
{
    if(!UpdateSymbolCache(symbol)) return 0;
    return m_cachedTickValue;
}

//+------------------------------------------------------------------+
//| Ottiene tick size con cache                                   |
//+------------------------------------------------------------------+
double MarginCalculator::GetTickSize(const string symbol)
{
    if(!UpdateSymbolCache(symbol)) return 0;
    return m_cachedTickSize;
}

//+------------------------------------------------------------------+
//| Calcola pip value per lots                                    |
//+------------------------------------------------------------------+
double MarginCalculator::GetPipValue(const string symbol, double lots = 1.0)
{
    double tickValue = GetTickValue(symbol);
    double tickSize = GetTickSize(symbol);
    
    if(tickValue <= 0 || tickSize <= 0) return 0;
    
    // Per Forex: 1 pip = 10 ticks (per simboli 5-digit)
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double pipMultiplier = (digits == 5 || digits == 3) ? 10.0 : 1.0;
    
    return (tickValue / tickSize) * pipMultiplier * lots;
}

//+------------------------------------------------------------------+
//| Rileva tipo asset automaticamente                             |
//+------------------------------------------------------------------+
AssetType MarginCalculator::DetectAssetType(const string symbol)
{
    string sym = symbol; // ✅ FIX: Non usare StringToUpper sulla reference
    StringToUpper(sym);   // ✅ FIX: Modifica la copia
    
    // Forex patterns
    if(StringLen(sym) == 6 || StringLen(sym) == 7)
    {
        // Check common currency codes
        if(StringFind(sym, "USD") >= 0 || StringFind(sym, "EUR") >= 0 || 
           StringFind(sym, "GBP") >= 0 || StringFind(sym, "JPY") >= 0 ||
           StringFind(sym, "CHF") >= 0 || StringFind(sym, "CAD") >= 0 ||
           StringFind(sym, "AUD") >= 0 || StringFind(sym, "NZD") >= 0)
        {
            return ASSET_FOREX;
        }
    }
    
    // Crypto patterns
    if(StringFind(sym, "BTC") >= 0 || StringFind(sym, "ETH") >= 0 || 
       StringFind(sym, "CRYPTO") >= 0 || StringFind(sym, "COIN") >= 0)
    {
        return ASSET_CRYPTO;
    }
    
    // Indices patterns
    if(StringFind(sym, "DAX") >= 0 || StringFind(sym, "SPX") >= 0 || 
       StringFind(sym, "DOW") >= 0 || StringFind(sym, "NASDAQ") >= 0 ||
       StringFind(sym, "40") >= 0 || StringFind(sym, "500") >= 0)
    {
        return ASSET_INDICES;
    }
    
    // Commodities patterns
    if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0 ||
       StringFind(sym, "XAG") >= 0 || StringFind(sym, "SILVER") >= 0 ||
       StringFind(sym, "OIL") >= 0 || StringFind(sym, "CRUDE") >= 0)
    {
        return ASSET_COMMODITY;
    }
    
    return ASSET_UNKNOWN;
}

//+------------------------------------------------------------------+
//| Normalizza volume secondo vincoli simbolo                     |
//+------------------------------------------------------------------+
double MarginCalculator::NormalizeVolume(const string symbol, double volume)
{
    if(volume <= 0) return 0;
    
    double minVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double stepVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    if(minVolume <= 0 || stepVolume <= 0) return 0;
    
    // Applica limite minimo
    if(volume < minVolume) return 0;
    
    // Applica limite massimo
    if(maxVolume > 0 && volume > maxVolume) volume = maxVolume;
    
    // Normalizza al passo più vicino
    double normalizedVolume = MathRound(volume / stepVolume) * stepVolume;
    
    return normalizedVolume;
}

//+------------------------------------------------------------------+
//| Valida position size                                           |
//+------------------------------------------------------------------+
bool MarginCalculator::ValidatePositionSize(const string symbol, double lots)
{
    double normalizedLots = NormalizeVolume(symbol, lots);
    
    if(normalizedLots != lots)
    {
        SetError(StringFormat("Position size %.5f normalized to %.5f", lots, normalizedLots));
        return false;
    }
    
    return normalizedLots > 0;
}

//+------------------------------------------------------------------+
//| Converti SL da pips a points                                  |
//+------------------------------------------------------------------+
double MarginCalculator::ConvertSLPipsToPoints(const string symbol, double slPips)
{
    return CalculateSlDistanceInPoints(symbol, slPips);
}

//+------------------------------------------------------------------+
//| Aggiorna cache simbolo                                        |
//+------------------------------------------------------------------+
bool MarginCalculator::UpdateSymbolCache(const string symbol)
{
    datetime currentTime = TimeCurrent();
    
    // Usa cache se recente (meno di 1 minuto)
    if(m_cachedSymbol == symbol && (currentTime - m_cacheTime) < 60)
    {
        return true;
    }
    
    if(!IsValidSymbol(symbol))
    {
        SetError("Invalid symbol for cache update: " + symbol);
        return false;
    }
    
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tickValue <= 0 || tickSize <= 0)
    {
        SetError("Invalid tick data for symbol: " + symbol);
        return false;
    }
    
    // Aggiorna cache
    m_cachedSymbol = symbol;
    m_cachedTickValue = tickValue;
    m_cachedTickSize = tickSize;
    m_cacheTime = currentTime;
    
    return true;
}

//+------------------------------------------------------------------+
//| Calcola distanza SL in points                                 |
//+------------------------------------------------------------------+
double MarginCalculator::CalculateSlDistanceInPoints(const string symbol, double slPips)
{
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    // Per simboli 5-digit/3-digit: 1 pip = 10 points
    // Per simboli 4-digit/2-digit: 1 pip = 1 point
    double pointsPerPip = (digits == 5 || digits == 3) ? 10.0 : 1.0;
    
    return slPips * pointsPerPip;
}

//+------------------------------------------------------------------+
//| Ottiene dimensione account                                     |
//+------------------------------------------------------------------+
double MarginCalculator::GetAccountSize()
{
    // Usa equity per calcoli più precisi
    return AccountInfoDouble(ACCOUNT_EQUITY);
}

//+------------------------------------------------------------------+
//| Valida simbolo                                                 |
//+------------------------------------------------------------------+
bool MarginCalculator::IsValidSymbol(const string symbol)
{
    if(symbol == "") return false;
    
    // Verifica che il simbolo esista nel Market Watch
    return SymbolInfoInteger(symbol, SYMBOL_SELECT);
}

//+------------------------------------------------------------------+
//| Imposta errore                                                 |
//+------------------------------------------------------------------+
void MarginCalculator::SetError(const string error)
{
    m_lastError = error;
    Print("MarginCalculator ERROR: ", error);
}

#endif // MARGIN_CALCULATOR_MQH