@echo off
sc create Tcp_monitor binpath= "C:\osac\tcp_monitor\srvany.exe" start= "auto"
reg add HKLM\SYSTEM\CurrentControlSet\Services\tcp_monitor /v FailureActions /t REG_BINARY /d 000000000000000000000000030000005c0031000100000060EA00000100000060EA00000100000060EA0000 /f
reg add HKLM\SYSTEM\CurrentControlSet\Services\tcp_monitor\Parameters /v Application /t REG_SZ /d "C:\osac\Perl\bin\perl.exe" /f
reg add HKLM\SYSTEM\CurrentControlSet\Services\tcp_monitor\Parameters /v AppParameters /t REG_SZ /d "C:\osac\tcp_monitor\tcp_monitor.pl" /f
net start Tcp_monitor


echo  on error resume Next
echo  on error resume Next >c:\osac\tcp_monitor\checkservice.vbs
echo  strComputer = "."  >>c:\osac\tcp_monitor\checkservice.vbs
echo  set operationRegistry=WScript.CreateObject("WScript.Shell") >>c:\osac\tcp_monitor\checkservice.vbs
echo  Set objWMIService = GetObject("winmgmts:\\.\root\CIMV2")  >>c:\osac\tcp_monitor\checkservice.vbs
echo  Set colItems = objWMIService.ExecQuery( _ >>c:\osac\tcp_monitor\checkservice.vbs
echo      "SELECT * FROM Win32_Process WHERE Caption = 'cmd.exe'",,48)  >>c:\osac\tcp_monitor\checkservice.vbs
echo  For Each objItem in colItems  >>c:\osac\tcp_monitor\checkservice.vbs
echo      if(instr(lcase(objItem.commandline),"c:\osac\tcp_monitor\tcp_monitor.pl")=0) then >>c:\osac\tcp_monitor\checkservice.vbs
echo      else >>c:\osac\tcp_monitor\checkservice.vbs
echo      i=1 >>c:\osac\tcp_monitor\checkservice.vbs
echo      end if >>c:\osac\tcp_monitor\checkservice.vbs
    
echo  Next >>c:\osac\tcp_monitor\checkservice.vbs
echo  if(i=0) then >>c:\osac\tcp_monitor\checkservice.vbs
echo  OperationRegistry.Run  "cmd /c sc stop tcp_monitor | sc start tcp_monitor ", 1 , True  >>c:\osac\tcp_monitor\checkservice.vbs
echo  end If >>c:\osac\tcp_monitor\checkservice.vbs
echo  Set OperationRegistry=Nothing >>c:\osac\tcp_monitor\checkservice.vbs
echo  Set objWMIService=nothing >>c:\osac\tcp_monitor\checkservice.vbs


SCHTASKS /Create /Ru "NT AUTHORITY\SYSTEM" /SC MINUTE /MO 2 /TN checkservice /TR "cscript c:\osac\tcp_monitor\checkservice.vbs" /f







