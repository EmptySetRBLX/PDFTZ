require "DebugUIs/DebugMenu/IsoRegions/IsoRegionsWindow"
require "ISUI/ISCollapsableWindow"

PDFTZDebugWindow = IsoRegionsWindow:derive("PDFTZDebugWindow")
function PDFTZDebugWindow:initialise()
    ISCollapsableWindow.initialise(self)
    self.title = "PDFTZ Debug"
end

function PDFTZDebugWindow.OnOpenPanel()
    if PDFTZDebugWindow.instance == nil then
        local ui = PDFTZDebugWindow:new(20, 20, 400, 400)
        ui:initialise()
        ui:instantiate()
        PDFTZDebugWindow.instance = ui
    end
    PDFTZDebugWindow.instance:addToUIManager()
end

function PDFTZDebugWindow:onMapRightMouseUp(x, y)
    self.panning = false
    if not self.mouseMoved then
        local playerNum = 0
        local cellX = self.renderer:uiToWorldX(x) / 300
        local cellY = self.renderer:uiToWorldY(y) / 300
        cellX = math.floor(cellX)
        cellY = math.floor(cellY)
        local context = ISContextMenu.get(playerNum, x + self:getAbsoluteX(), y + self:getAbsoluteY())
        --context:addOption("Clear Zombies", cellX, zpopClearZombies, cellY)
        --context:addOption("Spawn Time To Zero", cellX, zpopSpawnTimeToZero, cellY)
        --context:addOption("Spawn Now", cellX, zpopSpawnNow, cellY)
        local worldX = self.renderer:uiToWorldX(x)
        local worldY = self.renderer:uiToWorldY(y)
        context:addOption("Teleport Here", self.parent, IsoRegionsWindow.onTeleport, worldX, worldY)
    end
    return true
end

function PDFTZDebugWindow:createChildren()
    ISCollapsableWindow.createChildren(self)

    self.renderPanel = ISPanel:new(0, 0, self.width, self.height - self:titleBarHeight() - self:resizeWidgetHeight())
    self.renderPanel.render = PDFTZDebugWindow.renderTex
    self.renderPanel:initialise()
    --	self.renderPanel:instantiate()
    self.renderPanel.onMouseDown = PDFTZDebugWindow.onMapMouseDown
    self.renderPanel.onMouseUp = PDFTZDebugWindow.onMapMouseUp
    self.renderPanel.onMouseUpOutside = PDFTZDebugWindow.onMapMouseUpOutside
    self.renderPanel.onMouseMove = PDFTZDebugWindow.onMapMouseMove
    self.renderPanel.onRightMouseDown = PDFTZDebugWindow.onMapRightMouseDown
    self.renderPanel.onRightMouseUp = PDFTZDebugWindow.onMapRightMouseUp
    self.renderPanel.onRightMouseUpOutside = PDFTZDebugWindow.onMapRightMouseUpOutside
    self.renderPanel.onMouseWheel = PDFTZDebugWindow.onRenderMouseWheel
    self.renderPanel:setAnchorRight(true)
    self.renderPanel:setAnchorBottom(true)
    self.renderPanel.parent = self
    self.renderPanel.renderer = isoRegionsRenderer()
    self.renderPanel.renderer:load()
    self:addView(self.renderPanel)
end

function PDFTZDebugWindow:renderTex()
    self.renderer:render(self.javaObject, self.parent.zoom, self.parent.xpos, self.parent.ypos)
end