# STRATEGIA BREAKOUT BIDIREZIONALE - DOCUMENTAZIONE TECNICA COMPLETA

## 1. LOGICA BASE

### Principio Strategico
La strategia si basa sull'apertura di mercato con breakout bidirezionale su candele di riferimento specifiche.

**Timezone di riferimento:** Italiano (con conversione automatica al fuso orario del broker)

**Meccanismo temporale:**
- Candela di Riferimento: Orario della candela da analizzare (es. 8:45)
- Timeframe di Riferimento: Timeframe su cui applicare la logica (es. 15min)
- Apertura Automatica: Alla candela successiva (es. 9:00 se TF=15min, 8:50 se TF=5min)

**Candele di riferimento predefinite:**
- Sessione 1: 8:45 → Apertura 9:00
- Sessione 2: 14:45 → Apertura 15:00

## 2. MECCANISMO DI ENTRATA

### Setup Bidirezionale
All'apertura della candela di riferimento si aprono **due posizioni simultanee:**

**Logica Long (Buy Stop):**
- Entrata: Massimo della candela precedente
- Stop Loss: Minimo della candela precedente

**Logica Short (Sell Stop):**
- Entrata: Minimo della candela precedente
- Stop Loss: Massimo della candela precedente

[... resto della documentazione strategica ...]
