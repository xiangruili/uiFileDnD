function DnD_uifigure(target, dropFcn)
% Set up a callback when file/folder is dropped onto a uifigure component.
% 
% The target can be a uifigure or any uifigure component.
% 
% dropFcn is the callback function when a file is dropped. Its syntax is the
% same as general Matlab callback, like @myFunc or {@myFunc myOtherInput}.
% In the callback, the first argument is the target, and 2nd the data containing
%     ctrlKey: 0 % true if Ctrl key is down while dropping
%    shiftKey: 0 % true if Shift key is down while dropping
%       names: {'/myPath/myFile'} % cellstr for full file/folder names
% 
% Example to drop file/folder into uilistbox:
%  target = uilistbox(uifigure, 'Position', [80 100 400 100]);
%  DnD_uifigure(target, @(o,dat)set(o,'Items',dat.names));

% 201001 Wrote it, by Xiangrui.Li at gmail.com 
% 201004 Allow to add more target repeatedly
% 201023 Remove uihtml by using ww.executeJS

narginchk(2, 2);
if isempty(target), target = uifigure; end
if numel(target)>1 || ~ishandle(target)
    error('DnD_uifigure:badInput', 'target must be a single uifigure component');
end

fh = ancestor(target, 'figure');
h = findall(fh, 'Type', 'uibutton', 'Tag', 'uiFileDnD');
if ~isempty(h)
    h.UserData(end+1,:) = {dropFcn target};
    return;
end

drawnow; ww = matlab.internal.webwindowmanager.instance.windowList;
ww = ww(strcmp(matlab.ui.internal.FigureServices.getFigureURL(fh), {ww.URL}));
if ~ismethod(ww, 'enableDragAndDropAll')
    error('Matlab R2020b or later needed for file drag and drop');
end
h = uibutton(fh, 'Position', [1 1 0 0], 'Text', 'uiFileDnD_fakeBtn', ...
    'ButtonPushedFcn', {@drop ww}, 'UserData', {dropFcn target}, ...
    'Tag', 'uiFileDnD', 'Visible', 'off', 'HandleVisibility', 'off'); 

drawnow; ww.executeJS(help([mfilename '>drop']));
ww.enableDragAndDropAll; % enable file DnD to whole uifigure
ww.FileDragDropCallback = {@dragEnter h};

%% fired when drag enters uifigure
function dragEnter(ww, names, h)
pos = '';
for i = size(h.UserData,1):-1:1 %  redo in case pos changed or resized
    p = getpixelposition(h.UserData{i,2}, 1);
    if h.UserData{i,2}.Type == "figure", p(1:2) = 1; end
    pos = sprintf('[%g,%g,%g,%g],%s', p, pos);
end
ww.executeJS(['uiFileDnD.rects=[' pos '];']);
setappdata(h, 'names', cellstr(names)); % store file names

%% fired by javascript fake button press in ondrop
% // help text is actually javascript. Touch with care!
function drop(h, ~, ww)
% uiFileDnD = {rects: [], index: 0, ctrlKey: false, shiftKey: false};
% document.ondragenter = (e) => { // prevent default before firing ondragover
%   e.dataTransfer.dropEffect = "none"; 
%   return false;
% };
% document.ondragover = (e) => {
%   e.returnValue = false; // preventDefault & stopPropagation
%   var x = e.clientX+1, y = document.body.clientHeight-e.clientY;
%   for (var i = uiFileDnD.rects.length-1; i >= 0; i--) {
%     var p = uiFileDnD.rects[i]; // [left bottom width height]
%     if (x>=p[0] && y>=p[1] && x<p[0]+p[2] && y<p[1]+p[3]) {
%       uiFileDnD.index = i; // target index in rects
%       return; // keep OS default dropEffect
%     };
%   };
%   e.dataTransfer.dropEffect = "none"; // disable drop
% };
% document.ondrop = (e) => {
%   uiFileDnD.ctrlKey = e.ctrlKey;
%   uiFileDnD.shiftKey = e.shiftKey;
%   fakeButton().click(); // fire Matlab drop()
%   return false;
% };
% function fakeButton() {
%   for (let b of document.getElementsByClassName("mwPushButton")) {
%     if (b.textContent == "uiFileDnD_fakeBtn") return b;}
% };

dat = jsondecode(ww.executeJS('uiFileDnD'));
dat.names = getappdata(h, 'names');
args = [h.UserData(dat.index+1,:) rmfield(dat, {'rects' 'index'})];
if iscell(args{1}), args = [args{1}(1) args(2:3) args{1}(2:end)]; end
feval(args{:});
%%