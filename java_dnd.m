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
%   fake 'edit' as 'pushbutton' to enable DragOver (restore after Drop/Exit).
%  In DragOver, acceptDrag only if mouse over drop components and identify the
%   component by Position.
%  In Drop, get file names from MLDropTarget, also use a temporary keyFcn to
%   detect control and shift key during drop. Then fire dropFcn.

fh = ancestor(obj, 'figure');
FcnObj = getappdata(fh, 'uiFileDnD_FcnObj');
if ~isempty(FcnObj)
    ind = find([FcnObj{:,2}]==obj, 1, 'last');
    if isempty(ind), FcnObj(end+1,:) = {dropFcn obj};
    else, FcnObj{ind,1} = dropFcn;
    end
    setappdata(fh, 'uiFileDnD_FcnObj', FcnObj);
    return;
end

oldWarn = warning('off'); resetWarn = onCleanup(@()warning(oldWarn)); % JavaFrame
jFrame = handle(fh.JavaFrame.getAxisComponent, 'CallbackProperties'); %#ok

if ~exist('MLDropTarget', 'class'), javaaddpath(fileparts(mfilename('fullpath'))); end
dropTarget = handle(javaObjectEDT('MLDropTarget'), 'CallbackProperties');
set(dropTarget, 'Component', jFrame, 'DragEnterCallback', {@Callback fh jFrame}, ...
    'DragOverCallback', @Callback, 'DropCallback', @Callback, 'DragExitCallback', @Callback);
setappdata(fh, 'uiFileDnD_FcnObj', {dropFcn obj});

%% use signle callback to share data via persistent
function Callback(dropTarget, jEvent, varargin)
persistent R fh dispScale index FcnObj hEdit x y fSz
evt = jEvent.getClass.getName;
if nargin>2 % DragEnter: evt name is also DragEvent
    jEvent.rejectDrag();
    fh = varargin{1};
    fSz = getpixelposition(fh); fSz = fSz(3:4);
    dispScale = round([varargin{2}.getWidth varargin{2}.getHeight]./fSz*4)/4;
    hEdit = []; R = [];
    FcnObj = getappdata(fh, 'uiFileDnD_FcnObj');
    FcnObj = FcnObj(isvalid([FcnObj{:,2}]), :); % ignore invalid components
    for i = size(FcnObj,1):-1:1
        h = FcnObj{i,2};
        R(i,:) = getpixelposition(h, true);
        if R(i,4)==0, R(i,:) = getpixelposition(h.Parent, true); % axes' child
        elseif h.Type == "figure", R(i,1:2) = 1;
        elseif h.Type=="uicontrol" && h.Style=="edit" && h.Visible=="on"
            hEdit(end+1) = h; %#ok change back to 'edit' after Drop/Exit
            h.Style = 'pushbutton';
        end
    end
    R(:,3:4) = R(:,3:4) + R(:,1:2); % rect
    return;
elseif endsWith(evt, 'DragEvent') % DragOver
    try x = jEvent.getLocation.getX / dispScale(1); catch, return; end
    y = fSz(2) - jEvent.getLocation.getY / dispScale(2);
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
    dat.dropXY = round([x y]); % from DragOver
    dat.ctrlKey = contains('control', Modifier);
    dat.shiftKey = contains('shift', Modifier);

    dat.names = cellstr(char(dropTarget.getTransferData()));
    if strncmp(dat.names, 'file://', 7) % files identified as string
        dat.names = regexp(dat.names, '(?<=file://).*?(?=\r?\n)', 'match')';
    end

    args = [FcnObj(index,:) dat];
    if iscell(args{1}), args = [args{1}(1) args(2:3) args{1}(2:end)]; end
    feval(args{:});
end
set(hEdit, 'Style', 'edit'); % DragExit or Drop
