//+---------------------------------------------------------------------------------------------------------------------------------+
// Squelette de Robot de trading générique                                                                                          |                                                                                                              |
//Notes de version :                                                                                                                |
// * Basé sur DavidLucas-v1.0                                                                                                       |
// * v0.0 - 13/09/2024 - reprise du travail sur le robot                                                                            |
// * v1.0 - 29/09/24 mise en place du squelette d'algorithme complet                                                                |
// * v1.1 - 09/10/2024 modifications sur la logique d'entrée et le calcul de la prochaine heure de test                             |
// * v1.2 - 23/10/2024 ajout de la logique de sortie de marché                                                                      |
// * v1.3 - 28/10/2024 relecture avec David logique TP et SL                                                                        |
// * v1.4 - 23/11/2024 ajout de la logique d'achat                                                                                  |
// * v1.5 - 23/11/2024 modification de la fonction de passage d'ordre avec cette fois 3 TP différents, 1 pour chaque ordre          |
// * v1.6 - 23/11/2024 fonction PlacerOrdre() corrigée car ne prenait pas le numéro des tickets                                     |
// * v1.7 - 24/11/2024 journalisation simplifiée, correction erreur dans cliquet SL                                                 |
// * v1.8 - 24/11/2024 Cliquet SL réécrit                                                                                           | 
// * v1.9 - 26/11/2024 Debuggage de la fonction HAComposite                                                                         |
// * v1.9.1 - 26/11/2024 transformé en outil de debuggage                                                                           |
// * v1.9.2 - 27/11/2024 transformé en outil de debuggage pas terminé (préparation pour version 1.9.3 très simplifiée               |
// * v1.9.3 - 27/11/2024 journal simple Heiken Ashi                                                                                 | 
// * v2.0 - 30/11/2024 Réécriture fonction entrée et correction indicateurs (buffer appelé) + seuil RSI modifié + erreur MM corrigée|
// * v2.1 - 30/11/2024 version sans journalisation pour David, ne pas utiliser                                                      |
// * v2.2 - 30/11/2024 Nouvel ordre paramètre                                                                                       |
// * EADL v1.0 - 03/12/2024 Début de découpe du fichier + possibilité d'éteindre le RSI + RSI par intervalle et non valeur unique   |
//+---------------------------------------------------------------------------------------------------------------------------------+
#property copyright "Copyright 2024, Lucas Troncy - David Lhoyer"
#property version   "1.0"

//--- Appel aux fonctions exterieures
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <EADL\biblio_utilDL.mqh>

//--- Objets. ExtTrade sera utilisé pour passer les ordres d'achat et de vente
CTrade      ExtTrade;
CSymbolInfo ExtSymbolInfo;

//+------------------------------------------------------------------+
//| Déclaration des variables gloables                               |
//+------------------------------------------------------------------+
// Les variables globales sont initialisées dans la fonction OnInit()

enum IND_POSITION
  {
   P_SHORT = -1,
   P_NOT = 0,
   P_LONG = 1
  };

enum IND_ENTREE
  {
   E_SHORT = -1,
   E_NOT = 0,
   E_LONG = 1
  };

int g_IND_POSITION;                    // Indicateur d'existence de position'
int g_IND_ENTREE;                      // Indicateur de signal d'entrée
datetime g_next_check_time;            // Variable statique locale qui définit la prochaine heure d'exécution des détections de motif
ulong tickets[];                       // Tableau pour stocker les numéros de tickets des lots possédés
uint tpMultipliers[3]= {1, 10, 10};    // Multiplicateurs pour différents take profits

//+------------------------------------------------------------------+
//| Déclaration des fonctions de gestion de position                 |
//+------------------------------------------------------------------+
// Ces fonctions doivent être déclarées ici car on va devoir déclarer un tableau de fonction pour gérer individuellement
// chaque position

// Définir un type pour une fonction retournant un bool
typedef bool (*ConditionSortieFunc)();

// Déclaration des prototypes de fonctions
bool ConditionSortie1();
bool ConditionSortie2();
bool ConditionSortie3();

// Déclaration du tableau de pointeurs vers des fonctions
ConditionSortieFunc tableauDeConditionsSortie[3];

//+------------------------------------------------------------------+
//| Déclaration et initialisation des variables d'input utilisateur  |
//+------------------------------------------------------------------+
input long InpMagicNumber=100100;                     // Numéro magique de l'Expert Advisor, fixé à 100100 arbitrairement
input int InpHeureDebut=8;                            // Heure de début de trading en GMT
input int InpHeureFin=16;                             // Heure de fin de trading en GMT
//input string SymboleATrader = "USDEUR";             // Symbole à trader
input double   InpTaille_HAlong = 100;                // Taille du corps de bougie sur UT long en points
input double   InpTaille_HAmoyen = 50;                // Taille du corps de bougie sur UT moyen en points
input double   InpTaille_HAcourt = 20;                // Taille du corps de bougie sur UT court en points
input bool InpUtiliserRSI = true;                     // Mettre vrai pour utiliser la condition RSI ou faux pour ne pas l'utiliser
input int  InpPeriodRSI     =14;                      // Nombre de prise de valeur pour calcul du RSI
input int InpMANbrPositions = 28;                     // Nombre de prise de valeurs pour calcul de la moyenne mobile
input ENUM_TIMEFRAMES InpMAPeriod = PERIOD_M15;       // Période de la moyenne mobile
input ENUM_APPLIED_PRICE InpPriceRSI=PRICE_WEIGHTED;  // RSI appliqué au prix pondéré
input ENUM_TIMEFRAMES InpUT_RSI = PERIOD_M15;         // Période du RSI, réglée sur M15 par défaut
input double InpRSISeuilLongMax = 60;                 // Valeur du RSI seuil pour prendre position longue, valeur maximale
input double InpRSISeuilLongMin = 52;                 // Valeur du RSI seuil pour prendre position longue, valeur minimale
input double InpRSISeuilShortMax = 48;                // Valeur du RSI seuil pour prendre position short, valeur maximale
input double InpRSISeuilShortMin = 25;                // Valeur du RSI seuil pour prendre position short, valeur minimale
input int  InpPeriodDMI     =14;                      // Nombre de valeurs pour calcul du DMI
input ENUM_TIMEFRAMES InpUT_HA_Long = PERIOD_H1;      // Période Heiken Ashi la plus longue                      
input ENUM_TIMEFRAMES InpUT_HA_Moyen = PERIOD_M15;    // Période Heiken Ashi intermédiaire
input ENUM_TIMEFRAMES InpUT_HA_Court = PERIOD_M2;     // Période Heiken Ashi la plus courte
input uint InpSL      =200;                           // Stop Loss en points
input uint InpTP      =300;                           // Take Profit en points
input uint InpSlippage=10;                            // Slippage en points
input double InpLot   =1;                             // Taille de lot
input uint InpCliquet = 200;                          // Cliquet : écart en points entre le cours et le SL qui déclenche la modification du SL
input uint InpPourcentCliquet = 20;                   // PourcentCliquet : pourcentage du Cliquet qui est ajouté au SL. Compris entre 0 et 100
input ENUM_TIMEFRAMES InpUT_DMI = PERIOD_M2;          // Période du DMI, réglée sur M2 par défaut

//--- Initialisation des pointeurs d'indicateurs
int    ExtIndicatorHandleRSI=INVALID_HANDLE;  // Pointeur de l'indicateur RSI
int    ExtIndicatorHandleDMI=INVALID_HANDLE;  // Pointeur de l'indicateur DMI
int    ExtHandHeikenAshiUTL=INVALID_HANDLE;  // Pointeur de l'indicateur Heiken Ashi UT Long
int    ExtHandHeikenAshiUTC=INVALID_HANDLE;  // Pointeur de l'indicateur Heiken Ashi UT court
int    ExtHandHeikenAshiUTM=INVALID_HANDLE;  // Pointeur de l'indicateur Heiken Ashi UT moyen
int    ExtmaHandle=INVALID_HANDLE;              // Pointeur de l'indicateur de moyenne mobile

//+------------------------------------------------------------------+
//| Fonction d'initialisation de l'Expert Advisor                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialisation de l'objet CTrade
   ExtTrade.SetDeviationInPoints(InpSlippage);    // Définir le slippage
   ExtTrade.SetExpertMagicNumber(InpMagicNumber); // Numéro magique de l'EA
   ExtTrade.LogLevel(LOG_LEVEL_ERRORS);           // Niveau de journalisation

   // Initialisation des indicateurs
   ExtIndicatorHandleRSI = iRSI(_Symbol, InpUT_RSI, InpPeriodRSI, InpPriceRSI);
   ExtIndicatorHandleDMI = iADX(_Symbol, InpUT_DMI, InpPeriodDMI);
   ExtHandHeikenAshiUTL  = iCustom(_Symbol, InpUT_HA_Long, "\\Indicators\\Examples\\Heiken_Ashi");
   ExtHandHeikenAshiUTM  = iCustom(_Symbol, InpUT_HA_Moyen, "\\Indicators\\Examples\\Heiken_Ashi");
   ExtHandHeikenAshiUTC  = iCustom(_Symbol, InpUT_HA_Court, "\\Indicators\\Examples\\Heiken_Ashi");
   ExtmaHandle           = iMA(_Symbol, InpMAPeriod, InpMANbrPositions, 0, MODE_SMA, PRICE_CLOSE);

   // Vérification des erreurs de configuration
   if (!ValiderConfiguration())
   {
      ExpertRemove(); // Supprime l'Expert Advisor en cas d'erreur
      return INIT_FAILED; // Indique une initialisation échouée
   }

   // Initialisation des variables globales
   g_IND_POSITION = IND_POSITION::P_NOT; // Pas de position au démarrage
   g_IND_ENTREE = IND_ENTREE::E_NOT;     // Pas de signal d'entrée
   g_next_check_time = TimeCurrent();    // Heure actuelle pour la prochaine vérification
   ArrayResize(tickets, 0);              // Initialisation explicite d'un tableau vide

   // Initialisation des conditions de sortie
   tableauDeConditionsSortie[0] = ConditionSortie1;
   tableauDeConditionsSortie[1] = ConditionSortie2;
   tableauDeConditionsSortie[2] = ConditionSortie3;

   // Initialisation de la bibliothèque utilitaire
   biblio_utilDL_Init();

   // Retourne un succès après une initialisation réussie
   return INIT_SUCCEEDED;
}


//+------------------------------------------------------------------+
//| Fonction de désinitialisation de l'Expert Advisor                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
// Libérer les pointeurs des indicateurs
   IndicatorRelease(ExtIndicatorHandleRSI);
   IndicatorRelease(ExtIndicatorHandleDMI);
   IndicatorRelease(ExtHandHeikenAshiUTL);
   IndicatorRelease(ExtHandHeikenAshiUTM);
   IndicatorRelease(ExtHandHeikenAshiUTC);
   IndicatorRelease(ExtmaHandle);

   biblio_utilDL_Deinit();
  }
  
//+------------------------------------------------------------------+
//| Fonction de validation de la configuration                      |
//+------------------------------------------------------------------+
bool ValiderConfiguration()
{
   // Vérifier la cohérence des périodes Heiken Ashi
   if (!(InpUT_HA_Long > InpUT_HA_Moyen && InpUT_HA_Moyen > InpUT_HA_Court))
   {
      Print("Erreur : Les périodes Heiken Ashi doivent être cohérentes (Long > Moyen > Court).");
      return false;
   }

   // Vérifier les handles des indicateurs
   if (ExtIndicatorHandleRSI == INVALID_HANDLE)
      Print("Erreur : Échec de la création de l'indicateur RSI.");
   if (ExtIndicatorHandleDMI == INVALID_HANDLE)
      Print("Erreur : Échec de la création de l'indicateur DMI.");
   if (ExtHandHeikenAshiUTL == INVALID_HANDLE || ExtHandHeikenAshiUTM == INVALID_HANDLE || ExtHandHeikenAshiUTC == INVALID_HANDLE)
      Print("Erreur : Échec de la création de l'indicateur Heiken Ashi.");
   if (ExtmaHandle == INVALID_HANDLE)
      Print("Erreur : Échec de la création de la moyenne mobile.");

   // Vérifier la limite du pourcentage cliquet
   if (InpPourcentCliquet > 100)
   {
      Print("Erreur : Le pourcentage cliquet doit être compris entre 0 et 100.");
      return false;
   }

   // Si toutes les vérifications sont réussies
   return ExtIndicatorHandleRSI != INVALID_HANDLE &&
          ExtIndicatorHandleDMI != INVALID_HANDLE &&
          ExtHandHeikenAshiUTL != INVALID_HANDLE &&
          ExtHandHeikenAshiUTM != INVALID_HANDLE &&
          ExtHandHeikenAshiUTC != INVALID_HANDLE &&
          ExtmaHandle != INVALID_HANDLE;
}
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////  
//+------------------------------------------------------------------+
//| Fonction OnTradeTransaction de l'Expert Advisor                  |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
    // Vérifier si la transaction correspond à un deal ajouté
    if (trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        // Extraire les informations pertinentes
        ulong dealTicket = trans.deal;               // Ticket du deal
        ulong orderTicket = trans.order;             // Ticket de l'ordre associé
        string symbol = trans.symbol;                // Symbole de trading
        double price = trans.price;                  // Prix de la transaction
        double volume = trans.volume;                // Volume échangé
        double sl = trans.price_sl;                  // Niveau Stop Loss
        double tp = trans.price_tp;                  // Niveau Take Profit
        ENUM_DEAL_TYPE dealType = trans.deal_type;   // Type du deal (achat, vente, etc.)

        // Déterminer le type de deal sous forme lisible
        string dealTypeStr = "Inconnu";
        switch (dealType)
        {
            case DEAL_TYPE_BUY:   dealTypeStr = "Achat"; break;
            case DEAL_TYPE_SELL:  dealTypeStr = "Vente"; break;
            case DEAL_TYPE_BALANCE: dealTypeStr = "Équilibrage"; break;
            case DEAL_TYPE_CREDIT: dealTypeStr = "Crédit"; break;
        }

        // Construire un message pour le journal
        string message = StringFormat(
            "Deal détecté : Symbol=%s, Type=%s, Price=%.5f, Volume=%.2f, SL=%.5f, TP=%.5f, DealTicket=%d, OrderTicket=%d",
            symbol, dealTypeStr, price, volume, sl, tp, dealTicket, orderTicket);

        // Enregistrer dans le journal via la fonction personnalisée
        LogToDesktop(message);
    }
}
 
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//+------------------------------------------------------------------+
//| Fonction de tick de l'Expert Advisor                               |
//+------------------------------------------------------------------+
void OnTick()
  {

   if(!IsMarketOpen(InpHeureDebut,InpHeureFin)) { return;}

   if(!(TimeCurrent() > g_next_check_time)) {return;}
   
   if(g_IND_POSITION == P_NOT)  // S'il n'y a pas de position ouverte, on teste si on a le signal pour entrer sur le marché
     {
      if(!testEntree() || !validationEntree())  // S'il n'y a pas de signal ou bien qu'il n'y a pas de confirmation, on arrête
        {
         return;
        }
      else
         if(PlacerOrdre())
           {
            return;
           }
     }
   else // S'il y a au moins une position ouverte, on teste pour savoir si on a une configuration de dénouement
     {
      CliquetStopLoss(); // Mettre à jour le SL
      AppelerConditionsSortie(); // Gérer les positions
      verifTickets(); // Vérifier s'il y a encore des tickets après l'appel des conditions de sortie et mettre à jour g_IND_POSITION le cas échéant
      LogToDesktop(StringFormat("Fin d'un cycle de robot | prochaine heure de test : %s", TimeToString(g_next_check_time, TIME_MINUTES | TIME_SECONDS)));
     }
  }

//+------------------------------------------------------------------+
//| Fonction test entrée                                             |
//+------------------------------------------------------------------+
// Fonction pour tester les conditions d'entrée pour le trading basées sur les indicateurs Heiken Ashi et RSI
bool testEntree()
  {  
// Récupérer la couleur de la bougie Heiken Ashi long terme
   int indLT= HAcouleur(ExtHandHeikenAshiUTL);
	if(indLT < 0)     // Gérer l'erreur potentielle de HAcouleur
		{
			LogToDesktop("Erreur lors de la récupération de la couleur Heiken Ashi");
			return false;
		}
// Définir la tendance long terme
	bool tendanceLTHaussiere = (indLT == 1); // 1 est pour une bougie bleue, 0 pour une rouge

// Vérifier la condition RSI : si tendance haussière, on teste le RSI sur les seuils de l'entrée Long, sinon sur les seuils de l'entrée Short
	if ((tendanceLTHaussiere) ? RSI(InpRSISeuilLongMin,InpRSISeuilLongMax) : RSI(InpRSISeuilShortMin,InpRSISeuilShortMax))
		{
			int haConditionMedium = HAComposite(ExtHandHeikenAshiUTM, InpTaille_HAmoyen);// Récupérer les valeurs Heiken Ashi moyen terme

			// Vérifier les conditions pour la bougie moyen terme
			if(haConditionMedium == (tendanceLTHaussiere ? 1 : -1)) // Si tendanceLTHaussiere est vrai (long) alors le premier test est vrai si haCondtionMedium est égal à 1
				{
					int haConditionShort = HAComposite(ExtHandHeikenAshiUTC, InpTaille_HAcourt); // on calcule la valeur de la bougie CT
					if(haConditionShort == (tendanceLTHaussiere ? 1 : -1))
						{	
							g_IND_ENTREE = tendanceLTHaussiere ? E_LONG : E_SHORT;  // Mettre à jour l'indicateur d'entrée : E_LONG si bleu, E_SHORT si rouge
							string logMessage = StringFormat("Entrée sur marché. Tendance princ. : %s, Ind. MT : %s, Ind. CT : %s, DMI : %s",
							                                tendanceLTHaussiere ? "Haussier" : "Baissier",
							                                (haConditionMedium==0) ? "plat" : ((haConditionMedium==1) ?"haussier" : "baissier"),
							                                (haConditionShort==0) ? "plat" : ((haConditionShort==1) ?"haussier" : "baissier"),
							                                (DMI()==0) ? "NOK" : "OK");
							//Print(logMessage);
							LogToDesktop(logMessage);
							return true;  // Autoriser l'entrée en position
						}
					else 
						{ 
							g_IND_ENTREE = E_NOT; // Bien mettre à jour l'indicateur d'entrée négatif
							CalculateNextBarTime(g_next_check_time, InpUT_HA_Court); // mettre à jour le calcul de la prochaine barre, sur UT court terme
							string logMessage = (StringFormat("Pas d'entrée | Tendance principale : %s | Ind. MT : %s | Ind CT : %s | DMI : %s", 
								tendanceLTHaussiere ? "Haussier" : "Baissier", 
								(haConditionMedium==0) ? "plat" : ((haConditionMedium==1) ?"haussier" : "baissier"),
								(haConditionShort==0) ? "plat" : ((haConditionShort==1) ?"haussier" : "baissier"),(DMI()==0) ? "NOK" : "OK"
								));
						   //Print(logMessage);
							LogToDesktop(logMessage);							
							return false;  // Conditions non remplies pour l'entrée	court terme
						}
				} 
			else 
				{
					g_IND_ENTREE = E_NOT;
					CalculateNextBarTime(g_next_check_time, InpUT_HA_Moyen);
					string logMessage = (StringFormat("Pas d'entrée | Tendance principale : %s | Ind. MT : %s", 
								tendanceLTHaussiere ? "Haussier" : "Baissier", 
								(haConditionMedium==0) ? "plat" : ((haConditionMedium==1) ?"haussier" : "baissier")
								));					
							//Print(logMessage);
							LogToDesktop(logMessage);					
					return false;  // Conditions non remplies pour l'entrée moyen terme
				}
		}
	else 
		{ 
			g_IND_ENTREE = E_NOT; // Bien mettre à jour l'indicateur d'entrée négatif
			CalculateNextBarTime(g_next_check_time, InpUT_HA_Moyen); // mettre à jour le calcul de la prochaine barre, sur UT moyen terme
			string logMessage = (StringFormat("Pas d'entrée | Tendance principale : %s",  
						tendanceLTHaussiere ? "Haussier" : "Baissier"));
			//Print(logMessage);
			LogToDesktop(logMessage);
			return false;  // Conditions non remplies pour l'entrée	moyen terme
		}
  }
//+------------------------------------------------------------------+
//| Fonction validation entrée                                       |
//+------------------------------------------------------------------+
bool validationEntree()
  {
// Mettre ici toutes les conditions de validation d'entrée qu'on veut
   return true;
  }
//+------------------------------------------------------------------+
//| Fonction à exécuter lorsque toutes les conditions sont remplies   |
//+------------------------------------------------------------------+
bool PlacerOrdre()
  {
   ExtSymbolInfo.Refresh();      // Rafraîchir les informations du symbole
   ExtSymbolInfo.RefreshRates(); // Rafraîchir les taux de marché

   ArrayResize(tickets, 0); // Réinitialiser le tableau des tickets

   double price = 0;      // Variable pour le prix d'achat ou de vente
   double stoploss = 0.0; // Variable pour le stop loss
   double takeprofit = 0.0; // Variable pour le take profit

   int digits = ExtSymbolInfo.Digits();     // Récupérer le nombre de décimales pour le symbole
   double point = ExtSymbolInfo.Point();    // Récupérer la valeur du point
   double spread = ExtSymbolInfo.Ask() - ExtSymbolInfo.Bid(); // Calculer l'écart entre le prix d'achat et le prix de vente

// Calculer les stop-loss et take-profits de base une seule fois
   if(g_IND_ENTREE == E_LONG)
     {
      price = NormalizeDouble(ExtSymbolInfo.Ask(), digits); // Prix d'achat normalisé
      //stoploss = 0;
      stoploss = NormalizeDouble(price - InpSL * point, digits); // Calculer le stop loss
     }
   else
      if(g_IND_ENTREE == E_SHORT)
        {
         price = NormalizeDouble(ExtSymbolInfo.Bid(), digits); // Prix de vente normalisé
         //stoploss = 0;
         stoploss = NormalizeDouble(price + InpSL * point, digits); // Calculer le stop loss
        }

// Placer les trois ordres avec des take-profits différents
   for(int i = 0; i < 3; i++)
     {
      bool success = false; // Indicateur de succès pour chaque ordre
      ulong ticket = 0;     // Variable pour stocker le ticket de l'ordre

      if(g_IND_ENTREE == E_LONG)  // Ordre LONG
        {
         takeprofit = NormalizeDouble(price + (InpTP * tpMultipliers[i]) * point, digits); // Take profit avec multiplicateur

         // Tenter d'acheter
         success = ExtTrade.Buy(InpLot, Symbol(), price, stoploss, takeprofit);

         if(success && ExtTrade.ResultRetcode() == TRADE_RETCODE_DONE)
           {
            ticket = ExtTrade.ResultOrder(); // Récupérer le ticket de l'ordre
           }
        }
      else
         if(g_IND_ENTREE == E_SHORT)  // Ordre SHORT
           {
            takeprofit = NormalizeDouble(price - (InpTP * tpMultipliers[i]) * point, digits); // Take profit avec multiplicateur

            // Tenter de vendre
            success = ExtTrade.Sell(InpLot, Symbol(), price, stoploss, takeprofit);

            if(success && ExtTrade.ResultRetcode() == TRADE_RETCODE_DONE)
              {
               ticket = ExtTrade.ResultOrder(); // Récupérer le ticket de l'ordre
              }
           }

      // Vérifier si l'ordre a échoué
      if(ticket == 0)
        {
         LogTradeError(g_IND_ENTREE == E_LONG ? "buy" : "sell", price, stoploss, takeprofit);
         return false; // Retourner false si une transaction échoue
        }

      // Ajouter le ticket au tableau
      ArrayResize(tickets, ArraySize(tickets) + 1);
      tickets[ArraySize(tickets) - 1] = ticket;
     }

// Mettre à jour l'indicateur de position
   g_IND_POSITION = (g_IND_ENTREE == E_LONG) ? P_LONG : P_SHORT;
   g_IND_ENTREE = E_NOT; // Réinitialiser l'indicateur d'entrée

// Log des tickets
   string output = "Ordre placé. Tickets : [";
   for(int i = 0; i < ArraySize(tickets); i++)
     {
      output += IntegerToString(tickets[i]); // Convertir chaque élément en chaîne
      if(i < ArraySize(tickets) - 1)
         output += ", "; // Ajouter une virgule entre les éléments
     }
   output += "] ";

   LogToDesktop(output);

   return true; // Retourner true si tous les ordres ont été placés avec succès
  }

//+------------------------------------------------------------------+
//| Fonction pour calculer le Stop Loss en fonction de la direction   |
//+------------------------------------------------------------------+
double CalculateStopLoss(double price, double spread, int digits, uint stopLossPoints, double point, bool isLong = true)
  {
   double stoploss = 0;
   if(stopLossPoints > 0)
     {
      if(spread >= stopLossPoints * point)
        {
         PrintFormat("StopLoss (%d points) <= spread actuel = %.0f points. Utilisation de la valeur du spread", stopLossPoints, spread / point);
         stoploss = NormalizeDouble(isLong ? price - spread : price + spread, digits);
        }
      else
        {
         stoploss = NormalizeDouble(isLong ? price - stopLossPoints * point : price + stopLossPoints * point, digits);
        }
     }
   return stoploss;
  }

//+------------------------------------------------------------------+
//| Fonction pour calculer le Take Profit en fonction de la direction |
//+------------------------------------------------------------------+
double CalculateTakeProfit(double price, double spread, int digits, uint takeProfitPoints, double point, bool isLong = true)
  {
   double takeprofit = 0;
   if(takeProfitPoints > 0)
     {
      if(spread >= takeProfitPoints * point)
        {
         PrintFormat("TakeProfit (%d points) < spread actuel = %.0f points. Utilisation de la valeur du spread", takeProfitPoints, spread / point);
         takeprofit = NormalizeDouble(isLong ? price + spread : price - spread, digits);
        }
      else
        {
         takeprofit = NormalizeDouble(isLong ? price + takeProfitPoints * point : price - takeProfitPoints * point, digits);
        }
     }
   return takeprofit;
  }

//+------------------------------------------------------------------+
//| Fonction pour enregistrer une erreur de trade                     |
//+------------------------------------------------------------------+
void LogTradeError(string type, double price, double stoploss, double takeprofit)
  {
   string logmessage = StringFormat("Échec de %s %s à %G (SL=%G TP=%G) échec. Prix actuel=%G erreur=%d",
                                    type, Symbol(), price, stoploss, takeprofit, (type == "buy" ? ExtSymbolInfo.Ask() : ExtSymbolInfo.Bid()), GetLastError());
   LogToDesktop(logmessage);
  }

//+------------------------------------------------------------------+
//| Fonction pour effet Cliquet sur le stop loss                     |
//+------------------------------------------------------------------+
void CliquetStopLoss()
  {
// Vérifier si le tableau tickets[] contient des positions
   if(ArraySize(tickets) == 0)
     {
      LogToDesktop("Le tableau tickets est vide.");
      return;
     }

   double currentPrice = SymbolInfoDouble(Symbol(), (g_IND_POSITION == P_LONG) ? SYMBOL_BID : SYMBOL_ASK); // Prix actuel en fonction de la position (long/short)
   double point = ExtSymbolInfo.Point(); // Taille d'un point pour le symbole
   int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS); // Nombre de décimales pour le symbole

// Parcourir chaque ticket dans le tableau tickets[]
   for(int i = 0; i < ArraySize(tickets); i++)
     {
      ulong ticket = tickets[i];

      // Vérifier si la position existe pour ce ticket
      if(!PositionSelectByTicket(ticket))
        {
         LogToDesktop(StringFormat("Cliquet : la position avec le ticket %d n'existe pas ou a déjà été clôturée.", ticket));
         continue; // Passer au ticket suivant si la position n'existe plus
        }

      double currentStopLoss = PositionGetDouble(POSITION_SL); // Stop loss actuel
      double ecart = (g_IND_POSITION == P_LONG)
                     ? currentPrice - currentStopLoss  // Écart pour une position longue
                     : currentStopLoss - currentPrice; // Écart pour une position courte

      // Vérifier si l'écart est suffisant pour modifier le stop loss
      if(ecart > InpCliquet * point)
        {
         double nouveauStopLoss = (g_IND_POSITION == P_LONG)
                                  ? currentStopLoss + (ecart * InpPourcentCliquet / 100)  // Nouveau stop loss pour une position longue
                                  : currentStopLoss - (ecart * InpPourcentCliquet / 100); // Nouveau stop loss pour une position courte

         // Normaliser le nouveau stop loss
         nouveauStopLoss = NormalizeDouble(nouveauStopLoss, digits);

         // Modifier le stop loss
         if(!ExtTrade.PositionModify(ticket, nouveauStopLoss, PositionGetDouble(POSITION_TP)))
           {
            LogToDesktop(StringFormat("Erreur lors de la modification du stop loss pour le ticket %d ", ticket));
           }
         else
           {
            LogToDesktop(StringFormat("Stop loss modifié pour le ticket %d, nouveau stop loss : %f", ticket, nouveauStopLoss));
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Fonction de vérification de l'existance de tickets               |
//+------------------------------------------------------------------+
void verifTickets()
  {
   if(!(PositionSelectByTicket(tickets[0]) || PositionSelectByTicket(tickets[1]) || PositionSelectByTicket(tickets[2])))
     {
      LogToDesktop("Plus aucun ticket");
      g_IND_POSITION = P_NOT;
     }
    else 
      {              
         CalculateNextBarTime(g_next_check_time,MinTimeframe(InpMAPeriod,InpUT_DMI,InpUT_RSI) );       
       }
  }
//+------------------------------------------------------------------+
//| Fonction de gestion des positions                                |
//+------------------------------------------------------------------+
// Fonction qui boucle sur le tableau contenant les fonctions de conditions de sortie et qui appelle chaque fonction
void AppelerConditionsSortie()
  {
   if(g_IND_POSITION == P_NOT)
     {
      return;
     }
// Boucle pour traiter chaque ticket et condition de sortie
   for(int i = 0; i < ArraySize(tableauDeConditionsSortie); i++)
     {
      // Vérifier si une position est associée au ticket courant
      if(PositionSelectByTicket(tickets[i]))
        {
         // Vérifier si la condition de sortie est remplie pour ce ticket
         if(tableauDeConditionsSortie[i]())
           {
            // Tentative de clôture de la position
            if(!ExtTrade.PositionClose(tickets[i]))
              {
               LogToDesktop(StringFormat("Appeler condition sortie | Erreur lors de la clôture de la position pour le ticket %d", tickets[i]));
              }
            else
              {
               string logMessage = StringFormat("Appeler condition sortie | Position avec le ticket %d clôturée avec succès.", tickets[i]);
               LogToDesktop(logMessage);
              }
           }
        }
      else
        {
         LogToDesktop(StringFormat("Appeler condition sortie | La position avec le ticket %d est déjà clôturée ou inexistante.", tickets[i]));
        }
     }
// Si aucune condition remplie, mettre à jour g_next_check_time.
  }
//+------------------------------------------------------------------+
//| Conditions de sortie                                             |
//+------------------------------------------------------------------+
bool ConditionSortie1()
  {
return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ConditionSortie2()
  {
// Cette condition de sortie est atteinte sur le deuxième ticket si le DMI change de tendance.
   if(((g_IND_POSITION == P_LONG) && DMI_Sortie() == -1) || ((g_IND_POSITION == P_SHORT) && DMI_Sortie() == 1))
     {
      string logMessage = StringFormat("Sortie Condition 2 | g_IND_POSITION : %d | DMI de sortie : %d", g_IND_POSITION, DMI_Sortie());
      LogToDesktop(logMessage);
      return true;
     }
   else
     {
      return false; // Retourner faux si la condition de sortie n'est pas atteinte
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ConditionSortie3()
  {
// Cette condition de sortie est atteinte sur le troisième ticket si la moyenne mobile croise le prix à la hausse ou la baisse
   if(((g_IND_POSITION == P_LONG) && CrossMovingAverage() == 1) || ((g_IND_POSITION == P_SHORT) && CrossMovingAverage() == -1))
     {
      string logMessage = StringFormat("Sortie Condition 3 | g_IND_POSITION : %d | Moyenne Mobile : %d", g_IND_POSITION, CrossMovingAverage());
      LogToDesktop(logMessage);
      return true;
     }
   else
     {
      return false; // Retourner faux si la condition de sortie n'est pas atteinte
     }
  }


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//---------------------------------------------------------------------
// INDICATEURS
//---------------------------------------------------------------------
// Fonction pour récupérer la couleur de la bougie Heiken Ashi
int HAcouleur(int handleHA)
  {
// Tableau pour stocker la propriété de couleur Heiken Ashi
   double HA_couleur[1];

//test
// est 2

// Récupérer la propriété de couleur Heiken Ashi
   if(CopyBuffer(handleHA, 4, 1, 1, HA_couleur) < 0)
     {
      PrintFormat("Erreur lors de la récupération des valeurs de couleur Heiken Ashi, code %d", GetLastError());
      return -1;  // Indiquer une erreur
     }  
     
   // Retourner 1 si DodgerBlue (index 0), 0 si Red (index 1)
   return (HA_couleur[0] == 0.0) ? 1 : 0;
  }

int HAComposite(int handleHA, double parametreTaille)
{
   double HA_couleur[1], HA_haut[1], HA_bas[1], HA_ouverture[1], HA_fermeture[1];
   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   
   if (point == 0)
   {
      Print("Erreur : impossible de récupérer la valeur du point !");
      return -3;
   }

   // Récupérer les propriétés Heiken Ashi
   if (CopyBuffer(handleHA, 0, 1, 1, HA_ouverture) < 0 ||
       CopyBuffer(handleHA, 1, 1, 1, HA_haut) < 0 ||
       CopyBuffer(handleHA, 2, 1, 1, HA_bas) < 0 ||
       CopyBuffer(handleHA, 3, 1, 1, HA_fermeture) < 0 ||
       CopyBuffer(handleHA, 4, 1, 1, HA_couleur) < 0)
   {
      PrintFormat("Erreur lors de la récupération des données Heiken Ashi, code : %d", GetLastError());
      return -2;
   }
   

   // Journalisation avancée
   //LogToDesktop(StringFormat("Fermeture : %f | Haut : %f | Ouverture : %f | Bas : %f | Couleur : %d | corps : %f | point : %f",                        
   //                           HA_fermeture[0], HA_haut[0], HA_ouverture[0], HA_bas[0], (HA_couleur[0] == 0 ? "bleue" : "rouge"),
   //                           (HA_couleur[0] ==0 ? HA_fermeture[0] - HA_ouverture[0] : -HA_fermeture[0] + HA_ouverture[0]),
   //                           point
   //                           ));
   // Logique de décision
   if (HA_couleur[0] == 0 && ((HA_ouverture[0] - HA_bas[0]) ==0) &&
       (HA_fermeture[0] - HA_ouverture[0]) >= parametreTaille * point)
   {
      return 1;  // Bougie bleue, grand corps, cul plat
   }
   else if (HA_couleur[0] == 1 && ((HA_haut[0] - HA_ouverture[0]) ==0) &&
            (HA_ouverture[0] - HA_fermeture[0]) >= parametreTaille * point)
   {
      return -1;  // Bougie rouge, grand corps, cul plat
   }

   return 0;  // Aucun motif valide
}


// Fonction pour vérifier si le RSI est dans une bande définie
bool RSI(double bandmin, double bandmax)
  {
   double indicator_RSI_values[1];
   if(CopyBuffer(ExtIndicatorHandleRSI, 0, 1, 1, indicator_RSI_values) < 0)
     {
      PrintFormat("Erreur lors de la récupération des valeurs RSI, code %d", GetLastError());
      return false;  // Retourner EMPTY_VALUE en cas d'erreur
     }
   if (!InpUtiliserRSI) {return true;};  
   LogToDesktop(StringFormat("Valeur du RSI au moment du test : %f",indicator_RSI_values[0]));
   if (indicator_RSI_values[0] >= bandmin && indicator_RSI_values[0] <= bandmax) { return true;};
   return false;
  }

// Fonction pour vérifier la tendance de l'indicateur Directional Movement Index (DMI)
int DMI()
  {
   double indicator_DMI_values_plus[4];
   double indicator_DMI_values_moins[4];

// Vérifier si l'indicateur DMI est valide
   if(ExtIndicatorHandleDMI == INVALID_HANDLE)
     {
      Print("Erreur : L'indicateur DMI n'est pas valide.");
      return -1000;  // Retourner -1000 en cas d'erreur d'indicateur
     }
// Récupérer les valeurs DMI pour les 4 dernières bougies
   int copiedPlus = CopyBuffer(ExtIndicatorHandleDMI, 1, 1, 4, indicator_DMI_values_plus);
   int copiedMinus = CopyBuffer(ExtIndicatorHandleDMI, 2, 1, 4, indicator_DMI_values_moins);

   if(copiedPlus < 0 || copiedMinus < 0)
     {
      PrintFormat("Erreur lors de la récupération des valeurs DMI, code %d", GetLastError());
      return -1000;  // Retourner -1000 si la récupération échoue
     }
// Vérification d'une tendance haussière :
// Les trois dernières bougies doivent indiquer un -DI supérieur à +DI,
// et la dernière bougie (indice 0) doit avoir un +DI supérieur à -DI
   if(indicator_DMI_values_plus[3] < indicator_DMI_values_moins[3] &&
      indicator_DMI_values_plus[2] < indicator_DMI_values_moins[2] &&
      indicator_DMI_values_plus[1] < indicator_DMI_values_moins[1])
     {
      // La dernière bougie (indice 0) confirme la tendance haussière
      if(indicator_DMI_values_plus[0] > indicator_DMI_values_moins[0])
        {
         return 1;  // Tendance haussière
        }
     }
// Vérification d'une tendance baissière :
// Les trois dernières bougies doivent indiquer un +DI supérieur à -DI,
// et la dernière bougie (indice 0) doit avoir un -DI supérieur à +DI
   if(indicator_DMI_values_plus[3] > indicator_DMI_values_moins[3] &&
      indicator_DMI_values_plus[2] > indicator_DMI_values_moins[2] &&
      indicator_DMI_values_plus[1] > indicator_DMI_values_moins[1])
     {
      // La dernière bougie (indice 0) confirme la tendance baissière
      if(indicator_DMI_values_plus[0] < indicator_DMI_values_moins[0])
        {
         return -1;  // Tendance baissière
        }
     }
// Absence de tendance clairement définie
   return 0;  // Absence de tendance
  }

// Fonction DMI_Sortie() qui vérifie la relation entre +DI et -DI sur la dernière bougie
int DMI_Sortie()
  {
   double indicator_DMI_values_plus[1];  // Tableau pour stocker les valeurs de +DI
   double indicator_DMI_values_moins[1]; // Tableau pour stocker les valeurs de -DI

// Vérifier si l'indicateur DMI est valide
   if(ExtIndicatorHandleDMI == INVALID_HANDLE)
     {
      Print("Erreur : L'indicateur DMI n'est pas valide.");
      return -1000;  // Retourner -1000 en cas d'erreur d'indicateur
     }

// Récupérer les valeurs DMI pour la dernière bougie (indice 0)
   int copiedPlus = CopyBuffer(ExtIndicatorHandleDMI, 1, 1, 1, indicator_DMI_values_plus);
   int copiedMinus = CopyBuffer(ExtIndicatorHandleDMI, 2, 1, 1, indicator_DMI_values_moins);

   if(copiedPlus < 0 || copiedMinus < 0)
     {
      PrintFormat("Erreur lors de la récupération des valeurs DMI, code %d", GetLastError());
      return -1000;  // Retourner -1000 si la récupération échoue
     }

// Vérifier la relation entre +DI et -DI sur la dernière bougie
   if(indicator_DMI_values_plus[0] > indicator_DMI_values_moins[0])
     {
      return 1;  // +DI > -DI
     }
   else
      if(indicator_DMI_values_plus[0] < indicator_DMI_values_moins[0])
        {
         return -1; // +DI < -DI
        }
      else
        {
         return 0;  // +DI == -DI
        }
  }

// Indicateur de croisement de moyenne mobile avec le cours
int CrossMovingAverage()
  {
// Variables pour stocker les valeurs
   double maValues[2];  // Moyenne mobile sur les 2 dernières bougies
   double currentPrice, previousPrice;
// Récupération des valeurs de la moyenne mobile
// Récupération des valeurs de la moyenne mobile
   if(CopyBuffer(ExtmaHandle, 0, 1, 2, maValues) < 0)
     {
      PrintFormat("Erreur lors de la récupération des valeurs de la moyenne mobile, code %d", GetLastError());
      return -1000;  // Retourner -1000 en cas d'erreur
     }

// Récupération des cours
   currentPrice = iClose(NULL, 0, 0);  // Cours actuel
   previousPrice = iClose(NULL, 0, 1); // Cours précédent

// Vérification des croisements
   if(maValues[1] < previousPrice && maValues[0] > currentPrice)
     {
      return 1;  // Croisement haussier
     }
   if(maValues[1] > previousPrice && maValues[0] < currentPrice)
     {
      return -1;  // Croisement baissier
     }

   return 0;  // Aucun croisement détecté
  }
//+------------------------------------------------------------------+
