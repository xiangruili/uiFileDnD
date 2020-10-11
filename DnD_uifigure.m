function DnD_uifigure(target, dropFcn)
% Set up a callback when file/folder is dropped onto a uifigure component.
% 
% The target can be a uifigure or any uifigure component.
% 
% dropFcn is the callback function when a file is dropped. Its syntax is the
% same as general Matlab callback, like @myFunc or {@myFunc myOtherInput}.
% In the callback, the first argument is the target, and 2nd the data containing
%       names: {'/myPath/myFile'} % cellstr for full file/folder names
%     ctrlKey: 0 % true if Ctrl key is down while dropping
%    shiftKey: 0 % true if Shift key is down while dropping
% 
% Example to drop file/folder into uilistbox:
%  target = uilistbox(uifigure, 'Position', [80 100 400 100]);
%  DnD_uifigure(target, @(o,dat)set(o,'Items',dat.names));

% 201001 Wrote it, by Xiangrui.Li at gmail.com 
% 201004 Allow to add more target repeatedly

narginchk(2, 2);
if isempty(target), target = uifigure; end
if numel(target)>1 || ~ishandle(target)
    error('DnD_uifigure:badInput', 'target must be a single uifigure component');
end

fh = ancestor(target, 'figure');
h = findall(fh, 'Type', 'uihtml', 'Tag', 'uiFileDnD');
if ~isempty(h)
    h.UserData{end+1} = {target dropFcn};
    return;
end
h = uihtml(fh, 'Position', [1 1 0 0], 'HandleVisibility', 'off', ...
    'DataChangedFcn', @DnD_callback, 'UserData', {{target dropFcn}}, ...
    'Tag', 'uiFileDnD', 'HTMLSource', help('DnD_uifigure>JS_DnD_html'));
nam = fh.Name;
fh.Name = char(randi(9,1,4)+128); % rename to no-show name
drawnow; ww = matlab.internal.webwindowmanager.instance.windowList;
ww = ww(strcmp(fh.Name, {ww.Title}));
fh.Name = nam; % restore name
if ~ismethod(ww, 'enableDragAndDropAll')
    error('Matlab R2020b or later needed for file drag and drop');
end
ww.enableDragAndDropAll; % enable DnD to whole uifigure
ww.FileDragDropCallback = {@dragEnter h};

%% fired when drag enters uifigure
function dragEnter(~, names, h)
hs = allchild(h.Parent);
if h ~= hs(1), h.Parent.Children = [h; hs(h~=hs)]; end % make uihtml topmost
h.Position(3:4) = h.Parent.Position(3:4); drawnow; % enable JS in uihtml
for i = 1:numel(h.UserData)
    p = getpixelposition(h.UserData{i}{1}, 1);
    if h.UserData{i}{1}.Type == "figure", p(1:2) = 1; end
    pos{i} = p; %#ok JS ondragover to deny drop outside rect
end
h.Data.dropZone = pos; % JS ondragover to deny drop outside rect
h.Data.names = cellstr(names); % JS ondrop uses this for full name(s)

%% fired by javascript Data change in ondrop and ondragleave
function DnD_callback(h, e)
h.Position(3:4) = 0; % other components in uifigure will work properly
if e.Data.event == "dragleave", return; end % DnD revoked
[obj, dropFcn] = h.UserData{e.Data.index+1}{:};
dat = rmfield(e.Data, {'event' 'index'});
if iscell(dropFcn), feval(dropFcn{1}, obj, dat, dropFcn{2:end});
else, feval(dropFcn, obj, dat);
end

%% javascript for HTMLSource
function JS_DnD_html
% <div hidden></div>
% <script type="text/javascript">
%     function setup(htmlComponent) {
%         document.ondragover = (e) => {
%             e.returnValue = false
%             if(!(htmlComponent.Data.hasOwnProperty("dropZone"))) return
%             for(var i = 0; i < htmlComponent.Data.dropZone.length; i++) {
%                 if(inRect(e.clientX, e.clientY, htmlComponent.Data.dropZone[i])) return
%             }
%             e.dataTransfer.dropEffect = "none"
%         }
%         document.body.ondrop = (e) => {
%             e.returnValue = false
%             if(!(htmlComponent.Data.hasOwnProperty("dropZone"))) return
%             var n = htmlComponent.Data.dropZone.length
%             for(var i = n-1; i >= 0 && n > 1; i--) {
%                 if(inRect(e.clientX, e.clientY, htmlComponent.Data.dropZone[i])) break
%             }
%             htmlComponent.Data = {
%               "event": "drop", 
%               "names": htmlComponent.Data.names,
%               "ctrlKey": e.ctrlKey,
%               "shiftKey": e.shiftKey,
%               "index": i
%             }
%         }
%         document.ondragleave = (e) => {
%             htmlComponent.Data = {"event": "dragleave"}
%         }
%     }
%     function inRect(x, y, p) { // Matlab p = [left bottom width height]
%         x = x + 1; y = document.body.clientHeight - y
%         return (x>=p[0] && y>=p[1] && x<p[0]+p[2] && y<p[1]+p[3])
%     }
% </script>

%%
