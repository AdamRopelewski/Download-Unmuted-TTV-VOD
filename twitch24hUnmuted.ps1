$starting_path = Get-Location
# Data
$currentDate = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Get the chunk URL from the user
$url = Read-Host "Enter the chunk URL (e.g., https://example.com/chunked/1163.ts): "

if ($url -eq "") {
    Write-Host "No chunk URL provided." -ForegroundColor Red
    exit
}

# Extract the base URL from the provided URL
$base_url = $url.Substring(0, $url.LastIndexOf("/") + 1)

# Duration of one chunk in seconds
$chunk_duration = 10

# Get the start time of the video
$starting_seconds = Read-Host "Enter the start time of the video in hh;mm;ss format (if empty 00:00:00)"
if ($starting_seconds -eq "") {
    $starting_seconds = "00;00;00"
}
$starting_seconds = $starting_seconds.Replace(":", ";")
$hours, $minutes, $seconds = $starting_seconds.Split(";")
$starting_seconds = [int]$hours * 3600 + [int]$minutes * 60 + [int]$seconds

# Get the end time of the video
$end_seconds = Read-Host "Enter the end time of the video in hh;mm;ss format (if empty 5h)"
if ($end_seconds -eq "") {
    $end_seconds = "05;00;00"
}
$end_seconds = $end_seconds.Replace(":", ";")
$hours, $minutes, $seconds = $end_seconds.Split(";")
$end_seconds = [int]$hours * 3600 + [int]$minutes * 60 + [int]$seconds

$starting_chunk = [int]($starting_seconds / $chunk_duration)
$last_chunk = [int]($end_seconds / $chunk_duration)

$total_seconds = $end_seconds - $starting_seconds
if ($total_seconds -le 0) {
    Write-Host "The end time must be later than the start time." -ForegroundColor Red
    exit
}

# Calculate the number of chunks
$num_chunks = $last_chunk - $starting_chunk
Write-Host "`n`nMaximum number of chunks: $num_chunks"

# Path to the temporary folder
$folderPath = Join-Path -Path $env:TEMP -ChildPath "twitch24Unmuted-temp-$currentDate"

# Create the temporary folder if it doesn't exist
if (-Not (Test-Path -Path $folderPath)) {
    New-Item -Path $folderPath -ItemType Directory
}

# Change directory to the temporary folder
Set-Location $folderPath

# Remove the links.txt file if it exists
if (Test-Path "links.txt") {
    Remove-Item "links.txt"
}

# Generate all chunk URLs in memory
$chunk_urls = for ($i = $starting_chunk; $i -lt $last_chunk; $i++) { 
    "$base_url$($i + 1).ts"
}

# Write all URLs to the file at once
$chunk_urls -join "`n" | Set-Content -Path "links.txt"

Write-Host "Created the links.txt file."

# Start downloading using Invoke-WebRequest
Write-Host "`n`nStarting download.`n`n"

# Remove previous .ts files (if any)
Remove-Item *.ts -ErrorAction SilentlyContinue

# Initialize consecutive 403 error counter
$consecutive403 = 0
$shouldExitLoop = $false

# Go through each URL in the links.txt file
Get-Content "links.txt" | ForEach-Object {
    if ($shouldExitLoop) { return }
    
    $url = $_
    Write-Host "Downloading: $url"

    try {
		$response = wget.exe $url -q --show-progress --progress=bar:force --no-check-certificate


        if ($response.StatusCode -eq 200) {
            Write-Host "Downloaded: $url"
            $consecutive403 = 0  # Reset consecutive 403 counter
        }
    } catch {
        if ($_.Exception.Response.StatusCode -eq 403) {
            $consecutive403++
            Write-Host "403 Forbidden - Attempt: $consecutive403"
        }

        if ($consecutive403 -ge 30) {
            Write-Host "30 consecutive 403 errors - stopping download."
            $shouldExitLoop = $true
        }
    }
}

# Run ffmpeg to combine the .ts files into one video
Write-Host "`n`nStarting ffmpeg.`n`n"

$files = Get-ChildItem *.ts | Sort-Object { [int]($_.BaseName) }

# Create the concat file entries
$concat = $files | ForEach-Object { "file '$($_.Name)'" }

# Create the UTF-8 encoding without BOM
$utf8NoBOM = New-Object System.Text.UTF8Encoding $false

# Write to file without BOM
[System.IO.File]::WriteAllLines(
    (Join-Path -Path $folderPath -ChildPath "concat.txt"),
    $concat,
    $utf8NoBOM
)


# Combine the files using ffmpeg and save the result as VODunmuted.mp4
ffmpeg -f concat -safe 0 -i "concat.txt" -y -c copy "$starting_path\VODunmuted-$currentdate.mp4"

# Remove the .ts and .txt files
Remove-Item *.ts
Remove-Item *.txt

# Return to the starting directory
Set-Location $starting_path

# Remove the temporary folder
Remove-Item -Path $folderPath -Recurse -Force
