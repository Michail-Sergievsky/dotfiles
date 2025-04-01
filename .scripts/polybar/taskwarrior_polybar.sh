#!/usr/bin/env bash
#
# taskwarrior_polybar.sh
# Shows a small summary of Taskwarrior tasks in your Polybar.

# 1) Current context (if any)
# CONTEXT="$(task _get rc.context 2>/dev/null)"
# if [ -z "$CONTEXT" ] || [ "$CONTEXT" = "none" ]; then
#   CONTEXT="noctx"
# fi

# 2) Number of tasks in "in" or "next" or whichever filter you want
#    For example, let's show how many tasks have +IN
#    (Replace with your own filter logic as desired)
IN_COUNT="$(task +IN status:pending count 2>/dev/null)"

# 3) Number of "stuck" tasks or "stuck" projects
#    This is arbitrary. For example, let's say "stuck" means tasks that are
#    waiting or blocked. We'll just count waiting tasks as an example:
STUCK_COUNT="$(task status:waiting count 2>/dev/null)"

# 4) Number of tasks due this week
#    We'll define "this week" as due.before:eow (end of week).
#    If you prefer a different logic, adjust accordingly.
DUE_WEEK_COUNT="$(task status:pending due.before:eow count 2>/dev/null)"

# Print them in the format:  context in_count stuck_count due_week_count
# For example: "sp 4 30 2"
# echo "$CONTEXT $IN_COUNT $STUCK_COUNT $DUE_WEEK_COUNT"
#with colores
# echo "$CONTEXT %{F#FFFF00}$IN_COUNT%{F-} %{F#FF00FF}$STUCK_COUNT%{F-} %{F#FF0000}$DUE_WEEK_COUNT%{F-}"
#with emojies
echo "🗹 $IN_COUNT ⏳ $STUCK_COUNT 🚨 $DUE_WEEK_COUNT"
