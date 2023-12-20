local commands = {}

function commands.DeleteBody(args)
    IsoDeadBody.removeDeadBody(args.id)
end

function onServerCommand(module, command, args)
    if module == "PDFTZ" then
        commands[command](args)
    end
end

Events.OnServerCommand.Add(onServerCommand)

local oldRemoveCorpse = __classmetatables[IsoGridSquare.class]["__index"].removeCorpse

__classmetatables[IsoGridSquare.class]["__index"].removeCorpse = function(self, body, dontReplicate)
    if not dontReplicate then
        local id = body:getObjectID()
        print("Sending client command")
        sendClientCommand("PDFTZ", "PickupBodyId", {id = id})
    end

    return oldRemoveCorpse(self, body, dontReplicate)
end

local oldRemove = __classmetatables[ItemContainer.class]["__index"].Remove

__classmetatables[ItemContainer.class]["__index"].Remove = function(self, inventoryItem)

    if istype(inventoryItem, "InventoryItem") and inventoryItem:getName() == "Corpse" and self:getParent() ~= nil and self:getParent():getSquare() ~= nil then
        local parentObject = self:getParent()
        local square = parentObject:getSquare()
        local x = square:getX()
        local y = square:getY()
        local z = square:getZ()
        print("Sending client command")
        sendClientCommand("PDFTZ", "PlaceDeadBody", {
            x = x,
            y = y,
            z = z
        })
    end

    return oldRemove(self, inventoryItem)
end