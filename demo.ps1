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


#Under the hood, the PowerShell module is using the REST API to communicate to the array
Get-Pfa2Volume -Array $FlashArray -Verbose -Name 'vvol-aen-sql-22-a-1-3d9acfdd-vg/Data-47094663'


#Let's look at the attributes that are available to use
Get-Pfa2Volume -Array $FlashArray  | Get-Member


#Get a count of how many volumes are returned when we use this cmdlet...aka how many volumes are in our array
Get-Pfa2Volume -Array $FlashArray | Measure-Object 


#Let's get the top 10 volumes in terms of TotalPhysical capacity using sorting and filtering via PowerShell
#In PowerShell v7+ you can use the Sort-Object -Top 10 parameter, in PowerShell 5.1 you will use Select-Object -First 10
Get-Pfa2Volume -Array $FlashArray | 
    Select-Object Name -ExpandProperty Space | 
    Sort-Object -Property TotalPhysical -Descending | 
    Select-Object -First 10 |
    Format-Table


#Now, let's push the heavy lifting into the array, sorting by total_physical and limiting to the top 10, 
# with Sort and Limit the hard work happens on the server side and the results are returned locally
# Where did I find that sort property...
# https://support.purestorage.com/FlashArray/PurityFA/Purity_FA_REST_API/FlashArray_REST_API_Reference_Guides 
# total_physical is The total physical space occupied by system, shared space, volume, and snapshot data. Measured in bytes.
Get-Pfa2Volume -Array $FlashArray -Sort "space.total_physical-" -Limit 10 | 
    Select-Object Name -ExpandProperty Space | 
    Format-Table


#Let's see how long each method takes to get the data from the array, first let's look at sorting and filtering via PowerShell
Measure-Command {
    Get-Pfa2Volume -Array $FlashArray | 
    Select-Object Name -ExpandProperty Space | 
    Sort-Object -Property TotalPhysical -Descending | 
    Select-Object -First 10 |
    Format-Table
} | Select-Object TotalMilliseconds


#Next, let's see how long it takes to sort and filter on the array and return just the results we want
Measure-Command {
    Get-Pfa2Volume -Array $FlashArray -Sort "space.total_physical-" -Limit 10 | 
    Select-Object Name -ExpandProperty Space | 
    Format-Table
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


#Finding hot volumes in a FlashArray
Get-Pfa2VolumePerformance -Array $FlashArray | Get-Member


#Using our sorting method from earlier, I'm going to look for something that's generating a lot of reads, 
#and limit the output to the top 10
Get-Pfa2VolumePerformance -Array $FlashArray -Sort 'reads_per_sec-' -Limit 10 | 
    Select-Object Name, Time, ReadsPerSec, BytesPerRead


#But what if I want to look for total IOPs, we'll I have to calculate that locally.
$VolumePerformance = Get-Pfa2VolumePerformance -Array $FlashArray
$VolumePerformance | 
    Select-Object Name, ReadsPerSec, WritesPerSec, @{label="IOsPerSec";expression={$_.ReadsPerSec + $_.WritesPerSec}} | 
    Sort-Object -Property IOsPerSec -Descending | 
    Select-Object -First 10


#Let's learn how to look back in time...

#What's the default resolution for this sample...in other words how far back am I looking in the data available?
#The default resolution on storage objects like volumes is 30 seconds window starting when the cmdlet is run
Get-Pfa2VolumePerformance -Array $FlashArray -Sort 'reads_per_sec-' -Limit 10 | 
    Select-Object Name, Time, ReadsPerSec, BytesPerRead


#Let's look at 48 hours ago over a one day window
#In PowerShell 7 you can use Get-Date -AsUTC, In PowerShell 5.1 you can use (Get-Date).ToUniversalTime()
$Today = Get-Date -AsUTC
$Today = (Get-Date).ToUniversalTime()
$EndTime = $Today.AddDays(-2)
$StartTime = $Today.AddDays(-3)

#Let's find the to 10 highest read volumes 2 days ago.
Get-Pfa2VolumePerformance -Array $FlashArray -Sort 'reads_per_sec-' -Limit 10 -StartTime $StartTime -EndTime $EndTime -resolution 1800000 |
    Select-Object Name, Time, ReadsPerSec


#Let's find the to 10 highest read volumes 2 days ago, where they have the string aen in the name.
Get-Pfa2VolumePerformance -Array $FlashArray -Filter "name='*aen-sql-22-a*'" -Sort 'reads_per_sec-' -Limit 10 -StartTime $StartTime -EndTime $EndTime -resolution 1800000 | 
    Sort-Object ReadsPerSec -Descending |
    Select-Object Name, Time, ReadsPerSec


#Take aways
# 1. You can easily find volume level performance information via PowerShell and also our API.
# 2. Continue to use the filtering, sorting and limiting techniques discussed.
# 3. Its not just Volumes, you can do this for other objects too, Hosts, HostGroups, Pods, Directories, and the Array as a whole



#Categorize, search and manage your FlashArray resources efficiently
#Group a set of volumes with tags and get and performance metrics based on those tags
Get-Pfa2Volume -Array $FlashArray -Filter "name='*aen-sql-22*'" | 
    Select-Object Name 


#Let's get a set of volumes using our filtering technique
$VolumesSqlA = Get-Pfa2Volume -Array $FlashArray -Filter "name='*aen-sql-22-a*'" | 
    Select-Object Name -ExpandProperty Name

$VolumesSqlB = Get-Pfa2Volume -Array $FlashArray -Filter "name='*aen-sql-22-b*'" | 
    Select-Object Name -ExpandProperty Name

$VolumesSqlA
$VolumesSqlB

$TagNamespace = 'AnthonyNamespace'
$TagKey = 'SqlInstance'
$TagValueSqlA = 'aen-sql-22-a'
$TagValueSqlB = 'aen-sql-22-b'


#Assign the tags keys and values to the sets of volumes we're working with 
Set-Pfa2VolumeTagBatch -Array $FlashArray -TagNamespace $TagNamespace -ResourceNames $VolumesSqlA -TagKey $TagKey -TagValue $TagValueSqlA
Set-Pfa2VolumeTagBatch -Array $FlashArray -TagNamespace $TagNamespace -ResourceNames $VolumesSqlB -TagKey $TagKey -TagValue $TagValueSqlB


#Let's get all the volumes that have the Key = SqlInstance
Get-Pfa2VolumeTag -Array $FlashArray -Namespaces $TagNamespace -Filter "Key='SqlInstance'"


#Let's get all the volumes that have the Value of aen-sql-22-b
Get-Pfa2VolumeTag -Array $FlashArray -Namespaces $TagNamespace -Filter "Value='aen-sql-22-b'"


#And when we're done, we can clean up our tags
Remove-Pfa2VolumeTag -Array $FlashArray -Namespaces $TagNamespace -Keys $TagKey -ResourceNames $VolumesSqlA
Remove-Pfa2VolumeTag -Array $FlashArray -Namespaces $TagNamespace -Keys $TagKey -ResourceNames $VolumesSqlB


###Key take aways
### 1. You can classify objects in the array to give your integrations more information about
###    what's in the object...things like volumes and snapshots
### 2. What can you do with tags? Execute operations on sets of data, snapshots, clones, accounting, performance monitoring


#Streamline snapshot management with powerful API-driven techniques


#Let's look at the members available to us on the Volume Snapshot object
Get-Pfa2VolumeSnapshot -Array $FlashArray | Get-Member


#Find snapshots that are older than a specific date, we need to put the date into a format the API understands
#In PowerShell 7 you can use Get-Date -AsUTC, In PowerShell 5.1 you can use (Get-Date).ToUniversalTime()
$Today = (Get-Date).ToUniversalTime()
$Created = $Today.AddDays(-30)
$StringDate = Get-Date -Date $Created -Format "yyy-MM-ddTHH:mm:ssZ"


#There's likely lots of snapshots, so let's use array side filtering to 
#limit the set of objects and find snapshots older than a month on our array
Get-Pfa2VolumeSnapshot -Array $FlashArray -Filter "created<'$StringDate'" |
    Sort-Object -Property Created | 
    Select-Object Name, Created


#Similarly we can do this for protection groups 
Get-Pfa2ProtectionGroupSnapshot -Array $FlashArray -Filter "created<'$StringDate'" | 
    Sort-Object -Property Created | 
    Select-Object Name, Created


#You can remove snapshots with these cmdlets
#Remove-Pfa2VolumeSnapshot
#Remove-Pfa2ProtectionGroupSnapshot

#Setup and deploy the OpenMetrics Exporter, enabling you to collect and analyze data from your Pure Storage arrays
#https://github.com/PureStorage-OpenConnect/pure-fa-openmetrics-exporter
#https://www.nocentino.com/posts/2022-12-20-monitoring-flasharray-with-openmetrics/
Set-Location ~/Documents/GitHub/pure-fa-openmetrics-exporter/examples/config/docker
docker compose up --detach
http://localhost:3000
docker compose down 
