//+------------------------------------------------------------------+
//|                                                       GridTrader |
//|                                           Copyright 2025, MinhTC |
//+------------------------------------------------------------------+
#include "Config.mqh"
#include "Input.mqh"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CLeg : public CLegBase
  {

protected:
   double            mLevelSize;

   int               mCount;
   int               mOppositeLegCount;
   double            mProfitTail;
   double            mEntryPrice;
   double            mEntryPriceTrail;
   double            mExitPrice;
   double            mTrailDistance;
   double            mTrailStart;

   CPositionBasket   Basket;

   bool              On_Tick_Close();
   bool              On_Tick_Open();

   bool              CloseWithTrim(double closePrice);
   bool              On_Tick_Trailing();
   void              OpenTrade(double price);
   void              Recount();


public:
                     CLeg(int type);

   virtual void      On_Tick(int oppositeLegCount);
   int               GetCount() const { return mCount; }
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CLeg::CLeg(int type) : CLegBase(type)
  {

   Magic(InpMagic);
   TradeComment(InpTradeComment + " " + app_version);
   TradeDirection(InpTradeDirection);
   mLevelSize = mSymbolInfo.PointsToDouble(InpLevelPoints);
   mTrailDistance = mSymbolInfo.PointsToDouble(InpTrailDistance);
   mTrailStart    = mSymbolInfo.PointsToDouble(InpTrailStart);

   Recount();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CLeg::On_Tick(int oppositeLegCount)
  {
   mOppositeLegCount = oppositeLegCount;
   CLegBase::On_Tick();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CLeg::On_Tick_Close()
  {

   if(mCount == 0)
      return true;

   double closePrice = PriceClose();

   if(LT(closePrice, mExitPrice))
      return true; // not up to the exit price for the level

   if(mCount > mOppositeLegCount)
     {
      if(CloseWithTrim(closePrice))
         Recount();
     }
   else
     {
        {
         if(On_Tick_Trailing())
            Recount();
        }

      return true;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Hàm mở lệnh mới với điều kiện:                                   |
//| Nếu số lệnh hiện tại <= 50% số lệnh của leg đối lập              |
//| OR                                                               |
//| Nếu giá mở <= mEntryPrice                                        |
//+------------------------------------------------------------------+
bool CLeg::On_Tick_Open()
  {
   double priceOpen = PriceOpen();

   if(mCount == 0 || LE(priceOpen, mEntryPrice))
     {
      OpenTrade(priceOpen);
      return true;
     }

   if(mCount <= (mOppositeLegCount / 2) && (LE(priceOpen, mEntryPrice) || GE(priceOpen, mEntryPriceTrail)))
     {
      OpenTrade(priceOpen);
      return true;
     }

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CLeg::CloseWithTrim(double closePrice)
  {
   bool result = false;
// Tính khối lượng tối thiểu
   double minVolume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);

// Lấy head (vị thế cuối cùng) từ Basket
   CPositionData* head = Basket.GetLastNode();
   if(head == NULL)
      return result;

   result = true;

// Nếu số lượng vị thế nhỏ hơn hoặc bằng 2 thì reset mProfitTail và không cần trim head
   if(mCount <= 2)
     {
      mProfitTail = 0;
      return result;
     }

// Tính lỗ của head với khối lượng giao dịch cố định 0.01 lot:
   double headLoss = (head.Profit/head.Volume) * minVolume;
   double absHeadLoss = fabs(headLoss);

// Duyệt qua toàn bộ Basket, tìm các vị thế có lợi nhuận (profit > 0)
   double totalProfit = 0.0;
   CPositionData *profitablePositions[]; // Mảng động lưu các vị thế có lợi nhuận
   int profitableCount = 0;
   CPositionData *pos = Basket.GetFirstNode();

   while(pos != NULL)
     {
      // Tính lợi nhuận của vị thế hiện tại
      double posProfit = pos.Profit;
      if(posProfit > 0)
        {
         totalProfit += posProfit;
         // Thêm pos vào mảng profitablePositions
         ArrayResize(profitablePositions, profitableCount + 1);
         profitablePositions[profitableCount] = pos;
         profitableCount++;
        }
      pos = pos.Next(); // Giả sử CPositionData có con trỏ 'next' để duyệt danh sách
     }

// Nếu tổng lợi nhuận từ các vị thế profit >= 50% của absHeadLoss
   if(totalProfit >= 2 * absHeadLoss)
     {
      // Đóng tất cả các vị thế profit
      for(int i = 0; i < profitableCount; i++)
        {
         if(!mTrade.PositionClose(profitablePositions[i].Ticket))
           {
            // Xử lý lỗi nếu cần (ví dụ: ghi log lỗi) nhưng vẫn tiếp tục
           }
        }

      if(mTrade.PositionClosePartial(head.Ticket, minVolume))
         result = true;
     }

   return result;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CLeg::OpenTrade(double priceOpen)
  {
   double sl = 0;
   
   if(mPositionType == POSITION_TYPE_BUY)
   {
      sl = priceOpen - 31.4;
   }
   else
   {
      sl = priceOpen + 31.4;
   }

   if(mTrade.PositionOpen(Symbol(), mOrderType, InpVolume, priceOpen, sl, 0, mTradeComment))
   {
      Recount();
   }
  }

/*
 * Recount()
 *
 * Mainly for restarts
 * Scans currently open trades and rebuilds the position
 */
void CLeg::Recount()
  {

   int sortMode = (mOrderType == ORDER_TYPE_BUY) ? 3 : -3;
   Basket.Fill(sortMode, Symbol(), mMagic, mPositionType);

   mEntryPrice       = 0;
   mExitPrice        = 0;

   mCount      = Basket.Total();
   if(mCount == 0)
      return;

   CPositionData *tail = Basket.GetFirstNode();
   CPositionData *head = Basket.GetLastNode();
   CPositionData *next = tail.Next();

   mEntryPrice = Sub(tail.OpenPrice, mLevelSize);

   if(mCount <= (mOppositeLegCount / 2))
     {
      mEntryPrice = Sub(tail.OpenPrice, mLevelSize/2);
      mEntryPriceTrail = Add(head.OpenPrice,mLevelSize/2);
     }

   mExitPrice  = (mCount > 1) ? next.OpenPrice : Add(tail.OpenPrice, mLevelSize);

  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
/*
 * On Tick Trailing
 *
 * Duyệt qua các vị thế trong basket và cập nhật trailing stop nếu:
 * - Lợi nhuận của vị thế đạt tối thiểu TrailStart (ví dụ 300 pips)
 * - Đối với BUY: SL = Bid - TrailDistance
 * - Đối với SELL: SL = Ask + TrailDistance
 * Lưu ý: trailing stop của vị thế mới chưa được áp dụng cho đến khi đạt được mức TrailStart.
 */
bool CLeg::On_Tick_Trailing()
  {
   CPositionData *pos = Basket.GetFirstNode();
   double ask = mSymbolInfo.Ask();
   double bid = mSymbolInfo.Bid();

   while(pos != NULL)
     {
      if(mPositionType == POSITION_TYPE_BUY)
        {
         // Tính lợi nhuận hiện tại tính theo pips cho lệnh mua
         double currentProfitPips = (bid - pos.OpenPrice) / mSymbolInfo.Point();
         if(currentProfitPips >= InpTrailStart)  // Nếu đạt ngưỡng trail start
           {
            double newSL = bid - mTrailDistance;
            // Cập nhật SL nếu newSL cao hơn SL hiện tại (bảo vệ lợi nhuận)
            if(pos.StopLoss < newSL)
              {
               mTrade.PositionModify(pos.Ticket, newSL, 0);
              }
           }
        }
      else  // Dành cho lệnh bán
        {
         double currentProfitPips = (pos.OpenPrice - ask) / mSymbolInfo.Point();
         if(currentProfitPips >= InpTrailStart)
           {
            double newSL = ask + mTrailDistance;
            if(pos.StopLoss > newSL || pos.StopLoss == 0)
              {
               mTrade.PositionModify(pos.Ticket, newSL, 0);
              }
           }
        }
      pos = pos.Next();  // Duyệt đến vị thế kế tiếp
     }
   return true;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
