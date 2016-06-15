# Load the Helper Module
Import-Module -Name "$PSScriptRoot\..\Helper.psm1" -Verbose:$false

# Localized messages
data LocalizedData
{
    # culture="en-US"
    ConvertFrom-StringData @'
        NoWebAdministrationModule   =   Please ensure that WebAdministration module is installed.
        UnableToGetConfig           =   Unable to get configuration data for '{0}'
        ChangedMessage              =   Changed overrideMode for '{0}' to {1}
        VerboseGetTargetPresent     =   OverrideMode is present
        VerboseGetTargetAbsent      =   OvertideMode is absent
'@
}

function Get-TargetResource
{
    [OutputType([Hashtable])]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $SectionName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Allow', 'Deny')]
        [String] $OverrideMode
    )

    [string] $oMode = Get-OverrideMode -section $SectionName

    if ($oMode -eq $OverrideMode)
    {
        Write-Verbose -Message $LocalizedData.VerboseGetTargetPresent
        $ensureResult = 'Present'
    }
    else
    {
        Write-Verbose -Message $LocalizedData.VerboseGetTargetAbsent
        $ensureResult = 'Absent'
    }

    return @{
        SectionName = $SectionName
        OverrideMode = $oMode
        Ensure = $ensureResult
    }
}

function Set-TargetResource
{
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String] $SectionName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Allow', 'Deny')]
        [String] $OverrideMode
    )

     Write-Verbose($($LocalizedData.ChangedMessage) -f $SectionName, $OverrideMode)
     Set-WebConfiguration -Location '' `
                          -Filter "/system.webServer/$SectionName" `
                          -PSPath 'machine/webroot/apphost' `
                          -Metadata overrideMode `
                          -Value $OverrideMode
}

function Test-TargetResource
{
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$SectionName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Allow', 'Deny')]
        [String]$OverrideMode
    )

    [string] $oMode = Get-OverrideMode -Section $SectionName

    if ($oMode -eq $OverrideMode)
    {
        return $true
    }

    return $false
}

#region Helper Functions
Function Get-OverrideMode
{
    <#
    .NOTES
        Check for a single value.
        If $oMode is anything but Allow or Deny, we have a problem with our 
        Get-WebConfiguration call or the ApplicationHost.config file is corrupted.
    #>
    param
    (
        [string] $Section
    )

    Assert-Module

    [string] $oMode = ((Get-WebConfiguration -Location '' `
                                             -Filter /system.webServer/$Section `
                                             -Metadata).Metadata).effectiveOverrideMode

    if ($oMode -notmatch "^(Allow|Deny)$")
    {
        $errorMessage = $($LocalizedData.UnableToGetConfig) -f $Section
        New-TerminatingError -ErrorId UnableToGetConfig `
                             -ErrorMessage $errorMessage `
                             -ErrorCategory:InvalidResult
    }

    return $oMode
}

#endregion

Export-ModuleMember -function *-TargetResource
