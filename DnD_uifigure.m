function DnD_uifigure(target, dropFcn)
% Set up a callback when file/folder is dropped onto a uifigure component.
% 
% The target component can be uifigure itself or any uifigure component.
% 
% dropFcn is the callback function when a file is dropped. Its syntax is the
% same as general Matlab callback, like @myFunc or {@myFunc myOtherInput}.
% In the dropFcn callback, the 2nd argument is the data with fields:
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
h = findall(fh, 'Type', 'uihtml', 'Tag', 'DnD');
if ~isempty(h)
    h.UserData{end+1} = {target dropFcn};
    return;
end
h = uihtml(fh, 'Position', [1 1 0 0], 'HandleVisibility', 'callback', ...
    'DataChangedFcn', @DnD_callback, 'UserData', {{target dropFcn}}, ...
    'Tag', 'DnD', 'HTMLSource', help('DnD_uifigure>JS_DnD_html'));
nam = fh.Name;
fh.Name = char(randi(9,1,4)+128); % rename to no-show name
drawnow; ww = matlab.internal.webwindowmanager.instance.windowList;
ww = ww(strcmp(fh.Name, {ww.Title}));
fh.Name = nam; % restore name
ww.enableDragAndDropAll; % enable DnD to whole uifigure
ww.FileDragDropCallback = {@dragEnter h};

%% fired when drag enters uifigure
function dragEnter(~, names, h)
hs = allchild(h.Parent);
if h ~= hs(1), h.Parent.Children = [h; hs(h~=hs)]; end % make uihtml topmost
h.Position(3:4) = h.Parent.Position(3:4); drawnow; % enable JS call in uihtml
for i = 1:numel(h.UserData)
    p = getpixelposition(h.UserData{i}{1}, 1);
    if h.UserData{i}{1}.Type == "figure", p(1:2) = 1; end
    p(2) = h.Position(4) - p(4) - p(2) + 2; % from top
    p(3:4) = p(1:2) + p(3:4) - 1; % right-bottom
    h.Data.dropZone{i} = p - 1; % JS ondragover to deny drop outside rect
end
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

%% javascrpt
function JS_DnD_html
% <div class="drop-zone"></div>
% <script type="text/javascript">
%     function setup(htmlComponent) {
%         document.ondragover = (e) => {
%             e.preventDefault()
%             e.stopPropagation()
%             if(!(htmlComponent.Data.hasOwnProperty("dropZone"))) return;
%             var isOut = true
%             for(var i = 0; i < htmlComponent.Data.dropZone.length; i++) {
%                 var b = htmlComponent.Data.dropZone[i]
%                 isOut = isOut && (e.clientX<b[0] || e.clientX>b[2] || e.clientY<b[1] || e.clientY>b[3])
%             }
%             if (isOut) e.dataTransfer.dropEffect = "none"
%         }
%         document.body.ondrop = (e) => {
%             e.preventDefault()
%             var i = 0;
%             for(i = 0; i < htmlComponent.Data.dropZone.length; i++) {
%                 var b = htmlComponent.Data.dropZone[i]
%                 if (e.clientX>b[0] && e.clientX<b[2] && e.clientY>b[1] && e.clientY<b[3]) break;
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
% </script>

%%
