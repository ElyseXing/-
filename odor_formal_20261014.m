function odor_formal_20261014()
    scriptDir = fileparts(mfilename('fullpath'));
    addpath(scriptDir);
    if exist('ett', 'file') ~= 2
        error('ETT helper ett.m was not found beside this program.');
    end

    odors = {'CAR', 'GUA', 'CIN', 'PV'};
    prompts = {'Subject ID:', 'Age:', 'Gender:', ...
        'ETT serial port (e.g. COM3 or /dev/ttyUSB0):', ...
        'CAR left-nostril valve', 'GUA left-nostril valve', ...
        'CIN left-nostril valve', 'PV left-nostril valve', ...
        'CAR right-nostril valve', 'GUA right-nostril valve', ...
        'CIN right-nostril valve', 'PV right-nostril valve'};
    defaults = {'', '', '', 'COM3', '', '', '', '', '', '', '', ''};
    answer = inputdlg(prompts, 'Formal experiment setup', [1 48], defaults);
    if isempty(answer)
        return;
    end

    subjectId = strtrim(answer{1});
    ageText = strtrim(answer{2});
    age = str2double(ageText);
    gender = strtrim(answer{3});
    serialPort = strtrim(answer{4});
    valves = cellfun(@(value) str2double(strtrim(value)), answer(5:12));
    if isempty(subjectId) || isempty(gender) || ~isfinite(age) || age <= 0 || ...
            isempty(serialPort)
        error('Enter a subject ID, positive age, gender, and serial port.');
    end
    validateValves(valves);
    leftValveMap = containers.Map(odors, num2cell(valves(1:4)));
    rightValveMap = containers.Map(odors, num2cell(valves(5:8)));

    [highAudioFile, highPath] = chooseAudioFile('Select high-pitch audio');
    if isempty(highAudioFile)
        return;
    end
    [lowAudioFile, lowPath] = chooseAudioFile('Select low-pitch audio');
    if isempty(lowAudioFile)
        return;
    end
    if strcmp(highPath, lowPath)
        error('Select different files for high- and low-pitch audio.');
    end
    [audioHigh, highSampleRate] = audioread(highPath);
    [audioLow, lowSampleRate] = audioread(lowPath);
    if isempty(audioHigh) || isempty(audioLow) || any(~isfinite(audioHigh(:))) || ...
            any(~isfinite(audioLow(:)))
        error('Audio files must contain finite, non-empty audio samples.');
    end
    if highSampleRate ~= lowSampleRate
        error('High- and low-pitch audio must have the same sample rate.');
    end
    if size(audioHigh, 1) / highSampleRate < 2 || ...
            size(audioLow, 1) / lowSampleRate < 2
        error('Both audio files must be at least 2 seconds long.');
    end
    audioHigh = makeStereo(audioHigh);
    audioLow = makeStereo(audioLow);

    conditionOrders = {
        [1 4 3 2];
        [3 2 1 4];
        [2 3 4 1];
        [4 1 2 3]
    };
    selectedOrderIdx = randi(numel(conditionOrders));
    selectedOrder = conditionOrders{selectedOrderIdx};
    audioSequence = [1 0 0 1 0 1 0 1 0 0 1 1 1 0 1 0];
    conditionLeft = {'CAR', 'GUA', 'CIN', 'PV'};
    conditionRight = {'GUA', 'CAR', 'PV', 'CIN'};

    trialData = repmat(struct('Block', 0, 'TrialInBlock', 0, ...
        'GlobalTrial', 0, 'Condition', 0, 'LeftOdor', '', 'RightOdor', '', ...
        'Pitch', '', 'AudioFile', '', 'Response', '', 'RT', NaN), 16, 1);
    completedTrials = 0;
    outputFile = makeOutputPath(scriptDir, subjectId);
    writeFormalCsv(outputFile, subjectId, ageText, gender, trialData, ...
        completedTrials, 'InProgress');

    window = [];
    ettPort = [];
    audioHandle = [];
    try
        KbName('UnifyKeyNames');
        exitKey = KbName('ESCAPE');
        window = Screen('OpenWindow', max(Screen('Screens')), [0 0 0]);
        HideCursor;
        Screen('TextFont', window, 'SimHei');
        Screen('TextSize', window, 28);

        ettPort = ett('init', serialPort);
        ett('set', ettPort, 0);
        InitializePsychSound;
        audioHandle = PsychPortAudio('Open', [], 1, 1, highSampleRate, 2);

        instruction = ['下面进入正式测试。请根据注视点颜色变化吸气：黄色时准备，' ...
            '绿色时开始吸气。气味和声音出现后，请选择此刻更多感知到的气味。\n\n' ...
            '按 p 开始，按 ESC 中止。'];
        showMessage(window, instruction, [255 255 255]);
        waitForKey(KbName('p'), exitKey);

        trialCounter = 1;
        for blockIdx = 1:numel(selectedOrder)
            condition = selectedOrder(blockIdx);
            leftOdor = conditionLeft{condition};
            rightOdor = conditionRight{condition};
            valvesForTrial = [leftValveMap(leftOdor), rightValveMap(rightOdor)];
            if condition <= 2
                options = {'CAR', 'GUA'};
            else
                options = {'CIN', 'PV'};
            end

            for trialInBlock = 1:4
                isHighPitch = audioSequence(trialCounter) == 1;
                if isHighPitch
                    pitchLabel = 'High';
                    audioBuffer = audioHigh;
                    audioFile = highAudioFile;
                else
                    pitchLabel = 'Low';
                    audioBuffer = audioLow;
                    audioFile = lowAudioFile;
                end

                presentFormalStimulus(window, ettPort, audioHandle, ...
                    audioBuffer, valvesForTrial, exitKey);
                question = '此刻你更多感知到哪种气味？';
                [response, reactionTime] = collectChoice(window, options, ...
                    question, exitKey);

                trialData(trialCounter).Block = blockIdx;
                trialData(trialCounter).TrialInBlock = trialInBlock;
                trialData(trialCounter).GlobalTrial = trialCounter;
                trialData(trialCounter).Condition = condition;
                trialData(trialCounter).LeftOdor = leftOdor;
                trialData(trialCounter).RightOdor = rightOdor;
                trialData(trialCounter).Pitch = pitchLabel;
                trialData(trialCounter).AudioFile = audioFile;
                trialData(trialCounter).Response = response;
                trialData(trialCounter).RT = reactionTime;
                completedTrials = trialCounter;
                writeFormalCsv(outputFile, subjectId, ageText, gender, ...
                    trialData, completedTrials, 'InProgress');
                trialCounter = trialCounter + 1;
            end
        end

        writeFormalCsv(outputFile, subjectId, ageText, gender, ...
            trialData, completedTrials, 'Completed');
        showMessage(window, '正式实验结束，感谢参与！', [0 255 120]);
        waitWithEscape(4, exitKey);
        cleanupExperiment(ettPort, window, audioHandle);
        fprintf('Completed. Data saved to %s\n', outputFile);
    catch ME
        if exist(outputFile, 'file') == 2
            try
                writeFormalCsv(outputFile, subjectId, ageText, gender, ...
                    trialData, completedTrials, 'Interrupted');
            catch saveError
                warning('Formal:PartialSaveFailed', '%s', saveError.message);
            end
        end
        cleanupExperiment(ettPort, window, audioHandle);
        rethrow(ME);
    end
end

function [selectedFile, fullPath] = chooseAudioFile(dialogTitle)
    [filename, folder] = uigetfile( ...
        {'*.wav;*.mp3;*.flac', 'Audio files (*.wav, *.mp3, *.flac)'}, dialogTitle);
    if isequal(filename, 0)
        selectedFile = '';
        fullPath = '';
    else
        fullPath = fullfile(folder, filename);
        selectedFile = filename;
    end
end

function audio = makeStereo(audio)
    if size(audio, 2) == 1
        audio = [audio audio];
    elseif size(audio, 2) > 2
        audio = audio(:, 1:2);
    end
end

function validateValves(valves)
    if any(~isfinite(valves)) || any(valves ~= fix(valves)) || ...
            any(valves < 1 | valves > 12) || numel(unique(valves)) ~= numel(valves)
        error('Enter eight unique integer valve numbers from 1 to 12.');
    end
end

function presentFormalStimulus(window, ettPort, audioHandle, audioBuffer, ...
        valves, exitKey)
    phases = {[255 255 255], [255 255 0], [0 255 0]};
    durations = [4 2 2];
    for phase = 1:2
        drawFixation(window, phases{phase});
        Screen('Flip', window);
        waitWithEscape(durations(phase), exitKey);
    end

    drawFixation(window, phases{3});
    Screen('Flip', window);
    try
        ett('set', ettPort, valves);
        PsychPortAudio('FillBuffer', audioHandle, audioBuffer');
        PsychPortAudio('Start', audioHandle, 1, 0, 1);
        waitWithEscape(durations(3), exitKey);
    catch ME
        try
            PsychPortAudio('Stop', audioHandle);
        catch
        end
        ett('set', ettPort, 0);
        rethrow(ME);
    end
    PsychPortAudio('Stop', audioHandle);
    ett('set', ettPort, 0);
end

function [response, reactionTime] = collectChoice(window, options, question, exitKey)
    rect = Screen('Rect', window);
    [centerX, centerY] = RectCenter(rect);
    optionRects = zeros(2, 4);
    for optionIdx = 1:2
        optionRects(optionIdx, :) = CenterRectOnPoint([0 0 320 70], ...
            centerX, centerY - 65 + (optionIdx - 1) * 90);
    end
    confirmRect = CenterRectOnPoint([0 0 320 64], centerX, centerY + 150);
    selectedOption = 0;
    previousMouseDown = false;
    response = '';
    startTime = GetSecs;

    while isempty(response)
        [~, ~, keyCode] = KbCheck;
        if keyCode(exitKey)
            error('Formal:Aborted', 'Participant pressed ESC to stop the session.');
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
        DrawFormattedText(window, double(question), 'center', ...
            rect(2) + 0.18 * RectHeight(rect), [255 255 255]);
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
            error('Formal:Aborted', 'Participant pressed ESC to stop the session.');
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
            error('Formal:Aborted', 'Participant pressed ESC to stop the session.');
        end
        WaitSecs(0.01);
    end
end

function filename = makeOutputPath(outputDir, subjectId)
    safeSubjectId = regexprep(subjectId, '[^A-Za-z0-9_-]', '_');
    timestamp = clock;
    milliseconds = floor(mod(now * 86400 * 1000, 1000));
    baseName = sprintf('odor_formal_%s_%04d%02d%02d_%02d%02d%02d_%03d', ...
        safeSubjectId, timestamp(1), timestamp(2), timestamp(3), ...
        timestamp(4), timestamp(5), floor(timestamp(6)), milliseconds);
    filename = fullfile(outputDir, [baseName '.csv']);
    suffix = 1;
    while exist(filename, 'file') == 2
        filename = fullfile(outputDir, sprintf('%s_%d.csv', baseName, suffix));
        suffix = suffix + 1;
    end
end

function writeFormalCsv(filename, subjectId, age, gender, ...
        trialData, completedTrials, sessionStatus)
    fid = fopen(filename, 'w', 'n', 'UTF-8');
    if fid < 0
        error('Formal:CsvOpenFailed', 'Could not open output CSV: %s', filename);
    end
    fileGuard = onCleanup(@() fclose(fid));
    fprintf(fid, ['SubjectID,Age,Gender,Block,TrialInBlock,GlobalTrial,Condition,' ...
        'LeftOdor,RightOdor,Pitch,AudioFile,Response,RT,SessionStatus\n']);
    for trialIdx = 1:completedTrials
        trial = trialData(trialIdx);
        fprintf(fid, '%s,%s,%s,%d,%d,%d,%d,%s,%s,%s,%s,%s,%.3f,%s\n', ...
            csvEscape(subjectId), csvEscape(age), csvEscape(gender), ...
            trial.Block, trial.TrialInBlock, trial.GlobalTrial, trial.Condition, ...
            trial.LeftOdor, trial.RightOdor, trial.Pitch, ...
            csvEscape(trial.AudioFile), trial.Response, ...
            trial.RT, sessionStatus);
    end
    clear fileGuard;
end

function escaped = csvEscape(value)
    escaped = ['"' strrep(char(value), '"', '""') '"'];
end

function inside = IsInRect(x, y, rect)
    inside = x >= rect(1) && x <= rect(3) && y >= rect(2) && y <= rect(4);
end

function cleanupExperiment(ettPort, window, audioHandle)
    if ~isempty(audioHandle)
        try
            PsychPortAudio('Stop', audioHandle);
            PsychPortAudio('Close', audioHandle);
        catch cleanupError
            warning('Formal:AudioCleanupFailed', '%s', cleanupError.message);
        end
    end
    if ~isempty(ettPort)
        try
            ett('set', ettPort, 0);
            ett('close', ettPort);
            delete(ettPort);
        catch cleanupError
            warning('Formal:PortCleanupFailed', '%s', cleanupError.message);
        end
    end
    if ~isempty(window)
        Screen('CloseAll');
        ShowCursor;
    end
end