-- Queue for storing webhook messages to send after 5 seconds
local messageQueue = {}
local queueActive = true
local sentPlayers = {}

--// Create embed function \\--
local function createEmbed(title, description, color)
    if not color then
        color = 5814783  -- Default blue color
    end
    
    return {
        title = title,
        description = description,
        color = color,
        timestamp = DateTime.now():ToIsoDate(),
        footer = {
            text = "Roblox Advanced Tracking Tool"
        }
    }
end

--// Send session info immediately as embed \\--
local function sendSessionInfo()
    if not getgenv().webhookUrl or getgenv().webhookUrl == "" then
        return
    end
    
    local sessionInfo = string.format(
        "**Place ID:** %s\n" ..
        "**Game ID:** %s\n" ..
        "**Job ID:** %s\n" ..
        "**Server Time:** %s",
        tostring(game.PlaceId),
        tostring(game.PlaceId),
        tostring(game.JobId),
        os.date("%Y-%m-%d %H:%M:%S")
    )
    
    local data = {
        embeds = {
            createEmbed("Session Started", sessionInfo, 32768)  -- Green color
        }
    }
    
    local headers = {
        ["Content-Type"] = "application/json"
    }
    
    pcall(function()
        http_request({
            Url = getgenv().webhookUrl,
            Method = "POST",
            Headers = headers,
            Body = game:GetService("HttpService"):JSONEncode(data)
        })
    end)
end

--// Process queue after 5 seconds \\--
local function processQueue()
    wait(5)
    queueActive = false
    
    for _, embedData in ipairs(messageQueue) do
        local data = {
            embeds = {embedData.embed}
        }
        
        local headers = {
            ["Content-Type"] = "application/json"
        }
        
        pcall(function()
            http_request({
                Url = getgenv().webhookUrl,
                Method = "POST",
                Headers = headers,
                Body = game:GetService("HttpService"):JSONEncode(data)
            })
        end)
        
        wait(0.5) -- Delay between messages
    end
end

--// sendToWebhook Function with embeds \\--
local function sendToWebhook(title, description, color)
    if not title or not description then
        return
    end
    
    local embed = createEmbed(title, description, color)
    
    if queueActive then
        table.insert(messageQueue, {embed = embed})
    else
        local data = {
            embeds = {embed}
        }
        
        local headers = {
            ["Content-Type"] = "application/json"
        }
        
        pcall(function()
            http_request({
                Url = getgenv().webhookUrl,
                Method = "POST",
                Headers = headers,
                Body = game:GetService("HttpService"):JSONEncode(data)
            })
        end)
    end
end

--// Process player info and add to webhook queue \\--
local function processPlayer(player, eventType, color)
    if not player then
        return
    end
    
    local playerKey = player.UserId .. "_" .. eventType
    if sentPlayers[playerKey] then
        return
    end
    sentPlayers[playerKey] = true
    
    local playerInfo = string.format(
        "**Player Name:** %s\n" ..
        "**Display Name:** %s\n" ..
        "**User ID:** %d\n" ..
        "**Game ID:** %s\n" ..
        "**Time:** %s",
        player.Name,
        player.DisplayName,
        player.UserId,
        tostring(game.PlaceId),
        os.date("%Y-%m-%d %H:%M:%S")
    )
    
    sendToWebhook(eventType, playerInfo, color or 5814783)
end

--// Send immediate session info as embed \\--
sendSessionInfo()

--// Start queue processor \\--
spawn(processQueue)

--// Listen for local player joining the game \\--
local function onLocalPlayerAdded()
    if game.Players.LocalPlayer then
        processPlayer(game.Players.LocalPlayer, "Player Joined Game", 65280)  -- Green
    end
end

--// Listen for team-related events \\--
local function setupTeamListeners()
    game:GetService("Players").PlayerAdded:Connect(function(player)
        if player == game.Players.LocalPlayer then
            processPlayer(player, "Local Player Added", 65280)  -- Green
        end
    end)
    
    if game:GetService("Teams") then
        game:GetService("Teams").ChildAdded:Connect(function(team)
            if team:IsA("Team") then
                if game.Players.LocalPlayer and game.Players.LocalPlayer.Team then
                    processPlayer(
                        game.Players.LocalPlayer, 
                        "Joined Team: " .. game.Players.LocalPlayer.Team.Name, 
                        255  -- Blue
                    )
                end
            end
        end)
    end
end

--// Listen for player chat \\--
local function onPlayerChatted(message)
    if game.Players.LocalPlayer then
        local chatInfo = string.format(
            "**Player Name:** %s\n" ..
            "**Message Content:** %s\n" ..
            "**Time:** %s",
            game.Players.LocalPlayer.Name,
            message,
            os.date("%Y-%m-%d %H:%M:%S")
        )
        sendToWebhook("Chat Message", chatInfo, 10181046)  -- Purple
    end
end

--// Listen for game state changes \\--
local function setupGameStateListeners()
    processPlayer(game.Players.LocalPlayer, "Game Loaded", 8421504)  -- Gray
    
    game.Players.LocalPlayer.CharacterAdded:Connect(function(character)
        processPlayer(game.Players.LocalPlayer, "Player Respawned", 16776960)  -- Yellow
    end)
    
    if game.Players.LocalPlayer.Character then
        local humanoid = game.Players.LocalPlayer.Character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.Died:Connect(function()
                processPlayer(game.Players.LocalPlayer, "Player Died", 16711680)  -- Red
            end)
        end
    end
end

--// Main initialization function \\--
local function initializeWebhookListener()
    onLocalPlayerAdded()
    
    setupTeamListeners()
    setupGameStateListeners()
    
    game.Players.LocalPlayer.Chatted:Connect(onPlayerChatted)
end

--// Start the listener \\--
initializeWebhookListener()

-- Listen for player leaving the game
game:GetService("CoreGui").ChildRemoved:Connect(function(child)
    if child.Name == "RobloxGui" then
        if game.Players.LocalPlayer then
            processPlayer(game.Players.LocalPlayer, "Player Left Game", 16711680)  -- Red
        end
    end
end)