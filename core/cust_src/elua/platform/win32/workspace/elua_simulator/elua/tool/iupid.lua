function iup_id(func)
    return function(o)
        if o.id ~= nil then
            _G[o.id] = func(o)
            return _G[o.id]
        elseif o.ID ~= nil then
            _G[o.ID] = func(o)
            return _G[o.ID]
        else
            return func(o)
        end
    end
end

--standard
iup.button = iup_id(iup.button)
iup.canvas = iup_id(iup.canvas)
iup.frame = iup_id(iup.frame)
iup.multiline = iup_id(iup.multiline)
iup.progressbar = iup_id(iup.progressbar)
iup.spin = iup_id(iup.spin)
iup.tabs = iup_id(iup.tabs)
iup.val = iup_id(iup.val)
iup.toggle = iup_id(iup.toggle)
iup.radio = iup_id(iup.radio)
iup.text = iup_id(iup.text)
iup.list = iup_id(iup.list)
iup.label = iup_id(iup.label)
--dialog
iup.dialog = iup_id(iup.dialog)
iup.filedlg = iup_id(iup.filedlg)
iup.messagedlg = iup_id(iup.messagedlg)
iup.colordlg = iup_id(iup.colordlg)
iup.fontdlg = iup_id(iup.fontdlg)
iup.alarm = iup_id(iup.alarm)
iup.getfile = iup_id(iup.getfile)
iup.gettext = iup_id(iup.gettext)
iup.listdialog = iup_id(iup.listdialog)
iup.message = iup_id(iup.message)
iup.scanf = iup_id(iup.scanf)
iup.getcolor = iup_id(iup.getcolor)
iup.getparam = iup_id(iup.getparam)
--layout
iup.fill = iup_id(iup.fill)
iup.vbox = iup_id(iup.vbox)
iup.hbox = iup_id(iup.hbox)
iup.zbox = iup_id(iup.zbox)
iup.cbox = iup_id(iup.cbox)
iup.sbox = iup_id(iup.cbox)
--additional
iup.cells = iup_id(iup.cells)
iup.colorbar = iup_id(iup.colorbar)
iup.colorbrowser = iup_id(iup.colorbrowser)
iup.dial = iup_id(iup.dial)
iup.gauge = iup_id(iup.gauge)
iup.tabs = iup_id(iup.tabs)
iup.matrix = iup_id(iup.matrix)
iup.tree = iup_id(iup.tree)
iup.glcanvas = iup_id(iup.glcanvas)
iup.pplot = iup_id(iup.pplot)
iup.olecontrol = iup_id(iup.olecontrol)
iup.speech = iup_id(iup.speech)
