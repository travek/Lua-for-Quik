socket=require("socket")
host = "localhost"
port = 12345

do_main=true
Server_Date = getTradeDate().date
num_candles = 0
instrument_graph_code="RTS-12.20"
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
   Log = io.open(getScriptPath().."//Log.txt","r+");
   -- Если файл не существует
   if Log == nil then 
      -- Создает файл в режиме "записи"
      Log = io.open(getScriptPath().."//Log.txt","w"); 
      -- Закрывает файл
      Log:close();
      -- Открывает уже существующий файл в режиме "чтения/записи"
      Log = io.open(getScriptPath().."//Log.txt","r+");
   end; 
   -- Встает в конец файла
   Log:seek("end",0);
   -- Добавляет пустую строку-разрыв
   Log:write("\n");
   Log:flush();
   message("Log file open",1)
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
		message(SEC_CODE_FUT_FOR_OPEN.." trading"); 
	else 
		message(SEC_CODE_FUT_FOR_OPEN.." is not trading!!"); 
		return
	end;	
 
	local socket_version=socket._VERSION
	message("Start. Socket version: ".. socket_version,1)
	
	message("Attempting connection to host '" ..host.. "' and port " ..port.. "...",1)
	connection = assert(socket.connect(host, port))
	message("Connected local port!",1)
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
	
	--num_candles = nGetIndexPrevDateFirstCandle(instrument_graph_code)-150  -- Тут нужно переписать, т.к. определять первую свечу дня нужно отсчетом свечей, вычитать нельзя, т.к. есть вечерняя сессия
	begin_date=GetGraphStartDatefromConstraints("iRTS_futures_constraints.conf")
	current_candle_id = GetCandleIndexbyDate(instrument_graph_code, begin_date)
	str_out="Start sending rates from candle: "..tostring(current_candle_id)
	message(str_out)
	ToLog(str_out)
	--PrintIndexDateTimeFC(instrument_graph_code)
	num_candles=0
	if initialization==0 then	
		--local num_candles_1=current_candle_id
		str_out="Start Initialization! Sending Candles from ".. tostring(current_candle_id).." to external tool..."
		message(str_out)
		ToLog(str_out)
		
		--local ttable,ret_number, chart_legend=getCandlesByIndex(instrument_graph_code, 0, current_candle_id, 1)
		--str_out=ReturnStringwithCandleParams(ttable[0])
		--message(str_out)
		--message(tostring(current_candle_id)..";"..tostring(getNumCandles(instrument_graph_code)))
		
		while getNumCandles(instrument_graph_code) ~= num_candles do	
			num_candles_1=getNumCandles(instrument_graph_code)	
			local get_count = num_candles_1- current_candle_id
			local ttable,ret_number, chart_legend=getCandlesByIndex(instrument_graph_code, 0, current_candle_id, get_count)
			
			for i=0, get_count-1 do
				--local full_time=string_full_time(ttable[i].datetime)
				--local full_date=string_full_date(ttable[i].datetime)		
				--local o=ttable[i].open
				--local c=ttable[i].close
				--local h=ttable[i].high
				--local l=ttable[i].low
				--local v=ttable[i].volume
				control_signal=0  --Контрольный символ 0 - передача новой свечи
				export_string=tostring(control_signal)..","..export_string_begin .. ReturnStringwithCandleParams(ttable[i])
				assert(connection:send(export_string.. "\n"))	
				local receive_str=""
				local receive_partial=""
				local connection_receive_status=0
				receive_str,connection_receive_status, receive_partial = connection:receive('*l')
				local total_receive_str= receive_str or receive_partial
				--message(total_receive_str,1)			
			end
			num_candles=num_candles_1
			current_candle_id=current_candle_id+get_count
		end 
		initialization=1
		message("Initialization Completed! Candles processed: "..tostring(num_candles), 1)
		logger:debug("Candles processed: "..tostring(num_candles))
	end
	
	-- Training model; Control_signal==1
	if control_signal~=1 then
		control_signal="Train KRLS"
		export_string=tostring(control_signal)
		assert(connection:send(export_string.. "\n"))
		local receive_str=""
		local receive_partial=""
		local connection_receive_status=0
		receive_str,connection_receive_status, receive_partial = connection:receive('*l')
		local total_receive_str= receive_str or receive_partial
		if string.find(total_receive_str, "KRLS trained!") then
			message("KRLS trained!",1)
		else
			message("ERROR while KRLS training!!",1)
			return
		end		
	end
		
	local re_init=0
	local MayTrade = 1
	--message("Last candle processed: "..)
	
	while do_main do
		num_candles_=getNumCandles(instrument_graph_code)		
		--logger:debug("Current candles #: "..tostring(num_candles_))
		local prediction=0

		-- Проверяем, что после 18-40-00 нет открытой позиции
		if GetCurrentTime()>184000 then
			local current_futures_position=GetCurrentPositionOnFutures(SEC_CODE_FUT_FOR_OPEN)
			--message("Currenttime>184000. Current position: "..tostring(current_futures_position),1)
			if current_futures_position ~= nil and current_futures_position>0 then
				TransactionOnFutures("S",current_futures_position)
				MayTrade = 0
			end
			if current_futures_position ~= nil and current_futures_position<0 then
				TransactionOnFutures("B",current_futures_position)
				MayTrade = 0
			end
			MayTrade = 1	  -- ПОМЕНЯТЬ!!!!		
		end

		if num_candles_> num_candles 
		then
			--------------------
			if re_init==0 then
			-- Запрашиваем у сервера параметры последней свечи
				assert(connection:send("GetLastCandleParams".. "\n"))
				logger:debug("GetLastCandleParams".. "\n")
				receive_str,connection_receive_status, receive_partial = connection:receive('*l')
				local total_receive_str= receive_str or receive_partial
				message(total_receive_str)
				local good_status=CheckLastCandleParams4TwoTools(total_receive_str,instrument_graph_code, num_candles-1)
				message("Check status of prev candle: "..tostring(good_status),1)
				if good_status==-1
				then
				-- дата и время предыдущей свечи совпадают, но параметры нет
					local ttable,ret_number, chart_legend=getCandlesByIndex(instrument_graph_code, 0, num_candles-1, 1)
					for i=0, 0 do
						--local full_time=string_full_time(ttable[i].datetime)
						--local full_date=string_full_date(ttable[i].datetime)		
						--local o=ttable[i].open
						--local c=ttable[i].close
						--local h=ttable[i].high
						--local l=ttable[i].low
						--local v=ttable[i].volume
						control_signal=1   -- Актуализируем последнюю свечу
						export_string=tostring(control_signal)..","..export_string_begin .. ReturnStringwithCandleParams(ttable[i])
						assert(connection:send(export_string.. "\n"))	
						local receive_str=""
						local receive_partial=""
						local connection_receive_status=0
						receive_str,connection_receive_status, receive_partial = connection:receive('*l')
						local total_receive_str= receive_str or receive_partial	
						message(total_receive_str,1)
					end
					good_status=1
				elseif good_status==-2 
				then 
				-- дата ИЛИ время предыдущей свечи НЕ совпадают
					local date_2=splitstring(total_receive_str, ",")[0]
					local time_2=splitstring(total_receive_str, ",")[1]
					local candle2resend=GetCandleIndexbyDateTime(instrument_graph_code, date_2, time_2)
					message("Candle to resend: "..candle2resend,1)
					local resend_cnt=getNumCandles(instrument_graph_code)-candle2resend
					local ttable, ret_number, chart_legend=getCandlesByIndex(instrument_graph_code, 0, candle2resend, resend_cnt)
					--message(tostring(getNumberOf(ttable)))
					
					for i=0, resend_cnt-1 do
						local full_time=string_full_time(ttable[i].datetime)
						local full_date=string_full_date(ttable[i].datetime)		
						local o=ttable[i].open
						local c=ttable[i].close
						local h=ttable[i].high
						local l=ttable[i].low
						local v=ttable[i].volume
						control_signal=1  -- "Resend candle"
						export_string=tostring(control_signal)..","..export_string_begin .. full_date..","..full_time..","..tostring(o)..","..tostring(h)..","..tostring(l)..","..tostring(c)..","..tostring(v)
						assert(connection:send(export_string.. "\n"))	
						local receive_str=""
						local receive_partial=""
						local connection_receive_status=0
						receive_str,connection_receive_status, receive_partial = connection:receive('*l')
						local total_receive_str= receive_str or receive_partial				
						message(total_receive_str,1)
					end
					
					good_status=1	
				end
			
			
				--re_init=1
			end
			--------------------
			control_signal=2
			message("New candle: " .. tostring(num_candles_).." ("..tostring(CandleTimeByIndex(num_candles_))..")",1)
			num_candles = num_candles_		
			local ttable,ret_number,chart_legend=getCandlesByIndex(instrument_graph_code, 0, num_candles-1,1)	
			local full_time=string_full_time(ttable[0].datetime)
			local full_date=string_full_date(ttable[0].datetime)
			local o=ttable[0].open
			local c=ttable[0].close
			local h=ttable[0].high
			local l=ttable[0].low
			local v=ttable[0].volume
			export_string=tostring(control_signal)..","..export_string_begin .. full_date..","..full_time..","..tostring(o)..","..tostring(h)..","..tostring(l)..","..tostring(c)..","..tostring(v)
			
			--message("New candle time: " .. full_date .. " : ".. full_time,1)
			--message(export_string,1)
			--message("New candle price: " .. tostring(o).." : "..tostring(h).." : "..tostring(l).." : "..tostring(c).." : "..tostring(v),1)
			assert(connection:send(export_string.. "\n"))
			local receive_str=""
			local receive_partial=""
			local connection_receive_status=0
			receive_str,connection_receive_status, receive_partial = connection:receive('*l')
			local total_receive_str= receive_str or receive_partial			
			message("Predicted value: "..tostring(total_receive_str),1)						
			prediction=tonumber(total_receive_str)
			if MayTrade==1 then
				-- we can trade
				-- Перебирает строки таблицы "Позиции по клиентским счетам (фьючерсы)", ищет Текущие чистые позиции по инструменту "RIH5"
				local exist_position=0				
				for i = 0, getNumberOf("FUTURES_CLIENT_HOLDING") - 1 do
				-- ЕСЛИ строка по нужному инструменту И чистая позиция не равна нулю ТО
					if getItem("FUTURES_CLIENT_HOLDING",i).sec_code == SEC_CODE_FUT_FOR_OPEN and getItem("FUTURES_CLIENT_HOLDING",i).totalnet ~= 0 then
						local futures_in_position = getItem("FUTURES_CLIENT_HOLDING",i).totalnet
						-- ЕСЛИ текущая чистая позиция < 0 и сигнал BUY, ТО открыта длинная позиция (BUY)
						if futures_in_position ~= nil and futures_in_position < 0 and prediction> 0 
						then 
							--IsBuy = true;
							--BuyVol = getItem("FUTURES_CLIENT_HOLDING",i).totalnet;	-- Количество лотов в позиции BUY				
							TransactionOnFutures("B", 2*futures_in_position)
						end						
						if futures_in_position ~= nil and futures_in_position > 0 and prediction< 0 then 
							--IsBuy = true;
							--BuyVol = getItem("FUTURES_CLIENT_HOLDING",i).totalnet;	-- Количество лотов в позиции BUY				
							TransactionOnFutures("S", 2*futures_in_position)
						end
						exist_position=1
					
					end;
					
				end;
				if exist_position==0 then
					if prediction> 0 then

						--BuyVol = getItem("FUTURES_CLIENT_HOLDING",i).totalnet;	-- Количество лотов в позиции BUY				
						TransactionOnFutures("B", Lots2Buy) --задать параметр
					end	
					if prediction< 0 then 

						--BuyVol = getItem("FUTURES_CLIENT_HOLDING",i).totalnet;	-- Количество лотов в позиции BUY				
						TransactionOnFutures("S", Lots2Buy)  --задать параметр
					end						
				end
								
		--	else
				-- we don't trade
			--	re_init=1
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