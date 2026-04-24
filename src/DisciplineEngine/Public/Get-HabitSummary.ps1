function Get-HabitSummary {
    <#
    .SYNOPSIS
    Compute weekly habit compliance against target thresholds.

    .DESCRIPTION
    For the Monday-to-Sunday week containing -WeekOf, counts completed
    entries per habit and compares them against the project targets
    defined in CLAUDE.md:

        Exercise:    5 sessions / week
        Sleep:       7 days (before 22:30 each night)
        Development: 7 days (1 hour / day)

    Returns a single summary object with the counts, the week boundaries,
    and an overall status label.

    .PARAMETER WeekOf
    Any date inside the target week. Defaults to today. The function
    normalizes to Monday (start) through Sunday (end).

    .PARAMETER Path
    Path to the JSON store. Same default as Add-HabitEntry.

    .EXAMPLE
    Get-HabitSummary

    .EXAMPLE
    Get-HabitSummary -WeekOf 2026-04-20
    #>
    [CmdletBinding()]
    param(
        [datetime]$WeekOf = (Get-Date).Date,

        [string]$Path = $(if ($env:DISCIPLINE_ENGINE_STORE) {
            $env:DISCIPLINE_ENGINE_STORE
        } else {
            './data/habits.json'
        })
    )

    # -- Compute the Monday of the target week ------------------------------
    # [int][DayOfWeek] uses .NET's enum: Sunday=0, Monday=1, ..., Saturday=6.
    # For a Monday-start week: Sunday needs to step back 6 days; every other
    # day steps back (DayOfWeek - 1) days.
    $dow = [int]$WeekOf.DayOfWeek
    $daysSinceMonday = if ($dow -eq 0) { 6 } else { $dow - 1 }
    $weekStart = $WeekOf.Date.AddDays(-$daysSinceMonday)
    $weekEnd   = $weekStart.AddDays(6)   # Sunday

    # -- Load and filter entries --------------------------------------------
    $entries = Get-HabitStore -Path $Path

    # Where-Object { ... } filters a pipeline; inside the block, $_ is the
    # current item. We parse the stored Date string back to [datetime] with
    # an explicit format so there's no ambiguity.
    $inWeek = $entries | Where-Object {
        $d = [datetime]::ParseExact($_.Date, 'yyyy-MM-dd', $null)
        ($d -ge $weekStart) -and ($d -le $weekEnd) -and $_.Completed
    }

    # Dedupe (Date, Habit) pairs so logging the same habit twice on one day
    # counts only once. Group-Object buckets items by a key expression; we
    # then take the first item from each bucket.
    $deduped = $inWeek |
        Group-Object -Property { "$($_.Date)|$($_.Habit)" } |
        ForEach-Object { $_.Group[0] }

    # -- Count per habit ----------------------------------------------------
    # Seed the counts so habits with zero completions still appear.
    $byHabit = @{
        exercise    = 0
        sleep       = 0
        development = 0
    }
    foreach ($g in ($deduped | Group-Object -Property Habit)) {
        $byHabit[$g.Name] = $g.Count
    }

    # -- Compare to targets -------------------------------------------------
    $targets = @{
        exercise    = 5   # 5 sessions/week
        sleep       = 7   # every night before 22:30
        development = 7   # 1 hour every day
    }

    # Ratios per habit: 0.0 = nothing done, 1.0 = met target, >1.0 = over.
    # Cast to [double] to force floating-point division (integer division
    # would drop the fractional part).
    $ratios = @{
        exercise    = [double]$byHabit.exercise    / $targets.exercise
        sleep       = [double]$byHabit.sleep       / $targets.sleep
        development = [double]$byHabit.development / $targets.development
    }

    # Overall status logic (tune later as needed):
    #   on-track : every habit met its target
    #   critical : the worst habit is below 50%
    #   slipping : anything in between
    # Measure-Object -Minimum finds the smallest value in a collection.
    # We use its .Minimum property instead of piping to Where-Object because
    # a Where-Object that emits the number 0 is a falsy pipeline in an if —
    # a classic PowerShell footgun.
    $minRatio = ($ratios.Values | Measure-Object -Minimum).Minimum

    $status =
        if ($minRatio -lt 0.5) { 'critical' }
        elseif ($minRatio -lt 1.0) { 'slipping' }
        else { 'on-track' }

    # Return one summary object. Format the counts as "x/target" per the spec.
    return [pscustomobject]@{
        WeekStart     = $weekStart.ToString('yyyy-MM-dd')
        WeekEnd       = $weekEnd.ToString('yyyy-MM-dd')
        Exercise      = "$($byHabit.exercise)/$($targets.exercise)"
        Sleep         = "$($byHabit.sleep)/$($targets.sleep)"
        Development   = "$($byHabit.development)/$($targets.development)"
        OverallStatus = $status
    }
}
