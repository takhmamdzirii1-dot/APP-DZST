-- DZST by Venom
-- CSP Lua app with clean sections: Home, Change Car Color, Teleport Menu, Settings.

local app = {
  view = 'home',
  status = 'Ready',
  search = '',
  color = { r = 255, g = 0, b = 0, metallic = 0.45, sharpness = 0.55, clearcoat = 0.50 }
}

local paint = {
  carRoot = nil,
  selectedMeshes = nil,
  selectedMaterial = 'none',
  hoveredMaterial = 'none',
  canvas = nil,
  lastHex = '',
  refresh = 0
}

local bodyMaterialCandidates = {
  'ext_Body_Paint',
  'EXT_Body_Paint',
  'Body_Paint',
  'carpaint',
  'CarPaint'
}

local teleports = {
  { group = 'Shibaura PA', name = 'Position 1', cmd = 'pos1' },
  { group = 'Shibaura PA', name = 'Position 2', cmd = 'pos2' },
  { group = 'Daishi PA', name = 'Position 1', cmd = 'daishi1' },
  { group = 'Tatsumi PA', name = 'Main Spot', cmd = 'tatsumi' }
}

local C = {
  bg = rgbm(0.05, 0.06, 0.08, 0.96),
  panel = rgbm(0.10, 0.12, 0.16, 0.96),
  panel2 = rgbm(0.14, 0.16, 0.21, 0.98),
  line = rgbm(1, 1, 1, 0.08),
  text = rgbm(0.95, 0.97, 1, 1),
  muted = rgbm(0.67, 0.71, 0.79, 1),
  accent = rgbm(0.64, 0.24, 1.00, 1),
  accent2 = rgbm(0.51, 0.18, 0.86, 1),
  ok = rgbm(0.35, 0.95, 0.45, 1),
  bad = rgbm(1.00, 0.35, 0.35, 1)
}

local function clamp(v, mn, mx) return math.max(mn, math.min(mx, v)) end
local function online() local s = ac.getSim and ac.getSim() or nil return s and s.isOnlineRace == true end
local function hex() return string.format('#%02X%02X%02X', app.color.r, app.color.g, app.color.b) end
local function rgb() return rgbm(app.color.r / 255, app.color.g / 255, app.color.b / 255, 1) end
local function contains(a, b)
  a, b = string.lower(tostring(a or '')), string.lower(tostring(b or ''))
  return b == '' or string.find(a, b, 1, true) ~= nil
end

local function setStatus(msg, isError)
  app.status = (isError and 'Error: ' or 'Status: ') .. msg
end

local function pushTheme()
  ui.pushStyleVar(ui.StyleVar.WindowRounding, 16)
  ui.pushStyleVar(ui.StyleVar.FrameRounding, 12)
  ui.pushStyleVar(ui.StyleVar.ScrollbarRounding, 12)
  ui.pushStyleVar(ui.StyleVar.WindowPadding, vec2(14, 14))
  ui.pushStyleVar(ui.StyleVar.ItemSpacing, vec2(10, 9))
  ui.pushStyleColor(ui.StyleColor.WindowBg, C.bg)
  ui.pushStyleColor(ui.StyleColor.Text, C.text)
  ui.pushStyleColor(ui.StyleColor.Button, C.panel2)
  ui.pushStyleColor(ui.StyleColor.ButtonHovered, rgbm(1, 1, 1, 0.08))
  ui.pushStyleColor(ui.StyleColor.ButtonActive, rgbm(1, 1, 1, 0.13))
  ui.pushStyleColor(ui.StyleColor.FrameBg, C.panel2)
  ui.pushStyleColor(ui.StyleColor.FrameBgHovered, rgbm(1, 1, 1, 0.08))
  ui.pushStyleColor(ui.StyleColor.FrameBgActive, rgbm(1, 1, 1, 0.13))
  ui.pushStyleColor(ui.StyleColor.SliderGrab, C.accent)
  ui.pushStyleColor(ui.StyleColor.SliderGrabActive, C.accent2)
end

local function popTheme() ui.popStyleColor(10) ui.popStyleVar(5) end

local function pill(label, active, w, h)
  ui.pushStyleColor(ui.StyleColor.Button, active and C.accent or C.panel2)
  ui.pushStyleColor(ui.StyleColor.ButtonHovered, active and C.accent or rgbm(1, 1, 1, 0.08))
  ui.pushStyleColor(ui.StyleColor.ButtonActive, active and C.accent2 or rgbm(1, 1, 1, 0.13))
  local c = ui.button(label, vec2(w or 140, h or 34))
  ui.popStyleColor(3)
  return c
end

local function sectionHeader(title)
  ui.textColored('DZST by Venom', C.text)
  ui.sameLine()
  ui.textColored(online() and 'ONLINE' or 'OFFLINE', online() and C.ok or C.muted)
  ui.separator()
  ui.textColored(title, C.text)
end

local function getCarRoot()
  if paint.carRoot then return true end
  if not ac.findNodes then setStatus('CSP API missing ac.findNodes.', true) return false end
  local ok, node = pcall(ac.findNodes, 'carRoot:0')
  if not ok or not node then setStatus('Could not find carRoot:0.', true) return false end
  paint.carRoot = node
  return true
end

local function selectMaterial(material)
  if not getCarRoot() then return false end
  local ok, meshes = pcall(function() return paint.carRoot:findMeshes('{ material:' .. material .. ' & lod:A }') end)
  if ok and meshes then
    paint.selectedMeshes = meshes
    paint.selectedMaterial = material
    setStatus('Selected material: ' .. material, false)
    return true
  end
  return false
end

local function autoSelectBody()
  if selectMaterial('ext_Body_Paint') then return true end
  for _, mat in ipairs(bodyMaterialCandidates) do if selectMaterial(mat) then return true end end
  setStatus('Body material not found. Use SHIFT + click on car body.', true)
  return false
end

local function buildCanvas()
  if not paint.canvas then paint.canvas = ui.ExtraCanvas(vec2(2048, 2048)) end
  local c = rgb()
  paint.canvas:clear(c)
  paint.canvas:update(function() ui.drawRectFilled(vec2(0, 0), vec2(2048, 2048), c) end)
  return paint.canvas
end

local function applyPaint(force)
  if not paint.selectedMeshes and not autoSelectBody() then
    setStatus('Paint cancelled: no selected body meshes.', true)
    return false
  end
  local h = hex()
  if not force and paint.lastHex == h then return true end
  local canvas = buildCanvas()
  local ok = false
  pcall(function()
    paint.selectedMeshes:setMaterialTexture('txDiffuse', canvas)
    paint.selectedMeshes:setMotionStencil(0)
    ok = true
  end)
  if not ok then
    setStatus('Failed setting txDiffuse on selected meshes.', true)
    return false
  end
  pcall(function() paint.selectedMeshes:setMaterialProperty('ksAmbient', 1.0) end)
  pcall(function() paint.selectedMeshes:setMaterialProperty('ksDiffuse', 1.0) end)
  pcall(function() paint.selectedMeshes:setMaterialProperty('ksSpecular', 0.20 + app.color.metallic * 1.20) end)
  pcall(function() paint.selectedMeshes:setMaterialProperty('ksSpecularEXP', 30 + app.color.sharpness * 220) end)
  pcall(function() paint.selectedMeshes:setMaterialProperty('fresnelMaxLevel', 0.25 + app.color.clearcoat * 1.20) end)
  paint.lastHex = h
  setStatus('Paint applied on ' .. tostring(paint.selectedMaterial) .. ' = ' .. h, false)
  return true
end

local function updateHoverSelect()
  if not getCarRoot() or not render.createMouseRay or not ac.emptySceneReference then return end
  local sim = ac.getSim and ac.getSim() or nil
  if not sim or not sim.isWindowForeground then return end
  local ray, ref = render.createMouseRay(), ac.emptySceneReference()
  local hit = false
  pcall(function() hit = paint.carRoot:findMeshes('{ ! material:DAMAGE_GLASS & lod:A }'):raycast(ray, ref) ~= -1 end)
  if not hit then return end
  local okMat, mat = pcall(function() return ref:materialName() end)
  if okMat then paint.hoveredMaterial = tostring(mat) end
  local uiState = ac.getUI and ac.getUI() or nil
  if uiState and uiState.shiftDown and uiState.isMouseLeftKeyClicked and not uiState.wantCaptureMouse then
    if selectMaterial(paint.hoveredMaterial) then
      setStatus('Picked by SHIFT + click: ' .. tostring(paint.hoveredMaterial), false)
    else
      setStatus('SHIFT + click failed: material could not be selected.', true)
    end
  end
end

local function colorSlider(label, value)
  ui.text(label .. ': ' .. tostring(value))
  ui.setNextItemWidth(ui.availableSpaceX())
  local changed, v = ui.slider('##' .. label, value, 0, 255, '%.0f')
  return changed, math.floor(v + 0.5)
end

local function viewHome()
  sectionHeader('Home')
  if pill('Change Car Color', app.view == 'color', ui.availableSpaceX(), 40) then app.view = 'color' end
  if pill('Teleport Menu', app.view == 'teleport', ui.availableSpaceX(), 40) then app.view = 'teleport' end
  if pill('Settings', app.view == 'settings', ui.availableSpaceX(), 40) then app.view = 'settings' end
  ui.separator()
  ui.textColored(app.status, C.muted)
end

local function viewColor()
  updateHoverSelect()
  sectionHeader('Change Car Color')
  if pill('← Home', false, 100, 32) then app.view = 'home' end
  ui.sameLine()
  if pill('Auto Select Body', false, 170, 32) then autoSelectBody() end
  ui.textColored('Target: ' .. tostring(paint.selectedMaterial), paint.selectedMeshes and C.ok or C.bad)
  ui.textColored('Tip: Hold SHIFT and click body material in 3D view. Hover: ' .. tostring(paint.hoveredMaterial), C.muted)
  ui.separator()

  local changed, v
  changed, v = colorSlider('R', app.color.r); if changed then app.color.r = v; applyPaint(false) end
  changed, v = colorSlider('G', app.color.g); if changed then app.color.g = v; applyPaint(false) end
  changed, v = colorSlider('B', app.color.b); if changed then app.color.b = v; applyPaint(false) end

  ui.text('HEX: ' .. hex())
  local p = ui.getCursor()
  ui.drawRectFilled(vec2(p.x, p.y), vec2(p.x + ui.availableSpaceX(), p.y + 48), rgb(), 12)
  ui.drawRect(vec2(p.x, p.y), vec2(p.x + ui.availableSpaceX(), p.y + 48), C.line, 12, 0, 1)
  ui.dummy(vec2(1, 54))

  ui.text('Metallic'); ui.setNextItemWidth(ui.availableSpaceX()); changed, v = ui.slider('##metal', app.color.metallic, 0, 1, '%.0f%%'); if changed then app.color.metallic = clamp(v,0,1); applyPaint(false) end
  ui.text('Sharpness'); ui.setNextItemWidth(ui.availableSpaceX()); changed, v = ui.slider('##sharp', app.color.sharpness, 0, 1, '%.0f%%'); if changed then app.color.sharpness = clamp(v,0,1); applyPaint(false) end
  ui.text('Clearcoat'); ui.setNextItemWidth(ui.availableSpaceX()); changed, v = ui.slider('##coat', app.color.clearcoat, 0, 1, '%.0f%%'); if changed then app.color.clearcoat = clamp(v,0,1); applyPaint(false) end

  if pill('Apply Color', true, ui.availableSpaceX(), 36) then applyPaint(true) end
  ui.textColored(app.status, C.muted)
end

local function viewTeleport()
  sectionHeader('Teleport Menu')
  if pill('← Home', false, 100, 32) then app.view = 'home' end
  local changed, text = ui.inputText('##search', app.search, 128)
  if changed then app.search = text end
  ui.sameLine(); ui.textColored('Search', C.muted)
  ui.separator()

  local group = ''
  for _, t in ipairs(teleports) do
    if contains(t.group, app.search) or contains(t.name, app.search) then
      if group ~= t.group then group = t.group; ui.textColored(group, C.muted) end
      if pill(t.name, false, ui.availableSpaceX(), 34) then
        if online() and ac.sendChatMessage then
          ac.sendChatMessage('/tp ' .. t.cmd)
          setStatus('Sent teleport: /tp ' .. t.cmd, false)
        else
          setStatus('Teleport requires online server command support.', true)
        end
      end
    end
  end
end

local function viewSettings()
  sectionHeader('Settings')
  if pill('← Home', false, 100, 32) then app.view = 'home' end
  ui.separator()
  ui.textColored('DZST by Venom', C.text)
  ui.textColored('CSP Paintshop-style body paint editing enabled.', C.muted)
  ui.textColored('Manifest-compatible single-window CSP Lua app.', C.muted)
  ui.textColored(app.status, C.muted)
end

local function draw(dt)
  pushTheme()
  if app.view == 'home' then viewHome()
  elseif app.view == 'color' then viewColor()
  elseif app.view == 'teleport' then viewTeleport()
  else viewSettings() end

  if paint.selectedMeshes and paint.canvas then
    paint.refresh = paint.refresh + (dt or 0)
    if paint.refresh > 0.25 then
      paint.refresh = 0
      pcall(function() paint.selectedMeshes:setMaterialTexture('txDiffuse', paint.canvas):setMotionStencil(0) end)
    end
  end
  popTheme()
end

function windowMain(dt) draw(dt) end
function script.windowMain(dt) draw(dt) end
