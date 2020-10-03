function DnD_uifigure(target, dropFcn)
% Set up a callback when file/folder is dropped onto a uifigure component.
% 
% The target component can be uifigure itself or any uifigure component.
% 
% dropFcn is the callback function when a file is dropped. Its syntax is the
% same as general Matlab callback, like @myFunc or {@myFunc myOtherInput}.
% In the dropFcn callback, the 2nd argument is the data with fields:
%       event: 'drop'
%       names: {'/myPath/myFile'} % cellstr for full file/folder names
%     ctrlKey: 0 % true if Ctrl key is down while dropping
%    shiftKey: 0 % true if Shift key is down while dropping
% 
% Example to drop file/folder into uilistbox:
%  DnD_uifigure(uilistbox(uifigure), @(~,dat)disp(dat))

% 201001 Wrote it by Xiangrui.Li at gmail.com 

narginchk(2, 2);
if isempty(target), target = uifigure; end

fh = ancestor(target, 'figure');
h = uihtml(fh, 'Position', [1 1 0 0], 'HandleVisibility', 'callback', ...
    'DataChangedFcn', {@DnD_callback dropFcn}, 'HTMLSource', sprintf([ ...
    '<div class="drop-zone"></div>\n' ...
    '<script type="text/javascript">\n' ...
    '    function setup(htmlComponent) {\n' ...
    '        document.ondragover = (e) => {\n' ...
    '            var b = htmlComponent.Data.dropZone \n' ...
    '            e.preventDefault(); e.stopPropagation()\n' ...
    '            if(e.clientX<b[0] || e.clientX>b[2] || e.clientY<b[1] || e.clientY>b[3])\n' ...
    '                e.dataTransfer.dropEffect = "none"\n' ...
    '        }\n' ...
    '        document.body.ondrop = (e) => {\n' ...
    '            e.preventDefault()\n' ...
    '            htmlComponent.Data = {\n' ...
    '              "event": "drop", "names": htmlComponent.Data.names,\n' ...
    '              "ctrlKey": e.ctrlKey, "shiftKey": e.shiftKey} \n' ...
    '        }\n' ...
    '        document.ondragleave = (e) => {htmlComponent.Data = {"event": "dragleave"}}\n' ...
    '    }\n' ...
    '</script>\n']));

nam = fh.Name;
fh.Name = char(randi(9,1,4)+128); % rename to no-show name
drawnow; ww = matlab.internal.webwindowmanager.instance.windowList;
ww = ww(strcmp(fh.Name, {ww.Title}));
fh.Name = nam; % restore name
ww.enableDragAndDropAll; % enable DnD to whole uifigure
ww.FileDragDropCallback = {@dragEnter target h};

%% fired when drag enters uifigure
function dragEnter(~, evt, target, h)
hs = allchild(h.Parent);
if h ~= hs(1), h.Parent.Children = [h; hs(h~=hs)]; end % make uihtml topmost
h.Position(3:4) = h.Parent.Position(3:4); % enable JS call in uihtml
p = getpixelposition(target, 1);
if target.Type == "figure", p(1:2) = 1; end
p(2) = h.Position(4) - p(4) - p(2) + 2; % from top
p(3:4) = p(1:2) + p(3:4) - 1; % right-bottom
h.Data.dropZone = p - 1; % JS ondragover uses this to deny drop outside rect
h.Data.names = cellstr(evt); % JS ondrop uses this for full name(s)

%% fired by javascript Data change in ondrop and ondragleave
function DnD_callback(h, e, dropFcn)
h.Position(3:4) = 0; % other components in uifigure will work properly
if e.Data.event == "dragleave", return; end % DnD revoked
if iscell(dropFcn), feval(dropFcn{1}, h, e.Data, dropFcn{2:end});
else, feval(dropFcn, h, e.Data);
end
%%
