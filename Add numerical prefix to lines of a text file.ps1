# Created by Jacques Boucher
# jjrboucher@gmail.com
# 10 April 2023
#
# This script will allow the user to select a text file.
# It does not validate that it's a text file, user responsible to select correct file.
# It will  add a numerical prefix to each line of the text file, padding it to N digits (N defined by the variable $padding).
#
# The new file is created with the name of the old file, and adding ".numbered on dd_MMM_yyyy-HH_mm_ss.txt" to the end.

# If the destination file already exists (e.g., you run this a second time agains the same source file, resulting in the same destination file), it appends to it.
# So if you run it and it's not what you want, delete the renumbered file and re-run.


############################### Variables ############################################
$padding=4 # The padding you want to add. E.g., 4 means #1 will be 0001 (4 digits long).
$paddingChar="0" # character you want to pad with. if you prefer "   1" instead of "0001", change the paddingChar to a space " ".
$linecount=0
######################################################################################

function Get-FileName {  
    [CmdletBinding()]  
    Param (   
        [Parameter(Mandatory = $false)]  
        [string]$WindowTitle = 'Text File to prepend numbering',

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
            $selected = $openFileDialog.Filename
    }
    # clean-up
    $openFileDialog.Dispose()

    return $selected
}

$fileToRenumber=Get-FileName # calls the function, presenting the user with a Windows explorer type window to navigate and select a file.
$numberedFile=$fileToRenumber+".numbered on "+[DateTime]::Now.ToString("dd_MMM_yyyy-HH_mm_ss")+".txt" # new file - saved at same path as file selected.

if($fileToRenumber -eq $null) <# If the user hits CANCEL, exit the script #>
    {
        exit
    }

foreach ($line in (Get-Content -LiteralPath $fileToRenumber)) { # loops through each line of the text file
    $linecount++ # increments the number
    [string]$linecountS=$linecount # converts the numnber to a string
    $linecountS=$linecountS.PadLeft($padding,$paddingChar) # pads the numerical string.
    $newline = ""+$linecountS+" "+$line # combines the padded line number with the line of text
    Add-Content -LiteralPath $numberedFile $newline # appends the line to the file
}