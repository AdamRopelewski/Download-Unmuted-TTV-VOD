$starting_path = Get-Location
#Data
$currentDate = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
# Get the chunk URL from the user
$url = Read-Host "Enter the chunk URL (e.g., https://example.com/chunked/1163.ts): "

if ($url -eq "") {
    Write-Host "No chunk URL provided." -ForegroundColor Red
    exit
}

# Extract the base URL from the provided URL (i.e., the part before the chunk number)
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

# Get the end time of the video in seconds
$end_seconds = Read-Host "Enter the end time of the video in hh;mm;ss format (if empty 5h)"
if ($end_seconds -eq "") {
    $end_seconds = "05;00;00"
}
$end_seconds = $end_seconds.Replace(":", ";")
$hours, $minutes, $seconds = $end_seconds.Split(";")
$end_seconds = [int]$hours * 3600 + [int]$minutes * 60 + [int]$seconds

$starting_chunk = [int]($starting_seconds / $chunk_duration)

# Calculate the number of chunks based on the video duration
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

# Create a file with chunk URLs
for ($i = $starting_chunk; $i -lt $last_chunk; $i++) {
    $chunk_url = $base_url + ($i + 1) + ".ts"
    Add-Content -Path "links.txt" -Value $chunk_url
}
Write-Host "Created the links.txt file."

# Start downloading using wget
Write-Host "`n`nStarting wget.`n`n"

# Remove previous .ts files (if any)
Remove-Item *.ts

# Initialize consecutive 403 error counter
$consecutive403 = 0
$shouldExitLoop = $false
# Go through each URL in the links.txt file
Get-Content "links.txt" | ForEach-Object {
    # If the flag indicates the end of the loop, break it
    if ($shouldExitLoop) {
        return
    }
    # Execute wget command for each URL and capture the response status code
    $url = $_
    Write-Host "$url"

    # Write-Host "Downloading: $url"
    if ($consecutive403 -ge 1) {
        Write-Host "Consecutive 403 errors: $consecutive403"
    }

    $response = wget $url -S 2>&1 
    $responseSpeed = $response | Select-String "saved"
    $response = $response | Select-String "HTTP/1.1"

    # Check if the response contains a 403 status code
    if ($response -match "403") {
        $consecutive403++
    } else {
        # Reset the counter if the status code is not 403
        $consecutive403 = 0
        Write-Host "Download speed: $responseSpeed"
    }

    # If there are more than 20 consecutive 403 errors, exit the loop
    if ($consecutive403 -ge 20) {
        Write-Host "20 consecutive 403 errors - stopping download."
        $shouldExitLoop = $true
    }
}

# Run ffmpeg to combine the .ts files into one video
Write-Host "`n`nStarting ffmpeg.`n`n"

# Get the list of .ts files and sort them
$files = Get-ChildItem *.ts | Sort-Object { [int]($_.BaseName) } 
$concat = $files | ForEach-Object { "file '$($_.Name)'" }

# Save the list of files to concat.txt
$concat | Out-File -FilePath "concat.txt"

# Combine the files using ffmpeg and save the result as VODunmuted.mp4
ffmpeg -f concat -safe 0 -i "concat.txt" -y -c copy "$starting_path\VODunmuted-$currentdate.mp4"

# Remove the .ts and .txt files
Remove-Item *.ts
Remove-Item *.txt

# Return to the starting directory
Set-Location $starting_path

# Remove the temporary folder
Remove-Item -Path $folderPath -Recurse -Force
