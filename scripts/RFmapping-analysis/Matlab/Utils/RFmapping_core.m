function RFmapping_core(params)
    
    onlyReadGoodUnits = params.onlyReadGoodUnits;
    isBackgroundMoving = params.isBackgroundMoving;
    isAllocentricPixelBins = params.isAllocentricPixelBins;
    isRotation = params.isRotation;
    rotationOffsetSign = params.rotationOffsetSign;
    isFineResolution = params.isFineResolution;
    isUseRealCoordinate = params.isUseRealCoordinate;
    date = params.date;
    probelist = params.probelist;
    sessionList = params.sessionList;

    total_deg = params.total_deg;
    screenWidthPix = params.screenWidthPix;
    screenDeg = params.screenDeg;
    
    VSTimeWindow = params.VSTimeWindow;
    nbins = params.nbins;
    
    



    
    saveinJson = params.saveinjson;
    
    %%%%%%%%%%%%%%%%%%%%%
    % Process something before enter analysis
    %%%%%%%%%%%%%%%%%%%%%

    timeBinWidthMs = diff(VSTimeWindow) * 1000 / nbins;

    timeFolder = sprintf('%g_%g_%gms', ...
        VSTimeWindow(1) * 1000, VSTimeWindow(2) * 1000, timeBinWidthMs);
    if onlyReadGoodUnits
        unitSelectionFolder = 'good';
    else
        unitSelectionFolder = 'all';
    end

    pxPerDeg = screenWidthPix / screenDeg;
    screenCenterDeg = screenDeg / 2;
    
    if saveinJson
        fileExtension = '.json';
    else
        fileExtension = '.rfmap';
    end

    % Extract stim timing


    for session_raw = sessionList
        session = ['_', session_raw];

        sessionID = [date, session];
        
        fprintf('===========================\n');
        fprintf('Working on session: %s\n', sessionID);

        base_dir = [params.base_dir, date, '/', sessionID, '/'];
        
        
        trials_data_mat = [base_dir, date, '.mat'];
        trials_mat_adc = [base_dir, 'data/on_list_times.npy'];

        % load([fbasename '_Trials.mat']);
        trials = load(trials_data_mat).trials;
        trials_time = readNPY(trials_mat_adc);
        if isRotation
            hd_trials = [base_dir, 'data/hd_trials_times.npy'];
            hdOffsetPix = readNPY(hd_trials);
        end
        
        for probe = probelist
            fprintf('===========================\n')
            fprintf('Probe%s\n', probe);

            kilosort_folder = [base_dir, 'kilosort/Probe', probe, '/kilosort', session, '/'];
            % kilosort_folder = [base_dir, 'pipeline/260701/Probe', probe, '/kilosort'];
            clusterKSLabelFile = [kilosort_folder, 'cluster_KSLabel.tsv'];
            clusterGroupFile = [kilosort_folder, 'cluster_group.tsv'];
            spikeClustersFile = [kilosort_folder, 'spike_clusters.npy'];
            spikeTimesFile = [base_dir, 'data/probe', probe, '/adc_spike_time.npy'];
            save_dir = [base_dir, 'data/rfmapping/', unitSelectionFolder, '/', timeFolder, '/Probe', probe, '/'];
        
            labels = readtable(clusterKSLabelFile, 'FileType', 'text', 'Delimiter', '\t');
            spikeClusters = readNPY(spikeClustersFile);
            spikeTimes = readNPY(spikeTimesFile);
            
            goodUnits = labels.cluster_id(strcmp(labels.KSLabel, 'good'));
        
            % DetectExtInputOnset(fbasename,'digital',1,'RFmapStim'); % includes both opto and visual
        
            % load([fbasename '_Pulses_RFmapStim.mat']);
        
            pulseNum = length(trials_time) - 1;
            
        
            VisStim = [];
            VisStim.periods = zeros(pulseNum, 2);
            VisStim.duration = zeros(pulseNum, 1);
            VisStim.PosX = zeros(pulseNum, 1);
            VisStim.PosY = zeros(pulseNum, 1);
            VisStim.SquareSize = trials(1).Square_Size;
            VisStim.Lum = zeros(pulseNum, 1);
            
            VisStim.periods = [trials_time(1:pulseNum), trials_time(2:pulseNum+1)];
            VisStim.duration = VisStim.periods(:,2) - VisStim.periods(:,1);
        
            for i = 1:pulseNum
                if isBackgroundMoving
        %%%%%egocentric%%%%%
                    posXPix = (trials(i).Square_PositionX + screenCenterDeg) * pxPerDeg;
                    offsetPix = trials(i).BackgroundRotation_XOffset_Pix;
                    
                    VisStim.PosX(i) = mod(posXPix + rotationOffsetSign * offsetPix, screenWidthPix);
        %%%%%egocentric%%%%%
                elseif isRotation
                    posXPix = (trials(i).Square_PositionX + screenCenterDeg) * pxPerDeg;
                    offsetPix = hdOffsetPix(i);
                    
                    VisStim.PosX(i) = mod(posXPix + rotationOffsetSign * offsetPix, screenWidthPix);
                else
                    VisStim.PosX(i) = trials(i).Square_PositionX;
                end
        
                VisStim.PosY(i) = trials(i).Square_PositionY;
                VisStim.Lum(i) = trials(i).Square_Luminance;
        
            end
        
            % a = VisStim.duration;
            % 1/(mean(a(a>0.1)) - mean(a(a<0.1)))
        
            % SetCurrentSession('basename', fbasename);
            % unit_pool = GetUnits;
            
            unitPool = unique(spikeClusters);
            if onlyReadGoodUnits
                unitPool = intersect(unique(spikeClusters), goodUnits);
            end
        
            unitNum = size(unitPool, 1);
            
        
            % elec = 1;
            % clu = load([fbasename '.clu.' num2str(elec)]);
            % clu = clu(2:end);
        
            SqDeg = VisStim.SquareSize;
            xPositions = [];
            yPositions = [];
            squareWidthPix = SqDeg * pxPerDeg;
            squareWidthDeg = SqDeg;
            isPixelByPixelAnalysis = isBackgroundMoving || isRotation || isAllocentricPixelBins;
            if isBackgroundMoving || isRotation
        %%%%%egocentric%%%%%
                xPositions = 0:(screenWidthPix - 1);
                yPositions = unique(VisStim.PosY);
            elseif isAllocentricPixelBins
                allocentricBinNum = round(total_deg * pxPerDeg);
                xPositions = -total_deg / 2 + (0:(allocentricBinNum - 1)) / pxPerDeg;
                yPositions = unique(VisStim.PosY);
            else
                actualXPositions = unique(VisStim.PosX).';
                actualYPositions = unique(VisStim.PosY).';
                if isUseRealCoordinate
                    xPositions = actualXPositions;
                    yPositions = actualYPositions;
                else
                    x_num = length(actualXPositions);
                    y_num = length(actualYPositions);
                    xPositions = -(x_num - 1) / 2 * SqDeg + (0:x_num - 1) * SqDeg;
                    yPositions = -(y_num - 1) / 2 * SqDeg + (0:y_num - 1) * SqDeg;
                end
            
	    end

            x_num = length(xPositions);
            y_num = length(yPositions);
          
        
            RFmap = cell(unitNum, 1);
            
            parfor k = 1:unitNum
                u = unitPool(k);
                s = spikeTimes(spikeClusters == u);
        
                unitRF = [];
                % unitRF.ON.OnSet = zeros(30, 7, 25);
                unitRF.ON.OnSet = zeros(y_num,x_num,nbins);
        
                % unitRF.OFF.OnSet = zeros(10, 10, 25);
                % unitRF.ON.OffSet = zeros(10, 10, 63);
                % unitRF.OFF.OffSet = zeros(10, 10, 63);
                % unitRF.OnSetTime = 2:4:98;
                % unitRF.OffSetTime = 2:4:250;
        
                for x = 1:x_num
        
                    for y = 1:y_num
                        if isBackgroundMoving || isRotation
        %%%%%egocentric%%%%%
                            curX = xPositions(x);
                            curY = yPositions(y);
                            dx = mod(curX - VisStim.PosX + screenWidthPix / 2, screenWidthPix) - screenWidthPix / 2;
                            inSquareX = dx >= -squareWidthPix / 2 & dx < squareWidthPix / 2;
                            IDon = inSquareX & VisStim.PosY == curY & VisStim.Lum == 1;
        %%%%%360bin%%%%%
                        elseif isAllocentricPixelBins
                            curX = xPositions(x);
                            curY = yPositions(y);
                            dx = curX - VisStim.PosX;
                            inSquareX = dx >= -squareWidthDeg / 2 & dx < squareWidthDeg / 2;
                            IDon = inSquareX & VisStim.PosY == curY & VisStim.Lum == 1;
                        else
                            curX = xPositions(x);
                            curY = yPositions(y);
                            IDon = VisStim.PosX == curX & VisStim.PosY == curY & VisStim.Lum == 1;
                        end
                        % IDoff = VisStim.PosX == curX & VisStim.PosY == curY & VisStim.Lum == 0;
                        [sync, i] = Sync(s, VisStim.periods(IDon, 1), 'durations', VSTimeWindow);
                        [hist, ~] = SyncHist(sync, i, 'durations', VSTimeWindow, 'nBins', nbins);
        
                        if ~isempty(hist)
                            unitRF.ON.OnSet(y, x, :) = hist;
                        end
        
                        %
                        % [sync,i] = Sync(s,VisStim.periods(IDoff,1),'durations', [0 0.1]);
                        % [hist,~] = SyncHist(sync,i,'durations', [0 0.1],'nBins',25);
                        % if ~isempty(hist)
                        %     RFmap{k}.OFF.OnSet(x,y,:) = hist;
                        % end
                        %
                        % [sync,i] = Sync(s,VisStim.periods(IDon,2),'durations', [0 0.252]);
                        % [hist,~] = SyncHist(sync,i,'durations', [0 0.252],'nBins',63);
                        % if ~isempty(hist)
                        %     RFmap{k}.ON.OffSet(x,y,:) = hist;
                        % end
                        %
                        % [sync,i] = Sync(s,VisStim.periods(IDoff,2),'durations', [0 0.252]);
                        % [hist,~] = SyncHist(sync,i,'durations', [0 0.252],'nBins',63);
                        % if ~isempty(hist)
                        %     RFmap{k}.OFF.OffSet(x,y,:) = hist;
                        % end
                    end
        
                end
        
                RFmap{k} = unitRF;
                fprintf('done %d out of %d\n', k, unitNum);
            end
        
            if isPixelByPixelAnalysis && ~isFineResolution
                regularXNum = total_deg / SqDeg;
                pixelsPerRegularBin = screenWidthPix / regularXNum;
                for k = 1:unitNum
                    unitRF = RFmap{k};
                    unitRF.ON.OnSet = reshape(sum(reshape(unitRF.ON.OnSet, ...
                        y_num, pixelsPerRegularBin, regularXNum, nbins), 2), ...
                        y_num, regularXNum, nbins);
                    RFmap{k} = unitRF;
                end
                x_num = regularXNum;

                % Correct x num for outputfile to 960
                xPositionsForJson = -total_deg / 2 + SqDeg / 2 + (0:(regularXNum - 1)) * SqDeg;
            else
                xPositionsForJson = xPositions;
            end

            unitsSpikeCounts = zeros(unitNum, y_num, x_num, nbins);

            for k = 1:unitNum
                unitsSpikeCounts(k, :, :, :) = RFmap{k}.ON.OnSet;
            end

            unitsSpikeCountsJson = struct;
            unitsSpikeCountsJson.unitsSpikeCounts = unitsSpikeCounts;
            unitsSpikeCountsJson.unitsSpikeCountsSize = size(unitsSpikeCounts);
            unitsSpikeCountsJson.unitPool = unitPool;
            unitsSpikeCountsJson.xPositions = xPositionsForJson;
            unitsSpikeCountsJson.yPositions = yPositions;
            unitsSpikeCountsJson.VSTimeWindow = VSTimeWindow;
            unitsSpikeCountsJson.timeWindowMs = VSTimeWindow * 1000;
            unitsSpikeCountsJson.timeBinWidthMs = timeBinWidthMs;
            unitsSpikeCountsJson.timeBinEdges = linspace(VSTimeWindow(1), VSTimeWindow(2), nbins + 1);
            
            % validate the data for json file output
            assert(length(xPositionsForJson) == size(unitsSpikeCounts, 3));

            if exist(save_dir, 'dir') ~= 7
                mkdir(save_dir);
            end
            jsonText = jsonencode(unitsSpikeCountsJson);
            if isBackgroundMoving
                if isFineResolution
                    jsonFileName = ['egocentric_unitsSpikeCounts_', sessionID, fileExtension];
                else
                    jsonFileName = ['egocentric_30_unitsSpikeCounts_', sessionID, fileExtension];
                end
            elseif isRotation
                if isFineResolution
                    jsonFileName = ['rotation_unitsSpikeCounts_', sessionID, fileExtension];
                else
                    jsonFileName = ['rotation_30_unitsSpikeCounts_', sessionID, fileExtension];
                end
            elseif isAllocentricPixelBins
                if isFineResolution
                    jsonFileName = ['allocentric_pixelbins_unitsSpikeCounts_', sessionID, fileExtension];
                else
                    jsonFileName = ['allocentric_pixelbins_30_unitsSpikeCounts_', sessionID, fileExtension];
                end
            else
                jsonFileName = ['regular_unitsSpikeCounts_', sessionID, fileExtension];
            end
            fid = fopen(fullfile(save_dir, jsonFileName), 'w');
            fprintf(fid, '%s', jsonText);
            fclose(fid);

        
            if ~isBackgroundMoving && ~isRotation && ~isAllocentricPixelBins && ~isUseRealCoordinate
                totalResponse = 0;
                for k = 1:unitNum
                    totalResponse = totalResponse + sum(RFmap{k}.ON.OnSet(:));
                end
                if totalResponse == 0
                    fprintf('Suggest use the real y instead of precalculated due to the change of y axis by ptb\n');
                end
            end
        
        
           % Gen PDF from here
            if isBackgroundMoving
        %%%%%egocentric%%%%%
                if isFineResolution
                    savePdfDir = [save_dir, 'egocentric'];
                else
                    savePdfDir = [save_dir, 'egocentric_30'];
                end
        %%%%%egocentric%%%%%
            elseif isRotation
                if isFineResolution
                    savePdfDir = [save_dir, 'rotation'];
                else
                    savePdfDir = [save_dir, 'rotation_30'];
                end
            elseif isAllocentricPixelBins
                if isFineResolution
                    savePdfDir = [save_dir, 'allocentric_pixelbins'];
                else
                    savePdfDir = [save_dir, 'allocentric_pixelbins_30'];
                end
            else
                savePdfDir = [save_dir, 'regular'];
            end
            if exist(savePdfDir, 'dir') ~= 7
                mkdir(savePdfDir);
            end

            parfor k = 1:unitNum

                u = unitPool(k);
                rf = flipud(sum(RFmap{k}.ON.OnSet, 3));
                [rfRows, rfCols] = size(rf);
                if isPixelByPixelAnalysis && isFineResolution
        %%%%%egocentric%%%%%
                    plotHeight = 3;
                    leftWidth = 16;
                    innerBlankRows = 4;
                    polarPadRows = 1;
                    polarPlotRadius = innerBlankRows + rfRows + polarPadRows;
                    polarSize = 9;
                    figHeight = polarSize + 2.8;
                    figWidth = leftWidth + polarSize + 4.5;
        %%%%%egocentric%%%%%
                else
                    plotHeight = 8;
                    innerBlankRows = 4;
                    binSize = plotHeight / rfRows;
                    leftWidth = plotHeight * rfCols / rfRows;
                    polarPadRows = 1;
                    polarPlotRadius = innerBlankRows + rfRows + polarPadRows;
                    polarSize = 2 * polarPlotRadius * binSize;
                    figHeight = polarSize + 2.8;
                    figWidth = leftWidth + polarSize + 4.5;
                end
                fig = figure('Visible','off','Units','centimeters','Position',[23.336,4.3,figWidth,figHeight]);
        
                leftAx = axes('Parent',fig,'Units','centimeters', ...
                    'Position',[1.1,1.0 + (polarSize - plotHeight) / 2,leftWidth,plotHeight]);
                axes(leftAx);
                PlotColorMap(rf);
                leftAx.Toolbar.Visible = 'off';
                colormap gray;
                colorbar;
                if isPixelByPixelAnalysis && isFineResolution
        %%%%%egocentric%%%%%
                    axis tight;
        %%%%%egocentric%%%%%
                else
                    axis image;
                end
                title('ON onset RFmap');
                colorLimits = get(leftAx,'CLim');
        
                polarAx = axes('Parent',fig,'Units','centimeters','Position',[leftWidth+3.2,1.0,polarSize,polarSize]);
                polarAx.Toolbar.Visible = 'off';
                hold(polarAx,'on');
                thetaEdges = deg2rad(linspace(90 + total_deg/2, 90 - total_deg/2, rfCols + 1));
                rEdges = innerBlankRows:(innerBlankRows + rfRows);
                outerRadius = innerBlankRows + rfRows;
                nArc = 16;
                for row = 1:rfRows
                    for col = 1:rfCols
                        thetaCell = linspace(thetaEdges(col), thetaEdges(col + 1), nArc);
                        xPatch = [rEdges(row + 1) .* cos(thetaCell), rEdges(row) .* cos(fliplr(thetaCell))];
                        yPatch = [rEdges(row + 1) .* sin(thetaCell), rEdges(row) .* sin(fliplr(thetaCell))];
                        patch(polarAx,'XData',xPatch,'YData',yPatch,'CData',rf(row,col), ...
                            'FaceColor','flat','EdgeColor','none');
                    end
                end
                axis(polarAx,'equal');
                axis(polarAx,'off');
                xlim(polarAx,[-polarPlotRadius polarPlotRadius]);
                ylim(polarAx,[-polarPlotRadius polarPlotRadius]);
                set(polarAx,'CLim',colorLimits);
                title(polarAx,'Polar RFmap');
        
                sgtitle(sprintf('Unit %d', u));
                unitPdf = fullfile(savePdfDir, sprintf('%03d_unit_%d.pdf', k, u));
                exportgraphics(fig, unitPdf, 'ContentType', 'image');
                close(fig);
                fprintf('pdf done %d out of %d\n', k, unitNum);
            end
        
        %%%%%egocentric%%%%%
            SaveRfPatternCsv(RFmap, unitPool, save_dir, total_deg, date, sessionID, ...
                isBackgroundMoving, isRotation, isAllocentricPixelBins && ~isBackgroundMoving, isFineResolution);
        %%%%%egocentric%%%%%
        end
    end
end


% Build the csv file for python

function SaveRfPatternCsv(RFmap, unitPool, save_dir, total_deg, date, sessionID, isBackgroundMoving, isRotation, isAllocentricPixelBins, isFineResolution)
    
    if isBackgroundMoving
        if isFineResolution
            csvFile = fullfile(save_dir, ['egocentric_', sessionID, '.csv']);
        else
            csvFile = fullfile(save_dir, ['egocentric_30_', sessionID, '.csv']);
        end
    elseif isRotation
        if isFineResolution
            csvFile = fullfile(save_dir, ['rotation_', sessionID, '.csv']);
        else
            csvFile = fullfile(save_dir, ['rotation_30_', sessionID, '.csv']);
        end
    elseif isAllocentricPixelBins
        if isFineResolution
            csvFile = fullfile(save_dir, ['allocentric_pixelbins_', sessionID, '.csv']);
        else
            csvFile = fullfile(save_dir, ['allocentric_pixelbins_30_', sessionID, '.csv']);
        end
    else
        csvFile = fullfile(save_dir, ['regular_', sessionID, '.csv']);
    end
    csvDir = fileparts(csvFile);
    if exist(csvDir, 'dir') ~= 7
        mkdir(csvDir);
    end

    innerBlankRows = 4;
    polarPadRows = 1;
    unitNum = length(unitPool);
    sampleRf = flipud(sum(RFmap{1}.ON.OnSet, 3));
    [rfRows, rfCols] = size(sampleRf);
    rowCount = unitNum * rfRows * rfCols;

    unit_index = zeros(rowCount, 1);
    unit_id = zeros(rowCount, 1);
    row = zeros(rowCount, 1);
    col = zeros(rowCount, 1);
    rf_value = zeros(rowCount, 1);
    theta_start_deg = zeros(rowCount, 1);
    theta_end_deg = zeros(rowCount, 1);
    r_inner = zeros(rowCount, 1);
    r_outer = zeros(rowCount, 1);
    rf_rows = rfRows * ones(rowCount, 1);
    rf_cols = rfCols * ones(rowCount, 1);
    total_deg_col = total_deg * ones(rowCount, 1);
    inner_blank_rows = innerBlankRows * ones(rowCount, 1);
    polar_plot_radius = (innerBlankRows + rfRows + polarPadRows) * ones(rowCount, 1);

    thetaEdges = linspace(90 + total_deg / 2, 90 - total_deg / 2, rfCols + 1);
    rEdges = innerBlankRows:(innerBlankRows + rfRows);

    idx = 1;
    for k = 1:unitNum
        rf = flipud(sum(RFmap{k}.ON.OnSet, 3));
        for rr = 1:rfRows
            for cc = 1:rfCols
                unit_index(idx) = k;
                unit_id(idx) = unitPool(k);
                row(idx) = rr;
                col(idx) = cc;
                rf_value(idx) = rf(rr, cc);
                theta_start_deg(idx) = thetaEdges(cc);
                theta_end_deg(idx) = thetaEdges(cc + 1);
                r_inner(idx) = rEdges(rr);
                r_outer(idx) = rEdges(rr + 1);
                idx = idx + 1;
            end
        end
    end

    T = table(unit_index, unit_id, row, col, rf_value, theta_start_deg, ...
        theta_end_deg, r_inner, r_outer, rf_rows, rf_cols, total_deg_col, ...
        inner_blank_rows, polar_plot_radius);
%%%%%egocentric%%%%%
    if exist(csvFile, 'file') == 2
        delete(csvFile);
    end
%%%%%egocentric%%%%%
    writetable(T, csvFile);
end
