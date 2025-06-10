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