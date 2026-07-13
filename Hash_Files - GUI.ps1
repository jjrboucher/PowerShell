<# 
    Hash_Files_GUI.ps1
    Originally developed by Jacques Boucher (31 Jul 2024)
    GUI enhancement: adds a full Windows Forms interface.
    Date: 9 July 2026

    Features:
      - "Add Files..."  : multi-select file picker; files are added to the list.
      - "Add Folder..." : folder picker; user is asked whether to include
                          files from subfolders recursively.
      - File list shown in a ListView; user can select one or more entries
        and remove them ("Remove Selected"), or clear the whole list.
      - Hash algorithms selectable via checkboxes (defaults: MD5 + SHA256,
        matching the original script's defaults).
      - Progress bar and status label while hashing.
      - Output CSV written to the folder of the first file in the list,
        using the same naming convention as the original script.
      - Uses -LiteralPath throughout to handle special characters such as
        square brackets (carried over from the original bug fixes).
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ---------------------------------------------------------------------------
# Main form
# ---------------------------------------------------------------------------
$form                 = New-Object System.Windows.Forms.Form
$form.Text            = "File Hasher"
$form.Size            = New-Object System.Drawing.Size(820, 660)
$form.MinimumSize     = New-Object System.Drawing.Size(700, 560)
$form.StartPosition   = "CenterScreen"
$form.Font            = New-Object System.Drawing.Font("Segoe UI", 9)

# ---------------------------------------------------------------------------
# File list (ListView)
# ---------------------------------------------------------------------------
$lblFiles             = New-Object System.Windows.Forms.Label
$lblFiles.Text        = "Files to hash:"
$lblFiles.Location    = New-Object System.Drawing.Point(12, 12)
$lblFiles.AutoSize    = $true
$form.Controls.Add($lblFiles)

$listView             = New-Object System.Windows.Forms.ListView
$listView.Location    = New-Object System.Drawing.Point(12, 34)
$listView.Size        = New-Object System.Drawing.Size(640, 330)
$listView.View        = [System.Windows.Forms.View]::Details
$listView.FullRowSelect = $true
$listView.MultiSelect = $true
$listView.GridLines   = $true
$listView.HideSelection = $false
$listView.Anchor      = "Top,Bottom,Left,Right"
[void]$listView.Columns.Add("Name", 220)
[void]$listView.Columns.Add("Path", 400)
$form.Controls.Add($listView)

# Keeps full paths; ListView items mirror this (Tag holds the full path).
$script:fileList = New-Object System.Collections.Generic.List[string]

function Add-FileToList {
    param([string]$FullPath)
    # Avoid duplicates (case-insensitive on Windows)
    foreach ($existing in $script:fileList) {
        if ($existing -ieq $FullPath) { return }
    }
    $fi = Get-Item -LiteralPath $FullPath -ErrorAction SilentlyContinue
    if ($null -eq $fi -or $fi.PSIsContainer) { return }
    $script:fileList.Add($FullPath)
    $item = New-Object System.Windows.Forms.ListViewItem($fi.Name)
    [void]$item.SubItems.Add($fi.DirectoryName)
    $item.Tag = $FullPath
    [void]$listView.Items.Add($item)
}

function Update-Status {
    $lblStatus.Text = "$($script:fileList.Count) file(s) in list."
}

# ---------------------------------------------------------------------------
# Buttons: Add Files / Add Folder / Remove Selected / Clear All
# ---------------------------------------------------------------------------
$btnAddFiles          = New-Object System.Windows.Forms.Button
$btnAddFiles.Text     = "Add Files..."
$btnAddFiles.Location = New-Object System.Drawing.Point(662, 34)
$btnAddFiles.Size     = New-Object System.Drawing.Size(130, 30)
$btnAddFiles.Anchor   = "Top,Right"
$form.Controls.Add($btnAddFiles)

$btnAddFolder          = New-Object System.Windows.Forms.Button
$btnAddFolder.Text     = "Add Folder..."
$btnAddFolder.Location = New-Object System.Drawing.Point(662, 70)
$btnAddFolder.Size     = New-Object System.Drawing.Size(130, 30)
$btnAddFolder.Anchor   = "Top,Right"
$form.Controls.Add($btnAddFolder)

$btnRemove             = New-Object System.Windows.Forms.Button
$btnRemove.Text        = "Remove Selected"
$btnRemove.Location    = New-Object System.Drawing.Point(662, 116)
$btnRemove.Size        = New-Object System.Drawing.Size(130, 30)
$btnRemove.Anchor      = "Top,Right"
$form.Controls.Add($btnRemove)

$btnClear              = New-Object System.Windows.Forms.Button
$btnClear.Text         = "Clear All"
$btnClear.Location     = New-Object System.Drawing.Point(662, 152)
$btnClear.Size         = New-Object System.Drawing.Size(130, 30)
$btnClear.Anchor       = "Top,Right"
$form.Controls.Add($btnClear)

# ---------------------------------------------------------------------------
# Hash algorithm checkboxes
# ---------------------------------------------------------------------------
$grpHashes            = New-Object System.Windows.Forms.GroupBox
$grpHashes.Text       = "Hash algorithms"
$grpHashes.Location   = New-Object System.Drawing.Point(12, 374)
$grpHashes.Size       = New-Object System.Drawing.Size(640, 80)
$grpHashes.Anchor     = "Bottom,Left,Right"
$form.Controls.Add($grpHashes)

# Algorithm name -> default checked state (matches original script defaults).
# Note: MACTripleDES and RIPEMD160 are only available in Windows PowerShell 5.1,
# not in PowerShell 7+. They are included but may fail on newer versions.
$algorithmDefaults = [Ordered]@{
    MACTripleDES = $false
    MD5          = $true
    RIPEMD160    = $false
    SHA1         = $false
    SHA256       = $true
    SHA384       = $false
    SHA512       = $false
}

$script:hashCheckboxes = @{}
$x = 15; $y = 22; $col = 0
foreach ($alg in $algorithmDefaults.Keys) {
    $cb          = New-Object System.Windows.Forms.CheckBox
    $cb.Text     = $alg
    $cb.Checked  = $algorithmDefaults[$alg]
    $cb.AutoSize = $true
    $cb.Location = New-Object System.Drawing.Point($x, $y)
    $grpHashes.Controls.Add($cb)
    $script:hashCheckboxes[$alg] = $cb
    $col++
    $x += 155
    if ($col -eq 4) { $col = 0; $x = 15; $y += 28 }
}

# ---------------------------------------------------------------------------
# Output folder selection
# ---------------------------------------------------------------------------
$lblOutput            = New-Object System.Windows.Forms.Label
$lblOutput.Text       = "Output folder:"
$lblOutput.Location   = New-Object System.Drawing.Point(12, 466)
$lblOutput.AutoSize   = $true
$lblOutput.Anchor     = "Bottom,Left"
$form.Controls.Add($lblOutput)

$txtOutputFolder          = New-Object System.Windows.Forms.TextBox
$txtOutputFolder.Location = New-Object System.Drawing.Point(100, 462)
$txtOutputFolder.Size     = New-Object System.Drawing.Size(552, 24)
$txtOutputFolder.Anchor   = "Bottom,Left,Right"
# Empty = default behaviour: CSV goes to the folder of the first file in the list.
$form.Controls.Add($txtOutputFolder)

$btnBrowseOutput          = New-Object System.Windows.Forms.Button
$btnBrowseOutput.Text     = "Browse..."
$btnBrowseOutput.Location = New-Object System.Drawing.Point(662, 460)
$btnBrowseOutput.Size     = New-Object System.Drawing.Size(130, 28)
$btnBrowseOutput.Anchor   = "Bottom,Right"
$form.Controls.Add($btnBrowseOutput)

# ---------------------------------------------------------------------------
# Progress bar, status label, Start button
# ---------------------------------------------------------------------------
$progress             = New-Object System.Windows.Forms.ProgressBar
$progress.Location    = New-Object System.Drawing.Point(12, 500)
$progress.Size        = New-Object System.Drawing.Size(640, 24)
$progress.Anchor      = "Bottom,Left,Right"
$form.Controls.Add($progress)

$lblStatus            = New-Object System.Windows.Forms.Label
$lblStatus.Text       = "0 file(s) in list."
$lblStatus.Location   = New-Object System.Drawing.Point(12, 532)
$lblStatus.Size       = New-Object System.Drawing.Size(640, 40)
$lblStatus.Anchor     = "Bottom,Left,Right"
$form.Controls.Add($lblStatus)

$btnHash              = New-Object System.Windows.Forms.Button
$btnHash.Text         = "Start Hashing"
$btnHash.Location     = New-Object System.Drawing.Point(662, 500)
$btnHash.Size         = New-Object System.Drawing.Size(130, 40)
$btnHash.Anchor       = "Bottom,Right"
$btnHash.Font         = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnHash)

$btnClose             = New-Object System.Windows.Forms.Button
$btnClose.Text        = "Close"
$btnClose.Location    = New-Object System.Drawing.Point(662, 546)
$btnClose.Size        = New-Object System.Drawing.Size(130, 30)
$btnClose.Anchor      = "Bottom,Right"
$form.Controls.Add($btnClose)

# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------
$btnAddFiles.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title           = "Select files to hash"
    $dlg.Filter          = "All files (*.*)|*.*"
    $dlg.Multiselect     = $true
    $dlg.CheckFileExists = $true
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        foreach ($f in $dlg.FileNames) { Add-FileToList -FullPath $f }
        Update-Status
    }
    $dlg.Dispose()
})

$btnAddFolder.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Select a folder containing files to hash"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $folder = $dlg.SelectedPath
        $answer = [System.Windows.Forms.MessageBox]::Show(
            "Add all files from subfolders recursively?`n`nYes  = include subfolders`nNo   = this folder only",
            "Recursive?",
            [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
            [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($answer -ne [System.Windows.Forms.DialogResult]::Cancel) {
            $recurse = ($answer -eq [System.Windows.Forms.DialogResult]::Yes)
            $lblStatus.Text = "Scanning folder..."
            $form.Refresh()
            $files = if ($recurse) {
                Get-ChildItem -LiteralPath $folder -File -Recurse -ErrorAction SilentlyContinue
            } else {
                Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue
            }
            $listView.BeginUpdate()
            foreach ($f in $files) { Add-FileToList -FullPath $f.FullName }
            $listView.EndUpdate()
            Update-Status
        }
    }
    $dlg.Dispose()
})

$btnRemove.Add_Click({
    # Remove from the bottom up so indices stay valid.
    $selected = @($listView.SelectedItems)
    if ($selected.Count -eq 0) {
        [void][System.Windows.Forms.MessageBox]::Show(
            "Select one or more files in the list first.",
            "Nothing selected",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }
    foreach ($item in $selected) {
        [void]$script:fileList.Remove([string]$item.Tag)
        $listView.Items.Remove($item)
    }
    Update-Status
})

$btnClear.Add_Click({
    $script:fileList.Clear()
    $listView.Items.Clear()
    Update-Status
})

$btnBrowseOutput.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Select the folder where the CSV file will be saved"
    if (-not [string]::IsNullOrWhiteSpace($txtOutputFolder.Text) -and (Test-Path -LiteralPath $txtOutputFolder.Text)) {
        $dlg.SelectedPath = $txtOutputFolder.Text
    }
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtOutputFolder.Text = $dlg.SelectedPath
    }
    $dlg.Dispose()
})

$btnClose.Add_Click({ $form.Close() })

# Allow the Delete key to remove selected files as well.
$listView.Add_KeyDown({
    param($sender, $e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Delete) {
        $btnRemove.PerformClick()
    }
})

# ---------------------------------------------------------------------------
# Hashing
# ---------------------------------------------------------------------------
$btnHash.Add_Click({
    if ($script:fileList.Count -eq 0) {
        [void][System.Windows.Forms.MessageBox]::Show(
            "Add at least one file to the list first.",
            "No files",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $selectedAlgs = @($script:hashCheckboxes.Keys | Where-Object { $script:hashCheckboxes[$_].Checked })
    # Preserve the original ordered sequence of algorithms.
    $selectedAlgs = @($algorithmDefaults.Keys | Where-Object { $script:hashCheckboxes[$_].Checked })
    if ($selectedAlgs.Count -eq 0) {
        [void][System.Windows.Forms.MessageBox]::Show(
            "Select at least one hash algorithm.",
            "No algorithm selected",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    # Determine the output folder for the CSV.
    # If the user specified one, validate it; otherwise default to the folder
    # of the first file in the list (the original script's behaviour).
    $outputFolder = $txtOutputFolder.Text.Trim()
    if (-not [string]::IsNullOrWhiteSpace($outputFolder)) {
        if (-not (Test-Path -LiteralPath $outputFolder -PathType Container)) {
            $answer = [System.Windows.Forms.MessageBox]::Show(
                "The output folder does not exist:`n$outputFolder`n`nCreate it?",
                "Output folder not found",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question)
            if ($answer -eq [System.Windows.Forms.DialogResult]::Yes) {
                try {
                    [void](New-Item -ItemType Directory -Path $outputFolder -Force -ErrorAction Stop)
                }
                catch {
                    [void][System.Windows.Forms.MessageBox]::Show(
                        "Could not create the folder:`n$outputFolder`n`n$($_.Exception.Message)",
                        "Error",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Error)
                    return
                }
            }
            else {
                return
            }
        }
    }
    else {
        $firstFile    = Get-Item -LiteralPath $script:fileList[0]
        $outputFolder = $firstFile.DirectoryName
    }

    $csvName = "Hash-values(" + [DateTime]::Now.ToString("dd_MMM_yyyy-HH_mm_ss") + ").csv"
    $csvFile = Join-Path $outputFolder $csvName

    $csvHeader = "Name, Path"
    foreach ($alg in $selectedAlgs) { $csvHeader += "," + $alg }

    try {
        "sep=,"    | Out-File -LiteralPath $csvFile                # Tell Excel the separator is a comma
        $csvHeader | Out-File -Append -LiteralPath $csvFile        # Header row
    }
    catch {
        [void][System.Windows.Forms.MessageBox]::Show(
            "Could not create the CSV file:`n$csvFile`n`n$($_.Exception.Message)",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    # Disable controls during hashing
    $btnHash.Enabled = $false; $btnAddFiles.Enabled = $false; $btnAddFolder.Enabled = $false
    $btnRemove.Enabled = $false; $btnClear.Enabled = $false

    $progress.Minimum = 0
    $progress.Maximum = $script:fileList.Count
    $progress.Value   = 0

    $errors = 0
    $i = 0
    foreach ($path in $script:fileList) {
        $i++
        $fi = Get-Item -LiteralPath $path -ErrorAction SilentlyContinue
        if ($null -eq $fi) {
            $errors++
            $progress.Value = $i
            continue
        }
        $lblStatus.Text = "Hashing ($i of $($script:fileList.Count)): $($fi.Name)"
        $form.Refresh()
        [System.Windows.Forms.Application]::DoEvents()

        $csvLine = $fi.Name + "," + $fi.DirectoryName
        foreach ($alg in $selectedAlgs) {
            try {
                $tHash   = Get-FileHash -Algorithm $alg -LiteralPath $fi.FullName -ErrorAction Stop
                $csvLine += "," + $tHash.Hash
            }
            catch {
                $csvLine += ",ERROR"
                $errors++
            }
        }
        $csvLine | Out-File -Append -LiteralPath $csvFile
        $progress.Value = $i
    }

    # Re-enable controls
    $btnHash.Enabled = $true; $btnAddFiles.Enabled = $true; $btnAddFolder.Enabled = $true
    $btnRemove.Enabled = $true; $btnClear.Enabled = $true

    $summary = "Done. Hashed $($script:fileList.Count) file(s)."
    if ($errors -gt 0) { $summary += " $errors error(s) encountered (marked ERROR in the CSV)." }
    $summary += "`n`nResults saved to:`n$csvFile"
    $lblStatus.Text = "Done. Results: $csvFile"

    [void][System.Windows.Forms.MessageBox]::Show(
        $summary,
        "Hashing complete",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information)
})

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
[void]$form.ShowDialog()
$form.Dispose()
