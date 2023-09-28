Import-Module PureStoragePowerShellSDK2


#Connect to our FlashArray
$Credential = Get-Credential -UserName "anocentino" -Message 'Enter your credential information...'
$FlashArray = Connect-Pfa2Array –EndPoint sn1-m70-f06-33.puretec.purestorage.com -Credential $Credential -IgnoreCertificateError


#Gather performance data about volumes to fine tune your storage infrastructure for optimal efficiency
#Identify and address bottlenecks by pinpointing hot volumes


#Using filtering...
Get-Pfa2Volume -Array $FlashArray | Measure-Object
 

Measure-Command {
    Get-Pfa2Volume -Array $FlashArray | Where-Object { $_.Name -like "*aen*" }
} | Select-Object TotalMilliseconds


Measure-Command {
    Get-Pfa2Volume -Array $FlashArray -Filter "name='*aen*'" 
} | Select-Object TotalMilliseconds




#Kick off a backup



#Find the hot volume on reads
Get-Pfa2VolumePerformance -Array $FlashArray | Get-Member

Get-Pfa2VolumePerformance -Array $FlashArray -Sort 'reads_per_sec-' -Limit 10 
    | Select-Object Name, ReadsPerSec, BytesPerRead



#Let's look at the last 24 hours
$EndTime = Get-Date
$StartTime = $EndTime.AddHours(-24)

Get-Pfa2VolumePerformance -Array $FlashArray -Sort 'reads_per_sec-' -Limit 10 -StartTime $StartTime -EndTime $EndTime
    | Select-Object Name, ReadsPerSec, BytesPerRead


$VolumePerformance = Get-Pfa2VolumePerformance -Array $FlashArray
$VolumePerformance | Select-Object Name, ReadsPerSec, WritesPerSec, @{label="IOsPerSec";expression={$_.ReadsPerSec + $_.WritesPerSec}} 
    | Sort-Object -Property IOsPerSec -Descending 
    | Select-Object -First 10
    



#Let's look at the performance data that's available to us for hosts on the array
Get-Pfa2HostPerformance -Array $FlashArray | Get-Member


#Let's get the top host by average total IO (Reads + Writes)...to do this we need to rely on PowerShell to do the math for us
$HostPerformance = Get-Pfa2HostPerformance -Array $FlashArray

$HostPerformance | Select-Object Name, ReadsPerSec, WritesPerSec, @{label="IOsPerSec";expression={$_.ReadsPerSec + $_.WritesPerSec}} 
    | Sort-Object -Property IOsPerSec -Descending 
    | Select-Object -First 10






#Categorize, search and manage your FlashArray resources efficiently
#Group a set of volumes with tags and get and performance metrics based on those tags



#Streamline snapshot management with powerful API-driven techniques



#Setup and deploy the OpenMetrics Exporter, enabling you to collect and analyze data from your Pure Storage arrays




