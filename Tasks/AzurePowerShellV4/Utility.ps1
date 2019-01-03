$rollForwardTable = @{
    "5.0.0" = "5.1.1";
};

function Get-SavedModulePath {
    [CmdletBinding()]
    param([string] $azurePowerShellVersion)
    return $($env:SystemDrive + "\Modules\Az_" + $azurePowerShellVersion) 
}

function Update-PSModulePathForHostedAgent {
    [CmdletBinding()]
    param([string] $targetAzurePs)
    Trace-VstsEnteringInvocation $MyInvocation
    try {
        if ($targetAzurePs) {
            $hostedAgentAzModulePath = Get-SavedModulePath -azurePowerShellVersion $targetAzurePs
        }
        else {
            $hostedAgentAzModulePath = Get-LatestModule -patternToMatch "^az_[0-9]+\.[0-9]+\.[0-9]+$" -patternToExtract "[0-9]+\.[0-9]+\.[0-9]+$"
        }

        $env:PSModulePath = $hostedAgentAzModulePath + ";" + $env:PSModulePath
        $env:PSModulePath = $env:PSModulePath.TrimStart(';') 
    } finally {
        Write-Verbose "The updated value of the PSModulePath is: $($env:PSModulePath)"
        Trace-VstsLeavingInvocation $MyInvocation
    }
}

function Get-LatestModule {
    [CmdletBinding()]
    param([string] $patternToMatch,
          [string] $patternToExtract)
    
    $resultFolder = ""
    $regexToMatch = New-Object -TypeName System.Text.RegularExpressions.Regex -ArgumentList $patternToMatch
    $regexToExtract = New-Object -TypeName System.Text.RegularExpressions.Regex -ArgumentList $patternToExtract
    $maxVersion = [version] "0.0.0"

    try {
        $moduleFolders = Get-ChildItem -Directory -Path $($env:SystemDrive + "\Modules") | Where-Object { $regexToMatch.IsMatch($_.Name) }
        foreach ($moduleFolder in $moduleFolders) {
            $moduleVersion = [version] $($regexToExtract.Match($moduleFolder.Name).Groups[0].Value)
            if($moduleVersion -gt $maxVersion) {
                $modulePath = [System.IO.Path]::Combine($moduleFolder.FullName,"Az\$moduleVersion\Az.psm1")

                if(Test-Path -LiteralPath $modulePath -PathType Leaf) {
                    $maxVersion = $moduleVersion
                    $resultFolder = $moduleFolder.FullName
                } else {
                    Write-Verbose "A folder matching the module folder pattern was found at $($moduleFolder.FullName) but didn't contain a valid module file"
                }
            }
        }
    }
    catch {
        Write-Verbose "Attempting to find the Latest Module Folder failed with the error: $($_.Exception.Message)"
        $resultFolder = ""
    }
    Write-Verbose "Latest module folder detected: $resultFolder"
    return $resultFolder
}

function  Get-RollForwardVersion {
    [CmdletBinding()]
    param([string]$azurePowerShellVersion)
    Trace-VstsEnteringInvocation $MyInvocation
    
    try {
        $rollForwardAzurePSVersion = $rollForwardTable[$azurePowerShellVersion]
        if(![string]::IsNullOrEmpty($rollForwardAzurePSVersion)) {
            $hostedAgentAzModulePath = Get-SavedModulePath -azurePowerShellVersion $rollForwardAzurePSVersion
        
            if((Test-Path -Path $hostedAgentAzModulePath) -eq $true) {
                Write-Warning (Get-VstsLocString -Key "OverrideAzurePowerShellVersion" -ArgumentList $azurePowerShellVersion, $rollForwardAzurePSVersion)
                return $rollForwardAzurePSVersion;
            }
        }
        return $azurePowerShellVersion
    }
    finally {
        Trace-VstsLeavingInvocation $MyInvocation
    }
}

function  Get-InputForRunScript {
    [CmdletBinding()]
    param()

    $targetAzurePs = Get-VstsInput -Name TargetAzurePs
    $serviceName = Get-VstsInput -Name ConnectedServiceNameARM -Require
    $endpoint = Get-VstsEndpoint -Name $serviceName -Require
}