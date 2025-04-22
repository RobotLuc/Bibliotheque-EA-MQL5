//+------------------------------------------------------------------+
//|                                       SignalBuilder.mqh          |
//|  Classe utilitaire pour construire des signaux composés          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Lucas Troncy"
//+-------------------------------------------------------------------+
//| Notes de version                                                  |
//|28/03/2025 - Création                                              |
//|30/03/2025 - Modification avec ajout de template                   |
//|22/04/2025 - Un signal inactivé n'est plus ajouté au signal de base|
//+-------------------------------------------------------------------+
#ifndef __SIGNAL_BUILDER_MQH__
#define __SIGNAL_BUILDER_MQH__

#include <Expert\Signal\SignalITF.mqh>
#include <Expert\Signal\SignalHA_Am.mqh>
#include <Expert\Signal\SignalRSI.mqh>
#include <Expert\Signal\SignalMA.mqh>
#include <Expert\Utils\UtilsLTR.mqh>
#include <Expert\Config\SignalsConfig.mqh>

//+------------------------------------------------------------------+
//| Classe CSignalBuilder                                            |
//+------------------------------------------------------------------+
class CSignalBuilder
  {
public:
   // Interface unifiée
   static bool       BuildAndAddFilter(CSignalITF *signal, const HAConfig &cfg, bool isactive=true);
   static bool       BuildAndAddFilter(CSignalITF *signal, const RSIConfig &cfg, bool isactive=true);
   static bool       BuildAndAddFilter(CSignalITF *signal, const MAConfig &cfg, bool isactive=true);
   // Tu ajouteras ici ADXConfig, etc.

private:
   // Fonction utilitaire pour factoriser l'ajout d'un filtre uniquement si isactive == true
   template<typename T>
   static T* AddAndConfigureFilter(CSignalITF *signal, bool isactive)
     {
      if(signal == NULL || !isactive)
         return NULL;

      T *filter = new T;
      if(filter == NULL)
         return NULL;

      if(!signal.AddFilter(filter))
         return NULL;

      return filter;
     }
  };

//+------------------------------------------------------------------+
//| Implémentation : filtre Heikin Ashi                              |
//+------------------------------------------------------------------+
bool CSignalBuilder::BuildAndAddFilter(CSignalITF *signal, const HAConfig &cfg, bool isactive)
  {
   CSignalHAm *filter = AddAndConfigureFilter<CSignalHAm>(signal, isactive);
   if(filter == NULL)
      return false;

   filter.Period(cfg.tf);
   filter.PatternsUsage(CUtilsLTR::EncodeBitmask(cfg.enabled));

   filter.Pattern_0(cfg.poids[0]);
   filter.Pattern_1(cfg.poids[1]);
   filter.Pattern_2(cfg.poids[2]);
   filter.Pattern_3(cfg.poids[3]);
   filter.Pattern_4(cfg.poids[4]);
   filter.Pattern_5(cfg.poids[5]);

   filter.PctBigBody(cfg.pct_big_body);
   filter.PctMediumBody(cfg.pct_medium_body);
   filter.PctDojiBody(cfg.pct_doji_body);

   filter.PctTinyWick(cfg.pct_tiny_wick);
   filter.PctSmallWick(cfg.pct_small_wick);
   filter.PctLongWick(cfg.pct_long_wick);

   filter.DojiBefore(cfg.dojibefore);
   filter.AutoFullsize(cfg.auto_fullsize);
   filter.FullsizePts(cfg.fullsize_pts);

   return filter.ValidationSettings();
  }

//+------------------------------------------------------------------+
//| Implémentation : filtre RSI                                      |
//+------------------------------------------------------------------+
bool CSignalBuilder::BuildAndAddFilter(CSignalITF *signal, const RSIConfig &cfg, bool isactive)
  {
   CSignalRSI *filter = AddAndConfigureFilter<CSignalRSI>(signal, isactive);
   if(filter == NULL)
      return false;
   
   filter.Period(cfg.tf);
   filter.PeriodRSI(cfg.period);
   filter.Applied(cfg.price);
   filter.PatternsUsage(CUtilsLTR::EncodeBitmask(cfg.enabled));
   filter.Pattern_0(cfg.poids[0]);
   filter.Pattern_1(cfg.poids[1]);
   filter.Pattern_2(cfg.poids[2]);
   filter.Pattern_3(cfg.poids[3]);
   filter.Pattern_4(cfg.poids[4]);
   filter.Pattern_5(cfg.poids[5]);
   filter.SeuilSurAchete(cfg.seuil_surachete);
   filter.SeuilSurVendu(cfg.seuil_survendu);

   return filter.ValidationSettings();
  }

//+------------------------------------------------------------------+
//| Implémentation : filtre Moyenne Mobile                           |
//+------------------------------------------------------------------+
bool CSignalBuilder::BuildAndAddFilter(CSignalITF *signal, const MAConfig &cfg, bool isactive)
  {
   CSignalMA *filter = AddAndConfigureFilter<CSignalMA>(signal, isactive);
   if(filter == NULL)
      return false;

   filter.PeriodMA(cfg.period);
   filter.Shift(cfg.shift);
   filter.Method(cfg.method);
   filter.Applied(cfg.price);
   filter.Period(cfg.tf);

   filter.Pattern_0(cfg.poids[0]);
   filter.Pattern_1(cfg.poids[1]);
   filter.Pattern_2(cfg.poids[2]);
   filter.Pattern_3(cfg.poids[3]);
   filter.PatternsUsage(CUtilsLTR::EncodeBitmask(cfg.enabled));
   return filter.ValidationSettings();
  }

#endif // __SIGNAL_BUILDER_MQH__
//+------------------------------------------------------------------+
//|   Fin de la classe statique CSignalBuilder                       |
//+------------------------------------------------------------------+
