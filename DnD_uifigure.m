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
    h.UserData(end+1,:) = {target dropFcn};
    return;
end

h = uihtml(fh, 'Position', [1 1 0 0], 'HandleVisibility', 'off', ...
    'DataChangedFcn', @DnD_callback, 'UserData', {target dropFcn}, ...
    'Tag', 'uiFileDnD', 'HTMLSource', help('DnD_uifigure>DnD_callback'));
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
dragEnter(ww, '', h); h.Position = [1 1 0 0]; % exercise to reduce "+Copy" time

%% fired when drag enters uifigure
function dragEnter(ww, names, h)
if h.Position(3)>0, return; end % if called repeatedly, disable ww only once
ww.setActivateCurrentWindow(false); drawnow; % avoid default open behavior
hs = allchild(h.Parent);
if h ~= hs(1), h.Parent.Children = [h; hs(h~=hs)]; end % make uihtml topmost
h.Position = [1 1 h.Parent.Position(3:4)]; drawnow; % enable JS in uihtml
for i = size(h.UserData,1):-1:1 %  redo in case pos changed or resized
    pos{i} = getpixelposition(h.UserData{i,1}, 1);
    if h.UserData{i,1}.Type == "figure", pos{i}(1:2) = 1; end
end
h.Data.dropZone = pos; % used by JS ondragover
h.Data.names = cellstr(names); % hard to get path in JS
ww.setActivateCurrentWindow(true);

%% fired by javascript Data change in ondrop and ondragleave
% <!-- help text is actually javascript for HTMLSource. Touch with care! -->
function DnD_callback(h, e)
% <div hidden></div>
% <script type="text/javascript">
%   function setup(h) {
%     document.ondragover = (e) => {
%       e.returnValue = false // preventDefault & stopPropagation
%       var i, x = e.clientX+1, y = document.body.clientHeight-e.clientY
%       for (i = h.Data.dropZone.length-1; i >= 0; i--) {
%         var p = h.Data.dropZone[i] // [left bottom width height]
%         if (x>=p[0] && y>=p[1] && x<p[0]+p[2] && y<p[1]+p[3]) {
%           h.Data.event = "dragover" // no need: not fire callback
%           h.Data.index = i
%           return
%         }
%       }
%       e.dataTransfer.dropEffect = "none" // disable drop
%     }
%     document.body.ondrop = (e) => {
%       e.returnValue = false
%       h.Data.event = "drop" 
%       h.Data.ctrlKey = e.ctrlKey
%       h.Data.shiftKey = e.shiftKey
%       h.Data = h.Data // fire callback
%     }
%     document.ondragleave = (e) => { // Data struct kept even dragleave
%       h.Data.event = "dragleave"
%       h.Data = h.Data
%     }
%   }
% </script>

if e.Data.event == "dragover", return; end % not needed, just in case
h.Position(3:4) = 0; % other components in uifigure will work properly
if e.Data.event == "dragleave", return; end % DnD revoked
[target, dropFcn] = h.UserData{e.Data.index+1,:};
dat = rmfield(e.Data, {'event' 'index' 'dropZone'});
if iscell(dropFcn), feval(dropFcn{1}, target, dat, dropFcn{2:end});
else, feval(dropFcn, target, dat);
end
%%
