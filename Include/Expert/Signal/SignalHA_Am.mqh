//+------------------------------------------------------------------+
// Titre du fichier : SignalHA-Am.mqh
// Contenu du fichier :
//   * type : Classe MQL5
//   * nom : CSignalHAm
//   * dérive de : ExpertSignal
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Lucas Troncy"
//+------------------------------------------------------------------+
//| Description of the class                                         |
//| Title=Signals of indicator Heiken Ashi                           |
//| Type=SignalAdvanced                                              |
//| Name=Heiken Ashi Ameliore                                        |
//| ShortName=HAm                                                    |
//| Class=CSignalHAm                                                 |
//| Page=signal_ham                                                  |
//| No Parameters                                                    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#include <Expert\ExpertSignal.mqh>
//+------------------------------------------------------------------+
//| Heiken Ashi amélioré, valeurs retournées, pour mémoire           |
//+------------------------------------------------------------------+
//double ExtOBuffer[];       0 // Heiken Ashi Open
//double ExtHBuffer[];       1 // Heiken Ashi High
//double ExtLBuffer[];       2 // Heiken Ashi Low
//double ExtCBuffer[];       3 // Heiken Ashi Close
//double ExtColorBuffer[];   4 // Heiken Ashi Candle Color (Blue/Red)
//double ExtBullishBuffer[]; 5 // Haussier (booléen)
//double ExtBodyBuffer[];    6 // Corps
//double ExtUpperWick[];     7 // MecheSup
//double ExtLowerWick[];     8 // MecheInf
//
//+------------------------------------------------------------------+
//| Class CSignalHAm                                                 |
//| Purpose: Class of generator of trade signals based on            |
//|          the 'Heiken Ashi Amélioré' indicator.                   |
//| Is derived from the CExpertSignal class.                         |
//+------------------------------------------------------------------+
class CSignalHAm : public CExpertSignal
  {
protected:
   CiCustom          m_ham;             // object-indicator
   //--- adjusted parameters
   bool              m_auto_fullsize;         // true = pourcentages, false = points fixes
   double            m_fullsize_pts;          // taille de référence en points (0 = mode auto)

   double            m_pct_doji_body;
   double            m_pct_medium_body;
   double            m_pct_big_body;

   double            m_pct_tiny_wick;
   double            m_pct_small_wick;
   double            m_pct_long_wick;

   int               m_ham_dojibefore;          // Nombre de bougies avant le doji pour valider le signal

   //--- "weights" of market models (0-100)
   int               m_pattern_0;      // "bougie directionnelle"
   int               m_pattern_1;      // "bougie grand corps"
   int               m_pattern_2;      // "bougie cul plat"
   int               m_pattern_3;      // "bougie Doji de base"
   int               m_pattern_4;      // "bougie Doji pied long"
   int               m_pattern_5;      // "bougie Doji libellule ou tombeau"

public:
                     CSignalHAm(void);
                    ~CSignalHAm(void);
   //--- methods of setting adjustable parameters
   void              AutoFullsize(bool value)             { m_auto_fullsize = value;           }
   void              FullsizePts(double value)            { m_fullsize_pts = value;            }
   void              PctBigBody(double value)             { m_pct_big_body = value;            }
   void              PctMediumBody(double value)          { m_pct_medium_body = value;         }
   void              PctDojiBody(double value)            { m_pct_doji_body = value;           }
   void              PctTinyWick(double value)            { m_pct_tiny_wick = value;           }
   void              PctSmallWick(double value)           { m_pct_small_wick = value;          }
   void              PctLongWick(double value)            { m_pct_long_wick = value;           }
   void              DojiBefore(int value);
   //--- methods of adjusting "weights" of market models
   void              Pattern_0(int value)                { m_pattern_0=value;          }
   void              Pattern_1(int value)                { m_pattern_1=value;          }
   void              Pattern_2(int value)                { m_pattern_2=value;          }
   void              Pattern_3(int value)                { m_pattern_3=value;          }
   void              Pattern_4(int value)                { m_pattern_4=value;          }
   void              Pattern_5(int value)                { m_pattern_5=value;          }
   //--- method of verification of settings
   virtual bool      ValidationSettings(void);
   //--- method of creating the indicator and timeseries
   virtual bool      InitIndicators(CIndicators *indicators);
   //--- methods of checking if the market models are formed
   virtual int       LongCondition(void);
   virtual int       ShortCondition(void);

protected:
   //--- method of initialization of the indicator
   bool              InitHAm(CIndicators *indicators);
   //--- methods of getting data
   double            HAOpen(int ind)               { return(m_ham.GetData(0,ind));    }
   double            HAClose(int ind)              { return(m_ham.GetData(3,ind));    }
   double            HAHigh(int ind)               { return(m_ham.GetData(1,ind));    }
   double            HALow(int ind)                { return(m_ham.GetData(2,ind));    }
   double            HABull(int ind)               { return(m_ham.GetData(5,ind));    }
   double            HABody(int ind)               { return(m_ham.GetData(6,ind));    }
   double            HAUpWick(int ind)             { return(m_ham.GetData(7,ind));    }
   double            HADownWick(int ind)           { return(m_ham.GetData(8,ind));    }
   //--- methods misc.
   bool              above(double val, double pct, double fullsize_price, bool use_relative);
   bool              below(double val, double pct, double fullsize_price, bool use_relative);
   bool              ArePreviousCandlesBullish(void);
   bool              ArePreviousCandlesBearish(void);
   int               DetectPattern(int idx);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSignalHAm::CSignalHAm(void) : m_pattern_0(0),
   m_pattern_1(100),
   m_pattern_2(0),
   m_pattern_3(0),
   m_pattern_4(0),
   m_pattern_5(0),
   m_ham_dojibefore(1),
   m_auto_fullsize(true),
   m_fullsize_pts(0),
   m_pct_big_body(0.7),
   m_pct_medium_body(0.5),
   m_pct_doji_body(0.1),
   m_pct_tiny_wick(0.05),
   m_pct_small_wick(0.1),
   m_pct_long_wick(0.4)
  {
//--- initialization of protected data
   m_used_series=USE_SERIES_OPEN+USE_SERIES_HIGH+USE_SERIES_LOW+USE_SERIES_CLOSE;
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSignalHAm::~CSignalHAm(void)
  {
  }
//+------------------------------------------------------------------+
//| Validation settings protected data.                              |
//+------------------------------------------------------------------+
bool CSignalHAm::ValidationSettings(void)
  {
//--- validation settings of additional filters
   if(!CExpertSignal::ValidationSettings())
      return(false);
//--- initial data checks
   if(m_pct_big_body     <= 0 || m_pct_big_body     > 1.0 ||
      m_pct_medium_body  <= 0 || m_pct_medium_body  > 1.0 ||
      m_pct_doji_body    <= 0 || m_pct_doji_body    > 1.0 ||
      m_pct_long_wick    <= 0 || m_pct_long_wick    > 1.0 ||
      m_pct_small_wick   <= 0 || m_pct_small_wick   > 1.0 ||
      m_pct_tiny_wick    <= 0 || m_pct_tiny_wick    > 1.0 ||
      m_ham_dojibefore   <1)
     {
      Print(__FUNCTION__, ": les paramètres de pourcentage doivent être compris entre 0 et 1 et le nombre de bougies avant le doji supérieur ou égal à 1");
      return false;
     }

//--- validation de fullsize_pts si mode absolu
   if(!m_auto_fullsize && m_fullsize_pts <= 0.0)
     {
      Print(__FUNCTION__, ": en mode absolu (m_auto_fullsize == false), m_fullsize_pts doit être > 0");
      return false;
     }

   return true;
  }
//+------------------------------------------------------------------+
//| Create indicators.                                               |
//+------------------------------------------------------------------+
bool CSignalHAm::InitIndicators(CIndicators *indicators)
  {
//--- check pointer
   if(indicators==NULL)
      return(false);
//--- initialization of indicators and timeseries of additional filters
   if(!CExpertSignal::InitIndicators(indicators))
      return(false);
//--- create and initialize HAm indicator
   if(!InitHAm(indicators))
      return(false);
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Initialize HAm indicators.                                       |
//+------------------------------------------------------------------+
bool CSignalHAm::InitHAm(CIndicators *indicators)
  {
//--- check pointer
   if(indicators==NULL)
      return(false);
//--- add an object to the collection
   if(!indicators.Add(GetPointer(m_ham)))
     {
      printf(__FUNCTION__+": error adding object");
      return(false);
     }
//--- set parameters of the indicator
   MqlParam parameters[1];
//---
   parameters[0].type=TYPE_STRING;
   parameters[0].string_value="Heiken Ashi Ameliore.ex5";

//--- object initialization
   if(!m_ham.Create(m_symbol.Name(),m_period,IND_CUSTOM,1,parameters))
     {
      printf(__FUNCTION__+": error initializing object");
      return(false);
     }
//--- number of buffers
   if(!m_ham.NumBuffers(9))
     {
      printf(__FUNCTION__+": error creating buffers");
      return(false);
     }
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Détection du motif Heiken Ashi à l'index donné                   |
//+------------------------------------------------------------------+
int CSignalHAm::DetectPattern(int idx)
  {
   double high     = HAHigh(idx);
   double low      = HALow(idx);
   double open     = HAOpen(idx);
   double close    = HAClose(idx);
   double fullsize_price = high - low;

   double body     = HABody(idx);
   double upwick   = HAUpWick(idx);
   double downwick = HADownWick(idx);

// --- Logging des valeurs critiques ---
   string msg = StringFormat("DetectPattern idx=%d | fullsize_price=%.5f | body=%.5f | upwick=%.5f | downwick=%.5f",
                             idx, fullsize_price, body, upwick, downwick);
   CUtilsLTR::LogToDesktop(msg);

   if(fullsize_price <= 0.0 ||
      body == EMPTY_VALUE ||
      upwick == EMPTY_VALUE ||
      downwick == EMPTY_VALUE)
      return -1;

   bool use_relative = (m_auto_fullsize || m_fullsize_pts == 0);
   if(!use_relative)
      fullsize_price = m_fullsize_pts * m_adjusted_point;

   if(above(body, m_pct_big_body, fullsize_price, use_relative) &&
      below(upwick, m_pct_small_wick, fullsize_price, use_relative) &&
      below(downwick, m_pct_small_wick, fullsize_price, use_relative))
      return 1;

   if(above(body, m_pct_medium_body, fullsize_price, use_relative) &&
      ((below(upwick, m_pct_tiny_wick, fullsize_price, use_relative) &&
        below(downwick, m_pct_long_wick, fullsize_price, use_relative)) ||
       (below(downwick, m_pct_tiny_wick, fullsize_price, use_relative) &&
        below(upwick, m_pct_long_wick, fullsize_price, use_relative))))
      return 2;

   if(below(body, m_pct_doji_body, fullsize_price, use_relative) &&
      above(upwick, m_pct_small_wick, fullsize_price, use_relative) &&
      above(downwick, m_pct_small_wick, fullsize_price, use_relative))
      return 3;

   if(below(body, m_pct_doji_body, fullsize_price, use_relative) &&
      above(upwick, m_pct_long_wick, fullsize_price, use_relative) &&
      above(downwick, m_pct_long_wick, fullsize_price, use_relative))
      return 4;

   if(below(body, m_pct_doji_body, fullsize_price, use_relative) &&
      ((above(upwick, m_pct_long_wick, fullsize_price, use_relative) &&
        below(downwick, m_pct_tiny_wick, fullsize_price, use_relative)) ||
       (above(downwick, m_pct_long_wick, fullsize_price, use_relative) &&
        below(upwick, m_pct_tiny_wick, fullsize_price, use_relative))))
      return 5;

   return -1;
  }
//+------------------------------------------------------------------+
//|  Vote pour prendre une position longue                           |
//+------------------------------------------------------------------+
int CSignalHAm::LongCondition()
  {
   int result = 0;
   int motif = -1;
   int idx = StartIndex();
   if(idx < 0)
     {
      CUtilsLTR::LogToDesktop("Indice de départ invalide (idx < 0) dans LongCondition.");
      return 0;
     }

   double bullish = HABull(idx);
   double body = HABody(idx);
   int pattern = DetectPattern(idx);

// --- Bougies "générales" haussières ---
   if(bullish == 1.0)
     {
      if(IS_PATTERN_USAGE(0))
        {
         result = m_pattern_0;
         motif = 0;
        }

      if(pattern == 1 && IS_PATTERN_USAGE(1))
        {
         result = m_pattern_1;
         motif = 1;
        }
      else
         if(pattern == 2 && IS_PATTERN_USAGE(2))
           {
            result = m_pattern_2;
            motif = 2;
           }
     }

// --- Bougies doji ou de transition ---
   if(motif == -1 && ArePreviousCandlesBearish()) // Seulement si aucun motif général haussier n'est détecté
     {
      if(pattern == 3 && IS_PATTERN_USAGE(3))
        {
         result = m_pattern_3;
         motif = 3;
        }
      else
         if(pattern == 4 && IS_PATTERN_USAGE(4))
           {
            result = m_pattern_4;
            motif = 4;
           }
         else
            if(pattern == 5 && IS_PATTERN_USAGE(5))
              {
               result = m_pattern_5;
               motif = 5;
              }
     }

// --- Logging ---
   if(motif != -1)
      CUtilsLTR::LogToDesktop(StringFormat("Long - Motif : %d | Vote : %d | Body : %f", motif, result, body));
   else
      CUtilsLTR::LogToDesktop(StringFormat("Pas de tendance haussière - Body : %f | Vote : %d | poids : %f", body, result, m_weight));

   return result;
  }
//+------------------------------------------------------------------+
//|  Vote pour prendre une position courte                           |
//+------------------------------------------------------------------+
int CSignalHAm::ShortCondition()
  {
   int result = 0;
   int motif = -1;
   int idx = StartIndex();
   if(idx < 0)
      return 0;

   double bullish = HABull(idx);
   double body = HABody(idx);
   int pattern = DetectPattern(idx);

// --- Bougies "générales" baissières ---
   if(bullish == 0.0)
     {
      if(IS_PATTERN_USAGE(0))
        {
         result = m_pattern_0;
         motif = 0;
        }

      if(pattern == 1 && IS_PATTERN_USAGE(1))
        {
         result = m_pattern_1;
         motif = 1;
        }
      else
         if(pattern == 2 && IS_PATTERN_USAGE(2))
           {
            result = m_pattern_2;
            motif = 2;
           }
     }


// --- Bougies doji ou de transition ---
   if(motif == -1 && ArePreviousCandlesBullish()) // Seulement si aucun motif général baissier n'est détecté
     {
      if(pattern == 3 && IS_PATTERN_USAGE(3))
        {
         result = m_pattern_3;
         motif = 3;
        }
      else
         if(pattern == 4 && IS_PATTERN_USAGE(4))
           {
            result = m_pattern_4;
            motif = 4;
           }
         else
            if(pattern == 5 && IS_PATTERN_USAGE(5))
              {
               result = m_pattern_5;
               motif = 5;
              }
     }

// --- Logging ---
   if(motif != -1)
      CUtilsLTR::LogToDesktop(StringFormat("Short - Motif : %d | Vote : %d | Body : %f", motif, result, body));
//   else
//      CUtilsLTR::LogToDesktop(StringFormat("Pas de tendance baissière - Body : %f | Vote : %d | poids : %f", body, result, m_weight));

   return result;
  }

//+------------------------------------------------------------------+
//| Méthode annexe : vérifie si les bougies avant l'indice actuel    |
//| sont haussières (HABull(i) == 1).                                |
//+------------------------------------------------------------------+
bool CSignalHAm::ArePreviousCandlesBullish()
  {
// Vérification que la valeur de m_ham_dojibefore est valide
   if(m_ham_dojibefore < 1)
      return false;

// Parcours de HABull(i) pour i = 2 à (m_ham_dojibefore + 1)
   for(int i = 2; i <= m_ham_dojibefore + 1; i++)
     {
      if(HABull(i) != 1.0)
         return false; // Dès qu'une bougie n'est pas haussière, on sort immédiatement
     }

   return true; // Toutes les bougies étaient haussières
  }
//+------------------------------------------------------------------+
//| Méthode annexe : vérifie si les bougies avant l'indice actuel    |
//| sont baissières (HABull(i) == 0).                                |
//+------------------------------------------------------------------+
bool CSignalHAm::ArePreviousCandlesBearish()
  {
// Vérification que la valeur de m_ham_dojibefore est valide
   if(m_ham_dojibefore < 1)
      return false;

// Parcours de HABull(i) pour i = 2 à (m_ham_dojibefore + 1)
   for(int i = 2; i <= m_ham_dojibefore + 1; i++)
     {
      if(HABull(i) == 1.0)
         return false; // Dès qu'une bougie est haussière, on sort immédiatement
     }

   return true; // Toutes les bougies étaient baissières
  }

//+------------------------------------------------------------------+
// DojiBefore setter                                                 |
//+------------------------------------------------------------------+
void CSignalHAm::DojiBefore(int value)
  {
   if(value < 1)
      PrintFormat("Attention, valeur DojiBefore inférieure à 1 : ", value);
   m_ham_dojibefore = value;
  }
//+------------------------------------------------------------------+
//| Helper : compare si val est "au-dessus" d’un seuil donné         |
//| avec support du mode relatif ou absolu                           |
//+------------------------------------------------------------------+
bool CSignalHAm::above(double val, double pct, double fullsize_price, bool use_relative)
  {
   return use_relative ? (val / fullsize_price >= pct) : (val >= fullsize_price * pct);
  }

//+------------------------------------------------------------------+
//| Helper : compare si val est "en-dessous" d’un seuil donné        |
//| avec support du mode relatif ou absolu                           |
//+------------------------------------------------------------------+
bool CSignalHAm::below(double val, double pct, double fullsize_price, bool use_relative)
  {
   return use_relative ? (val / fullsize_price <= pct) : (val <= fullsize_price * pct);
  }

//+------------------------------------------------------------------+
// Fin du fichier SignalHA-Am.mqh
//+------------------------------------------------------------------+
