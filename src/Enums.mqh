//+------------------------------------------------------------------+
//|                                                        Enums.mqh |
//|                                    Enumerazioni e Strutture Base |
//|                                              Simple & Effective  |
//+------------------------------------------------------------------+

#ifndef ENUMS_MQH
#define ENUMS_MQH

//+------------------------------------------------------------------+
//| Enumerazioni Essenziali                                        |
//+------------------------------------------------------------------+

// Tipo di asset (auto-detection)
enum AssetType
{
   ASSET_FOREX,        // Forex pairs
   ASSET_INDICES,      // Indici  
   ASSET_CRYPTO,       // Crypto
   ASSET_COMMODITY,    // Materie prime
   ASSET_UNKNOWN       // Non riconosciuto
};

// Stato sessione trading
enum SessionState
{
   SESSION_WAITING,         // In attesa apertura
   SESSION_ACTIVE,          // Attiva con ordini
   SESSION_DONE_FOR_SESSION, // Target raggiunti
   SESSION_EXPIRED          // Scaduta
};

// Livelli di logging
enum LogLevel
{
   LOG_INFO,           // Informazioni
   LOG_WARNING,        // Avvisi
   LOG_ERROR,          // Errori
   LOG_CRITICAL        // Critici
};

//+------------------------------------------------------------------+
//| Strutture Dati Base                                            |
//+------------------------------------------------------------------+

// Dati candela di riferimento
struct CandleData
{
   datetime time;
   double   open;
   double   high;
   double   low;
   double   close;
   
   // Metodi essenziali
   double GetBody() { return MathAbs(close - open); }
   bool IsDoji(double threshold) { return GetBody() <= threshold; }
   
   CandleData() : time(0), open(0), high(0), low(0), close(0) {}
};

// Livelli di entrata breakout
struct EntryLevels
{
   double buyEntry;     // Buy Stop level
   double sellEntry;    // Sell Stop level  
   double buySL;        // Buy Stop Loss
   double sellSL;       // Sell Stop Loss
   bool   valid;        // Livelli validi
   
   EntryLevels() : buyEntry(0), sellEntry(0), buySL(0), sellSL(0), valid(false) {}
};

// Take Profit configuration
struct TPLevel
{
   double riskReward;   // R:R ratio (es. 2.0)
   double percentage;   // % volume (es. 50.0)
   bool   hit;          // Target raggiunto
   
   TPLevel() : riskReward(0), percentage(0), hit(false) {}
   TPLevel(double rr, double pct) : riskReward(rr), percentage(pct), hit(false) {}
};

//+------------------------------------------------------------------+
//| ✅ UNIFICATA: Asset Information                                 |
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
    
    // Campi AssetDetector
    string baseSymbol;          // Simbolo base (es. EUR)
    string quoteSymbol;         // Simbolo quote (es. USD)  
    double pointValue;          // Point value in USD
    
    AssetInfo() : type(ASSET_UNKNOWN), contractSize(0), tickSize(0), 
                  tickValue(0), marginRate(0), baseQuoteCurrency(""), digits(0),
                  baseSymbol(""), quoteSymbol(""), pointValue(0) {}
};

//+------------------------------------------------------------------+
//| ✅ UNIFICATA: Position Size Information                         |
//+------------------------------------------------------------------+
struct PositionSizeInfo
{
    // Core fields
    double totalLots;           // Lotti totali da aprire
    double riskAmount;          // USD di rischio
    double stopLossPoints;      // Punti di Stop Loss
    double pointValue;          // Valore monetario per punto
    bool isValid;               // Se il calcolo è valido
    string errorReason;         // Motivo errore se any
    
    // MarginCalculator compatibility fields
    double calculatedLots;      // Alias per totalLots
    double slDistance;          // Alias per stopLossPoints
    double tickValue;           // Tick value per lotto
    double tickSize;            // Dimensione tick
    string lastError;           // Alias per errorReason
    
    PositionSizeInfo() : totalLots(0), riskAmount(0), stopLossPoints(0), 
                        pointValue(0), isValid(false), errorReason(""),
                        calculatedLots(0), slDistance(0), tickValue(0), 
                        tickSize(0), lastError("") {}
                        
    // Sync methods for compatibility
    void SyncFields() {
        calculatedLots = totalLots;
        slDistance = stopLossPoints;
        lastError = errorReason;
    }
};

//+------------------------------------------------------------------+
//| ✅ AGGIUNTA: Margin Information                                 |
//+------------------------------------------------------------------+
struct MarginInfo
{
    double requiredMargin;        // Margine richiesto per posizione
    double availableMargin;       // Margine disponibile
    double futureUsedMargin;      // Margine usato dopo apertura
    double marginUtilization;     // % utilizzo margine
    bool   canOpenPosition;       // Se posizione può essere aperta
    string lastError;            // Ultimo errore
    
    MarginInfo() : requiredMargin(0), availableMargin(0), futureUsedMargin(0), 
                   marginUtilization(0), canOpenPosition(false), lastError("") {}
};

//+------------------------------------------------------------------+
//| ✅ AGGIUNTA: Multi-Target Information                           |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| ✅ AGGIUNTA: Risk Parameters                                    |
//+------------------------------------------------------------------+
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
//| Costanti Essenziali                                            |
//+------------------------------------------------------------------+

#define MAX_SESSIONS 5         // Max sessioni simultanee
#define MAX_TAKEPROFIT 5       // Max take profit
#define HEARTBEAT_INTERVAL 3600 // Heartbeat ogni ora

//+------------------------------------------------------------------+
//| Funzioni Utility Essenziali                                    |
//+------------------------------------------------------------------+

string AssetTypeToString(AssetType type)
{
   switch(type)
   {
      case ASSET_FOREX:     return "FOREX";
      case ASSET_INDICES:   return "INDICES"; 
      case ASSET_CRYPTO:    return "CRYPTO";
      case ASSET_COMMODITY: return "COMMODITY";
      default:              return "UNKNOWN";
   }
}

string SessionStateToString(SessionState state)
{
   switch(state)
   {
      case SESSION_WAITING:         return "WAITING";
      case SESSION_ACTIVE:          return "ACTIVE";
      case SESSION_DONE_FOR_SESSION: return "DONE";
      case SESSION_EXPIRED:         return "EXPIRED";
      default:                      return "UNKNOWN";
   }
}

#endif // ENUMS_MQH