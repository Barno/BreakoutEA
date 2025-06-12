//+------------------------------------------------------------------+
//|                                             MarginCalculator.mqh |
//|                                       Risk & Margin Management   |
//|                                              SOLID Architecture  |
//+------------------------------------------------------------------+

#ifndef MARGIN_CALCULATOR_MQH
#define MARGIN_CALCULATOR_MQH

#include "Enums.mqh"

//+------------------------------------------------------------------+
//| Strutture per Asset Information                                 |
//+------------------------------------------------------------------+
struct AssetInfo
{
    AssetType type;             // Tipo asset (Forex, Index, Crypto, etc.)
    double contractSize;        // Contract size
    double tickSize;            // Tick size minimo
    double tickValue;           // Valore monetario per tick
    double marginRate;          // Tasso margin requirement
    string baseQuoteCurrency;   // Valuta base/quote
    int digits;                 // Decimali prezzo
    
    AssetInfo() : type(ASSET_UNKNOWN), contractSize(0), tickSize(0), 
                  tickValue(0), marginRate(0), baseQuoteCurrency(""), digits(0) {}
};

struct MarginInfo
{
    double requiredMargin;      // Margine richiesto
    double availableMargin;     // Margine disponibile
    double marginLevel;         // Livello margine %
    double utilizationPercent;  // % utilizzo del margine disponibile
    bool canOpenPosition;       // Se possiamo aprire posizione
    string limitReason;         // Motivo limitazione se any
    
    MarginInfo() : requiredMargin(0), availableMargin(0), marginLevel(0),
                   utilizationPercent(0), canOpenPosition(false), limitReason("") {}
};

//+------------------------------------------------------------------+
//| Interface per Margin Calculator (SOLID - Dependency Inversion) |
//+------------------------------------------------------------------+
class IMarginCalculator
{
public:
    virtual double GetRequiredMargin(const string symbol, double lots, ENUM_ORDER_TYPE orderType) = 0;
    virtual double GetAvailableMargin() = 0;
    virtual bool CanOpenPosition(const string symbol, double lots, ENUM_ORDER_TYPE orderType) = 0;
    virtual MarginInfo GetMarginAnalysis(const string symbol, double lots, ENUM_ORDER_TYPE orderType) = 0;
    virtual AssetInfo GetAssetInfo(const string symbol) = 0;
};

//+------------------------------------------------------------------+
//| MarginCalculator Class - Main Implementation                   |
//+------------------------------------------------------------------+
class MarginCalculator : public IMarginCalculator
{
private:
    string m_lastError;                    // Ultimo errore
    double m_safetyMarginPercent;         // % margine di sicurezza
    double m_maxMarginUtilization;        // Max % utilizzo margine
    
    // Cache per performance
    AssetInfo m_cachedAssetInfo;
    string m_cachedSymbol;
    datetime m_cacheTime;
    
public:
    MarginCalculator();
    ~MarginCalculator();
    
    // Main Interface Implementation (IMarginCalculator)
    virtual double GetRequiredMargin(const string symbol, double lots, ENUM_ORDER_TYPE orderType) override;
    virtual double GetAvailableMargin() override;
    virtual bool CanOpenPosition(const string symbol, double lots, ENUM_ORDER_TYPE orderType) override;
    virtual MarginInfo GetMarginAnalysis(const string symbol, double lots, ENUM_ORDER_TYPE orderType) override;
    virtual AssetInfo GetAssetInfo(const string symbol) override;
    
    // Enhanced Features (Nostre Innovazioni)
    double GetMarginUtilizationPercent(const string symbol, double lots, ENUM_ORDER_TYPE orderType);
    double CalculateMaxLotsForMargin(const string symbol, ENUM_ORDER_TYPE orderType, double marginPercent = 80.0);
    double GetMarginRequirementForRisk(const string symbol, double riskPercent, double stopLossPoints);
    bool ValidateMarginSafety(const string symbol, double lots, ENUM_ORDER_TYPE orderType);
    
    // Configuration
    void SetSafetyMarginPercent(double percent) { m_safetyMarginPercent = percent; }
    void SetMaxMarginUtilization(double percent) { m_maxMarginUtilization = percent; }
    double GetSafetyMarginPercent() const { return m_safetyMarginPercent; }
    
    // Info & Status
    string GetLastError() const { return m_lastError; }
    void ClearCache();

private:
    // Core Calculation Methods
    AssetInfo DetectAssetProperties(const string symbol);
    double CalculateForexMargin(const string symbol, double lots, ENUM_ORDER_TYPE orderType);
    double CalculateIndexMargin(const string symbol, double lots, ENUM_ORDER_TYPE orderType);
    double CalculateCryptoMargin(const string symbol, double lots, ENUM_ORDER_TYPE orderType);
    double CalculateCommodityMargin(const string symbol, double lots, ENUM_ORDER_TYPE orderType);
    
    // Asset Detection & Utilities
    AssetType IdentifyAssetType(const string symbol);
    double GetSymbolContractSize(const string symbol);
    double GetSymbolMarginRate(const string symbol);
    double GetCurrentPrice(const string symbol, ENUM_ORDER_TYPE orderType);
    
    // Validation & Error Handling
    bool ValidateSymbol(const string symbol);
    bool ValidateLots(double lots);
    bool ValidateOrderType(ENUM_ORDER_TYPE orderType);
    void SetError(const string error);
    
    // Cache Management
    bool IsCacheValid(const string symbol);
    void UpdateCache(const string symbol, const AssetInfo& info);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
MarginCalculator::MarginCalculator() : m_lastError(""),
                                      m_safetyMarginPercent(20.0),
                                      m_maxMarginUtilization(80.0),
                                      m_cachedSymbol(""),
                                      m_cacheTime(0)
{
    Print("MarginCalculator: Initialized with safety margin ", m_safetyMarginPercent, "%");
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
MarginCalculator::~MarginCalculator()
{
}

//+------------------------------------------------------------------+
//| Calcola margine richiesto per posizione                        |
//+------------------------------------------------------------------+
double MarginCalculator::GetRequiredMargin(const string symbol, double lots, ENUM_ORDER_TYPE orderType)
{
    // Validazione input
    if(!ValidateSymbol(symbol) || !ValidateLots(lots) || !ValidateOrderType(orderType))
    {
        return -1;
    }
    
    // Ottieni info asset
    AssetInfo assetInfo = GetAssetInfo(symbol);
    if(assetInfo.type == ASSET_UNKNOWN)
    {
        SetError("Unknown asset type for symbol: " + symbol);
        return -1;
    }
    
    double requiredMargin = 0;
    
    // Calcola margine basato sul tipo asset
    switch(assetInfo.type)
    {
        case ASSET_FOREX:
            requiredMargin = CalculateForexMargin(symbol, lots, orderType);
            break;
        case ASSET_INDICES:
            requiredMargin = CalculateIndexMargin(symbol, lots, orderType);
            break;
        case ASSET_CRYPTO:
            requiredMargin = CalculateCryptoMargin(symbol, lots, orderType);
            break;
        case ASSET_COMMODITY:
            requiredMargin = CalculateCommodityMargin(symbol, lots, orderType);
            break;
        default:
            SetError("Unsupported asset type");
            return -1;
    }
    
    if(requiredMargin > 0)
    {
        Print("MarginCalculator: Required margin for ", lots, " lots of ", symbol, " = ", 
              DoubleToString(requiredMargin, 2), " ", AccountInfoString(ACCOUNT_CURRENCY));
    }
    
    return requiredMargin;
}

//+------------------------------------------------------------------+
//| Ottiene margine disponibile                                    |
//+------------------------------------------------------------------+
double MarginCalculator::GetAvailableMargin()
{
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    
    if(freeMargin < 0)
    {
        SetError("Cannot retrieve account free margin");
        return 0;
    }
    
    Print("MarginCalculator: Available margin = ", DoubleToString(freeMargin, 2), 
          " ", AccountInfoString(ACCOUNT_CURRENCY));
    
    return freeMargin;
}

//+------------------------------------------------------------------+
//| Verifica se possiamo aprire posizione                          |
//+------------------------------------------------------------------+
bool MarginCalculator::CanOpenPosition(const string symbol, double lots, ENUM_ORDER_TYPE orderType)
{
    double requiredMargin = GetRequiredMargin(symbol, lots, orderType);
    if(requiredMargin <= 0) return false;
    
    double availableMargin = GetAvailableMargin();
    if(availableMargin <= 0) return false;
    
    // Applica safety margin
    double safetyAdjustedMargin = availableMargin * (100.0 - m_safetyMarginPercent) / 100.0;
    
    bool canOpen = requiredMargin <= safetyAdjustedMargin;
    
    Print("MarginCalculator: Can open position? ", canOpen ? "YES" : "NO",
          " (Required: ", DoubleToString(requiredMargin, 2),
          ", Available: ", DoubleToString(safetyAdjustedMargin, 2), ")");
    
    return canOpen;
}

//+------------------------------------------------------------------+
//| Analisi completa margine                                       |
//+------------------------------------------------------------------+
MarginInfo MarginCalculator::GetMarginAnalysis(const string symbol, double lots, ENUM_ORDER_TYPE orderType)
{
    MarginInfo info;
    
    info.requiredMargin = GetRequiredMargin(symbol, lots, orderType);
    info.availableMargin = GetAvailableMargin();
    
    if(info.requiredMargin > 0 && info.availableMargin > 0)
    {
        info.utilizationPercent = (info.requiredMargin / info.availableMargin) * 100.0;
        info.marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
        
        // Determina se possiamo aprire
        double safetyAdjustedMargin = info.availableMargin * (100.0 - m_safetyMarginPercent) / 100.0;
        info.canOpenPosition = info.requiredMargin <= safetyAdjustedMargin;
        
        if(!info.canOpenPosition)
        {
            if(info.requiredMargin > info.availableMargin)
                info.limitReason = "Insufficient margin";
            else
                info.limitReason = "Safety margin limit (" + DoubleToString(m_safetyMarginPercent, 1) + "%)";
        }
    }
    else
    {
        info.canOpenPosition = false;
        info.limitReason = "Calculation error";
    }
    
    return info;
}

//+------------------------------------------------------------------+
//| Ottiene informazioni asset                                     |
//+------------------------------------------------------------------+
AssetInfo MarginCalculator::GetAssetInfo(const string symbol)
{
    // Controlla cache
    if(IsCacheValid(symbol))
    {
        return m_cachedAssetInfo;
    }
    
    // Rileva proprietà asset
    AssetInfo info = DetectAssetProperties(symbol);
    
    // Aggiorna cache
    UpdateCache(symbol, info);
    
    return info;
}

//+------------------------------------------------------------------+
//| Calcola percentuale utilizzo margine                           |
//+------------------------------------------------------------------+
double MarginCalculator::GetMarginUtilizationPercent(const string symbol, double lots, ENUM_ORDER_TYPE orderType)
{
    double requiredMargin = GetRequiredMargin(symbol, lots, orderType);
    double availableMargin = GetAvailableMargin();
    
    if(requiredMargin <= 0 || availableMargin <= 0) return 0;
    
    return (requiredMargin / availableMargin) * 100.0;
}

//+------------------------------------------------------------------+
//| Calcola lotti massimi per percentuale margine                  |
//+------------------------------------------------------------------+
double MarginCalculator::CalculateMaxLotsForMargin(const string symbol, ENUM_ORDER_TYPE orderType, double marginPercent = 80.0)
{
    double availableMargin = GetAvailableMargin();
    if(availableMargin <= 0) return 0;
    
    double targetMargin = availableMargin * marginPercent / 100.0;
    
    // Test con 1 lotto per ottenere ratio
    double testMargin = GetRequiredMargin(symbol, 1.0, orderType);
    if(testMargin <= 0) return 0;
    
    double maxLots = targetMargin / testMargin;
    
    // Arrotonda al minimo step size del broker
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    maxLots = MathFloor(maxLots / stepLot) * stepLot;
    maxLots = MathMax(maxLots, minLot);
    
    Print("MarginCalculator: Max lots for ", marginPercent, "% margin = ", DoubleToString(maxLots, 2));
    
    return maxLots;
}

//+------------------------------------------------------------------+
//| Implementazione metodi privati continua...                     |
//+------------------------------------------------------------------+

// METODI PRIVATI - Implementazione Base per MVP
// (Implementazione completa nei prossimi step)

AssetInfo MarginCalculator::DetectAssetProperties(const string symbol)
{
    AssetInfo info;
    info.type = IdentifyAssetType(symbol);
    info.contractSize = GetSymbolContractSize(symbol);
    info.tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    info.tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    info.marginRate = GetSymbolMarginRate(symbol);
    info.digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    return info;
}

AssetType MarginCalculator::IdentifyAssetType(const string symbol)
{
    // Identificazione base per MVP
    string upperSymbol = symbol;
    StringToUpper(upperSymbol);
    
    // Forex patterns
    if(StringLen(symbol) >= 6 && StringLen(symbol) <= 7)
    {
        if(StringFind(upperSymbol, "USD") >= 0 || StringFind(upperSymbol, "EUR") >= 0 ||
           StringFind(upperSymbol, "GBP") >= 0 || StringFind(upperSymbol, "JPY") >= 0)
            return ASSET_FOREX;
    }
    
    // Indices patterns
    if(StringFind(upperSymbol, "DAX") >= 0 || StringFind(upperSymbol, "SPX") >= 0 ||
       StringFind(upperSymbol, "NAS") >= 0 || StringFind(upperSymbol, "FTSE") >= 0)
        return ASSET_INDICES;
    
    // Crypto patterns
    if(StringFind(upperSymbol, "BTC") >= 0 || StringFind(upperSymbol, "ETH") >= 0 ||
       StringFind(upperSymbol, "CRYPTO") >= 0)
        return ASSET_CRYPTO;
    
    // Commodity patterns  
    if(StringFind(upperSymbol, "GOLD") >= 0 || StringFind(upperSymbol, "SILVER") >= 0 ||
       StringFind(upperSymbol, "OIL") >= 0 || StringFind(upperSymbol, "XAU") >= 0)
        return ASSET_COMMODITY;
    
    return ASSET_UNKNOWN;
}

double MarginCalculator::CalculateForexMargin(const string symbol, double lots, ENUM_ORDER_TYPE orderType)
{
    // Formula base Forex: (Lots * ContractSize * Price) / Leverage
    double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    double price = GetCurrentPrice(symbol, orderType);
    double leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
    
    if(contractSize <= 0 || price <= 0 || leverage <= 0) return -1;
    
    return (lots * contractSize * price) / leverage;
}

double MarginCalculator::CalculateIndexMargin(const string symbol, double lots, ENUM_ORDER_TYPE orderType)
{
    // Formula indici: simile a Forex ma con contract size specifico
    return CalculateForexMargin(symbol, lots, orderType);
}

double MarginCalculator::CalculateCryptoMargin(const string symbol, double lots, ENUM_ORDER_TYPE orderType)
{
    // Formula crypto: può variare per broker
    return CalculateForexMargin(symbol, lots, orderType);
}

double MarginCalculator::CalculateCommodityMargin(const string symbol, double lots, ENUM_ORDER_TYPE orderType)
{
    // Formula commodity: standard con margine specifico
    return CalculateForexMargin(symbol, lots, orderType);
}

double MarginCalculator::GetSymbolContractSize(const string symbol)
{
    return SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
}

double MarginCalculator::GetSymbolMarginRate(const string symbol)
{
    return SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL);
}

double MarginCalculator::GetCurrentPrice(const string symbol, ENUM_ORDER_TYPE orderType)
{
    MqlTick tick;
    if(!SymbolInfoTick(symbol, tick)) return 0;
    
    return (orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_LIMIT) ? 
           tick.ask : tick.bid;
}

bool MarginCalculator::ValidateSymbol(const string symbol)
{
    if(symbol == "")
    {
        SetError("Empty symbol");
        return false;
    }
    return true;
}

bool MarginCalculator::ValidateLots(double lots)
{
    if(lots <= 0)
    {
        SetError("Invalid lot size");
        return false;
    }
    return true;
}

bool MarginCalculator::ValidateOrderType(ENUM_ORDER_TYPE orderType)
{
    return true; // Per ora accetta tutti i tipi
}

void MarginCalculator::SetError(const string error)
{
    m_lastError = error;
    Print("MarginCalculator ERROR: ", error);
}

bool MarginCalculator::IsCacheValid(const string symbol)
{
    return (symbol == m_cachedSymbol && TimeCurrent() - m_cacheTime < 60); // Cache per 1 minuto
}

void MarginCalculator::UpdateCache(const string symbol, const AssetInfo& info)
{
    m_cachedSymbol = symbol;
    m_cachedAssetInfo = info;
    m_cacheTime = TimeCurrent();
}

void MarginCalculator::ClearCache()
{
    m_cachedSymbol = "";
    m_cacheTime = 0;
}

#endif // MARGIN_CALCULATOR_MQH