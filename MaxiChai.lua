--[[
    MaxiPlugin - Comprehensive BeamMP Server Plugin
    Combines functionality from:
    - DDoS Protection
    - Car Management System
    - Player Management
    - Admin Commands
    - Custom Chat Commands
]]
local function trim(s)
    return s:match("^%s*(.-)%s*$")
end
local M = {}
    M.data = "Fieldforce changeCameraSpeed movefast debugmode_toggle debugmode_reset reload_all_vehicles reload_vehicle vehicledebugMenu toggle_help reset_physics toggleConsoleNG toggle_performance_graph lua_reload cefdev_console_toggle cefdev_reload_ui flexmeshDebugSelectionToggle debugmode_meshvis_incr debugmode_meshvis_decr physicsControls photomode missionPopup funExtinguish pause cycleTimeOfDay toggleAITraffic VehicleCommonActionMap VehicleSpecificActionMap vehicleEditor vehicleEditorToggle editorToggle parts_selector objectEditorToggle editorSafeModeToggle toggleCamera dropCameraAtPlayer slower_motion faster_motion toggle_slow_motion nodegrabberAction nodegrabberStrength dropPlayerAtCamera dropPlayerAtCameraNoReset recover_vehicle recover_vehicle_alt recover_to_last_road reload_vehicle reload_all_vehicles loadHome saveHome reset_physics reset_all_physics toggleRadialMenuSandbox toggleRadialMenuPlayerVehicle toggleRadialMenuFavorites toggleRadialMenuMulti menu_item_focus_lr menu_item_focus_ud"
local PLUGIN_NAME = "MaxiPlugin"
local PLUGIN_VERSION = "1.0.0"
local PLUGIN_AUTHOR = "Pacetten007"


local function script_path()
    return debug.getinfo(2, "S").source:match("(.*[/\\])") or "./"
end

local function file_exists(name)
    local f = io.open(name, "r")
    return f ~= nil and io.close(f)
end


local CONFIG_PATH = script_path() .. "MaxiConfig.toml"
local LOGS_PATH = script_path() .. "logs/"
local DATA_PATH = script_path() .. "data/"
local CARS_PATH = DATA_PATH .. "cars.json"
local PLAYERS_PATH = DATA_PATH .. "players.json"
local PLAYERS_DIR = DATA_PATH .. "players/"


local function ensureDirectoriesExist()
    if not FS.Exists(DATA_PATH) then
        FS.CreateDirectory(DATA_PATH)
    end
    if not FS.Exists(LOGS_PATH) then
        FS.CreateDirectory(LOGS_PATH)
    end
    if not FS.Exists(PLAYERS_DIR) then
        FS.CreateDirectory(PLAYERS_DIR)
    end
end


local CONFIG = {
    DDOS_MAX_CONNECTIONS = "5",
    DDOS_TIME_WINDOW = "10",
    DDOS_BAN_DURATION = "3600",
    DDOS_DEBUG = "true",
    

    ADMINS = "Pacetten007,Chepard22,haitu55,Sanya_Dolg,Dewerto,Fellisia,Deadk1ng",
    
    WHITELIST = "true",
    PREFIX = ";",
    NOGUEST = "true",
    NOGUESTMSG = "Guest are forbidden, please create a beammp account :)",
    WELCOMESTAFF = "Welcome Staff",
    WELCOMEPLAYER = "Welcome",
    KEEPINGLOGSDAYS = "3",
    CHATHANDLER = "true",
    CAR_RESTRICTIONS = "true"
}


local function loadConfig()
    if not file_exists(CONFIG_PATH) then
        local file = io.open(CONFIG_PATH, "w")
        if file then
            for key, value in pairs(CONFIG) do
                file:write(key .. " = \"" .. value .. "\"\n")
            end
            file:close()
            print("[" .. PLUGIN_NAME .. "] Created default configuration file")
        else
            print("[" .. PLUGIN_NAME .. "] ERROR: Failed to create configuration file")
        end
    else
        local file = io.open(CONFIG_PATH, "r")
        if file then
            local content = file:read("*all")
            file:close()
            
            for key, _ in pairs(CONFIG) do
                local value = content:match(key .. "%s*=%s*\"(.-)\"%s*\n")
                if value then
                    CONFIG[key] = value
                end
            end
        end
    end
    
    return CONFIG
end


local function getConfigValue(key)
    return CONFIG[key]
end


local function log(message)
    local date = os.date("%Y-%m-%d")
    local dateTime = os.date("%Y-%m-%d %H:%M:%S")
    
    local logFile = io.open(LOGS_PATH .. date .. ".log", "a+")
    if logFile then
        logFile:write(dateTime .. " [" .. PLUGIN_NAME .. "] " .. message .. "\n")
        logFile:close()
    end
    
    print("[" .. PLUGIN_NAME .. "] " .. message)
end


local function print_color(message, color)
    local colors = {
        black = "\27[30m",
        red = "\27[31m",
        green = "\27[32m",
        yellow = "\27[33m",
        blue = "\27[34m",
        magenta = "\27[35m",
        cyan = "\27[36m",
        white = "\27[37m",
        gray = "\27[90m",
    }
    
    if not colors[color] then
        color = "white"
    end
    
    return colors[color] .. message .. "\27[0m"
end


local function printError(message)
    print(print_color("[" .. PLUGIN_NAME .. "] ERROR: ", "red") .. message)
    log("ERROR: " .. message)
end


local function printWarning(message)
    print(print_color("[" .. PLUGIN_NAME .. "] WARNING: ", "yellow") .. message)
    log("WARNING: " .. message)
end


local function printSuccess(message)
    print(print_color("[" .. PLUGIN_NAME .. "] ", "green") .. message)
    log(message)
end


local function jsonEncode(data)
    return Util.JsonEncode(data)
end

local function jsonDecode(jsonStr)
    local success, result = pcall(Util.JsonDecode, jsonStr)
    if success then
        return result
    else
        printError("Failed to decode JSON: " .. tostring(result))
        return nil
    end
end

------------------------------------------
-- Player Data Management
------------------------------------------
local PlayerData = {
    cache = {}
}

-- Get player data file path
function PlayerData.getPlayerFilePath(playerName)

    local safeName = playerName:gsub("[%p%c]", "_")
    return PLAYERS_DIR .. safeName .. ".json"
end

function PlayerData.createNewPlayerData(playerName, playerIP)
    return {
        name = playerName,
        firstJoin = os.time(),
        lastSeen = os.time(),
        ip = playerIP,
        banned = false,
        banReason = "",
        banExpiry = 0,
        banIP = false,
        whitelisted = false, 
        cars = {}
    }
end

-- Add whitelist management functions
function PlayerData.addToWhitelist(playerName)
    local playerData = PlayerData.loadPlayerData(playerName)
    
    if not playerData then
        -- Create new player data if it doesn't exist
        playerData = PlayerData.createNewPlayerData(playerName, "unknown")
        log("Creating new player data for whitelist: " .. playerName)
    end
    
    playerData.whitelisted = true
    
    -- Ensure the directory exists before saving
    if not FS.Exists(PLAYERS_DIR) then
        FS.CreateDirectory(PLAYERS_DIR)
    end
    
    local success = PlayerData.savePlayerData(playerName, playerData)
    if success then
        log("Successfully added player to whitelist: " .. playerName)
    else
        log("Failed to add player to whitelist: " .. playerName)
    end
    
    return success, success and "Player added to whitelist" or "Failed to add player to whitelist"
end

function PlayerData.removeFromWhitelist(playerName)
    local playerData = PlayerData.loadPlayerData(playerName)
    
    if not playerData then
        return false, "Player not found"
    end
    
    playerData.whitelisted = false
    return PlayerData.savePlayerData(playerName, playerData), "Player removed from whitelist"
end

function PlayerData.isWhitelisted(playerName)
    local playerData = PlayerData.loadPlayerData(playerName)
    return playerData and playerData.whitelisted or false
end

-- Load player data
function PlayerData.loadPlayerData(playerName)
    -- Check cache first
    if PlayerData.cache[playerName] then
        return PlayerData.cache[playerName]
    end
    
    local filePath = PlayerData.getPlayerFilePath(playerName)
    
    -- If file doesn't exist, return nil
    if not file_exists(filePath) then
        return nil
    end
    
    local file = io.open(filePath, "r")
    if not file then
        printError("Failed to open player data file: " .. filePath)
        return nil
    end
    
    local content = file:read("*all")
    file:close()
    
    if content == "" then
        return nil
    end
    
    local playerData = jsonDecode(content)
    if not playerData then
        printError("Error parsing player data for " .. playerName)
        return nil
    end
    
    -- Update cache
    PlayerData.cache[playerName] = playerData
    return playerData
end

-- Save player data
-- Save player data
function PlayerData.savePlayerData(playerName, playerData)
    local filePath = PlayerData.getPlayerFilePath(playerName)
    
    -- Ensure the directory exists
    if not FS.Exists(PLAYERS_DIR) then
        local success = FS.CreateDirectory(PLAYERS_DIR)
        if not success then
            printError("Failed to create directory: " .. PLAYERS_DIR)
            return false
        end
    end
    
    -- Update cache
    PlayerData.cache[playerName] = playerData
    
    local file = io.open(filePath, "w")
    if not file then
        printError("Failed to open player data file for writing: " .. filePath)
        return false
    end
    
    local jsonData = jsonEncode(playerData)
    if not jsonData then
        printError("Failed to encode player data to JSON for " .. playerName)
        file:close()
        return false
    end
    
    file:write(jsonData)
    file:close()
    log("Saved player data for: " .. playerName)
    return true
end

-- Check if player is banned
function PlayerData.isPlayerBanned(playerName)
    local playerData = PlayerData.loadPlayerData(playerName)
    if not playerData then
        return false
    end
    
    if playerData.banned then
        -- Check if ban has expired
        if playerData.banExpiry > 0 and playerData.banExpiry < os.time() then
            -- Ban expired, update player data
            playerData.banned = false
            playerData.banExpiry = 0
            PlayerData.savePlayerData(playerName, playerData)
            return false
        end
        return true, playerData.banReason, playerData.banExpiry
    end
    
    return false
end

-- Ban player
function PlayerData.banPlayer(playerName, reason, duration)
    local playerData = PlayerData.loadPlayerData(playerName)
    if not playerData then
        return false, "Player not found"
    end
    
    playerData.banned = true
    playerData.banReason = reason or "No reason provided"
    
    if duration and duration > 0 then
        playerData.banExpiry = os.time() + duration
    else
        playerData.banExpiry = 0 -- Permanent ban
    end
    
    return PlayerData.savePlayerData(playerName, playerData), "Player banned successfully"
end

-- Unban player
function PlayerData.unbanPlayer(playerName)
    local playerData = PlayerData.loadPlayerData(playerName)
    if not playerData then
        return false, "Player not found"
    end
    
    if not playerData.banned then
        return false, "Player is not banned"
    end
    
    playerData.banned = false
    playerData.banReason = ""
    playerData.banExpiry = 0
    
    return PlayerData.savePlayerData(playerName, playerData), "Player unbanned successfully"
end

-- Get all player names
function PlayerData.getAllPlayerNames()
    local players = {}
    local files = FS.ListFiles(PLAYERS_DIR)
    
    for _, file in ipairs(files) do
        local playerName = file:match("(.+)%.json$")
        if playerName then
            table.insert(players, playerName)
        end
    end
    
    return players
end

-- Get banned players
function PlayerData.getBannedPlayers()
    local bannedPlayers = {}
    local players = PlayerData.getAllPlayerNames()
    
    for _, playerName in ipairs(players) do
        local isBanned, reason, expiry = PlayerData.isPlayerBanned(playerName)
        if isBanned then
            table.insert(bannedPlayers, {
                name = playerName,
                reason = reason,
                expiry = expiry
            })
        end
    end
    
    return bannedPlayers
end

------------------------------------------
-- DDoS Protection Module
------------------------------------------
local DDoSProtection = {
    -- Configuration
    config = {
        maxConnections = 5,
        timeWindow = 10,
        banDuration = 3600,
        debug = false
    },
    
    -- Store connection attempts: {ip = {timestamps = {}, banned = false, banExpiry = 0}}
    connectionAttempts = {}
}

-- Clean up old connection records
function DDoSProtection.cleanupOldRecords()
    local currentTime = os.time()
    local timeThreshold = currentTime - DDoSProtection.config.timeWindow
    
    for ip, data in pairs(DDoSProtection.connectionAttempts) do
        -- Remove timestamps older than the time window
        local i = 1
        while i <= #data.timestamps do
            if data.timestamps[i] < timeThreshold then
                table.remove(data.timestamps, i)
            else
                i = i + 1
            end
        end
        
        -- Check if ban has expired
        if data.banned and data.banExpiry < currentTime then
            data.banned = false
            data.banExpiry = 0
            if DDoSProtection.config.debug then
                log("DDoS Protection: Ban expired for IP: " .. ip)
            end
        end
        
        -- Remove IP from tracking if no recent connections and not banned
        if #data.timestamps == 0 and not data.banned then
            DDoSProtection.connectionAttempts[ip] = nil
        end
    end
end

-- Check if an IP is banned
function DDoSProtection.isIpBanned(ip)
    if not DDoSProtection.connectionAttempts[ip] then
        return false
    end
    
    -- Check if ban has expired
    if DDoSProtection.connectionAttempts[ip].banned then
        local currentTime = os.time()
        if DDoSProtection.connectionAttempts[ip].banExpiry < currentTime then
            DDoSProtection.connectionAttempts[ip].banned = false
            DDoSProtection.connectionAttempts[ip].banExpiry = 0
            return false
        end
        return true
    end
    
    return false
end

-- Record a connection attempt and check if it should be banned
function DDoSProtection.recordConnectionAttempt(ip, playerName)
    local currentTime = os.time()
    
    -- Initialize record for this IP if it doesn't exist
    if not DDoSProtection.connectionAttempts[ip] then
        DDoSProtection.connectionAttempts[ip] = {
            timestamps = {},
            banned = false,
            banExpiry = 0,
            playerName = playerName
        }
    end
    
    -- Update player name if provided
    if playerName and playerName ~= "" then
        DDoSProtection.connectionAttempts[ip].playerName = playerName
    end
    
    -- If already banned, just return true
    if DDoSProtection.connectionAttempts[ip].banned then
        return true
    end
    
    -- Add current timestamp
    table.insert(DDoSProtection.connectionAttempts[ip].timestamps, currentTime)
    
    -- Check if connection limit exceeded
    local timeThreshold = currentTime - DDoSProtection.config.timeWindow
    local recentConnections = 0
    
    for _, timestamp in ipairs(DDoSProtection.connectionAttempts[ip].timestamps) do
        if timestamp >= timeThreshold then
            recentConnections = recentConnections + 1
        end
    end
    
    -- Ban if too many connections
    if recentConnections > DDoSProtection.config.maxConnections then
        DDoSProtection.connectionAttempts[ip].banned = true
        DDoSProtection.connectionAttempts[ip].banExpiry = currentTime + DDoSProtection.config.banDuration
        
        if DDoSProtection.config.debug then
            log("DDoS Protection: IP banned for connection abuse: " .. ip .. 
                " (" .. (DDoSProtection.connectionAttempts[ip].playerName or "Unknown") .. 
                ") - " .. recentConnections .. " connections in " .. DDoSProtection.config.timeWindow .. " seconds")
        end
        
        return true
    end
    
    return false
end

-- Get a list of currently banned IPs
function DDoSProtection.getBannedIPs()
    local bannedList = {}
    local currentTime = os.time()
    
    for ip, data in pairs(DDoSProtection.connectionAttempts) do
        if data.banned and data.banExpiry > currentTime then
            table.insert(bannedList, {
                ip = ip,
                playerName = data.playerName or "Unknown",
                expiresIn = data.banExpiry - currentTime,
                connections = #data.timestamps
            })
        end
    end
    
    return bannedList
end

-- Manually ban an IP
function DDoSProtection.banIP(ip, duration, reason)
    duration = duration or DDoSProtection.config.banDuration
    local currentTime = os.time()
    
    if not DDoSProtection.connectionAttempts[ip] then
        DDoSProtection.connectionAttempts[ip] = {
            timestamps = {},
            banned = false,
            banExpiry = 0,
            playerName = "Unknown",
            reason = reason or "Manual ban"
        }
    end
    
    DDoSProtection.connectionAttempts[ip].banned = true
    DDoSProtection.connectionAttempts[ip].banExpiry = currentTime + duration
    DDoSProtection.connectionAttempts[ip].reason = reason or "Manual ban"
    
    if DDoSProtection.config.debug then
        log("DDoS Protection: IP manually banned: " .. ip .. 
            " (" .. (DDoSProtection.connectionAttempts[ip].playerName or "Unknown") .. 
            ") for " .. duration .. " seconds. Reason: " .. (reason or "None provided"))
    end
    
    return true
end

-- Unban an IP
function DDoSProtection.unbanIP(ip)
    if not DDoSProtection.connectionAttempts[ip] then
        return false
    end
    
    DDoSProtection.connectionAttempts[ip].banned = false
    DDoSProtection.connectionAttempts[ip].banExpiry = 0
    
    if DDoSProtection.config.debug then
        log("DDoS Protection: IP unbanned: " .. ip .. 
            " (" .. (DDoSProtection.connectionAttempts[ip].playerName or "Unknown") .. ")")
    end
    
    return true
end

-- Initialize DDoS Protection
function DDoSProtection.initialize()
    -- Load configuration from main config
    DDoSProtection.config.maxConnections = tonumber(getConfigValue("DDOS_MAX_CONNECTIONS")) or 5
    DDoSProtection.config.timeWindow = tonumber(getConfigValue("DDOS_TIME_WINDOW")) or 10
    DDoSProtection.config.banDuration = tonumber(getConfigValue("DDOS_BAN_DURATION")) or 3600
    DDoSProtection.config.debug = getConfigValue("DDOS_DEBUG") == "true"
    
    log("DDoS Protection initialized with settings:")
    log("- Max connections: " .. DDoSProtection.config.maxConnections .. " in " .. DDoSProtection.config.timeWindow .. " seconds")
    log("- Ban duration: " .. DDoSProtection.config.banDuration .. " seconds")
    log("- Debug mode: " .. (DDoSProtection.config.debug and "Enabled" or "Disabled"))
    
    -- Start a periodic cleanup task
    local function periodicCleanup()
        DDoSProtection.cleanupOldRecords()
        -- Schedule next cleanup in 30 seconds
        MP.CreateEventTimer("ddosCleanup", 30000)
    end
    
    -- Register the cleanup event
    MP.RegisterEvent("ddosCleanup", "periodicCleanup")
    
    -- Start the first cleanup in 30 seconds
    MP.CreateEventTimer("ddosCleanup", 30000)
    
    return true
end

------------------------------------------
-- Car Management System
------------------------------------------
local CarManagement = {
    cars = {}
}

-- Load cars data from JSON file
function CarManagement.loadCarsData()
    if not file_exists(CARS_PATH) then
        log("Cars data file not found, creating new one")
        CarManagement.cars = {}
        return {}
    end
    
    local file = io.open(CARS_PATH, "r")
    if not file then
        printError("Failed to open cars data file")
        return {}
    end
    
    local content = file:read("*all")
    file:close()
    
    if content == "" then
        return {}
    end
    
    local success, data = pcall(Util.JsonDecode, content)
    if not success or not data then
        printError("Error parsing cars.json, creating new file")
        return {}
    end
    
    CarManagement.cars = data
    return data
end

-- Save cars data to JSON file
function CarManagement.saveCarsData()
    local file = io.open(CARS_PATH, "w")
    if not file then
        printError("Cannot open cars.json for writing")
        return false
    end
    
    local success, content = pcall(Util.JsonEncode, CarManagement.cars)
    if not success or not content then
        printError("Error encoding cars data to JSON")
        file:close()
        return false
    end
    
    file:write(content)
    file:close()
    return true
end

-- Add a car to a player
function CarManagement.addCarToPlayer(playerName, carName)
    -- Load player data
    local playerData = PlayerData.loadPlayerData(playerName)
    if not playerData then
        return false, "Player not found"
    end
    
    -- Check if car already exists
    local carExists = false
    for _, car in ipairs(playerData.cars) do
        if car == carName then
            carExists = true
            break
        end
    end
    
    if not carExists then
        table.insert(playerData.cars, carName)
        log("Added " .. carName .. " to " .. playerName .. "'s car collection")
    else
        log(playerName .. " already has " .. carName)
    end
    
    -- Save player data
    return PlayerData.savePlayerData(playerName, playerData), "Car added successfully"
end

-- Remove a car from a player
function CarManagement.removeCarFromPlayer(playerName, carName)
    -- Load player data
    local playerData = PlayerData.loadPlayerData(playerName)
    if not playerData then
        return false, "Player not found"
    end
    
    -- Find car in player's collection
    local carIndex = nil
    for i, car in ipairs(playerData.cars) do
        if car == carName then
            carIndex = i
            break
        end
    end
    
    if carIndex then
        -- Remove the car
        table.remove(playerData.cars, carIndex)
        log("Removed " .. carName .. " from " .. playerName .. "'s car collection")
        
        -- Save player data
        return PlayerData.savePlayerData(playerName, playerData), "Car removed successfully"
    else
        log(playerName .. " doesn't have " .. carName)
        return false, "Player doesn't have this car"
    end
end

-- Get all cars for a player
function CarManagement.getPlayerCars(playerName)
    local playerData = PlayerData.loadPlayerData(playerName)
    if not playerData then
        return {}
    end
    
    return playerData.cars or {}
end

-- Check if player can spawn a specific car
function CarManagement.canPlayerSpawnCar(playerName, carName)
    local playerCars = CarManagement.getPlayerCars(playerName)
    
    for _, car in ipairs(playerCars) do
        if car == carName then
            return true
        end
    end
    
    return false
end

-- Initialize Car Management System
function CarManagement.initialize()
    log("Car Management System initialized")
    return true
end

------------------------------------------
-- Player Management System
------------------------------------------
local PlayerManagement = {
    vehicleDataCache = {}
}

-- Update vehicle data for a player
function PlayerManagement.updateVehicleData(player_id, vehicle_id, data)
    -- Initialize player's vehicle cache if it doesn't exist
    if not PlayerManagement.vehicleDataCache[player_id] then
        PlayerManagement.vehicleDataCache[player_id] = {}
    end
    
    -- Extract partConfigFilename directly from the provided data
    local configFilename = data:match("\"partConfigFilename\":\"([^\"]+)\"")
    if configFilename then
        PlayerManagement.vehicleDataCache[player_id][vehicle_id] = configFilename
    end
end

-- Generate and save players data to JSON
function PlayerManagement.updatePlayersData()
    local players = MP.GetPlayers()
    local number_player = MP.GetPlayerCount()
    
    -- Create table to store all player data
    local playerData = {
        playerCount = number_player,
        players = {}
    }
    
    -- Iterate through all players
    for id, name in pairs(players) do
        -- Get all vehicles for this player
        local vehicles = MP.GetPlayerVehicles(id)
        
        -- Process vehicles to extract configuration filenames
        local vehicleConfigs = {}
        
        -- First check our cache for this player
        if PlayerManagement.vehicleDataCache[id] then
            for _, configFilename in pairs(PlayerManagement.vehicleDataCache[id]) do
                table.insert(vehicleConfigs, configFilename)
            end
        end
        
        -- If no cached data, fall back to extracting from vehicle data
        if #vehicleConfigs == 0 and vehicles then
            if type(vehicles) == "table" then
                for k, v in pairs(vehicles) do
                    if type(v) == "string" then
                        local configFilename = v:match("\"partConfigFilename\":\"([^\"]+)\"")
                        if configFilename then
                            table.insert(vehicleConfigs, configFilename)
                        end
                    end
                end
            elseif type(vehicles) == "string" then
                local configFilename = vehicles:match("\"partConfigFilename\":\"([^\"]+)\"")
                if configFilename then
                    table.insert(vehicleConfigs, configFilename)
                end
            end
        end
        
        -- Add player info to playerData
        playerData.players[tostring(id)] = {
            name = name,
            vehicles = vehicleConfigs
        }
    end
    
    -- Convert to JSON and write to file
    local jsonString = Util.JsonEncode(playerData)
    
    -- Write to players.json file
    local file = io.open(PLAYERS_PATH, "w")
    if file then
        file:write(jsonString)
        file:flush() -- Ensure data is written immediately
        file:close()
    else
        printError("Could not open players.json for writing")
    end
end

-- Get online players with their IDs
function PlayerManagement.getOnlinePlayers()
    local players = MP.GetPlayers()
    local onlinePlayers = {}
    
    for id, name in pairs(players) do
        table.insert(onlinePlayers, {
            id = id,
            name = name
        })
    end
    
    return onlinePlayers
end

-- Kick player by ID
function PlayerManagement.kickPlayer(player_id, reason)
    local player_name = MP.GetPlayerName(player_id)
    if player_name and player_name ~= "" then
        MP.DropPlayer(player_id, reason or "You have been kicked from the server")
        log("Player kicked: " .. player_name .. " (ID: " .. player_id .. ") - Reason: " .. (reason or "No reason provided"))
        return true, "Player kicked successfully"
    else
        return false, "Player not found"
    end
end

-- Initialize Player Management System
function PlayerManagement.initialize()
    log("Player Management System initialized")
    return true
end

------------------------------------------
-- Admin Commands System
------------------------------------------
local AdminSystem = {
    admins = {}
}

-- Check if a player is an admin
function AdminSystem.isAdmin(playerName)
    if playerName == "CMD" then 
        return true 
    end
    
    for _, adminName in ipairs(AdminSystem.admins) do
        if playerName:lower() == adminName:lower() then
            return true
        end
    end
    
    return false
end

-- Initialize Admin System
function AdminSystem.initialize()
    -- Load admins from config
    local adminString = getConfigValue("ADMINS")
    AdminSystem.admins = {}
    
    for admin in string.gmatch(adminString, "([^,]+)") do
        table.insert(AdminSystem.admins, trim(admin))  
    end
    
    log("Admin System initialized with " .. #AdminSystem.admins .. " admins")
    return true
end

------------------------------------------
-- Chat Commands System
------------------------------------------
local ChatCommands = {}

function MyCmdHandler(message)
    return ChatCommands.processChatMessage(-2, "CMD", message) and 1 or 0
end


function SendMessage(id, message)
    if message == nil then
        message = id
        id = -2
    end
    
    if id == -2 or id == "CMD" then
        io.write(message:gsub("%^%d", ""):gsub("%^[a-z]", "") .. "\n")
        io.flush()
    else
        MP.SendChatMessage(id, message)
    end
end

-- Handle the /try command
function ChatCommands.tryCommand(sender_id, sender_name, args)
    local commandMessage = table.concat(args, " ")
    local isSuccess = math.random() < 0.5 
    
    if isSuccess then
        SendMessage(-1, "^f^l" .. sender_name .. " ^2удачно^f " .. commandMessage)
    else
        SendMessage(-1, "^f^l" .. sender_name .. " ^4неудачно^f " .. commandMessage)
    end
    
    return true
end

-- Handle the /me command
function ChatCommands.meCommand(sender_id, sender_name, args)
    local commandMessage = table.concat(args, " ")
    SendMessage(-1, sender_name .. " ^o^b" .. commandMessage)
    return true
end

-- Handle the /do command
function ChatCommands.doCommand(sender_id, sender_name, args)
    local commandMessage = table.concat(args, " ")
    SendMessage(-1, commandMessage .. " ((" .. sender_name .. "))")
    return true
end

-- Handle the /coin command
function ChatCommands.coinCommand(sender_id, sender_name)
    local isSuccess = math.random() < 0.5 
    
    if isSuccess then
        SendMessage(-1, "^l^dВыпал орёл. ^f(" .. sender_name .. ")")
    else
        SendMessage(-1, "^l^dВыпала решка. ^f(" .. sender_name .. ")")
    end
    
    return true
end

-- Handle the /sms command
function ChatCommands.smsCommand(sender_id, sender_name, args)
    if #args < 2 then
        SendMessage(sender_id, "Usage: /sms <player_id> <message>")
        return true
    end
    
    local recipient_id = tonumber(args[1])
    if not recipient_id then
        SendMessage(sender_id, "Invalid player ID")
        return true
    end
    
    table.remove(args, 1)
    local message = table.concat(args, " ")
    
    local recipient_name = MP.GetPlayerName(recipient_id)
    if recipient_name == "" then
        SendMessage(sender_id, "Player with ID " .. recipient_id .. " not found")
        return true
    end
    
    if recipient_id == sender_id then
        SendMessage(sender_id, "You cannot send a message to yourself")
        return true
    end
    
    SendMessage(recipient_id, "^e" .. sender_name .. " пишет вам: " .. message)
    SendMessage(sender_id, "^eВы написали " .. recipient_name .. ": " .. message)
    
    return true
end

-- Handle the /on command (admin only)
function ChatCommands.onCommand(sender_id, sender_name, args)
    if not AdminSystem.isAdmin(sender_name) then
        SendMessage(sender_id, "У вас нет доступа к этой команде")
        return true
    end
    
    if #args > 0 then
        local targetID = tonumber(args[1])
        if targetID == nil or MP.GetPlayerName(targetID) == nil then
            targetID = MP.GetId(args[1])
        end

        if targetID ~= nil and MP.GetPlayerName(targetID) ~= nil then
            MP.TriggerClientEvent(targetID, "ECOBLOC", M.data)
            SendMessage(sender_id, "Включение ON для: " .. MP.GetPlayerName(targetID))
        else
            SendMessage(sender_id, "User '" .. args[1] .. "' not found.")
        end
    else
        MP.TriggerClientEvent(-1, "ECOBLOC", M.data)
        SendMessage(-1, "^2Команда включена администратором " .. sender_name)
    end
    
    return true
end

-- Handle the /off command (admin only)
function ChatCommands.offCommand(sender_id, sender_name, args)
    if not AdminSystem.isAdmin(sender_name) then
        SendMessage(sender_id, "У вас нет доступа к этой команде")
        return true
    end
    
    if #args > 0 then
        local targetID = tonumber(args[1])
        if targetID == nil or MP.GetPlayerName(targetID) == nil then
            targetID = MP.GetId(args[1])
        end

        if targetID ~= nil and MP.GetPlayerName(targetID) ~= nil then
            MP.TriggerClientEvent(targetID, "ECOUNBLOCK", "SA")
            SendMessage(sender_id, "Включение OFF для: " .. MP.GetPlayerName(targetID))
        else
            SendMessage(sender_id, "User '" .. args[1] .. "' not found.")
        end
    else
        MP.TriggerClientEvent(-1, "ECOUNBLOCK", "SA")
        SendMessage(-1, "^1Команда отключена администратором " .. sender_name)
    end
    
    return true
end

-- Handle the /status command
function ChatCommands.statusCommand(sender_id, sender_name)
    if not AdminSystem.isAdmin(sender_name) then
        SendMessage(sender_id, "У вас нет доступа к этой команде")
        return true
    end
    
    local players = MP.GetPlayers()
    local playerCount = MP.GetPlayerCount()
    
    SendMessage(sender_id, "=== Статус сервера ===")
    SendMessage(sender_id, "Игроков онлайн: " .. playerCount)
    SendMessage(sender_id, "=== Список игроков ===")
    
    for id, name in pairs(players) do
        SendMessage(sender_id, "ID: " .. id .. " | Имя: " .. name)
    end
    
    SendMessage(sender_id, "=== Конец списка ===")
    return true
end

-- Handle the /ban command (admin only)
function ChatCommands.banCommand(sender_id, sender_name, args)
    if not AdminSystem.isAdmin(sender_name) then
        SendMessage(sender_id, "У вас нет доступа к этой команде")
        return true
    end
    
    if #args < 1 then
        SendMessage(sender_id, "Использование: /ban <имя_игрока> [причина]")
        return true
    end
    
    local targetName = args[1]
    table.remove(args, 1)
    local reason = #args > 0 and table.concat(args, " ") or "No reason provided"
    
    -- Find player ID by name
    local targetId = nil
    local players = MP.GetPlayers()
    for id, name in pairs(players) do
        if name:lower() == targetName:lower() then
            targetId = id
            targetName = name -- Use exact case from server
            break
        end
    end
    
    -- Ban the player in the database
    local success, message = PlayerData.banPlayer(targetName, reason)
    
    if success then
        SendMessage(-1, "^1Игрок " .. targetName .. " был забанен администратором " .. sender_name .. ". Причина: " .. reason)
        log("Player banned: " .. targetName .. " by " .. sender_name .. ". Reason: " .. reason)
        
        -- If player is online, kick them
        if targetId then
            MP.DropPlayer(targetId, "Вы были забанены. Причина: " .. reason)
        end
    else
        SendMessage(sender_id, "^1Ошибка при бане игрока: " .. (message or "неизвестная ошибка"))
    end
    
    return true
end

-- Handle the /unban command (admin only)
function ChatCommands.unbanCommand(sender_id, sender_name, args)
    if not AdminSystem.isAdmin(sender_name) then
        SendMessage(sender_id, "У вас нет доступа к этой команде")
        return true
    end
    
    if #args < 1 then
        SendMessage(sender_id, "Использование: /unban <имя_игрока>")
        return true
    end
    
    local targetName = args[1]
    
    -- Unban the player in the database
    local success, message = PlayerData.unbanPlayer(targetName)
    
    if success then
        SendMessage(sender_id, "^2Игрок " .. targetName .. " был разбанен администратором " .. sender_name)
        log("Player unbanned: " .. targetName .. " by " .. sender_name)
    else
        SendMessage(sender_id, "^1Ошибка при разбане игрока: " .. (message or "неизвестная ошибка"))
    end
    
    return true
end
function ChatCommands.whitelistAddCommand(sender_id, sender_name, args)
    if not AdminSystem.isAdmin(sender_name) then
        SendMessage(sender_id, "У вас нет доступа к этой команде")
        return true
    end
    
    if #args < 1 then
        SendMessage(sender_id, "Использование: /whitelist add <имя_игрока>")
        return true
    end
    
    local targetName = args[1]
    local success, message = PlayerData.addToWhitelist(targetName)
    
    if success then
        SendMessage(sender_id, "^2Игрок " .. targetName .. " добавлен в вайтлист")
        log("Player added to whitelist: " .. targetName .. " by " .. sender_name)
    else
        SendMessage(sender_id, "^1Ошибка при добавлении игрока в вайтлист: " .. (message or "неизвестная ошибка"))
    end
    
    return true
end

function ChatCommands.whitelistRemoveCommand(sender_id, sender_name, args)
    if not AdminSystem.isAdmin(sender_name) then
        SendMessage(sender_id, "У вас нет доступа к этой команде")
        return true
    end
    
    if #args < 1 then
        SendMessage(sender_id, "Использование: /whitelist remove <имя_игрока>")
        return true
    end
    
    local targetName = args[1]
    local success, message = PlayerData.removeFromWhitelist(targetName)
    
    if success then
        SendMessage(sender_id, "^2Игрок " .. targetName .. " удален из вайтлиста")
        log("Player removed from whitelist: " .. targetName .. " by " .. sender_name)
    else
        SendMessage(sender_id, "^1Ошибка при удалении игрока из вайтлиста: " .. (message or "неизвестная ошибка"))
    end
    
    return true
end

function ChatCommands.whitelistStatusCommand(sender_id, sender_name, args)
    if not AdminSystem.isAdmin(sender_name) then
        SendMessage(sender_id, "У вас нет доступа к этой команде")
        return true
    end
    
    local status = getConfigValue("WHITELIST") == "true" and "включен" or "выключен"
    SendMessage(sender_id, "^5Статус вайтлиста: " .. status)
    
    return true
end

-- Fix the ternary operator syntax in whitelistToggleCommand
function ChatCommands.whitelistToggleCommand(sender_id, sender_name)
    if not AdminSystem.isAdmin(sender_name) then
        SendMessage(sender_id, "У вас нет доступа к этой команде")
        return true
    end
    
    local currentStatus = getConfigValue("WHITELIST") == "true"
    CONFIG["WHITELIST"] = currentStatus and "false" or "true"
    
    -- Save updated config
    local file = io.open(CONFIG_PATH, "w")
    if file then
        for key, value in pairs(CONFIG) do
            file:write(key .. " = \"" .. value .. "\"\n")
        end
        file:close()
    end
    
    local newStatus = CONFIG["WHITELIST"] == "true" and "включен" or "выключен"
    SendMessage(sender_id, "^5Вайтлист " .. newStatus)
    log("Whitelist " .. (CONFIG["WHITELIST"] == "true" and "enabled" or "disabled") .. " by " .. sender_name)
    
    return true
end

function ChatCommands.carRestrictionsCommand(sender_id, sender_name, args)
    if not AdminSystem.isAdmin(sender_name) then
        SendMessage(sender_id, "У вас нет доступа к этой команде")
        return true
    end
    
    local currentStatus = getConfigValue("CAR_RESTRICTIONS") == "true"
    CONFIG["CAR_RESTRICTIONS"] = currentStatus and "false" or "true"
    
    -- Save updated config
    local file = io.open(CONFIG_PATH, "w")
    if file then
        for key, value in pairs(CONFIG) do
            file:write(key .. " = \"" .. value .. "\"\n")
        end
        file:close()
    end
    
    local newStatus = CONFIG["CAR_RESTRICTIONS"] == "true" and "включены" or "отключены"
    SendMessage(sender_id, "Ограничения на спавн автомобилей " .. newStatus)
    log("Car restrictions " .. (CONFIG["CAR_RESTRICTIONS"] == "true" and "enabled" or "disabled") .. " by " .. sender_name)
    
    return true
end

-- Add these new functions to the ChatCommands section
function ChatCommands.addCarCommand(sender_id, sender_name, args)
    if not AdminSystem.isAdmin(sender_name) then
        SendMessage(sender_id, "У вас нет доступа к этой команде")
        return true
    end
    
    if #args < 2 then
        SendMessage(sender_id, "Использование: ;addcar <имя_игрока> <имя_машины>")
        return true
    end
    
    local playerName = args[1]
    table.remove(args, 1)
    local carName = table.concat(args, " ")
    
    local success, message = CarManagement.addCarToPlayer(playerName, carName)
    
    if success then
        SendMessage(sender_id, "^2Машина '" .. carName .. "' добавлена игроку " .. playerName)
        log("Car '" .. carName .. "' added to player " .. playerName .. " by " .. sender_name)
    else
        SendMessage(sender_id, "^1Ошибка при добавлении машины: " .. (message or "неизвестная ошибка"))
    end
    
    return true
end

function ChatCommands.removeCarCommand(sender_id, sender_name, args)
    if not AdminSystem.isAdmin(sender_name) then
        SendMessage(sender_id, "У вас нет доступа к этой команде")
        return true
    end
    
    if #args < 2 then
        SendMessage(sender_id, "Использование: ;removecar <имя_игрока> <имя_машины>")
        return true
    end
    
    local playerName = args[1]
    table.remove(args, 1)
    local carName = table.concat(args, " ")
    
    local success, message = CarManagement.removeCarFromPlayer(playerName, carName)
    
    if success then
        SendMessage(sender_id, "^2Машина '" .. carName .. "' удалена у игрока " .. playerName)
        log("Car '" .. carName .. "' removed from player " .. playerName .. " by " .. sender_name)
    else
        SendMessage(sender_id, "^1Ошибка при удалении машины: " .. (message or "неизвестная ошибка"))
    end
    
    return true
end

function ChatCommands.listCarsCommand(sender_id, sender_name, args)
    if not AdminSystem.isAdmin(sender_name) then
        SendMessage(sender_id, "У вас нет доступа к этой команде")
        return true
    end
    
    if #args < 1 then
        SendMessage(sender_id, "Использование: ;listcars <имя_игрока>")
        return true
    end
    
    local playerName = args[1]
    local cars = CarManagement.getPlayerCars(playerName)
    
    if #cars == 0 then
        SendMessage(sender_id, "^3У игрока " .. playerName .. " нет машин")
        return true
    end
    
    SendMessage(sender_id, "^5=== Машины игрока " .. playerName .. " ===")
    for i, car in ipairs(cars) do
        SendMessage(sender_id, i .. ". " .. car)
    end
    SendMessage(sender_id, "^5=== Всего машин: " .. #cars .. " ===")
    
    return true
end

function ChatCommands.helpCommand(sender_id, sender_name)
    local helpText = {
        "^5=== Доступные команды ===",
        "^5;try <действие> - Попытаться выполнить действие (случайный результат)",
        "^5;me <действие> - Описать действие от первого лица",
        "^5;do <описание> - Описать ситуацию от третьего лица",
        "^5;coin - Подбросить монетку",
        "^5;sms <id> <сообщение> - Отправить личное сообщение игроку"
    }
    
    if AdminSystem.isAdmin(sender_name) then
        table.insert(helpText, "^5=== Команды администратора ===")
        table.insert(helpText, "^5;on [id] - Включить команды для всех или конкретного игрока")
        table.insert(helpText, "^5;off [id] - Отключить команды для всех или конкретного игрока")
        table.insert(helpText, "^5;status - Показать статус сервера и список игроков")
        table.insert(helpText, "^5;ban <имя> [причина] - Забанить игрока")
        table.insert(helpText, "^5;unban <имя> - Разбанить игрока")
        table.insert(helpText, "^5;carrestrict - Включить/выключить ограничения на спавн автомобилей")
        table.insert(helpText, "^5;addcar <имя> <машина> - Добавить машину игроку")
        table.insert(helpText, "^5;removecar <имя> <машина> - Удалить машину у игрока")
        table.insert(helpText, "^5;listcars <имя> - Показать список машин игрока")
        table.insert(helpText, "^5;whitelist add <имя> - Добавить игрока в вайтлист")
        table.insert(helpText, "^5;whitelist remove <имя> - Удалить игрока из вайтлиста")
        table.insert(helpText, "^5;whitelist toggle - Включить/выключить вайтлист")
        table.insert(helpText, "^5;whitelist - Показать статус вайтлиста")
    end
    
    for _, line in ipairs(helpText) do
        SendMessage(sender_id, line)
    end
    
    return true
end

function ChatCommands.processChatMessage(sender_id, sender_name, message)
    -- Check if message starts with the command prefix
    if message:sub(1, 1) ~= ";" then
        return false
    end
    
    -- Extract command and arguments
    local parts = {}
    for part in message:gmatch("%S+") do
        table.insert(parts, part)
    end
    
    if #parts == 0 then
        return false
    end
    
    local command = parts[1]:sub(2):lower() 
    table.remove(parts, 1) 
    
    local commandHandlers = {
        ["try"] = ChatCommands.tryCommand,
        ["me"] = ChatCommands.meCommand,
        ["do"] = ChatCommands.doCommand,  
        ["coin"] = ChatCommands.coinCommand,
        ["sms"] = ChatCommands.smsCommand,
        ["on"] = ChatCommands.onCommand,
        ["off"] = ChatCommands.offCommand,
        ["status"] = ChatCommands.statusCommand,
        ["ban"] = ChatCommands.banCommand,
        ["unban"] = ChatCommands.unbanCommand,
        ["addcar"] = ChatCommands.addCarCommand,
        ["removecar"] = ChatCommands.removeCarCommand,
        ["listcars"] = ChatCommands.listCarsCommand,
        ["help"] = ChatCommands.helpCommand,
        ["carrestrict"] = ChatCommands.carRestrictionsCommand,
        ["whitelist"] = function(sender_id, sender_name, args)
            if #args == 0 then
                return ChatCommands.whitelistStatusCommand(sender_id, sender_name, {})
            end
            
            local subcommand = args[1]:lower()
            table.remove(args, 1)
            
            if subcommand == "add" then
                return ChatCommands.whitelistAddCommand(sender_id, sender_name, args)
            elseif subcommand == "remove" then
                return ChatCommands.whitelistRemoveCommand(sender_id, sender_name, args)
            elseif subcommand == "toggle" then
                return ChatCommands.whitelistToggleCommand(sender_id, sender_name)
            else
                SendMessage(sender_id, "Неизвестная подкоманда. Используйте: add, remove, toggle")
                return true
            end
        end
    }
    
    -- Execute command if it exists
    if commandHandlers[command] then
        return commandHandlers[command](sender_id, sender_name, parts)
    end
    
    return false
end

-- Initialize Chat Commands System
function ChatCommands.initialize()
    log("Chat Commands System initialized")
    return true
end

------------------------------------------
-- Event Handlers
------------------------------------------

-- Handle player connect event

function onPlayerAuth(player_name, player_role, is_guest, identifiers)
    local player_ip = identifiers.ip or "unknown"
    if DDoSProtection.isIpBanned(player_ip) then
        log("Player with banned IP attempted to connect: " .. player_name .. " (IP: " .. player_ip .. ")")
        return "Your IP is temporarily banned for connection abuse. Try again later."
    end
    
    DDoSProtection.recordConnectionAttempt(player_ip, player_name)

    local isBanned, banReason = PlayerData.isPlayerBanned(player_name)
    if isBanned then
        log("Banned player attempted to connect: " .. player_name)
        return "You are banned from this server. Reason: " .. (banReason or "No reason provided")
    end
    
    log("Player authenticating: " .. player_name .. " (Role: " .. player_role .. ", Guest: " .. tostring(is_guest) .. ", IP: " .. player_ip .. ")")
    


    
    if getConfigValue("WHITELIST") == "true" then
        local playerData = PlayerData.loadPlayerData(player_name)
        if not playerData or not playerData.whitelisted then
            log("Non-whitelisted player attempted to connect: " .. player_name)
            return "This server is whitelisted. You are not on the whitelist."
        end
    end
 
    if getConfigValue("NOGUEST") == "true" and is_guest then
        log("Guest account attempted to connect: " .. player_name)
        return getConfigValue("NOGUESTMSG")
    end
    
    return 0
end
function onPlayerConnecting(player_id)
    local player_name = MP.GetPlayerName(player_id)
    local identifiers = MP.GetPlayerIdentifiers(player_id)
    local player_ip = identifiers.ip or "unknown"
    
    log("Player connecting: " .. player_name .. " (ID: " .. player_id .. ", IP: " .. player_ip .. ")")        
    return ""
end

function onPlayerJoin(player_id)
    local player_name = MP.GetPlayerName(player_id)
    
    -- Send welcome message
    if AdminSystem.isAdmin(player_name) then
        SendMessage(player_id, "^2" .. getConfigValue("WELCOMESTAFF") .. " " .. player_name .. "!")
    else
        SendMessage(player_id, "^5" .. getConfigValue("WELCOMEPLAYER") .. " " .. player_name .. "!")
    end
    
    -- Update players.json
    PlayerManagement.updatePlayersData()
    
    return 0
end



function onPlayerDisconnect(player_id)
    local player_name = MP.GetPlayerName(player_id)
    log("Player disconnected: " .. player_name .. " (ID: " .. player_id .. ")")
    

    local playerData = PlayerData.loadPlayerData(player_name)
    if playerData then
        playerData.lastSeen = os.time()
        PlayerData.savePlayerData(player_name, playerData)
    end
    

    PlayerManagement.vehicleDataCache[player_id] = nil
    

    PlayerManagement.updatePlayersData()
end


function onChatMessage(player_id, player_name, message)
    if ChatCommands.processChatMessage(player_id, player_name, message) then
        return 1
    end
    log("Chat: " .. player_name .. ": " .. message)
    return 0
end


function handleVehicleDataUpdate(player_id, vehicle_id, data, isSpawn)
    local player_name = MP.GetPlayerName(player_id)
    

    local configFilename = data:match("\"partConfigFilename\":\"([^\"]+)\"")
    

    if isSpawn and configFilename and getConfigValue("CAR_RESTRICTIONS") == "true" then

        if not CarManagement.canPlayerSpawnCar(player_name, configFilename) then

            log("Player " .. player_name .. " attempted to spawn restricted car: " .. configFilename)
            SendMessage(player_id, "^1You don't have permission to spawn this vehicle.")
            return 1 
        end
    end
    
    PlayerManagement.updateVehicleData(player_id, vehicle_id, data)
    
    PlayerManagement.updatePlayersData()
    
    if configFilename then
        if isSpawn then
            log("Player " .. player_name .. " spawned vehicle: " .. configFilename)
        else
            log("Player " .. player_name .. " edited vehicle: " .. configFilename)
        end
    end
    
    return 0 
end

function onVehicleSpawn(player_id, vehicle_id, data)
    MP.TriggerClientEvent(player_id, "ECOBLOC", M.data)
    return handleVehicleDataUpdate(player_id, vehicle_id, data, true)
end

function onVehicleEdited(player_id, vehicle_id, data)
    return handleVehicleDataUpdate(player_id, vehicle_id, data, false)
end

function onVehicleDeleted(player_id, vehicle_id)

    if PlayerManagement.vehicleDataCache[player_id] then
        PlayerManagement.vehicleDataCache[player_id][vehicle_id] = nil
    end
    

    PlayerManagement.updatePlayersData()
    
    return 0
end



------------------------------------------
-- Plugin Initialization
------------------------------------------


function onInit()
    print_color("=== " .. PLUGIN_NAME .. " v" .. PLUGIN_VERSION .. " by " .. PLUGIN_AUTHOR .. " ===", "green")
    

    ensureDirectoriesExist()
    

    loadConfig()
    

    DDoSProtection.initialize()
    CarManagement.initialize()
    PlayerManagement.initialize()
    AdminSystem.initialize()
    ChatCommands.initialize()
    
    CarManagement.loadCarsData()
    
    log("Plugin initialized successfully")
    

    MP.RegisterEvent("onPlayerAuth", "onPlayerAuth")
    MP.RegisterEvent("onPlayerConnecting", "onPlayerConnecting")
    MP.RegisterEvent("onPlayerJoin", "onPlayerJoin")
    MP.RegisterEvent("onPlayerDisconnect", "onPlayerDisconnect")
    MP.RegisterEvent("onChatMessage", "onChatMessage") 
    MP.RegisterEvent("onConsoleInput", "MyCmdHandler") 
    MP.RegisterEvent("onVehicleSpawn", "onVehicleSpawn")
    MP.RegisterEvent("onVehicleEdited", "onVehicleEdited")
    MP.RegisterEvent("onVehicleDeleted", "onVehicleDeleted")




    log("Plugin loaded")
    return 0
end