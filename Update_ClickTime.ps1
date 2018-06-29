Function Update-ClickTime {

<#
.SYNOPSIS

Fetch the timesheets from liquidplanner and updates to click time database for number of days.

.DESCRIPTION

Need Click time database and provide the write access to the account

.PARAMETER Name
sqlservername[Mandatory]
sqldatabase[Mandatory]
sqlusername[Mandatory]
sqlpassword[Mandatory][System.Security.Object]
numberofdays[Default = 1 day]

.INPUTS
[String]sqlservername
[String]sqldatabase
[String]sqlusername
[String]sqlpassword - Passed into as plain text further convert into Secure-String
[Int]numberofdays

.OUTPUTS

System.String. Timesheets and task names with in the desired amount of time

.EXAMPLE

C:\PS> Update-ClickTime -sqlservername "Instance/database" -sqldatabase "DatabaseName" -sqlusername "UserName" -sqlpassword "Password" -numberofdays 1

.EXAMPLE

C:\PS> Update-ClickTime -sqlservername "Instance/database" -sqldatabase "DatabaseName" -sqlusername "UserName" -sqlpassword "Password"
#>
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $True)]
        [string]$sqlservername,
        
        [Parameter(Mandatory = $True)]
        [string]$sqldatabase,
        
        [Parameter(Mandatory = $True)]
        [string]$sqlusername,
        
        [Parameter(Mandatory = $True)]
        $sqlpassword,
        
        [Parameter()]
        [int]$numberofdays = 1)


    $apiKey = "apikey"
    $workspaceid = "id"
    $headers = @{"Authorization" = "Bearer " + $apiKey}
    $date = get-date (get-date).AddDays( - $numberofdays) -Format o
    $password = convertto-securestring $sqlpassword -asplaintext -force
    $ErrorActionPreference = "silentlycontinue"

    $timesheets = Invoke-WebRequest -Uri "https://app.liquidplanner.com/api/v1/workspaces/$workspaceid/timesheet_entries?updated_since=$date" -Headers $headers
    $projects = Invoke-WebRequest -uri "https://app.liquidplanner.com/api/v1/workspaces/$workspaceid/projects" -Headers $headers
    $members = Invoke-WebRequest -Uri "https://app.liquidplanner.com/api/v1/workspaces/$workspaceid/members" -Headers $headers


    $jsontimesheet = $timesheets.Content | ConvertFrom-Json
    $jsonprojects = $projects.Content   | ConvertFrom-Json
    $jsonmembers = $members.Content    | ConvertFrom-Json


    $timesheet = @()

    foreach ($i in $jsontimesheet) {

        $clientName = $jsonprojects | Where-Object {$_.id -like $i.project_id} | Select-Object client_name
        $projectname = $jsonprojects | Where-Object {$_.id -like $i.project_id} | Select-Object name, id
        $task_code = $i.item_id
        $task_name = Invoke-WebRequest -Uri "https://app.liquidplanner.com/api/v1/workspaces/$workspaceid/tasks/$task_code" -Headers $headers | ConvertFrom-Json | Select-Object name
        write-host "For $taskid Name: $task_name.name Url: $task_name"
        $employee = $jsonmembers | Where-Object {$_.id -like $i.member_id} | Select-Object id, ($res = @{Label = "fullname"; Expression = {"$($_.last_name) $($_.first_name)"}})
        $hours_work = $i.work
        $date = $i.work_performed_on
        $updated_date = $i.updated_at


        $timesheet += [PSCustomObject]@{
            client_name     = $clientName.client_name;
            project_name    = $projectname.name;
            project_number  = $projectname.id;
            task_code       = $task_code;
            full_name       = $employee.fullname;
            employee_number = $employee.id;
            hours_entered   = $hours_work;
            entry_date      = $date;
            inserteddt      = $updated_date;
        }
    }


    ##############################################
    # Checking to see if the SqlServer module is already installed, if not installing it
    ##############################################
    $SQLModuleCheck = Get-Module -ListAvailable SqlServer
    if ($SQLModuleCheck -eq $null) {
        write-host "SqlServer Module Not Found - Installing"
        # Not installed, trusting PS Gallery to remove prompt on install
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        # Installing module, requires run as admin for -scope AllUsers, change to CurrentUser if not possible
        Install-Module -Name SqlServer –Scope AllUsers -Confirm:$false -AllowClobber
    }
    ##############################################
    # Importing the SqlServer module
    ##############################################
    Import-Module SqlServer 

    $SQLInstance = $sqlservername
    $SQLDatabase = $sqldatabase
    $SQLUsername = $sqlusername
    $SQLPassword = $password 

    # Inserting array into the new table we created
    ForEach ($time in $timesheet) {
        # Setting the values as variables first, also converting to correct format to match SQL DB


        $client_name = $time.client_name
        $project_name = $time.project_name
        $project_number = $time.project_number 
        $task_code = $time.task_code 
        $full_name = $time.full_name 
        $employee_number = $time.employee_number
        $hours_entered = $time.hours_entered -as [decimal]
        $entry_date = $time.entry_date -as [datetime]
        $inserteddt = $time.inserteddt -as [datetime]


        # Creating the INSERT query using the variables defined
        $SQLQuery = "USE $SQLDatabase
        INSERT INTO [dbo].[stg_ExtractClicktime]
          ([client_name],
           [project_name],
           [project_number],
           [task_code],
           [full_name],
           [employee_number],
           [hours_entered],
           [entry_date],
           [inserteddt],
           [cost],
		   [Project_billable],
		   [billing_rate])

        VALUES( '$client_name','$project_name','$project_number', '$task_code','$full_name' , '$employee_number', '$hours_entered', '$entry_date','$inserteddt', '50', 'yes', '100')"
        # Running the INSERT query
        $SQLQuery4Output = Invoke-Sqlcmd -query $SQLQuery -ServerInstance $SQLInstance -Username $SQLUsername -Password $SQLPassword

    }

}
