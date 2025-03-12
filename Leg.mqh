//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
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
   double            mProfitTail;
   double            mEntryPrice;
   double            mExitPrice;

   CPositionBasket   Basket;

   bool              On_Tick_Close();
   bool              On_Tick_Open();

   bool              CloseWithTrim(double closePrice);
   void              OpenTrade(double price);
   void              Recount();

public:
                     CLeg(int type);

   virtual void      On_Tick();
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

   Recount();
  }

void CLeg::On_Tick() { CLegBase::On_Tick(); }

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

   if(CloseWithTrim(closePrice))
      Recount();

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CLeg::On_Tick_Open()
  {

   double priceOpen = PriceOpen();
   if(mCount == 0 || LE(priceOpen, mEntryPrice))
     {
      OpenTrade(priceOpen);
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

   if(mTrade.PositionOpen(Symbol(), mOrderType, InpVolume, priceOpen, 0, 0, mTradeComment))
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

   mEntryPrice = 0;
   mExitPrice  = 0;

   mCount      = Basket.Total();
   if(mCount == 0)
      return;

   CPositionData *tail = Basket.GetFirstNode();
   CPositionData *next = tail.Next();

   mEntryPrice = Sub(tail.OpenPrice, mLevelSize);
   mExitPrice  = (mCount > 1) ? next.OpenPrice : Add(tail.OpenPrice, mLevelSize);

  }
//+------------------------------------------------------------------+
