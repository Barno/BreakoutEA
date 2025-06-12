//+------------------------------------------------------------------+
//|                                                  TimeManager.mqh |
//|                                    Gestione Tempo e Fusi Orari   |
//|                                              Single Responsibility |
//+------------------------------------------------------------------+

#ifndef TIME_MANAGER_MQH
#define TIME_MANAGER_MQH

#include "Enums.mqh"

//+------------------------------------------------------------------+
//| Strutture per gestione tempo                                    |
//+------------------------------------------------------------------+
struct TimeZoneInfo
  {
   int               offsetHours;        // Offset in ore dal GMT
   bool              isDSTActive;       // Se ora legale è attiva
   string            timeZoneName;    // Nome fuso orario

                     TimeZoneInfo() : offsetHours(0), isDSTActive(false), timeZoneName("GMT") {}
  };

struct TradingHours
  {
   int               startHour;          // Ora inizio trading
   int               startMinute;        // Minuto inizio trading
   int               endHour;            // Ora fine trading
   int               endMinute;          // Minuto fine trading
   bool              isActive;          // Se questo orario è attivo

                     TradingHours() : startHour(0), startMinute(0), endHour(23), endMinute(59), isActive(true) {}
                     TradingHours(int sH, int sM, int eH, int eM) : startHour(sH), startMinute(sM), endHour(eH), endMinute(eM), isActive(true) {}
  };

//+------------------------------------------------------------------+
//| TimeManager Class                                               |
//+------------------------------------------------------------------+
class TimeManager
  {
private:
   TimeZoneInfo      m_italianTimeZone;     // Fuso orario italiano
   TimeZoneInfo      m_brokerTimeZone;      // Fuso orario broker
   int               m_manualOffsetHours;            // Offset manuale se auto-detection fallisce
   bool              m_autoDetectionEnabled;       // Se auto-detection è abilitata
   datetime          m_lastUpdateTime;         // Ultimo aggiornamento fuso orario
   string            m_lastError;                // Ultimo errore

public:
                     TimeManager();
                    ~TimeManager();

   // Main interface
   bool              Initialize(int manualOffsetHours = 0);
   datetime          ConvertItalianToBroker(datetime italianTime);
   datetime          ConvertBrokerToItalian(datetime brokerTime);
   datetime          GetBrokerTime();
   datetime          GetItalianTime();

   // Validation
   bool              IsWithinTradingHours(const TradingHours& hours, datetime timeToCheck = 0);
   bool              IsTradingDay(datetime timeToCheck = 0);
   bool              IsMarketOpen(datetime timeToCheck = 0);

   // DST Management
   bool              IsDSTActive(datetime timeToCheck = 0);
   datetime          GetDSTStartDate(int year);
   datetime          GetDSTEndDate(int year);

   // Configuration
   bool              SetManualOffset(int offsetHours);
   void              EnableAutoDetection(bool enable) { m_autoDetectionEnabled = enable; }

   // Info
   TimeZoneInfo      GetItalianTimeZone() const { return m_italianTimeZone; }
   TimeZoneInfo      GetBrokerTimeZone() const { return m_brokerTimeZone; }
   string            GetLastError() const { return m_lastError; }

private:
   bool              DetectBrokerTimeZone();
   bool              UpdateDSTStatus();
   int               CalculateOffsetFromGMT(datetime localTime, datetime gmtTime);
   bool              IsValidOffset(int offsetHours);
   void              SetError(const string error);
   datetime          CreateDateTime(int year, int month, int day, int hour = 0, int minute = 0);
   string            DetectTimeZoneName(int offsetHours, datetime serverTime);
   bool              IsSummerPeriod(datetime timeToCheck);
   bool              IsBrokerDSTActive(int offsetHours, datetime serverTime);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
TimeManager::TimeManager() : m_manualOffsetHours(0),
   m_autoDetectionEnabled(true),
   m_lastUpdateTime(0),
   m_lastError("")
  {
// Inizializza fuso orario italiano (GMT+1/+2 con DST)
   m_italianTimeZone.timeZoneName = "Europe/Rome";
   m_italianTimeZone.offsetHours = 1; // GMT+1 base
   m_italianTimeZone.isDSTActive = false;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
TimeManager::~TimeManager()
  {
  }

//+------------------------------------------------------------------+
//| Inizializza TimeManager                                         |
//+------------------------------------------------------------------+
bool TimeManager::Initialize(int manualOffsetHours = 0)
  {
   Print("TimeManager: Initializing...");

   m_manualOffsetHours = manualOffsetHours;
   m_lastError = "";

// Aggiorna status DST per l'Italia
   if(!UpdateDSTStatus())
     {
      SetError("Failed to update DST status");
      return false;
     }

// Prova rilevamento automatico fuso broker
   if(m_autoDetectionEnabled)
     {
      if(!DetectBrokerTimeZone())
        {
         Print("TimeManager WARNING: Auto-detection failed, using manual offset: ", m_manualOffsetHours);
         m_brokerTimeZone.offsetHours = m_manualOffsetHours;
         m_brokerTimeZone.timeZoneName = "Manual_Offset";
        }
     }
   else
     {
      // Usa offset manuale
      m_brokerTimeZone.offsetHours = m_manualOffsetHours;
      m_brokerTimeZone.timeZoneName = "Manual_Offset";
     }

   m_lastUpdateTime = TimeCurrent();

   Print("TimeManager: Initialized successfully");
   Print("Italian TZ: ", m_italianTimeZone.timeZoneName, " (GMT",
         m_italianTimeZone.offsetHours > 0 ? "+" : "", m_italianTimeZone.offsetHours,
         ", DST: ", m_italianTimeZone.isDSTActive ? "ON" : "OFF", ")");
   Print("Broker TZ: ", m_brokerTimeZone.timeZoneName, " (GMT",
         m_brokerTimeZone.offsetHours > 0 ? "+" : "", m_brokerTimeZone.offsetHours, ")");

   return true;
  }

//+------------------------------------------------------------------+
//| Converte orario italiano in orario broker                      |
//+------------------------------------------------------------------+
datetime TimeManager::ConvertItalianToBroker(datetime italianTime)
  {
// Calcola differenza tra fusi orari
   int italianOffset = m_italianTimeZone.offsetHours + (m_italianTimeZone.isDSTActive ? 1 : 0);
   int brokerOffset = m_brokerTimeZone.offsetHours;

   int timeDifference = brokerOffset - italianOffset;

// Applica conversione
   datetime brokerTime = italianTime + (timeDifference * 3600); // 3600 secondi = 1 ora

   return brokerTime;
  }

//+------------------------------------------------------------------+
//| Converte orario broker in orario italiano                      |
//+------------------------------------------------------------------+
datetime TimeManager::ConvertBrokerToItalian(datetime brokerTime)
  {
// Calcola differenza tra fusi orari
   int italianOffset = m_italianTimeZone.offsetHours + (m_italianTimeZone.isDSTActive ? 1 : 0);
   int brokerOffset = m_brokerTimeZone.offsetHours;

   int timeDifference = italianOffset - brokerOffset;

// Applica conversione
   datetime italianTime = brokerTime + (timeDifference * 3600);

   return italianTime;
  }

//+------------------------------------------------------------------+
//| Ottiene orario corrente del broker                             |
//+------------------------------------------------------------------+
datetime TimeManager::GetBrokerTime()
  {
   return TimeCurrent(); // MT5 restituisce sempre orario broker
  }

//+------------------------------------------------------------------+
//| Ottiene orario corrente italiano                               |
//+------------------------------------------------------------------+
datetime TimeManager::GetItalianTime()
  {
   return ConvertBrokerToItalian(TimeCurrent());
  }

//+------------------------------------------------------------------+
//| Verifica se siamo negli orari di trading                       |
//+------------------------------------------------------------------+
bool TimeManager::IsWithinTradingHours(const TradingHours& hours, datetime timeToCheck = 0)
  {
   if(!hours.isActive)
      return false;

   if(timeToCheck == 0)
      timeToCheck = GetItalianTime();

   MqlDateTime dt;
   TimeToStruct(timeToCheck, dt);

// Converti orari in minuti per confronto semplice
   int currentMinutes = dt.hour * 60 + dt.min;
   int startMinutes = hours.startHour * 60 + hours.startMinute;
   int endMinutes = hours.endHour * 60 + hours.endMinute;

// Gestione orari che attraversano mezzanotte
   if(endMinutes < startMinutes)
     {
      return (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
     }
   else
     {
      return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
     }
  }

//+------------------------------------------------------------------+
//| Verifica se è un giorno di trading                             |
//+------------------------------------------------------------------+
bool TimeManager::IsTradingDay(datetime timeToCheck = 0)
  {
   if(timeToCheck == 0)
      timeToCheck = GetItalianTime();

   MqlDateTime dt;
   TimeToStruct(timeToCheck, dt);

// Lunedì = 1, Domenica = 0
// Trading: Lunedì-Venerdì (1-5)
   return (dt.day_of_week >= 1 && dt.day_of_week <= 5);
  }

//+------------------------------------------------------------------+
//| Verifica se il mercato è aperto                                |
//+------------------------------------------------------------------+
bool TimeManager::IsMarketOpen(datetime timeToCheck = 0)
  {
   if(timeToCheck == 0)
      timeToCheck = GetItalianTime();

// Controlla se è giorno di trading
   if(!IsTradingDay(timeToCheck))
      return false;

// Orari standard Forex: 22:00 Domenica - 22:00 Venerdì (GMT)
// In italiano: 23:00 Domenica - 23:00 Venerdì (ora solare) / 00:00-00:00 (ora legale)
   TradingHours forexHours;
   forexHours.startHour = m_italianTimeZone.isDSTActive ? 0 : 23;
   forexHours.startMinute = 0;
   forexHours.endHour = m_italianTimeZone.isDSTActive ? 0 : 23;
   forexHours.endMinute = 0;

   return IsWithinTradingHours(forexHours, timeToCheck);
  }

//+------------------------------------------------------------------+
//| Verifica se ora legale è attiva                                |
//+------------------------------------------------------------------+
bool TimeManager::IsDSTActive(datetime timeToCheck = 0)
  {
   if(timeToCheck == 0)
      timeToCheck = GetItalianTime();

   MqlDateTime dt;
   TimeToStruct(timeToCheck, dt);

   datetime dstStart = GetDSTStartDate(dt.year);
   datetime dstEnd = GetDSTEndDate(dt.year);

   return (timeToCheck >= dstStart && timeToCheck < dstEnd);
  }

//+------------------------------------------------------------------+
//| Calcola data inizio ora legale (ultima domenica di marzo)      |
//+------------------------------------------------------------------+
datetime TimeManager::GetDSTStartDate(int year)
  {
// Ultima domenica di marzo, ore 02:00
   datetime marchEnd = CreateDateTime(year, 3, 31, 2, 0); // 31 marzo

   MqlDateTime dt;
   TimeToStruct(marchEnd, dt);

// Trova ultima domenica (day_of_week = 0)
   int daysToSubtract = dt.day_of_week == 0 ? 0 : dt.day_of_week;

   return marchEnd - (daysToSubtract * 86400); // 86400 = secondi in un giorno
  }

//+------------------------------------------------------------------+
//| Calcola data fine ora legale (ultima domenica di ottobre)      |
//+------------------------------------------------------------------+
datetime TimeManager::GetDSTEndDate(int year)
  {
// Ultima domenica di ottobre, ore 03:00
   datetime octoberEnd = CreateDateTime(year, 10, 31, 3, 0); // 31 ottobre

   MqlDateTime dt;
   TimeToStruct(octoberEnd, dt);

// Trova ultima domenica
   int daysToSubtract = dt.day_of_week == 0 ? 0 : dt.day_of_week;

   return octoberEnd - (daysToSubtract * 86400);
  }

//+------------------------------------------------------------------+
//| Imposta offset manuale                                         |
//+------------------------------------------------------------------+
bool TimeManager::SetManualOffset(int offsetHours)
  {
   if(!IsValidOffset(offsetHours))
     {
      SetError("Invalid offset hours: " + IntegerToString(offsetHours));
      return false;
     }

   m_manualOffsetHours = offsetHours;
   m_brokerTimeZone.offsetHours = offsetHours;
   m_brokerTimeZone.timeZoneName = "Manual_Offset";

   Print("TimeManager: Manual offset set to GMT", offsetHours > 0 ? "+" : "", offsetHours);
   return true;
  }

//+------------------------------------------------------------------+
//| Rileva automaticamente fuso orario broker                      |
//+------------------------------------------------------------------+
bool TimeManager::DetectBrokerTimeZone()
  {
   Print("TimeManager: Attempting auto-detection of broker timezone...");

// Ottieni orario server e GMT
   datetime serverTime = TimeCurrent();//Restituisce l'ultimo orario conosciuto di server (orario della ricevuta dell'ultima quotazione) nel formato datetime
   string timeString = TimeToString(serverTime);
   Print("Server Time: ", timeString);
   datetime gmtTime = TimeGMT(); //Restituisce GMT in formato datetime con l'ora legale dell' orario locale del computer, in cui il terminale client è in esecuzione
   string timeStringGTM = TimeToString(gmtTime);
   Print("GMT Current Time: ", timeStringGTM);
   datetime macTime = TimeLocal();     // Orario del tuo Mac
   int diffHours = (macTime - gmtTime) / 3600;
   int offset =TimeGMTOffset() / 3600; //Restituisce la corrente differenza tra l'orario GMT e l'ora del computer locale in secondi, tenendo conto dello switch per l'inverno o estate. Dipende dalle impostazioni dell'ora del computer.

   Print("Mac Time: ", TimeToString(macTime));
   Print("GMT Time: ", TimeToString(gmtTime));
   Print("Difference di ore tra locale e gmt time ", diffHours, " hours");
   Print("Difference (TimeGMTOffset) tra l'ora del computer e GMT tenendo conto dello switch estete inverno: ", offset, " hours");

   if(gmtTime == 0)
     {
      SetError("Cannot get GMT time for auto-detection");
      return false;
     }

// Calcola offset in ore
   int offsetSeconds = (int)(serverTime - gmtTime);
   int offsetHours = offsetSeconds / 3600;

// Arrotonda per gestire minuti extra
   int remainingMinutes = MathAbs(offsetSeconds % 3600) / 60;
   //gestisce i ritardi di sottrazione per vedere esattamente quanto ore ci sono di differenza. se la sottrazione viene fatta qualche minuto dopo si rischierebbe di avere una sottrazione sbagliata
   if(remainingMinutes > 15)
     {
      offsetHours += (offsetSeconds > 0) ? 1 : -1;
     }

   if(!IsValidOffset(offsetHours))
     {
      SetError("Detected invalid offset: " + IntegerToString(offsetHours));
      return false;
     }

// Determina timezone probabile basata su offset
   string detectedTimeZone = DetectTimeZoneName(offsetHours, serverTime);

   m_brokerTimeZone.offsetHours = offsetHours;
   m_brokerTimeZone.timeZoneName = detectedTimeZone;
   m_brokerTimeZone.isDSTActive = IsBrokerDSTActive(offsetHours, serverTime);

   Print("TimeManager: Auto-detected broker timezone: ", detectedTimeZone,
         " (GMT", offsetHours > 0 ? "+" : "", offsetHours, ")");

   return true;
  }

//+------------------------------------------------------------------+
//| Determina nome timezone da offset                              |
//+------------------------------------------------------------------+
string TimeManager::DetectTimeZoneName(int offsetHours, datetime serverTime)
  {
// Verifica se è estate o inverno per DST
   bool isSummer = IsSummerPeriod(serverTime);

   switch(offsetHours)
     {
      case 0:
         return "GMT/UTC (London)";
      case 1:
         return isSummer ? "CET/CEST (Central Europe Summer)" : "CET (Central Europe)";
      case 2:
         if(isSummer)
            return "EET/EEST (Eastern Europe Summer - Cyprus/Greece)";
         else
            return "EET (Eastern Europe - Cyprus/Greece)";
      case 3:
         if(isSummer)
            return "IDT (Israel Daylight Time)";
         else
            return "IST/MSK (Israel Standard/Moscow Time)";
      case 4:
         return "GST (Gulf Standard - Dubai/Abu Dhabi)";
      case 5:
         return "PKT (Pakistan Time)";
      case 6:
         return "BST (Bangladesh Time)";
      case 7:
         return "ICT (Indochina Time)";
      case 8:
         return "SGT/CST (Singapore/China Time)";
      case 9:
         return "JST (Japan Standard Time)";
      case 10:
         return "AEST (Australian Eastern Time)";
      case -5:
         return isSummer ? "EDT (US Eastern Daylight)" : "EST (US Eastern Standard)";
      case -6:
         return isSummer ? "CDT (US Central Daylight)" : "CST (US Central Standard)";
      case -7:
         return isSummer ? "PDT (US Pacific Daylight)" : "PST (US Pacific Standard)";
      case -8:
         return "PST (US Pacific Standard)";
      default:
         return "Unknown (GMT" + (offsetHours > 0 ? "+" : "") + IntegerToString(offsetHours) + ")";
     }
  }

//+------------------------------------------------------------------+
//| Verifica se è periodo estivo (approssimativo)                  |
//+------------------------------------------------------------------+
bool TimeManager::IsSummerPeriod(datetime timeToCheck)
  {
   MqlDateTime dt;
   TimeToStruct(timeToCheck, dt);

// Approssimazione: Aprile-Settembre = estate
   return (dt.mon >= 4 && dt.mon <= 9);
  }

//+------------------------------------------------------------------+
//| Verifica se broker ha DST attivo                               |
//+------------------------------------------------------------------+
bool TimeManager::IsBrokerDSTActive(int offsetHours, datetime serverTime)
  {
// Logica DST basata su timezone comune dei broker
   bool isSummer = IsSummerPeriod(serverTime);

   switch(offsetHours)
     {
      case 1:  // Europa Centrale (molti broker EU)
      case 2:  // Europa Orientale (Cipro, Grecia)
         return isSummer; // DST attivo in estate

      case 3:  // Israele (molti broker forex)
         return isSummer; // Israele ha DST

      case 0:  // Regno Unito
         return isSummer; // UK ha DST

      case -5: // US Eastern
      case -6: // US Central
      case -7: // US Pacific
         return isSummer; // USA ha DST

      default:
         return false; // Conservativo per timezone sconosciute
     }
  }

//+------------------------------------------------------------------+
//| Aggiorna status ora legale                                     |
//+------------------------------------------------------------------+
bool TimeManager::UpdateDSTStatus()
  {
   datetime currentTime = GetItalianTime();
   bool wasDSTActive = m_italianTimeZone.isDSTActive;

   m_italianTimeZone.isDSTActive = IsDSTActive(currentTime);

// Aggiorna offset italiano
   m_italianTimeZone.offsetHours = 1 + (m_italianTimeZone.isDSTActive ? 1 : 0);

   if(wasDSTActive != m_italianTimeZone.isDSTActive)
     {
      Print("TimeManager: DST status changed - Now: ",
            m_italianTimeZone.isDSTActive ? "ACTIVE (GMT+2)" : "INACTIVE (GMT+1)");
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Calcola offset da GMT                                          |
//+------------------------------------------------------------------+
int TimeManager::CalculateOffsetFromGMT(datetime localTime, datetime gmtTime)
  {
   int differenceSeconds = (int)(localTime - gmtTime);
   int offsetHours = differenceSeconds / 3600;

// Arrotonda a ore intere
   if(MathAbs(differenceSeconds % 3600) > 1800) // Più di 30 minuti
     {
      offsetHours += (differenceSeconds > 0) ? 1 : -1;
     }

   return offsetHours;
  }

//+------------------------------------------------------------------+
//| Valida offset orario                                           |
//+------------------------------------------------------------------+
bool TimeManager::IsValidOffset(int offsetHours)
  {
// Fusi orari validi: da GMT-12 a GMT+14
   return (offsetHours >= -12 && offsetHours <= 14);
  }

//+------------------------------------------------------------------+
//| Imposta messaggio di errore                                    |
//+------------------------------------------------------------------+
void TimeManager::SetError(const string error)
  {
   m_lastError = error;
   Print("TimeManager ERROR: ", error);
  }

//+------------------------------------------------------------------+
//| Crea datetime da componenti                                    |
//+------------------------------------------------------------------+
datetime TimeManager::CreateDateTime(int year, int month, int day, int hour = 0, int minute = 0)
  {
   MqlDateTime dt;
   dt.year = year;
   dt.mon = month;
   dt.day = day;
   dt.hour = hour;
   dt.min = minute;
   dt.sec = 0;

   return StructToTime(dt);
  }

#endif // TIME_MANAGER_MQH
//+------------------------------------------------------------------+
