//+------------------------------------------------------------------+
// Titre du fichier : ExpertAsymetriqueDirectionnel.mqh              |
// Contenu du fichier :                                              |
//   * type : Classe MQL5                                            |
//   * nom : CExpertDir                                              |
//   * dérive de : CExpert                                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Notes de version                                                 |
//|26/04/2025 - Création                                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Lucas Troncy"
#include <Expert\ExpertAsymetrique.mqh>
//+------------------------------------------------------------------+
//| Declaration                                                      |
//+------------------------------------------------------------------+
class CExpertDir : public CExpert
  {
protected:
   bool              m_allow_long;
   bool              m_allow_short;

public:
   void              AllowLong(bool allow)  { m_allow_long = allow; }
   void              AllowShort(bool allow) { m_allow_short = allow; }

                     CExpertDir(void);        // constructeur
                    ~CExpertDir(void);       // destructeur

   virtual bool      CheckOpenLong(void) override;
   virtual bool      CheckOpenShort(void) override;
   virtual bool      ValidationSettings(void) override;
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CExpertDir::CExpertDir(void) :m_allow_long(true), m_allow_short(true)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CExpertDir::~CExpertDir(void)
  {
  }
//+------------------------------------------------------------------+
//| Validation of settings                                           |
//+------------------------------------------------------------------+
bool CExpertDir::ValidationSettings(void)
  {
   if(!CExpert::ValidationSettings())
      return(false);

//--- Vérification spécifique AllowLong / AllowShort
   if(!m_allow_long && !m_allow_short)
     {
      Print(__FUNCTION__ + ": Erreur de configuration - vous devez autoriser au moins les positions longues ou courtes.");
      return(false); // Refuse l'initialisation de l'EA
     }

//--- tout est ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Surcharge CheckOpenLong                                          |
//+------------------------------------------------------------------+
bool CExpertDir::CheckOpenLong(void)
  {
   double price = EMPTY_VALUE;
   double sl = 0.0;
   double tp = 0.0;
   datetime expiration = TimeCurrent();

   if(m_signal_open.CheckOpenLong(price, sl, tp, expiration))
     {
      if(!m_allow_long)
        {
         Print("Signal Long détecté mais l'utilisateur a désactivé les positions longues.");
         return(false);
        }

      if(!m_trade.SetOrderExpiration(expiration))
         m_expiration = expiration;
      return(OpenLong(price, sl, tp));
     }

   return(false);
  }
//+------------------------------------------------------------------+
//| Surcharge CheckOpenShort                                         |
//+------------------------------------------------------------------+
bool CExpertDir::CheckOpenShort(void)
  {
   double price = EMPTY_VALUE;
   double sl = 0.0;
   double tp = 0.0;
   datetime expiration = TimeCurrent();

   if(m_signal_open.CheckOpenShort(price, sl, tp, expiration))
     {
      if(!m_allow_short)
        {
         Print("Signal Short détecté mais l'utilisateur a désactivé les positions courtes.");
         return(false);
        }

      if(!m_trade.SetOrderExpiration(expiration))
         m_expiration = expiration;
      return(OpenShort(price, sl, tp));
     }

   return(false);
  }
//+------------------------------------------------------------------+
// Fin du fichier ExpertAsymetriqueDirectionnel.mqh
//+------------------------------------------------------------------+
