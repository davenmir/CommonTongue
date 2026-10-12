local _, ns = ...

-- Agent-drafted. reviewed = false until a native speaker signs off.
-- esMX uses these patterns too (ADR-0005).
ns.Data.RegisterLanguage("esES", {
    reviewed = false,
    phrases = {
        THANKS = { match = { "gracias", "grax" }, render = "Gracias" },
        PLEASE = { match = { "por favor", "pf" }, render = "Por favor" },
        HELLO = { match = { "hola" }, render = "Hola" },
        BYE = { match = { "adiós", "adios", "chao" }, render = "Adiós" },
        INVITE = { match = { "invita", "inviten", "inv" }, render = "Inviten por favor" },
        PULL = { match = { "pull", "entro" }, render = "Pull" },
        READY = { match = { "listo", "lista", "ready" }, render = "Listo" },
        INCOMING = { match = { "incoming", "vienen" }, render = "Incoming" },
        WIPE = { match = { "wipe" }, render = "Wipe" },
        REZ = { match = { "reza", "rez" }, render = "Rez" },
        INTERRUPT = { match = { "interrupt", "kickeá", "kick" }, render = "Interrumpir" },
        STACK = { match = { "stack", "juntos" }, render = "Stack" },
        SPREAD = { match = { "spread", "separados" }, render = "Separados" },
        GOOD_LUCK = { match = { "suerte", "gl" }, render = "Suerte" },
        PULL_IN = {
            match = { "pull in {seconds}", "entro en {seconds}" },
            render = "Pull en {seconds}",
        },
        LFM_ROLES = {
            match = {
                "lfm {roles} para {activity}",
                "busco {roles} para {activity}",
                "lfm {roles} {activity}",
                "busco {roles} {activity}",
            },
            render = "Busco {roles} para {activity}",
        },
        LFG_ACTIVITY = {
            match = { "lfg {activity}", "busco grupo {activity}" },
            render = "Busco grupo {activity}",
        },
        WTS_ITEM_PRICE = {
            match = { "wts {item} {price}", "vendo {item} {price}" },
            render = "Vendo {item} {price}",
        },
        WTB_ITEM = { match = { "wtb {item}", "compro {item}" }, render = "Compro {item}" },
    },
})

ns.Data.RegisterLanguage("esMX", ns.Data.GetLanguage("esES"))
