//+------------------------------------------------------------------+
// Titre du fichier : SignalDMI.mqh
// Contenu du fichier :
//   * type : Classe MQL5
//   * nom : CSignalDMI
//   * dérive de : ExpertSignal
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Lucas Troncy"
//+------------------------------------------------------------------+
//| Description of the class                                         |
//| Title=Signals of indicator DMI                                   |
//| Type=SignalAdvanced                                              |
//| Name=DMI                                                         |
//| ShortName=DMI                                                    |
//| Class=CSignalDMI                                                 |
//| Page=signal_dmi                                                  |
//| No Parameters                                                    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#include <Expert\ExpertSignal.mqh>
//+------------------------------------------------------------------+
//| Classe CSignalDMI                                                |
//+------------------------------------------------------------------+
class CSignalDMI : public CExpertSignal
  {
protected:
   CiCustom   m_dmi;
   int        m_periodDMI;
   double     m_threshold_adx;

public:
               CSignalDMI();
              ~CSignalDMI();

   void        PeriodDMI(int p)        { m_periodDMI = p;      }
   void        ThresholdADX(double t)  { m_threshold_adx = t;  }

   virtual bool InitIndicators(CIndicators *indicators);
   virtual bool ValidationSettings(void);
   virtual int  LongCondition(void);
   virtual int  ShortCondition(void);
  };

//+------------------------------------------------------------------+
//| Constructeur                                                     |
//+------------------------------------------------------------------+
CSignalDMI::CSignalDMI() : m_periodDMI(14), m_threshold_adx(20.0)
  {
   m_used_series = USE_SERIES_HIGH + USE_SERIES_LOW + USE_SERIES_CLOSE;
  }

CSignalDMI::~CSignalDMI() {}

//+------------------------------------------------------------------+
//| Validation des paramètres utilisateur                           |
//+------------------------------------------------------------------+
bool CSignalDMI::ValidationSettings()
  {
   if(m_periodDMI <= 0 || m_threshold_adx <= 0.0)
     {
      Print(__FUNCTION__, ": paramètres invalides (period ou threshold <= 0)");
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Initialisation de l'indicateur DMI/ADX                           |
//+------------------------------------------------------------------+
bool CSignalDMI::InitIndicators(CIndicators *indicators)
  {
   if(indicators == NULL)
      return false;

   if(!CExpertSignal::InitIndicators(indicators))
      return false;

   MqlParam params[1];
   params[0].type = TYPE_INT;
   params[0].integer_value = m_periodDMI;

   if(!m_dmi.Create(m_symbol.Name(), m_period, IND_CUSTOM, 1, params, "ADX"))
     {
      Print(__FUNCTION__, ": échec de création de l'indicateur ADX.");
      return false;
     }

   if(!m_dmi.NumBuffers(3))
     {
      Print(__FUNCTION__, ": l'indicateur ADX devrait fournir 3 tampons.");
      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Condition Longue                                                 |
//+------------------------------------------------------------------+
int CSignalDMI::LongCondition()
  {
   int idx = StartIndex();
   if(idx < 0)
      return 0;

   double plusDI  = m_dmi.GetData(0, idx);
   double minusDI = m_dmi.GetData(1, idx);
   double adx     = m_dmi.GetData(2, idx);

   if(plusDI > minusDI && adx >= m_threshold_adx)
      return m_weight;

   return 0;
  }

//+------------------------------------------------------------------+
//| Condition Courte                                                 |
//+------------------------------------------------------------------+
int CSignalDMI::ShortCondition()
  {
   int idx = StartIndex();
   if(idx < 0)
      return 0;

   double plusDI  = m_dmi.GetData(0, idx);
   double minusDI = m_dmi.GetData(1, idx);
   double adx     = m_dmi.GetData(2, idx);

   if(minusDI > plusDI && adx >= m_threshold_adx)
      return m_weight;

   return 0;
  }
//+------------------------------------------------------------------+
