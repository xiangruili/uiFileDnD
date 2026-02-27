function java_dnd(obj, dropFcn)
% Set Matlab dropFcn for a figure or its object. Called by uiFileDnD.m.

% 170421 Xiangrui Li adapted from dndcontrol class by Maarten van der Seijs:
%   https://www.mathworks.com/matlabcentral/fileexchange/53511
% 260209 use fh.WindowKeyPressFcn to catch ctrlKey/shiftKey
% 260225 adopt similar approach to uiFileDnD.m, so work for axes
% 260227 also work for uicontrol Style=edit

% Required: MLDropTarget.class on javapath or under the same folder
% Tricks to make this work:
%  Set figure jFrame as Component for MLDropTarget, so the figure accepts drop.
%  Store drop-accepting object and dropFcn into figure appdata.
%  In DragEnter, get obj position (take care of java cords scale issue), also
%   fake 'edit' as 'pushbutton' to enable DragOver.
%  In DragOver, acceptDrag only if mouse over drop components and store the
%   component index by Positio. Slow down DragOver to avoid Matlab crash.
%  In Drop, get file names from MLDropTarget, also use a temporary keyFcn to
%   detect control and shift key during drop. Then fire dropFcn.

fh = ancestor(obj, 'figure');
FncObj = getappdata(fh, 'uiFileDnD_FncObj');
if ~isempty(FncObj)
    ind = find([FncObj{:,2}]==obj, 1, 'last');
    if isempty(ind), FncObj(end+1,:) = {dropFcn obj};
    else, FncObj{ind,1} = dropFcn;
    end
    setappdata(fh, 'uiFileDnD_FncObj', FncObj);
    return;
end

oldWarn = warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
warning('off','MATLAB:ui:javaframe:PropertyToBeRemoved');
resetWarn = onCleanup(@()warning(oldWarn));
jFrame = handle(fh.JavaFrame.getAxisComponent, 'CallbackProperties'); %#ok

if ~exist('MLDropTarget', 'class'), javaaddpath(fileparts(mfilename('fullpath'))); end
dropTarget = handle(javaObjectEDT('MLDropTarget'), 'CallbackProperties');
set(dropTarget, 'Component', jFrame, 'DragEnterCallback', {@Callback fh jFrame}, ...
    'DragOverCallback', @Callback, 'DropCallback', @Callback, 'DragExitCallback', @Callback);
setappdata(fh, 'uiFileDnD_FncObj', {dropFcn obj});

%% use signle callback to share data via persistent
function Callback(dropTarget, jEvent, varargin)
persistent R fh dispScale lastOver index FncObj hEdit
evt = jEvent.getClass.getName;
if nargin>2 % DragEnter: evt same as DragOver
    fh = varargin{1};
    pos = getpixelposition(fh);
    dispScale = round([varargin{2}.getWidth varargin{2}.getHeight]./pos(3:4)*4)/4;
    hEdit = []; R = [];
    FncObj = getappdata(fh, 'uiFileDnD_FncObj');
    FncObj = FncObj(isvalid([FncObj{:,2}]), :); % ignore invalid components
    for i = size(FncObj,1):-1:1
        h = FncObj{i,2};
        R(i,:) = getpixelposition(h, true);
        if all(R(i,:)==0), R(i,:) = getpixelposition(h.Parent, true);
        elseif h.Type == "figure", R(i,1:2) = 1;
        elseif h.Type=="uicontrol" && h.Style=="edit" && h.Visible=="on"
            hEdit(end+1) = h; %#ok change back to 'edit' after Drop/Exit
            h.Style = 'pushbutton';
        end
    end
    R(:,2) = pos(4) - R(:,2) - R(:,4); % from top for java coords
    R(:,3:4) = R(:,3:4) + R(:,1:2); % rect
    return;
elseif endsWith(evt, 'DragEvent') % DragOver
    if isempty(lastOver), lastOver = datetime; end
    if datetime-lastOver<seconds(0.02), return; end
    lastOver = datetime;
    x = jEvent.getLocation.getX / dispScale(1);
    y = jEvent.getLocation.getY / dispScale(2);
    index = find(x>R(:,1) & x<R(:,3) & y>R(:,2) & y<R(:,4), 1, "last");
    if isempty(index), jEvent.rejectDrag(); % reject if outside obj
    else, jEvent.acceptDrag(3) % ACTION_COPY_OR_MOVE
    end
    return;
elseif endsWith(evt, 'DropEvent') % Drop
    keyFcn = fh.WindowKeyPressFcn;
    resetFcn = onCleanup(@()set(fh,'WindowKeyPressFcn',keyFcn));
    fh.WindowKeyPressFcn = @(o,e)assignin('caller','Modifier',e.Modifier);
    figure(fh); drawnow;
    bot = java.awt.Robot();
    k = java.awt.event.KeyEvent.VK_CAPS_LOCK; % no harm key
    bot.keyPress(k); bot.keyRelease(k); bot.keyPress(k); pause(0.05); bot.keyRelease(k);
    if ~exist('Modifier', 'var'), Modifier = {}; end % in case Robot() fails
    dat.ctrlKey = contains('control', Modifier);
    dat.shiftKey = contains('shift', Modifier);

    dat.names = cellstr(char(dropTarget.getTransferData()));
    if strncmp(dat.names, 'file://', 7) % files identified as string
        dat.names = regexp(dat.names, '(?<=file://).*?(?=\r?\n)', 'match')';
    end

    args = [FncObj(index,:) dat];
    if iscell(args{1}), args = [args{1}(1) args(2:3) args{1}(2:end)]; end
    feval(args{:});
end
set(hEdit, 'Style', 'edit'); % DragExit or Drop
