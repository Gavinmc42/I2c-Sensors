unit Sensors;

{$mode objfpc}{$H+}

interface

uses
  RaspberryPi,
  GlobalConfig,
  GlobalConst,
  GlobalTypes,
  Platform,
  Threads,
  Classes,
  Console,
  Devices,
  Serial,
  I2C,
  GraphicsConsole,
  Framebuffer,
  math,
  SysUtils,
  Logs,
  Ultibo;


const

  //i2c chip addresses
  PCA9544 = $70;

  PSoCLCD = $58;
  RTC = $68;
  TMP421 = $4c;
  TMP102 = $48;

  LTC2945_400A = $6f;
  LTC2945_Wind = $6e;
  LTC2945_100A = $6d;
  LTC2945_DC1 = $6b;
  LTC2945_DC2 = $6c;
  LTC2945_Bat = $6a;

  MMA8453 = $1c;

  LSM303A = $19;
  LSM303M = $1e;

  //i2c register addresses

  i2c_ch0 = $04;
  i2c_ch1 = $05;
  i2c_ch2 = $06;
  i2c_ch3 = $07;

  VinMSB = $1E;
  VinLSB = $1F;

  SenseMSB = $14;
  SenseLSB = $15;

  PowerMSB2 = $05;
  PowerMSB1 = $06;
  PowerLSB = $07;

  Status = $00;
  AccxM = $01;
  AccxL = $02;
  AccyM = $03;
  AccyL = $04;
  AcczM = $05;
  AcczL = $06;
  IDreg = $0d;

var

   Console2 : TWindowHandle;
   I2CDevice:PI2CDevice;

   Temp:Word;
   i2caddress:Word;
   i2cregister:Byte;
   Count:LongWord;
   Data:LongWord;
   Dataarray:  array of LongWord;
   Hexadd:String;
   Hexreg:String;
   Hexdata:String;

   i: integer;

   Vhib, Vlob: LongWord;
   Shib, Slob: LongWord;
   Phib, Pmsb, Plob: LongWord;

   Vsolar, Ssolar,Psolar: LongWord;
   Vleft, Sleft, Pleft: LongWord;
   Vright, Sright, Pright: LongWord;
   Vwind, Swind, Pwind: LongWord;
   V1kw, S1kw, P1kw: LongWord;
   V4kw, S4kw, P4kw: LongWord;

   p1w, s1w, v1w : Real;
   p1s, s1s, v1s : Real;
   p2, s2, v2: Real;
   p3, s3, v3 : Real;
   p4, s4, v4 : Real;
   p5, s5, v5 : Real;
   p6, s6, v6 : Real;

   Ax, Ay, Az, Mx, My, Mz , temph, templ, PitchC, RollC: integer;
   AccX, AccY, AccZ, Pitch, Roll, Polar, Heading, Angle, SinB, CosB, SinP, CosP : Real;
   MagX, MagY, MagZ  : Real;

   tmp, itemp, otemp, stemp, TempC: Real;
   acch, accl, magh, magl, hitmp, lotmp : LongWord;

   Totalin, Totalout: Real;


   Characters:String;

procedure initi2c();
procedure readsensors();
procedure readsensorstest();
procedure i2cdetect();

implementation



 function i2cwrite(i2caddress: Word; i2cdata: Byte): LongWord;
     begin
     Count:= 1;
     Data := i2cdata;
     if I2CDeviceWrite(I2CDevice,i2caddress, @Data,SizeOf(Byte),Count) = ERROR_SUCCESS then
          begin
              Result:=Data;
    
          end
      else
          begin
            Hexadd:=IntToHex(i2caddress, 2);
            Hexreg:=IntToHex(i2cregister, 2);
      
            if Debug = 2 then
                 begin
                     Log(' i2c write error at 0x' + Hexadd + ' 0x' + Hexreg );
            
                 end;
              Exit;
          end;

     end;

function i2cwritewrite(i2caddress: Word; i2cregister,i2cdata: Byte): LongWord;
     begin
     Count:= 1;
     Data := i2cdata;
     if I2CDeviceWriteWrite(I2CDevice,i2caddress, @i2cregister, Count, @Data,SizeOf(Byte),Count) = ERROR_SUCCESS then
          begin
              Result:=Data;
           
          end
      else
          begin
            Hexadd:=IntToHex(i2caddress, 2);
            Hexreg:=IntToHex(i2cregister, 2);
            Hexdata:=IntToHex(i2cregister, 2);
          
            if Debug = 2 then
                 begin
                     Log(' i2c writewrite error at 0x' + Hexadd + ' 0x' + Hexreg );
                  
                 end;
              Exit;
          end;

     end;


function i2cread(i2caddress: Word; i2cregister: Byte): LongWord;
  begin
  Count:=1;
  if I2CDeviceWriteRead(I2CDevice,i2caddress,@i2cregister, Count, @Data,SizeOf(Byte),Count) = ERROR_SUCCESS then
       begin
           Result:=Data;
           Hexadd:=IntToHex(i2caddress, 2);
           Hexreg:=IntToHex(i2cregister, 2);
           Hexdata:=IntToHex(Data, 2);
 
           if Debug = 2 then
                begin
                    Log(' 0x' + Hexadd + ' 0x' + Hexreg + ' 0x' + Hexdata );
                end;
       end
   else
       begin
           Hexadd:=IntToHex(i2caddress, 2);
           Hexreg:=IntToHex(i2cregister, 2);
           if Debug = 2 then
                begin
                    Log(' 0x' + Hexadd + ' 0x' + Hexreg + ' 0x' + Hexdata );
                end;
           Exit;

       end;

  end;

procedure i2cdump(i2caddress: Word; numCount: LongWord);
  begin

     for i := 0 to numCount do
        begin
          Count:=1;
          i2cregister:= i;
          if I2CDeviceWriteRead(I2CDevice,i2caddress,@i2cregister, Count, @Data,SizeOf(Byte),Count) = ERROR_SUCCESS then
             begin
                 Hexadd:=IntToHex(i2cregister, 2);
                 Hexdata:=IntToHex(Data, 2);
              end
          else
              begin
                 Hexadd:=IntToHex(i2caddress, 2);
                 Hexdata:=IntToHex(i2cregister, 2);
                 if Debug = 2 then
                     begin
                         Log('i2c Dump error at 0x' + Hexadd + ' 0x' + Hexdata );
                      end;
              end;
        end;
    end;

procedure i2cdetect();
   begin

        for i2caddress:=$01 to $7f do
          begin
              Count:=1;
              i2cregister:=0;
              if I2CDeviceWriteRead(I2CDevice,i2caddress,@i2cregister, Count, @Data,SizeOf(Byte),Count) = ERROR_SUCCESS then
                 begin
                     ConsoleWindowWriteLn(Console2, '');
                     Hexadd:=IntToHex(i2caddress, 2);
                     Hexdata:=IntToHex(Data, 2);
                     if Debug = 3 then
                         begin
                              Log(' 0x' + Hexadd + ' 0x' + Hexdata );
                              Log( ' i2c address=0x' + Hexadd + ' data=');
                         end;
                     for i2cregister:=$00 to $0f do
                         begin
                             sleep(20);
                             if I2CDeviceWriteRead(I2CDevice,i2caddress,@i2cregister,Count,@Data,SizeOf(Byte),Count) = ERROR_SUCCESS then
                                 begin
                                      Hexdata:=IntToHex(Data, 2);
                                      if Debug = 3 then
                                          begin
                                               Log( ' 0x' + Hexdata );

                                          end;
                                 end;
                         end;
                     LogLn( ' ');
   
                 end
              else
                 begin
                     Hexadd:=IntToHex(i2caddress, 2);
                     if Debug = 3 then
                         begin
                              Log( ' 0x' + Hexadd + '_na_' );

                         end;
                     sleep(20);
                     if (i2caddress + 1) MOD 16 = 0 then
                        begin
                             if Debug = 3 then
                              begin
                                   LogLn(  '');

                              end;
                        end;

                 end;
          end;

   end;

procedure LCDwrite(LCDaddr, LCDdata : Byte);
   begin
        i2cwritewrite(PSoCLCD, LCDaddr, LCDdata);
   end;

procedure LCDclear();
   begin
      for i := 1 to 17 do
         begin
           LCDwrite(i, $20);
         end;
      i2cwritewrite(PSoCLCD, $00, $02);
      MillisecondDelay(50);

      for i := 1 to 17 do
         begin
            LCDwrite(i, $20);
         end;
      i2cwritewrite(PSoCLCD, $00, $03);
      MillisecondDelay(50);

   end;

procedure LCDstring();
   begin
      i := $01;
   end;


function readtemp(): Real;
   begin

     i2caddress := TMP102;
     Count:=1;
     i2cregister:= i;
     if I2CDeviceWriteRead(I2CDevice,i2caddress,@i2cregister, Count, @Data,SizeOf(Word),Count) = ERROR_SUCCESS then
        begin
            lotmp := Data Div 256;
	    hitmp := Data Mod 256;
            tmp  := hitmp + (0.0625*(lotmp/16));
            Result:= tmp;
            MillisecondDelay(20);
        end
     else
         Result := 20.3;
     if Debug = 2 then
         LogLn('Reading Temp__' + FloatToStr(Result));
   end;

procedure readLSM303Ax();
   begin

      acch := i2cread(LSM303A, $28);
      accl := i2cread(LSM303A, $29);
      Ax := (acch << 8) + accl;
      if Ax >= 32768 then
         begin
	    Ax := Ax - 65536;
         end;


      if Debug = 2 then
         LogLn('Reading LSM303Ax__' + IntToStr(Ax));

   end;

procedure readLSM303Ay();
   begin

      acch := i2cread(LSM303A, $2A);
      accl := i2cread(LSM303A, $2B);
      Ay := (acch << 8) + accl;
      if Ay >= 32768 then
         begin
  	    Ay := Ay - 65536;
         end;


      if Debug = 2 then
         LogLn('Reading LSM303Ay__' + IntToStr(Ay));

   end;

procedure readLSM303Az();
   begin


      acch := i2cread(LSM303A, $2C);
      accl := i2cread(LSM303A, $2D);
      Az := (acch << 8) + accl;
      if Az >= 32768 then
         begin
  	    Az := Az - 65536;
         end;


      if Debug = 2 then
          LogLn('Reading LSM303Az__' + IntToStr(Az));
   end;

procedure readLSM303Mx();
   begin

      acch := i2cread(LSM303M, $03);
      accl := i2cread(LSM303M, $04);
      Mx := (acch << 8) + accl;
      if Mx >= 32768 then
         begin
  	    Mx := Mx - 65536;
         end;


      if Debug = 2 then
         LogLn('Reading LSM303Mx__' + IntToStr(Mx));
   end;

procedure readLSM303My();
   begin


      acch := i2cread(LSM303M, $05);
      accl := i2cread(LSM303M, $06);
      My := (acch << 8) + accl;
      if My >= 32768 then
         begin
  	    My := My - 65536;
         end;

      if Debug = 2 then
         LogLn('Reading LSM303My__' + IntToStr(My));
   end;
procedure readLSM303Mz();
   begin

      acch := i2cread(LSM303M, $07);
      accl := i2cread(LSM303M, $08);
      Mz := (acch << 8) + accl;
      if Mz >= 32768 then
         begin
  	    Mz := Mz - 65536;
         end;


      if Debug = 2 then
        LogLn('Reading LSM303Mz__' + IntToStr(Mz));

   end;

procedure readLSM303Temp();
   begin
      temph := i2cread(LSM303M, $31);
      templ := i2cread(LSM303M, $32);
      temp := (temph * 256) + templ;
      if Debug = 2 then
         LogLn('Reading LSM303Mz__' + IntToStr(temp));

   end;

 procedure readMMA8453();
   begin

      acch := i2cread(MMA8453, AccxM);
      accl := i2cread(MMA8453, AccxL);
      aX := 256 * acch + accl;

      acch := i2cread(MMA8453, AccyM);
      accl := i2cread(MMA8453, AccyL);
      aY := 256 * acch + accl;

      acch := i2cread(MMA8453, AcczM);
      accl := i2cread(MMA8453, AcczL);
      aZ := 256 * acch + accl;

      if aX >= 32768 then
         aX := aX - 65536;
      if aY >= 32768 then
         aY := aY - 65536;
      if aZ >= 32768 then
         aZ := aZ - 65536;

      AccX := aX div 16384;
      AccY := aY div 16384;
      AccZ := aZ div 16384;

      if Debug = 2 then
         LogLn('Reading MMA8453__');


   end;



 procedure initLSM303();
   begin
       if Debug = 1 then
           LogLn('Initializing LSM303');

       i2cwritewrite(LSM303A, $20, $47);
       i2cwritewrite(LSM303A, $23, $48);
       i2cwritewrite(LSM303M, $00, $94);    //LSM303DLHC     30Hz
       i2cwritewrite(LSM303M, $02, $00);

   end;

 procedure initMMA8453();
   begin
      if Debug = 1 then
          LogLn('Initializing MMA8453');

      i2cwritewrite(MMA8453, $0e, $00);
      i2cwritewrite(MMA8453, $2b, $00);
      i2cwritewrite(MMA8453, $2a, $05);

   end;


procedure PCA9544Ch(i2cdata: Byte);
   begin
       i2cwrite(PCA9544, i2cdata);

   end;


procedure initi2c();
  begin
      Console2 := ConsoleWindowCreate(ConsoleDeviceGetDefault,CONSOLE_POSITION_TOP, False);

      BCM2708I2C_COMBINED_WRITEREAD := True;

      I2CDevice:=PI2CDevice(DeviceFindByDescription('BCM2835 BSC1 Master I2C'));

      LogLn('');
      if I2CDeviceStart(I2CDevice,100000) <> ERROR_SUCCESS then
            begin
               if Debug = 1 then
                   begin                        //Error Occurred
                        LogLn('i2c error!!');
                   end;
            end
          else
            begin
                if Debug = 1 then
                   begin
                        LogLn('i2c initialised');
                   end;
            end;


      sleep(100);
      //i2cdetect;

      initMMA8453;
      initLSM303;

  end;

procedure readsensorstest();
   begin
     if Debug = 1 then
         begin
         LogLn( ' ');
         LogLn('Reading sensors');

         end;
      //compass and level
      //i2cdetect;


      //PCA9544Ch(i2c_ch2);
      //readLSM303Ax;
      //readLSM303Ay;
      //readLSM303Az;
      //readLSM303Mx;
      //readLSM303My;
      //readLSM303Mz;

   end;

procedure readsensors();
   begin
      if Debug = 1 then
         LogLn(' ');
         LogLn('Reading sensors ');

      //inside temp
      PCA9544Ch(i2c_ch1);
      itemp := readtemp();

      //outsde temp
      PCA9544Ch(i2c_ch2);
      otemp := readtemp();

      //solarpanel temp
      PCA9544Ch(i2c_ch3);
      stemp := readtemp();
      //compass and level

      PCA9544Ch(i2c_ch2);

      if Debug = 2 then
            LogLn('LSM303 ok ');

      readLSM303Ax;
      readLSM303Ay;
      readLSM303Az;
      readLSM303Mx;
      readLSM303My;
      readLSM303Mz;


      AccX := Ax / 16384;
      AccY := Ay / 16384;
      AccZ := Az / 16384;

      MagX := Mx / 16384;
      MagY := My / 16384;
      MagZ := Mz / 16384;


      if Debug = 1 then
         LogLn('Accel AccX= ' + FloatToStr(AccX) + ', AccY= ' + FloatToStr(AccY) + ', AccZ= ' + FloatToStr(AccZ));
         LogLn('Mag MagX= ' + FloatToStr(Magx) + '  MagY= ' + FloatToStr(MagY) + '  MagZ= ' + FloatToStr(MagZ));


      Pitch := 180* ArcTan(AccX/sqrt((AccY*AccY) + (AccZ*AccZ)))/3.14159;
      Roll := 180* ArcTan(AccY/sqrt((AccX*AccX) + (AccZ*AccZ)))/3.14159;

      PitchC := round(Pitch);
      RollC := round(Roll);

      if PitchC >= 12 then
         PitchC := 0;

      if RollC >= 12 then
         RollC := 0;

      if PitchC < -12 then
         PitchC := -12;

      if RollC < -12 then
         RollC := -12;

      if Debug = 1 then
         LogLn('Bubble ' + IntToStr(PitchC) + ', ' + IntToStr(RollC));

      Polar := ArcTan2(MagZ, MagX);
      //Polar := 35;

      SinB := sin(Polar);
      CosB := cos(Polar);
      Heading := 180 * Polar/3.14159;

      if Heading < 0  then
          Heading := Heading + 360;

      if Debug = 1 then
         LogLn('Compass '  + ' Polar= ' + FloatToStr(Polar) + ' Headling= ' +  FloatToStr(Heading));


      //tilt
      PCA9544Ch(i2c_ch3);
      readMMA8453;
      Angle := 45;

      //Pitch := 180* ArcTan(AccX/sqrt((AccY*AccY) + (AccZ*AccZ)))/3.14159;
      //Roll := 180* ArcTan(AccY/sqrt((AccX*AccX) + (AccZ*AccZ)))/3.14159;

      Pitch := 45;

      SinP := sin(Pitch * 3.14159/180);
      CosP := cos(Pitch * 3.14159/180);


      PCA9544Ch(i2c_ch0);
      //solar
      Vhib := i2cread(LTC2945_Bat, VinMSB);
      Vlob := i2cread(LTC2945_Bat, VinLSB);
      Vsolar := 16 * Vhib + (Vlob div 16);

      Shib := i2cread(LTC2945_Bat, SenseMSB);
      Slob := i2cread(LTC2945_Bat, SenseLSB);
      Ssolar := 16 * Shib + (Slob div 16);

      Phib := i2cread(LTC2945_Bat, PowerMSB2);
      Pmsb := i2cread(LTC2945_Bat, PowerMSB1);
      Plob := i2cread(LTC2945_Bat, PowerLSB);
      Psolar := Plob + (256 * Pmsb) + ( 256 * 256 * Phib);

      s1s := Ssolar * 0.025;
      p1s := Psolar * 0.025 * 0.025;
      v1s := Vsolar * 0.025;

      //wind
      Vhib := i2cread(LTC2945_Wind, VinMSB);
      Vlob := i2cread(LTC2945_Wind, VinLSB);
      Vwind := 16 * Vhib + (Vlob div 16);

      Shib := i2cread(LTC2945_Wind, SenseMSB);
      Slob := i2cread(LTC2945_Wind, SenseLSB);
      Swind := 16 * Shib + (Slob div 16);

      Phib := i2cread(LTC2945_Wind, PowerMSB2);
      Pmsb := i2cread(LTC2945_Wind, PowerMSB1);
      Plob := i2cread(LTC2945_Wind, PowerLSB);
      Pwind := Plob + (256 * Pmsb) + ( 256 * 256 * Phib);

      s1w := Swind * 0.025;
      p1w := Pwind * 0.025 * 0.025;
      v1w := Vwind * 0.025;

      //left
      Vhib := i2cread(LTC2945_DC1, VinMSB);
      Vlob := i2cread(LTC2945_DC1, VinLSB);
      Vleft  := 16 * Vhib + (Vlob div 16);

      Shib := i2cread(LTC2945_DC1, SenseMSB);
      Slob := i2cread(LTC2945_DC1, SenseLSB);
      Sleft  := 16 * Shib + (Slob div 16);

      Phib := i2cread(LTC2945_DC1, PowerMSB2);
      Pmsb := i2cread(LTC2945_DC1, PowerMSB1);
      Plob := i2cread(LTC2945_DC1, PowerLSB);
      Pleft := Plob + (256 * Pmsb) + ( 256 * 256 * Phib);

      s2 := Sleft * 0.025;
      p2 := Pleft * 0.025 * 0.025;
      v2 := Vleft * 0.025;

      //right
      Vhib := i2cread(LTC2945_DC2, VinMSB);
      Vlob := i2cread(LTC2945_DC2, VinLSB);
      Vright := 16 * Vhib + (Vlob div 16);

      Shib := i2cread(LTC2945_DC2, SenseMSB);
      Slob := i2cread(LTC2945_DC2, SenseLSB);
      Sright := 16 * Shib + (Slob div 16);

      Phib := i2cread(LTC2945_DC2, PowerMSB2);
      Pmsb := i2cread(LTC2945_DC2, PowerMSB1);
      Plob := i2cread(LTC2945_DC2, PowerLSB);
      Pright := Plob + (256 * Pmsb) + ( 256 * 256 * Phib);

      s3 := Sright * 0.025;
      p3 := Pright * 0.025 * 0.025;
      v3 := Vright * 0.025;

      //1kw
      Vhib := i2cread(LTC2945_100A, VinMSB);
      Vlob := i2cread(LTC2945_100A, VinLSB);
      V1kw := 16 * Vhib + (Vlob div 16);

      Shib := i2cread(LTC2945_100A, SenseMSB);
      Slob := i2cread(LTC2945_100A, SenseLSB);
      S1kw := 16 * Shib + (Slob div 16);

      Phib := i2cread(LTC2945_100A, PowerMSB2);
      Pmsb := i2cread(LTC2945_100A, PowerMSB1);
      Plob := i2cread(LTC2945_100A, PowerLSB);
      P1kw := Plob + (256 * Pmsb) + ( 256 * 256 * Phib);

      s4 := S1kw * 0.025;
      p4 := P1kw * 0.025 * 0.025;
      v4 := V1kw * 0.025;

      //4kw
      Vhib := i2cread(LTC2945_400A, VinMSB);
      Vlob := i2cread(LTC2945_400A, VinLSB);
      V4kw  := 16 * Vhib + (Vlob div 16);

      Shib := i2cread(LTC2945_400A, SenseMSB);
      Slob := i2cread(LTC2945_400A, SenseLSB);
      S4kw  := 16 * Shib + (Slob div 16);

      Phib := i2cread(LTC2945_400A, PowerMSB2);
      Pmsb := i2cread(LTC2945_400A, PowerMSB1);
      Plob := i2cread(LTC2945_400A, PowerLSB);
      P4kw := Plob + (256 * Pmsb) + ( 256 * 256 * Phib);

      s5 := S4kw * 0.025;
      p5 := P4kw * 0.025 * 0.025;
      v5 := V4kw * 0.025;

      Totalin := p1w + p1s;
      Totalout := p2 + p3 + p4 + p5;

      if Debug = 1 then
          begin


              Log('iTemp = ' + FloatToStr(itemp));
              Log('  oTemp = ' + FloatToStr(otemp));
              LogLn('  sTemp = ' + FloatToStr(stemp));


              Log('Vsolar = ' + FloatToStr(v1s));
              Log('  Ssolar = ' + FloatToStr(s1s));
              LogLn('  Psolar = ' + FloatToStr(p1s));

              Log('Vwind = ' + FloatToStr(v1w));
              Log('  Swind = ' + FloatToStr(s1w));
              LogLn('  Pwind = ' + FloatToStr(p1w));

              Log('Vleft = ' + FloatToStr(v2));
              Log('  Sleft = ' + FloatToStr(s2));
              LogLn('  Pleft = ' + FloatToStr(p2));

              Log('Vright = ' + FloatToStr(v3));
              Log('  Sright = ' + FloatToStr(s3));
              LogLn('  Pright = ' + FloatToStr(p3));

              Log('V1kw = ' + FloatToStr(v4));
              Log('  S1kw = ' + FloatToStr(s4));
              LogLn('  P1kw = ' + FloatToStr(p4));

              Log('V4kw = ' + FloatToStr(v5));
              Log('  S4kw = ' + FloatToStr(s5));
              LogLn('  P4kw = ' + FloatToStr(p5));

              Log('Total In = ' + FloatToStr(Totalin));
              LogLn('   Total out = ' + FloatToStr(Totalout));

              LogLn(' ' );
          end;

   end;




end.

