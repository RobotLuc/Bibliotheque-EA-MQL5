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
// * v1.8 - 24/11/2024 Cliquet SL réécrit                                                                                           
// * v1.9 - 26/11/2024 Debuggage de la fonction HAComposite                                                                         |
// * v1.9.1 - 26/11/2024 transformé en outil de debuggage                                                                           |
// * v1.9.2 - 27/11/2024 transformé en outil de debuggage pas terminé (préparation pour version 1.9.3 très simplifiée               |
//+---------------------------------------------------------------------------------------------------------------------------------+
#property copyright "Copyright 2024, Lucas Troncy - David Lhoyer"
#property version   "1.9"

//--- Appel aux fonctions exterieures
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

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

// Journalisation
int fileHandle = INVALID_HANDLE; // Handle global du fichier
string fileName = "journal_personnalise.txt"; // Nom du fichier

//+------------------------------------------------------------------+
//| Déclaration et initialisation des variables d'input utilisateur  |
//+------------------------------------------------------------------+

//--- Expert ID
input long InpMagicNumber=100100;   // Numéro magique de l'Expert Advisor, fixé à 100100 arbitrairement

//--- Paramètres d'heures de marché et de marché
input int InpHeureDebut=8;                   // Heure de début de trading en GMT
input int InpHeureFin=16;                    // Heure de fin de trading en GMT

//--- Paramètres d'entrée RSI
input int  InpPeriodRSI     =14;                      // Période moyenne du RSI
input ENUM_APPLIED_PRICE InpPriceRSI=PRICE_WEIGHTED;  // RSI appliqué au prix pondéré
input ENUM_TIMEFRAMES InpUT_RSI = PERIOD_M15;         // Période du RSI, réglée sur M15 par défaut

//--- Paramètres d'entrée DMI
input int  InpPeriodDMI     =14;                      // Période moyenne du DMI
input ENUM_TIMEFRAMES InpUT_DMI = PERIOD_M2;          // Période du DMI, réglée sur M2 par défaut

//--- Paramètres d'entrée Heiken Ashi
input ENUM_TIMEFRAMES InpUT_HA_Long = PERIOD_H4;   // Période Heiken Ashi la plus longue
input ENUM_TIMEFRAMES InpUT_HA_Moyen = PERIOD_M15; // Période Heiken Ashi intermédiaire
input ENUM_TIMEFRAMES InpUT_HA_Court = PERIOD_M2;  // Période Heiken Ashi la plus courte

input double   InpTaille_HAlong = 2000; // Taille du corps de bougie sur UT long en points
input double   InpTaille_HAmoyen = 1000; // Taille du corps de bougie sur UT moyen en points
input double   InpTaille_HAcourt = 1000;  // Taille du corps de bougie sur UT court en points

//--- Initialisation des pointeurs d'indicateurs
int    ExtIndicatorHandleRSI=INVALID_HANDLE;  // Pointeur de l'indicateur RSI
int    ExtIndicatorHandleDMI=INVALID_HANDLE;  // Pointeur de l'indicateur DMI
int    ExtHandHeikenAshiUTL=INVALID_HANDLE;  // Pointeur de l'indicateur Heiken Ashi UT Long
int    ExtHandHeikenAshiUTC=INVALID_HANDLE;  // Pointeur de l'indicateur Heiken Ashi UT court
int    ExtHandHeikenAshiUTM=INVALID_HANDLE;  // Pointeur de l'indicateur Heiken Ashi UT moyen

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//+------------------------------------------------------------------+
//| Fonction d'initialisation de l'Expert Advisor                     |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Définition des paramètres pour l'objet CTrade
   ExtTrade.SetExpertMagicNumber(InpMagicNumber); // Numéro magique de l'Expert Advisor
   ExtTrade.LogLevel(LOG_LEVEL_ERRORS);           // Niveau de logging

//--- Initialisation des indicateurs : DMI, RSI, Heiken Ashi et moyenne mobile
   ExtIndicatorHandleRSI=iRSI(_Symbol, InpUT_RSI, InpPeriodRSI, InpPriceRSI);
   ExtIndicatorHandleDMI=iADX(_Symbol, InpUT_DMI, InpPeriodDMI);
   ExtHandHeikenAshiUTL=iCustom(_Symbol,InpUT_HA_Long,"\\Indicators\\Examples\\Heiken_Ashi");
   ExtHandHeikenAshiUTM=iCustom(_Symbol,InpUT_HA_Moyen,"\\Indicators\\Examples\\Heiken_Ashi");
   ExtHandHeikenAshiUTC=iCustom(_Symbol,InpUT_HA_Court,"\\Indicators\\Examples\\Heiken_Ashi");

// Vérifier toutes les initialisations dans un bloc conditionnel unique
   if(!(InpUT_HA_Long > InpUT_HA_Moyen && InpUT_HA_Moyen > InpUT_HA_Court) ||
      ExtIndicatorHandleRSI == INVALID_HANDLE ||
      ExtIndicatorHandleDMI == INVALID_HANDLE ||
      ExtHandHeikenAshiUTL == INVALID_HANDLE ||
      ExtHandHeikenAshiUTM == INVALID_HANDLE ||
      ExtHandHeikenAshiUTC == INVALID_HANDLE
      )
     {

      // Afficher un message d'erreur spécifique pour chaque initialisation échouée
      if(!(InpUT_HA_Long > InpUT_HA_Moyen && InpUT_HA_Moyen > InpUT_HA_Court))
        {
         Print("Erreur: Input_HA_Long, Moyen et Court doivent être cohérents. Arrêt de l'EA.");
        }
      if(ExtIndicatorHandleRSI == INVALID_HANDLE)
        {
         Print("Erreur à la création de l'indicateur RSI");
        }
      if(ExtIndicatorHandleDMI == INVALID_HANDLE)
        {
         Print("Erreur à la création de l'indicateur DMI");
        }
      if(ExtHandHeikenAshiUTL == INVALID_HANDLE || ExtHandHeikenAshiUTM == INVALID_HANDLE || ExtHandHeikenAshiUTC == INVALID_HANDLE)
        {
         Print("Erreur à la création de l'indicateur Heiken Ashi");
        }
      ExpertRemove(); // Supprimer l'Expert Advisor
      return INIT_FAILED; // Retourner un statut d'échec
     }
//+------------------------------------------------------------------+
//| Initialisation des variables globales                            |
//+------------------------------------------------------------------+
   g_IND_POSITION =IND_POSITION::P_NOT;  // Initialisation : pas de position pour démarrer
   g_IND_ENTREE =IND_ENTREE::E_NOT;    // Initialisation : pas de signal d'entrée
   g_next_check_time = TimeCurrent(); // Variable statique locale qui définit la prochaine heure d'exécution des détections de motif

//+------------------------------------------------------------------+
//| Journalisation                                                   |
//+------------------------------------------------------------------+
// Supprimer et recréer le fichier en écrasant le contenu existant
   fileHandle = FileOpen(fileName, FILE_WRITE | FILE_TXT);
   if(fileHandle == INVALID_HANDLE)
     {
      PrintFormat("Erreur : Impossible d'ouvrir ou de créer le fichier '%s'. Code d'erreur : %d", fileName, GetLastError());
      return INIT_FAILED;
     }
   else
     {
      Print("Fichier de log recréé avec succès.");
     }

// Fermer immédiatement pour permettre un mode append dans les autres fonctions si nécessaire
   FileClose(fileHandle);

// Réouvrir le fichier en mode append (ajout de texte) si vous souhaitez continuer à écrire
   fileHandle = FileOpen(fileName, FILE_WRITE | FILE_TXT | FILE_READ);
   if(fileHandle == INVALID_HANDLE)
     {
      PrintFormat("Erreur : Impossible de réouvrir le fichier '%s' pour l'écriture en mode append. Code d'erreur : %d", fileName, GetLastError());
      return INIT_FAILED;
     }
   else
     {
      Print("Fichier de log prêt pour ajout de données.");
     }

   // Récupération du symbole négocié
   string symbol = Symbol();

   // Log du symbole
   LogToDesktop(StringFormat("L'expert est attaché au symbole : %s", symbol));

// Fin de l'initialisation
   return(INIT_SUCCEEDED);
  }
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//+------------------------------------------------------------------+
//| Fonction de désinitialisation de l'Expert Advisor                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
// Libérer les pointeurs des indicateurs
   IndicatorRelease(ExtIndicatorHandleRSI);
   IndicatorRelease(ExtIndicatorHandleDMI);
   IndicatorRelease(ExtHandHeikenAshiUTL);
   IndicatorRelease(ExtHandHeikenAshiUTM);
   IndicatorRelease(ExtHandHeikenAshiUTC);

   if(fileHandle != INVALID_HANDLE)
     {
      FileClose(fileHandle);
      Print("Fichier de log fermé avec succès.");
     }
  }
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//+------------------------------------------------------------------+
//| Fonction de tick de l'Expert Advisor                               |
//+------------------------------------------------------------------+
void OnTick()
  {
    if(TimeCurrent() < g_next_check_time)
     {
      return;
     }
   testEntree();
  }
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//---------------------------------------------------------------------
// FONCTIONS ANNEXES
//---------------------------------------------------------------------

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

// Vérifier la condition RSI : si tendance haussière, il faut RSI >= 50 ; sinon, il faut RSI <= 50
	if ((tendanceLTHaussiere) ? (RSI(0) >= 50) : (RSI(0) <= 50))
		{
			int haConditionMedium = HAComposite(ExtHandHeikenAshiUTM, InpTaille_HAmoyen);// Récupérer les valeurs Heiken Ashi moyen terme

			// Vérifier les conditions pour la bougie moyen terme
			if(haConditionMedium == (tendanceLTHaussiere ? 1 : -1)) // Si tendanceLTHaussiere est vrai (long) alors le premier test est vrai si haCondtionMedium est égal à 1
				{
					int haConditionShort = HAComposite(ExtHandHeikenAshiUTC, InpTaille_HAcourt); // on calcule la valeur de la bougie CT
					if(haConditionShort == (tendanceLTHaussiere ? 1 : -1) && DMI() == (tendanceLTHaussiere ? 1 : -1))
						{	
							g_IND_ENTREE = tendanceLTHaussiere ? E_LONG : E_SHORT;  // Mettre à jour l'indicateur d'entrée : E_LONG si bleu, E_SHORT si rouge
							string logMessage = StringFormat("Entrée sur marché. Tendance princ. : %s, Ind. MT : %s, RSI : %.2f, Ind. CT : %s, DMI : %s",
							                                tendanceLTHaussiere ? "Haussier" : "Baissier",
							                                (haConditionMedium==0) ? "plat" : ((haConditionMedium==1) ?"haussier" : "baissier"),
							                                RSI(0),
							                                (haConditionShort==0) ? "plat" : ((haConditionShort==1) ?"haussier" : "baissier"),
							                                (DMI()==0) ? "NOK" : "OK");
							LogToDesktop(logMessage);
							return true;  // Autoriser l'entrée en position
						}
					else 
						{ 
							g_IND_ENTREE = E_NOT; // Bien mettre à jour l'indicateur d'entrée négatif
							CalculateNextBarTime(g_next_check_time, InpUT_HA_Court); // mettre à jour le calcul de la prochaine barre, sur UT court terme
							LogToDesktop(StringFormat("Prochain check : %s | Pas d'entrée | Tendance principale : %s | RSI : %.2f | Ind. MT : %s | Ind CT : %s | DMI : %s", 
								TimeToString(g_next_check_time, TIME_MINUTES | TIME_SECONDS), 
								tendanceLTHaussiere ? "Haussier" : "Baissier", RSI(0),
								(haConditionMedium==0) ? "plat" : ((haConditionMedium==1) ?"haussier" : "baissier"),
								(haConditionShort==0) ? "plat" : ((haConditionShort==1) ?"haussier" : "baissier"),(DMI()==0) ? "NOK" : "OK"
								));
							return false;  // Conditions non remplies pour l'entrée	court terme
						}
				} 
			else 
				{
					g_IND_ENTREE = E_NOT;
					CalculateNextBarTime(g_next_check_time, InpUT_HA_Moyen);
					LogToDesktop(StringFormat("Prochain check : %s | Pas d'entrée | Tendance principale : %s | RSI : %.2f | Ind. MT : %s", 
								TimeToString(g_next_check_time, TIME_MINUTES | TIME_SECONDS), 
								tendanceLTHaussiere ? "Haussier" : "Baissier", RSI(0),
								(haConditionMedium==0) ? "plat" : ((haConditionMedium==1) ?"haussier" : "baissier")
								));					
					return false;  // Conditions non remplies pour l'entrée moyen terme
				}
		}
	else 
		{ 
			g_IND_ENTREE = E_NOT; // Bien mettre à jour l'indicateur d'entrée négatif
			CalculateNextBarTime(g_next_check_time, InpUT_HA_Moyen); // mettre à jour le calcul de la prochaine barre, sur UT moyen terme
			LogToDesktop(StringFormat("Prochain check : %s | Pas d'entrée | Tendance principale : %s | RSI : %.2f", 
						TimeToString(g_next_check_time, TIME_MINUTES | TIME_SECONDS), 
						tendanceLTHaussiere ? "Haussier" : "Baissier", RSI(0)));
			return false;  // Conditions non remplies pour l'entrée	moyen terme
		}
  }

//+------------------------------------------------------------------+
//| Fonction pour calculer le temps d'ouverture de la prochaine barre |
//+------------------------------------------------------------------+
void CalculateNextBarTime(datetime &next_check_time, ENUM_TIMEFRAMES timeframe)
  {
// Valider le timeframe (en supposant que PeriodSeconds retourne 0 pour des timeframes invalides)
   int period_seconds = PeriodSeconds(timeframe);
   if(period_seconds <= 0)
     {
      Print("Timeframe invalide passé à CalculateNextBarTime");
      return;
     }
// Utiliser TimeTradeServer pour une meilleure précision en cas de délai entre les ticks
   datetime current_time = TimeTradeServer();

// Aligner le temps actuel au début de la bougie actuelle
   datetime next_bar_open = current_time - (current_time % period_seconds);

// Calculer le temps d'ouverture de la prochaine bougie
   next_bar_open += period_seconds;

// Mettre à jour le temps de vérification suivant
   next_check_time = next_bar_open;
  }

//+------------------------------------------------------------------+
//| Journalisation                                                   |
//+------------------------------------------------------------------+
void LogToDesktop(const string &logMessage)
  {
   if(fileHandle == INVALID_HANDLE)
     {
      Print("Erreur : Le fichier de log n'est pas ouvert.");
      return;
     }

// Obtenir l'heure actuelle
   datetime currentTime = TimeCurrent();
   string timestamp = TimeToString(currentTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS);

// Écrire le message de log avec un horodatage
   FileWrite(fileHandle, "[" + timestamp + "] " + logMessage);

// Optionnel : Forcer l'écriture si nécessaire (peut impacter légèrement les performances)
   FileFlush(fileHandle);
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

// Récupérer la propriété de couleur Heiken Ashi
   if(CopyBuffer(handleHA, 4, 0, 1, HA_couleur) < 0)
     {
      PrintFormat("Erreur lors de la récupération des valeurs de couleur Heiken Ashi, code %d", GetLastError());
      return -1;  // Indiquer une erreur
     }  
     
   // Retourner 1 si DodgerBlue (index 0), 0 si Red (index 1)
   return (HA_couleur[0] == 0.0) ? 1 : 0;
  }

int HAComposite(int handleHA, double parametreTaille)
{
   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);  
   double HA_ouverture[1], HA_haut[1], HA_bas[1], HA_fermeture[1], HA_couleur[1];

   if (point == 0)
   {
      Print("Erreur : impossible de récupérer la valeur du point !");
      return -3;
   }

   if (handleHA < 0)
   {
      Print("Erreur : handleHA invalide !");
      return -4;
   }

   // Récupérer les buffers
   if (CopyBuffer(handleHA, 0, 0, 1, HA_ouverture) < 0)
   {
      PrintFormat("Erreur CopyBuffer pour HA_ouverture, code : %d", GetLastError());
      return -2;
   }
   if (CopyBuffer(handleHA, 1, 0, 1, HA_haut) < 0)
   {
      PrintFormat("Erreur CopyBuffer pour HA_haut, code : %d", GetLastError());
      return -2;
   }
   if (CopyBuffer(handleHA, 2, 0, 1, HA_bas) < 0)
   {
      PrintFormat("Erreur CopyBuffer pour HA_bas, code : %d", GetLastError());
      return -2;
   }
   if (CopyBuffer(handleHA, 3, 0, 1, HA_fermeture) < 0)
   {
      PrintFormat("Erreur CopyBuffer pour HA_fermeture, code : %d", GetLastError());
      return -2;
   }
   if (CopyBuffer(handleHA, 4, 0, 1, HA_couleur) < 0)
   {
      PrintFormat("Erreur CopyBuffer pour HA_couleur, code : %d", GetLastError());
      return -2;
   }

   // Vérification des valeurs
   LogToDesktop(StringFormat("HA_ouverture: %f, HA_haut: %f, HA_bas: %f, HA_fermeture: %f, HA_couleur: %f",
               HA_ouverture[0], HA_haut[0], HA_bas[0], HA_fermeture[0], HA_couleur[0]));

   // Logique de décision
   int couleur = (int)HA_couleur[0]; // Conversion explicite
   if (couleur == 0 && ((HA_ouverture[0] - HA_bas[0]) == 0) &&
       (HA_fermeture[0] - HA_ouverture[0]) >= parametreTaille * point)
   {
      return 1;  // Bougie bleue, grand corps, cul plat
   }
   else if (couleur == 1 && ((HA_haut[0] - HA_ouverture[0]) == 0) &&
            (HA_ouverture[0] - HA_fermeture[0]) >= parametreTaille * point)
   {
      return -1;  // Bougie rouge, grand corps, cul plat
   }

   return 0;  // Aucun motif valide
}


// Fonction pour récupérer la valeur RSI à un index spécifié
double RSI(int index)
  {
   double indicator_RSI_values[1];
   if(CopyBuffer(ExtIndicatorHandleRSI, 0, index, 1, indicator_RSI_values) < 0)
     {
      PrintFormat("Erreur lors de la récupération des valeurs RSI, code %d", GetLastError());
      return EMPTY_VALUE;  // Retourner EMPTY_VALUE en cas d'erreur
     }
   return indicator_RSI_values[0];  // Retourner la valeur RSI
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
   int copiedPlus = CopyBuffer(ExtIndicatorHandleDMI, 1, 0, 4, indicator_DMI_values_plus);
   int copiedMinus = CopyBuffer(ExtIndicatorHandleDMI, 2, 0, 4, indicator_DMI_values_moins);

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