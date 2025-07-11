//+------------------------------------------------------------------+
// Titre du fichier : ExpertRSI-HA-DMI.mqh
// Contenu du fichier :
//   * type : Expert Advisor MQL5
//   * nom : ExpertRSI-HA-DMI
//+------------------------------------------------------------------+
#property version   "1.00"
//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#include <Expert\ExpertAsymetrique.mqh>
#include <Expert\Signal\SignalITF.mqh>
#include <Expert\Signal\SignalRSI-LTR.mqh>
#include <Expert\Signal\SignalHA_Am.mqh>
#include <Expert\Signal\SignalMA.mqh>
#include <Expert\Trailing\TrailingNone.mqh>
#include <Expert\Money\MoneyFixedLot.mqh>
//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
//--- inputs for expert
input string Inp_Expert_Title            ="ExpertRSI-HA-MA";// Nom du robot
input int    Expert_MagicNumber          =120300;           // Nombre magique du robot
input bool   Expert_EveryTick            =false;            // Le robot est-il appelé à chaque tick ?

//--- inputs for signal HA 1
input ENUM_TIMEFRAMES    Inp_Timeframe_HA = PERIOD_H1;  // Temporalité du signal HA
input int    Inp_HA_Poids_Motif_0=100;                  // Poids :  "Bougie Cul plat"
input int    Inp_HA_Poids_Motif_1=0;                    // Poids :  "Bougie Doji"
input double Inp_BCBody = 100;                          // Nombre de points du corps de bougie
input double Inp_BCWick = 2;                            // Nombre max. de points de la mèche de bougie cul plat
input int    Inp_pattern_used_HA = 3;                   // Les motifs 1 et 2 sont utilisés, pas le 3

//--- inputs for signal HA 2
input ENUM_TIMEFRAMES    Inp_Timeframe_HA = PERIOD_H1;  // Temporalité du signal HA
input int    Inp_HA_Poids_Motif_0=100;                  // Poids :  "Bougie Cul plat"
input int    Inp_HA_Poids_Motif_1=0;                    // Poids :  "Bougie Doji"
input double Inp_BCBody = 100;                          // Nombre de points du corps de bougie
input double Inp_BCWick = 2;                            // Nombre max. de points de la mèche de bougie cul plat
input int    Inp_pattern_used_HA = 3;                   // Les motifs 1 et 2 sont utilisés, pas le 3

//--- inputs for signal HA 3
input ENUM_TIMEFRAMES    Inp_Timeframe_HA = PERIOD_H1;  // Temporalité du signal HA
input int    Inp_HA_Poids_Motif_0=100;                  // Poids :  "Bougie Cul plat"
input int    Inp_HA_Poids_Motif_1=0;                    // Poids :  "Bougie Doji"
input double Inp_BCBody = 100;                          // Nombre de points du corps de bougie
input double Inp_BCWick = 2;                            // Nombre max. de points de la mèche de bougie cul plat
input int    Inp_pattern_used_HA = 3;                   // Les motifs 1 et 2 sont utilisés, pas le 3

//--- inputs for Signal RSI
input ENUM_TIMEFRAMES    Inp_Timeframe_RSI = PERIOD_M5;  // Temporalité du signal RSI 
input int    Inp_Periode_RSI  =14;                       // Nombre de périodes pour le calcul du RSI
input ENUM_APPLIED_PRICE    Inp_Applied  =PRICE_WEIGHTED;// Prix utilisé pour calcul du RSI
//input int    Inp_Pattern_usage = 62;
input bool Inp_UsePattern0_RSI = true;  // Activer Pattern 0
input bool Inp_UsePattern1_RSI = true;  // Activer Pattern 1
input bool Inp_UsePattern2_RSI = false; // Activer Pattern 2
input bool Inp_UsePattern3_RSI = false; // Activer Pattern 3

input int    Inp_Poids_Motif_0=0;                       // Poids : "L'oscillateur a la direction requise"
input int    Inp_Poids_Motif_1=90;                      // Poids : "Renversement derrière le niveau de surachat/survente"
input int    Inp_Poids_Motif_2=0;                       // Poids : "Swing échoué"
input int    Inp_Poids_Motif_3=100;                     // Poids : "Divergence Prix-RSI"
input int    Inp_Poids_Motif_4=0;                       // Poids : "Double divergence Prix-RSI"
input int    Inp_Poids_Motif_5=0;                       // Poids : "Motif Tête/épaules"
input double Inp_SeuilRSI_Sur_Vendu = 35.0;             // Seuil en-dessous duquel le marché est considéré survendu
input double Inp_SeuilRSI_Sur_Achete = 65.0;            // Seuil en-dessus duquel le marché est considéré suracheté

//---inputs for Money
input double nbr_lots = 3.0;                  // Nombre de lots pris à chaque position

input int    Inp_SeuilOuverture = 90;         // Note minimale pour ouvrir une position (long ou short)
input int    Inp_SeuilFermeture = 90;         // Note minimale pour clore la position (long ou short)
input int    Inp_TakeProfit  =500;            // Take Profit des positions prises avec le signal, en points
input int    Inp_StopLoss    =200;            // Stop loss des posisions prises avec le signal, en points
input int    Inp_JoursFermeture =65;          // Jours de fermeture du marché. 65 = samedi et dimanche
input int    Inp_HeuresFermeture = 16646399;  // Heures de fermeture du marché, en bitmask

//+------------------------------------------------------------------+
//| Global expert object                                             |
//+------------------------------------------------------------------+
CExpert ExtExpert;
//+------------------------------------------------------------------+
//| Initialization function of the expert                            |
//+------------------------------------------------------------------+
int OnInit(void)
  {    
  
//--- Initializing expert
   if(!ExtExpert.Init(Symbol(),Period(),Expert_EveryTick,Expert_MagicNumber))
     {
      //--- failed
      printf(__FUNCTION__+": error initializing expert");
      ExtExpert.Deinit();
      return(-1);
     }

//--- Creation of open and close signal objects : base is always ITF signal
   CSignalITF *signal_open = new CSignalITF;
   CSignalITF *signal_close = new CSignalITF;  
 
   if(signal_open==NULL || signal_close == NULL)
     {
      //--- failed
      printf(__FUNCTION__+": error creating signal ITF");
      ExtExpert.Deinit();
      return(-2);
     }  

//--- Creation of filters signal objects on open signal
   CSignalHAm *f1_signal_open=new CSignalHAm;
   CSignalRSI *f2_signal_open=new CSignalRSI;

//--- Creation of filters signal objects on close signal  
   CSignalHAm *f1_signal_close = new CSignalHAm;
   
   if(f1_signal_open==NULL || f2_signal_open ==NULL || f1_signal_close == NULL)
     {
      //--- failed
      printf(__FUNCTION__+": error creating signal added to ITF Signal");
      ExtExpert.Deinit();
      return(-2);
     }
     
//--- Add signal to expert (will be deleted automatically))
   if(!ExtExpert.InitSignalOpen(signal_open) || !ExtExpert.InitSignalClose(signal_close))
     {
      //--- failed
      printf(__FUNCTION__+": error initializing signal");
      ExtExpert.Deinit();
      return(-3);
     }
               
//--- Ajouter filtre au signal d'entrée
   if(!signal_open.AddFilter(f1_signal_open) || !signal_open.AddFilter(f2_signal_open))
   {
      Print("Erreur lors de l'ajout de filtres au signal_open !");
      return INIT_FAILED;
   }     

//--- Ajouter filtre au signal de sortie
   if(!signal_close.AddFilter(f1_signal_close))
   {
      Print("Erreur lors de l'ajout de filtres au signal_close !");
      return INIT_FAILED;
   }

//---- Réglage des signaux

//--- Set signals period  
   if (!f2_signal_open.Period(Inp_Timeframe_RSI) || !f1_signal_open.Period(Inp_Timeframe_HA) || !f1_signal_close.Period(Inp_Timeframe_HA))   
     {
      //--- failed
      printf(__FUNCTION__+": error setting timeframe filter signals");
      ExtExpert.Deinit();
      return(-4);
     } 

//---- Temporal filter parameters setting
   signal_open.BadDaysOfWeek(Inp_JoursFermeture);
   signal_open.BadHoursOfDay(Inp_HeuresFermeture);
   
   signal_close.BadDaysOfWeek(Inp_JoursFermeture);
   signal_close.BadHoursOfDay(Inp_HeuresFermeture);
   
   signal_open.ThresholdOpen(Inp_SeuilOuverture);
   signal_open.ThresholdClose(Inp_SeuilFermeture);
   
   signal_close.ThresholdOpen(Inp_SeuilOuverture);
   signal_close.ThresholdClose(Inp_SeuilFermeture);
      
   signal_open.TakeLevel(Inp_TakeProfit);
   signal_open.StopLevel(Inp_StopLoss);
   
   signal_close.TakeLevel(Inp_TakeProfit);
   signal_close.StopLevel(Inp_StopLoss);       
     
//--- Set signal_open parameters
   f1_signal_open.Pattern_0(Inp_HA_Poids_Motif_0);
   f1_signal_open.Pattern_1(Inp_HA_Poids_Motif_1);
   f1_signal_open.BCBody(Inp_BCBody);
   f1_signal_open.BCWick_bottom(Inp_BCWick);

   f2_signal_open.PeriodRSI(Inp_Periode_RSI);
   f2_signal_open.Applied(Inp_Applied);
   //f2_signal_open.PatternsUsage(Inp_Pattern_usage);
   f2_signal_open.Pattern_0(Inp_Poids_Motif_0);
   f2_signal_open.Pattern_1(Inp_Poids_Motif_1);
   f2_signal_open.Pattern_2(Inp_Poids_Motif_2);
   f2_signal_open.Pattern_3(Inp_Poids_Motif_3);
   f2_signal_open.Pattern_4(Inp_Poids_Motif_4);
   f2_signal_open.Pattern_5(Inp_Poids_Motif_5);
   f2_signal_open.SeuilSurAchete(Inp_SeuilRSI_Sur_Achete);
   f2_signal_open.SeuilSurVendu(Inp_SeuilRSI_Sur_Vendu);

//--- Set signal_close parameters
   f1_signal_close.Pattern_0(Inp_HA_Poids_Motif_0);
   f1_signal_close.Pattern_1(Inp_HA_Poids_Motif_1);
   f1_signal_close.BCBody(Inp_BCBody);
   f1_signal_close.BCWick_bottom(Inp_BCWick);

//--- Check signal parameters
   if(!signal_open.ValidationSettings() || !signal_close.ValidationSettings())
     {
      //--- failed
      printf(__FUNCTION__+": error signal parameters");
      ExtExpert.Deinit();
      return(-5);
     }
//--- Check filter parameters
   if(!f1_signal_open.ValidationSettings() || !f2_signal_open.ValidationSettings() || !f1_signal_close.ValidationSettings())
     {
      //--- failed
      printf(__FUNCTION__+": error signal filter parameters");
      ExtExpert.Deinit();
      return(-5);
     }         
     
//--- Creation of trailing object
   CTrailingNone *trailing=new CTrailingNone;
   if(trailing==NULL)
     {
      //--- failed
      printf(__FUNCTION__+": error creating trailing");
      ExtExpert.Deinit();
      return(-6);
     }
//--- Add trailing to expert (will be deleted automatically))
   if(!ExtExpert.InitTrailing(trailing))
     {
      //--- failed
      printf(__FUNCTION__+": error initializing trailing");
      ExtExpert.Deinit();
      return(-7);
     }
//--- Set trailing parameters
//--- Check trailing parameters
   if(!trailing.ValidationSettings())
     {
      //--- failed
      printf(__FUNCTION__+": error trailing parameters");
      ExtExpert.Deinit();
      return(-8);
     }
//--- Creation of money object
   CMoneyFixedLot *money=new CMoneyFixedLot;
   if(money==NULL)
     {
      //--- failed
      printf(__FUNCTION__+": error creating money");
      ExtExpert.Deinit();
      return(-9);
     }
//--- Add money to expert (will be deleted automatically))
   if(!ExtExpert.InitMoney(money))
     {
      //--- failed
      printf(__FUNCTION__+": error initializing money");
      ExtExpert.Deinit();
      return(-10);
     }
//--- Set money parameters
   money.Lots(nbr_lots);
   
//--- Check money parameters
   if(!money.ValidationSettings())
     {
      //--- failed
      printf(__FUNCTION__+": error money parameters");
      ExtExpert.Deinit();
      return(-11);
     }
    
//--- Setting Expert Period
   if(!ExtExpert.Period(MathMin(signal_open.SignalMinPeriod(),signal_close.SignalMinPeriod())))
     {
      //--- failed
      printf(__FUNCTION__+": error setting expert period");
      ExtExpert.Deinit();
      return(-12);
     }
     else {
     
     printf(__FUNCTION__+": ok setting expert period : %i", MathMin(signal_open.SignalMinPeriod(),signal_close.SignalMinPeriod()));
     }             
          
//--- Tuning of all necessary indicators
   if(!ExtExpert.InitIndicators())
     {
      //--- failed
      printf(__FUNCTION__+": error initializing indicators");
      ExtExpert.Deinit();
      return(-13);
     }
     
   Print("TERMINAL_PATH = ",TerminalInfoString(TERMINAL_PATH)); 
   Print("TERMINAL_DATA_PATH = ",TerminalInfoString(TERMINAL_DATA_PATH)); 
   Print("TERMINAL_COMMONDATA_PATH = ",TerminalInfoString(TERMINAL_COMMONDATA_PATH)); 
//--- succeed
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Deinitialization function of the expert                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ExtExpert.Deinit();
  }
//+------------------------------------------------------------------+
//| Function-event handler "tick"                                    |
//+------------------------------------------------------------------+
void OnTick(void)
  {
   ExtExpert.OnTick();
  }
//+------------------------------------------------------------------+
//| Function-event handler "trade"                                   |
//+------------------------------------------------------------------+
void OnTrade(void)
  {
   ExtExpert.OnTrade();
  }
//+------------------------------------------------------------------+
//| Function-event handler "timer"                                   |
//+------------------------------------------------------------------+
void OnTimer(void)
  {
   ExtExpert.OnTimer();
  }
//+------------------------------------------------------------------+
// Fin du fichier ExpertRSI.mqh
//+------------------------------------------------------------------+