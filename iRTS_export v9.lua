socket=require("socket")
host = "localhost"
port = 12345

do_main=true
Server_Date = getTradeDate().date
num_candles = 0
instrument_graph_code="RTS-12.20"
strInstrument="RTS"
initialization=0
Lots2Buy=0
can_trade_after_190000=0


function getTradeAccount(class_code)
-- Функция возвращает таблицу с описанием торгового счета для запрашиваемого кода класса
	for i=0,getNumberOf ("trade_accounts")-1 do
		local trade_account=getItem("trade_accounts",i)
		if string.find(trade_account.class_codes,class_code,1,1) then 
			message(trade_account.trdaccid,1)
			return trade_account.trdaccid
		end
	end
	return nil
end


CLASS_CODE_FUT          = "SPBFUT";          -- Класс ФЬЮЧЕРСОВ
TRADE_ACC               = getTradeAccount(CLASS_CODE_FUT)     -- Торговый счет
CLIENT_CODE             = TRADE_ACC;     	-- Код клиента
 
SEC_CODE_FUT_FOR_OPEN   = "RIZ0";            -- Код ФЬЮЧЕРСА для открытия
SEC_CODE_FUT_IN_POS     = "";                -- Код ФЬЮЧЕРСА в позиции
OPEN_BALANCE_FUT        = 0;                 -- Баланс позиции по ФЬЮЧЕРСАМ
OPEN_PRICE_FUT          = 0;                 -- Средняя цена открытия позиции по ФЬЮЧЕРСАМ
OPEN_DATE_FUT           = "";                -- Дата открытия позиции по ФЬЮЧЕРСАМ

NotBS_FUT = true;         -- Флаг, что ФЬЮЧЕРСЫ еще не куплены/проданы
OpenPosProcessed = false;  -- Флаг, что открытие позиций обработано
ClosePosProcessed = false; -- Флаг, что закрытие позиций обработано
STATE = nil;               -- Флаг текущего процесса ("OPEN"/"CLOSE")
trans_id_FUT = nil; 	-- ID заявки на фьючерс
OrderNum_FUT = nil; 	-- Номер заявки на фьючерс в торговой системе


require "logging.file"
local logger = logging.file("test%s.log", "%Y-%m-%d")


-- Возвращает таблицу-описание торгового счета по его названию или nil, если торговый счет не обнаружен
--function(trdaccid) return trdaccid == account end

function search_account(account)
	--message("in search_account(account)",1)
	--message(account,1)
	local t_cnt=getNumberOf("trade_accounts")
	for i=0, t_cnt-1 do
		local t=getItem("trade_accounts",i)
		if t.trdaccid==account then
			--message("Find :"..tostring(t.trdaccid),1)
			return t
		end

	end

end

function OnStop(stop_flag)
	do_main=false
	Log:close();
	message("Log file closed",1)
end

function OnInit()
   -- Пытается открыть лог-файл в режиме "чтения/записи"
   file_name=os.date('//Log_%y%m%d_%H%M%S.txt')
   Log = io.open(getScriptPath()..file_name,"r+");
   -- Если файл не существует
   if Log == nil then 
      -- Создает файл в режиме "записи"
      Log = io.open(getScriptPath()..file_name,"w"); 
      -- Закрывает файл
      Log:close();
      -- Открывает уже существующий файл в режиме "чтения/записи"
      Log = io.open(getScriptPath()..file_name,"r+");
   end; 
   -- Встает в конец файла
   Log:seek("end", 0);
   -- Добавляет пустую строку-разрыв
   Log:write("\n");
   Log:flush();
   --message("Log file open",1)
   ToLog("Script started! ")
 
   -- Инициализирует генератор
   math.randomseed(os.date("*t",os.time()).sec); -- Инициализирует генератор псевдослучайных чисел параметром, каждый параметр порождает соответствующую (но одну и ту же) последовательность псевдослучайных чисел.    
end; 

-- Функция для записи в лог действий скрипта
function ToLog(str)
   local datetime = os.date("*t",os.time()); -- Текущие дата/время
   local sec_mcs_str = tostring(os.clock()); -- Секунды с микросекундами 
   local mcs_str = string.sub(sec_mcs_str, sec_mcs_str:find("%.") + 1);   -- Микросекунды
   -- Записывает в лог-файл переданную строку, добавляя в ее начало время с точностью до микросекунд
   Log:write(tostring(datetime.day).."-"
            ..tostring(datetime.month).."-"
            ..tostring(datetime.year).." "
            ..tostring(datetime.hour)..":"
            ..tostring(datetime.min)..":"
            ..tostring(datetime.sec).."."
            ..mcs_str.." "
            ..str.."\n");  -- Записывает в лог-файл
   Log:flush();   -- Сохраняет изменения в лог-файле
end;

function getTimeframe(ident)   -- таймфрем графика в  секундах
   local candles = getCandlesByIndex(ident,0,0,getNumCandles(ident)-1)
   if candles then
      for i = 1,#candles do
         candles[i] = os.time(candles[i].datetime)
      end
      for i = 2,#candles do
         candles[i-1] = candles[i] - candles[i-1]
      end
      return math.min(unpack(candles))
   end
end

function string_full_time(local_date_time)

	local hour_=tostring(local_date_time.hour)
	local min_ = tostring(local_date_time.min)
	local sec_= tostring(local_date_time.sec)
	if local_date_time.hour<10 
	then
		hour_="0"..tostring(local_date_time.hour)
	else
		hour_=tostring(local_date_time.hour)
	end

	if local_date_time.min<10 
	then
		min_="0"..tostring(local_date_time.min)
	else
		min_=tostring(local_date_time.min)
	end

	if local_date_time.sec<10 
	then
		sec_="0"..tostring(local_date_time.sec)
	else
		sec_=tostring(local_date_time.sec)
	end
		
	local string_full_time_ = hour_ .. min_ .. sec_
	return string_full_time_ 
end

function string_full_date(local_date_time)
	local year_=tostring(local_date_time.year)
	local month_ = tostring(local_date_time.month)
	local day_= tostring(local_date_time.day)

	if local_date_time.month<10 
	then
		month_="0"..tostring(local_date_time.month)
	else
		month_=tostring(local_date_time.month)
	end

	if local_date_time.day<10 
	then
		day_="0"..tostring(local_date_time.day)
	else
		day_=tostring(local_date_time.day)
	end
		
	local string_full_time_ = year_ .. month_ .. day_
	return string_full_time_ 
end

function nGetIndexPrevDateFirstCandle(ind)
	local date_=0
	local nIndexPrevDateFirstCandle=-1
	local server_date_ = tonumber(string_full_date(getTradeDate()))
	--logger:debug("server_date_..."..tostring(server_date_))
	local c_number=getNumCandles(ind)
	local t, res, _ = getCandlesByIndex (ind, 0, 0, c_number)  
    for i = c_number-1, 2, -1 do
		date_ = tonumber(string_full_date(t[i].datetime))
		--logger:debug("date_"..tostring(date_))
		prev_date2=tonumber(string_full_date(t[i-1].datetime))
		--logger:debug("prev_date2..."..tostring(prev_date2))
		if date_<server_date_ and date_> prev_date2 then 
			nIndexPrevDateFirstCandle=i
			break 
		end
	end
	--logger:debug("nIndexPrevDateFirstCandle..."..tostring(nIndexPrevDateFirstCandle))
  return nIndexPrevDateFirstCandle
end

function PrintIndexDateTimeFC(graph)
-- Печать номер, день, дата первой свечи предыдущего дня
	local date_=0
	local nIndexPrevDateFirstCandle=-1
	local server_date_ = tonumber(string_full_date(getTradeDate()))
	local c_number=getNumCandles(graph)
	local t, res, _ = getCandlesByIndex (graph, 0, 0, c_number)  
    for i = c_number-1, 2, -1 do
		date_ = tonumber(string_full_date(t[i].datetime))
		prev_date2=tonumber(string_full_date(t[i-1].datetime))
		if date_<server_date_ and date_> prev_date2 then 
			nIndexPrevDateFirstCandle=i
			break 
		end
	end
	t, res, _ = getCandlesByIndex (graph, 0, nIndexPrevDateFirstCandle, 1)
	local full_time=string_full_time(t[0].datetime)
	local full_date=string_full_date(t[0].datetime)

	message(tostring(nIndexPrevDateFirstCandle).."; "..full_date.."; "..full_time,1)
	return 1
end


function main()

	if CheckGraphExist(instrument_graph_code) ~=1
	then
		message("Graph "..instrument_graph_code.." is not opened!!!  Exit from script",1)
		ToLog("Graph "..instrument_graph_code.." is not opened!!!  Exit from script")
		return
	else
		message("Graph "..instrument_graph_code.." is opened!!!",1)
		ToLog("Graph "..instrument_graph_code.." is opened!!!")
	end
	
	if CheckFuturesSetup(CLASS_CODE_FUT,  SEC_CODE_FUT_FOR_OPEN, instrument_graph_code)>0 then
		return 
	end
	-- Проверяем соотношение ACCOUNT и CLASSCODE
	local account_description = search_account(TRADE_ACC)
	if account_description == nil then
		message("Trade account " .. TRADE_ACC .. " not found",1)
		ToLog("Trade account " .. TRADE_ACC .. " not found")
	elseif string.find(account_description.class_codes,CLASS_CODE_FUT) == nil then
		message("Trade account " .. TRADE_ACC .. " doesn't allow to trade " .. CLASS_CODE_FUT,1)
		ToLog("Trade account " .. TRADE_ACC .. " doesn't allow to trade " .. CLASS_CODE_FUT)
	end	
	
	local fut_code_status =  tonumber(getParamEx(CLASS_CODE_FUT,  SEC_CODE_FUT_FOR_OPEN, "STATUS").param_value);
	-- Выводит сообщение о текущем состоянии
	if fut_code_status == 1 then
		str_out=SEC_CODE_FUT_FOR_OPEN.." trading"
		message(str_out);
		ToLog(str_out)
	else
		str_out=SEC_CODE_FUT_FOR_OPEN.." is not trading!!"
		message(str_out); 
		ToLog(str_out)
		return
	end;	
 
	local socket_version=socket._VERSION
	str_out="Start. Socket version: ".. socket_version
	message(str_out,1)
	ToLog(str_out)
	
	str_out="Attempting connection to host '" ..host.. "' and port " ..port.. "..."
	message(str_out,1)
	ToLog(str_out)
	connection = assert(socket.connect(host, port))
	str_out="Connected local port!"
	message(str_out,1)
	ToLog(str_out)
	--assert(connection:send("Good!".. "\n"))
	
	--num_candles = getNumCandles(instrument_graph_code)
	local graph_timeframe = getTimeframe(instrument_graph_code)
	graph_timeframe=graph_timeframe/60
	message("Graph time frame: " .. tostring(graph_timeframe),1)
	if graph_timeframe~=5 then
		message("Graph time is NOT 5 minutes",1)
		return
	end
	local export_string_begin = instrument_graph_code..","..tostring(graph_timeframe)..","
	local export_string=export_string_begin
	local control_signal=-1
	
	begin_date=GetGraphStartDatefromConstraints("iRTS_futures_constraints.conf")
	connection:send("GetInstrument".. "\n")
	local receive_str=""
	local receive_partial=""
	local connection_receive_status=0
	receive_str, connection_receive_status, receive_partial = connection:receive('*l')
	local total_receive_str= receive_str or receive_partial
	if (total_receive_str~=strInstrument) then
		err_msg="Connected to the server that doesn't process RTS instrument"
		message(err_msg)
		ToLog(err_msg)
		return	
	end
	
	current_candle_id=0  ---getNumCandles(instrument_graph_code)
	while do_main do		
		while current_candle_id~=getNumCandles(instrument_graph_code)-1 do
			--1. GetLastCandle from Server 
			-- Запрашиваем у сервера параметры последней свечи
			msg_send="GetLastCandleParams"
			assert(connection:send(msg_send.. "\n"))
			ToLog(msg_send)
			receive_str,connection_receive_status, receive_partial = connection:receive('*l')
			local total_receive_str= receive_str or receive_partial
			ToLog("Received on GetLastCandleParams: "..total_receive_str)
			local split = splitstring(total_receive_str, ",")
			local date_=split[0]
			local time_=split[1]
			local min_candle_index=GetMinCandleIndexBiggerDateTime(instrument_graph_code, date_, time_, 100000, 190000, current_candle_id)
			ToLog("Returned from GetMinCandleIndexBiggerDateTime:"..tostring(min_candle_index))
			ToLog("Number of candles: "..tostring(getNumCandles(instrument_graph_code)))
			ToLog("current_candle_id:"..tostring(current_candle_id))
			
			--2. If Full Candle exists -> Send min Candle to Server
			if(min_candle_index < getNumCandles(instrument_graph_code)-1 and min_candle_index>=0) then
				local ttable, ret_number, chart_legend=getCandlesByIndex(instrument_graph_code, 0, min_candle_index, 1)			
				export_string="SendNewCompleteCandleOnServer"..","..export_string_begin .. ReturnStringwithCandleParams(ttable[0])
				ToLog(export_string)
				assert(connection:send(export_string.. "\n"))	
				local receive_str=""
				local receive_partial=""
				local connection_receive_status=0
				receive_str,connection_receive_status, receive_partial = connection:receive('*l')
				local total_receive_str= receive_str or receive_partial					
				current_candle_id=min_candle_index
			end
			
			if (min_candle_index == getNumCandles(instrument_graph_code)-1 and current_candle_id == getNumCandles(instrument_graph_code)-1) then
			-- Этот кейс возможен при инициализации, когда выгружаем на сервер свечи с графика
				local ttable, ret_number, chart_legend=getCandlesByIndex(instrument_graph_code, 0, min_candle_index, 1)			
				export_string="SendNewCompleteCandleOnServer"..","..export_string_begin .. ReturnStringwithCandleParams(ttable[0])
				ToLog(export_string)
				assert(connection:send(export_string.. "\n"))	
				local receive_str=""
				local receive_partial=""
				local connection_receive_status=0
				receive_str,connection_receive_status, receive_partial = connection:receive('*l')
				local total_receive_str= receive_str or receive_partial		
				current_candle_id=min_candle_index			
			end		
			
			if (min_candle_index == getNumCandles(instrument_graph_code)-1 and current_candle_id < getNumCandles(instrument_graph_code)-1) then
				--1. Check last candle on Server == prev candle on graph. If not then update candle on Server
				if CompareServerCandleVsGraphCandleIdx(total_receive_str, instrument_graph_code, current_candle_id) ~=1 then
					-- Update last candle on Server
					local ttable, ret_number, chart_legend=getCandlesByIndex(instrument_graph_code, 0, current_candle_id, 1)			
					export_string="UpdateLastCandleOnServer"..","..export_string_begin .. ReturnStringwithCandleParams(ttable[0])
					ToLog(export_string)
					assert(connection:send(export_string.. "\n"))	
					local receive_str=""
					local receive_partial=""
					local connection_receive_status=0
					receive_str,connection_receive_status, receive_partial = connection:receive('*l')
					local total_receive_str= receive_str or receive_partial									
				end
				
				-- Get Trade Signal from the server
				if (current_candle_id == getNumCandles(instrument_graph_code)-2) then 
					export_string="GetTradeSignal"
					ToLog(export_string)
					assert(connection:send(export_string.. "\n"))	
					local receive_str=""
					local receive_partial=""
					local connection_receive_status=0
					receive_str,connection_receive_status, receive_partial = connection:receive('*l')
					local total_receive_str= receive_str or receive_partial	
					ToLog("Received trading signal: "..total_receive_str)				
					------
				end			
				
				-- Sending last candle to Server
				local ttable, ret_number, chart_legend=getCandlesByIndex(instrument_graph_code, 0, min_candle_index, 1)			
				export_string="SendNewCompleteCandleOnServer"..","..export_string_begin .. ReturnStringwithCandleParams(ttable[0])
				ToLog(export_string)
				assert(connection:send(export_string.. "\n"))	
				local receive_str=""
				local receive_partial=""
				local connection_receive_status=0
				receive_str,connection_receive_status, receive_partial = connection:receive('*l')
				local total_receive_str= receive_str or receive_partial		
				current_candle_id=min_candle_index	

			end		
					
			
			--2.2 Last candle is already in the database, need to update
			if (min_candle_index == -1) then
				ToLog("In min_candle_index == -1")
				ToLog("current_candle_id:"..tostring(current_candle_id))
				ToLog("getNumCandles(instrument_graph_code):"..tostring(getNumCandles(instrument_graph_code)))
				if (current_candle_id == getNumCandles(instrument_graph_code)-1) then
					-- update candle			
					local ttable, ret_number, chart_legend=getCandlesByIndex(instrument_graph_code, 0, current_candle_id, 1)			
					export_string="UpdateLastCandleOnServer"..","..export_string_begin .. ReturnStringwithCandleParams(ttable[0])
					ToLog(export_string)
					assert(connection:send(export_string.. "\n"))	
					local receive_str=""
					local receive_partial=""
					local connection_receive_status=0
					receive_str,connection_receive_status, receive_partial = connection:receive('*l')
					local total_receive_str= receive_str or receive_partial								
				end		
			
			end				
		
		end
	
	end
	
	message("Stop",1)
end 



-- Функция 
function TransactionOnFutures(BS_operation, BS_quantity)
	--message("Function TransactionOnFutures() is disabled now! Comment return from the top of the function")
	--return 0
	if can_trade_after_190000==0
	then
		message("Can't trade after 19:00")
		ToLog("Can't trade after 19:00")
		return 
	end
	
	if not (BS_operation =="B" or BS_operation =="S")
	then
		message("wrong B/S operation code received: "..tostring(BS_operation),1)
		return
	end

   ToLog("OpenPosition"); -- Записывает в лог-файл
   -- Устанавливает флаг текущего процесса в ОТКРЫТИЕ позиции
   
   -- Сбрасывает флаг обработки открытия позиций
   OpenPosProcessed = false;
 
   -- Генерирует случайный ID транзакции на продажу ФЬЮЧЕРСОВ
   trans_id_FUT = math.random(1,9999);
   ToLog("trans_id_FUT = "..tostring(trans_id_FUT)); -- Записывает в лог-файл
   -- Заполняет структуру для отправки транзакции на продажу ФЬЮЧЕРСОВ
   local trn_comment=""
   if BS_operation == "B" then
		trn_comment="Покупка фьючерсов скриптом"
		STATE = "BUY";
   end
   if BS_operation == "S" then
		trn_comment="Продажа фьючерсов скриптом"
		STATE = "SELL";
   end   
   -- ["PRICE"]      = tostring(getParamEx(CLASS_CODE_FUT, SEC_CODE_FUT_FOR_OPEN, "bid").param_value - 10*getParamEx(CLASS_CODE_FUT, SEC_CODE_FUT_FOR_OPEN, "SEC_PRICE_STEP").param_value), -- по цене, заниженной на 10 мин. шагов цены
   local string_BS_quantity=tostring(BS_quantity)
   local Transaction={
      ["TRANS_ID"]   = tostring(trans_id_FUT),
      ["ACTION"]     = "NEW_ORDER",
      ["CLASSCODE"]  = CLASS_CODE_FUT,
      ["SECCODE"]    = SEC_CODE_FUT_FOR_OPEN,
      ["OPERATION"]  = BS_operation, -- продажа (SELL)
      ["TYPE"]       = "M", -- по рынку (MARKET)
      ["QUANTITY"]   = string_BS_quantity, -- количество
      ["ACCOUNT"]    = TRADE_ACC,
      ["PRICE"]      = "0",
      ["COMMENT"]    = trn_comment
   }
   
   -- Флаг, что ФЬЮЧЕРСЫ еще не проданы
   NotBS_FUT = true;
   local Result = sendTransaction(Transaction);
   ToLog("Заявка "..BS_operation.." отправлена"); -- Записывает в лог-файл
   ToLog("Result = "..Result); -- Записывает в лог-файл
   -- ЕСЛИ функция вернула строку диагностики ошибки, ТО значит транзакция не прошла
   if Result ~= "" then
      -- Выводит сообщение с ошибкой
      message(BS_operation.." операция не удалась!\nОШИБКА: "..Result);
      -- Завершает выполнение функции
      return(0);
   end;   
end;

--- Функция вызывается терминалом QUIK при получении новой заявки или при изменении параметров существующей заявки.
function OnOrder(order)
   -- ЕСЛИ текущий процесс ОТКРЫТИЕ позиции, ТО
   if STATE == "BUY" then

      -- Если исполнилась заявка на продажу ФЬЮЧЕРСОВ
      if order.trans_id == trans_id_FUT and order.balance == 0 and NotBS_FUT then
         ToLog("OnOrder");
         ToLog("trans_id = "..tostring(order.trans_id).." balance = "..tostring(order.balance).." order_num = "..tostring(order.order_num));
         -- Меняет значение флага
         NotBS_FUT = false;
         ToLog("ФЬЮЧЕРСЫ куплены"); -- Записывает в лог-файл
         -- Запоминает номер заявки на фьючерсы в торговой системе
         OrderNum_FUT = order.order_num;
      end;
   elseif  STATE == "SELL" then -- ЕСЛИ текущий процесс ЗАКРЫТИЕ позиции, ТО   
 
      -- Если исполнилась заявка на покупку ФЬЮЧЕРСОВ
      if order.trans_id == trans_id_FUT and order.balance == 0 and NotBS_FUT then
         ToLog("OnOrder");
         ToLog("trans_id = "..tostring(order.trans_id).." balance = "..tostring(order.balance).." order_num = "..tostring(order.order_num));
         -- Меняет значение флага
         NotBS_FUT = false;
         ToLog("ФЬЮЧЕРСЫ проданы"); -- Записывает в лог-файл
         -- Запоминает номер заявки на фьючерсы в торговой системе
         OrderNum_FUT = order.order_num;
      end;
   end;
end;

function GetCurrentTime()
	local num_candles_2=getNumCandles(instrument_graph_code)
	local tt,ret_number,chart_legend=getCandlesByIndex(instrument_graph_code, 0, num_candles_2-1, 1)
	local full_time=tonumber(string_full_time(tt[0].datetime))
	return full_time
end

function GetCurrentPositionOnFutures(futures_code)
	local current_position = nil
	for i = 0, getNumberOf("FUTURES_CLIENT_HOLDING") - 1 do
		-- ЕСЛИ строка по нужному инструменту И чистая позиция не равна нулю ТО
		if getItem("FUTURES_CLIENT_HOLDING",i).sec_code == futures_code then 
			current_position = getItem("FUTURES_CLIENT_HOLDING",i).totalnet			
			break
		end
	end
	return current_position
end

function CheckGraphExist(graph)
	local num_candles_3=getNumCandles(graph)
	local exists=0
	if num_candles_3 ~= nil and num_candles_3>0
	then
		exists=1
	else
		exists=0
	end
	return exists

end

function GetCandleIndexbyDateTime(graph_code_, date_, time_)
	--message(date_..","..time_,1)
	local candles_cnt=getNumCandles(graph_code_)
	local tt,ret_number,chart_legend=getCandlesByIndex(graph_code_, 0, 0, candles_cnt)
	local index=-1
	for i=candles_cnt-1, 0, -1 do
		local full_time=string_full_time(tt[i].datetime)
		local full_date=string_full_date(tt[i].datetime)
		--message(full_date..","..full_time,1)
		if date_== full_date and time_==full_time
		then
			return i
		end
	
	end
	return -1

end

function GetMinCandleIndexBiggerDateTime(graph_code_, date_, time_, min_time_constraint, max_time_constraint, start_from)
	ndatetime=tonumber(date_..time_)
	local candles_cnt=getNumCandles(graph_code_)
	local tt,ret_number,chart_legend=getCandlesByIndex(graph_code_, 0, 0, candles_cnt)
	local index=-1
	for i=start_from, candles_cnt-1 do
		local full_time=string_full_time(tt[i].datetime)
		local full_date=string_full_date(tt[i].datetime)
		if tonumber(full_date)>=tonumber(date_) and (tonumber(full_time)<max_time_constraint and tonumber(full_time)>=min_time_constraint) then 			
			local nfull_datetime=tonumber(full_date..full_time)
			--message(full_date..","..full_time,1)
			if nfull_datetime>ndatetime then
				return i
			end
		end 
	
	end
	return -1

end

function GetCandleIndexbyDate(graph_code_, date_)
	-- Get Index of the first candle of a day date_
	message(date_,1)
	local candles_cnt=getNumCandles(graph_code_)
	local tt,ret_number,chart_legend=getCandlesByIndex(graph_code_, 0, 0, candles_cnt)
	local index=-1
	for i=0, candles_cnt-1 do
		--local full_time=string_full_time(tt[i].datetime)
		local full_date=string_full_date(tt[i].datetime)
		--message(full_date..","..full_time,1)
		if tonumber(date_) == tonumber(full_date)
		then
			return i
		end
	
	end
	return -1

end

function splitstring(inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={} ; i=0
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                t[i] = str
                i = i + 1
        end
        return t
end

function CheckLastCandleParams4TwoTools(total_receive_str, graph_code, c_index)
	local split = splitstring(total_receive_str, ",")
	--message("String received: "..total_receive_str,1)
	local date_=split[0]
	local time_=split[1]
	local o_=split[2]
	local h_=split[3]
	local l_=split[4]
	local c_=split[5]
	local v_=split[6]
	
	local ttable,ret_number,chart_legend=getCandlesByIndex(graph_code, 0, c_index,1)	
	local full_time=string_full_time(ttable[0].datetime)
	local full_date=string_full_date(ttable[0].datetime)
	local o=ttable[0].open
	local c=ttable[0].close
	local h=ttable[0].high
	local l=ttable[0].low
	local v=ttable[0].volume	
	local result=0
	if date_ ~= full_date or time_~=full_time
	then
		return -2
	end
	
	if date_ == full_date and time_==full_time 
	then
		if o_ ~=o or h_ ~=h or l_~=l or c_~=c or v_~=v
		then 		
			return -1
		end
	end	
	return 1
end

function CompareServerCandleVsGraphCandleIdx(total_receive_str, graph_code, c_index)
	local split = splitstring(total_receive_str, ",")
	local date_=split[0]
	local time_=split[1]
	local o_=split[2]
	local h_=split[3]
	local l_=split[4]
	local c_=split[5]
	local v_=split[6]
	
	local ttable,ret_number,chart_legend=getCandlesByIndex(graph_code, 0, c_index,1)	
	local full_time=string_full_time(ttable[0].datetime)
	local full_date=string_full_date(ttable[0].datetime)
	local o=ttable[0].open
	local c=ttable[0].close
	local h=ttable[0].high
	local l=ttable[0].low
	local v=ttable[0].volume	
	local result=0
	
	if date_ == full_date and time_==full_time and tonumber(o_) == tonumber(o) and tonumber(h_) == tonumber(h) and tonumber(l_) == tonumber(l) and tonumber(c_) == tonumber(c) and tonumber(v_) == tonumber(v) then
		return 1
	end
	
	return 0
end


function ReturnStringwithCandleParams(ttable)
	local res_string=""
	local full_time=string_full_time(ttable.datetime)
	local full_date=string_full_date(ttable.datetime)		
	local o=ttable.open
	local c=ttable.close
	local h=ttable.high
	local l=ttable.low
	local v=ttable.volume
	
	res_string=full_date..","..full_time..","..tostring(o)..","..tostring(h)..","..tostring(l)..","..tostring(c)..","..tostring(v)	
	
	return res_string
end

function CandleTimeByIndex(index)
	local ttable,ret_number,chart_legend=getCandlesByIndex(instrument_graph_code, 0, index-1,1)	
	local full_time=string_full_time(ttable[0].datetime)

	return full_time
end

function GetPrevDate(instrument_graph_code)
	local prev_date=""
	local num_candles=getNumCandles(instrument_graph_code)
	local ttable, ret_number, chart_legend=getCandlesByIndex(instrument_graph_code, 0, num_candles-1, 1)		
	local full_date=string_full_date(ttable[0].datetime)		
	local CurrentDate=full_date
	local idx_candle=num_candles-2
	
	while idx_candle>=0 do
		local ttable, ret_number, chart_legend=getCandlesByIndex(instrument_graph_code, 0, idx_candle, 1)		
		local full_date=string_full_date(ttable[0].datetime)
		if (full_date~=CurrentDate) then
			prev_date=full_date
			return full_date
		end		
		idx_candle=idx_candle-1
		if idx_candle<0 then
			return CurrentDate
		end
	end
	
end

function GetIndexBeginningOfDay(instrument_graph_code, day)
	local search_index=-1
	local num_candles=getNumCandles(instrument_graph_code)	
	
	for i=0, num_candles-1 do
		local ttable, ret_number, chart_legend=getCandlesByIndex(instrument_graph_code, 0, i, 1)		
		local full_date=string_full_date(ttable[0].datetime)		
		if full_date==day then
			search_index=i
			break
		end	
	end
	return search_index
end

function GetIndexEndOfDay(instrument_graph_code, day)
	local search_index=-1
	local num_candles=getNumCandles(instrument_graph_code)
	
	local ttable, ret_number, chart_legend=getCandlesByIndex(instrument_graph_code, 0, num_candles-1, 1)		
	local full_date=string_full_date(ttable[0].datetime)

	if (full_date==day) then
		search_index=num_candles-1
		return search_index
	end
	
	index_scan=num_candles-1
	while index_scan>=0 do
		ttable, ret_number, chart_legend=getCandlesByIndex(instrument_graph_code, 0, index_scan, 1)		
		full_date=string_full_date(ttable[0].datetime)		
		if full_date==day then
			search_index=index_scan
			return search_index
		end
		index_scan=index_scan-1		
	end
	return search_index
end

function GetDateByIndex(instrument_graph_code, idx)
	local day=""
	local num_candles=getNumCandles(instrument_graph_code)
	local ttable, ret_number, chart_legend=getCandlesByIndex(instrument_graph_code, 0, idx, 1)		
	local full_date=string_full_date(ttable[0].datetime)		
	day=full_date
	return day
end

function CheckFuturesSetup(CLASS_CODE_FUT, SEC_CODE_FUT_FOR_OPEN, instrument_graph_code)
-- Check that futures code (short name) in TTP == futures code in opened graph
	rts_ptype=tostring(getParamEx(CLASS_CODE_FUT, SEC_CODE_FUT_FOR_OPEN, "shortname").param_type)
	rts_name=tostring(getParamEx(CLASS_CODE_FUT, SEC_CODE_FUT_FOR_OPEN, "shortname").param_value)
	rts_ok=tostring(getParamEx(CLASS_CODE_FUT, SEC_CODE_FUT_FOR_OPEN, "shortname").result)
	rts_image=tostring(getParamEx(CLASS_CODE_FUT, SEC_CODE_FUT_FOR_OPEN, "shortname").param_image)
	
	if rts_ptype == "3" then
		if rts_image==instrument_graph_code then			
			return 0
		else
			message("Graph is opened for wrong futures code! Please check code names...")
			return 1
		end
	end
	
	return 0
	
end

function GetGraphStartDatefromConstraints(fn)
	local date_constraints = {}
	local start_date=""
	for line in io.lines(fn) do
		cnt=0
		for w in line:gmatch("(.-);") do 
			if cnt==0 then fut_code=w end
			if cnt==1 then fut_desc=w end
			if cnt==2 then date_begin=tonumber(w) end
			if cnt==3 then date_end=tonumber(w) end			
			--message(w) 
			cnt=cnt+1
		end
		
		--local fut_code, fut_desc, date_begin, date_end, file_name = line:match("(%w+);(.+);(%d+);(%d+);(.+)")
		--date_begin=tonumber(date_begin)
		--date_end=tonumber(date_end)
		curr_date=tonumber(string_full_date(getTradeDate()))
		str_out=tostring(fut_code)..";"..tostring(date_begin)..";"..tostring(date_end)..";"..tostring(curr_date)..";"
		ToLog(str_out)
		--message(str_out)
		start_date=date_begin
		if (curr_date>=date_begin and curr_date<=date_end) then		
			str_out="Start date fro graph: "..tostring(start_date)
			ToLog(str_out)
			--message(str_out)
			return start_date
		end		

	end
	return start_date

end