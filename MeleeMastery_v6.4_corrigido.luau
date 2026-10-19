-- MeleeMastery v6.4 MAX - correcoes aplicadas ao original em tempo de execucao.
-- Ajustes: altura maior, afastamento horizontal maior, viagem mais rapida,
-- hitbox do NPC ampliada para alcance e clique por VirtualInputManager com fallback.

local sourceUrl = "https://raw.githubusercontent.com/cristhianberitto-dev/Rd-hub-talvez-definitivo/main/MeleeMastery_Only_v6.4.luau"

local fetchOk, source = pcall(function()
    return game:HttpGet(sourceUrl)
end)

if not fetchOk or type(source) ~= "string" or #source < 1000 then
    error("MeleeMastery MAX: nao foi possivel baixar o original. Verifique a conexao do executor.")
end

source = source:gsub("\r\n", "\n")

local function replaceOnce(oldText, newText, description)
    local first = source:find(oldText, 1, true)
    if not first then
        error("MeleeMastery MAX: trecho nao encontrado: " .. description .. ". O original pode ter mudado.")
    end
    local second = source:find(oldText, first + #oldText, true)
    if second then
        error("MeleeMastery MAX: trecho duplicado: " .. description .. ". Execucao cancelada.")
    end
    source = source:sub(1, first - 1) .. newText .. source:sub(first + #oldText)
end

local function replaceAll(oldText, newText, expectedCount, description)
    local count = 0
    source = source:gsub(oldText:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"), function()
        count += 1
        return newText
    end)
    if count ~= expectedCount then
        error("MeleeMastery MAX: quantidade inesperada no trecho " .. description .. " (" .. tostring(count) .. "). Execucao cancelada.")
    end
end

-- Altura inicial e velocidade de deslocamento.
replaceOnce("local Height = 6", "local Height = 30", "altura inicial")
replaceOnce("local FLIGHT_SPEED = 85", "local FLIGHT_SPEED = 150", "velocidade de locomocao")
replaceOnce(
    "local cruiseY = math.max(root.Position.Y, destination.Y) + 40",
    "local cruiseY = math.max(root.Position.Y, destination.Y) + 80",
    "altura de cruzeiro durante a viagem"
)

-- Slider: de 20 a 40 studs, com valor inicial 30.
replaceAll("UDim2.new((Height - 4) / 6, 0, 1, 0)", "UDim2.new((Height - 20) / 20, 0, 1, 0)", 2, "preenchimento do slider de altura")
replaceOnce(
    "Height = math.clamp(math.floor(4 + alpha * 6 + 0.5), 4, 10)",
    "Height = math.clamp(math.floor(20 + alpha * 20 + 0.5), 20, 40)",
    "limites do slider de altura"
)

-- Fica realmente acima do topo do modelo em vez de usar o centro do root.
replaceOnce(
    "local desiredY = targetRoot.Position.Y + Height",
    "local modelTopY = -math.huge\n                        for _, part in ipairs(target:GetDescendants()) do\n                            if part:IsA("BasePart") and part ~= targetRoot then\n                                modelTopY = math.max(modelTopY, part.Position.Y + (part.Size.Y / 2))\n                            end\n                        end\n                        if modelTopY == -math.huge then modelTopY = targetRoot.Position.Y end\n                        local desiredY = modelTopY + Height",
    "calculo da altura acima do NPC"
)

-- Afastamento para nao ficar encostado/dentro do NPC.
replaceOnce("local offsetX = 4.5", "local offsetX = 18", "afastamento horizontal do NPC")

-- Alcance ampliado: habilita novamente a alteracao de hitbox, com limite controlado.
replaceOnce(
    "local hitboxSize = math.clamp(28 + (Height * 1.5), 28, 48)",
    "local hitboxSize = math.clamp(82 + (Height * 0.2), 82, 90)",
    "tamanho maximo da hitbox"
)

-- Clique automatico sem mouse1click/mouse1press, que no relato anterior causavam crash.
local attackStart = source:find("local function ClickAttack()", 1, true)
if not attackStart then
    error("MeleeMastery MAX: funcao ClickAttack nao encontrada. Execucao cancelada.")
end
local hitboxMarker = source:find("-- Aumenta a hitbox do NPC", attackStart, true)
if not hitboxMarker then
    error("MeleeMastery MAX: limite da funcao ClickAttack nao encontrado. Execucao cancelada.")
end

local safeAttack = [[local function ClickAttack()
    -- Intervalo de seguranca para evitar uma sequencia de eventos de input muito rapida.
    if os.clock() - lastClick < 0.65 then return false end

    -- Primeiro tenta gerar um clique pela API de input virtual, sem mouse1click().
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
    -- Canto inferior direito evita clicar nos botoes do painel central do script.
    local x = math.floor(viewport.X * 0.86)
    local y = math.floor(viewport.Y * 0.82)
    local inputOk, virtualInput = pcall(function()
        return game:GetService("VirtualInputManager")
    end)

    if inputOk and virtualInput then
        local downOk = pcall(function()
            virtualInput:SendMouseButtonEvent(x, y, 0, true, game, 0)
        end)
        task.wait(0.04)
        -- Sempre tenta soltar o botao, mesmo se o evento de pressionar falhar.
        local upOk = pcall(function()
            virtualInput:SendMouseButtonEvent(x, y, 0, false, game, 0)
        end)
        if downOk and upOk then
            lastClick = os.clock()
            return true
        end
    end

    -- Fallback: ativacao da ferramenta Melee equipada. Pode variar conforme o executor/jogo.
    local character = Player.Character
    if character then
        for _, item in ipairs(character:GetChildren()) do
            if item:IsA("Tool") and item.ToolTip == "Melee" then
                local activateOk = pcall(function() item:Activate() end)
                if activateOk then
                    lastClick = os.clock()
                    return true
                end
            end
        end
    end
    return false
end
]]

source = source:sub(1, attackStart - 1) .. safeAttack .. source:sub(hitboxMarker)
source = source:gsub("v6%.4 | click 0%.5s %+ hitbox controlada", "v6.4 MAX | altura 20-40 + alcance ampliado")
source = source:gsub(
    'print%(%"%[MeleeMastery%] v6%.4 carregada; click a cada 0%.5s %+ hitbox do NPC controlada para alcance%.%")',
    'print("[MeleeMastery] v6.4 MAX carregada; altura e alcance ampliados.")'
)

local compileOk, compiled = pcall(loadstring, source)
if not compileOk or type(compiled) ~= "function" then
    error("MeleeMastery MAX: falha ao compilar o original corrigido. O original pode ter mudado.")
end

return compiled()
