/*

   GridTrader
   Main

   Copyright 2025, MinhTC
*/

#define app_version "2.030"
#define app_magic   240500000

#include "Config.mqh"
#include "Input.mqh"
#include "Leg.mqh"

CLeg *BuyLeg;
CLeg *SellLeg;

// CGVar *GV;

;
int OnInit()
  {

   BuyLeg  = new CLeg(POSITION_TYPE_BUY);
   SellLeg = new CLeg(POSITION_TYPE_SELL);

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   delete BuyLeg;
   delete SellLeg;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {

   if(!IsTradeAllowed())
      return;

   if(IsNewBar())
     {
     }
   int buyLegCount = BuyLeg.GetCount();
   int sellLegCount = SellLeg.GetCount();
   BuyLeg.On_Tick(sellLegCount);
   SellLeg.On_Tick(buyLegCount);

   return;
  }
//+------------------------------------------------------------------+
