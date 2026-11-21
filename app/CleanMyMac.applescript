-- CleanMyMac v2: one-click Quick Clean, or scan and pick items in Advanced.

on scriptCmd()
	return "/bin/bash " & quoted form of ((POSIX path of (path to home folder)) & "Library/Application Support/CleanMyMac/cleanmymac.sh")
end scriptCmd

on run
	set choice to button returned of (display dialog "Quick Clean — caches, logs and app caches. Safe, one click." & return & return & "Advanced — scan your Mac and choose exactly what to clean." with title "CleanMyMac" buttons {"Cancel", "Advanced…", "Quick Clean"} default button "Quick Clean" cancel button "Cancel" with icon note)
	if choice is "Quick Clean" then
		showResult(runScript(" --quick"))
	else
		advancedClean()
	end if
end run

on runScript(args)
	try
		return do shell script scriptCmd() & args
	on error errMsg
		return "Something went wrong:" & return & errMsg
	end try
end runScript

on advancedClean()
	display notification "Scanning your Mac… (about 15 seconds)" with title "CleanMyMac"
	set scanText to runScript(" --scan")
	set ids to {}
	set labels to {}
	set kbs to {}
	set defaults to {}
	set oldTID to AppleScript's text item delimiters
	set AppleScript's text item delimiters to tab
	repeat with ln in paragraphs of scanText
		set parts to text items of (contents of ln)
		if (count of parts) ≥ 5 then
			set lbl to (item 2 of parts) & "   —   " & (item 4 of parts)
			set end of ids to item 1 of parts
			set end of labels to lbl
			set end of kbs to (item 3 of parts) as number
			if item 5 of parts is "quick" then set end of defaults to lbl
		end if
	end repeat
	set AppleScript's text item delimiters to oldTID

	if (count of ids) is 0 then
		display dialog "Nothing to clean — your Mac is already tidy." with title "CleanMyMac" buttons {"OK"} default button "OK"
		return
	end if

	set picked to choose from list labels with title "CleanMyMac — Advanced" with prompt "Choose what to clean. Quick items are pre-selected; ⌘-click to add or remove." default items defaults OK button name "Continue" cancel button name "Cancel" with multiple selections allowed
	if picked is false then return

	set sel to {}
	set totalKB to 0
	set wantsSystem to false
	repeat with p in picked
		set p to contents of p
		repeat with i from 1 to count of labels
			if item i of labels is p then
				if item i of ids is "system" then
					set wantsSystem to true
				else
					set end of sel to item i of ids
				end if
				set totalKB to totalKB + (item i of kbs)
			end if
		end repeat
	end repeat

	set msg to "Clean " & (count of picked) & " item(s)?"
	if totalKB > 0 then set msg to msg & return & return & "About " & humanSize(totalKB) & " will be freed."
	display dialog msg with title "CleanMyMac" buttons {"Cancel", "Clean"} default button "Clean" cancel button "Cancel" with icon caution

	set out to ""
	if (count of sel) > 0 then
		set AppleScript's text item delimiters to ","
		set idList to sel as text
		set AppleScript's text item delimiters to oldTID
		set out to runScript(" --items " & quoted form of idList)
	end if
	if wantsSystem then
		try
			do shell script "purge; atsutil databases -remove >/dev/null 2>&1; dscacheutil -flushcache; killall -HUP mDNSResponder; tmutil deletelocalsnapshots / >/dev/null 2>&1; true" with administrator privileges
			set out to out & return & "✔ RAM freed, font & DNS caches reset"
		on error
			set out to out & return & "– System tune-up skipped (no password)"
		end try
	end if
	showResult(out)
end advancedClean

on humanSize(kb)
	if kb ≥ 1048576 then return (((round (kb / 104857.6)) / 10) as text) & " GB"
	if kb ≥ 1024 then return ((round (kb / 1024)) as text) & " MB"
	return "less than 1 MB"
end humanSize

on showResult(out)
	set btn to button returned of (display dialog out with title "CleanMyMac" buttons {"Open Log", "Done"} default button "Done" with icon note)
	if btn is "Open Log" then do shell script "open -a Console " & quoted form of ((POSIX path of (path to home folder)) & "Library/Logs/CleanMyMac.log")
end showResult
