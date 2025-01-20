# Twitch Unmuted

This PowerShell script allows you to download and concatenate video chunks from a specified URL, creating a single unmuted video file. The script utilizes `wget` to fetch the video segments and `ffmpeg` to merge them into one file.

## Disclaimer
This script works only within 24 hours of the VOD's publication!

## Prerequisites

- PowerShell
- `wget` command-line tool
- `ffmpeg` command-line tool

## Prerequisite Installation Guide

1. **Install Chocolatey**  
   Download and install Chocolatey by following the instructions [here](https://chocolatey.org/install).

2. **Install FFmpeg**  
   Once Chocolatey is installed, open **Command Prompt** (CMD) or **PowerShell** as Administrator and run the following command to install FFmpeg:
   ```cmd
   choco install ffmpeg
   ```

3. **Install Wget**  
   To install Wget, use the following command in the same elevated terminal:
   ```cmd
   choco install wget
   ```



## Usage

1. Clone the repository or download the `twitch24hUnmuted.ps1` script.
2. Open a PowerShell terminal.
3. Navigate to the directory where the `twitch24hUnmuted.ps1` script is located.
4. Execute the script with the following command:

```powershell
.\twitch24hUnmuted.ps1
```


## Information
1. You need to provide a URL to one of the video chunks, NOT the VOD.
2. The script will use a temporary directory for `.ts` and `.txt` files during execution.
3. Temporary files will be automatically deleted after the script finishes.
4. The resulting `.mp4` output file will be saved in the same directory as the script (`twitch24hUnmuted.ps1`).
5. The script downloads the source quality of VOD.