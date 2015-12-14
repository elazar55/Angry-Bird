enum I_SIG
{
    MFI,
    CCI
};

bool long_trade          = FALSE;
bool short_trade         = FALSE;
double all_lots          = 0;
double average_price     = 0;
double bands_extra_high  = 0;
double bands_extra_low   = 0;
double bands_high        = 0;
double bands_highest     = 0;
double bands_low         = 0;
double bands_lowest      = 0;
double bands_mid         = 0;
double commission        = 0;
double delta             = 0;
double i_lots            = 0;
double i_takeprofit      = 0;
double last_buy_price    = 0;
double last_sell_price   = 0;
double lots_multiplier   = 0;
double price_target      = 0;
double rsi               = 0;
double rsi_prev          = 0;
double tp_dist           = 0;
int error                = 0;
int i_test               = 0;
int lotdecimal           = 2;
int magic_number         = 2222;
int pipstep              = 0;
int previous_time        = 0;
int slip                 = 1000;
int total                = 0;
string comment           = "";
string name              = "Ilan1.6";
uint time_elapsed        = 0;
uint time_start          = GetTickCount();
extern int rsi_max       = 200;
extern int rsi_min       = -100;
extern int rsi_period    = 14;
extern int stddev_period = 14;
extern double exp_base   = 1.7;
extern double lots       = 0.01;
extern I_SIG indicator   = 0;

int init()
{
    if (IsTesting())
    {
        if (rsi_min > rsi_max) ExpertRemove();
        if (rsi_max > 100 && indicator != CCI) ExpertRemove();
        if (rsi_min < 0   && indicator != CCI) ExpertRemove();
    }
    total = OrdersTotal();
    if (total)
    {
        last_buy_price  = FindLastBuyPrice();
        last_sell_price = FindLastSellPrice();
        Update();
        NewOrdersPlaced();
    }
    ObjectCreate("Average Price", OBJ_HLINE, 0, 0, average_price, 0, 0, 0, 0);
    return (0);
}

int deinit()
{
    time_elapsed = GetTickCount() - time_start;
    Print("Time Elapsed: " + time_elapsed);
    return (0);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int start()
{
    //--- Works only at the first tick of a new bar
    if (!IsOptimization()) Update();
    if (previous_time == Time[0]) return (0);
    previous_time = Time[0];
    Update();
    double indicator_ = IndicatorSignal();
    //---

    //--- First
    if (OrdersTotal() == 0)
    {
        if (indicator_ == OP_BUY)
        {
            SendBuy();
        }
        else if (indicator_ == OP_SELL)
        {
            SendSell();
        }
        return 0;
    }
    //---

    //--- Cancels
    if (AccountProfit() >= 0)
    {
        if (short_trade)
        {
            //--- Closes sell and opens buy
            if (indicator_ == OP_BUY)
            {
                CloseThisSymbolAll();
                Update();
                SendBuy();
                return 0;
            }
            //--- Take
            if (Ask < bands_mid)
            {
                CloseThisSymbolAll();
                return 0;
            }
        }
        if (long_trade)
        {
            //--- Closes buy and opens sell
            if (indicator_ == OP_SELL)
            {
                CloseThisSymbolAll();
                Update();
                SendSell();
                return 0;
            }
            //--- Take
            if (Bid > bands_mid)
            {
                CloseThisSymbolAll();
                return 0;
            }
        }
    }
    //---

    //--- Proceeding Trades
    if (short_trade && indicator_ == OP_SELL && Bid > last_sell_price + pipstep * Point)
    {
        SendSell();
    }
    else if (long_trade && indicator_ == OP_BUY && Ask < last_buy_price - pipstep * Point)
    {
        SendBuy();
    }
    //---
    return 0;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Update()
{
    total = OrdersTotal();

    pipstep = (2 / Point) / iStdDev(0, 0, stddev_period, 0, MODE_SMA, PRICE_TYPICAL, 0);

    if (short_trade)
    {
        tp_dist = (Bid - average_price) / Point;
    }
    else if (long_trade)
    {
        tp_dist = (average_price - Ask) / Point;
    }

    if (OrdersTotal() == 0)
    {
        //--- Resets
        all_lots        = 0;
        average_price   = 0;
        commission      = 0;
        i_takeprofit    = 0;
        last_buy_price  = 0;
        last_sell_price = 0;
        i_lots          = lots;
        long_trade      = FALSE;
        short_trade     = FALSE;
        delta           = MarketInfo(Symbol(), MODE_TICKVALUE) * lots;
        //---
    }
    else
    {
        total = OrdersTotal();

        // lots_multiplier = MathPow(exp_base, OrdersTotal());
        // lots_multiplier = MathPow(exp_base, tp_dist * Point);
         lots_multiplier = (tp_dist * Point) * exp_base;
        if (lots_multiplier < 1) lots_multiplier = 1;

        i_lots       = NormalizeDouble(lots * lots_multiplier, lotdecimal);
        commission   = CalculateCommission() * -1;
        all_lots     = CalculateLots();
        delta        = MarketInfo(Symbol(), MODE_TICKVALUE) * all_lots;
        i_takeprofit = MathRound(commission / delta) + pipstep;
    }

    if (!IsOptimization())
    {
        int time_difference = TimeCurrent() - Time[0];
        ObjectSet("Average Price", OBJPROP_PRICE1, average_price);

        Comment("Last Distance: " + tp_dist + " Pipstep: " + pipstep + " Take Profit: " + i_takeprofit +
                " Lots: " + i_lots + " Time: " + time_difference);
    }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void NewOrdersPlaced()
{
    //--- Prevents bad results showing in tester
    if (IsTesting() && error < 0)
    {
        while (AccountBalance() > 20)
        {
            error = OrderSend(Symbol(), OP_BUY, AccountFreeMargin() / Bid,
                              Ask, slip, 0, 0, name, magic_number, 0, 0);
            CloseThisSymbolAll();
        }
        ExpertRemove();
    }
    //---

    Update();
    UpdateAveragePrice();
    UpdateOpenOrders();
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateAveragePrice()
{
    average_price = 0;
    double count = 0;
    for (int i = 0; i < OrdersTotal(); i++)
    {
        error = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
        {
            average_price += OrderOpenPrice() * OrderLots();
            count += OrderLots();
        }
    }
    average_price = NormalizeDouble(average_price / count, Digits);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateOpenOrders()
{
    for (int i = 0; i < CountTrades(); i++)
    {
        error = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
        {
            if (OrderType() == OP_BUY)
            {
                price_target = average_price +
                               NormalizeDouble((i_takeprofit * Point), Digits);
                short_trade = FALSE;
                long_trade  = TRUE;
            }
            else if (OrderType() == OP_SELL)
            {
                price_target = average_price -
                               NormalizeDouble((i_takeprofit * Point), Digits);
                short_trade = TRUE;
                long_trade  = FALSE;
            }
            error =
                OrderModify(OrderTicket(), 0, 0,
                            NormalizeDouble(price_target, Digits), 0, clrYellow);
        }
    }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double IndicatorSignal()
{
    double rsi_open;

    //--- Indicator selection
    if (indicator == MFI)
    {
        rsi      = iMFI(0, 0, rsi_period, 1);
        rsi_prev = iMFI(0, 0, rsi_period, 2);
        rsi_open = iMFI(0, 0, rsi_period, 0);
    }
    else if (indicator == CCI)
    {
        rsi      = iCCI(0, 0, rsi_period, PRICE_TYPICAL, 1);
        rsi_prev = iCCI(0, 0, rsi_period, PRICE_TYPICAL, 2);
        rsi_open = iCCI(0, 0, rsi_period, PRICE_TYPICAL, 0);
    }
    //---

    bands_highest = iBands(0, 0, stddev_period, 2, 0, PRICE_TYPICAL, MODE_UPPER, 1);
    bands_high    = iBands(0, 0, stddev_period, 1, 0, PRICE_TYPICAL, MODE_UPPER, 1);
    bands_mid     = iBands(0, 0, stddev_period, 1, 0, PRICE_TYPICAL, MODE_MAIN,  1);
    bands_low     = iBands(0, 0, stddev_period, 1, 0, PRICE_TYPICAL, MODE_LOWER, 1);
    bands_lowest  = iBands(0, 0, stddev_period, 2, 0, PRICE_TYPICAL, MODE_LOWER, 1);

    if (rsi > rsi_max && rsi < rsi_prev && Bid > bands_high) return OP_SELL;
    if (rsi < rsi_min && rsi > rsi_prev && Ask < bands_low)  return OP_BUY;
    return (-1);
}
//+------------------------------------------------------------------+
//| SUBROUTINES                                                      |
//+------------------------------------------------------------------+
int CountTrades()
{
    int count = 0;
    for (int trade = OrdersTotal() - 1; trade >= 0; trade--)
    {
        error = OrderSelect(trade, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
            if (OrderType() == OP_SELL || OrderType() == OP_BUY) count++;
    }
    return (count);
}

void CloseThisSymbolAll()
{
    for (int trade = OrdersTotal() - 1; trade >= 0; trade--)
    {
        error = OrderSelect(trade, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
        {
            if (OrderType() == OP_BUY)
                error = OrderClose(OrderTicket(), OrderLots(), Bid, slip, clrBlue);
            if (OrderType() == OP_SELL)
                error = OrderClose(OrderTicket(), OrderLots(), Ask, slip, clrBlue);
        }
    }
}

double CalculateProfit()
{
    double Profit = 0;
    for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt--)
    {
        error = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
            if (OrderType() == OP_BUY || OrderType() == OP_SELL)
                Profit += OrderProfit();
    }
    return (Profit);
}

double CalculateCommission()
{
    double p_commission = 0;
    for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt--)
    {
        error = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
            if (OrderType() == OP_BUY || OrderType() == OP_SELL)
                p_commission += OrderCommission();
    }
    return (p_commission);
}

double CalculateLots()
{
    double lot = 0;
    for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt--)
    {
        error = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number)
            if (OrderType() == OP_BUY || OrderType() == OP_SELL)
            {
                lot += OrderLots();
            }
    }
    return (lot);
}

double FindLastBuyPrice()
{
    double oldorderopenprice;
    int oldticketnumber;
    int ticketnumber = 0;
    for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt--)
    {
        error = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number &&
            OrderType() == OP_BUY)
        {
            oldticketnumber = OrderTicket();
            if (oldticketnumber > ticketnumber)
            {
                oldorderopenprice = OrderOpenPrice();
                ticketnumber     = oldticketnumber;
            }
        }
    }
    return (oldorderopenprice);
}

double FindLastSellPrice()
{
    double oldorderopenprice;
    int oldticketnumber;
    int ticketnumber = 0;
    for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt--)
    {
        error = OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic_number &&
            OrderType() == OP_SELL)
        {
            oldticketnumber = OrderTicket();
            if (oldticketnumber > ticketnumber)
            {
                oldorderopenprice = OrderOpenPrice();
                ticketnumber      = oldticketnumber;
            }
        }
    }
    return (oldorderopenprice);
}

void SendBuy()
{
    error = OrderSend(Symbol(), OP_BUY, i_lots, Ask, slip, 0, 0, name,
                              magic_number, 0, clrLimeGreen);
/*
    while (GetLastError() == ERR_OFF_QUOTES)
    {
       if (RefreshRates() == TRUE)
       {       
            error = OrderSend(Symbol(), OP_BUY, i_lots, Ask, slip, 0, 0, name,
                              magic_number, 0, clrLimeGreen);
        }
    } 
*/
    last_buy_price = Ask;
    NewOrdersPlaced();
}

void SendSell()
{
    error = OrderSend(Symbol(), OP_SELL, i_lots, Bid, slip, 0, 0, name,
                          magic_number, 0, clrHotPink);
/*
    while (GetLastError() == ERR_OFF_QUOTES)
    {
       if (RefreshRates() == TRUE)
       {       
            error = OrderSend(Symbol(), OP_SELL, i_lots, Bid, slip, 0, 0, name,
                          magic_number, 0, clrHotPink);
        }
    }
*/
    last_sell_price = Bid;
    NewOrdersPlaced();
}
