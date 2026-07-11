# Rank badge artwork

15 badges (512px, resized from the 2000px masters in the designer's `ranks/`
export, where `1.png` = Bronze III … `15.png` = Crimson I), named
`<tier>_<level>.png`. Level 3 = III (entry), level 1 = I (top of tier).

Internal tier names stay `bronze silver gold platinum elite`; the user-facing
labels are the hype names in the ARBs (`rankBronze` = Grinder, Warrior, Beast,
Titan, Apex). `RankBadge` (`lib/features/leaderboard/rank.dart`) loads these
automatically and falls back to a styled medal if a file is missing.
