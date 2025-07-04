//+------------------------------------------------------------------+
//|                                              CUtilsLTR.mqh       |
//|                         Utilitaires généraux pour EA MQL5       |
//|                                                                  |
//| Description :                                                    |
//|   - Fonctions statiques diverses (PGCD, bitmask, etc.)          |
//|   - Classe interne CJournal pour logging fichier                |
//+------------------------------------------------------------------+
#ifndef __CUTILSLTR_MQH__
#define __CUTILSLTR_MQH__

class CUtilsLTR
  {
public:
   // Fonctions utilitaires statiques
   static int  GCD(int a, int b);
   static int  TimeframeToMinutes(ENUM_TIMEFRAMES period);
   static int  ConvertMinutesToFlag(int minutes);
   static int  EncodeDaysClosed(const bool &jours_ouverts[]);
   static int  EncodeDaysClosed(bool dimanche, bool lundi, bool mardi,
                                bool mercredi, bool jeudi, bool vendredi, bool samedi);
   static int  GenerateBadHoursOfDay(int ouverture, int fermeture, int pause_debut = -1, int pause_fin = -1);
   static int  EncodeBitmask(const bool &patterns[]);

   static void LogToDesktop(const string &logMessage);
   static void Close(); // Nécessaire pour garder l'interface, mais ne fera rien dans cette version

   // Classe interne pour le logging fichier
   class CJournal
     {
     public:
        static void Log(string message);
        static void Close(); // Dans cette version, la fermeture est gérée localement dans Log(), donc Close() sera vide.
     };
  };

#endif // __CUTILSLTR_MQH__

//+------------------------------------------------------------------+
//|                Implémentation de la classe CUtilsLTR             |
//+------------------------------------------------------------------+
#ifdef __CUTILSLTR_MQH__

// PGCD
int CUtilsLTR::GCD(int a, int b)
  {
   while(b != 0)
     {
      int temp = b;
      b = a % b;
      a = temp;
     }
   return(a);
  }

// Conversion timeframes -> minutes
int CUtilsLTR::TimeframeToMinutes(ENUM_TIMEFRAMES period)
  {
   switch(period)
     {
      case PERIOD_M1:  return 1;
      case PERIOD_M2:  return 2;
      case PERIOD_M3:  return 3;
      case PERIOD_M4:  return 4;
      case PERIOD_M5:  return 5;
      case PERIOD_M6:  return 6;
      case PERIOD_M10: return 10;
      case PERIOD_M12: return 12;
      case PERIOD_M15: return 15;
      case PERIOD_M20: return 20;
      case PERIOD_M30: return 30;
      case PERIOD_H1:  return 60;
      case PERIOD_H2:  return 120;
      case PERIOD_H3:  return 180;
      case PERIOD_H4:  return 240;
      case PERIOD_H6:  return 360;
      case PERIOD_H8:  return 480;
      case PERIOD_H12: return 720;
      case PERIOD_D1:  return 1440;
      case PERIOD_W1:  return 10080;
      case PERIOD_MN1: return 43200;
      default:         return 0;
     }
  }

// Conversion minutes -> OBJ_PERIOD_* (flags)
int CUtilsLTR::ConvertMinutesToFlag(int minutes)
  {
   switch(minutes)
     {
      case 1:     return OBJ_PERIOD_M1;
      case 2:     return OBJ_PERIOD_M2;
      case 3:     return OBJ_PERIOD_M3;
      case 4:     return OBJ_PERIOD_M4;
      case 5:     return OBJ_PERIOD_M5;
      case 6:     return OBJ_PERIOD_M6;
      case 10:    return OBJ_PERIOD_M10;
      case 12:    return OBJ_PERIOD_M12;
      case 15:    return OBJ_PERIOD_M15;
      case 20:    return OBJ_PERIOD_M20;
      case 30:    return OBJ_PERIOD_M30;
      case 60:    return OBJ_PERIOD_H1;
      case 120:   return OBJ_PERIOD_H2;
      case 180:   return OBJ_PERIOD_H3;
      case 240:   return OBJ_PERIOD_H4;
      case 360:   return OBJ_PERIOD_H6;
      case 480:   return OBJ_PERIOD_H8;
      case 720:   return OBJ_PERIOD_H12;
      case 1440:  return OBJ_PERIOD_D1;
      case 10080: return OBJ_PERIOD_W1;
      case 43200: return OBJ_PERIOD_MN1;
      default:    return WRONG_VALUE;
     }
  }

// Bitmask de jours fermés depuis tableau booléen
int CUtilsLTR::EncodeDaysClosed(const bool &jours_ouverts[])
  {
   int mask = 0;
   for(int i = 0; i < 7; i++)
      if(!jours_ouverts[i]) mask |= (1 << i);
   return mask;
  }

// Bitmask de jours fermés depuis paramètres individuels
int CUtilsLTR::EncodeDaysClosed(bool dimanche, bool lundi, bool mardi,
                                bool mercredi, bool jeudi, bool vendredi, bool samedi)
  {
   bool j[7] = {dimanche, lundi, mardi, mercredi, jeudi, vendredi, samedi};
   return EncodeDaysClosed(j);
  }

// Bitmask d'heures fermées
int CUtilsLTR::GenerateBadHoursOfDay(int ouverture, int fermeture, int pause_debut, int pause_fin)
  {
   bool heures_ouvertes[24];
   ArrayInitialize(heures_ouvertes, false);

   if(ouverture < 0 || ouverture > 23 || fermeture < 0 || fermeture > 24 || ouverture >= fermeture)
     {
      Print("Paramètres d'ouverture/fermeture invalides");
      return 0;
     }

   for(int h = ouverture; h < fermeture; h++)
      heures_ouvertes[h] = true;

   if(pause_debut >= 0 && pause_fin >= 0 && pause_debut <= pause_fin && pause_fin <= 23)
     for(int h = pause_debut; h <= pause_fin; h++)
        heures_ouvertes[h] = false;

   int mask = 0;
   for(int h = 0; h < 24; h++)
      if(!heures_ouvertes[h]) mask |= (1 << h);

   return mask;
  }

// Encode tableau booléen en bitmask
int CUtilsLTR::EncodeBitmask(const bool &patterns[])
  {
   int mask = 0;
   for(int i = 0; i < ArraySize(patterns); i++)
      if(patterns[i]) mask |= (1 << i);
   return mask;
  }

//--- UTILISATION D'UN CHEMIN COMPLET POUR ÉVITER LE LOCKING FTMO ---
// NOTE : Assure-toi d'avoir "Allow Dll imports" si tu reçois une erreur 5004.
//        Sinon, le terminal FTMO peut restreindre l'accès hors MQL5\Files.
//        Ajuste le chemin ci-dessous à ta convenance.
#define RELATIVE_FILENAME  "Journal_FTMO.txt"

//--- Nouvelle version de CJournal::Log ---
// Ouvre le fichier, écrit la ligne, flush puis ferme immédiatement, évitant ainsi de garder le fichier verrouillé.
void CUtilsLTR::CJournal::Log(string message)
  {
   // Ouvre le fichier en mode lecture/écriture, texte et ANSI.
   int fileHandle = FileOpen(RELATIVE_FILENAME, FILE_WRITE | FILE_READ | FILE_TXT | FILE_ANSI);
   if(fileHandle == INVALID_HANDLE)
     {
      Print("Erreur ouverture fichier ", RELATIVE_FILENAME, " : ", GetLastError());
      return;
     }

   // Place le curseur à la fin pour ajouter la nouvelle entrée
   FileSeek(fileHandle, 0, SEEK_END);

   datetime currentTime = TimeCurrent();
   string timestamp = TimeToString(currentTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
   FileWrite(fileHandle, "[" + timestamp + "] " + message);

   FileFlush(fileHandle);
   FileClose(fileHandle);
  }

// Dans cette version, CJournal::Close n'a plus rien à faire.
void CUtilsLTR::CJournal::Close()
  {
   Print("[CJournal] Close() appelé, mais non nécessaire dans la nouvelle version (fichier déjà fermé après chaque écriture).");
  }

// Appel statique externe depuis l'EA
void CUtilsLTR::LogToDesktop(const string &logMessage)
  {
   CUtilsLTR::CJournal::Log(logMessage);
  }

// La fonction Close() externe devient une simple redirection (inutile ici)
void CUtilsLTR::Close()
  {
   CUtilsLTR::CJournal::Close();
  }

#endif // __CUTILSLTR_MQH__
