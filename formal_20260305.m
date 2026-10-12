%点完选项会有点卡
%记得检查COM端口

function olfacaudi_experiment()
    try
        % 初始化Psychtoolbox
        clear; clc; close all;
        Screen('Preference','SkipSyncTests',1);
        Screen('CloseAll');
        KbName('UnifyKeyNames');
        
        % 实验参数设置
        numBlocks = 4;          % 区块数量
        numTrialsPerBlock = 4;  % 每个区块4个试次
        totalTrials = numBlocks * numTrialsPerBlock; % 总共16个试次
        whiteFixTime = 4;       % 白色注视点时间
        yellowFixTime = 2;      % 黄色注视点时间
        greenFixTime = 2;       % 绿色注视点时间(气味呈现)
        postOdorTime = 4;       % 气味后休息时间
        feedbackTime = 2;       % 反馈时间
        
        % 按键设置
        exitKey = KbName('escape'); % 退出键
        
        % 端口设置
        olfactometerPort = 'COM3'; % 嗅觉仪连接的端口
        
        % 创建数据结构
        expData = struct();
        expData.subjectInfo = struct('id', [], 'gender', [], 'age', []);
        expData.trialData = struct('block', {}, 'condition', {}, 'audio', {}, 'response', {}, 'rt', {}, 'correct', {});
        
        % 获取被试信息
        dlgtitle = '被试信息';
        prompt = {'您的序号：', '性别(男/女)：', '年龄：'};
        dims = [1 45];
        answer = inputdlg(prompt, dlgtitle, dims);
        
        expData.subjectInfo.id = str2double(answer{1});
        expData.subjectInfo.gender = answer{2};
        expData.subjectInfo.age = str2double(answer{3});
        
        % 初始化串口
        delete(instrfindall('Type', 'serial'));
        ettPort = ett('init', olfactometerPort);
        ett('set', ettPort, 0); % 关闭所有阀门
        
        % 初始化音频
        InitializePsychSound;
        audioHigh = audioread('1000Hz.wav');
        audioLow = audioread('80Hz.wav');
        
        % 确保音频是列向量
        if size(audioHigh, 2) > 1
            audioHigh = mean(audioHigh, 2);
        end
        if size(audioLow, 2) > 1
            audioLow = mean(audioLow, 2);
        end
        
        % 创建音频处理对象
        pahandle = PsychPortAudio('Open', [], [], 0, [], 2);
        
        % 设置屏幕
        window = Screen('OpenWindow', max(Screen('Screens')), [0 0 0]);
        Screen('TextSize', window, 30);
        Screen('TextFont', window, 'SimHei');
        windowRect = Screen('Rect', window);
        [xCenter, yCenter] = RectCenter(windowRect);
        HideCursor;
        
        % 颜色定义
        white = [255 255 255];
        yellow = [255 255 0];
        green = [0 255 0];
        gray = [128 128 128];
        highlight = [255 255 0]; % 高亮颜色(黄色)
        
        % 1. 显示实验指导语
        instruction_text = ['现在进入正式测试阶段。下面你将听到声音并闻到气味。请根据注视点颜色变化呼吸：\n\n'...
                           '之后请选择你闻到的气味'];
        Screen('TextFont', window, 'SimHei'); 
        DrawFormattedText(window, double(instruction_text), 'center', 'center', white);
        Screen('Flip', window);
        
        % 添加ESC键检测的等待循环
        startTime = GetSecs();
        while GetSecs() - startTime < 5
            [~, ~, keyCode] = KbCheck;
            if keyCode(exitKey)
                cleanup(ettPort, window);
                return;
            end
            WaitSecs(0.01);
        end
        
        % 2. 定义气味条件顺序
        conditionOrders = {
            [1, 4, 3, 2];  % 顺序1
            [3, 2, 1, 4];  % 顺序2
            [2, 3, 4, 1];  % 顺序3
            [4, 1, 2, 3]   % 顺序4
        };
        
        % 随机选择一种顺序
        selectedOrderIdx = randi(4);
        selectedOrder = conditionOrders{selectedOrderIdx};
        expData.conditionOrder = selectedOrder; % 记录选择的顺序
        
        % 3. 定义声音序列 (1=高音, 0=低音)
        audioSequence = [1,0,0,1,0,1,0,1,0,0,1,1,1,0,1,0];
        
        % 4. 定义气味条件对应的阀门组合和气味类别
        conditionInfo = {
            [1, 8], '1';   % 条件1: Q1左(阀1), Z1右(阀8) -> 气味1和2
            [3, 10], '3';  % 条件2: Q2左(阀3), Z2右(阀10) -> 气味3和4
            [2, 7], '2';   % 条件3: Z1左(阀2), Q1右(阀7) -> 气味1和2
            [4, 9], '4'    % 条件4: Z2左(阀4), Q2右(阀9) -> 气味3和4
        };
        
        % 5. 主实验循环
        trialCounter = 1;
        correctCount = 0;
        
        for blockIdx = 1:numBlocks
            % 获取当前区块的气味条件
            currentCondition = selectedOrder(blockIdx);
            valves = conditionInfo{currentCondition, 1};
            odorCategory = conditionInfo{currentCondition, 2};
            
            % 根据气味类别确定选项
            if strcmp(odorCategory, '1') || strcmp(odorCategory, '2')
                optionText = {'LM', 'GU'};
                correctMap = containers.Map({'1','2'}, {1,2});
            else
                optionText = {'PA', 'EN'};
                correctMap = containers.Map({'3','4'}, {1,2});
            end
            
            for trialInBlock = 1:numTrialsPerBlock
                % 获取当前试次的声音类型
                currentAudio = audioSequence(trialCounter);
                
                % 存储试次信息
                expData.trialData(trialCounter).block = blockIdx;
                expData.trialData(trialCounter).condition = currentCondition;
                expData.trialData(trialCounter).audio = currentAudio;
                expData.trialData(trialCounter).odorCategory = odorCategory;
                
                % ===== 试次开始 =====
                
                % 阶段1: 4秒白色注视点
                drawFixation(window, xCenter, yCenter, white);
                Screen('Flip', window);
                
                startTime = GetSecs();
                while GetSecs() - startTime < whiteFixTime
                    [~, ~, keyCode] = KbCheck;
                    if keyCode(exitKey)
                        cleanup(ettPort, window);
                        return;
                    end
                    WaitSecs(0.01);
                end
                
                % 阶段2: 2秒黄色注视点(准备)
                drawFixation(window, xCenter, yCenter, yellow);
                Screen('Flip', window);
                
                startTime = GetSecs();
                while GetSecs() - startTime < yellowFixTime
                    [~, ~, keyCode] = KbCheck;
                    if keyCode(exitKey)
                        cleanup(ettPort, window);
                        return;
                    end
                    WaitSecs(0.01);
                end
                
                % 阶段3: 2秒绿色注视点(吸气+气味+声音)
                drawFixation(window, xCenter, yCenter, green);
                Screen('Flip', window);
                
                % 开启气味和声音
                ett('set', ettPort, valves);
                if currentAudio == 1
                    PsychPortAudio('FillBuffer', pahandle, [audioHigh'; audioHigh']);
                else
                    PsychPortAudio('FillBuffer', pahandle, [audioLow'; audioLow']);
                end
                PsychPortAudio('Start', pahandle, 1, 0, 1);
                odorStartTime = GetSecs();
                
                % 保持绿色注视点
                while GetSecs() - odorStartTime < greenFixTime
                    [~, ~, keyCode] = KbCheck;
                    if keyCode(exitKey)
                        PsychPortAudio('Stop', pahandle);
                        ett('set', ettPort, 0);
                        cleanup(ettPort, window);
                        return;
                    end
                end
                
                % 停止声音和气味
                PsychPortAudio('Stop', pahandle);
                ett('set', ettPort, 0);
                
                % === 选择界面 ===
                response = NaN;
                rt = NaN;
                selectedOption = 0;
                startTime = GetSecs();
                
                % 定义选项位置
                optionRects = zeros(2, 4);
                optionYPos = [yCenter-50, yCenter+50];
                for i = 1:2
                    optionRects(i,:) = CenterRectOnPoint([0 0 200 60], xCenter, optionYPos(i));
                end
                confirmRect = CenterRectOnPoint([0 0 200 60], xCenter, yCenter+150);
                
                % 首次绘制选择界面
                Screen('TextSize', window, 30);
                for i = 1:2
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
                        cleanup(ettPort, window);
                        return;
                    end
                    
                    % 检查鼠标点击
                    [mx, my, buttons] = GetMouse(window);
                    if any(buttons)
                        % 检查选项点击
                        for i = 1:2
                            if IsInRect(mx, my, optionRects(i,:))
                                selectedOption = i;
                                
                                % 重新绘制界面以显示选择
                                Screen('TextSize', window, 30);
                                for j = 1:2
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
                            if response == correctMap(odorCategory)
                                correctCount = correctCount + 1;
                                expData.trialData(trialCounter).correct = 1;
                            else
                                expData.trialData(trialCounter).correct = 0;
                            end
                            
                            % 存储数据
                            expData.trialData(trialCounter).response = optionText{response};
                            expData.trialData(trialCounter).rt = rt;

                            startTime = GetSecs();
                            while GetSecs() - startTime < feedbackTime
                                [~, ~, keyCode] = KbCheck;
                                if keyCode(exitKey)
                                    cleanup(ettPort, window);
                                    return;
                                end
                                WaitSecs(0.01);
                            end
                        end
                    end
                end
                
                % 更新试次计数器
                trialCounter = trialCounter + 1;
            end
        end
        
        % 6. 保存数据为CSV文件
        csvFilename = sprintf('subject%d_%s_%d.csv', ...
                              expData.subjectInfo.id, ...
                              expData.subjectInfo.gender, ...
                              expData.subjectInfo.age);
        
        % 创建表头
        headers = {'SubjectID', 'Gender', 'Age', 'Block', 'TrialInBlock', ...
                  'GlobalTrial', 'Condition', 'Audio', ...
                  'Response', 'RT'};
        
        % 打开文件写入数据
        fid = fopen(csvFilename, 'w', 'n', 'UTF-8');
        fprintf(fid, '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n', headers{:});
        
        % 写入所有试次数据
        for t = 1:length(expData.trialData)
            trial = expData.trialData(t);
            
            % 计算区块内试次索引
            trialInBlock = mod(t, numTrialsPerBlock);
            if trialInBlock == 0
                trialInBlock = numTrialsPerBlock;
            end
            
            % 处理缺失的数据
            if isempty(trial.response)
                responseStr = 'NA';
                rtStr = 'NA';
                correctStr = 'NA';
            else
                responseStr = trial.response;
                rtStr = sprintf('%.3f', trial.rt);
                correctStr = num2str(trial.correct);
            end
            
            % 写入一行数据
            fprintf(fid, '%d,%s,%d,%d,%d,%d,%d,%d,%s,%s\n', ...
                    expData.subjectInfo.id, ...
                    expData.subjectInfo.gender, ...
                    expData.subjectInfo.age, ...
                    trial.block, ...
                    trialInBlock, ...
                    t, ...
                    trial.condition, ...
                    trial.audio, ...
                    responseStr, ...
                    rtStr);
        end
        
        fclose(fid);
        disp(['实验数据已保存为CSV文件: ' csvFilename]);
        
        % 7. 显示结束信息
        endText = sprintf('实验结束！感谢您的参与！');
        Screen('TextFont', window, 'SimHei'); 
        DrawFormattedText(window, double(endText), 'center', 'center', white);
        Screen('Flip', window);
        
        startTime = GetSecs();
        while GetSecs() - startTime < 4
            [~, ~, keyCode] = KbCheck;
            if keyCode(exitKey)
                cleanup(ettPort, window);
                return;
            end
            WaitSecs(0.01);
        end
        
        % 8. 清理
        cleanup(ettPort, window);

    catch ME
        % 错误处理
        cleanup();
        rethrow(ME);
    end
    
    % 清理函数
    function cleanup(ettPort, window)
        if exist('ettPort', 'var') && ~isempty(ettPort)
            ett('set', ettPort, 0); % 关闭所有阀门
            ett('close', ettPort);
        end
        if exist('window', 'var') && ~isempty(window)
            sca;
            ShowCursor;
            Priority(0);
        end
        if exist('pahandle', 'var') && ~isempty(pahandle)
            PsychPortAudio('Close');
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
end

