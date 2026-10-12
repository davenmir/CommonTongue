local _, ns = ...

ns.Data.RegisterLanguage("enUS", {
    reviewed = true,
    phrases = {
        THANKS = { match = { "thanks", "thank you", "ty", "thx" }, render = "thanks" },
        PLEASE = { match = { "please", "pls", "plz" }, render = "please" },
        HELLO = { match = { "hello", "hi", "hey" }, render = "hello" },
        BYE = { match = { "bye", "goodbye", "cya", "see you" }, render = "bye" },
        INVITE = {
            match = { "invite", "inv", "invite please", "inv pls" },
            render = "invite please",
        },
        PULL = { match = { "pull", "pulling" }, render = "pull" },
        READY = { match = { "ready", "rdy" }, render = "ready" },
        INCOMING = { match = { "incoming", "inc" }, render = "incoming" },
        WIPE = { match = { "wipe", "wiping" }, render = "wipe" },
        REZ = { match = { "rez", "res", "ress", "revive" }, render = "rez" },
        INTERRUPT = { match = { "interrupt", "kick", "cc" }, render = "interrupt" },
        STACK = { match = { "stack", "stack up" }, render = "stack" },
        SPREAD = { match = { "spread", "spread out" }, render = "spread" },
        GOOD_LUCK = { match = { "gl", "glhf", "good luck" }, render = "good luck" },
        PULL_IN = {
            match = { "pull in {seconds}", "pulling in {seconds}" },
            render = "pull in {seconds}",
        },
        LFM_ROLES = {
            match = {
                "lfm {roles} {activity}",
                "lfm {roles} for {activity}",
                "need {roles} for {activity}",
                "looking for {roles} for {activity}",
                "looking for {roles} {activity}",
            },
            render = "LFM {roles} for {activity}",
        },
        LFG_ACTIVITY = {
            match = { "lfg {activity}", "looking for group {activity}" },
            render = "LFG {activity}",
        },
        WTS_ITEM_PRICE = {
            match = { "wts {item} {price}", "wts {item} for {price}" },
            render = "WTS {item} {price}",
        },
        WTB_ITEM = { match = { "wtb {item}" }, render = "WTB {item}" },
    },
})
