function New-CoreCrontab
{
    [CmdletBinding()]
    param(
        [string[]]$Command
    )

    $tempFile = "mktemp"
    $Command | Set-Content -Path $tempFile

    crontab $tempFile

    Get-ChildItem -Path $tempFile | Remove-Item -Confirm:$false
}

function Get-CorePlatform
{
    [cmdletbinding()]
    param()

    $osDetected = $false
    try{
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        Write-Verbose -Message 'Windows detected'
        $osDetected = $true
        $osFamily = 'Windows'
        $osName = $os.Caption
        $osVersion = $os.Version
        $nodeName = $os.CSName
        $architecture = $os.OSArchitecture
    }
    catch{
        Write-Verbose -Message 'Possibly Linux or Mac'
        $uname = "$(uname)"
        if($uname -match '^Darwin|^Linux'){
            $osDetected = $true
            $osFamily = $uname
            $osName = "$(uname -v)"
            $osVersion = "$(uname -r)"
            $nodeName = "$(uname -n)"
            $architecture = "$(uname -p)"
        }
        # Other
        else
        {
            Write-Warning -Message "Kernel $($uname) not covered"
        }
    }
    [ordered]@{
        OSDetected = $osDetected
        OSFamily = $osFamily
        OS = $osName
        Version = $osVersion
        Hostname = $nodeName
        Architecture = $architecture
    }
}

function New-CoreScheduledTask
{
    [cmdletbinding()]
    param(
        [datetime]$Start,
        [scriptblock]$Script
    )

    switch -RegEx ((Get-CorePlatform).OSFamily)
    {
        'Windows' {
            $text = @()
            $text += 'schtasks','/Create','/SC Once'
            $text += "/ST $($Start.ToShortTimeString()) /SD $($Start.ToString('dd-MM-yyyy'))"
            $text += "/TN CoreTools-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            $text += "/TR ""powershell.exe -Command '&{$Script}'"""
            
            Invoke-Expression -Command ($text -join ' ')
        }
        "^Linux|^Darwin"{
           $text = @()
           $text += (crontab -l 2>&1 | where{$_ -notmatch "no crontab"})

           $cronLine = "$($Start.Minute) $($Start.Hour) $($Start.Day) $($Start.Month) $([int]$Start.DayOfWeek)"
           $cronline += " $(which powershell) -Command ""&{$($Script)}"""
           $text += $cronLine

           New-CoreCrontab -Command $text
        }
        'Default'{
            Write-Error -Message "Unknown OSFamiliy $($_)"
        }
    }
}