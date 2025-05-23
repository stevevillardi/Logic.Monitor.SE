<#
.SYNOPSIS
    Identifies and analyzes LogicMonitor alerts that have associated log anomalies.

.DESCRIPTION
    This cmdlet searches for alerts that have corresponding log anomalies within a specified time window.
    It analyzes log messages for sentiment, correlates them with alerts, and provides detailed information
    about the relationships between alerts and anomalous logs.

    The function performs sentiment analysis on log messages using a predefined list of negative terms
    and calculates both individual and aggregate sentiment scores for the logs associated with each alert.

.PARAMETER StartDate
    The beginning of the time range to search for alerts.
    Default: 14 days ago from current time
    
.PARAMETER EndDate
    The end of the time range to search for alerts.
    Default: Current time

.PARAMETER MaxPages
    Maximum number of pages to retrieve when querying log anomalies.
    Default: 10

.PARAMETER BatchSize
    Number of records to retrieve per page when querying log anomalies.
    Default: 500

.OUTPUTS
    Returns an array of custom objects containing:
    - Portal information
    - Alert details (ID, URL, type, severity, etc.)
    - Resource information
    - Instance details
    - Log analysis (count, sentiment scores)
    - Associated anomalous logs with timing and sentiment data

.EXAMPLE
    Find-LMLogAnomalyAlerts
    
    Searches for alert-anomaly correlations from the last 14 days to current time using default parameters.

.EXAMPLE
    Find-LMLogAnomalyAlerts -StartDate (Get-Date).AddDays(-7) -EndDate (Get-Date)
    
    Searches for alert-anomaly correlations from the last 7 days using custom date range.

.EXAMPLE
    Find-LMLogAnomalyAlerts -MaxPages 20 -BatchSize 1000
    
    Searches with increased page limit and batch size for larger environments.

.NOTES
    - Requires active connection to LogicMonitor portal (use Connect-LMAccount first)
    - Processes both cleared and active alerts
    - Matches logs and alerts within a 30-minute time window
    - Sentiment analysis is performed using predefined negative terms
    - Results are sorted by log count, total sentiment score, and severity
    
.LINK
    Module repo: https://github.com/stevevillardi/Logic.Monitor.SE

.LINK
    PSGallery: https://www.powershellgallery.com/packages/Logic.Monitor.SE
#>

Function Find-LMLogAnomalyAlerts {
    [CmdletBinding()]
    Param(
        [DateTime]$StartDate = (Get-Date).AddDays(-14),
        [DateTime]$EndDate = (Get-Date),
        [Int]$MaxPages = 10,
        [Int]$BatchSize = 500
    )
    Write-Information "Starting log anomaly alert matching process..."
    Write-Information "Date Range: $StartDate to $EndDate"

    # Define sentiment terms and weights
    $sentimentTerms = @{
        Critical = @{
            Weight = -3
            Terms = @('fatal', 'crash', 'outage', 'corrupt', 'unreachable')
        }
        High = @{
            Weight = -2
            Terms = @('error', 'exception', 'failure', 'critical', 'severe')
        }
        Medium = @{
            Weight = -1
            Terms = @('warning', 'timeout', 'denied', 'rejected')
        }
        Positive = @{
            Weight = 1
            Terms = @('resolved', 'recovered', 'restored', 'fixed')
        }
    }

    # Function to calculate sentiment score
    function Get-LogSentiment {
        param (
            [string]$message
        )
        $score = 0
        $messageLower = $message.ToLower()
        
        foreach ($severity in $sentimentTerms.Keys) {
            foreach ($term in $sentimentTerms[$severity].Terms) {
                if ($messageLower -match $term) {
                    $score += $sentimentTerms[$severity].Weight
                }
            }
        }
        return $score
    }

    If($(Get-LMAccountStatus).Valid){
        try {
            $Portal = $(Get-LMAccountStatus).Portal
            Write-Information "Account validation successful. Starting data collection..."

            # 1. Collect all alerts
            Write-Information "Collecting alerts from $StartDate to $EndDate..."
            $AllAlerts = @()
            $currentStartDate = $StartDate
            $maxAlertSize = 10000
            
            do {
                $alertBatch = Get-LMAlert -StartDate $currentStartDate -EndDate $EndDate -ClearedAlerts $true -Sort "startEpoch"
                if ($alertBatch) {
                    $AllAlerts += $alertBatch
                    if ($alertBatch.Count -eq $maxAlertSize) {
                        $lastAlert = $alertBatch[-1]
                        $currentStartDate = [DateTimeOffset]::FromUnixTimeSeconds($lastAlert.startEpoch).DateTime.AddSeconds(1)
                        Write-Information "Retrieved $($AllAlerts.Count) alerts, continuing from $currentStartDate..."
                    }
                }
            } while ($alertBatch -and $alertBatch.Count -eq $maxAlertSize -and $currentStartDate -lt $EndDate)

            Write-Information "Retrieved total of $($AllAlerts.Count) alerts"

            # 2. Collect all anomalous logs
            Write-Information "Collecting log anomalies..."
            $Anomalies = Get-LMLogMessage -Query '_anomaly.type="never_before_seen"' -StartDate $StartDate -EndDate $EndDate -Async -MaxPages $MaxPages -BatchSize $BatchSize
            Write-Information "Retrieved $($Anomalies.Count) anomalies"

            if (-not $AllAlerts -or -not $Anomalies) {
                Write-Warning "No data found for analysis"
                return
            }

            # 3. Group alerts by resource
            Write-Information "Organizing data by resource..."
            $alertsByResource = @{}
            foreach ($alert in $AllAlerts) {
                $resourceId = $alert.monitorObjectId
                if (-not $alertsByResource.ContainsKey($resourceId)) {
                    $alertsByResource[$resourceId] = @()
                }
                $alertsByResource[$resourceId] += $alert
            }

            # 4. Group logs by resource
            $logsByResource = @{}
            foreach ($log in $Anomalies) {
                $resourceId = $log._resource.id
                if (-not $logsByResource.ContainsKey($resourceId)) {
                    $logsByResource[$resourceId] = @()
                }
                $logsByResource[$resourceId] += $log
            }

            # 5. Match logs to alerts by resource and time window
            $matchedEvents = @{}
            $processedCount = 0

            Write-Information "Starting matching process..."

            foreach ($log in $Anomalies) {
                $processedCount++
                if ($processedCount % 100 -eq 0) {
                    Write-Information "Processed $processedCount of $($Anomalies.Count) logs..."
                }

                $logTime = [DateTimeOffset]::FromUnixTimeMilliseconds($log.timestamp).DateTime
                $logResourceId = $log._resource.id
                
                Write-Debug "Processing log ID: $($log.id) for resource $logResourceId at time $logTime"
                
                # Find matching alerts for this log
                $matchingAlerts = $AllAlerts | Where-Object {
                    $alertResourceId = $_.monitorObjectId
                    $alertStartTime = [DateTimeOffset]::FromUnixTimeSeconds($_.startEpoch).DateTime
                    
                    ($logResourceId -eq $alertResourceId) -and 
                    ([Math]::Abs(($logTime - $alertStartTime).TotalMinutes) -le 30)
                }
                
                if ($matchingAlerts) {
                    Write-Information "Found $($matchingAlerts.Count) matching alert(s) for log ID: $($log.id)"
                    foreach ($alert in $matchingAlerts) {
                        $alertKey = $alert.id
                        $timeDiff = [Math]::Abs(($logTime - [DateTimeOffset]::FromUnixTimeSeconds($alert.startEpoch).DateTime).TotalMinutes)
                        
                        $logEntry = @{
                            LogId = $log.id
                            LogTimestamp = $logTime
                            LogMessage = $log.message
                            TimeDifferenceMinutes = $timeDiff
                            SentimentScore = Get-LogSentiment -message $log.message
                        }

                        if (-not $matchedEvents.ContainsKey($alertKey)) {
                            $matchedEvents[$alertKey] = @{
                                AlertId = $alert.id
                                ResourceId = $logResourceId
                                AlertTimestamp = [DateTimeOffset]::FromUnixTimeSeconds($alert.startEpoch).DateTime
                                AlertType = $alert.type
                                AlertValue = $alert.alertValue
                                Severity = $alert.severity
                                DatasourceName = $alert.resourceTemplateName
                                ResourceName = $alert.monitorObjectName
                                InstanceName = $alert.instanceName
                                InstanceDescription = $alert.instanceDescription
                                DatapointName = $alert.datapointName
                                AssociatedLogs = @()
                                TotalSentimentScore = 0
                            }
                        }

                        $matchedEvents[$alertKey].AssociatedLogs += $logEntry
                        $matchedEvents[$alertKey].TotalSentimentScore += $logEntry.SentimentScore
                    }
                }
            }

            Write-Information "Matching process complete. Found $($matchedEvents.Count) unique alerts with associated logs."

            # Convert to array and sort by importance
            $sortedResults = $matchedEvents.Values | ForEach-Object {
                [PSCustomObject]@{
                    PortalName = $Portal
                    AlertId = $_.AlertId
                    AlertUrl = "https://$Portal.logicmonitor.com/santaba/uiv4/alerts/$($_.AlertId)"
                    ResourceId = $_.ResourceId
                    DatasourceName = $_.DatasourceName
                    ResourceName = $_.ResourceName
                    InstanceName = $_.InstanceName
                    InstanceDescription = $_.InstanceDescription
                    DatapointName = $_.DatapointName
                    AlertTimestamp = $_.AlertTimestamp
                    AlertType = $_.AlertType
                    Severity = $_.Severity
                    AlertValue = $_.AlertValue
                    LogCount = $_.AssociatedLogs.Count
                    TotalSentimentScore = $_.TotalSentimentScore
                    AverageSentimentScore = [math]::Round($_.TotalSentimentScore / $_.AssociatedLogs.Count, 2)
                    AssociatedLogs = $_.AssociatedLogs | Sort-Object SentimentScore
                }
            } | Sort-Object -Property @{Expression = "LogCount"; Descending = $true}, 
                                    @{Expression = "TotalSentimentScore"; Descending = $true},
                                    @{Expression = "Severity"; Descending = $true}

            Write-Information "Analysis complete. Found $($sortedResults.Count) alerts with associated anomalies."
            return $sortedResults
        }
        catch {
            Write-Error "An error occurred: $_"
            return
        }
    }
    Else {
        Write-Error "Please ensure you are logged in before running any commands, use Connect-LMAccount to login and try again."
    }
}
