# Grid-trading

## 1. Overview
Primary Purpose:
The code implements a grid trading strategy. It manages the opening and closing of trades based on grid levels and includes a trailing stop mechanism to protect profits.

### Main Structure:
Class CLeg: Inherits from CLegBase and handles the trading logic for a single “leg” within the grid strategy.
Key Components: Uses a Basket object to manage the list of open positions, while controlling trade entries, exits, trailing stops, and recalculating parameters.

## 2. Key Variables and Data Structures

### Important Member Variables:
mLevelSize: The grid level size, converted from points to a real price value.

mTrailDistance & mTrailStart: Parameters for the trailing stop mechanism, specifying the trailing distance and the profit threshold before trailing starts.

mCount: The current number of open positions in the basket.

mOppositeLegCount: The number of positions in the opposite leg, used for comparative trading logic.

mProfitTail: Holds the profit amount to be “protected” when trimming positions.

mEntryPrice, mEntryPriceTrail, mExitPrice: Calculated entry and exit price levels based on the grid.

Basket: An instance of CPositionBasket used for managing the collection of open positions.

## 3. Main Functions

### 3.1. Constructor CLeg(int type)

### Functionality:
- Calls the constructor of the base class CLegBase.
- Sets up initial trading parameters (magic number, comment, trade direction) based on input values from Input.mqh.
- Converts point values to real price values for mLevelSize, mTrailDistance, and mTrailStart using the PointsToDouble method.
- Invokes the Recount() function to scan and rebuild the list of open positions right from the start.

### 3.2. Function On_Tick(int oppositeLegCount)

### Functionality:
Receives the number of positions from the opposite leg and assigns it to mOppositeLegCount.

Calls the base class’s On_Tick() method to handle the common tick logic.

### 3.3. Function On_Tick_Close()

### Execution Flow:
If there are no open positions (mCount == 0), the function exits early.

Retrieves the current closing price (PriceClose).

Compares the closing price with mExitPrice:

If the closing price has not reached the exit level, no action is taken.

If the number of open positions exceeds that of the opposite leg:

It calls CloseWithTrim(closePrice) to trim the positions, then recalculates the basket via Recount().

### Otherwise:
It calls On_Tick_Trailing() to update trailing stops for open positions and then calls Recount().

### 3.4. Function On_Tick_Open()

### Trade Entry Logic:
Retrieves the current opening price (PriceOpen).

If there are no open positions (mCount == 0) or the opening price is less than or equal to mEntryPrice, it opens a new trade by calling OpenTrade(priceOpen).

Additionally, if the number of open positions is less than or equal to 50% of the opposite leg’s positions and the opening price meets either of the following conditions:

The opening price is less than or equal to mEntryPrice, or
The opening price is greater than or equal to mEntryPriceTrail, then it also calls OpenTrade(priceOpen).

### 3.5. Function CloseWithTrim(double closePrice)

### Core Functionality:
This function “trims” (reduces) the open positions to protect profits when certain conditions are met.

### Detailed Process:

Determines the minimum trade volume (minVolume) based on the symbol’s information.

Retrieves the “head” position (the last open position) from the basket.

If the total number of positions is small (≤2), it resets mProfitTail and skips the trim process.

Calculates the loss of the head position based on its profit-to-volume ratio (adjusted by minVolume).

Iterates through the entire basket to collect positions with a profit greater than 0, accumulating their total profit.

If the total profit from these profitable positions is at least twice the absolute loss of the head:

- Closes all profitable positions.

- Partially closes the head position using the minimum volume to “trim” and protect profit.

### 3.6. Function OpenTrade(double priceOpen)

### Functionality:
Executes a new trade via mTrade.PositionOpen, using parameters such as the symbol, order type, volume, and the provided opening price.

If the trade opens successfully, it calls Recount() to update the basket.

### 3.7. Function Recount()
### Functionality:
This function scans the currently open trades and updates internal parameters accordingly.

### Detailed Process:

Determines the sortMode based on the trade direction (BUY or SELL).

Calls Basket.Fill to retrieve the list of open positions filtered by mMagic and mPositionType.

Resets the entry (mEntryPrice) and exit (mExitPrice) price levels, and updates the count (mCount) of positions in the basket.

If there are open positions:

Retrieves the first (tail) and the last (head) positions.

Calculates mEntryPrice using the tail’s open price adjusted by mLevelSize.

When the number of open positions is less than or equal to 50% of the opposite leg’s positions, it adjusts mEntryPrice (using half the grid level) and computes mEntryPriceTrail based on the head’s open price.

Determines mExitPrice: if more than one position is open, it uses the open price of the next position; if there is only one, it adds mLevelSize to the tail’s open price.

### 3.8. Function On_Tick_Trailing()
### Functionality:
This function iterates through the open positions to update the trailing stop, ensuring that profit is protected when the trade has reached a minimum profit threshold (InpTrailStart).

### Detailed Process:

#### For BUY positions:
- Calculates the current profit in pips: (bid - pos.OpenPrice) / point.

- If the profit meets or exceeds InpTrailStart, calculates a new stop loss (SL) as bid - mTrailDistance.

- If the new SL is higher than the current SL, it updates the position’s SL using mTrade.PositionModify.

#### For SELL positions:

- Calculates the current profit in pips: (pos.OpenPrice - ask) / point.

- If the profit meets or exceeds InpTrailStart, calculates a new SL as ask + mTrailDistance.

- If the current SL is greater than the new SL or if no SL is set (SL equals 0), it updates the position’s SL.

### Objective:
The trailing stop mechanism dynamically adjusts the stop loss to lock in profits once a certain profit threshold is reached.

## 4. Key Points and Considerations
### Edge Case Handling:

If there are no open positions (mCount == 0), most functions simply return true without further processing.

In CloseWithTrim, if there are only a few positions (≤2), the function avoids unnecessary operations by resetting mProfitTail.

### Price Level Calculations:

Entry, exit, and trailing levels are derived from the open prices of positions (tail, head, next) and adjusted using the grid level (mLevelSize).

Adjustments (like using half the grid level) are applied when the number of open positions is less than 50% of the opposite leg, enhancing the strategy's flexibility.

### Interaction with Trade Management:

Functions such as PositionOpen, PositionClose, PositionModify, and PositionClosePartial from the mTrade object handle the actual trade execution.

Error handling is minimally addressed (e.g., in CloseWithTrim), with potential logging or further actions implied if operations fail.

### Position Basket Management:

The Basket object is responsible for managing the list of open positions, providing methods for iteration (GetFirstNode(), GetLastNode(), Next()) and updating the list via Fill().

## 5. Conclusion
This code implements a grid trading strategy with the following key components:

### Trade Entry:
- Based on comparisons between the current opening price and computed levels (mEntryPrice, mEntryPriceTrail), as well as the ratio relative to positions in the opposite leg.
### Trade Exit:
- Combines a defined exit price level with a trimming mechanism that protects accumulated profit.
### Trailing Stop:
- Dynamically adjusts the stop loss when trades reach a specified profit threshold, thereby securing gains.
 
