# Echo server program
import socket
from datetime import datetime
import shutil
import os

HOST = '127.0.0.1'                 # Symbolic name meaning all available interfaces
PORT = 12345                       # Arbitrary non-privileged port
Gtimestr = datetime.now().strftime("%Y%m%d-%H%M%S")
version=0
strInstrument="RTS"

class rates(object):
    def __init__(self, date, time, open_, high, low, close, vol=0.0):
        self.date=date
        self.time=time
        self.o=open_
        self.h=high
        self.l=low
        self.c=close
        self.vol=vol
        self.vwap=0.0
        self.ohlc=(open_+high+low+close)/4.0
        self.hlc=(high+low+close)/3.0
        self.cStd=0.0
        self.dcStd=0.0
        self.dhcStd=0.0
        self.dclStd=0.0
        self.dhlcStd=0.0        
        self.dohlcStd=0.0        
        self.dhlchStd=0.0        
        self.dhlclStd=0.0        
        self.dhhStd=0.0        
        self.dllStd=0.0
        self.l_hcStd=0.0
        self.l_clStd=0.0
        self.l_dcStd=0.0
        self.l_dc2Std=0.0
        self.l_dc3Std=0.0
        self.l_dc4Std=0.0
        self.l_dhhStd=0.0
        self.l_dhh2Std=0.0
        self.l_dhh3Std=0.0
        self.l_dhh4Std=0.0
        self.l_dllStd=0.0
        self.l_dll2Std=0.0
        self.l_dll3Std=0.0
        self.l_dll4Std=0.0
        self.l_dhlcStd=0.0
        self.l_dhlc2Std=0.0
        self.l_dhlc3Std=0.0
        self.l_dhlc4Std=0.0
        self.l_dohlcStd=0.0
        self.l_dhlchStd=0.0
        self.l_dhlclStd=0.0  
        self.LncStd=0.0
        self.KalmanNextPredict=0.0
        self.DayMax=0.0
        self.DayMin=0.0
        self.DayMaxC=0.0
        self.DayMinC=0.0        
        self.DayOpen=0.0
        self.DayMaxProfit=0.0
        self.DayMaxProfit_pct=0.0
        self.movChange=list()
        self.dmovChange={}
        self.dPosMoveChange={}
        self.dNegMoveChange={}
        self.stochastic={}

class trade_date_constrains(object):
    def __init__(self, fut_code, fut_code_desc, date_begin, date_end, file_name=""):
        self.fut_code=fut_code
        self.fut_code_desc=fut_code_desc
        self.date_begin=date_begin
        self.date_end=date_end
        self.file_name=file_name

def check_version():
    read_version=open('version.txt', 'r')
    ver = read_version.read().splitlines()
    global version
    version=int(ver[0])
    read_version.close()

    set_version = open('version.txt','w')    
    set_version.write(str(version+1))
    set_version.close() 

def strGetLastCandle(v_rates):
    s=str(v_rates[-1].date)+','
    s=s+str(v_rates[-1].time)+','
    s=s+str(v_rates[-1].o)+','
    s=s+str(v_rates[-1].h)+','
    s=s+str(v_rates[-1].l)+','
    s=s+str(v_rates[-1].c)+','
    s=s+str(v_rates[-1].vol)
    s=s+'\n'
    return s

def loadDateConstrains(file_name):
    #"iRTS_futures_constraints.conf"
    lst_tdc=list()
    read_const=open(file_name, 'r')
    print(f"Start reading trade constrains from file {file_name}...")
    for line in read_const:
        l1=line.split(';')
        tdc=trade_date_constrains(str(l1[0]), str(l1[1]), int(l1[2]), int(l1[3]), str(l1[4]).strip())
        lst_tdc.append(tdc)
    read_const.close()
    return lst_tdc

def loadLastArchData(lst_tdc, v_rates, CloseStdLen=2):
    today=int(datetime.today().strftime('%Y%m%d'))
    fn=""
    v_rates=[]
    date_begin=0
    date_end=0
    for i in range(len(lst_tdc)-1, -1, -1):
        if (today>=lst_tdc[i].date_begin and today<lst_tdc[i].date_end):
            fn=lst_tdc[i-1].file_name
            date_begin=lst_tdc[i-1].date_begin
            date_end=lst_tdc[i-1].date_end
            break
    if (len(fn)>1):
        try:
            read_rates=open(fn, 'r')
        except FileNotFoundError:
            print(f"File not found {fn}")
            return v_rates
        
        print(f"Start reading rates from file {fn}...")
        for line in read_rates:
            l1=line.split(',')
            if (l1[2].isdigit() and int(l1[3])<190000 and int(l1[2])<int(date_end)):    #
                rts=rates(int(l1[2]),int(l1[3]), float(l1[4]), float(l1[5]), float(l1[6]), float(l1[7]), float(l1[8]) )
                v_rates.append(rts)
                #calc_DayStats(v_rates)
                #calc_std4Kalman(v_rates, CloseStdLen)       
                #calc_movingChange(v_rates)
                #calc_stochastic(v_rates, [3,4,5,6,7,8,9,10,11,12,13,14,15,16,17])
                #calc_vwap(v_rates)
        read_rates.close()
    return v_rates

def CandleAlreadyExists(v_rates, rate):
    tf=False

    for i in range(0, len(v_rates)):
        if v_rates[i].date==rate.date and v_rates[i].time==rate.time:
            tf=True
            return tf

    return tf

def main():
    lst_tdc=loadDateConstrains("iRTS_futures_constraints.conf")
    v_rates=list()
    v_rates_new=list()
    v_rates=loadLastArchData(lst_tdc, v_rates)
    print(f"Total number of rates read: {len(v_rates)}")
    dict_last=len(v_rates)-1
    print(f"First candle read from file: {v_rates[0].date}, {v_rates[0].time}, {v_rates[0].o}, {v_rates[0].h}, {v_rates[0].l}, {v_rates[0].c}")
    print(f"Last candle read from file:  {v_rates[-1].date}, {v_rates[-1].time}, {v_rates[-1].o}, {v_rates[-1].h}, {v_rates[-1].l}, {v_rates[-1].c}")

    if (1==1):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            print(f"binding to local port: {PORT}...")
            s.bind((HOST, PORT))
            print("Done!")    
            s.listen(1)

            while True:
                print("\nWaiting for new incoming connection...")
                conn, addr = s.accept()
                print('Connected by', addr)
                while True:            
                    try:
                        data = conn.recv(1024)                
                    except:
                        print("Can't receive data. Connection is not alive!")
                        break
                    stringdata = data.decode('utf-8')
                    print('Received: ', stringdata)
            
                    if not data: 
                        print("Breaking... Closing connection!")
                        break
                    if len(stringdata)>0:
                        try:
                            if (stringdata.find("0,RTS", 0, len(stringdata))>=0):   # Инициализация - получение истории свечей
                                l1=stringdata.split(',')
                                if (int(l1[4])<190000):
                                    rts=rates(int(l1[3]),int(l1[4]), float(l1[5]), float(l1[6]), float(l1[7]), float(l1[8]), float(l1[9]) )
                                    if (not CandleAlreadyExists(v_rates, rts)):
                                        v_rates_new.append(rts)                                        
                                    #calc_DayStats(v_rates)
                                    #calc_std4Kalman(v_rates, CloseStdLen)       
                                    #calc_movingChange(v_rates)
                                    #calc_stochastic(v_rates, [3,4,5,6,7,8,9,10,11,12,13,14,15,16,17])
                                    #calc_vwap(v_rates)

                                print("Sending back: ", stringdata)
                                conn.sendall(str.encode(stringdata))
                                continue

                            if (stringdata.find("SendNewCompleteCandleOnServer", 0, len(stringdata))>=0):   # Инициализация - получение истории свечей
                                l1=stringdata.split(',')
                                if (int(l1[4])<190000):
                                    rts=rates(int(l1[3]),int(l1[4]), float(l1[5]), float(l1[6]), float(l1[7]), float(l1[8]), float(l1[9]) )
                                    if (not CandleAlreadyExists(v_rates, rts)):
                                        v_rates.append(rts)                                        
                                    #calc_DayStats(v_rates)
                                    #calc_std4Kalman(v_rates, CloseStdLen)       
                                    #calc_movingChange(v_rates)
                                    #calc_stochastic(v_rates, [3,4,5,6,7,8,9,10,11,12,13,14,15,16,17])
                                    #calc_vwap(v_rates)

                                #print("Sending back: ", stringdata)
                                conn.sendall(str.encode(stringdata))
                                continue

                            if (stringdata.find("1,RTS", 0, len(stringdata))>=0):   # Обновление/Актуализация данных по ранее переданной последней свече и/или получение новых
                                l1=stringdata.split(',')
                                if (int(l1[4])<190000):
                                    rts=rates(int(l1[3]),int(l1[4]), float(l1[5]), float(l1[6]), float(l1[7]), float(l1[8]), float(l1[9]) )
                                    if (v_rates[-1].date==rts.date and v_rates[-1].time==rts.time):
                                        v_rates.pop()
                                    v_rates.append(rts)

                                    #calc_DayStats(v_rates)
                                    #calc_std4Kalman(v_rates, CloseStdLen)       
                                    #calc_movingChange(v_rates)
                                    #calc_stochastic(v_rates, [3,4,5,6,7,8,9,10,11,12,13,14,15,16,17])
                                    #calc_vwap(v_rates)

                                print("Sending back: ", stringdata)
                                conn.sendall(str.encode(stringdata))
                                continue

                            if (stringdata.find("UpdateLastCandleOnServer", 0, len(stringdata))>=0):   # Обновление/Актуализация данных по ранее переданной последней свече и/или получение новых
                                l1=stringdata.split(',')
                                if (int(l1[4])<190000):
                                    rts=rates(int(l1[3]),int(l1[4]), float(l1[5]), float(l1[6]), float(l1[7]), float(l1[8]), float(l1[9]) )
                                    if (v_rates[-1].date==rts.date and v_rates[-1].time==rts.time):
                                        v_rates.pop()
                                    v_rates.append(rts)

                                    #calc_DayStats(v_rates)
                                    #calc_std4Kalman(v_rates, CloseStdLen)       
                                    #calc_movingChange(v_rates)
                                    #calc_stochastic(v_rates, [3,4,5,6,7,8,9,10,11,12,13,14,15,16,17])
                                    #calc_vwap(v_rates)

                                print("Sending back: ", stringdata)
                                conn.sendall(str.encode(stringdata))
                                continue

                            if (stringdata.find("2,RTS", 0, len(stringdata))>=0): # Получение новой незаконченной свечи
                                l1=stringdata.split(',')
                                if (int(l1[4])<190000):
                                    rts=rates(int(l1[3]),int(l1[4]), float(l1[5]), float(l1[6]), float(l1[7]), float(l1[8]), float(l1[9]) )
                                    v_rates.append(rts)
                                    #calc_DayStats(v_rates)
                                    #calc_std4Kalman(v_rates, CloseStdLen)       
                                    #calc_movingChange(v_rates)
                                    #calc_stochastic(v_rates, [3,4,5,6,7,8,9,10,11,12,13,14,15,16,17])
                                    #calc_vwap(v_rates)
                                responce=str(rts.c/100)
                                print("Sending back: ", responce)
                                conn.sendall(str.encode(responce+'\n'))
                                continue

                            if (stringdata.find("AddNewUNcompleteCandleOnServer", 0, len(stringdata))>=0): # Получение новой незаконченной свечи
                                l1=stringdata.split(',')
                                if (int(l1[4])<190000):
                                    rts=rates(int(l1[3]),int(l1[4]), float(l1[5]), float(l1[6]), float(l1[7]), float(l1[8]), float(l1[9]) )
                                    v_rates.append(rts)
                                    #calc_DayStats(v_rates)
                                    #calc_std4Kalman(v_rates, CloseStdLen)       
                                    #calc_movingChange(v_rates)
                                    #calc_stochastic(v_rates, [3,4,5,6,7,8,9,10,11,12,13,14,15,16,17])
                                    #calc_vwap(v_rates)
                                responce=str(rts.c/100)
                                print("Sending back: ", responce)
                                conn.sendall(str.encode(responce+'\n'))
                                continue

                            #if (stringdata.find("Data_send", 0, len(stringdata))>=0):
                            #    conn.sendall(str.encode("Data_received\n"))
                            #    print("Send: ", "Data_received")
                            #    v_rates=v_rates+v_rates_new
                            #    v_rates_new=[]
                            #    continue

                            if(stringdata.find("GetInstrument", 0, len(stringdata))>=0):
                                conn.sendall(str.encode(strInstrument+"\n"))                                
                                continue

                            if(stringdata.find("GetTradeSignal", 0, len(stringdata))>=0):
                                conn.sendall(str.encode("0"+"\n"))                                
                                continue

                            if (stringdata.find("GetLastCandleParams", 0, len(stringdata))>=0):
                                res_out=strGetLastCandle(v_rates)
                                #print("Sending:", res_out)
                                conn.sendall(str.encode(res_out))
                                #print("Send: ", res_out)

                                print(v_rates[0].date, v_rates[0].time, v_rates[0].o, v_rates[0].h, v_rates[0].l, v_rates[0].c, v_rates[0].vol)
                                print(v_rates[-1].date, v_rates[-1].time, v_rates[-1].o, v_rates[-1].h, v_rates[-1].l, v_rates[-1].c, v_rates[-1].vol)

                                #file_1=open('v_rates.out','a')
                                #for i in range(0, len(v_rates)):
                                #    file_1.write("%s, %s, %s, %s, %s, %s\n" % (v_rates[i].date, v_rates[i].time, v_rates[i].o, v_rates[i].h, v_rates[i].l, v_rates[i].c))
                                #file_1.close()

                                continue
                                                           
                        except:
                            print("Connection is not alive. Cleaning all candles for the current day from server data!")
                            cur_day=v_rates[-1].date

                            while v_rates[-1].date==cur_day:
                                v_rates.pop()
                            break


if __name__=="__main__":
    dir_name="arch"
    if (not os.path.exists(dir_name)):
        print(dir_name+" not exists, creating dir")
        os.makedirs('arch')
        print(dir_name+" exists")
    check_version()
    shutil.copyfile('PyTradeServer.py', '.\\arch\\PyTradeServer_'+str(version)+'_'+Gtimestr+'.py')  
    main()


                
