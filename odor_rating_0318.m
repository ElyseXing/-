function odor_rating_experiment_with_random_sequence()
    % 气味评分实验 - 使用随机生成的试次顺序
    % 修改：增加被试信息输入框，并将信息记录到CSV文件

    clear; clc; close all;

    % ========== 新增：获取被试信息 ==========
    prompt = {'被试编号:', '年龄:', '性别 (男/女):'};ep
    dlgtitle = '输入被试信息';
    dims = [1 35];
    definput = {'', '', ''};
    answer = inputdlg(prompt, dlgtitle, dims, definput);
    if isempty(answer)
        error('用户取消输入');
    end
    subject_id = answer{1};
    age = answer{2};
    gender = answer{3};
    if isempty(subject_id) || isempty(age) || isempty(gender)
        error('被试信息不能为空，请重新运行实验并完整填写。');
    end
    % =======================================

    Screen('Preference','SkipSyncTests',1);
    KbName('UnifyKeyNames');

    % 按键设置
    p_key = KbName('p');
    exitKey = KbName('ESCAPE');
    left_key = KbName('leftarrow');
    right_key = KbName('rightarrow');
    up_key = KbName('uparrow');
    down_key = KbName('downarrow');
    confirm_key = KbName('e');

    % 打开窗口
    whichscreen = max(Screen('Screens'));
    backcolor = [0 0 0];
    [window, rect] = Screen('OpenWindow', whichscreen, backcolor);
    HideCursor;

    % 显示实验指导语
    show_instruction_screen(window, rect, confirm_key, exitKey);

    % 生成随机试次顺序
    [trial_sequence, sequence_info] = generate_final_trial_sequence();

    % 从sequence_info中提取block顺序
    for block_idx = 1:9
        block_sequence{block_idx} = sequence_info.compact_str((block_idx-1)*2+1:block_idx*2);
    end

    % 定义每个block的气味顺序映射
    block_patterns = struct();
    block_patterns.A1 = {'EGM', 'MIC', 'PCE'};  % 显示顺序从左到右是a1, a2, a3
    block_patterns.A2 = {'PCE', 'EGM', 'MIC'};
    block_patterns.A3 = {'MIC', 'PCE', 'EGM'};

    block_patterns.B1 = {'CGA', 'IME', 'NOP'};  % 显示顺序从左到右是b1, b2, b3
    block_patterns.B2 = {'NOP', 'CGA', 'IME'};
    block_patterns.B3 = {'IME', 'NOP', 'CGA'};

    block_patterns.C1 = {'AMI', 'OCP', 'BCM'};  % 显示顺序从左到右是c1, c2, c3
    block_patterns.C2 = {'BCM', 'AMI', 'OCP'};
    block_patterns.C3 = {'OCP', 'BCM', 'AMI'};

    % 评分维度
    dimensions = {'熟悉性', '愉悦性', '强度', '复杂度'};
    num_dimensions = 4;

    % 评分范围
    rating_min = 1;
    rating_max = 5;

    % 颜色定义
    colors.white = [255 255 255];
    colors.gray = [150 150 150];
    colors.active = [0 255 0];      % 当前激活的评分轴颜色
    colors.inactive = [100 100 100]; % 非激活的评分轴颜色
    colors.axis = [200 200 200];    % 坐标轴颜色
    colors.odor1 = [255 100 100];   % 第一个气味颜色
    colors.odor2 = [100 255 100];   % 第二个气味颜色
    colors.odor3 = [100 100 255];   % 第三个气味颜色
    colors.current = [255 255 0];   % 当前维度的颜色
    colors.confirmed = [255 150 0]; % 已确认的颜色

    try
        % 存储所有评分结果（每个block独立）
        all_block_ratings = cell(9, 1);  % 每个block的评分

        % 实验主循环
        for block_idx = 1:9
            current_block = block_sequence{block_idx};
            block_type = current_block(1);  % A, B, 或 C
            block_pattern = current_block(2);  % 1, 2, 或 3

            fprintf('\n=== Block %d: %s ===\n', block_idx, current_block);

            % 获取当前block的三个气味
            trials = block_patterns.(current_block);
            fprintf('气味顺序: %s, %s, %s\n', trials{1}, trials{2}, trials{3});

            % 为当前block创建新的评分结构
            block_ratings = struct();
            for i = 1:3
                odor_name = trials{i};
                % 初始化为中间值3
                block_ratings.(odor_name) = ones(1, num_dimensions) * 3;
            end

            % 逐个处理当前block的三个气味
            for trial_in_block = 1:3
                current_trial = trials{trial_in_block};

                % 1. 显示气味提示界面
                fprintf('试次 %d/%d: 气味 %s\n', trial_in_block, 3, current_trial);
                show_odor_prompt(window, rect, current_trial, p_key, exitKey);

                % 2. 显示评分界面
                ratings = show_rating_interface(window, rect, ...
                    current_block, current_trial, trials, dimensions, ...
                    rating_min, rating_max, block_ratings, ...
                    left_key, right_key, up_key, down_key, confirm_key, exitKey, colors);

                % 保存评分结果到当前block
                block_ratings.(current_trial) = ratings;
                fprintf('气味 %s 评分: %s\n', current_trial, mat2str(ratings));

                % 3. 短暂休息（除了最后一个试次）
                if trial_in_block < 3
                    show_inter_trial_interval(window, rect);
                end
            end

            % 保存当前block的评分
            all_block_ratings{block_idx} = block_ratings;

            % block间休息（除了最后一个block）
            if block_idx < 9
                show_block_interval(window, rect, block_idx);
            end
        end

        % 实验结束
        show_end_screen(window, rect);

        % ========== 修改：传递被试信息给保存函数 ==========
        save_block_ratings_data(all_block_ratings, block_sequence, dimensions, block_patterns, sequence_info, ...
                                subject_id, age, gender);
        % ================================================

        % 清理资源
        Screen('CloseAll');
        ShowCursor;
        fprintf('实验完成！\n');

    catch ME
        % 错误处理
        Screen('CloseAll');
        ShowCursor;
        rethrow(ME);
    end
end


% 指导语界面函数
function show_instruction_screen(window, rect, confirm_key, exitKey)
    % 显示实验指导语界面

    white = [255 255 255];
    instruction_color = [255 255 100];  % 黄色用于按键提示

    Screen('TextSize', window, round(rect(4)/40));  % 稍微小一点的字号
    Screen('TextFont', window, 'SimHei');

    % 指导语内容
    instruction_text = [
        '欢迎参加今天的实验\n\n'...
        '在实验中您将对一些气味混合物进行评分。\n'...
        '评分的维度包括熟悉性、愉悦性、强度和复杂度。\n\n'...
        '评分范围为1~5分，其中1分为最低分，5分为最高分，3分为中间值。\n\n'...
        '按下键盘左右键调整评分大小，\n'...
        '按下e键确认该维度评分，\n'...
        '按下键盘上下键切换评分维度。\n\n'...
        '请根据主试和屏幕上的提示进行操作。\n\n'...
        '准备好后请耐心等待主试开始。'];

    % 计算文本边界
    textRect = Screen('TextBounds', window, double(instruction_text));

    % 如果文本太高，可能需要分段显示
    if textRect(4) > rect(4) * 0.8
        % 分段显示指导语
        instruction_lines = {
            '欢迎参加今天的实验';
            '';
            '在实验中您将对一些气味混合物进行评分。';
            '评分的维度包括熟悉性、愉悦性、强度和复杂度。';
            '';
            '评分范围为1~5分，其中1分为最低分，5分为最高分，3分为中间值。';
            '';
            '按下键盘左右键调整评分大小，';
            '按下e键确认该维度评分，';
            '按下键盘上下键切换评分维度。';
            '';
            '请根据主试和屏幕上的提示进行操作。';
            '';
            '准备好后请耐心等待主试开始。';
        };

        % 清屏
        Screen('FillRect', window, [0 0 0], rect);

        % 绘制每一行
        line_height = round(rect(4)/30);
        start_y = rect(4) * 0.1;

        for i = 1:length(instruction_lines)
            line_text = instruction_lines{i};
            if isempty(line_text)
                % 空行
                start_y = start_y + line_height;
            else
                lineRect = Screen('TextBounds', window, double(line_text));
                line_x = rect(3)/2 - lineRect(3)/2;
                Screen('DrawText', window, double(line_text), line_x, start_y, white);
                start_y = start_y + line_height;
            end
        end

    else
        % 单次显示所有指导语
        Screen('FillRect', window, [0 0 0], rect);
        DrawFormattedText(window, double(instruction_text), 'center', 'center', white);
    end

    % 添加按键提示
    Screen('TextSize', window, round(rect(4)/50));
    prompt_text = '按e键继续';
    promptRect = Screen('TextBounds', window, double(prompt_text));
    Screen('DrawText', window, double(prompt_text), ...
        rect(3)/2 - promptRect(3)/2, rect(4) * 0.9, instruction_color);

    Screen('Flip', window);

    % 等待空格键
    fprintf('显示指导语界面，等待按e键开始实验...\n');
    while true
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown
            if keyCode(confirm_key)
                fprintf('e键被按下，开始实验\n');
                break;
            elseif keyCode(exitKey)
                fprintf('ESC键被按下，退出实验\n');
                error('用户提前终止实验');
            end
        end
        WaitSecs(0.01);
    end
end

function show_odor_prompt(window, rect, odor_name, p_key, exitKey)
    % 显示气味提示界面

    white = [255 255 255];
    instruction_color = [255 255 100];

    Screen('TextSize', window, round(rect(4)/30));
    Screen('TextFont', window, 'SimHei');

    % 清屏
    Screen('FillRect', window, [0 0 0], rect);

    % 气味文本
    odor_text = sprintf('下面你将闻到气味%s', odor_name);
    odorRect = Screen('TextBounds', window, double(odor_text));
    odorX = rect(3)/2 - odorRect(3)/2;
    odorY = rect(4)/2 - 50;
    Screen('DrawText', window, double(odor_text), odorX, odorY, white);

    % 提示文本
    prompt_text = '请找到对应嗅笔，并按下p键继续';
    promptRect = Screen('TextBounds', window, double(prompt_text));
    promptX = rect(3)/2 - promptRect(3)/2;
    promptY = odorY + 80;
    Screen('DrawText', window, double(prompt_text), promptX, promptY, white);

    Screen('Flip', window);

    % 等待P键
    while true
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown
            if keyCode(p_key)
                break;
            elseif keyCode(exitKey)
                error('用户提前终止实验');
            end
        end
        WaitSecs(0.01);
    end
end

function ratings = show_rating_interface(window, rect, ...
    current_block, current_trial, trials, dimensions, ...
    min_val, max_val, block_ratings, ...
    left_key, right_key, up_key, down_key, confirm_key, exitKey, colors)

    % 显示评分界面
    % 显示当前block的三个气味评分轴，但只能操作当前试次的气味
    % block_ratings: 当前block内的评分数据

    num_dims = length(dimensions);
    num_odors = 3;

    % 获取当前气味在所有气味列表中的索引
    current_odor_idx = find(strcmp(trials, current_trial));

    % 初始化评分
    ratings = block_ratings.(current_trial);

    % 记录每个维度是否已确认
    confirmed = false(1, num_dims);

    % 当前选择的维度
    current_dim = 1;

    % 屏幕布局参数
    screen_width = rect(3);
    screen_height = rect(4);

    % 标题区域
    title_y = 50;

    % 气味标签区域
    odor_label_y = 120;

    % 评分区域
    rating_start_y = 180;
    rating_height = 400;
    dim_spacing = rating_height / num_dims;

    % 每个气味的评分轴宽度
    axis_width = screen_width * 0.2;

    % 主循环
    while ~all(confirmed)
        % 清屏
        Screen('FillRect', window, [0 0 0], rect);

        % 绘制标题
        Screen('TextSize', window, round(screen_height/35));
        Screen('TextFont', window, 'SimHei');

        title_text = sprintf('请为气味 %s 评分', current_trial);
        titleRect = Screen('TextBounds', window, double(title_text));
        Screen('DrawText', window, double(title_text), ...
            screen_width/2 - titleRect(3)/2, 80, colors.white);

        % 绘制三个气味标签
        Screen('TextSize', window, round(screen_height/35));

        for odor_idx = 1:num_odors
            odor_name = trials{odor_idx};

            % 选择颜色
            if strcmp(odor_name, current_trial)
                % 当前试次的气味
                if all(confirmed)
                    odor_color = colors.confirmed;
                else
                    odor_color = colors.active;
                end
            else
                % 同block的其他气味
                odor_color = colors.inactive;
            end

            % 计算水平位置
            if odor_idx == 1
                odor_x = screen_width * 0.2;
            elseif odor_idx == 2
                odor_x = screen_width * 0.5;
            else
                odor_x = screen_width * 0.8;
            end

            % 绘制气味标签
            odor_text = odor_name;
            odorRect = Screen('TextBounds', window, double(odor_text));
            odor_x_center = odor_x - odorRect(3)/2;

            Screen('DrawText', window, double(odor_text), ...
                odor_x_center, 180, odor_color);
        end

        % 重新计算评分区域的起始位置，使其垂直居中
        rating_area_height = num_dims * 100;
        rating_start_y = screen_height/2 - rating_area_height/2;

        % 绘制评分维度
        for dim_idx = 1:num_dims
            dim_y = rating_start_y + (dim_idx-1) * 100;

            % 绘制维度名称
            dim_text = dimensions{dim_idx};
            if dim_idx == current_dim
                dim_color = colors.current;
            else
                dim_color = colors.white;
            end

            Screen('TextSize', window, round(screen_height/40));
            dimRect = Screen('TextBounds', window, double(dim_text));
            Screen('DrawText', window, double(dim_text), 50, dim_y, dim_color);

            % 绘制三个气味的评分轴
            for odor_idx = 1:num_odors
                odor_name = trials{odor_idx};

                % 计算水平位置
                if odor_idx == 1
                    axis_x = screen_width * 0.2;
                elseif odor_idx == 2
                    axis_x = screen_width * 0.5;
                else
                    axis_x = screen_width * 0.8;
                end

                axis_x_start = axis_x - axis_width/2;
                axis_x_end = axis_x + axis_width/2;
                axis_y = dim_y + 30;

                % 获取这个气味的评分
                if strcmp(odor_name, current_trial)
                    % 当前试次的气味
                    odor_rating = ratings(dim_idx);
                else
                    % 同block的其他气味
                    odor_rating = block_ratings.(odor_name)(dim_idx);
                end

                % 确定轴的颜色
                if strcmp(odor_name, current_trial)
                    if confirmed(dim_idx)
                        axis_color = colors.confirmed;
                    else
                        axis_color = colors.active;
                    end
                else
                    axis_color = colors.inactive;
                end

                % 绘制坐标轴
                Screen('DrawLine', window, axis_color, ...
                    axis_x_start, axis_y, axis_x_end, axis_y, 2);

                % 绘制刻度
                for val = min_val:max_val
                    x_pos = axis_x_start + (val-min_val)/(max_val-min_val) * axis_width;

                    % 刻度线
                    Screen('DrawLine', window, axis_color, ...
                        x_pos, axis_y-5, x_pos, axis_y+5, 1);

                    % 刻度值
                    if val == min_val || val == max_val
                        Screen('TextSize', window, round(screen_height/50));
                        if val == min_val
                            text_x = x_pos;
                        else
                            text_x = x_pos - 10;
                        end
                        DrawFormattedText(window, num2str(val), text_x, axis_y+20, axis_color);
                    end
                end

                % 绘制评分点
                if strcmp(odor_name, current_trial)
                    if confirmed(dim_idx)
                        point_color = colors.confirmed;
                    else
                        point_color = colors.active;
                    end
                else
                    point_color = colors.inactive;
                end

                x_pos = axis_x_start + (odor_rating-min_val)/(max_val-min_val) * axis_width;

                % 绘制评分点
                point_size = 8;
                Screen('FillOval', window, point_color, ...
                    [x_pos-point_size, axis_y-point_size, ...
                     x_pos+point_size, axis_y+point_size]);

                % 如果是当前气味和当前维度，显示评分值
                if strcmp(odor_name, current_trial) && dim_idx == current_dim
                    Screen('TextSize', window, round(screen_height/40));
                    rating_text = num2str(odor_rating);
                    ratingRect = Screen('TextBounds', window, rating_text);
                    Screen('DrawText', window, rating_text, ...
                        x_pos-ratingRect(3)/2, axis_y-35, point_color);
                end
            end
        end

        % 绘制控制说明
        Screen('TextSize', window, round(screen_height/50));

        if all(confirmed)
            control_text = '当前气味评分完成，按e键继续';
        else
            control_text = '按←→键调整评分，按↑↓键切换维度，按e键确认当前维度';
        end

        DrawFormattedText(window, double(control_text), 'center', screen_height-100, [200 200 100]);

        % 添加评分说明
        rating_instruction = '评分说明：1分为最小值，5分为最大值，3分为中间值';
        DrawFormattedText(window, double(rating_instruction), 'center', screen_height-60, [200 200 100]);

        Screen('Flip', window);

        % 检查按键
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
                current_dim = mod(current_dim - 2, num_dims) + 1;
                WaitSecs(0.2);
            elseif keyCode(down_key)
                current_dim = mod(current_dim, num_dims) + 1;
                WaitSecs(0.2);
            elseif keyCode(confirm_key)
                confirmed(current_dim) = true;

                if all(confirmed)
                    break;
                end

                for dim_offset = 1:num_dims
                    next_dim = mod(current_dim + dim_offset - 1, num_dims) + 1;
                    if ~confirmed(next_dim)
                        current_dim = next_dim;
                        break;
                    end
                end
                WaitSecs(0.2);
            end
        end
        WaitSecs(0.01);
    end
end

function show_inter_trial_interval(window, rect)
    % 显示试次间间隔

    Screen('FillRect', window, [0 0 0], rect);
    Screen('TextSize', window, round(rect(4)/30));
    Screen('TextFont', window, 'SimHei');

    wait_text = '请稍作休息';
    waitRect = Screen('TextBounds', window, double(wait_text));
    Screen('DrawText', window, double(wait_text), ...
        rect(3)/2 - waitRect(3)/2, rect(4)/2, [200 200 200]);

    Screen('Flip', window);
    WaitSecs(4.0);
end

function show_block_interval(window, rect, block_idx)
    % 显示block间间隔

    Screen('FillRect', window, [0 0 0], rect);
    Screen('TextSize', window, round(rect(4)/25));
    Screen('TextFont', window, 'SimHei');

    complete_text = sprintf('第%d组完成', block_idx);
    completeRect = Screen('TextBounds', window, double(complete_text));
    Screen('DrawText', window, double(complete_text), ...
        rect(3)/2 - completeRect(3)/2, rect(4)/2 - 50, [100 200 255]);

    rest_text = '请稍作休息，准备下一组';
    restRect = Screen('TextBounds', window, double(rest_text));
    Screen('DrawText', window, double(rest_text), ...
        rect(3)/2 - restRect(3)/2, rect(4)/2, [200 200 200]);

    Screen('Flip', window);
    WaitSecs(3.0);
end

function show_end_screen(window, rect)
    % 显示结束界面

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

% ========== 修改：增加被试信息参数 ==========
function save_block_ratings_data(all_block_ratings, block_sequence, dimensions, block_patterns, sequence_info, ...
                                 subject_id, age, gender)
    % 保存评分数据（按block组织），包含被试信息
    % ========================================

    % 创建文件名
    filename = sprintf('complexity_ratings_%s_%s.csv', subject_id, datestr(now, 'yyyymmdd_HHMMSS'));

    % 打开文件
    fid = fopen(filename, 'w', 'n', 'UTF-8');

    % ========== 修改：写入包含被试信息的表头 ==========
    fprintf(fid, 'SubjectID,Age,Gender,BlockOrder,BlockPattern,BlockID,Odor,');
    for i = 1:length(dimensions)
        fprintf(fid, '%s,', dimensions{i});
    end
    fprintf(fid, '\n');
    % ================================================

    % 写入序列信息（作为注释行）
    fprintf(fid, '# 序列信息: Block间顺序=%s, Block内顺序=%s, 紧凑表示=%s\n', ...
        sequence_info.block_order, sequence_info.inner_order, sequence_info.compact_str);

    % 写入数据
    for block_idx = 1:9
        current_block = block_sequence{block_idx};
        block_ratings = all_block_ratings{block_idx};

        % 获取当前block的三个气味
        trials = block_patterns.(current_block);

        for trial_idx = 1:3
            odor_name = trials{trial_idx};
            ratings = block_ratings.(odor_name);

            % ========== 修改：每行数据前加入被试信息 ==========
            fprintf(fid, '%s,%s,%s,%s,%s,%d,%s,', ...
                subject_id, age, gender, ...
                sequence_info.block_order(block_idx), ...
                current_block, ...
                block_idx, ...
                odor_name);
            % ================================================
            for j = 1:length(ratings)
                fprintf(fid, '%d,', ratings(j));
            end
            fprintf(fid, '\n');
        end
    end

    fclose(fid);
    fprintf('评分数据已保存至: %s\n', filename);

    % 打印汇总信息
    fprintf('\n=== 评分数据汇总 ===\n');
    fprintf('被试信息: 编号=%s, 年龄=%s, 性别=%s\n', subject_id, age, gender);
    fprintf('试次顺序信息:\n');
    fprintf('  Block间顺序: %s\n', sequence_info.block_order);
    fprintf('  Block内顺序: %s\n', sequence_info.inner_order);
    fprintf('  紧凑表示: %s\n', sequence_info.compact_str);

    for block_idx = 1:9
        current_block = block_sequence{block_idx};
        block_ratings = all_block_ratings{block_idx};
        trials = block_patterns.(current_block);

        fprintf('\nBlock %d: %s\n', block_idx, current_block);
        for i = 1:3
            odor_name = trials{i};
            ratings = block_ratings.(odor_name);
            fprintf('  %s: %s\n', upper(odor_name), mat2str(ratings));
        end
    end
end


% 试次顺序生成函数
function [trial_sequence, sequence_info] = generate_final_trial_sequence()
    % 生成最终的27个试次顺序
    % 使用正确的表示法：
    % A1 = a1a3a2, A2 = a2a1a3, A3 = a3a2a1
    % B1 = b1b3b2, B2 = b2b1b3, B3 = b3b2b1
    % C1 = c1c3c2, C2 = c2c1c3, C3 = c3c2c1

    % block间顺序
    block_orders = {'ABCBCACAB', 'CABABCBCA', 'BCACABABC'};

    % block内顺序映射
    % 注意：这里的1,2,3不是数字顺序，而是block内顺序的编号
    block_patterns = struct();
    block_patterns.A1 = {'a1', 'a3', 'a2'};
    block_patterns.A2 = {'a2', 'a1', 'a3'};
    block_patterns.A3 = {'a3', 'a2', 'a1'};

    block_patterns.B1 = {'b1', 'b3', 'b2'};
    block_patterns.B2 = {'b2', 'b1', 'b3'};
    block_patterns.B3 = {'b3', 'b2', 'b1'};

    block_patterns.C1 = {'c1', 'c3', 'c2'};
    block_patterns.C2 = {'c2', 'c1', 'c3'};
    block_patterns.C3 = {'c3', 'c2', 'c1'};

    % 随机选择block间顺序
    block_order_idx = randi(3);
    block_order = block_orders{block_order_idx};

    % 随机选择block内顺序（从132, 213, 321中选择）
    % 这里的1,2,3对应A1/A2/A3等
    inner_order_idx = randi(3);
    switch inner_order_idx
        case 1
            inner_order = '132';  % 对应A1, B1, C1等
        case 2
            inner_order = '213';  % 对应A2, B2, C2等
        case 3
            inner_order = '321';  % 对应A3, B3, C3等
    end

    fprintf('=== 27个试次顺序生成 ===\n');
    fprintf('Block间顺序: %s (第%d种)\n', block_order, block_order_idx);
    fprintf('Block内顺序: %s (第%d种)\n', inner_order, inner_order_idx);

    % 解析数字顺序
    num1 = str2double(inner_order(1));  % 第一个数字
    num2 = str2double(inner_order(2));  % 第二个数字
    num3 = str2double(inner_order(3));  % 第三个数字

    % 生成紧凑表示
    compact_str = '';
    trial_sequence = cell(9, 3);

    block_order_chars = char(block_order);

    for block_idx = 1:9
        block_type = block_order_chars(block_idx);

        % 确定这个block使用哪个顺序
        if block_idx <= 3
            % 前3个block用第1个数字
            pattern_num = num1;
        elseif block_idx <= 6
            % 中间3个block用第3个数字
            pattern_num = num3;
        else
            % 最后3个block用第2个数字
            pattern_num = num2;
        end

        % 构建block模式标识符，如"A1", "B3"等
        pattern_id = sprintf('%c%d', block_type, pattern_num);

        % 获取这个block的试次顺序
        trials = block_patterns.(pattern_id);
        trial_sequence(block_idx, :) = trials;

        % 添加到紧凑表示
        compact_str = [compact_str pattern_id];
    end

    fprintf('紧凑表示: %s\n\n', compact_str);

    % 显示详细27个试次
    display_detailed_sequence(trial_sequence, compact_str, block_order);

    % 返回信息
    sequence_info.block_order = block_order;
    sequence_info.inner_order = inner_order;
    sequence_info.compact_str = compact_str;
    sequence_info.trial_sequence = trial_sequence;
end

function display_detailed_sequence(trial_sequence, compact_str, block_order)
    fprintf('详细27个试次顺序:\n');

    block_order_chars = char(block_order);
    compact_chars = char(compact_str);

    for block_idx = 1:9
        block_type = block_order_chars(block_idx);
        trials = trial_sequence(block_idx, :);
        compact_pattern = compact_chars((block_idx-1)*2+1:block_idx*2);

        fprintf('Block %d: %s = %s %s %s\n', ...
            block_idx, compact_pattern, trials{1}, trials{2}, trials{3});
    end

    % 验证
    fprintf('\n验证:\n');
    all_trials = trial_sequence(:);

    odors = {'a1', 'a2', 'a3', 'b1', 'b2', 'b3', 'c1', 'c2', 'c3'};
    counts = zeros(1, 9);

    for i = 1:length(all_trials)
        trial = all_trials{i};
        idx = find(strcmp(odors, trial));
        if ~isempty(idx)
            counts(idx) = counts(idx) + 1;
        end
    end

    fprintf('每个气味出现次数:\n');
    for i = 1:9
        fprintf('  %s: %d次\n', upper(odors{i}), counts(i));
    end
    fprintf('总试次数: %d\n', numel(all_trials));
end