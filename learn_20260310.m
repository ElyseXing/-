% 作者：邢若雨
% 修改：将函数改为脚本形式，以解决ETTMat_init静态工作区错误
% esc退出，鼠标点击选择

% 初始化Psychtoolbox
clear; clc; close all;
Screen('Preference','SkipSyncTests',1);
Screen('CloseAll');
KbName('UnifyKeyNames');

% 实验参数设置
instructTime = 10;  % 初始指导语时间
odorInfoTime = 4;   % 气味信息显示时间
whiteFixTime = 4;   % 白色注视点时间
yellowFixTime = 2;  % 黄色注视点时间
greenFixTime = 2;   % 绿色注视点时间(气味呈现)
postOdorTime = 4;   % 气味后休息时间
feedbackTime = 8;   % 反馈时间

% 按键设置
exitKey = KbName('escape');   % 退出键

% 创建数据结构
expData = struct();
expData.trialData = struct('odor', {}, 'response', {}, 'correct', {}, 'rt', {});

% ========== 新版本ETT初始化 ==========
% 删除旧的串口初始化
% delete(instrfindall('Type','serial'));

% 新版本初始化
fprintf('初始化ETT设备...\n');

% 加载ETT驱动
ETTMat_init;

% 获取设备列表
DeviceList = Device.ScanDeviceList;
if DeviceList.Count < 1 || DeviceList.Item(0) == ""
    error('没有找到ETT设备，请连接设备后重试！');
end

% 显示设备信息
fprintf('找到 %d 个设备:\n', DeviceList.Count);
for n = 0:DeviceList.Count-1
    deviceProperties = DeviceList.Item(n).Split('.');
    fprintf('设备 %d: ID: %s, 名称: %s, 类型: %s\n', ...
        n+1, deviceProperties(1), deviceProperties(2), deviceProperties(3));
end

% 使用第一个设备
ett_device = Device;

% 关闭所有阀门
ett_device.CloseAllChannels();
fprintf('ETT初始化完成\n');
% ===================================

% 初始化音频
InitializePsychSound;
audioHigh = audioread('1000Hz.wav');

% 确保音频是列向量
if size(audioHigh, 2) > 1
    audioHigh = mean(audioHigh, 2); % 如果是多声道，转换为单声道
end

% 创建音频处理对象
pahandle = PsychPortAudio('Open', [], [], 0, [], 2); % 最后参数2表示立体声
PsychPortAudio('FillBuffer', pahandle, [audioHigh'; audioHigh']); % 立体声播放

% 设置屏幕
window = Screen('OpenWindow', max(Screen('Screens')), [0 0 0]);
Screen('TextSize', window, 30);
Screen('TextFont', window, 'SimHei'); % 保证中文显示
windowRect = Screen('Rect', window);
[xCenter, yCenter] = RectCenter(windowRect);
HideCursor;

% 颜色定义
white = [255 255 255];
yellow = [255 255 0];
green = [0 255 0];
gray = [128 128 128];
highlight = [255 255 0]; % 高亮颜色(黄色)

try
    % 1. 显示初始指导语10秒
    instruction_text = ['下面进入学习阶段，请根据注视点颜色的变化吸气，并尽可能记住这些气味。\n\n' ...
                       '当注视点变黄时准备，当注视点变绿时开始吸气。'];
    Screen('TextFont', window, 'SimHei');
    DrawFormattedText(window, double(instruction_text), 'center', 'center', white); 
    Screen('Flip', window);
    WaitSecs(instructTime);  

    % 添加ESC键检测的等待循环
    startTime = GetSecs();
    while GetSecs() - startTime < instructTime
        [~, ~, keyCode] = KbCheck;
        if keyCode(exitKey)
            cleanup();
            return;
        end
        WaitSecs(0.01); % 避免CPU过载
    end

    %% 气味学习阶段 - 依次呈现4种气味
    odors = {'LM', 'GU', 'PA', 'EN'};
    valveMapping = containers.Map({'LM', 'GU', 'PA', 'EN'}, {[1,7], [2,8], [3,9], [4,10]});
    
    for i = 1:length(odors)
        currentOdor = odors{i};
        
        % 显示当前气味信息
        odor_text = sprintf('下面你将闻到气味%s', currentOdor);
        Screen('TextFont', window, 'SimHei');
        DrawFormattedText(window, double(odor_text), 'center', 'center', white);
        Screen('Flip', window);
        WaitSecs(odorInfoTime);
        
        % 添加ESC键检测的等待循环
        startTime = GetSecs();
        while GetSecs() - startTime < odorInfoTime
            [~, ~, keyCode] = KbCheck;
            if keyCode(exitKey)
                cleanup();
                return;
            end
            WaitSecs(0.01);
        end

        % 白色注视点
        drawFixation(window, xCenter, yCenter, white);
        Screen('Flip', window);
        WaitSecs(whiteFixTime);
        
        % 黄色注视点(准备)
        drawFixation(window, xCenter, yCenter, yellow);
        Screen('Flip', window);
        WaitSecs(yellowFixTime);
        
        % 绿色注视点(吸气+气味+声音)
        drawFixation(window, xCenter, yCenter, green);
        Screen('Flip', window);
        
        % ========== 开启气味（新版本） ==========
        % 先关闭所有阀门
        ett_device.CloseAllChannels();
        
        % 打开指定阀门
        for valve_num = valveMapping(currentOdor)
            ett_device.SetChannel(valve_num, true);
        end
        
        startTime = GetSecs();
        
        % 保持绿色注视点
        while GetSecs() - startTime < greenFixTime
            [~, ~, keyCode] = KbCheck;
            if keyCode(exitKey)
                % 停止气味
                ett_device.CloseAllChannels();
                cleanup();
                return;
            end
        end
        
        % ========== 停止气味（新版本） ==========
        ett_device.CloseAllChannels();
        
        % 白色注视点(休息)
        drawFixation(window, xCenter, yCenter, white);
        Screen('Flip', window);
        WaitSecs(postOdorTime);
    end
    
    %% 按键学习阶段
    trialOrder = {'GU', 'PA', 'EN', 'LM', 'PA', 'GU', 'EN', 'LM'};
    correctResponses = containers.Map({'LM', 'PA', 'GU', 'EN'}, {'LM', 'PA', 'GU', 'EN'});

    % 定义气味分组
    group1 = {'LM', 'GU'};  % 第一组
    group2 = {'PA', 'EN'};  % 第二组
    correctCount = 0;

    % 显示按键学习指导语
    instruction_text = ['接下来请根据气味选择对应的选项。\n\n' ...   
              '请用鼠标点击选择，然后点击"确认"按钮'];
    Screen('TextFont', window, 'SimHei');
    DrawFormattedText(window, double(instruction_text), 'center', 'center', white);
    Screen('Flip', window);
    WaitSecs(instructTime);

    for trial = 1:length(trialOrder)
        currentOdor = trialOrder{trial};
        
        % 白色注视点
        drawFixation(window, xCenter, yCenter, white);
        Screen('Flip', window);
        WaitSecs(whiteFixTime);
        
        % 黄色注视点(准备)
        drawFixation(window, xCenter, yCenter, yellow);
        Screen('Flip', window);
        WaitSecs(yellowFixTime);
        
        % 绿色注视点(吸气+气味)
        drawFixation(window, xCenter, yCenter, green);
        Screen('Flip', window);
        
        % ========== 开启气味（新版本） ==========
        % 先关闭所有阀门
        ett_device.CloseAllChannels();
        
        % 打开指定阀门
        for valve_num = valveMapping(currentOdor)
            ett_device.SetChannel(valve_num, true);
        end
        
        odorStartTime = GetSecs();
        
        % 保持绿色注视点
        while GetSecs() - odorStartTime < greenFixTime
            [~, ~, keyCode] = KbCheck;
            if keyCode(exitKey)
                % 停止气味
                ett_device.CloseAllChannels();
                cleanup();
                return;
            end
        end
        
        % ========== 停止气味（新版本） ==========
        ett_device.CloseAllChannels();
        
        % === 选择界面（根据气味分组显示不同选项）===
        response = NaN;
        rt = NaN;
        selectedOption = 0;
        startTime = GetSecs();
        
        % 根据当前气味确定显示哪组选项
        if ismember(currentOdor, group1)
            optionText = group1;  % 显示 LM, GU
        else
            optionText = group2;  % 显示 PA, EN
        end
        
        % 定义选项位置（现在只有2个选项）
        numOptions = length(optionText);
        optionRects = zeros(numOptions, 4);
        optionYPos = linspace(yCenter-50, yCenter+50, numOptions);
        for i = 1:numOptions
            optionRects(i,:) = CenterRectOnPoint([0 0 200 60], xCenter, optionYPos(i));
        end
        confirmRect = CenterRectOnPoint([0 0 200 60], xCenter, yCenter+150);
        
        % 首次绘制选择界面
        Screen('TextSize', window, 30);
        for i = 1:numOptions
            if i == selectedOption
                color = highlight;
            else
                color = white;
            end
            Screen('FrameRect', window, color, optionRects(i,:), 2);
            DrawFormattedText(window, double(optionText{i}), 'center', 'center', color, [], [], [], [], [], optionRects(i,:));
        end
        
        % 绘制确认按钮
        Screen('FrameRect', window, white, confirmRect, 2);
        Screen('TextFont', window, 'SimHei');
        DrawFormattedText(window, double('确认'), 'center', 'center', white, [], [], [], [], [], confirmRect);
        Screen('Flip', window);
        
        % 启用鼠标
        ShowCursor('Arrow');
        
        while isnan(response)
            % 检查退出键
            [~, ~, keyCode] = KbCheck;
            if keyCode(exitKey)
                HideCursor;
                cleanup();
                return;
            end

            % 检查鼠标点击
            [mx, my, buttons] = GetMouse(window);
            
            if any(buttons)
                % 检查选项点击
                for i = 1:numOptions
                    if IsInRect(mx, my, optionRects(i,:))
                        selectedOption = i;
                        
                        % 重新绘制界面以显示选择
                        Screen('TextSize', window, 30);
                        for j = 1:numOptions
                            if j == selectedOption
                                color = highlight;
                            else
                                color = white;
                            end
                            Screen('FrameRect', window, color, optionRects(j,:), 2);
                            DrawFormattedText(window, double(optionText{j}), 'center', 'center', color, [], [], [], [], [], optionRects(j,:));
                        end
                        
                        % 绘制确认按钮
                        Screen('FrameRect', window, white, confirmRect, 2);
                        DrawFormattedText(window, double('确认'), 'center', 'center', white, [], [], [], [], [], confirmRect);
                        Screen('Flip', window);
                        
                        WaitSecs(0.2); % 防止多次点击
                    end
                end
                
                % 检查确认按钮点击
                if IsInRect(mx, my, confirmRect) && selectedOption ~= 0
                    response = selectedOption;
                    rt = GetSecs() - startTime;
                    
                    % 检查是否正确
                    if strcmp(optionText{response}, correctResponses(currentOdor))
                        correctCount = correctCount + 1;
                        expData.trialData(trial).correct = 1;
                    else
                        expData.trialData(trial).correct = 0;
                    end
                    
                    % 存储数据
                    expData.trialData(trial).odor = currentOdor;
                    expData.trialData(trial).response = optionText{response};
                    expData.trialData(trial).rt = rt;
                    
                    % 显示反馈前隐藏鼠标
                    HideCursor;
                    
                    % 显示反馈
                    feedback_text = sprintf('你选择了%s\n\n正确答案是%s', ...
                                        optionText{response}, correctResponses(currentOdor));
                    Screen('TextFont', window, 'SimHei');
                    DrawFormattedText(window, double(feedback_text), 'center', 'center', white);
                    Screen('Flip', window);
                    WaitSecs(feedbackTime);
                end
            end
        end
    end
    
    % 计算并显示正确率
    accuracy = correctCount / length(trialOrder) * 100;
    result_text = sprintf('恭喜您完成了学习阶段！\n\n您的正确率是%.0f%%', accuracy);
    Screen('TextFont', window, 'SimHei');
    DrawFormattedText(window, double(result_text), 'center', 'center', white);
    Screen('Flip', window);
    WaitSecs(feedbackTime);
    
    % 清理并退出
    cleanup();

catch ME
    % 错误处理
    fprintf('程序发生错误: %s\n', ME.message);
    for i = 1:length(ME.stack)
        fprintf('错误位置: %s 第%d行\n', ME.stack(i).name, ME.stack(i).line);
    end
    cleanup();
    rethrow(ME);
end

% 清理函数
function cleanup()
    try
        % 关闭ETT设备阀门
        if exist('ett_device', 'var') && ~isempty(ett_device)
            ett_device.CloseAllChannels();
            fprintf('ETT设备已关闭\n');
        end
    catch ME
        fprintf('关闭ETT设备时出错: %s\n', ME.message);
    end
    
    try
        % 关闭音频设备
        if exist('pahandle', 'var') && ~isempty(pahandle)
            PsychPortAudio('Close', pahandle);
        end
    catch ME
        fprintf('关闭音频设备时出错: %s\n', ME.message);
    end
    
    try
        % 关闭屏幕
        if exist('window', 'var') && ~isempty(window)
            sca;
            ShowCursor;
            Priority(0);
        end
    catch ME
        fprintf('关闭屏幕时出错: %s\n', ME.message);
    end
end

% 绘制注视点函数
function drawFixation(window, x, y, color)
    Screen('TextSize', window, 60);
    DrawFormattedText(window, '+', 'center', 'center', color);
end

% 检查点是否在矩形内
function inside = IsInRect(x, y, rect)
    inside = x >= rect(1) && x <= rect(3) && y >= rect(2) && y <= rect(4);
end