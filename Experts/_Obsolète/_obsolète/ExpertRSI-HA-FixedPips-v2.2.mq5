//+------------------------------------------------------------------+
//| Titre du fichier : ExpertRSI-HA-FixedPips.mqh                   |
//| Contenu du fichier :                                             |
//|   * type : Expert Advisor MQL5                                   |
//|   * nom : ExpertRSI-HA-FixedPips                                 |
//+------------------------------------------------------------------+
#property version   "2.10"
#property copyright "Copyright 2025, Lucas Troncy"

//+------------------------------------------------------------------+
//| Notes de version                                                  |
//+------------------------------------------------------------------+
// v1.0 : expert de base
// v2.0 : expert utilisant les méthodes BuildAndAddFilter
// v2.1 : corrigé oubli de Inp IsActive des RSI et configuration jours et heures trade

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
input string Inp_Expert_Title            ="ExpertRSI-HA";// Nom du robot
input int    Expert_MagicNumber          =120302;           // Nombre magique du robot
input bool   Expert_EveryTick            =false;            // Le robot est-il appelé à chaque tick ?

input int    Inp_TakeProfit            = 5000;            // Take Profit des positions prises avec le signal, en points
input int    Inp_StopLoss              = 2000;            // Stop loss des positions prises avec le signal, en points
input double nbr_lots                  = 3.0;            // Nombre de lots pris à chaque position
input int    Inp_SeuilOuverture        = 100;            // Note minimale pour ouvrir une position (long ou short)
input int    Inp_SeuilFermeture        = 99;            // Note minimale pour clore une position (long ou short)

//--- inputs for signal HA 1
input string __SIGNAL_HA1__ = "-------------Signal Heiken Ashi 1 prise de positions------";
input bool            Inp_HA1_Active = true;               // Ce signal est-il à prendre en compte ?
input ENUM_TIMEFRAMES Inp_Timeframe_HA1     = PERIOD_M5;   // Temporalité du signal ouverture HA 1

//--- Paramétrage des motifs HA1
input bool Inp_HA1_Enabled_Motif_0 = true;   // Activer le motif 0 : Bougie directionnelle
input int  Inp_HA1_Poids_Motif_0   = 0;      // Poids : Bougie directionnelle
input bool Inp_HA1_Enabled_Motif_1 = true;   // Activer le motif 1 : Bougie grand corps
input int  Inp_HA1_Poids_Motif_1   = 0;      // Poids : Bougie grand corps
input bool Inp_HA1_Enabled_Motif_2 = true;   // Activer le motif 2 : Bougie cul plat
input int  Inp_HA1_Poids_Motif_2   = 100;    // Poids : Bougie cul plat
input bool Inp_HA1_Enabled_Motif_3 = true;   // Activer le motif 3 : Doji classique
input int  Inp_HA1_Poids_Motif_3   = 0;      // Poids : Doji classique
input bool Inp_HA1_Enabled_Motif_4 = true;   // Activer le motif 4 : Doji pied long
input int  Inp_HA1_Poids_Motif_4   = 0;      // Poids : Doji pied long
input bool Inp_HA1_Enabled_Motif_5 = true;   // Activer le motif 5 : Doji libellule / tombeau
input int  Inp_HA1_Poids_Motif_5   = 0;      // Poids : Doji libellule / tombeau

//--- Paramètres de détection des motifs
input bool   Inp_HA1_auto_fullsize   = true;  // Mode relatif (true) ou absolu (false)
input double Inp_HA1_fullsize_pts    = 0.0;   // Taille de référence en points si mode absolu

input double Inp_HA1_pct_big_body    = 0.7;   // Seuil pour grand corps (0.7 = 70% de la bougie)
input double Inp_HA1_pct_medium_body = 0.5;   // Seuil pour corps moyen
input double Inp_HA1_pct_doji_body   = 0.1;   // Seuil pour considérer un corps de doji
input double Inp_HA1_pct_tiny_wick   = 0.05;  // Seuil pour une très petite mèche
input double Inp_HA1_pct_small_wick  = 0.1;   // Seuil pour une mèche petite
input double Inp_HA1_pct_long_wick   = 0.4;   // Seuil pour une mèche longue

input int    Inp_HA1_dojibefore      = 1;     // Nombre de bougies précédentes pour valider un doji

//--- inputs for signal HA 2
input string __SIGNAL_HA2__ = "-------------Signal Heiken Ashi 2 prise de positions------";
input bool            Inp_HA2_Active = false;               // Ce signal est-il à prendre en compte ?
input ENUM_TIMEFRAMES Inp_Timeframe_HA2     = PERIOD_H1;   // Temporalité du signal ouverture HA 2

//--- Poids des motifs 0 à 5
//--- Paramétrage des motifs HA2
input bool Inp_HA2_Enabled_Motif_0 = true;   // Activer le motif 0 : Bougie directionnelle
input int  Inp_HA2_Poids_Motif_0   = 0;      // Poids : Bougie directionnelle
input bool Inp_HA2_Enabled_Motif_1 = true;   // Activer le motif 1 : Bougie grand corps
input int  Inp_HA2_Poids_Motif_1   = 0;      // Poids : Bougie grand corps
input bool Inp_HA2_Enabled_Motif_2 = true;   // Activer le motif 2 : Bougie cul plat
input int  Inp_HA2_Poids_Motif_2   = 100;    // Poids : Bougie cul plat
input bool Inp_HA2_Enabled_Motif_3 = true;   // Activer le motif 3 : Doji classique
input int  Inp_HA2_Poids_Motif_3   = 0;      // Poids : Doji classique
input bool Inp_HA2_Enabled_Motif_4 = true;   // Activer le motif 4 : Doji pied long
input int  Inp_HA2_Poids_Motif_4   = 0;      // Poids : Doji pied long
input bool Inp_HA2_Enabled_Motif_5 = true;   // Activer le motif 5 : Doji libellule / tombeau
input int  Inp_HA2_Poids_Motif_5   = 0;      // Poids : Doji libellule / tombeau

//--- Paramètres de détection des motifs
input bool   Inp_HA2_auto_fullsize   = true;  // Mode relatif (true) ou absolu (false)
input double Inp_HA2_fullsize_pts    = 0.0;   // Taille de référence en points si mode absolu

input double Inp_HA2_pct_big_body    = 0.7;   // Seuil pour grand corps (en % de la bougie)
input double Inp_HA2_pct_medium_body = 0.5;   // Seuil pour corps moyen
input double Inp_HA2_pct_doji_body   = 0.1;   // Seuil pour considérer un doji

input double Inp_HA2_pct_tiny_wick   = 0.05;  // Seuil pour une très petite mèche
input double Inp_HA2_pct_small_wick  = 0.1;   // Seuil pour une mèche petite
input double Inp_HA2_pct_long_wick   = 0.4;   // Seuil pour une mèche longue

input int    Inp_HA2_dojibefore      = 1;     // Nombre de bougies précédentes pour valider un doji


//--- inputs for signal HA 3
input string __SIGNAL_HA3__ = "-------------Signal Heiken Ashi 3 prise de positions------";
input bool            Inp_HA3_Active = false;               // Ce signal est-il à prendre en compte ?
input ENUM_TIMEFRAMES Inp_Timeframe_HA3     = PERIOD_M15;  // Temporalité du signal ouverture HA 3

//--- Paramétrage des motifs HA3
input bool Inp_HA3_Enabled_Motif_0 = true;   // Activer le motif 0 : Bougie directionnelle
input int  Inp_HA3_Poids_Motif_0   = 0;      // Poids : Bougie directionnelle
input bool Inp_HA3_Enabled_Motif_1 = true;   // Activer le motif 1 : Bougie grand corps
input int  Inp_HA3_Poids_Motif_1   = 0;      // Poids : Bougie grand corps
input bool Inp_HA3_Enabled_Motif_2 = true;   // Activer le motif 2 : Bougie cul plat
input int  Inp_HA3_Poids_Motif_2   = 100;    // Poids : Bougie cul plat
input bool Inp_HA3_Enabled_Motif_3 = true;   // Activer le motif 3 : Doji classique
input int  Inp_HA3_Poids_Motif_3   = 0;      // Poids : Doji classique
input bool Inp_HA3_Enabled_Motif_4 = true;   // Activer le motif 4 : Doji pied long
input int  Inp_HA3_Poids_Motif_4   = 0;      // Poids : Doji pied long
input bool Inp_HA3_Enabled_Motif_5 = true;   // Activer le motif 5 : Doji libellule / tombeau
input int  Inp_HA3_Poids_Motif_5   = 0;      // Poids : Doji libellule / tombeau

//--- Paramètres de détection des motifs
input bool   Inp_HA3_auto_fullsize   = true;  // Mode relatif (true) ou absolu (false)
input double Inp_HA3_fullsize_pts    = 0.0;   // Taille de référence en points si mode absolu

input double Inp_HA3_pct_big_body    = 0.7;   // Seuil pour grand corps (en % de la bougie)
input double Inp_HA3_pct_medium_body = 0.5;   // Seuil pour corps moyen
input double Inp_HA3_pct_doji_body   = 0.1;   // Seuil pour considérer un doji

input double Inp_HA3_pct_tiny_wick   = 0.05;  // Seuil pour une très petite mèche
input double Inp_HA3_pct_small_wick  = 0.1;   // Seuil pour une mèche petite
input double Inp_HA3_pct_long_wick   = 0.4;   // Seuil pour une mèche longue

input int    Inp_HA3_dojibefore      = 1;     // Nombre de bougies précédentes pour valider un doji

//--- inputs for Signal RSI
input string __SIGNAL_RSIO__ = "-------------Signal RSI prise de positions--------------";
input bool                Inp_RSIO_Active = false;              // Ce signal est-il à prendre en compte ?
input ENUM_TIMEFRAMES     Inp_Timeframe_RSI = PERIOD_M5;       // Temporalité du signal RSI ouverture
input int                 Inp_Periode_RSI    = 14;              // Nombre de périodes pour le calcul du RSI
input ENUM_APPLIED_PRICE  Inp_Applied        = PRICE_WEIGHTED; // Prix utilisé pour calcul du RSI
input double              Inp_SeuilRSI_Sur_Vendu  = 35.0;       // Seuil en-dessous duquel le marché est considéré survendu
input double              Inp_SeuilRSI_Sur_Achete = 65.0;       // Seuil en-dessus duquel le marché est considéré suracheté
//--- Configuration des motifs du signal RSI ouverture
input bool Inp_RSIO_Enabled_Motif_0 = true;   // Activer le motif 0 : L'oscillateur a la direction requise
input int  Inp_RSIO_Poids_Motif_0   = 0;      // Poids motif 0
input bool Inp_RSIO_Enabled_Motif_1 = true;   // Activer le motif 1 : Renversement derrière le niveau de surachat/survente
input int  Inp_RSIO_Poids_Motif_1   = 100;    // Poids motif 1
input bool Inp_RSIO_Enabled_Motif_2 = true;   // Activer le motif 2 : Swing échoué
input int  Inp_RSIO_Poids_Motif_2   = 0;      // Poids motif 2
input bool Inp_RSIO_Enabled_Motif_3 = true;   // Activer le motif 3 : Divergence Prix-RSI
input int  Inp_RSIO_Poids_Motif_3   = 100;    // Poids motif 3
input bool Inp_RSIO_Enabled_Motif_4 = true;   // Activer le motif 4 : Double divergence Prix-RSI
input int  Inp_RSIO_Poids_Motif_4   = 0;      // Poids motif 4
input bool Inp_RSIO_Enabled_Motif_5 = true;   // Activer le motif 5 : Motif Tête/épaules
input int  Inp_RSIO_Poids_Motif_5   = 0;      // Poids motif 5

//--- inputs for signal HA fermeture
input string __SIGNAL_HA4__ = "-------------Signal Heiken Ashi cloture de positions------";
input bool            Inp_HAf_Active = false;               // Ce signal est-il à prendre en compte ?
input ENUM_TIMEFRAMES Inp_Timeframe_HAf     = PERIOD_H4;   // Temporalité du signal fermeture HA

//--- Poids des motifs 0 à 5
//--- Paramétrage des motifs HA4 (fermeture)
input bool Inp_HAf_Enabled_Motif_0 = true;   // Activer le motif 0 : Bougie directionnelle
input int  Inp_HAf_Poids_Motif_0   = 0;      // Poids : Bougie directionnelle
input bool Inp_HAf_Enabled_Motif_1 = true;   // Activer le motif 1 : Bougie grand corps
input int  Inp_HAf_Poids_Motif_1   = 0;      // Poids : Bougie grand corps
input bool Inp_HAf_Enabled_Motif_2 = true;   // Activer le motif 2 : Bougie cul plat
input int  Inp_HAf_Poids_Motif_2   = 100;    // Poids : Bougie cul plat
input bool Inp_HAf_Enabled_Motif_3 = true;   // Activer le motif 3 : Doji classique
input int  Inp_HAf_Poids_Motif_3   = 0;      // Poids : Doji classique
input bool Inp_HAf_Enabled_Motif_4 = true;   // Activer le motif 4 : Doji pied long
input int  Inp_HAf_Poids_Motif_4   = 0;      // Poids : Doji pied long
input bool Inp_HAf_Enabled_Motif_5 = true;   // Activer le motif 5 : Doji libellule / tombeau
input int  Inp_HAf_Poids_Motif_5   = 0;      // Poids : Doji libellule / tombeau

//--- Paramètres de détection des motifs
input double Inp_HAf_pct_big_body    = 0.7;   // Seuil pour grand corps (en % de la bougie)
input double Inp_HAf_pct_medium_body = 0.5;   // Seuil pour corps moyen
input double Inp_HAf_pct_doji_body   = 0.1;   // Seuil pour considérer un doji

input double Inp_HAf_pct_tiny_wick   = 0.05;  // Seuil pour une très petite mèche
input double Inp_HAf_pct_small_wick  = 0.1;   // Seuil pour une mèche petite
input double Inp_HAf_pct_long_wick   = 0.4;   // Seuil pour une mèche longue

input int    Inp_HAf_dojibefore      = 1;     // Nombre de bougies précédentes pour valider un doji
input bool   Inp_HAf_auto_fullsize   = true;  // Mode relatif (true) ou absolu (false)
input double Inp_HAf_fullsize_pts    = 0.0;   // Taille de référence en points si mode absolu

//--- inputs for Signal RSI fermeture
input string __SIGNAL_RSIF__ = "-------------Signal RSI cloture de positions--------------";
input bool                Inp_RSIF_Active = false;               // Ce signal est-il à prendre en compte ?
input ENUM_TIMEFRAMES     Inp_Timeframe_RSIf = PERIOD_M5;       // Temporalité du signal RSI fermeture
input int                 Inp_Periode_RSIf    = 14;              // Nombre de périodes pour le calcul du RSI
input ENUM_APPLIED_PRICE  Inp_Appliedf        = PRICE_WEIGHTED; // Prix utilisé pour calcul du RSI
input double              Inp_SeuilRSI_Sur_Venduf  = 35.0;       // Seuil en-dessous duquel le marché est considéré survendu
input double              Inp_SeuilRSI_Sur_Achetef = 65.0;       // Seuil en-dessus duquel le marché est considéré suracheté
//--- Configuration des motifs du signal RSI fermeture
input bool Inp_RSIF_Enabled_Motif_0 = true;   // Activer le motif 0 : L'oscillateur a la direction requise
input int  Inp_RSIF_Poids_Motif_0   = 0;      // Poids motif 0
input bool Inp_RSIF_Enabled_Motif_1 = true;   // Activer le motif 1 : Renversement derrière le niveau de surachat/survente
input int  Inp_RSIF_Poids_Motif_1   = 100;    // Poids motif 1
input bool Inp_RSIF_Enabled_Motif_2 = true;   // Activer le motif 2 : Swing échoué
input int  Inp_RSIF_Poids_Motif_2   = 0;      // Poids motif 2
input bool Inp_RSIF_Enabled_Motif_3 = true;   // Activer le motif 3 : Divergence Prix-RSI
input int  Inp_RSIF_Poids_Motif_3   = 100;    // Poids motif 3
input bool Inp_RSIF_Enabled_Motif_4 = true;   // Activer le motif 4 : Double divergence Prix-RSI
input int  Inp_RSIF_Poids_Motif_4   = 0;      // Poids motif 4
input bool Inp_RSIF_Enabled_Motif_5 = true;   // Activer le motif 5 : Motif Tête/épaules
input int  Inp_RSIF_Poids_Motif_5   = 0;      // Poids motif 5

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
   CUtilsLTR::CJournal::Log("Démarrage de l’EA ExpertRSI-HA-FixedPips");
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

//--- Création des filtres Heiken Ashi (3 pour open, 1 pour close)

//--- Signal HA1 - Prise de position
   CSignalBuilder::BuildAndAddFilter(signal_open,
                                     CSignalConfigFactory::CreateHAConfig(Inp_Timeframe_HA1,
                                           Inp_HA1_Poids_Motif_0, Inp_HA1_Poids_Motif_1, Inp_HA1_Poids_Motif_2, Inp_HA1_Poids_Motif_3, Inp_HA1_Poids_Motif_4, Inp_HA1_Poids_Motif_5,
                                           Inp_HA1_Enabled_Motif_0, Inp_HA1_Enabled_Motif_1, Inp_HA1_Enabled_Motif_2, Inp_HA1_Enabled_Motif_3, Inp_HA1_Enabled_Motif_4, Inp_HA1_Enabled_Motif_5,
                                           Inp_HA1_pct_big_body, Inp_HA1_pct_medium_body, Inp_HA1_pct_doji_body,
                                           Inp_HA1_pct_tiny_wick, Inp_HA1_pct_small_wick, Inp_HA1_pct_long_wick,
                                           Inp_HA1_dojibefore, Inp_HA1_auto_fullsize, Inp_HA1_fullsize_pts),
                                     Inp_HA1_Active);

//--- Signal HA2 - Prise de position
   CSignalBuilder::BuildAndAddFilter(signal_open,
                                     CSignalConfigFactory::CreateHAConfig(Inp_Timeframe_HA2,
                                           Inp_HA2_Poids_Motif_0, Inp_HA2_Poids_Motif_1, Inp_HA2_Poids_Motif_2, Inp_HA2_Poids_Motif_3, Inp_HA2_Poids_Motif_4, Inp_HA2_Poids_Motif_5,
                                           Inp_HA2_Enabled_Motif_0, Inp_HA2_Enabled_Motif_1, Inp_HA2_Enabled_Motif_2, Inp_HA2_Enabled_Motif_3, Inp_HA2_Enabled_Motif_4, Inp_HA2_Enabled_Motif_5,
                                           Inp_HA2_pct_big_body, Inp_HA2_pct_medium_body, Inp_HA2_pct_doji_body,
                                           Inp_HA2_pct_tiny_wick, Inp_HA2_pct_small_wick, Inp_HA2_pct_long_wick,
                                           Inp_HA2_dojibefore, Inp_HA2_auto_fullsize, Inp_HA2_fullsize_pts),
                                     Inp_HA2_Active);


//--- Signal HA3 - Prise de position
   CSignalBuilder::BuildAndAddFilter(signal_open,
                                     CSignalConfigFactory::CreateHAConfig(Inp_Timeframe_HA3,
                                           Inp_HA3_Poids_Motif_0, Inp_HA3_Poids_Motif_1, Inp_HA3_Poids_Motif_2, Inp_HA3_Poids_Motif_3, Inp_HA3_Poids_Motif_4, Inp_HA3_Poids_Motif_5,
                                           Inp_HA3_Enabled_Motif_0, Inp_HA3_Enabled_Motif_1, Inp_HA3_Enabled_Motif_2, Inp_HA3_Enabled_Motif_3, Inp_HA3_Enabled_Motif_4, Inp_HA3_Enabled_Motif_5,
                                           Inp_HA3_pct_big_body, Inp_HA3_pct_medium_body, Inp_HA3_pct_doji_body,
                                           Inp_HA3_pct_tiny_wick, Inp_HA3_pct_small_wick, Inp_HA3_pct_long_wick,
                                           Inp_HA3_dojibefore, Inp_HA3_auto_fullsize, Inp_HA3_fullsize_pts),
                                     Inp_HA3_Active);


//--- Signal HA4 - Clôture de position
   CSignalBuilder::BuildAndAddFilter(signal_close,
                                     CSignalConfigFactory::CreateHAConfig(Inp_Timeframe_HAf,
                                           Inp_HAf_Poids_Motif_0, Inp_HAf_Poids_Motif_1, Inp_HAf_Poids_Motif_2, Inp_HAf_Poids_Motif_3, Inp_HAf_Poids_Motif_4, Inp_HAf_Poids_Motif_5,
                                           Inp_HAf_Enabled_Motif_0, Inp_HAf_Enabled_Motif_1, Inp_HAf_Enabled_Motif_2, Inp_HAf_Enabled_Motif_3, Inp_HAf_Enabled_Motif_4, Inp_HAf_Enabled_Motif_5,
                                           Inp_HAf_pct_big_body, Inp_HAf_pct_medium_body, Inp_HAf_pct_doji_body,
                                           Inp_HAf_pct_tiny_wick, Inp_HAf_pct_small_wick, Inp_HAf_pct_long_wick,
                                           Inp_HAf_dojibefore, Inp_HAf_auto_fullsize, Inp_HAf_fullsize_pts),
                                     Inp_HAf_Active);

//--- Filtres RSI
   CSignalBuilder::BuildAndAddFilter(signal_open,
                                     CSignalConfigFactory::CreateRSIConfig(Inp_Timeframe_RSI,
                                           Inp_RSIO_Poids_Motif_0, Inp_RSIO_Poids_Motif_1,
                                           Inp_RSIO_Poids_Motif_2, Inp_RSIO_Poids_Motif_3,
                                           Inp_RSIO_Poids_Motif_4, Inp_RSIO_Poids_Motif_5,
                                           Inp_RSIO_Enabled_Motif_0, Inp_RSIO_Enabled_Motif_1,
                                           Inp_RSIO_Enabled_Motif_2, Inp_RSIO_Enabled_Motif_3,
                                           Inp_RSIO_Enabled_Motif_4, Inp_RSIO_Enabled_Motif_5,
                                           Inp_Periode_RSI,
                                           Inp_Applied,
                                           Inp_SeuilRSI_Sur_Achete,
                                           Inp_SeuilRSI_Sur_Vendu),
                                     Inp_RSIO_Active);

   CSignalBuilder::BuildAndAddFilter(signal_close,
                                     CSignalConfigFactory::CreateRSIConfig(Inp_Timeframe_RSIf,
                                           Inp_RSIF_Poids_Motif_0, Inp_RSIF_Poids_Motif_1,
                                           Inp_RSIF_Poids_Motif_2, Inp_RSIF_Poids_Motif_3,
                                           Inp_RSIF_Poids_Motif_4, Inp_RSIF_Poids_Motif_5,
                                           Inp_RSIF_Enabled_Motif_0, Inp_RSIF_Enabled_Motif_1,
                                           Inp_RSIF_Enabled_Motif_2, Inp_RSIF_Enabled_Motif_3,
                                           Inp_RSIF_Enabled_Motif_4, Inp_RSIF_Enabled_Motif_5,
                                           Inp_Periode_RSIf,
                                           Inp_Appliedf,
                                           Inp_SeuilRSI_Sur_Achetef,
                                           Inp_SeuilRSI_Sur_Venduf),
                                     Inp_RSIF_Active);

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

//--- Période minimale des signaux
   if(!ExtExpert.Period(MathMin(signal_open.SignalMinPeriod(),signal_close.SignalMinPeriod())))
     {
      printf(__FUNCTION__+": error setting expert period");
      ExtExpert.Deinit();
      return(-12);
     }
   else
      printf(__FUNCTION__+": ok setting expert period : %i", MathMin(signal_open.SignalMinPeriod(),signal_close.SignalMinPeriod()));

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
   CUtilsLTR::CJournal::Close();
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
