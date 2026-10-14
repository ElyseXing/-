function odor_learn_20261014()
    scriptDir = fileparts(mfilename('fullpath'));
    addpath(scriptDir);
    if exist('ett', 'file') ~= 2
        error('ETT helper ett.m was not found beside this program.');
    end

    odors = {'CAR', 'GUA', 'CIN', 'PV'};
    prompts = {'Subject ID:', 'Age:', 'Gender:', ...
        'ETT serial port (e.g. COM3 or /dev/ttyUSB0):', ...
        'CAR valve (verify hardware)', 'GUA valve (verify hardware)', ...
        'CIN valve (verify hardware)', 'PV valve (verify hardware)'};
    defaults = {'', '', '', 'COM3', '', '', '', ''};
    answer = inputdlg(prompts, 'Odor learning setup', [1 48], defaults);
    if isempty(answer)
        return;
    end

    subjectId = strtrim(answer{1});
    age = str2double(strtrim(answer{2}));
    gender = strtrim(answer{3});
    serialPort = strtrim(answer{4});
    valves = cellfun(@(value) str2double(strtrim(value)), answer(5:8));
    if isempty(subjectId) || isempty(gender) || ~isfinite(age) || age <= 0 || ...
            isempty(serialPort)
        error('Enter a subject ID, positive age, gender, and serial port.');
    end
    validateValves(valves);
    valveMap = containers.Map(odors, num2cell(valves));

    window = [];
    ettPort = [];
    try
        KbName('UnifyKeyNames');
        exitKey = KbName('ESCAPE');
        window = Screen('OpenWindow', max(Screen('Screens')), [0 0 0]);
        HideCursor;
        Screen('TextFont', window, 'SimHei');
        Screen('TextSize', window, 28);

        ettPort = ett('init', serialPort);
        ett('set', ettPort, 0);

        instruction = ['下面进入学习阶段，请根据注视点颜色变化吸气。\n' ...
            '注视点变黄时准备，变绿时开始吸气。\n\n按 p 开始，按 ESC 中止。'];
        showMessage(window, instruction, [255 255 255]);
        waitForKey(KbName('p'), exitKey);

        for odorIdx = 1:numel(odors)
            showMessage(window, sprintf('下面你将闻到气味 %s', odors{odorIdx}), ...
                [255 255 255]);
            waitWithEscape(4, exitKey);
            presentLearningOdor(window, ettPort, valveMap(odors{odorIdx}), exitKey);
        end

        trialOrder = makeLearningOrder(odors);
        correctCount = 0;
        for trialIdx = 1:numel(trialOrder)
            odor = trialOrder{trialIdx};
            presentRecognitionOdor(window, ettPort, valveMap(odor), exitKey);
            options = optionsForOdor(odor);
            [response, ~] = collectChoice(window, options, exitKey);
            correct = strcmp(response, odor);
            correctCount = correctCount + correct;
            if correct
                feedback = sprintf('正确！这是气味 %s', odor);
            else
                feedback = sprintf('正确答案：气味 %s', odor);
            end
            showMessage(window, feedback, [255 255 255]);
            waitWithEscape(4, exitKey);
        end

        accuracy = 100 * correctCount / numel(trialOrder);
        passed = accuracy > 80;
        if passed
            resultText = sprintf(['学习阶段完成！正确率：%.0f%%\n' ...
                '已达到进入正式测试的标准。'], accuracy);
        else
            resultText = sprintf(['学习阶段完成。正确率：%.0f%%\n' ...
                '未高于 80%%，本次不进入正式测试。'], accuracy);
        end
        showMessage(window, resultText, [0 255 120]);
        waitWithEscape(5, exitKey);
        cleanupExperiment(ettPort, window);
        ettPort = [];
        window = [];

        if passed
            choice = questdlg(sprintf('学习正确率 %.0f%%。现在启动正式实验吗？', ...
                accuracy), '学习阶段通过', '启动正式实验', '结束', '启动正式实验');
            if strcmp(choice, '启动正式实验')
                odor_formal_20261014();
            end
        end
        fprintf('Learning completed for subject %s: %.0f%% correct.\n', ...
            subjectId, accuracy);
    catch ME
        cleanupExperiment(ettPort, window);
        rethrow(ME);
    end
end

function validateValves(valves)
    if any(~isfinite(valves)) || any(valves ~= fix(valves)) || ...
            any(valves < 1 | valves > 12) || numel(unique(valves)) ~= numel(valves)
        error('Enter a unique integer valve number from 1 to 12 for each odor.');
    end
end

function order = makeLearningOrder(odors)
    repeatedOdors = [odors, odors];
    hasAdjacentDuplicate = true;
    while hasAdjacentDuplicate
        order = repeatedOdors(randperm(numel(repeatedOdors)));
        hasAdjacentDuplicate = any(strcmp(order(1:end-1), order(2:end)));
    end
end

function options = optionsForOdor(odor)
    if any(strcmp(odor, {'CAR', 'GUA'}))
        options = {'CAR', 'GUA'};
    else
        options = {'CIN', 'PV'};
    end
end

function presentLearningOdor(window, ettPort, valve, exitKey)
    drawFixation(window, [255 255 255]);
    Screen('Flip', window);
    waitWithEscape(4, exitKey);
    drawFixation(window, [255 255 0]);
    Screen('Flip', window);
    waitWithEscape(2, exitKey);
    drawFixation(window, [0 255 0]);
    Screen('Flip', window);
    ett('set', ettPort, valve);
    try
        waitWithEscape(2, exitKey);
    catch ME
        ett('set', ettPort, 0);
        rethrow(ME);
    end
    ett('set', ettPort, 0);
    drawFixation(window, [255 255 255]);
    Screen('Flip', window);
    waitWithEscape(4, exitKey);
end

function presentRecognitionOdor(window, ettPort, valve, exitKey)
    for phase = 1:2
        colors = {[255 255 255], [255 255 0]};
        durations = [4 2];
        drawFixation(window, colors{phase});
        Screen('Flip', window);
        waitWithEscape(durations(phase), exitKey);
    end
    drawFixation(window, [0 255 0]);
    Screen('Flip', window);
    ett('set', ettPort, valve);
    try
        waitWithEscape(2, exitKey);
    catch ME
        ett('set', ettPort, 0);
        rethrow(ME);
    end
    ett('set', ettPort, 0);
end

function [response, reactionTime] = collectChoice(window, options, exitKey)
    rect = Screen('Rect', window);
    [centerX, centerY] = RectCenter(rect);
    optionRects = zeros(2, 4);
    for optionIdx = 1:2
        optionRects(optionIdx, :) = CenterRectOnPoint([0 0 300 70], ...
            centerX, centerY - 65 + (optionIdx - 1) * 90);
    end
    confirmRect = CenterRectOnPoint([0 0 300 64], centerX, centerY + 150);
    selectedOption = 0;
    previousMouseDown = false;
    response = '';
    startTime = GetSecs;

    while isempty(response)
        [~, ~, keyCode] = KbCheck;
        if keyCode(exitKey)
            error('Learning:Aborted', 'Participant pressed ESC to stop the session.');
        end
        [mouseX, mouseY, buttons] = GetMouse(window);
        mouseDown = any(buttons);
        if mouseDown && ~previousMouseDown
            for optionIdx = 1:2
                if IsInRect(mouseX, mouseY, optionRects(optionIdx, :))
                    selectedOption = optionIdx;
                end
            end
            if selectedOption > 0 && IsInRect(mouseX, mouseY, confirmRect)
                response = options{selectedOption};
                reactionTime = GetSecs - startTime;
            end
        end
        previousMouseDown = mouseDown;

        Screen('FillRect', window, [0 0 0]);
        DrawFormattedText(window, double('请选择刚才闻到的气味'), ...
            'center', rect(2) + 0.18 * RectHeight(rect), [255 255 255]);
        for optionIdx = 1:2
            color = [255 255 255];
            if selectedOption == optionIdx
                color = [255 255 0];
            end
            Screen('FrameRect', window, color, optionRects(optionIdx, :), 2);
            label = sprintf('气味 %s', options{optionIdx});
            DrawFormattedText(window, double(label), 'center', 'center', ...
                color, [], [], [], [], [], optionRects(optionIdx, :));
        end
        Screen('FrameRect', window, [255 255 255], confirmRect, 2);
        DrawFormattedText(window, double('确认'), 'center', 'center', ...
            [255 255 255], [], [], [], [], [], confirmRect);
        Screen('Flip', window);
        WaitSecs(0.01);
    end
end

function showMessage(window, text, color)
    Screen('FillRect', window, [0 0 0]);
    DrawFormattedText(window, double(text), 'center', 'center', color);
    Screen('Flip', window);
end

function drawFixation(window, color)
    Screen('FillRect', window, [0 0 0]);
    rect = Screen('Rect', window);
    [centerX, centerY] = RectCenter(rect);
    arm = 22;
    Screen('DrawLine', window, color, centerX - arm, centerY, centerX + arm, centerY, 4);
    Screen('DrawLine', window, color, centerX, centerY - arm, centerX, centerY + arm, 4);
end

function waitForKey(targetKey, exitKey)
    while true
        [keyDown, ~, keyCode] = KbCheck;
        if keyDown && keyCode(exitKey)
            error('Learning:Aborted', 'Participant pressed ESC to stop the session.');
        elseif keyDown && keyCode(targetKey)
            return;
        end
        WaitSecs(0.01);
    end
end

function waitWithEscape(duration, exitKey)
    startTime = GetSecs;
    while GetSecs - startTime < duration
        [~, ~, keyCode] = KbCheck;
        if keyCode(exitKey)
            error('Learning:Aborted', 'Participant pressed ESC to stop the session.');
        end
        WaitSecs(0.01);
    end
end

function inside = IsInRect(x, y, rect)
    inside = x >= rect(1) && x <= rect(3) && y >= rect(2) && y <= rect(4);
end

function cleanupExperiment(ettPort, window)
    if ~isempty(ettPort)
        try
            ett('set', ettPort, 0);
            ett('close', ettPort);
            delete(ettPort);
        catch cleanupError
            warning('Learning:CleanupFailed', '%s', cleanupError.message);
        end
    end
    if ~isempty(window)
        Screen('CloseAll');
        ShowCursor;
    end
end