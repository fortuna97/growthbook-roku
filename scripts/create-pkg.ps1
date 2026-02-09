# Create pkg.zip with forward slashes (ZIP spec-compliant)
# Compress-Archive uses backslashes which breaks brs-desktop file loading
param(
    [string]$SourceDir = "test-channel",
    [string]$OutputZip = "test-channel\pkg.zip"
)

Add-Type -Assembly System.IO.Compression
Add-Type -Assembly System.IO.Compression.FileSystem

$sourceFull = [System.IO.Path]::GetFullPath($SourceDir)
$zipFull = [System.IO.Path]::GetFullPath($OutputZip)

# Remove existing zip
if (Test-Path $zipFull) { Remove-Item $zipFull }

# Create zip with forward-slash entry names
$zip = [IO.Compression.ZipFile]::Open($zipFull, [IO.Compression.ZipArchiveMode]::Create)

Get-ChildItem -Path $sourceFull -Recurse -File |
    Where-Object { $_.FullName -ne $zipFull } |
    ForEach-Object {
        $relativePath = $_.FullName.Substring($sourceFull.Length + 1).Replace('\', '/')
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $relativePath) | Out-Null
    }

$zip.Dispose()
Write-Host "Created $OutputZip with forward-slash paths"
