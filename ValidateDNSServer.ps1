# Paths to the input and output files
$dnsFilePath = 'D:\DNSServerCheck\Hong Kong\dns_servers.txt'
$functionableOutputPath = 'D:\DNSServerCheck\Hong Kong\functionableDNS.txt'
$nonfunctionableOutputPath = 'D:\DNSServerCheck\Hong Kong\nonfunctionableDNS.txt'

# Generate a timestamp for the log file name
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFilePath = "D:\DNSServerCheck\Hong Kong\script_log_$timestamp.txt" #Log file path with timestamp

# Capture start time
$startTime = Get-Date

# Read DNS servers from the input file
$dnsServers = Get-Content -Path $dnsFilePath

# Initialize arrays for valid and invalid DNS servers
$functionableDNS = @()
$nonfunctionableDNS = @()

# Create a script block for validating DNS servers
$scriptBlock = {
    param ($server)

    try {
        # Attempt to resolve a known domain (e.g., www.google.com)
        $result = Resolve-DnsName -Name 'www.google.com' -Server $server -ErrorAction Stop
        return @{ Server = $server; Status = 'Functional'; HostName = $result.HostName }
    } catch {
        return @{ Server = $server; Status = 'Non-Functional' }
    }
}

# Initialize jobs for each DNS server
$jobs = @()

foreach ($server in $dnsServers) {
    # Start a job for each DNS server
    $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $server
    $jobs += $job

    # Control the number of concurrent jobs
    if ($jobs.Count -ge 20) {  # Adjust this number based on your system's capability
        # Wait for jobs to complete before starting new ones
        $completedJobs = Wait-Job -Job $jobs
        # Collect results from completed jobs
        foreach ($completedJob in $completedJobs) {
            $result = Receive-Job -Job $completedJob
            Remove-Job -Job $completedJob  # Clean up the job
            if ($result.Status -eq 'Functional') {
                $functionableDNS += $result.Server  # Add to functional list
            } else {
                $nonfunctionableDNS += $result.Server  # Add to non-functional list
            }
        }
        # Reset the jobs array for the next batch
        $jobs = @()
    }
}

# Wait for any remaining jobs to complete
if ($jobs.Count -gt 0) {
    $completedJobs = Wait-Job -Job $jobs
    foreach ($completedJob in $completedJobs) {
        $result = Receive-Job -Job $completedJob
        Remove-Job -Job $completedJob  # Clean up the job
        if ($result.Status -eq 'Functional') {
            $functionableDNS += $result.Server  # Add to functional list
        } else {
            $nonfunctionableDNS += $result.Server  # Add to non-functional list
        }
    }
}

# Write results to output files
$functionableDNS | Set-Content -Path $functionableOutputPath
$nonfunctionableDNS | Set-Content -Path $nonfunctionableOutputPath

# Capture end time
$endTime = Get-Date

# Calculate duration
$duration = $endTime - $startTime

# Format the duration in hh:mm:ss
$durationFormatted = "{0:D2}:{1:D2}:{2:D2}" -f $duration.Hours, $duration.Minutes, $duration.Seconds

# Output the duration
Write-Host "Total duration: $durationFormatted"

# Log the duration to the log file
$logEntry = "Script completed in: $durationFormatted"
Add-Content -Path $logFilePath -Value $logEntry

# Output summary
#Write-Host "Functionable DNS servers saved to: $functionableOutputPath"
#Write-Host "Nonfunctionable DNS servers saved to: $nonfunctionableOutputPath"