local _, ns = ...

ns.Data.RegisterPhrases({
    THANKS = {},
    PLEASE = {},
    HELLO = {},
    BYE = {},
    INVITE = {},
    PULL = {},
    READY = {},
    INCOMING = {},
    WIPE = {},
    REZ = {},
    INTERRUPT = {},
    STACK = {},
    SPREAD = {},
    GOOD_LUCK = {},
    PULL_IN = { params = { seconds = "number" } },
    LFM_ROLES = { params = { roles = "roleList", activity = "activity" } },
    LFG_ACTIVITY = { params = { activity = "activity" } },
    WTS_ITEM_PRICE = { params = { item = "link", price = "gold" } },
    WTB_ITEM = { params = { item = "link" } },
})
