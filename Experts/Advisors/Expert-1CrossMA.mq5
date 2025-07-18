//+------------------------------------------------------------------+
//| Titre du fichier : ExpertRSI-HA-FixedPips.mqh                    |
//| Contenu du fichier :                                             |
//|   * type : Expert Advisor MQL5                                   |
//|   * nom : ExpertRSI-CrossMA-FixedPips                            |
//+------------------------------------------------------------------+
#property version   "1.0"
#property copyright "Copyright 2025, Lucas Troncy"

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <Expert\ExpertAsymetrique.mqh>
#include <Expert\Signal\BuilderSignal.mqh>
#include <Expert\Config\SignalsConfig.mqh>
#include <Expert\Config\SignalConfigFactory.mqh>
#include <Expert\Money\MoneyFixedLot.mqh>
#include <Expert\Trailing\TrailingFixedPips.mqh>

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input string Inp_Expert_Title            ="Expert-FixedPips";// Nom du robot
input int    Expert_MagicNumber          =190001;           // Nombre magique du robot
input bool   Expert_EveryTick            =false;            // Le robot est-il appelé à chaque tick ?

input int    Inp_TakeProfit            = 5000;            // Take Profit des positions prises avec le signal, en points
input int    Inp_StopLoss              = 2000;            // Stop loss des positions prises avec le signal, en points
input double nbr_lots                  = 3.0;            // Nombre de lots pris à chaque position
input int    Inp_SeuilOuverture        = 100;            // Note minimale pour ouvrir une position (long ou short)
input int    Inp_SeuilFermeture        = 100;            // Note minimale pour clore une position (long ou short)
input double Inp_Price_Level           = 0.0;            // Ecart (points) entre prix marché et bid

//--- inputs for Signal RSI
input string __SIGNAL_RSIO__ = "-------------Signal RSI prise de positions--------------";
input bool                Inp_RSIO_Active = false;              // Ce signal est-il à prendre en compte ?
input ENUM_TIMEFRAMES     Inp_Timeframe_RSI = PERIOD_M5;       // Temporalité du signal RSI ouverture
input int                 Inp_Periode_RSI    = 14;              // Nombre de périodes pour le calcul du RSI
input ENUM_APPLIED_PRICE  Inp_Applied        = PRICE_WEIGHTED; // Prix utilisé pour calcul du RSI
input double              Inp_SeuilRSI_Sur_Vendu  = 35.0;       // Seuil en-dessous duquel le marché est considéré survendu
input double              Inp_SeuilRSI_Sur_Achete = 65.0;       // Seuil en-dessus duquel le marché est considéré suracheté

bool Inp_RSIO_Enabled_Motif_0 = false;   // Activer le motif 0 : L'oscillateur a la direction requise
int  Inp_RSIO_Poids_Motif_0   = 100;      // Poids motif 0
input bool Inp_RSIO_Enabled_Motif_1 = false;   // Activer le motif 1 : Renversement derrière le niveau de surachat/survente
input int  Inp_RSIO_Poids_Motif_1   = 100;    // Poids motif 1
bool Inp_RSIO_Enabled_Motif_2 = false;   // Activer le motif 2 : Swing échoué
int  Inp_RSIO_Poids_Motif_2   = 100;      // Poids motif 2
bool Inp_RSIO_Enabled_Motif_3 = false;   // Activer le motif 3 : Divergence Prix-RSI
int  Inp_RSIO_Poids_Motif_3   = 100;    // Poids motif 3
bool Inp_RSIO_Enabled_Motif_4 = false;   // Activer le motif 4 : Double divergence Prix-RSI
int  Inp_RSIO_Poids_Motif_4   = 100;      // Poids motif 4
bool Inp_RSIO_Enabled_Motif_5 = false;   // Activer le motif 5 : Motif Tête/épaules
int  Inp_RSIO_Poids_Motif_5   = 100;      // Poids motif 5
input bool Inp_RSIO_Enabled_Motif_6 = false;   // Activer le motif 6 : Bande d'évolution du RSI
input int  Inp_RSIO_Poids_Motif_6   = 100;      // Poids motif 6

input double             Inp_MinVar_RSIO = 0.5; // Variation minimale du RSI pour détecter une tendance
input double             Inp_SeuilRSIO_medianmax = 55.0;  // Seuil minimum pour tendance RSI Longue (motif 6)
input double             Inp_SeuilRSIO_max = 70.0; // Seuil maximum pour tendance RSI Longue (motif 6)
input double             Inp_SeuilRSIO_medianmin = 45.0; // Seuil maximum pour tendance RSI Courte (motif 6)
input double             Inp_SeuilRSIO_min = 30.0; // Seuil minimum pour tendance RSI Courte (motif 6)
input bool               Inp_TrendStrategy_RSIO = true;       // Stratégie de suivi de tendance (true) ou contre-tendance (false)

//--- inputs for Signal Crossing MA
input string __SIGNAL_CROSSMA__ = "-------------Signal Croisement de MM de prise de positions--------------";
input bool               Inp_CSMA1_Active = false;              // Ce signal est-il à prendre en compte ?
input ENUM_TIMEFRAMES    Inp_Timeframe_CSMA1 = PERIOD_M5;       // Temporalité du signal Moy. Mobile fermeture
// Paramètres de la MA rapide
input   int                Inp_CSMA1_Period_Fast=8;              // Nombre de périodes pour calcul de la MM rapide
input   int                Inp_CSMA1_Shift_Fast=0;                // Décalage temporel de la MM rapide
input   ENUM_MA_METHOD     Inp_CSMA1_Method_Fast=MODE_SMA;        // Mode de calcul de la MM rapide
input   ENUM_APPLIED_PRICE Inp_CSMA1_Price_Fast=PRICE_WEIGHTED;  // Prix sur lequel la MM rapide est calculé
// Paramètres de la MA lente
input   int                Inp_CSMA1_Period_Slow=28;              // Nombre de périodes pour calcul de la MM lente
input   int                Inp_CSMA1_Shift_Slow=0;                // Décalage temporel de la MM lente
input   ENUM_MA_METHOD     Inp_CSMA1_Method_Slow=MODE_SMA;        // Mode de calcul de la MM lente
input   ENUM_APPLIED_PRICE Inp_CSMA1_Price_Slow=PRICE_WEIGHTED;  // Prix sur lequel la MM lente est calculé

input bool Inp_CSMA1_Enabled_Motif_0 = false;   // Activer le motif 0 : croisement des MM
input int  Inp_CSMA1_Poids_Motif_0   = 100;     // Poids motif 0

//--- inputs for Signal RSI fermeture
input string __SIGNAL_RSIF__ = "-------------Signal RSI cloture de positions--------------";
input bool                Inp_RSIF_Active = false;               // Ce signal est-il à prendre en compte ?
input ENUM_TIMEFRAMES     Inp_Timeframe_RSIf = PERIOD_M5;       // Temporalité du signal RSI fermeture
input int                 Inp_Periode_RSIf    = 14;              // Nombre de périodes pour le calcul du RSI
input ENUM_APPLIED_PRICE  Inp_Appliedf        = PRICE_WEIGHTED; // Prix utilisé pour calcul du RSI
input double              Inp_SeuilRSI_Sur_Venduf  = 35.0;       // Seuil en-dessous duquel le marché est considéré survendu
input double              Inp_SeuilRSI_Sur_Achetef = 65.0;       // Seuil en-dessus duquel le marché est considéré suracheté

//--- Configuration des motifs du signal RSI fermeture
bool Inp_RSIF_Enabled_Motif_0 = false;   // Activer le motif 0 : L'oscillateur a la direction requise
int  Inp_RSIF_Poids_Motif_0   = 100;      // Poids motif 0
input bool Inp_RSIF_Enabled_Motif_1 = false;   // Activer le motif 1 : Renversement derrière le niveau de surachat/survente
input int  Inp_RSIF_Poids_Motif_1   = 100;    // Poids motif 1
bool Inp_RSIF_Enabled_Motif_2 = false;   // Activer le motif 2 : Swing échoué
int  Inp_RSIF_Poids_Motif_2   = 100;      // Poids motif 2
bool Inp_RSIF_Enabled_Motif_3 = false;   // Activer le motif 3 : Divergence Prix-RSI
int  Inp_RSIF_Poids_Motif_3   = 100;    // Poids motif 3
bool Inp_RSIF_Enabled_Motif_4 = false;   // Activer le motif 4 : Double divergence Prix-RSI
int  Inp_RSIF_Poids_Motif_4   = 100;      // Poids motif 4
bool Inp_RSIF_Enabled_Motif_5 = false;   // Activer le motif 5 : Motif Tête/épaules
int  Inp_RSIF_Poids_Motif_5   = 100;      // Poids motif 5
input bool Inp_RSIF_Enabled_Motif_6 = false;   // Activer le motif 6 : Bande d'évolution du RSI
input int  Inp_RSIF_Poids_Motif_6   = 100;      // Poids motif 6

input double             Inp_MinVar_RSIF = 0.5; // Variation minimale du RSI pour détecter une tendance
input double             Inp_SeuilRSIF_medianmax = 55.0; // Seuil minimum pour tendance RSI Longue (motif 6)
input double             Inp_SeuilRSIF_max = 70.0; // Seuil maximum pour tendance RSI Longue (motif 6)
input double             Inp_SeuilRSIF_medianmin = 45.0; // Seuil maximum pour tendance RSI Courte (motif 6)
input double             Inp_SeuilRSIF_min = 30.0; // Seuil minimum pour tendance RSI Courte (motif 6)
input bool               Inp_TrendStrategy_RSIF = true;       // Stratégie de suivi de tendance (true) ou contre-tendance (false)

//--- inputs for Trailing
input string __STOP_SUIVEUR__ = "-------------Configuration du stop suiveur--------------";
input int Inp_StopLevel   = 1500;  // Nombre de points entre le SL et le prix marché
input int Inp_ProfilLevel = 5000;  // Nombre de points entre le TP et le prix marché

input string __JOURS_TRADING__ = "---Configuration des jours et heures de trading--------";
input bool Inp_Ouvert_Lundi    = true;                  // Trader le lundi
input bool Inp_Ouvert_Mardi    = true;                  // Trader le mardi
input bool Inp_Ouvert_Mercredi = true;                  // Trader le mercredi
input bool Inp_Ouvert_Jeudi    = true;                  // Trader le jeudi
input bool Inp_Ouvert_Vendredi = true;                  // Trader le vendredi
input bool Inp_Ouvert_Samedi   = false;                 // Trader le samedi
input bool Inp_Ouvert_Dimanche = false;                 // Trader le dimanche

input int  Inp_Heure_Ouverture = 8;      // Heure d'ouverture du marché
input int  Inp_Heure_Fermeture = 17;     // Heure de fermeture du marché
input int  Inp_Debut_Pause_Dej = -1;     // Heure début déjeuner (-1 : pas de déjeuner)
input int  Inp_Fin_Pause_Dej = -1;       // Heure fin déjeuner (-1 : pas de déjeuner)
//+------------------------------------------------------------------+
//| Global expert object                                             |
//+------------------------------------------------------------------+
CExpert ExtExpert;
//+------------------------------------------------------------------+
//| Nouvelle version de OnInit utilisant ConfigFactory & Builder     |
//+------------------------------------------------------------------+
int OnInit()
  {
   printf(__FUNCTION__+"Démarrage de l’EA");
   if(!ExtExpert.Init(Symbol(),Period(),Expert_EveryTick,Expert_MagicNumber))
      return INIT_FAILED;

   CSignalITF *signal_open = new CSignalITF;
   CSignalITF *signal_close = new CSignalITF;

   if(signal_open==NULL || signal_close==NULL)
      return INIT_FAILED;

   if(!ExtExpert.InitSignalOpen(signal_open) || !ExtExpert.InitSignalClose(signal_close))
     {
      printf(__FUNCTION__+": error initializing signal");
      ExtExpert.Deinit();
      return(-3);
     }

//--- Configuration du filtre temporel : jours interdits
   int bad_days = CUtilsLTR::EncodeDaysClosed(
                     Inp_Ouvert_Dimanche,
                     Inp_Ouvert_Lundi,
                     Inp_Ouvert_Mardi,
                     Inp_Ouvert_Mercredi,
                     Inp_Ouvert_Jeudi,
                     Inp_Ouvert_Vendredi,
                     Inp_Ouvert_Samedi);

   signal_open.BadDaysOfWeek(bad_days);
   signal_close.BadDaysOfWeek(bad_days);

//--- Configuration du filtre temporel : heures interdites
   int bad_hours = CUtilsLTR::GenerateBadHoursOfDay(
                      Inp_Heure_Ouverture,
                      Inp_Heure_Fermeture,
                      Inp_Debut_Pause_Dej,
                      Inp_Fin_Pause_Dej);

   signal_open.BadHoursOfDay(bad_hours);
   signal_close.BadHoursOfDay(bad_hours);

   signal_open.ThresholdOpen(Inp_SeuilOuverture);
   signal_open.ThresholdClose(Inp_SeuilFermeture);
   signal_open.TakeLevel(Inp_TakeProfit);
   signal_open.StopLevel(Inp_StopLoss);

   signal_close.ThresholdOpen(Inp_SeuilOuverture);
   signal_close.ThresholdClose(Inp_SeuilFermeture);
   signal_close.TakeLevel(Inp_TakeProfit);
   signal_close.StopLevel(Inp_StopLoss);

   signal_open.PriceLevel(Inp_Price_Level);

//--- Filtre RSI Open
   if(!CSignalBuilder::BuildAndAddFilter(signal_open,
                                         CSignalConfigFactory::CreateRSIConfig(Inp_Timeframe_RSI,
                                               Inp_RSIO_Poids_Motif_0, Inp_RSIO_Poids_Motif_1,
                                               Inp_RSIO_Poids_Motif_2, Inp_RSIO_Poids_Motif_3,
                                               Inp_RSIO_Poids_Motif_4, Inp_RSIO_Poids_Motif_5,
                                               Inp_RSIO_Poids_Motif_6,
                                               Inp_RSIO_Enabled_Motif_0, Inp_RSIO_Enabled_Motif_1,
                                               Inp_RSIO_Enabled_Motif_2, Inp_RSIO_Enabled_Motif_3,
                                               Inp_RSIO_Enabled_Motif_4, Inp_RSIO_Enabled_Motif_5,
                                               Inp_RSIO_Enabled_Motif_6,
                                               Inp_Periode_RSI,
                                               Inp_Applied,
                                               Inp_SeuilRSI_Sur_Achete,
                                               Inp_SeuilRSI_Sur_Vendu,
                                               Inp_MinVar_RSIO,
                                               Inp_SeuilRSIO_medianmax,
                                               Inp_SeuilRSIO_max,
                                               Inp_SeuilRSIO_medianmin,
                                               Inp_SeuilRSIO_min, Inp_TrendStrategy_RSIO),
                                         Inp_RSIO_Active))
     {
      Print(__FUNCTION__, ": erreur création filtre RSI O");
      ExtExpert.Deinit();
      return INIT_FAILED;
     }

//--- Filtre CrossMA Open
   if(!CSignalBuilder::BuildAndAddFilter(signal_open,
                                         CSignalConfigFactory::CreateCrossMAConfig(Inp_Timeframe_CSMA1,
                                               Inp_CSMA1_Poids_Motif_0, 0,
                                               0, 0,
                                               0,
                                               Inp_CSMA1_Enabled_Motif_0, false,
                                               false, false,
                                               false,
                                               Inp_CSMA1_Period_Fast,
                                               Inp_CSMA1_Shift_Fast,
                                               Inp_CSMA1_Method_Fast,
                                               Inp_CSMA1_Price_Fast,
                                               Inp_CSMA1_Period_Slow,
                                               Inp_CSMA1_Shift_Slow,
                                               Inp_CSMA1_Method_Slow,
                                               Inp_CSMA1_Price_Slow),
                                         Inp_CSMA1_Active))
     {
      Print(__FUNCTION__, ": erreur création filtre CrossMA O");
      ExtExpert.Deinit();
      return INIT_FAILED;
     }

//--- Filtre RSI Close
   if(!CSignalBuilder::BuildAndAddFilter(signal_close,
                                         CSignalConfigFactory::CreateRSIConfig(Inp_Timeframe_RSIf,
                                               Inp_RSIF_Poids_Motif_0, Inp_RSIF_Poids_Motif_1,
                                               Inp_RSIF_Poids_Motif_2, Inp_RSIF_Poids_Motif_3,
                                               Inp_RSIF_Poids_Motif_4, Inp_RSIF_Poids_Motif_5,
                                               Inp_RSIF_Poids_Motif_6,
                                               Inp_RSIF_Enabled_Motif_0, Inp_RSIF_Enabled_Motif_1,
                                               Inp_RSIF_Enabled_Motif_2, Inp_RSIF_Enabled_Motif_3,
                                               Inp_RSIF_Enabled_Motif_4, Inp_RSIF_Enabled_Motif_5,
                                               Inp_RSIF_Enabled_Motif_6,
                                               Inp_Periode_RSIf,
                                               Inp_Appliedf,
                                               Inp_SeuilRSI_Sur_Achetef,
                                               Inp_SeuilRSI_Sur_Venduf,
                                               Inp_MinVar_RSIF,
                                               Inp_SeuilRSIF_medianmax,
                                               Inp_SeuilRSIF_max,
                                               Inp_SeuilRSIF_medianmin,
                                               Inp_SeuilRSIF_min, Inp_TrendStrategy_RSIF),
                                         Inp_RSIF_Active))
     {
      Print(__FUNCTION__, ": erreur création filtre RSI F");
      ExtExpert.Deinit();
      return INIT_FAILED;
     }

//--- Trailing
   CTrailingFixedPips *trailing = new CTrailingFixedPips;
   if(trailing==NULL)
     {
      printf(__FUNCTION__+": error creating trailing");
      ExtExpert.Deinit();
      return(-6);
     }
   if(!ExtExpert.InitTrailing(trailing))
     {
      printf(__FUNCTION__+": error initializing trailing");
      ExtExpert.Deinit();
      return(-7);
     }
   trailing.StopLevel(Inp_StopLevel);
   trailing.ProfitLevel(Inp_ProfilLevel);

   if(!trailing.ValidationSettings())
     {
      printf(__FUNCTION__+": error trailing parameters");
      ExtExpert.Deinit();
      return(-8);
     }

//--- Money management
   CMoneyFixedLot *money=new CMoneyFixedLot;
   if(money==NULL)
     {
      printf(__FUNCTION__+": error creating money");
      ExtExpert.Deinit();
      return(-9);
     }
   if(!ExtExpert.InitMoney(money))
     {
      printf(__FUNCTION__+": error initializing money");
      ExtExpert.Deinit();
      return(-10);
     }
   money.Lots(nbr_lots);
   if(!money.ValidationSettings())
     {
      printf(__FUNCTION__+": error money parameters");
      ExtExpert.Deinit();
      return(-11);
     }

//--- Initialisation des indicateurs
   if(!ExtExpert.InitIndicators())
     {
      Print("error initializing indicators");
      ExtExpert.Deinit();
      return(-13);
     }

   Print("TERMINAL_PATH = ",TerminalInfoString(TERMINAL_PATH));
   Print("TERMINAL_DATA_PATH = ",TerminalInfoString(TERMINAL_DATA_PATH));
   Print("TERMINAL_COMMONDATA_PATH = ",TerminalInfoString(TERMINAL_COMMONDATA_PATH));

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
void OnTick()
  {
   ExtExpert.OnTick();
  }

//+------------------------------------------------------------------+
//| Function-event handler "trade"                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
   ExtExpert.OnTrade();
  }

//+------------------------------------------------------------------+
//| Function-event handler "timer"                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   ExtExpert.OnTimer();
  }

//+------------------------------------------------------------------+
//| Fin du fichier ExpertRSI-HA-FixedPips.mqh                        |
//+------------------------------------------------------------------+
