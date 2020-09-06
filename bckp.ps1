[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('Archive', 'Restore')]
    [String]
    $Command,
    [Parameter(Mandatory = $true, Position = 1)]
    [String]
    $BackupName
)

function Backup-Data {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Key
    )
    
    process {
        $BackupSettings = Get-BackupSettings $Key

        $Origin = $BackupSettings.Origin

        if (-Not (Test-Path $Origin)) {
            "Origin not found: $Origin" | Write-Host
            exit
        }

        $CurrentLocation = Get-Location

        $Timestamp = Get-Date -Format "yyyyMMddThhmmss"
        $Archive = $Configuration.Archive

        $ArchiveName = "$Archive\$Key\$Timestamp.7z"

        Set-Location -Path $BackupSettings.Origin

        7z a -t7z $ArchiveName ( Get-ChildItem . -Recurse -Name | Where-Object { $_ -match $BackupSettings.Filter } )

        Set-Location -Path $CurrentLocation
    }
}

function Get-BackupSettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Key        
    )

    process {
        $Store = $Configuration.Store
        $Filename = "$Store\$Key.json"

        if (-Not (Test-Path $Filename)) {
            "Unknown backup: $Key" | Write-Host
            exit
        }

        $BackupSettings = Get-Content $Filename | ConvertFrom-Json

        $BackupSettings.Origin = [Environment]::ExpandEnvironmentVariables($BackupSettings.Origin)

        $BackupSettings
    }
}

function Get-LatestArchiveFilename {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Key        
    )

    process {
        $Archive = $Configuration.Archive
        $Path = "${Archive}\${Key}"

        if (-Not (Test-Path $Path)) {
            "No archive found: ${Key}" | Write-Host
            exit
        }

        $Latest = Get-ChildItem $Path -Name | Select-Object -Last 1        

        "${Archive}\${Key}\${Latest}"
    }

}

function Restore-Data {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Key
    )
    
    process {      
        $ArchiveFilename = Get-LatestArchiveFilename $Key
        $BackupSettings = Get-BackupSettings $Key

        $Origin = $BackupSettings.Origin

        7z x -o"$Origin" $ArchiveFilename
    }
}

$AppPath = "${env:APPDATA}\bckp"

if (-Not (Test-Path $AppPath)) {
    New-Item -ItemType Directory -Force -Path $AppPath
}

$ConfigurationFile = "${env:APPDATA}\bckp\config.json"

if (Test-Path $ConfigurationFile -PathType Leaf) {
    $Configuration = Get-Content $ConfigurationFile | ConvertFrom-Json
}
else {
    $Configuration = @{
        Archive = "%APPDATA%\bckp\archive"
        Store   = "%APPDATA%\bckp\store"
    }
    
    ConvertTo-Json $Configuration | Out-File -FilePath $ConfigurationFile -Force
}

$Configuration.Archive = [Environment]::ExpandEnvironmentVariables($Configuration.Archive)
$Configuration.Store = [Environment]::ExpandEnvironmentVariables($Configuration.Store)
    
switch ($Command) {
    'Archive' { 
        Backup-Data -Key $BackupName        
    }
    'Restore' {
        Restore-Data -Key $BackupName
    }
    Default {
        "Unknown command: ${Command}" | Write-Host
    }
}
