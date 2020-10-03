# Drag and Drop OS file/folder(s) into uifigure

This single file implementation can set up a callback fired when files and/or folders are dropped onto a uifigure component. 

In the callback, full file/folder names are captured for user to decide the action. Ctrl and Shift key status during the drop event are also reported.

Example to drop file/folder into uilistbox:
    
    DnD_uifigure(uilistbox(uifigure), @(~,dat)disp(dat))
