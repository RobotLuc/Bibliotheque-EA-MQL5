//+------------------------------------------------------------------+
//|                                             SignalEnveloppe.mqh  |
//|  Exemple de classe composite utilisant plusieurs CExpertSignal   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Lucas Troncy"

#include "ExpertSignal.mqh"
#include "Expert.mqh"
//+------------------------------------------------------------------+
//| Class CExpertSignalComposite                                     |
//| Purpose: Classe pour création de signaux composites multitemps   |
//| Derives from class CExpertSignal                                 |
//+------------------------------------------------------------------+
class CSignalEnveloppe : public CExpertSignal
  {
protected:
   CArrayObj m_sub_signals; // Tableau de signaux internes, chacun avec un timeframe différent
   int m_min_confirmation; // On peut garder un paramètre indiquant le nombre minimum de signaux devant confirmer la direction pour valider un signal d'achat ou de vente.

public:
                     CSignalEnveloppe(void);
                    ~CSignalEnveloppe(void);
   bool AddSubSignal(CExpertSignal *signal, ENUM_TIMEFRAMES period_signal);
   virtual bool ValidationSettings(void);
   virtual bool InitIndicators(CIndicators *indicators=NULL);
   virtual int LongCondition(void);
   virtual int ShortCondition(void);
   void MinConfirmation(int value) { m_min_confirmation = value; }   
};     
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
void CSignalEnveloppe::CSignalEnveloppe(void) : m_min_confirmation(0) 
   {
   }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+   
void CSignalEnveloppe::~CSignalEnveloppe(void)
     {
       // Nettoyage
       int total=m_sub_signals.Total();
       for(int i=0; i<total; i++)
         {
           CExpertSignal *sig=(CExpertSignal*)m_sub_signals.At(i);
           if(sig!=NULL)
             delete sig;
         }
       m_sub_signals.Clear();
     }
//+------------------------------------------------------------------+
//| Add a pre-defined signal                                         |
//+------------------------------------------------------------------+
bool CSignalEnveloppe::AddSubSignal(CExpertSignal *signal, ENUM_TIMEFRAMES period_signal)
{
   // Vérification du pointeur
   if(signal == NULL)
   {
      Print(__FUNCTION__ + ": Le signal fourni est NULL.");
      return false;
   }


   // Configurer les propriétés du signal à partir des propriétés existantes de CSignalEnveloppe
   if(!signal.Init(GetPointer(m_symbol),m_period, m_adjusted_point))
   {
      Print(__FUNCTION__ + ": Le signal fourni ne peut être initialisé.");
      return false;
   }      
   // Modifier la période du signal, de signal_enveloppe.m_period vers period_signal

   if(!signal.Period(period_signal))
   {
      Print(__FUNCTION__ + ": Impossible d'ajouter le signal au tableau interne.");
      return false;
   }  
   
   signal.EveryTick(m_every_tick);
   signal.Magic(m_magic);
   CUtilsLTR::LogToDesktop(StringFormat("Poids du signal à l'ajout dans l'enveloppe : %f | m_other_period : %d", signal.m_weight, signal.m_other_period));
   
   // Ajouter ce signal existant au tableau interne
   if(!m_sub_signals.Add(signal))
   {
      Print(__FUNCTION__ + ": Impossible d'ajouter le signal au tableau interne.");
      return false;
   }
   
   // Mettre à jour m_period si timeframe_signal est plus petit
   if(m_period == 0 || period_signal < m_period)
   {
      m_period = period_signal;
   }
  CUtilsLTR::LogToDesktop(StringFormat("Période de l'enveloppe : %f", m_period));   
   // Succès
   return true;
}
//+------------------------------------------------------------------+
//| Validate parameters                                              |
//+------------------------------------------------------------------+
bool CSignalEnveloppe::ValidationSettings(void)
     {
     // D’abord, valider la classe de base
       if(!CExpertSignal::ValidationSettings())
         return(false);
     // Compter le nombre de signaux ajoutés par l'utilisateur   
       int total=m_sub_signals.Total();  

     // Si m_min_confirmation est 0 c'est-àd-dire non modifée par l'utilisateur, lui attribuer le nombre total de signaux
       if(m_min_confirmation == 0)
            m_min_confirmation = total;
      
       // Valider aussi les signaux internes
       for(int i=0; i<total; i++)
         {
           CExpertSignal *sig=(CExpertSignal*)m_sub_signals.At(i);
           if(sig==NULL)
             return(false);
           if(!sig.ValidationSettings())
             return(false);
         }
       return(true);
     }
//+------------------------------------------------------------------+
//| Create indicators                                                |
//+------------------------------------------------------------------+
bool CSignalEnveloppe::InitIndicators(CIndicators *indicators)
     {
       // Appel de la classe de base pour initialiser ses propres indicateurs
       if(!CExpertSignal::InitIndicators(indicators))
         return(false);
       // Initialiser les indicateurs de chaque sous-signal
       int total=m_sub_signals.Total();
       for(int i=0; i<total; i++)
         {
           CExpertSignal *sig=(CExpertSignal*)m_sub_signals.At(i);
           // On passe les séries de prix déjà créées par le parent
           sig.SetPriceSeries(m_open,m_high,m_low,m_close);
           sig.SetOtherSeries(m_spread,m_time,m_tick_volume,m_real_volume);
           if(!sig.InitIndicators(indicators))
             return(false);
         }
       return(true);
     }
//+------------------------------------------------------------------+
//| Detection of Long Condition (pondérée) avec arrondi              |
//+------------------------------------------------------------------+
int CSignalEnveloppe::LongCondition(void)
  {
   int    total    = m_sub_signals.Total();
   double long_sum = 0.0;

   for(int i = 0; i < total; i++)
     {
      CExpertSignal *sig = (CExpertSignal*)m_sub_signals.At(i);
      if(sig == NULL)
         continue;

      // Somme pondérée de LongCondition()
      long_sum += sig.m_weight * sig.LongCondition();
     }
   // Division par le nombre total de signaux pour obtenir la moyenne
   long_sum /= (double)total;
   // Arrondir au plus proche entier puis caster en int
   return (int)MathRound(long_sum);
  }
//+------------------------------------------------------------------+
//| Detection of Short Condition (pondérée) avec arrondi             |
//+------------------------------------------------------------------+
int CSignalEnveloppe::ShortCondition(void)
  {
   int    total     = m_sub_signals.Total();
   double short_sum = 0.0;

   for(int i = 0; i < total; i++)
     {
      CExpertSignal *sig = (CExpertSignal*)m_sub_signals.At(i);
      if(sig == NULL)
         continue;

      // Somme pondérée de ShortCondition()
      short_sum += sig.m_weight * sig.ShortCondition();
     }
   // Division par le nombre total de signaux pour obtenir la moyenne
   short_sum /= (double)total;
   // Arrondir au plus proche entier puis caster en int
   return (int)MathRound(short_sum);
  }
//+------------------------------------------------------------------+
