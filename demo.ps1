Import-Module PureStoragePowerShellSDK2


#Connect to our FlashArray
$Credential = Get-Credential -UserName "anocentino" -Message 'Enter your credential information...'
$FlashArray = Connect-Pfa2Array –EndPoint sn1-m70-f06-33.puretec.purestorage.com -Credential $Credential -IgnoreCertificateError

##Demo 1 - Gather information and performance data about volumes 
Get-Command -Module PureStoragePowerShellSDK2


#Let's look at the cmdlets that have performance in the name to see what's available to us to work with
Get-Command -Module PureStoragePowerShellSDK2 | Where-Object { $_.Name -like "*performance" } 


#First, let's get a listing of all the volumes in the array
Get-Pfa2Volume -Array $FlashArray 


#Let's look at the attributes that are available to use
Get-Pfa2Volume -Array $FlashArray  | Get-Member


#Get a count of how many volumes are returned when we use this cmdlet...aka how many volumes are in our array
Get-Pfa2Volume -Array $FlashArray | Measure-Object 


#Let's get the top 10 volumes in terms of TotalPhysical capacity using sorting and filtering via PowerShell
Get-Pfa2Volume -Array $FlashArray 
    | Select-Object Name, Space.TotalPhysical -ExpandProperty Space
    | Sort-Object -Property TotalPhysical -Descending -Top 10 
    | Format-Table


#Now, let's push the heavy lifting into the array, sorting by total_physical and limiting to the top 10, 
# with Sort and Limit the hard work happens on the server side and the results are returned locally
Get-Pfa2Volume -Array $FlashArray -Sort "space.total_physical-" -Limit 10 -Verbose
    | Select-Object Name, Space.TotalPhysical -ExpandProperty Space 
    | Format-Table


#Let's see how long each method takes to get the data from the array, first let's look at sorting and filtering via PowerShell
Measure-Command {
    Get-Pfa2Volume -Array $FlashArray 
    | Select-Object Name, Space.TotalPhysical -ExpandProperty Space
    | Sort-Object -Property TotalPhysical -Descending -Top 10 
    | Format-Table
} | Select-Object TotalMilliseconds


#Next, let's see how long it takes to sort and filter on the array and return just the results we want
#Where did I find that sort property...https://support.purestorage.com/FlashArray/PurityFA/Purity_FA_REST_API/FlashArray_REST_API_Reference_Guides 
# total_physical is The total physical space occupied by system, shared space, volume, and snapshot data. Measured in bytes.
Measure-Command {
    Get-Pfa2Volume -Array $FlashArray -Sort "space.total_physical-" -Limit 10 
    | Select-Object Name, Space.TotalPhysical -ExpandProperty Space 
    | Format-Table
} | Select-Object TotalMilliseconds


#Let's use filtering on a listing of volumes...first with PowerShell
Get-Pfa2Volume -Array $FlashArray | Where-Object { $_.Name -like "*aen*" }


#Now, let's push that into the array and sort in the api
Get-Pfa2Volume -Array $FlashArray -Filter "name='*aen*'" 


Measure-Command {
    Get-Pfa2Volume -Array $FlashArray | Where-Object { $_.Name -like "*aen*" }
} | Select-Object TotalMilliseconds


Measure-Command {
    Get-Pfa2Volume -Array $FlashArray -Filter "name='*aen*'" 
} | Select-Object TotalMilliseconds

###Take aways, use sort, limit and filter to scope your API calls to what you want to get. Will significantly increase performance


#Demo 2 - Identify and address bottlenecks by pinpointing hot volumes
#Kick off a backup to generate some read workload
Start-Job -ScriptBlock {
    $username = "sa"
    $password = 'S0methingS@Str0ng!' | ConvertTo-SecureString -AsPlainText
    $SqlCredential = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $password
    Backup-DbaDatabase -SqlInstance 'aen-sql-22-a' -SqlCredential $SqlCredential -Database 'FT_Demo' -Type Full -FilePath NUL 
}


#Find the hot volume on reads
Get-Pfa2VolumePerformance -Array $FlashArray | Get-Member


#Using our sorting method from earlier, i'm going to look for somethign that's generating a lot of reads, and limit the output to the top 10
Get-Pfa2VolumePerformance -Array $FlashArray -Sort 'reads_per_sec-' -Limit 10 
    | Select-Object Name, Time, ReadsPerSec, BytesPerRead



$VolumePerformance = Get-Pfa2VolumePerformance -Array $FlashArray
$VolumePerformance | Select-Object Name, ReadsPerSec, WritesPerSec, @{label="IOsPerSec";expression={$_.ReadsPerSec + $_.WritesPerSec}} 
    | Sort-Object -Property IOsPerSec -Descending 
    | Select-Object -First 10


    
#What's the default resolution for this sample...in other words how far back am I looking in the data available?
#The default resolution on storage objects like volumes is 30 seconds sample starting when the cmdlet is run
Get-Pfa2VolumePerformance -Array $FlashArray -Sort 'reads_per_sec-' -Limit 10 
| Select-Object Name, Time, ReadsPerSec, BytesPerRead



#Let's look at 24 hours ago
$Today = Get-Date
$EndTime = $Today.AddDays(-1)
$StartTime = $Today.AddDays(-1)

Get-Pfa2VolumePerformance -Array $FlashArray -Sort 'reads_per_sec-' -Limit 10 -StartTime $StartTime -EndTime $EndTime
| Select-Object Name, Time, ReadsPerSec, BytesPerRead

#Take aways
# 1. You can easily find volume level performance information via PowerShell and also our API.
# 2. Continue to use the filtering, sorting and limiting techniques discussed.
# 3. Its not just Volumes, you can do this for other objects too, Hosts, HostGroups, Pods, Directories, and the Array as a whole




#Categorize, search and manage your FlashArray resources efficiently
#Group a set of volumes with tags and get and performance metrics based on those tags



#Streamline snapshot management with powerful API-driven techniques



#Setup and deploy the OpenMetrics Exporter, enabling you to collect and analyze data from your Pure Storage arrays


