-- 3D lobby controller.
-- The lobby exists in Workspace before Play; this script only wires the
-- ProximityPrompts and transfers the player into the 2D World PvP match.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local workspaceService=game:GetService("Workspace")

local lobby=workspaceService:WaitForChild("Lobby")
local remotes=ReplicatedStorage:WaitForChild("WorldPvPRemotes")
local EnterMatch=remotes:WaitForChild("EnterMatch")
local Notice=remotes:WaitForChild("Notice")

local function notice(player,message,kind)
    Notice:FireClient(player,{message=message,kind=kind or "info"})
end

local modeParts={
    {part=lobby.ModePads.Teams,prompt=lobby.ModePads.TeamsPrompt,value="Teams",label="TEAMS"},
    {part=lobby.ModePads.FFA,prompt=lobby.ModePads.FFAPrompt,value="FFA",label="FREE FOR ALL"},
    {part=lobby.ModePads.Solo,prompt=lobby.ModePads.SoloPrompt,value="Solo",label="SOLO"},
}
local mapParts={
    {part=lobby.MapPads.World,prompt=lobby.MapPads.WorldPrompt,value="World",label="WORLD"},
    {part=lobby.MapPads.Europe,prompt=lobby.MapPads.EuropePrompt,value="Europe",label="EUROPE"},
    {part=lobby.MapPads.Asia,prompt=lobby.MapPads.AsiaPrompt,value="Asia",label="ASIA"},
    {part=lobby.MapPads.MENA,prompt=lobby.MapPads.MENAPrompt,value="MENA",label="MIDDLE EAST"},
}

local function setBillboard(modelName,partName)
    local model=lobby:FindFirstChild(modelName)
    local part=model and model:FindFirstChild(partName)
    local billboard=model and model:FindFirstChild(partName.."Billboard")
    if billboard and part then billboard.Adornee=part end
end

setBillboard("ModePads","Teams")
setBillboard("ModePads","FFA")
setBillboard("ModePads","Solo")
setBillboard("MapPads","World")
setBillboard("MapPads","Europe")
setBillboard("MapPads","Asia")
setBillboard("MapPads","MENA")
if lobby.EnterPad.EnterBillboard then lobby.EnterPad.EnterBillboard.Adornee=lobby.EnterPad end

for _,entry in ipairs(modeParts) do
    entry.prompt.Triggered:Connect(function(player)
        player:SetAttribute("SelectedMode",entry.value)
        notice(player,"تم اختيار النمط: "..entry.label..". الآن اختر الخريطة.","success")
    end)
end

for _,entry in ipairs(mapParts) do
    entry.prompt.Triggered:Connect(function(player)
        player:SetAttribute("SelectedMap",entry.value)
        notice(player,"تم اختيار الخريطة: "..entry.label..". اقترب من ENTER WORLD للدخول.","success")
    end)
end

lobby.EnterPrompt.Triggered:Connect(function(player)
    player:SetAttribute("SelectedMode",player:GetAttribute("SelectedMode") or "FFA")
    player:SetAttribute("SelectedMap",player:GetAttribute("SelectedMap") or "World")
    EnterMatchRequest:Fire(player)
end)

local function hideCharacter(player,character)
    if not character then return end
    if not player:GetAttribute("InWorldMatch") then return end
    character:PivotTo(CFrame.new(lobby.GameAnchor.Position + Vector3.new(0,4,0)))
    for _,item in ipairs(character:GetDescendants()) do
        if item:IsA("BasePart") then
            item.Transparency=1
            item.CanCollide=false
            item.CastShadow=false
        elseif item:IsA("Decal") then
            item.Transparency=1
        end
    end
end

local function wirePlayer(player)
    player:SetAttribute("SelectedMode",player:GetAttribute("SelectedMode") or "FFA")
    player:SetAttribute("SelectedMap",player:GetAttribute("SelectedMap") or "World")
    player:SetAttribute("InWorldMatch",false)
    player.CharacterAdded:Connect(function(character)
        task.wait()
        hideCharacter(player,character)
    end)
    player:GetAttributeChangedSignal("InWorldMatch"):Connect(function()
        if player:GetAttribute("InWorldMatch") then
            hideCharacter(player,player.Character)
        end
    end)
end

Players.PlayerAdded:Connect(wirePlayer)
for _,player in ipairs(Players:GetPlayers()) do
    wirePlayer(player)
end
