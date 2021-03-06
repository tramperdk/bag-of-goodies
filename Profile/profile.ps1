## Importing Modules
# PSColors colorizes output of different cmdlets (Get-Service, Get-ChildItem etc.)
Import-Module PSColor

## Static variables
# Elevated check - Todo: Use this somewhere.. or change apperance so we know we need to tread carefully.
# $Admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Host title, there's actually a char in there...
$Host.UI.RawUI.WindowTitle = "​" #https://www.fileformat.info/info/unicode/char/200B/index.htm

# Aliases for various tools 
Set-Alias -Name "nano" -Value "C:\Users\sla\OneDrive - BIZBRAINS A S\nano.exe"
Set-Alias -Name "cpick" -Value "C:\Users\sla\OneDrive - BIZBRAINS A S\jcpicker.exe"
Set-Alias -Name "image" -Value "C:\Users\sla\OneDrive - BIZBRAINS A S\NexusImage.exe"

# Set new colors for PSColor
$global:PSColor.File.Directory.Color = 'Blue'
$global:PSColor.File.Executable.Color = 'Green'

## Functions
# scrot - Screenshot function, sort of like linux scrot but with system information printed and formatted beforehand.
Function scrot {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$false)]
        [switch]$ClearHost,
        [parameter(Mandatory=$false)]
        [int]$Timeout = 3,
        [parameter(Mandatory=$false)]
        [string]$OutputPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop),
        [parameter(Mandatory=$false)]
        [switch]$OpenAfterShot,
        [parameter(Mandatory=$false)]
        [switch]$PrintOnly
    )
    # We need to use System.Windows.Forms for getting screen bounds etc.
    Add-Type -AssemblyName System.Windows.Forms

    # Clear console if ClearHost switch is supplied ("scrot -ClearHost")
    if ($ClearHost) { Clear-Host }

    # Gather various information from WMI (Todo: Try to convert these to CIM)
    $computer    = Get-WmiObject Win32_ComputerSystem
    $os          = Get-WmiObject Win32_OperatingSystem
    $processor   = Get-WmiObject Win32_Processor
    $display     = Get-WmiObject Win32_DisplayConfiguration
    $network     = Get-WmiObject Win32_NetworkAdapterConfiguration
    $uptime      = $os.ConvertToDateTime($os.LocalDateTime) - $os.ConvertToDateTime($os.LastBootUpTime)
    $ipAddresses = ($network | Where-Object IPAddress | ForEach-Object { $_.IPAddress[0] }) -join ", "

    # Create various hashtables
    $Computer   = @{ "HOST" = "$($env:computername) - $($computer.Model), $($computer.Manufacturer)" }
    $Uptime     = @{ "RUN" = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m $($uptime.Seconds)s" }
    $OS         = @{ "OS" = "$($os.Caption) $($os.OSArchitecture)"}
    $Kernel     = @{ "BUILD" = "$((Get-WmiObject Win32_OperatingSystem).Version)"}
    $CPU        = @{ "CPU" = "$($processor.Name)"}
    $GPU        = @{ "GPU" = "$($display.DeviceName)"}
    $RAM        = @{ "RAM" = "$([math]::Truncate((Get-WmiObject Win32_OperatingSystem).FreePhysicalMemory / 1KB)) MB / $([math]::Truncate(((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory) / 1MB)) MB"}
    $NET        = @{ "NET" = "$ipAddresses"}
    $Shell      = @{ "SHELL" = "PowerShell v$($Host.Version)"}

    # Create array with hashtables
    $InformationArray = $Computer, $Uptime, $OS, $Kernel, $CPU, $GPU, $RAM, $NET, $Shell

    # To get all colors : [enum]::GetNames([System.ConsoleColor])
    # These are the colors we want to use for our 
    $Colors = @(
        "DarkRed"
        "DarkGreen"
        "DarkYellow"
        "Blue"
        "DarkMagenta"
        "DarkCyan"
        "Gray"
    )

    foreach ($Information in $InformationArray) {
        Write-Host -NoNewline "[" -ForegroundColor Yellow
        Write-Host -NoNewline "$($Information.Keys)" 
        Write-Host -NoNewline "]`t" -ForegroundColor Yellow
        Write-Host -NoNewline " : "
        Write-Host "$($Information.Values)" -ForegroundColor Yellow
    }
    
    Write-Host ""
    $Colors | ForEach-Object { Write-Host -NoNewline "    " -BackgroundColor $_ }
    Write-Host ""

    if ($PrintOnly) {  } # PrintOnly specified, no need to take a screenshot.
    else {
        Write-Host -NoNewline "Taking screenshot in : "
        $Timeout..1 | ForEach-Object { Write-Host -NoNewline "$_.. "; Start-Sleep -Seconds 1}
        $OutputPath = Join-Path $OutputPath "scrot_$(Get-Random -Maximum $([System.Int32]::MaxValue)).png"
        $Bitmap = New-Object System.Drawing.Bitmap([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width, [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height)
        $Graphics = [System.Drawing.Graphics]::FromImage($Bitmap)
        $Graphics.CopyFromScreen((New-Object System.Drawing.Point(0,0)), (New-Object System.Drawing.Point(0,0)), $Bitmap.Size)
        $Graphics.Dispose()
        $Bitmap.Save($OutputPath)
        "Screenshot saved to $OutputPath"
        if ($OpenAfterShot) { .$OutputPath }   
    }
}
function Get-AzureLoginState
{
    Try {
        if ([string]::IsNullOrEmpty((Get-AzureRmContext).Account)) { return $false } 
        else { return $true }
    } 
    Catch {
        return $false
    }
}

# Prompt - Making it fancy.
function Prompt {
	#Set our Color variables. 
	$DelimiterColor = [ConsoleColor]::Yellow 
	$HostColor = [ConsoleColor]::Green 
	$LocationColor = [ConsoleColor]::Cyan 

	Write-Host -NoNewline -ForegroundColor $HostColor ("$(([Environment]::UserName).ToUpper())")
	write-Host -NoNewline ' @ '
	write-Host -NoNewline -ForegroundColor $HostColor ([net.dns]::GetHostName()) 
	write-Host -NoNewline -ForegroundColor $DelimiterColor ' [' 
    Write-Host -NoNewline -ForegroundColor $LocationColor (Get-ShortPath (Get-Location).Path)  
    write-host -NoNewline -ForegroundColor $DelimiterColor '] ❯' # Unicode char is 'heavy right-pointing angle quotation mark ornament'
	return ' '
}

# Shorten path to eg. ~\D\W\Scripts
function Get-ShortPath([string] $Path) { 
	#Replace the path to $home with '~'
	$Location = $Path.Replace($HOME, '~') 
	# Remove ugly prefixes for UNC paths
	$Location = $Location -Replace '^[^:]+::', '' 
	#RegEx the paths shorter ... i have no idea what I'm doing.
	$Location = $Location -Replace '\\(\.?)([^\\])[^\\]*(?=\\)','\$1$2'
	return $Location.ToUpper()
}