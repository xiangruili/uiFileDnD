function java_dnd(target, dropFcn)
% Set Matlab dropFcn for a figure object. Called by uiFileDnD.m.

% 170421 Xiangrui Li adapted from dndcontrol class by Maarten van der Seijs:
%   https://www.mathworks.com/matlabcentral/fileexchange/53511
% 260201 include findjobj_fast(), so input is figure component
% 260209 use fh.WindowKeyPressFcn to catch ctrlKey/shiftKey
% 260225 adopt similar approach to uiFileDnD.m: findjobj not needed

% Required: MLDropTarget.class on javapath or under the same folder

fh = ancestor(target, 'figure');
targets = getappdata(fh, 'uiFileDnD_target');
if ~isempty(targets)
    targets(end+1,:) = {dropFcn target};
    setappdata(fh, 'uiFileDnD_target', targets);
    return;
end

if ~exist('MLDropTarget', 'class')
    pth = fileparts(mfilename('fullpath'));
    javaaddpath(pth); % dynamic for this session
    fid = fopen(fullfile(prefdir, 'javaclasspath.txt'), 'a+');
    if fid>0 % static path for later sessions: work for 2013+?
        autoClose = onCleanup(@() fclose(fid));
        fseek(fid, 0, 'bof');
        classpth = fread(fid, inf, '*char')';
        if isempty(strfind(classpth, pth)) %#ok<*STREMP> % avoid multiple write
            fseek(fid, 0, 'bof');
            fprintf(fid, '%s\n', pth);
        end
    end
end

dropTarget = handle(javaObjectEDT('MLDropTarget'), 'CallbackProperties');
set(dropTarget, 'DragOverCallback', {@DragOverCallback fh});
set(dropTarget, 'DropCallback', {@DropCallback fh});

oldWarn = warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
warning('off','MATLAB:ui:javaframe:PropertyToBeRemoved');
resetWarn = onCleanup(@()warning(oldWarn));
jObj = handle(fh.JavaFrame.getAxisComponent, 'CallbackProperties'); %#ok
jObj.setDropTarget(dropTarget);
setappdata(fh, 'uiFileDnD_target', {dropFcn target});

% java dimension does not take care of display scale
sz = getpixelposition(fh);
dispScale = [jObj.getWidth jObj.getHeight] ./ sz(3:4);
setappdata(fh, 'uiFileDnD_dispScale', round(dispScale*4)/4);
%%

function DragOverCallback(~, jEvent, fh)
persistent lastOver
if isempty(lastOver), lastOver = datetime; end
if datetime-lastOver<seconds(0.02), return; end
lastOver = datetime;
dispScale = getappdata(fh, 'uiFileDnD_dispScale');
x = jEvent.getLocation.getX/dispScale(1);
y = fh.Position(4) - jEvent.getLocation.getY/dispScale(2);
targets = getappdata(fh, 'uiFileDnD_target');
for i = size(targets,1):-1:1
    p = getpixelposition(targets{i,2}, true);
    if all(p==0), p = getpixelposition(targets{i,2}.Parent, true);
    elseif targets{i,2}.Type == "figure", p(1:2) = 1;
    end
    if x>p(1) && x<p(1)+p(3) && y>p(2) && y<p(2)+p(4)
        jEvent.acceptDrag(java.awt.dnd.DnDConstants.ACTION_COPY_OR_MOVE);
        setappdata(fh, 'uiFileDnD_index', i);
        return;
    end
end
jEvent.rejectDrag();
%%

function DropCallback(jSource, ~, fh)
% Try to detect control and shift key during drop 
keyFcn = fh.WindowKeyPressFcn;
resetFcn = onCleanup(@()set(fh,'WindowKeyPressFcn',keyFcn));
fh.WindowKeyPressFcn = @(o,e)setappdata(o,'uiFileDnD_Modifier',e.Modifier);
figure(fh); drawnow;
bot = java.awt.Robot();
k = java.awt.event.KeyEvent.VK_CAPS_LOCK; % no harm key
bot.keyPress(k); bot.keyRelease(k); bot.keyPress(k); pause(0.05); bot.keyRelease(k);
Modifier = getappdata(fh, 'uiFileDnD_Modifier');
if ~iscell(Modifier), Modifier = {}; end % in case Robot() fails
evt.ctrlKey = contains('control', Modifier);
evt.shiftKey = contains('shift', Modifier);

evt.names = cellstr(char(jSource.getTransferData()));
if strncmp(evt.names, 'file://', 7) % files identified as string
    evt.names = regexp(evt.names, '(?<=file://).*?(?=\r?\n)', 'match')';
end

targets = getappdata(fh, 'uiFileDnD_target');
args = [targets(getappdata(fh,'uiFileDnD_index'),:) evt];
if iscell(args{1}), args = [args{1}(1) args(2:3) args{1}(2:end)]; end
feval(args{:});

%%
