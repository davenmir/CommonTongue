local _, ns = ...
local Compat = ns.Compat

-- Fires as (restrictionType, state); chat lockdown observed as type 5 (ARCHITECTURE §1.1).
Compat.restrictionEvent = "ADDON_RESTRICTION_STATE_CHANGED"
