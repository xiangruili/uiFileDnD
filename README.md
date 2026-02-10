# Drag and Drop OS file/folder(s) into Matlab figure/uifigure (2026.02.09)
[![View uiFileDnD on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://www.mathworks.com/matlabcentral/fileexchange/80656-uifilednd)

The uiFileDnD implementation allows to set up a callback fired when files and/or folders are dropped onto a (ui)figure component. 

In the callback, full file/folder names are captured for user to decide the action. Ctrl and Shift key status during the drop event are also reported.

Example to drop file/folder onto uilistbox of uifigure:
    
    target = uilistbox(uifigure, 'Position', [80 100 400 100]);
    uiFileDnD(target, @(o,dat)set(o,'Items',dat.names));

Example to drop file/folder onto listbox of figure:
    
    target = uicontrol(figure, 'Style', 'listbox', 'Position', [80 100 400 100]);
    uiFileDnD(target, @(o,dat)set(o,'String',dat.names));

Note: 
 1. File DnD onto uifigure works only for Matlab R2020b or later.
 2. File DnD works for uifigure and figure since R2025a.
 3. File DnD works for uifigure under Linux since R2025a.
 4. Since R2025a, the following line needs to be added into startup.m file:

    try addprop(groot, 'ForceIndependentlyHostedFigures'); catch, end

 5. java_dnd.m & MLDropTarget.class are for Matlab figure before R2025a, and will be removed in the future.
