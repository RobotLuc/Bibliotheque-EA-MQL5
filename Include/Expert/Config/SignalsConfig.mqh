//+------------------------------------------------------------------+
//|                                                SignalsConfig.mqh |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Lucas Troncy"
// Fichier contenant les structures de configuration des signaux
//+------------------------------------------------------------------+
#ifndef __SIGNAL_CONFIGS_MQH__
#define __SIGNAL_CONFIGS_MQH__

//+------------------------------------------------------------------+
//| Structure pour configurer un filtre Heiken Ashi Amélioré        |
//+------------------------------------------------------------------+
struct HAConfig
  {
   ENUM_TIMEFRAMES   tf;            // Temporalité
   int               poids[6];      // Poids des motifs 0 à 5
   bool              enabled[6];    // Activation motifs 0 à 5

   double            pct_big_body;
   double            pct_medium_body;
   double            pct_doji_body;

   double            pct_tiny_wick;
   double            pct_small_wick;
   double            pct_long_wick;

   int               dojibefore;        // Nombre de bougies avant le doji
   bool              auto_fullsize;     // true = mode relatif, false = absolu
   double            fullsize_pts;      // Valeur absolue en points (si > 0)
  };

//+------------------------------------------------------------------+
//| Structure pour configurer un filtre RSI                         |
//+------------------------------------------------------------------+
struct RSIConfig
  {
   ENUM_TIMEFRAMES    tf;
   int                poids[7];       // Poids des motifs 0 à 6
   bool               enabled[7];     // Activation motifs 0 à 6

   int                period;
   ENUM_APPLIED_PRICE price;
   double             seuil_surachete;
   double             seuil_survendu;
   double             min_rsi_change;
   double             seuil_medianmax; // ➔ pour motif 6 (long)
   double             seuil_maximum;   // ➔ pour motif 6 (haut)
   double             seuil_medianmin; // ➔ pour motif 6 (short)
   double             seuil_minimum;   // ➔ pour motif 6 (bas)
   bool               trend_strategy;
  };

//+------------------------------------------------------------------+
//| Structure pour configurer un filtre MA                          |
//+------------------------------------------------------------------+
struct MAConfig
  {
   ENUM_TIMEFRAMES     tf;
   int                 poids[5];       // Poids des motifs 0 à 3
   bool                enabled[5];     // Activation motifs 0 à 3

   int                 period;
   int                 shift;
   ENUM_MA_METHOD      method;
   ENUM_APPLIED_PRICE  price;
   double              min_ma_change;
   double              diff_price_ma;
  };

//+------------------------------------------------------------------+
//| Structure pour configurer un filtre Stochastique                |
//+------------------------------------------------------------------+
struct StochConfig
  {
   ENUM_TIMEFRAMES    tf;
   int                poids[5];         // Poids des motifs 0 à 4
   bool               enabled[5];       // Activation motifs 0 à 4

   int                periodK;          // %K period
   int                periodD;          // %D period
   int                period_slow;      // Smoothing
   ENUM_STO_PRICE     applied_price;    // Source de prix
  };

//+------------------------------------------------------------------+
//| Structure pour configurer un filtre CrossMA                      |
//+------------------------------------------------------------------+
struct CrossMAConfig
  {
   ENUM_TIMEFRAMES     tf;               // Temporalité
   int                 poids[5];         // Poids des motifs 0 à 4
   bool                enabled[5];       // Activation motifs 0 à 4

   // Paramètres MA rapide
   int                 period_fast;
   int                 shift_fast;
   ENUM_MA_METHOD      method_fast;
   ENUM_APPLIED_PRICE  price_fast;

   // Paramètres MA lente
   int                 period_slow;
   int                 shift_slow;
   ENUM_MA_METHOD      method_slow;
   ENUM_APPLIED_PRICE  price_slow;
  };

#endif // __SIGNAL_CONFIGS_MQH__
//+------------------------------------------------------------------+
//| Fin du fichier SignalsConfig.mqh                                |
//+------------------------------------------------------------------+
