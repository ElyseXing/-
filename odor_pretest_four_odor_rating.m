function odor_rating_20261014()
% Rate four candidate odors on familiarity, valence, intensity, and lightness.
% Requires Psychtoolbox and ett.m in this file's directory.

    scriptDir = fileparts(mfilename('fullpath'));
    addpath(scriptDir);
    if exist('ett', 'file') ~= 2
        error('ETT helper ett.m was not found beside this program.');
    end

    odors = {'CAR', 'GUA', 'CIN', 'PV'};
    valveLabels = {'CAR valve (check hardware)', 'GUA valve (check hardware)', ...
        'CIN valve (check hardware)', 'PV valve (check hardware)'};
    prompt = [{'Subject ID:', 'Age:', 'Gender:', ...
        'ETT serial port (e.g. COM3 or /dev/cu.xxx):'}, valveLabels];
    defaults = [{'', '', '', 'COM3'}, {'', '', '', ''}];
    answer = inputdlg(prompt, 'Four-odor pretest setup', [1 48], defaults);
    if isempty(answer)
        return;
    end

    subjectId = strtrim(answer{1});
    ageText = strtrim(answer{2});
    gender = strtrim(answer{3});
    serialPort = strtrim(answer{4});
    age = str2double(ageText);
    valves = zeros(1, numel(odors));
    for odorIdx = 1:numel(odors)
        valves(odorIdx) = str2double(strtrim(answer{4 + odorIdx}));
    end
    if isempty(subjectId) || isempty(gender) || isempty(serialPort) || ...
            ~isfinite(age) || age <= 0
        error('Subject ID, positive numeric age, gender, and serial port are required.');
    end
    if any(~isfinite(valves)) || any(valves ~= fix(valves)) || ...
            any(valves < 1 | valves > 12) || numel(unique(valves)) ~= numel(valves)
        error('Enter a unique integer valve number from 1 to 12 for each odor.');
    end

    % Defaults follow the old six-odor index order; verify the actual tubing.
    valveMap = containers.Map(odors, num2cell(valves));
    trialOrder = makeTrialOrder(odors);
    ratings = nan(numel(trialOrder), 4);
    completedTrials = 0;
    outputFile = makeOutputPath(scriptDir, subjectId);

    window = [];
    ettPort = [];
    exitKey = [];
    try
        KbName('UnifyKeyNames');
        exitKey = KbName('ESCAPE');
        continueKey = KbName('p');
        window = Screen('OpenWindow', max(Screen('Screens')), [0 0 0]);
        HideCursor;
        Screen('TextFont', window, 'SimHei');
        Screen('TextSize', window, 28);

        fprintf('Initializing olfactometer on %s...\n', serialPort);
        ettPort = ett('init', serialPort);
        ett('set', ettPort, 0);
        writeRatingsCsv(outputFile, subjectId, ageText, gender, ...
            trialOrder, ratings, completedTrials, 'InProgress');

        showInstructions(window, continueKey, exitKey);
        for trialIdx = 1:numel(trialOrder)
            odor = trialOrder{trialIdx};
            fprintf('Trial %d/%d: %s (valve %d)\n', ...
                trialIdx, numel(trialOrder), odor, valveMap(odor));

            showOdorPrompt(window, odor, exitKey);
            presentOdor(window, ettPort, valveMap(odor), exitKey);

            trialRatings = zeros(1, 4);
            for dimensionIdx = 1:4
                trialRatings(dimensionIdx) = rateDimension( ...
                    window, odor, dimensionIdx, exitKey);
            end
            ratings(trialIdx, :) = trialRatings;
            completedTrials = trialIdx;
            writeRatingsCsv(outputFile, subjectId, ageText, gender, ...
                trialOrder, ratings, completedTrials, 'InProgress');
            fprintf('%s ratings: intensity=%d, valence=%d, lightness=%d, familiarity=%d\n', ...
                odor, trialRatings(1), trialRatings(2), trialRatings(3), trialRatings(4));

            if trialIdx < numel(trialOrder)
                showRest(window, exitKey);
            end
        end

        writeRatingsCsv(outputFile, subjectId, ageText, gender, ...
            trialOrder, ratings, completedTrials, 'Completed');
        showEndScreen(window, exitKey);
        cleanupExperiment(ettPort, window);
        fprintf('Completed. Ratings saved to %s\n', outputFile);
    catch ME
        if exist(outputFile, 'file') == 2
            try
                writeRatingsCsv(outputFile, subjectId, ageText, gender, ...
                    trialOrder, ratings, completedTrials, 'Interrupted');
                fprintf('Session data (including any completed trials) saved to %s\n', outputFile);
            catch saveError
                warning('Pretest:PartialSaveFailed', ...
                    'Could not save partial ratings: %s', saveError.message);
            end
        end
        cleanupExperiment(ettPort, window);
        rethrow(ME);
    end
end

function order = makeTrialOrder(odors)
    repeatedOdors = [odors, odors];
    hasAdjacentDuplicate = true;
    while hasAdjacentDuplicate
        order = repeatedOdors(randperm(numel(repeatedOdors)));
        hasAdjacentDuplicate = any(strcmp(order(1:end-1), order(2:end)));
    end
end

function showInstructions(window, continueKey, exitKey)
    text = sprintf(['本预实验将呈现 CAR、GUA、CIN、PV，每种气味两次。\n' ...
            '每次请对主观强度、愉悦性、主观轻盈性和熟悉性评分。\n\n' ...
        '拖动屏幕上的评分条选择 0–100 分，确认后进入下一维度。\n' ...
        '气味呈现时：白色注视点后为黄色准备提示，再变绿时吸气。\n' ...
        '按 p 开始；随时按 ESC 可中止。']);
    Screen('FillRect', window, [0 0 0]);
    DrawFormattedText(window, double(text), 'center', 'center', [255 255 255]);
    Screen('Flip', window);
    waitForKey(continueKey, exitKey);
end

function showOdorPrompt(window, odor, exitKey)
    text = sprintf('接下来你将闻到气味 %s', odor);
    Screen('FillRect', window, [0 0 0]);
    DrawFormattedText(window, double(text), 'center', 'center', [255 255 255]);
    Screen('Flip', window);
    waitWithEscape(4, exitKey);
end

function presentOdor(window, ettPort, valve, exitKey)
    colors = {[255 255 255], [255 255 0], [0 255 0]};
    durations = [4, 4, 4];
    for phase = 1:2
        drawFixation(window, colors{phase});
        Screen('Flip', window);
        waitWithEscape(durations(phase), exitKey);
    end

    drawFixation(window, colors{3});
    Screen('Flip', window);
    ett('set', ettPort, valve);
    waitWithEscape(durations(3), exitKey);
    ett('set', ettPort, 0);
end

function drawFixation(window, color)
    Screen('FillRect', window, [0 0 0]);
    rect = Screen('Rect', window);
    centerX = (rect(1) + rect(3)) / 2;
    centerY = (rect(2) + rect(4)) / 2;
    arm = 22;
    Screen('DrawLine', window, color, centerX - arm, centerY, ...
        centerX + arm, centerY, 4);
    Screen('DrawLine', window, color, centerX, centerY - arm, ...
        centerX, centerY + arm, 4);
end

function score = rateDimension(window, odor, dimensionIdx, exitKey)
    names = {'主观强度', '愉悦性', '主观轻盈性', '熟悉性'};
    leftLabels = {'非常弱', '非常不愉快', '非常沉闷', '非常不熟悉'};
    rightLabels = {'非常强', '非常愉快', '非常轻盈', '非常熟悉'};
    score = 50;
    dragging = false;
    previousMouseDown = false;

    rect = Screen('Rect', window);
    centerX = (rect(1) + rect(3)) / 2;
    trackLeft = rect(1) + 0.18 * RectWidth(rect);
    trackRight = rect(1) + 0.82 * RectWidth(rect);
    trackY = rect(2) + 0.60 * RectHeight(rect);
    trackRect = [trackLeft - 20, trackY - 30, trackRight + 20, trackY + 30];
    buttonRect = CenterRectOnPoint([0 0 330 64], centerX, rect(2) + 0.80 * RectHeight(rect));
    while true
        [~, ~, keyCode] = KbCheck;
        if keyCode(exitKey)
            error('Pretest:Aborted', 'Participant pressed ESC to stop the session.');
        end

        [mouseX, mouseY, buttons] = GetMouse(window);
        mouseDown = any(buttons);
        if mouseDown && ~previousMouseDown
            if IsInRect(mouseX, mouseY, buttonRect)
                break;
            elseif IsInRect(mouseX, mouseY, trackRect)
                dragging = true;
            end
        elseif ~mouseDown
            dragging = false;
        end
        if mouseDown && (dragging || IsInRect(mouseX, mouseY, trackRect))
            score = round(100 * min(1, max(0, ...
                (mouseX - trackLeft) / (trackRight - trackLeft))));
        end
        previousMouseDown = mouseDown;

        Screen('FillRect', window, [0 0 0]);
        title = sprintf('%s：请评估气味 %s', names{dimensionIdx}, odor);
        DrawFormattedText(window, double(title), 'center', rect(2) + 0.22 * RectHeight(rect), ...
            [255 255 255]);
        DrawFormattedText(window, sprintf('%d', score), 'center', ...
            rect(2) + 0.43 * RectHeight(rect), [255 255 0]);
        Screen('DrawLine', window, [180 180 180], trackLeft, trackY, ...
            trackRight, trackY, 8);
        for tick = 0:10
            x = trackLeft + (trackRight - trackLeft) * tick / 10;
            Screen('DrawLine', window, [180 180 180], x, trackY - 8, ...
                x, trackY + 8, 2);
        end
        markerX = trackLeft + (trackRight - trackLeft) * score / 100;
        Screen('FillOval', window, [0 220 120], ...
            [markerX - 13, trackY - 13, markerX + 13, trackY + 13]);
        DrawFormattedText(window, '0', trackLeft - 5, trackY + 28, [220 220 220]);
        DrawFormattedText(window, '100', trackRight - 25, trackY + 28, [220 220 220]);
        leftLabel = leftLabels{dimensionIdx};
        rightLabel = rightLabels{dimensionIdx};
        rightLabelBounds = Screen('TextBounds', window, double(rightLabel));
        Screen('DrawText', window, double(leftLabel), trackLeft, trackY + 75, [210 210 210]);
        Screen('DrawText', window, double(rightLabel), ...
            trackRight - rightLabelBounds(3), trackY + 75, [210 210 210]);
        Screen('FrameRect', window, [255 255 255], buttonRect, 2);
        DrawFormattedText(window, double('确认此评分并继续'), 'center', 'center', ...
            [255 255 255], [], [], [], [], buttonRect);
        Screen('Flip', window);
        WaitSecs(0.01);
    end
end

function showRest(window, exitKey)
    text = '请休息，稍后继续';
    Screen('FillRect', window, [0 0 0]);
    DrawFormattedText(window, double(text), 'center', 'center', [200 200 200]);
    Screen('Flip', window);
    waitWithEscape(10, exitKey);
end

function showEndScreen(window, exitKey)
    Screen('FillRect', window, [0 0 0]);
    DrawFormattedText(window, double('预实验结束，感谢参与！'), ...
        'center', 'center', [0 255 0]);
    Screen('Flip', window);
    waitWithEscape(3, exitKey);
end

function waitForKey(targetKey, exitKey)
    while true
        [keyDown, ~, keyCode] = KbCheck;
        if keyDown && keyCode(exitKey)
            error('Pretest:Aborted', 'Participant pressed ESC to stop the session.');
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
            error('Pretest:Aborted', 'Participant pressed ESC to stop the session.');
        end
        WaitSecs(0.01);
    end
end

function writeRatingsCsv(filename, subjectId, age, gender, ...
        trialOrder, ratings, completedTrials, sessionStatus)
    fid = fopen(filename, 'w', 'n', 'UTF-8');
    if fid < 0
        error('Pretest:CsvOpenFailed', 'Could not open output CSV: %s', filename);
    end
    fileGuard = onCleanup(@() fclose(fid));
    fprintf(fid, 'SubjectID,Age,Gender,Trial,Repeat,Odor,Intensity,Valence,Lightness,Familiarity,SessionStatus\n');
    repeatCounts = containers.Map({'CAR', 'GUA', 'CIN', 'PV'}, num2cell(zeros(1, 4)));
    for trialIdx = 1:completedTrials
        odor = trialOrder{trialIdx};
        repeatCounts(odor) = repeatCounts(odor) + 1;
        fprintf(fid, '%s,%s,%s,%d,%d,%s,%d,%d,%d,%d,%s\n', ...
            csvEscape(subjectId), csvEscape(age), csvEscape(gender), ...
            trialIdx, repeatCounts(odor), odor, ratings(trialIdx, 1), ...
            ratings(trialIdx, 2), ratings(trialIdx, 3), ratings(trialIdx, 4), ...
            sessionStatus);
    end
    clear fileGuard;
end

function filename = makeOutputPath(outputDir, subjectId)
    safeSubjectId = regexprep(subjectId, '[^A-Za-z0-9_-]', '_');
    timestamp = clock;
    milliseconds = floor(mod(now * 86400 * 1000, 1000));
    baseName = sprintf('odor_rating_%s_%04d%02d%02d_%02d%02d%02d_%03d', ...
        safeSubjectId, timestamp(1), timestamp(2), timestamp(3), ...
        timestamp(4), timestamp(5), floor(timestamp(6)), milliseconds);
    filename = fullfile(outputDir, [baseName '.csv']);
    suffix = 1;
    while exist(filename, 'file') == 2
        filename = fullfile(outputDir, sprintf('%s_%d.csv', baseName, suffix));
        suffix = suffix + 1;
    end
end

function escaped = csvEscape(value)
    escaped = ['"' strrep(char(value), '"', '""') '"'];
end

function inside = IsInRect(x, y, rect)
    inside = x >= rect(1) && x <= rect(3) && y >= rect(2) && y <= rect(4);
end

function cleanupExperiment(ettPort, window)
    if ~isempty(ettPort)
        try
            ett('set', ettPort, 0);
        catch cleanupError
            warning('Pretest:ValveCleanupFailed', ...
                'Could not close all olfactometer valves: %s', cleanupError.message);
        end
        try
            ett('close', ettPort);
        catch cleanupError
            warning('Pretest:PortCleanupFailed', ...
                'Could not close the olfactometer serial port: %s', cleanupError.message);
        end
        try
            delete(ettPort);
        catch cleanupError
            warning('Pretest:PortDeleteFailed', ...
                'Could not release the olfactometer serial object: %s', cleanupError.message);
        end
    end
    if ~isempty(window)
        Screen('CloseAll');
        ShowCursor;
    end
end
