local _, ns = ...

-- Agent-drafted. reviewed = false until a native speaker signs off.
ns.Data.RegisterLanguage("deDE", {
    reviewed = false,
    phrases = {
        THANKS = { match = { "danke", "dankeschön", "dankesehr" }, render = "Danke" },
        PLEASE = { match = { "bitte" }, render = "Bitte" },
        HELLO = { match = { "hallo", "hi", "moin" }, render = "Hallo" },
        BYE = { match = { "tschüss", "tschau", "ciao" }, render = "Tschüss" },
        INVITE = { match = { "invite", "einladen", "inv" }, render = "Bitte einladen" },
        PULL = { match = { "pull", "ziehe" }, render = "Pull" },
        READY = { match = { "bereit", "ready", "rdy" }, render = "Bereit" },
        INCOMING = { match = { "incoming", "kommt" }, render = "Incoming" },
        WIPE = { match = { "wipe", "wipen" }, render = "Wipe" },
        REZ = { match = { "rez", "wiederbeleben" }, render = "Rez" },
        INTERRUPT = { match = { "unterbrechen", "kick", "interrupt" }, render = "Unterbrechen" },
        STACK = { match = { "stack", "zusammen" }, render = "Stack" },
        SPREAD = { match = { "spread", "verteilen" }, render = "Verteilen" },
        GOOD_LUCK = { match = { "viel glück", "gl" }, render = "Viel Glück" },
        PULL_IN = {
            match = { "pull in {seconds}", "ziehe in {seconds}" },
            render = "Pull in {seconds}",
        },
        LFM_ROLES = {
            match = {
                "suche {roles} für {activity}",
                "suche {roles} {activity}",
                "lfm {roles} {activity}",
                "lfm {roles} für {activity}",
            },
            render = "Suche {roles} für {activity}",
        },
        LFG_ACTIVITY = {
            match = { "lfg {activity}", "suche gruppe {activity}" },
            render = "Suche Gruppe {activity}",
        },
        WTS_ITEM_PRICE = {
            match = { "wts {item} {price}", "verkaufe {item} {price}" },
            render = "Verkaufe {item} {price}",
        },
        WTB_ITEM = { match = { "wtb {item}", "suche {item}" }, render = "Suche {item}" },
    },
})
