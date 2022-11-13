<# Developed by Jacques Boucher
    Date: 7 Nov 2022
    Bug fixes: 1-Script wasn't working if you only selected one file to hash.
                 It worked fine when selecting more than one. Added a check
                 of the variable type. If a string, it means the user only selected
                 one file to hash so it processes it slightly different.

               2-Also moved the second assignment of $csvFile to after $tFile is assigned.
                 In the previous version it was assigned at the start of the script which wouldn't
                 have resulted in the correct assignment as $tFile was not yet declared at that point.

    Enhancements: 1 - Added variables for each type of supported hash. You can edit the script
                      to have it calculate the hash(es) you prefer.
                  2 - On 31 Oct 2022, added -LiteralPath to the Get-FileHash command to deal with speacial characters. Otherwise, the file is not processed by Get-FileHash when it contains special characters.
                  3 - On 1 Nov 2022, converted array of hashes to a dictionary to streamline code.
                  4 - On 7 Nov 2022, created CSV with all selected hashes on a single line with proper headers.

 #>


<# Global Variables to configure script behaviour without needing to change code. #>

$csvFile = "Hash-values("+[DateTime]::Now.ToString("dd_MMM_yyyy-HH_mm_ss")+").csv" <# Number_exhibits.log - path will be appended based on the path of the files selected by the user #>
$csvHeader = "Name, Path"

<# Hashing algorithms to use. 1 = True, 0 = False #>
$MACTripleDesHash = 0
$md5Hash = 1
$RIPEMD160Hash = 0
$sha1Hash = 0
$sha256Hash = 1
$sha384Hash = 0
$sha512Hash = 0


$hashes = @{} <# Declare an empty dictionary #>
<# adding hashing algorithms to the dictionary and corresponding values from above variables #>

$hashes = [Ordered]@{MacTripleDES=$MACTripleDesHash; MD5=$md5Hash; RIPEMD160=$RIPEMD160Hash; SHA1=$sha1Hash; SHA256=$sha256Hash; SHA384=$sha384Hash; SHA512=$sha512Hash}

ForEach ($hash in $hashes.keys) { <# Loop through the dictionary keys, which are the hashing algorithms supported by PowerShell #>
   if($hashes.$hash) <# If the associated value is 1, then add to header. #>
       {
       $csvheader = $csvHeader + ", " + $hash
       }
   }


function Get-FileName {  
    [CmdletBinding()]  
    Param (   
        [Parameter(Mandatory = $false)]  
        [string]$WindowTitle = 'Open',

        [Parameter(Mandatory = $false)]
        [string]$InitialDirectory,  

        [Parameter(Mandatory = $false)]
        [string]$Filter = "All files (*.*)|*.*",

        [switch]$AllowMultiSelect
    ) 
    Add-Type -AssemblyName System.Windows.Forms

    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Title  = $WindowTitle
    $openFileDialog.Filter = $Filter
    $openFileDialog.CheckFileExists = $true
    if (![string]::IsNullOrWhiteSpace($InitialDirectory)) { $openFileDialog.InitialDirectory = $InitialDirectory }
    if ($AllowMultiSelect) { $openFileDialog.MultiSelect = $true }

    if ($openFileDialog.ShowDialog().ToString() -eq 'OK') {
        if ($AllowMultiSelect) { 
            $selected = @($openFileDialog.Filenames)
        } 
        else { 
            $selected = $openFileDialog.Filename
        }
    }
    # clean-up
    $openFileDialog.Dispose()

    return $selected
}

[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')

$scriptFolder = Get-ChildItem $MyInvocation.MyCommand.Path
$scriptFolder = $scriptFolder.Directory



$winTitle = "Files to Hash"

$Folder=''
$originalFiles = Get-FileName -WindowTitle $winTitle -InitialDirectory $Folder -AllowMultiSelect

if($originalFiles -eq $null) <# If the user hits CANCEL #>
    {
        exit
    }


if($originalFiles.GetType().Name -eq "String") <# Only selected 1 file to hash, so not an array #>
    {
    $tFile = (Get-ChildItem -LiteralPath $originalFiles)
    }
    else <# Selected more than one file to hash, so it's an array #>
        {
        $tFile = (Get-ChildItem -LiteralPath $originalFiles[0])
        }

$csvFile = (($tFile.Directory.FullName) + "\" + $csvFile)
"sep=," | Out-File $csvFile <# Writes instructions to Excel (first line of csv) that the separator is a comma #>
$csvHeader | Out-File -Append $csvFile <# Write header #>

ForEach ($originalFileTemp in $originalFiles) {
    $originalFile = Get-ChildItem -LiteralPath $originalFileTemp <# converts string to filename #>
    $csvLine = $originalFile.Name + ", " + $originalFile.Directory
    Write-Host "Hashing $originalFile"
     ForEach ($hash in $hashes.keys) { <# Loop through the dictionary keys, which are the hashing algorithms supported by PowerShell #>
        if($hashes.$hash) <# If the associated value is 1, then calculate that hash. #>
            {
            $tHash = Get-FileHash -Algorithm $hash -LiteralPath $originalFile
            $csvLine = $csvLine + ", " + $tHash.Hash
            }
        }
    $csvLine | Out-File -Append $csvFile
    }
