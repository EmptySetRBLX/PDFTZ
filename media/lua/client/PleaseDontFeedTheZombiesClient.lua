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