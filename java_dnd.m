function java_dnd(target, dropFcn)
% Set Matlab dropFcn for a figure object. Called by uiFileDnD.m.

% 170421 Xiangrui Li adapted from dndcontrol class by Maarten van der Seijs:
%   https://www.mathworks.com/matlabcentral/fileexchange/53511
% 260201 include findjobj_fast(), so input is figure component

% Required: MLDropTarget.class under the same folder

if ~exist('MLDropTarget', 'class')
    pth = fileparts(mfilename('fullpath'));
    javaaddpath(pth); % dynamic for this session
    fid = fopen(fullfile(prefdir, 'javaclasspath.txt'), 'a+');
    if fid>0 % static path for later sessions: work for 2013+?
        cln = onCleanup(@() fclose(fid));
        fseek(fid, 0, 'bof');
        classpth = fread(fid, inf, '*char')';
        if isempty(strfind(classpth, pth)) %#ok<*STREMP> % avoid multiple write
            fseek(fid, 0, 'bof');
            fprintf(fid, '%s\n', pth);
        end
    end
end

dropTarget = handle(javaObjectEDT('MLDropTarget'), 'CallbackProperties');
set(dropTarget, 'DragEnterCallback', @DragEnterCallback, ...
                'DragExitCallback', @DragExitCallback, ...
                'DropCallback', {@DropCallback target dropFcn});
jObj = handle(findjobj_fast(target), 'CallbackProperties');
jObj.setDropTarget(dropTarget);
%%

function DropCallback(jSource, jEvent, target, dropFcn)
setComplete = onCleanup(@()jEvent.dropComplete(true));
% Following DropAction is for ~jEvent.isLocalTransfer, such as dropping file.
% For LocalTransfer, Linux seems consistent with other OS.
% DropAction: Neither ctrl nor shift Dn, PC/MAC 2, Linux 1
% All OS: ctrlDn 1, shiftDn 2, both Dn 1073741824 (2^30)
if ispc || ismac
    evt.ctrlKey = jEvent.getDropAction() ~= 2;
else % fails to report CtrlDn if user releases shift between DragEnter and Drop
    evt.ctrlKey = bitget(jEvent.getDropAction,31)>0; % ACTION_LINK 1<<30
    java.awt.Robot().keyRelease(16); % shift up
end
% evt.Location = [jEvent.getLocation.x jEvent.getLocation.y]; % top-left [0 0]
if jSource.getDropType() == 1 % String dropped
    evt.DropType = 'string';
    evt.names = char(jSource.getTransferData());
    if strncmp(evt.Data, 'file://', 7) % files identified as string
        evt.DropType = 'file';
        evt.names = regexp(evt.names, '(?<=file://).*?(?=\r?\n)', 'match')';
    end
elseif jSource.getDropType() == 2 % file(s) dropped
    evt.DropType = 'file';
    evt.names = cell(jSource.getTransferData());
else, return; % No success
end

if iscell(dropFcn), feval(dropFcn{1}, target, evt, dropFcn{2:end});
else, feval(dropFcn, target, evt);
end
%%

function DragEnterCallback(~, jEvent)
try jEvent.acceptDrag(1); catch, return; end % ACTION_COPY
if ~ispc && ~ismac, java.awt.Robot().keyPress(16); end % shift down
%%

function DragExitCallback(~, jEvent)
if ~ispc && ~ismac, java.awt.Robot().keyRelease(16); end % shift up
try jEvent.rejectDrag(1); catch, end % ACTION_COPY
%%

% Rest code from Yair Altman (2026). findjobj - find java handles of Matlab graphic objects
% https://www.mathworks.com/matlabcentral/fileexchange/14317-findjobj-find-java-handles-of-matlab-graphic-objects
function jControl = findjobj_fast(hControl, jContainer) %#ok<*JAVFM,*JAPIMATHWORKS>
    if double(get(hControl,'Parent'))~=0  % avoid below for figure handles
        try jControl = hControl.getTable; return, catch, end  % fast bail-out for old uitables
        try jControl = hControl.JavaFrame.getGUIDEView; return, catch, end  % bail-out for HG2 matlab.ui.container.Panel
    end
    oldWarn = warning;
    warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
    warning('off','MATLAB:ui:javaframe:PropertyToBeRemoved');
    try oc = onCleanup(@()warning(oldWarn)); catch, end % Gracefully restore warnings on return (suggested by T. Carpenter 2021-08-17)
    if nargin < 2 || isempty(jContainer)
        % Use a HG2 matlab.ui.container.Panel jContainer if the control's parent is a uipanel
        try
            hParent = get(hControl,'Parent');
        catch
            % Probably indicates an invalid/deleted/empty handle
            jControl = [];
            return
        end
        try jContainer = hParent.JavaFrame.getGUIDEView; catch, jContainer = []; end
    end
    if isempty(jContainer)
        if isequal(double(hControl),0)  % root handle => return jDesktop
            try
                jControl = com.mathworks.mde.desk.MLDesktop.getInstance;
                if isempty(jControl), error('retry'), end
            catch
                jControl = com.mathworks.mlservices.MatlabDesktopServices.getDesktop;
            end
            return
        end
        hFig = ancestor(hControl,'figure');
        jf = get(hFig, 'JavaFrame');
        if isequal(hFig,hControl) % speedup suggested by T. Carpenter 2021-08-17
            jControl = jf;
            return
        end
        jContainer = jf.getFigurePanelContainer.getComponent(0);
    end
    warning(oldWarn);
    jControl = [];
    counter = 20;  % 2018-09-21 speedup (100 x 0.001 => 20 x 0.005) - Martin Lehmann suggestion on FEX 2016-06-07
    specialTooltipStr = '!@#$%^&*';
    try  % Fix for R2018b suggested by Eddie (FEX comment 2018-09-19)
        tooltipPropName = 'TooltipString';
        oldTooltip = get(hControl,tooltipPropName);
        set(hControl,tooltipPropName,specialTooltipStr);
    catch
        tooltipPropName = 'Tooltip';
        oldTooltip = get(hControl,tooltipPropName);
        set(hControl,tooltipPropName,specialTooltipStr);
    end
    while isempty(jControl) && counter>0
        counter = counter - 1;
        pause(0.005);
        jControl = findTooltipIn(jContainer, specialTooltipStr);
    end
    set(hControl,tooltipPropName,oldTooltip);
    try jControl.setToolTipText(oldTooltip); catch, end
    try jControl = jControl.getParent.getView.getParent.getParent; catch, end  % return JScrollPane if exists

function jControl = findTooltipIn(jContainer, specialTooltipStr)
    try
        jControl = [];  % Fix suggested by H. Koch 11/4/2017
        tooltipStr = jContainer.getToolTipText;
        %if strcmp(char(tooltipStr),specialTooltipStr)
        if ~isempty(tooltipStr) && tooltipStr.startsWith(specialTooltipStr)  % a bit faster
            jControl = jContainer;
        else
            for idx = 1 : jContainer.getComponentCount
                jControl = findTooltipIn(jContainer.getComponent(idx-1), specialTooltipStr);
                if ~isempty(jControl), return; end
            end
        end
    catch
        % ignore
    end
%%