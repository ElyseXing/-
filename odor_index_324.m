function odor_rating_experiment()
    % 气味评分实验（6种气味，4个维度，评分1-7）
    % 使用ETT设备控制阀门，集成十字注视点与气味同eeee步

    clear; clc; close all;

    % ==================== 1. 获取被试信息 ====================
    prompt = {'被试编号:', '年龄:', '性别 (男/女):'};
    dlgtitle = '输入被试信息';
    dims = [1 35];
    definput = {'', '', ''};
    answer = inputdlg(prompt, dlgtitle, dims, definput);
    if isempty(answer)eeee
        error('用户取消输入');
    end
    subject_id = answer{1};
    age = answer{2};
    gender = answer{3};
    if isempty(subject_id) || isempty(age) || isempty(gender)
        error('被试信息不能为空，请重新运行实验并完整填写。');
    end

    % ==================== 2. 初始化Psychtoolbox ====================
    Screen('Preference', 'SkipSyncTests', 1);   % 调试用，正式实验建议eeeeee删除
    KbName('UnifyKeyNames');

    % 按键设置
    p_key = KbName('p');               % 继续键
    exitKey = KbName('ESCAPE');        % 退出键
    left_key = KbName('leftarrow');    % 减小评分
    right_key = KbName('rightarrow');  % 增加评分
    up_key = KbName('uparrow');        % 上一维度
    down_key = KbName('downarrow');    % 下一维度
    confirm_key = KbName('e');         % 确认当前维度

    % 打开窗口
    whichscreen = max(Screen('Screens'));
    backcolor = [0 0 0];
    [window, rect] = Screen('OpenWindow', whichscreen, backcolor);
    HideCursor;

    % ==================== 3. ETT设备初始化 ====================
    fprintf('初始化ETT设备...\n');
    try
        ETTMat_init;    % 加载ETT驱动
        DeviceList = Device.ScanDeviceList;
        if DeviceList.Count < 1 || DeviceList.Item(0) == ""
            error('没有找到ETT设备，请连接设备后重试！');
        end
        fprintf('找到 %d 个设备:\n', DeviceList.Count);
        for n = 0:DeviceList.Count-1
            deviceProperties = DeviceList.Item(n).Split('.');
            fprintf('设备 %d: ID: %s, 名称: %s, 类型: %s\n', ...
                n+1, deviceProperties(1), deviceProperties(2), deviceProperties(3));
        end
        ett_device = Device;
        ett_device.CloseAllChannels();
        fprintf('ETT初始化完成\n');
    catch ME
        Screen('CloseAll');
        ShowCursor;
        rethrow(ME);
    end

    % ==================== 4. 显示三页指导语（分开独立等待p键） ====================
    show_instruction_page1(window, rect, p_key, exitKey);
    show_instruction_page2(window, rect, p_key, exitKey);
    show_instruction_page3(window, rect, p_key, exitKey);

    % ==================== 5. 实验参数 ====================
    odors = {'CIN', 'CAR', 'ACE', 'IP', 'PV', 'GUA'};
    num_odors = length(odors);
    trial_order = randperm(num_odors);
    odors_shuffled = odors(trial_order);

    dimensions = {'熟悉性', '愉悦性', '强度', '沉闷轻盈'};
    num_dimensions = 4;
    rating_min = 1;
    rating_max = 7;
    rating_mid = 4;

    colors.white = [255 255 255];
    colors.gray = [150 150 150];
    colors.yellow = [255 255 0];
    colors.green = [0 255 0];
    colors.active = [0 255 0];      % 当前激活的评分轴颜色
    colors.inactive = [100 100 100]; % 非激活的评分轴颜色
    colors.current_dim = [255 255 0]; % 当前选中的维度名称颜色
    colors.confirmed = [255 150 0];  % 已确认维度的评分轴颜色

    % 注视点持续时间（秒），每个阶段均为4秒
    fixation_duration = 4.0;

    all_ratings = cell(num_odors, 1);

    try
        % ==================== 6. 实验主循环 ====================
        for trial_idx = 1:num_odors
            current_odor = odors_shuffled{trial_idx};
            valve_idx = find(strcmp(odors, current_odor));
            fprintf('\n=== 试次 %d/%d: 气味 %s (阀门%d) ===\n', trial_idx, num_odors, current_odor, valve_idx);

            % 6.1 气味提示界面（4秒）
            show_odor_prompt(window, rect, current_odor, 4.0, p_key, exitKey);

            % 6.2 十字注视点变色（白→黄→绿）各4秒，绿色期间打开阀门
            fixation_and_valve(window, rect, valve_idx, fixation_duration, exitKey, ett_device);

            % 6.3 评分界面
            ratings = show_rating_interface(window, rect, current_odor, dimensions, ...
                rating_min, rating_max, rating_mid, ...
                left_key, right_key, up_key, down_key, confirm_key, exitKey, colors);

            all_ratings{trial_idx} = struct('odor', current_odor, 'ratings', ratings);
            fprintf('气味 %s 评分: 熟悉性=%d, 愉悦性=%d, 强度=%d, 沉闷轻盈=%d\n', ...
                current_odor, ratings(1), ratings(2), ratings(3), ratings(4));

            % 6.4 试次间休息（10秒）
            if trial_idx < num_odors
                show_rest_interval(window, rect, 10.0);
            end
        end

        % ==================== 7. 实验结束 ====================
        show_end_screen(window, rect);
        save_ratings_data(all_ratings, odors_shuffled, dimensions, subject_id, age, gender, trial_order);

        % 关闭所有阀门并清理
        ett_device.CloseAllChannels();
        Screen('CloseAll');
        ShowCursor;
        fprintf('实验完成！\n');

    catch ME
        % 错误处理：确保阀门关闭
        if exist('ett_device', 'var')
            ett_device.CloseAllChannels();
        end
        Screen('CloseAll');
        ShowCursor;
        rethrow(ME);
    end
end


% ==================== 辅助函数 ====================

% --- 第一页指导语：任务说明（使用双引号确保\n换行）---
function show_instruction_page1(window, rect, p_key, exitKey)
    white = [255 255 255];
    instruction_color = [255 255 100];
    text = sprintf('接下来，你将闻到一些气味，并分别对他们进行打分。\n\n气味的评分范围是1分到7分，\n1分代表最低值，7分代表最高值，4分为中间值。\n\n键盘左键减少评分，右键增加评分，\n按e确认当前维度后，评分轴颜色将出现变化，\n随后自动切换至下一个评分维度。\n你也可以使用键盘上下键切换打分维度。\n\n（按p继续）');
    draw_centered_text(window, rect, text, white);
    draw_bottom_prompt(window, rect, "按p继续", instruction_color);
    Screen('Flip', window);
    wait_for_key(p_key, exitKey);
end

% --- 第二页指导语：维度解释 ---
function show_instruction_page2(window, rect, p_key, exitKey)
    white = [255 255 255];
    instruction_color = [255 255 100];
    text = sprintf(['熟悉性：在之前的生活中，你是否闻到过类似的气味、它能否让你回想起某段回忆、特定的情景或物品。\n' ...
    '1分代表非常陌生，7分代表非常熟悉。\n\n' ...
    '愉悦性：这个气味好不好闻。\n' ...
    '1分代表非常难闻，7分代表非常好闻。\n\n' ...
    '强度：这个气味的浓或者淡，类似声音的音量大小。\n' ...
    '1分代表这个气味非常淡、几乎闻不到，7分代表这个气味很浓郁。\n\n' ...
    '沉闷轻盈：可以类比声音的音调。\n' ...
    '1分代表这个气味感知起来很沉闷，就像声音中的低音一样；\n' ...
    '7分代表这个气味感知起来很轻盈、明亮，就像声音中的高音一样。\n\n' ...
    '（按p继续）']);
    draw_centered_text(window, rect, text, white);
    draw_bottom_prompt(window, rect, "按p继续", instruction_color);
    Screen('Flip', window);
    wait_for_key(p_key, exitKey);
end

% --- 第三页指导语：注视点提示 ---
function show_instruction_page3(window, rect, p_key, exitKey)
    white = [255 255 255];
    instruction_color = [255 255 100];
    text = sprintf('白色注视点变黄提示集中注意，变绿时开始吸气，\n注意只有当注视点是绿色时你会闻到气味。\n\n准备好后请按p开始实验。');
    draw_centered_text(window, rect, text, white);
    draw_bottom_prompt(window, rect, "按p开始实验", instruction_color);
    Screen('Flip', window);
    wait_for_key(p_key, exitKey);
end

% --- 气味提示界面（持续指定秒数）---
function show_odor_prompt(window, rect, odor_name, duration, p_key, exitKey)
    white = [255 255 255];
    Screen('TextSize', window, round(rect(4)/30));
    Screen('TextFont', window, 'SimHei');
    Screen('FillRect', window, [0 0 0], rect);

    odor_text = sprintf('接下来你将闻到气味%s', odor_name);
    odorRect = Screen('TextBounds', window, double(odor_text));
    odorX = rect(3)/2 - odorRect(3)/2;
    odorY = rect(4)/2;
    Screen('DrawText', window, double(odor_text), odorX, odorY, white);
    Screen('Flip', window);

    start_time = GetSecs;
    while (GetSecs - start_time) < duration
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown && keyCode(exitKey)
            error('用户提前终止实验');
        end
        WaitSecs(0.01);
    end
end

% --- 十字注视点变色 + 阀门控制（白→黄→绿，各4秒）---
function fixation_and_valve(window, rect, valve_idx, duration, exitKey, ett_device)
    screen_center = [rect(3)/2, rect(4)/2];
    line_len = 30;
    line_width = 3;
    % 十字线四个端点的坐标：水平左、水平右、垂直上、垂直下
    cross_points = [screen_center(1)-line_len, screen_center(1)+line_len, screen_center(1), screen_center(1);
                    screen_center(2),            screen_center(2),            screen_center(2)-line_len, screen_center(2)+line_len];

    % 白色十字
    Screen('FillRect', window, [0 0 0], rect);
    Screen('DrawLines', window, cross_points, line_width, [255 255 255]);
    Screen('Flip', window);
    WaitSecs(duration);
    if check_esc(exitKey), error('用户中止'); end

    % 黄色十字
    Screen('FillRect', window, [0 0 0], rect);
    Screen('DrawLines', window, cross_points, line_width, [255 255 0]);
    Screen('Flip', window);
    WaitSecs(duration);
    if check_esc(exitKey), error('用户中止'); end

    % 绿色十字 + 打开阀门
    Screen('FillRect', window, [0 0 0], rect);
    Screen('DrawLines', window, cross_points, line_width, [0 255 0]);
    Screen('Flip', window);

    ett_device.CloseAllChannels();
    ett_device.SetChannel(valve_idx, true);
    odor_start = GetSecs;

    while GetSecs - odor_start < duration
        if check_esc(exitKey)
            ett_device.CloseAllChannels();
            error('用户提前终止实验');
        end
        WaitSecs(0.01);
    end

    ett_device.CloseAllChannels();
end

% --- 检查ESC键 ---
function pressed = check_esc(exitKey)
    [keyIsDown, ~, keyCode] = KbCheck;
    pressed = keyIsDown && keyCode(exitKey);
end

% --- 评分界面（手动分行，避免DrawFormattedText错误）---
function ratings = show_rating_interface(window, rect, odor_name, dimensions, ...
    min_val, max_val, init_val, ...
    left_key, right_key, up_key, down_key, confirm_key, exitKey, colors)

    num_dims = length(dimensions);
    ratings = ones(1, num_dims) * init_val;
    confirmed = false(1, num_dims);
    current_dim = 1;

    screen_width = rect(3);
    screen_height = rect(4);
    dim_height = 120;
    rating_area_start_y = screen_height/2 - (num_dims * dim_height)/2 + 50;
    axis_left_x = screen_width * 0.2;
    axis_right_x = screen_width * 0.8;
    axis_width = axis_right_x - axis_left_x;

    while ~all(confirmed)
        Screen('FillRect', window, [0 0 0], rect);

        % 标题
        Screen('TextSize', window, round(screen_height/35));
        title_text = sprintf('请为气味 %s 评分', odor_name);
        titleRect = Screen('TextBounds', window, double(title_text));
        title_x = screen_width/2 - titleRect(3)/2;
        Screen('DrawText', window, double(title_text), title_x, 80, colors.white);

        % 绘制每个维度
        for dim = 1:num_dims
            y = rating_area_start_y + (dim-1) * dim_height;

            % 维度名称
            dim_text = dimensions{dim};
            if dim == current_dim
                dim_color = colors.current_dim;
            else
                dim_color = colors.white;
            end
            Screen('TextSize', window, round(screen_height/40));
            dimRect = Screen('TextBounds', window, double(dim_text));
            Screen('DrawText', window, double(dim_text), 50, y, dim_color);

            % 评分轴
            axis_y = y + 30;
            if dim == current_dim
                if confirmed(dim)
                    axis_color = colors.confirmed;
                else
                    axis_color = colors.active;
                end
            else
                axis_color = colors.inactive;
            end
            Screen('DrawLine', window, axis_color, axis_left_x, axis_y, axis_right_x, axis_y, 2);

            % 刻度和刻度值
            for val = min_val:max_val
                x = axis_left_x + (val - min_val)/(max_val - min_val) * axis_width;
                Screen('DrawLine', window, axis_color, x, axis_y-5, x, axis_y+5, 1);
                if val == min_val || val == max_val || val == 4
                    Screen('TextSize', window, round(screen_height/50));
                    text_x = x - 8;
                    if val == min_val
                        text_x = x;
                    elseif val == max_val
                        text_x = x - 15;
                    end
                    DrawFormattedText(window, num2str(val), text_x, axis_y+20, axis_color);
                end
            end

            % 评分点
            rating = ratings(dim);
            x_pos = axis_left_x + (rating - min_val)/(max_val - min_val) * axis_width;
            point_size = 10;
            if dim == current_dim
                if confirmed(dim)
                    point_color = colors.confirmed;
                else
                    point_color = colors.active;
                end
            else
                point_color = colors.inactive;
            end
            Screen('FillOval', window, point_color, ...
                [x_pos-point_size, axis_y-point_size, x_pos+point_size, axis_y+point_size]);

            % 显示当前分值
            if dim == current_dim && ~confirmed(dim)
                Screen('TextSize', window, round(screen_height/40));
                rating_text = num2str(rating);
                ratingRect = Screen('TextBounds', window, rating_text);
                Screen('DrawText', window, rating_text, ...
                    x_pos - ratingRect(3)/2, axis_y-35, point_color);
            end
        end

        % 底部说明（手动分行）
        Screen('TextSize', window, round(screen_height/50));
        bottom_lines = { ...
            '1分代表最低值，7分代表最高值。', ...
            '键盘左键减少评分，右键增加评分，按e确认当前维度。', ...
            '键盘上下键切换打分维度。' ...
        };
        line_height = round(screen_height/30);
        start_y = screen_height - length(bottom_lines)*line_height - 20;
        for i = 1:length(bottom_lines)
            line = bottom_lines{i};
            lineRect = Screen('TextBounds', window, double(line));
            line_x = screen_width/2 - lineRect(3)/2;
            line_y = start_y + (i-1)*line_height;
            Screen('DrawText', window, double(line), line_x, line_y, [200 200 100]);
        end

        Screen('Flip', window);

        % 按键响应
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown
            if keyCode(exitKey)
                error('用户提前终止实验');
            elseif keyCode(left_key) && ~confirmed(current_dim)
                if ratings(current_dim) > min_val
                    ratings(current_dim) = ratings(current_dim) - 1;
                end
                WaitSecs(0.15);
            elseif keyCode(right_key) && ~confirmed(current_dim)
                if ratings(current_dim) < max_val
                    ratings(current_dim) = ratings(current_dim) + 1;
                end
                WaitSecs(0.15);
            elseif keyCode(up_key)
                new_dim = current_dim - 1;
                if new_dim < 1, new_dim = num_dims; end
                current_dim = new_dim;
                WaitSecs(0.2);
            elseif keyCode(down_key)
                new_dim = current_dim + 1;
                if new_dim > num_dims, new_dim = 1; end
                current_dim = new_dim;
                WaitSecs(0.2);
            elseif keyCode(confirm_key)
                if ~confirmed(current_dim)
                    confirmed(current_dim) = true;
                    for offset = 1:num_dims
                        next_dim = mod(current_dim + offset - 1, num_dims) + 1;
                        if ~confirmed(next_dim)
                            current_dim = next_dim;
                            break;
                        end
                    end
                    WaitSecs(0.2);
                end
            end
        end
        WaitSecs(0.01);
    end
end

% --- 试次间休息 ---
function show_rest_interval(window, rect, duration)
    Screen('FillRect', window, [0 0 0], rect);
    Screen('TextSize', window, round(rect(4)/30));
    Screen('TextFont', window, 'SimHei');
    rest_text = '请休息一会并等待实验继续';
    restRect = Screen('TextBounds', window, double(rest_text));
    Screen('DrawText', window, double(rest_text), ...
        rect(3)/2 - restRect(3)/2, rect(4)/2, [200 200 200]);
    Screen('Flip', window);
    WaitSecs(duration);
end

% --- 实验结束界面 ---
function show_end_screen(window, rect)
    Screen('FillRect', window, [0 0 0], rect);
    Screen('TextSize', window, round(rect(4)/30));
    Screen('TextFont', window, 'SimHei');
    end_text = '实验结束，感谢您的参与！';
    endRect = Screen('TextBounds', window, double(end_text));
    Screen('DrawText', window, double(end_text), ...
        rect(3)/2 - endRect(3)/2, rect(4)/2, [0 255 0]);
    Screen('Flip', window);
    WaitSecs(3.0);
end

% --- 保存数据到CSV ---
function save_ratings_data(all_ratings, odors_shuffled, dimensions, subject_id, age, gender, trial_order)
    filename = sprintf('odor_ratings_%s_%s.csv', subject_id, datestr(now, 'yyyymmdd_HHMMSS'));
    fid = fopen(filename, 'w', 'n', 'UTF-8');
    fprintf(fid, 'SubjectID,Age,Gender,TrialOrder,Odor,');
    for i = 1:length(dimensions)
        fprintf(fid, '%s,', dimensions{i});
    end
    fprintf(fid, '\n');

    for idx = 1:length(all_ratings)
        odor = all_ratings{idx}.odor;
        ratings = all_ratings{idx}.ratings;
        fprintf(fid, '%s,%s,%s,%d,%s,', subject_id, age, gender, trial_order(idx), odor);
        for j = 1:length(ratings)
            fprintf(fid, '%d,', ratings(j));
        end
        fprintf(fid, '\n');
    end

    fclose(fid);
    fprintf('数据已保存至: %s\n', filename);

    fprintf('\n=== 评分汇总 ===\n');
    fprintf('被试: %s, 年龄: %s, 性别: %s\n', subject_id, age, gender);
    fprintf('试次顺序: ');
    for i = 1:length(odors_shuffled)
        fprintf('%s ', odors_shuffled{i});
    end
    fprintf('\n');
    for idx = 1:length(all_ratings)
        odor = all_ratings{idx}.odor;
        ratings = all_ratings{idx}.ratings;
        fprintf('%s: 熟悉性=%d 愉悦性=%d 强度=%d 沉闷轻盈=%d\n', odor, ratings(1), ratings(2), ratings(3), ratings(4));
    end
end

% --- 辅助：绘制多行文本（支持换行）---
function draw_centered_text(window, rect, text, color)
    % 按换行符分割
    lines = strsplit(text, '\n');
    Screen('TextSize', window, round(rect(4)/40));
    Screen('TextFont', window, 'SimHei');
    line_height = round(rect(4)/30);
    total_height = length(lines) * line_height;
    start_y = rect(4)/2 - total_height/2;
    for i = 1:length(lines)
        line = lines{i};
        if isempty(line), continue; end
        lineRect = Screen('TextBounds', window, double(line));
        line_x = rect(3)/2 - lineRect(3)/2;
        line_y = start_y + (i-1) * line_height;
        Screen('DrawText', window, double(line), line_x, line_y, color);
    end
end

% --- 辅助：底部提示 ---
function draw_bottom_prompt(window, rect, text, color)
    Screen('TextSize', window, round(rect(4)/50));
    promptRect = Screen('TextBounds', window, double(text));
    Screen('DrawText', window, double(text), ...
        rect(3)/2 - promptRect(3)/2, rect(4)*0.9, color);
end

% --- 辅助：等待按键（带清空缓冲区，避免多个页面同时跳过）---
function wait_for_key(targetKey, exitKey)
    % 清空键盘缓冲区，确保之前按键不会影响
    while KbCheck; end
    while true
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown
            if keyCode(targetKey)
                % 释放按键后退出
                while KbCheck; end
                break;
            elseif keyCode(exitKey)
                error('用户提前终止实验');
            end
        end
        WaitSecs(0.01);
    end
end