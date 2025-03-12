#include "Config.mqh"
#include "Input.mqh"

class CLeg : public CLegBase {

   protected:
      double          mLevelSize;

      int             mCount;
      double          mProfitTail;
      double          mEntryPrice;
      double          mExitPrice;

      CPositionBasket Basket;

      bool            On_Tick_Close();
      bool            On_Tick_Open();

      bool            CloseWithTrim( double closePrice );
      void            OpenTrade( double price );
      void            Recount();

   public:
      CLeg( int type );

      virtual void On_Tick();
};

CLeg::CLeg( int type ) : CLegBase( type ) {

   Magic( InpMagic );
   TradeComment( InpTradeComment + " " + app_version );
   TradeDirection( InpTradeDirection );
   mLevelSize = mSymbolInfo.PointsToDouble( InpLevelPoints );

   Recount();
}

void CLeg::On_Tick() { CLegBase::On_Tick(); }

bool CLeg::On_Tick_Close() {

   if ( mCount == 0 ) return true;

   double closePrice = PriceClose();
   if ( LT( closePrice, mExitPrice ) ) return true; // not up to the exit price for the level

   if ( CloseWithTrim( closePrice ) ) Recount();

   return true;
}

bool CLeg::On_Tick_Open() {

   double priceOpen = PriceOpen();
   if ( mCount == 0 || LE( priceOpen, mEntryPrice ) ) {
      OpenTrade( priceOpen );
   }

   return true;
}

bool CLeg::CloseWithTrim(double closePrice)
{
    bool result = false;

    // Lấy tail (vị thế đầu tiên)
    CPositionData *tail = Basket.GetFirstNode();
    if (tail == NULL)
        return result;

    // Thử đóng lệnh tail
    if (!mTrade.PositionClose(tail.Ticket))
        return result;  // Nếu đóng không thành công, trả về false

    result = true;

    // Cập nhật lợi nhuận của tail: (closePrice - openPrice) * volume
    double tailProfit = (closePrice - tail.OpenPrice) * tail.Volume;
    double absTailProfit = fabs(tailProfit);
    mProfitTail += absTailProfit;

    // Nếu số lượng vị thế nhỏ hơn hoặc bằng 2 thì reset mProfitTail và không cần trim head
    if (mCount <= 2)
    {
        mProfitTail = 0;
        return result;
    }

    // Lấy head (vị thế cuối cùng)
    CPositionData *head = Basket.GetLastNode();

    // Tính lỗ của head với khối lượng giao dịch cố định 0.01 lot:
    // Công thức: (closePrice - head->openPrice) * 0.01
    double headLoss = (head.Profit/head.Volume) * 0.01;
    double absHeadLoss = fabs(headLoss);

    // Kiểm tra điều kiện: chỉ đóng partial head nếu lỗ <= 50% lợi nhuận tail tích lũy
    if (absHeadLoss <= 0.5 * mProfitTail)
    {
        double partialVolume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
        mTrade.PositionClosePartial(head.Ticket, partialVolume);
        // Cập nhật lại lợi nhuận tail bằng cách trừ đi giá trị lỗ đã thực hiện
        mProfitTail -= absHeadLoss;
    }

    return result;
}

void CLeg::OpenTrade( double priceOpen ) {

   if (mTrade.PositionOpen( Symbol(), mOrderType, InpVolume, priceOpen, 0, 0, mTradeComment )) {
	   Recount();
	}
}

/*
 *	Recount()
 *
 *	Mainly for restarts
 *	Scans currently open trades and rebuilds the position
 */
void CLeg::Recount() {

   int sortMode = ( mOrderType == ORDER_TYPE_BUY ) ? 3 : -3;
   Basket.Fill( sortMode, Symbol(), mMagic, mPositionType );

   mEntryPrice = 0;
   mExitPrice  = 0;

   mCount      = Basket.Total();
   if ( mCount == 0 ) return;

   CPositionData *tail = Basket.GetFirstNode();
   CPositionData *next = tail.Next();

   mEntryPrice = Sub( tail.OpenPrice, mLevelSize );
   mExitPrice  = ( mCount > 1 ) ? next.OpenPrice : Add( tail.OpenPrice, mLevelSize );

}
