-- DZST by Venom v3.0
-- Clean action bar UI with real material-selected paint workflow.
-- Original code by DZST by Venom.
--
-- Paint workflow:
-- 1) Open Color.
-- 2) Press AUTO TARGET or hold SHIFT and click the car body.
-- 3) Move RGB sliders.
--
-- Based on CSP Paintshop-style logic: carRoot:0 -> findMeshes(material) -> setMaterialTexture(txDiffuse).

local S = {
  view = "home",
  status = "Ready",
  r = 255,
  g = 0,
  b = 0,
  metallic = 0.50,
  sharpness = 0.50,
  clearcoat = 0.50,
  selectedTab = "Body",
  selectedPart = "ALL BODY",
  search = "",
  autoOpenDelay = 0,
}

local paint = {
  carNode = nil,
  allCarMeshes = nil,
  selectedMeshes = nil,
  selectedMaterial = "none",
  hoveredMaterial = "none",
  hoveredMesh = "none",
  canvas = nil,
  originalTexture = nil,
  lastHex = "",
  refresh = 0,
}

local teleports = {
  { group = "SHIBAURA PA", name = "Position 1", cmd = "pos1" },
  { group = "SHIBAURA PA", name = "Position 2", cmd = "pos2" },
  { group = "SHIBAURA PA", name = "Position 3", cmd = "pos3" },
  { group = "SHIBAURA PA", name = "Position 4", cmd = "pos4" },
  { group = "SHIBAURA PA", name = "Position 5", cmd = "pos5" },
  { group = "DAISHI PA", name = "Position 1", cmd = "daishi1" },
  { group = "DAISHI PA", name = "Position 2", cmd = "daishi2" },
  { group = "TATSUMI PA", name = "Main Spot", cmd = "tatsumi" },
}

local materials = {
  "ext_Body_Paint",
  "EXT_Body_Paint",
  "Body_Paint",
  "BODY_PAINT",
  "carpaint",
  "CarPaint",
  "EXT_Carpaint",
  "body",
  "BODY",
  "paint",
  "chassis",
}

local C = {
  bg = rgbm(0.055, 0.060, 0.075, 0.94),
  card = rgbm(0.105, 0.110, 0.135, 0.92),
  card2 = rgbm(0.140, 0.145, 0.175, 0.95),
  line = rgbm(1, 1, 1, 0.06),
  text = rgbm(0.96, 0.97, 1, 1),
  muted = rgbm(0.62, 0.65, 0.72, 1),
  dim = rgbm(0.40, 0.43, 0.50, 1),
  purple = rgbm(0.66, 0.10, 1.00, 1),
  purple2 = rgbm(0.50, 0.08, 0.88, 1),
  green = rgbm(0.46, 0.95, 0.22, 1),
  red = rgbm(1.00, 0.22, 0.18, 1),
}

local function clamp(v, a, b)
  if v < a then return a end
  if v > b then return b end
  return v
end

local function hex()
  return string.format("#%02X%02X%02X", clamp(S.r, 0, 255), clamp(S.g, 0, 255), clamp(S.b, 0, 255))
end

local function rgb()
  return rgbm(S.r / 255, S.g / 255, S.b / 255, 1)
end

local function sim()
  if ac and ac.getSim then
    local ok, v = pcall(ac.getSim)
    if ok then return v end
  end
  return nil
end

local function online()
  local s = sim()
  return s ~= nil and s.isOnlineRace == true
end

local function send(cmd, offline)
  if online() and ac and ac.sendChatMessage then
    local ok = pcall(ac.sendChatMessage, cmd)
    if ok then
      S.status = "Sent: " .. cmd
      return
    end
  end
  S.status = offline or ("Offline: " .. cmd)
end

local function contains(a, b)
  a = string.lower(tostring(a or ""))
  b = string.lower(tostring(b or ""))
  return b == "" or string.find(a, b, 1, true) ~= nil
end

local function pushTheme()
  ui.pushStyleVar(ui.StyleVar.WindowRounding, 18)
  ui.pushStyleVar(ui.StyleVar.FrameRounding, 13)
  ui.pushStyleVar(ui.StyleVar.ScrollbarRounding, 12)
  ui.pushStyleVar(ui.StyleVar.GrabRounding, 12)
  ui.pushStyleVar(ui.StyleVar.WindowPadding, vec2(14, 14))
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, vec2(10, 9))
  ui.pushStyleColor(ui.StyleColor.WindowBg, C.bg)
  ui.pushStyleColor(ui.StyleColor.Text, C.text)
  ui.pushStyleColor(ui.StyleColor.Button, C.card2)
  ui.pushStyleColor(ui.StyleColor.ButtonHovered, rgbm(1, 1, 1, 0.075))
  ui.pushStyleColor(ui.StyleColor.ButtonActive, rgbm(1, 1, 1, 0.10))
  ui.pushStyleColor(ui.StyleColor.FrameBg, C.card2)
  ui.pushStyleColor(ui.StyleColor.FrameBgHovered, rgbm(1, 1, 1, 0.075))
  ui.pushStyleColor(ui.StyleColor.FrameBgActive, rgbm(1, 1, 1, 0.10))
  ui.pushStyleColor(ui.StyleColor.SliderGrab, C.purple)
  ui.pushStyleColor(ui.StyleColor.SliderGrabActive, C.purple)
end

local function popTheme()
  ui.popStyleColor(10)
  ui.popStyleVar(6)
end

local function pill(label, active, w, h)
  if active then
    ui.pushStyleColor(ui.StyleColor.Button, C.purple)
    ui.pushStyleColor(ui.StyleColor.ButtonHovered, C.purple)
    ui.pushStyleColor(ui.StyleColor.ButtonActive, C.purple2)
  else
    ui.pushStyleColor(ui.StyleColor.Button, C.card2)
    ui.pushStyleColor(ui.StyleColor.ButtonHovered, rgbm(1, 1, 1, 0.075))
    ui.pushStyleColor(ui.StyleColor.ButtonActive, rgbm(1, 1, 1, 0.10))
  end
  local clicked = ui.button(label, vec2(w or 120, h or 34))
  ui.popStyleColor(3)
  return clicked
end

local function header(title)
  ui.textColored("DZST by Venom", C.text)
  ui.sameLine()
  ui.textColored(online() and "ONLINE" or "OFFLINE", online() and C.green or C.muted)
  ui.separator()
  ui.textColored(title, C.text)
end

local function cardStart(height)
  local p = ui.getCursor()
  local w = ui.availableSpaceX()
  ui.drawRectFilled(vec2(p.x, p.y), vec2(p.x + w, p.y + height), C.card, 18)
  ui.drawRect(vec2(p.x, p.y), vec2(p.x + w, p.y + height), C.line, 18, 0, 1)
  ui.dummy(vec2(8, 8))
  ui.setCursorX(p.x + 14)
end

local function cardEnd()
  ui.dummy(vec2(1, 10))
end

local function getPaintRoots()
  if paint.carNode ~= nil and paint.allCarMeshes ~= nil then
    return true
  end

  if not ac or type(ac.findNodes) ~= "function" then
    S.status = "CSP API error: ac.findNodes not available"
    return false
  end

  local okNode, node = pcall(ac.findNodes, "carRoot:0")
  if not okNode or node == nil then
    S.status = "Could not find carRoot:0"
    return false
  end

  paint.carNode = node

  local okMeshes, meshes = pcall(function()
    return node:findMeshes("{ ! material:DAMAGE_GLASS & lod:A }")
  end)

  if not okMeshes or meshes == nil then
    S.status = "Could not scan car meshes"
    return false
  end

  paint.allCarMeshes = meshes
  return true
end

local function createCanvas()
  if paint.canvas == nil then
    paint.canvas = ui.ExtraCanvas(vec2(2048, 2048))
  end

  local c = rgb()
  paint.canvas:clear(c)
  paint.canvas:update(function()
    ui.drawRectFilled(vec2(0, 0), vec2(2048, 2048), c)
  end)

  return paint.canvas
end

local function selectMaterialByName(mat)
  if not getPaintRoots() then return false end

  local ok, meshes = pcall(function()
    return paint.carNode:findMeshes("{ material:" .. mat .. " & lod:A }")
  end)

  if ok and meshes ~= nil then
    paint.selectedMeshes = meshes
    paint.selectedMaterial = mat
    S.status = "Selected material: " .. mat
    return true
  end

  return false
end

local function autoSelectBody()
  for _, mat in ipairs(materials) do
    if selectMaterialByName(mat) then
      return true
    end
  end
  S.status = "Auto target failed. Hold SHIFT and click the body."
  return false
end

local function updateHoverTarget()
  if not getPaintRoots() then return end
  if not render or type(render.createMouseRay) ~= "function" then return end
  if not ac.emptySceneReference then return end

  local s = sim()
  local ray = render.createMouseRay()
  local ref = ac.emptySceneReference()

  local hit = false
  pcall(function()
    hit = s and s.isWindowForeground and paint.allCarMeshes:raycast(ray, ref) ~= -1
  end)

  if hit then
    local okName, meshName = pcall(function() return ref:name() end)
    local okMat, matName = pcall(function() return ref:materialName() end)
    if okName then paint.hoveredMesh = tostring(meshName) end
    if okMat then paint.hoveredMaterial = tostring(matName) end

    local uiState = ac.getUI and ac.getUI() or nil
    if uiState and uiState.shiftDown and uiState.isMouseLeftKeyClicked and not uiState.wantCaptureMouse then
      selectMaterialByName(paint.hoveredMaterial)
      pcall(function()
        paint.originalTexture = ref:getTextureSlotFilename("txDiffuse")
      end)
    end
  end
end

local function applyPaint(force)
  if paint.selectedMeshes == nil then
    if not autoSelectBody() then return false end
  end

  local h = hex()
  if not force and paint.lastHex == h then return true end

  createCanvas()

  local ok = false
  pcall(function()
    paint.selectedMeshes:setMaterialTexture("txDiffuse", paint.canvas):setMotionStencil(0)
    ok = true
  end)

  pcall(function() paint.selectedMeshes:setMaterialProperty("ksAmbient", 1.0) end)
  pcall(function() paint.selectedMeshes:setMaterialProperty("ksDiffuse", 1.0) end)
  pcall(function() paint.selectedMeshes:setMaterialProperty("ksSpecular", 0.20 + S.metallic * 1.20) end)
  pcall(function() paint.selectedMeshes:setMaterialProperty("ksSpecularEXP", 30 + S.sharpness * 230) end)
  pcall(function() paint.selectedMeshes:setMaterialProperty("fresnelMaxLevel", 0.25 + S.clearcoat * 1.20) end)

  if ok then
    paint.lastHex = h
    S.status = "Paint applied to " .. tostring(paint.selectedMaterial) .. " = " .. h
  else
    S.status = "Paint failed on selected material"
  end

  return ok
end

local function viewHome()
  header("Action Bar")

  cardStart(164)
  ui.textColored("QUICK ACTIONS", C.muted)
  ui.dummy(vec2(1, 4))

  if pill("Change Car Color", false, 260, 42) then S.view = "color" end
  ui.sameLine()
  if pill("Teleport Menu", false, 220, 42) then S.view = "teleport" end

  if pill("UI Settings", false, 260, 42) then S.view = "settings" end
  ui.sameLine()
  if pill("Close / Hide", false, 220, 42) then S.status = "Use AC app bar to hide this window" end

  ui.textColored("No fake buttons. Only linked sections.", C.dim)
  cardEnd()

  ui.textColored("Status: " .. S.status, C.muted)
  ui.textColored("Rights © DZST by Venom", C.dim)
end

local function rgbSlider(label, value)
  ui.text(label .. ": " .. tostring(value))
  ui.setNextItemWidth(ui.availableSpaceX())
  local changed, v = ui.slider("##" .. label, value, 0, 255, "%.0f")
  return changed, math.floor(v + 0.5)
end

local function pctSlider(label, value)
  ui.text(label .. ": " .. tostring(math.floor(value * 100 + 0.5)) .. "%")
  ui.setNextItemWidth(ui.availableSpaceX())
  local changed, v = ui.slider("##" .. label, value, 0, 1, "%.0f%%")
  return changed, clamp(v, 0, 1)
end

local function swatch(label, r, g, b)
  ui.pushStyleColor(ui.StyleColor.Button, rgbm(r / 255, g / 255, b / 255, 1))
  ui.pushStyleColor(ui.StyleColor.ButtonHovered, rgbm(r / 255, g / 255, b / 255, 0.86))
  ui.pushStyleColor(ui.StyleColor.ButtonActive, rgbm(r / 255, g / 255, b / 255, 0.70))
  local clicked = ui.button(label, vec2(42, 30))
  ui.popStyleColor(3)
  if clicked then
    S.r, S.g, S.b = r, g, b
    applyPaint(true)
  end
end

local function viewColor()
  updateHoverTarget()

  header("Pick New Color")
  if pill("← Back", false, 90, 32) then S.view = "home" end
  ui.sameLine()
  if pill("AUTO TARGET BODY", paint.selectedMeshes ~= nil, 180, 32) then autoSelectBody() end

  ui.textColored("Target: " .. tostring(paint.selectedMaterial), paint.selectedMeshes and C.green or C.red)
  ui.textColored("Hover body + SHIFT click to manually select material. Hovered: " .. tostring(paint.hoveredMaterial), C.muted)

  ui.dummy(vec2(1, 4))
  if pill("Body", S.selectedTab == "Body", 160, 34) then S.selectedTab = "Body" end
  ui.sameLine()
  if pill("Wheels", S.selectedTab == "Wheels", 160, 34) then S.status = "Wheels need separate material target" end
  ui.sameLine()
  if pill("Interior", S.selectedTab == "Interior", 160, 34) then S.status = "Interior needs separate material target" end

  if pill("ALL BODY", S.selectedPart == "ALL BODY", 120, 32) then S.selectedPart = "ALL BODY" end
  ui.sameLine()
  if pill("DOORS", S.selectedPart == "DOORS", 90, 32) then S.status = "Part masking not implemented yet" end
  ui.sameLine()
  if pill("FRONT", S.selectedPart == "FRONT", 90, 32) then S.status = "Part masking not implemented yet" end
  ui.sameLine()
  if pill("REAR", S.selectedPart == "REAR", 90, 32) then S.status = "Part masking not implemented yet" end

  ui.separator()

  local changed, v
  changed, v = rgbSlider("R", S.r); if changed then S.r = v; applyPaint(false) end
  changed, v = rgbSlider("G", S.g); if changed then S.g = v; applyPaint(false) end
  changed, v = rgbSlider("B", S.b); if changed then S.b = v; applyPaint(false) end

  ui.text("HEX: " .. hex())
  local pos = ui.getCursor()
  ui.drawRectFilled(vec2(pos.x, pos.y), vec2(pos.x + 220, pos.y + 72), rgb(), 14)
  ui.drawRect(vec2(pos.x, pos.y), vec2(pos.x + 220, pos.y + 72), C.line, 14, 0, 1)
  ui.dummy(vec2(224, 76))

  ui.textColored("Presets", C.muted)
  swatch("R", 255, 0, 0); ui.sameLine()
  swatch("O", 255, 120, 0); ui.sameLine()
  swatch("Y", 255, 230, 0); ui.sameLine()
  swatch("G", 0, 210, 65); ui.sameLine()
  swatch("C", 0, 210, 255); ui.sameLine()
  swatch("B", 0, 70, 255); ui.sameLine()
  swatch("P", 165, 0, 255); ui.sameLine()
  swatch("W", 255, 255, 255); ui.sameLine()
  swatch("K", 8, 8, 8)

  ui.separator()
  changed, v = pctSlider("Metallic", S.metallic); if changed then S.metallic = v; applyPaint(false) end
  changed, v = pctSlider("Sharpness", S.sharpness); if changed then S.sharpness = v; applyPaint(false) end
  changed, v = pctSlider("Clear Coat", S.clearcoat); if changed then S.clearcoat = v; applyPaint(false) end

  if pill("CONFIRM", true, 170, 38) then
    if applyPaint(true) and online() and ac and ac.sendChatMessage then
      pcall(ac.sendChatMessage, "/color " .. hex())
    end
  end

  ui.textColored("Status: " .. S.status, C.muted)
end

local function viewTeleport()
  header("Teleport Menu")
  if pill("← Back", false, 90, 32) then S.view = "home" end

  local changed, v = ui.inputText("##search", S.search, 256)
  if changed then S.search = v end
  ui.sameLine()
  ui.textColored("Search locations", C.dim)

  ui.separator()
  local g = ""
  for _, t in ipairs(teleports) do
    if contains(t.name, S.search) or contains(t.group, S.search) then
      if t.group ~= g then
        g = t.group
        ui.textColored(g, C.muted)
      end
      if pill(t.name .. "      ●", false, ui.availableSpaceX(), 36) then
        send("/tp " .. t.cmd, "Teleport needs server support: /tp " .. t.cmd)
      end
    end
  end
end

local function viewSettings()
  header("UI Settings")
  if pill("← Back", false, 90, 32) then S.view = "home" end
  ui.separator()
  ui.textColored("This is the clean version: no random fake action buttons.", C.muted)
  ui.textColored("Color requires CSP 0.1.77+ and a selected car material.", C.muted)
  ui.textColored("Rights © DZST by Venom", C.dim)
end

local function draw(dt)
  pushTheme()

  if S.view == "home" then viewHome()
  elseif S.view == "color" then viewColor()
  elseif S.view == "teleport" then viewTeleport()
  elseif S.view == "settings" then viewSettings()
  end

  if paint.selectedMeshes and paint.canvas then
    paint.refresh = paint.refresh + (dt or 0)
    if paint.refresh > 0.25 then
      paint.refresh = 0
      pcall(function()
        paint.selectedMeshes:setMaterialTexture("txDiffuse", paint.canvas):setMotionStencil(0)
      end)
    end
  end

  popTheme()
end

function windowMain(dt)
  draw(dt)
end

function script.windowMain(dt)
  draw(dt)
end
