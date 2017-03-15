function Get-CPUAlert 
{
	<#		
		.DESCRIPTION
			This function will Generate an Email alert for given threshold. 

		.PARAMETER 
            [string[]]$inputfile,
            -- Input file for the servers list
            [int]$threshold,
            -- value of the CPU percentage 
            [int]$frequency
            -- Duration of the monitoring

		.EXAMPLE
			PS C:\> Get-CPUAlert -Inputfile "Filepath" -OutFile -threshold 85 -frequency 10

		.INPUTS
			System.String

		.OUTPUTS
			PSCustomObject

		.NOTES
			Additional information about the function go here.

		.LINK
			about_functions_advanced

	#>
  [CmdletBinding()]
	[OutputType([PSCustomObject])]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeLine=$false)]
		[ValidateNotNullOrEmpty()]
        [string[]]$inputfile,
        [int]$threshold,
        [int]$frequency
	)
     
$ServerList = Get-Content $inputfile 
$Result = @()  
ForEach($computername in $ServerList)  
  {   
    $AVGProc = Get-WmiObject -computername $computername win32_processor |  
    Measure-Object -property LoadPercentage -Average | Select-Object Average 
    $Cpu = @()
    if ($AVGProc.average -ge $threshold)
      {
              for ($i = 0; $i-lt ($frequency*4);)
                {
                      if ($AVGProc.average -ge $threshold)
                      {
                           $Cpu += Get-WmiObject -computername $computername win32_processor |  
                                  Measure-Object -property LoadPercentage -Average | Select-Object Average  
                            }
                                         start-sleep -Milliseconds 15      
                                  $i++
                                }
                                  $Tavg = $cpu | measure-object -property average -average | select-object average
                                  $Tavg1 = [math]::Round($Tavg.average,2)
                        if ($Tavg1 -ge $threshold )
                          { 
                                $os = Get-Ciminstance Win32_OperatingSystem
                                $pctFree = [math]::Round(($os.TotalVisibleMemorySize-$os.FreePhysicalMemory)*100/$os.TotalVisibleMemorySize,2)
                                
                                $result += [PSCustomObject] @{  
                                                                  ServerName = "$computername" 
                                                                  CPULoad = "$($Tavg1)%" 
                                                                  MemLoad = "$($pctFree)%"
                                                                } 

                            $Outputreport = "<HTML><TITLE> Server Health Report </TITLE> 
                                                <BODY background-color:peachpuff> 
                                                <font color =""#99000"" face=""Microsoft Tai le""> 
                                                <H2> Server Health Report </H2></font> 
                                                <Table border=1 cellpadding=0 cellspacing=0> 
                                                <TR bgcolor=gray align=center> 
                                                  <TD><B>Server Name</B></TD> 
                                                  <TD><B>Avrg.CPU Utilization</B></TD> 
                                                  <TD><B>Memory Utilization</B></TD> 
                                                  " 

                              Foreach($Entry in $Result)  
                              
                                  {  
                                    if((($Entry.CpuLoad) -or ($Entry.memload)) -ge "80")  
                                    {  
                                      $Outputreport += "<TR bgcolor=red>"  
                                    }  
                                    else 
                                    { 
                                      $Outputreport += "<TR>"  
                                    } 
                                    $Outputreport += "<TD><B>$($Entry.Servername)</B></TD>
                                                      <TD align=center><B>$($Entry.CPULoad)</B></TD>
                                                      <TD align=center><B>$($Entry.MemLoad)</B></TD></TR>"  
                                  } 
                              $Outputreport += "</Table></BODY></HTML>"  
                              $Outputreport | out-file D:\Users\Althafuddin.S\Desktop\Test.htm  
                              #Invoke-item D:\Users\Althafuddin.S\Desktop\Test.htm 
                          }
      }
  }
######################  
# E-mail HTML output #  
###################### 
Add-PSSnapin Microsoft.Exchange.Management.Powershell.Admin -erroraction silentlyContinue
$enablemail="NO"   
$smtpServer = "smtp.verizon.com"
$mailfrom = "TMSCoverageMissingAssets <Hydra-Ops@one.verizon.com>"  
$mailto = "Shaik, Althafuddin (Althaf) <Althafuddin.Shaik@one.verizon.com>"
$subject = "CPU Alert Report"

Send-MailMessage -smtpServer $smtpServer -from $mailfrom -to $mailto -subject $subject -Body $Outputreport -BodyAsHtml  
                
}