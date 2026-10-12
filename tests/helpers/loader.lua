-- Loads addon files in TOC order with a shared namespace, emulating `local _, ns = ...`.

local stubs = require("tests.stubs.wow")

local M = {}

M.ADDON_NAME = "CommonTongue"
M.ADDON_DIR = "CommonTongue/"
M.TOC = M.ADDON_DIR .. "CommonTongue_Mainline.toc"

-- UI / comm libraries need a real client; tests replace them with fakes.
local FAKED_LIBS = {
    ["Libs/Ace3/AceComm-3.0/AceComm-3.0.xml"] = true,
    ["Libs/Ace3/AceGUI-3.0/AceGUI-3.0.xml"] = true,
    ["Libs/Ace3/AceConfig-3.0/AceConfig-3.0.xml"] = true,
}

local function normalize(path)
    return (path:gsub("\\", "/"))
end

local function dirname(path)
    return path:match("^(.*/)") or ""
end

local function readFile(path)
    local f = assert(io.open(path, "rb"), "cannot open " .. path)
    local content = f:read("*a")
    f:close()
    return content
end

--- File paths (relative to the addon folder) listed by the TOC, in order.
function M.tocFiles(tocPath)
    local files = {}
    for line in readFile(tocPath or M.TOC):gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" and not line:match("^#") then
            files[#files + 1] = normalize(line)
        end
    end
    return files
end

local function expandXml(path, out)
    local base = dirname(path)
    local xml = readFile(M.ADDON_DIR .. path)
    for tag, file in xml:gmatch('<(%a+)%s+file="([^"]+)"') do
        local child = base .. normalize(file)
        if tag == "Include" then
            expandXml(child, out)
        elseif tag == "Script" then
            out[#out + 1] = child
        end
    end
end

local function runFile(path, ns)
    local chunk = assert(loadfile(M.ADDON_DIR .. path))
    chunk(M.ADDON_NAME, ns)
end

--- Installs fresh stubs and loads the given addon files (default: whole TOC).
---@param opts table|nil stub options plus `files` to load a subset
---@return table ns, table state
function M.load(opts)
    opts = opts or {}
    local state = stubs.install(opts)
    local ns = {}
    local fakesInstalled = false

    for _, file in ipairs(opts.files or M.tocFiles()) do
        if FAKED_LIBS[file] then
            if file:find("AceComm", 1, true) then
                stubs.installAceCommFake(state)
            elseif not fakesInstalled then
                stubs.installAceConfigFakes(state)
                fakesInstalled = true
            end
        elseif file:match("%.xml$") then
            local scripts = {}
            expandXml(file, scripts)
            for _, script in ipairs(scripts) do
                runFile(script, ns)
            end
        else
            runFile(file, ns)
        end
    end
    return ns, state
end

--- Loads the whole addon and runs the login sequence.
function M.login(opts)
    local ns, state = M.load(opts)
    state.fire("ADDON_LOADED", M.ADDON_NAME)
    state.loggedIn = true
    state.fire("PLAYER_LOGIN")
    return ns, state
end

M.stubs = stubs

return M
