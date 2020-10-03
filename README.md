# Drag and Drop OS file/folder(s) into uifigure

This single file implementation can set up a callback when file/folder is dropped onto a uifigure component. 

In the callback, full file and/or folder names are captured for user to decide the action. Ctrl and Shift key status during the drop event are also reported.

Example to drop file/folder into uilistbox:
    
    DnD_uifigure(uilistbox(uifigure), @(~,dat)disp(dat))
