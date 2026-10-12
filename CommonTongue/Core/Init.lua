local ADDON_NAME, ns = ...

local ipairs, setmetatable, type = ipairs, setmetatable, type

ns.name = ADDON_NAME
ns.modules = {}
ns.moduleOrder = {}

-- Missing locale keys fall back to the key itself, which is the enUS text.
ns.L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})

---@param name string
---@return table module
function ns:NewModule(name)
    if self[name] ~= nil then
        error(("CommonTongue: module or field %q already exists"):format(name), 2)
    end
    local module = { name = name }
    self.modules[name] = module
    self.moduleOrder[#self.moduleOrder + 1] = module
    self[name] = module
    return module
end

local function callAll(method)
    for _, module in ipairs(ns.moduleOrder) do
        local fn = module[method]
        if type(fn) == "function" then
            ns.Compat.SafeCall(fn, module)
        end
    end
end

--- Runs every module's OnInitialize once, in load order. SavedVariables are ready.
function ns:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true
    callAll("OnInitialize")
end

--- Runs every module's OnEnable once, in load order, after the player is in the world.
function ns:Enable()
    if self.enabled then
        return
    end
    self.enabled = true
    callAll("OnEnable")
end

---@param message string
function ns:Print(message)
    print("|cff33ff99CommonTongue|r: " .. message)
end
