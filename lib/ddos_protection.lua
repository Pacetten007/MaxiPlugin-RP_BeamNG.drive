
local function cleanupOldRecords()
    local currentTime = os.time()
    local timeThreshold = currentTime - config.timeWindow
    
    for ip, data in pairs(connectionAttempts) do
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
            if config.debug then
                print("[DDoS Protection] Ban expired for IP: " .. ip)
            end
        end
        
        -- Remove IP from tracking if no recent connections and not banned
        if #data.timestamps == 0 and not data.banned then
            connectionAttempts[ip] = nil
        end
    end
end


function M.isIpBanned(ip)
    if not connectionAttempts[ip] then
        return false
    end
    
    -- Check if ban has expired
    if connectionAttempts[ip].banned then
        local currentTime = os.time()
        if connectionAttempts[ip].banExpiry < currentTime then
            connectionAttempts[ip].banned = false
            connectionAttempts[ip].banExpiry = 0
            return false
        end
        return true
    end
    
    return false
end

function M.recordConnectionAttempt(ip, playerName)
    local currentTime = os.time()
    
    -- Initialize record for this IP if it doesn't exist
    if not connectionAttempts[ip] then
        connectionAttempts[ip] = {
            timestamps = {},
            banned = false,
            banExpiry = 0,
            playerName = playerName
        }
    end
    
    -- Update player name if provided
    if playerName and playerName ~= "" then
        connectionAttempts[ip].playerName = playerName
    end
    
    -- If already banned, just return true
    if connectionAttempts[ip].banned then
        return true
    end
    
    -- Add current timestamp
    table.insert(connectionAttempts[ip].timestamps, currentTime)
    
    -- Check if connection limit exceeded
    local timeThreshold = currentTime - config.timeWindow
    local recentConnections = 0
    
    for _, timestamp in ipairs(connectionAttempts[ip].timestamps) do
        if timestamp >= timeThreshold then
            recentConnections = recentConnections + 1
        end
    end
    
    -- Ban if too many connections
    if recentConnections > config.maxConnections then
        connectionAttempts[ip].banned = true
        connectionAttempts[ip].banExpiry = currentTime + config.banDuration
        
        if config.debug then
            print("[DDoS Protection] IP banned for connection abuse: " .. ip .. 
                  " (" .. (connectionAttempts[ip].playerName or "Unknown") .. 
                  ") - " .. recentConnections .. " connections in " .. config.timeWindow .. " seconds")
        end
        
        return true
    end
    
    return false
end

-- Get a list of currently banned IPs
function M.getBannedIPs()
    local bannedList = {}
    local currentTime = os.time()
    
    for ip, data in pairs(connectionAttempts) do
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
function M.banIP(ip, duration, playerName)
    duration = duration or config.banDuration
    local currentTime = os.time()
    
    if not connectionAttempts[ip] then
        connectionAttempts[ip] = {
            timestamps = {},
            banned = false,
            banExpiry = 0,
            playerName = playerName or "Unknown"
        }
    end
    
    connectionAttempts[ip].banned = true
    connectionAttempts[ip].banExpiry = currentTime + duration
    
    if playerName and playerName ~= "" then
        connectionAttempts[ip].playerName = playerName
    end
    
    if config.debug then
        print("[DDoS Protection] IP manually banned: " .. ip .. 
              " (" .. (connectionAttempts[ip].playerName or "Unknown") .. 
              ") for " .. duration .. " seconds")
    end
    
    return true
end

-- Unban an IP
function M.unbanIP(ip)
    if not connectionAttempts[ip] then
        return false
    end
    
    connectionAttempts[ip].banned = false
    connectionAttempts[ip].banExpiry = 0
    
    if config.debug then
        print("[DDoS Protection] IP unbanned: " .. ip .. 
              " (" .. (connectionAttempts[ip].playerName or "Unknown") .. ")")
    end
    
    return true
end


function M.setConfig(newConfig)
    if newConfig.maxConnections and newConfig.maxConnections > 0 then
        config.maxConnections = newConfig.maxConnections
    end
    
    if newConfig.timeWindow and newConfig.timeWindow > 0 then
        config.timeWindow = newConfig.timeWindow
    end
    
    if newConfig.banDuration and newConfig.banDuration >= 0 then
        config.banDuration = newConfig.banDuration
    end
    
    if newConfig.debug ~= nil then
        config.debug = newConfig.debug
    end
    
    return config
end


function M.getConfig()
    return {
        maxConnections = config.maxConnections,
        timeWindow = config.timeWindow,
        banDuration = config.banDuration,
        debug = config.debug
    }
end