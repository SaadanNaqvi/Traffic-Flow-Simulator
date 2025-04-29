% This program aims to create a traffic flow simulator

% Version 7 adss back previous features such as the traffic lights and user
% input. It also has a user interface displaying statistics, and overall a
% fully functioning intersection system.

clear; clc; close all;

% Inputs
preset = input("Do you want to load a preset? (Y or N) ", "s");

if upper(preset) == "N"
    gridSize = input("Enter grid size [rows cols] (minimum 20x20 recommended): ");
    numCarsPerMin = input("Number of cars per minute (for each direction): ");
    simTime = input("Simulation time (seconds): ");
    
    carSpawnRate = numCarsPerMin / 60;

    fprintf('Define your road layout:\n');
    fprintf('Define your road layout row by row\n');
    
    roadGrid = zeros(gridSize);
    roadDirections = zeros(gridSize); % 1 = east-west, 2 = north-south
    
    % Text-based road drawing
    fprintf('Define your road layout (1=horizontal road, 2=vertical road, 3=intersection, 0=no road):\n');
    for i = 1:gridSize(1)
        rowInput = input(['Row ', num2str(i), ' (', num2str(gridSize(2)), ' digits, use 0,1,2,3): '], 's');
        for j = 1:min(length(rowInput), gridSize(2))
            val = str2double(rowInput(j));
            if val >= 0 && val <= 3
                roadGrid(i, j) = val;
                if val == 1
                    roadDirections(i, j) = 1; % Horizontal
                elseif val == 2
                    roadDirections(i, j) = 2; % Vertical
                elseif val == 3
                    roadDirections(i, j) = 3; % Both
                end
            end
        end
    end
    
else
    % Default preset with cross intersection
    gridSize = [30 30];
    numCarsPerMin = 20;
    simTime = 120;
    carSpawnRate = numCarsPerMin / 60;

    % Create a cross-shaped road with intersection markers
    roadGrid = zeros(gridSize);
    roadDirections = zeros(gridSize);
    centerRow = ceil(gridSize(1)/2);
    centerCol = ceil(gridSize(2)/2);
    
    % Horizontal road (two lanes - two-way road)
    roadGrid(centerRow-1:centerRow, :) = 1; % Two lanes
    roadDirections(centerRow-1:centerRow, :) = 1; % Two lanes
    
    % Vertical road (two lanes - two-way road)
    roadGrid(:, centerCol-1:centerCol) = 2; % Two lanes
    roadDirections(:, centerCol-1:centerCol) = 2; % Two lanes
    
    % Mark intersections
    roadGrid(centerRow-1:centerRow, centerCol-1:centerCol) = 3;
    roadDirections(centerRow-1:centerRow, centerCol-1:centerCol) = 3;
end

% Auto-detect and mark intersections if needed
for i = 2:gridSize(1)-1
    for j = 2:gridSize(2)-1
        % Check if there's both horizontal and vertical roads in adjacent cells
        horizontalRoad = any(roadGrid(i, j-1:j+1) == 1);
        verticalRoad = any(roadGrid(i-1:i+1, j) == 2);
        
        if horizontalRoad && verticalRoad
            roadGrid(i, j) = 3; % Mark as intersection
            roadDirections(i, j) = 3; % Both directions
        end
    end
end

% Traffic light settings
greenDuration = 15; % Green light duration in seconds
yellowDuration = 3; % Yellow light duration in seconds
redDuration = greenDuration + yellowDuration; % Full cycle duration

% Initialize the grid for car positions
% 0 = empty, 1 = right car, -1 = left car, 2 = down car, -2 = up car
grid = zeros(gridSize);

% Define lane directions for spawn and movement
% For horizontal roads: odd rows are eastbound (right), even rows are westbound (left)
% For vertical roads: odd columns are southbound (down), even columns are northbound (up)

% Custom colormap
cmap = [
    0.8 0.8 0.8; % 1: background (light gray)
    0.2 0.2 0.2; % 2: horizontal road
    0.3 0.3 0.3; % 3: vertical road
    0.4 0.4 0.4; % 4: intersection
    1 0 0;       % 5: red light
    1 1 0;       % 6: yellow light
    0 1 0;       % 7: green light
    1 1 1;       % 8: right car (white)
    1 1 1;       % 9: left car (white)
    0 0.5 1;     % 10: down car (blue)
    0 0.5 1;     % 11: up car (blue)
    0.9 0 0;     % 12: collision (bright red)
    0.5 0.5 0.5; % 13: traffic light pole
    1 0.5 0      % 14: stop line
];

% Find all intersections and adjacent road cells
[intersectRows, intersectCols] = find(roadGrid == 3);
numIntersections = length(intersectRows);

% Create traffic light positions
lightPositions = [];
stopLinePositions = [];
% Track intersection zones (cells where cars should not check lights after passing)
intersectionZones = zeros(gridSize);

for i = 1:numIntersections
    r = intersectRows(i);
    c = intersectCols(i);
    
    % Mark this cell as part of an intersection zone
    intersectionZones(r, c) = i;
    
    % Check surrounding cells to place traffic lights
    directions = {'N', 'E', 'S', 'W'};
    offsets = [-1 0; 0 1; 1 0; 0 -1];
    
    for d = 1:4
        nr = r + offsets(d,1);
        nc = c + offsets(d,2);
        
        if nr >= 1 && nr <= gridSize(1) && nc >= 1 && nc <= gridSize(2)
            roadType = roadGrid(nr, nc);
            
            % Place light based on road direction
            if roadType == 1 || roadType == 2
                % Add light at position adjacent to intersection
                lightPositions = [lightPositions; nr nc d i];
                
                % Add stop line two cells before the intersection
                stopR = r + 2*offsets(d,1);
                stopC = c + 2*offsets(d,2);
                
                if stopR >= 1 && stopR <= gridSize(1) && stopC >= 1 && stopC <= gridSize(2)
                    stopLinePositions = [stopLinePositions; stopR stopC d i];
                end
            end
        end
    end
end

% Group intersections by proximity to create proper intersection clusters
if numIntersections > 0
    % Simple clustering based on distance
    maxClusterDist = 3; % Maximum distance for clustered intersections
    clusterIDs = zeros(numIntersections, 1);
    currentCluster = 0;
    
    for i = 1:numIntersections
        if clusterIDs(i) == 0 % Unassigned intersection
            currentCluster = currentCluster + 1;
            clusterIDs(i) = currentCluster;
            
            % Find all intersections close to this one
            for j = 1:numIntersections
                if i ~= j && clusterIDs(j) == 0
                    dist = sqrt(sum((intersectRows(i) - intersectRows(j))^2 + (intersectCols(i) - intersectCols(j))^2));
                    if dist <= maxClusterDist
                        clusterIDs(j) = currentCluster;
                    end
                end
            end
        end
    end
    
    numClusters = max(clusterIDs);
    
    % Create light phases for each intersection cluster
    lightPhases = cell(numClusters, 1);
    lightTimers = zeros(numClusters, 1);
    currentPhases = ones(numClusters, 1); % 1=Horizontal green, 2=Horizontal yellow, 3=Vertical green, 4=Vertical yellow
    
    for i = 1:numClusters
        % Define the traffic light sequence for this intersection
        lightPhases{i} = {
            {'H', greenDuration},  % Horizontal green
            {'HY', yellowDuration}, % Horizontal yellow
            {'V', greenDuration},  % Vertical green
            {'VY', yellowDuration}  % Vertical yellow
        };
        lightTimers(i) = lightPhases{i}{1}{2}; % Start with the duration of first phase
    end
else
    numClusters = 0;
    lightPhases = {};
    lightTimers = [];
    currentPhases = [];
end

% Initialize visualization
visualGrid = ones(gridSize);
figure('Name', 'Traffic Simulation', 'Position', [100 100 800 800]);
h = imshow(visualGrid, cmap, 'InitialMagnification', 'fit');
axis off;
title('Traffic Simulation with Intersection Control');

% Create a lookup table for direction-based car movement
directionOffsets = [
    0 1;   % 1: Right-moving car
    0 -1;  % -1: Left-moving car
    1 0;   % 2: Down-moving car
    -1 0   % -2: Up-moving car
];

% Car counters
totalCars = 0;
passedCars = 0;
collisions = 0;

% Traffic light states tracking
lightStates = zeros(size(lightPositions, 1), 1); % 1=green, 2=yellow, 3=red

% Create a car ID tracking system - each car gets a unique ID
nextCarID = 1;
carIDs = zeros(gridSize); % Store unique car IDs in each cell

% Track which cars have passed which intersections
carPassedIntersection = []; % Will store [carID intersectionID] pairs

% Define a minimum car spacing (in cells)
minCarSpacing = 2;

% Main simulation loop
for t = 1:simTime
    % Update traffic light phases
    for i = 1:numClusters
        lightTimers(i) = lightTimers(i) - 1;
        
        if lightTimers(i) <= 0
            % Move to next phase
            currentPhases(i) = mod(currentPhases(i), 4) + 1;
            lightTimers(i) = lightPhases{i}{currentPhases(i)}{2};
        end
    end
    
    % Build the visual grid
    visualGrid = ones(gridSize);
    
    % Add roads
    visualGrid(roadGrid == 1) = 2; % Horizontal roads
    visualGrid(roadGrid == 2) = 3; % Vertical roads
    visualGrid(roadGrid == 3) = 4; % Intersections
    
    % Add stop lines
    for i = 1:size(stopLinePositions, 1)
        r = stopLinePositions(i, 1);
        c = stopLinePositions(i, 2);
        visualGrid(r, c) = 14; % Stop line
    end
    
    % Update traffic light states and visuals
    for i = 1:size(lightPositions, 1)
        r = lightPositions(i, 1);
        c = lightPositions(i, 2);
        direction = lightPositions(i, 3);
        intersectionIdx = lightPositions(i, 4);
        
        % Ensure we have a valid clusterID
        if intersectionIdx <= numIntersections
            clusterID = clusterIDs(intersectionIdx);
            
            % Get current phase for this cluster
            phase = currentPhases(clusterID);
            phaseInfo = lightPhases{clusterID}{phase}{1};
            
            % Determine light color based on phase and direction
            % Direction 1-North, 2-East, 3-South, 4-West
            isHorizontal = (direction == 2 || direction == 4); % East or West
            
            if isHorizontal % Horizontal road light
                if strcmp(phaseInfo, 'H')
                    lightColor = 7; % Green
                    lightStates(i) = 1;
                elseif strcmp(phaseInfo, 'HY')
                    lightColor = 6; % Yellow
                    lightStates(i) = 2;
                else
                    lightColor = 5; % Red
                    lightStates(i) = 3;
                end
            else % Vertical road light
                if strcmp(phaseInfo, 'V')
                    lightColor = 7; % Green
                    lightStates(i) = 1;
                elseif strcmp(phaseInfo, 'VY')
                    lightColor = 6; % Yellow
                    lightStates(i) = 2;
                else
                    lightColor = 5; % Red
                    lightStates(i) = 3;
                end
            end
            
            % Place the light
            visualGrid(r, c) = lightColor;
        end
    end
    
    % First, create a list of all cars with their locations and directions
    % Find all cars
    [carRows, carCols] = find(grid ~= 0);
    allCars = [];
    
    for i = 1:length(carRows)
        r = carRows(i);
        c = carCols(i);
        carType = grid(r, c);
        carID = carIDs(r, c);
        
        % Determine direction index for this car type
        dirIdx = find([1, -1, 2, -2] == carType);
        
        if ~isempty(dirIdx)
            % [ID, row, col, type, direction index]
            allCars = [allCars; carID, r, c, carType, dirIdx];
        end
    end
    
    % Initialize new grid and car IDs for the next step
    newGrid = zeros(size(grid));
    newCarIDs = zeros(size(carIDs));
    
    % Track which positions will be occupied in the next step
    occupiedPositions = zeros(gridSize);
    
    % First pass: check if cars can move or should stay in place
    carMoves = zeros(size(allCars, 1), 3); % [row, col, should_move]
    
    for i = 1:size(allCars, 1)
        carID = allCars(i, 1);
        r = allCars(i, 2);
        c = allCars(i, 3);
        carType = allCars(i, 4);
        dirIdx = allCars(i, 5);
        
        % Get movement direction
        dr = directionOffsets(dirIdx, 1);
        dc = directionOffsets(dirIdx, 2);
        
        % Calculate next position
        nr = r + dr;
        nc = c + dc;
        
        % Default: don't move
        carMoves(i, :) = [r, c, 0];
        
        % Check if next position is valid
        if nr >= 1 && nr <= gridSize(1) && nc >= 1 && nc <= gridSize(2) && roadGrid(nr, nc) > 0
            % Check if car is at a stop line before a red light
            atStopLine = false;
            mustStop = false;
            
            % Check if we're at a stop line
            for sl = 1:size(stopLinePositions, 1)
                stopR = stopLinePositions(sl, 1);
                stopC = stopLinePositions(sl, 2);
                stopDir = stopLinePositions(sl, 3);
                stopIntersectionIdx = stopLinePositions(sl, 4);
                
                % If we're at this stop line
                if r == stopR && c == stopC
                    atStopLine = true;
                    
                    % Check if this car has already passed this intersection
                    carPassedThisIntersection = false;
                    if ~isempty(carPassedIntersection)
                        carPassedThisIntersection = any(carPassedIntersection(:, 1) == carID & ...
                                                     carPassedIntersection(:, 2) == stopIntersectionIdx);
                    end
                    
                    % If car hasn't passed intersection yet, check light status
                    if ~carPassedThisIntersection
                        % Find the corresponding light
                        for lp = 1:size(lightPositions, 1)
                            if lp <= size(lightPositions, 1) && stopIntersectionIdx <= numIntersections && ...
                               lightPositions(lp, 4) == stopIntersectionIdx && lightPositions(lp, 3) == stopDir
                                % Check if the light is red or yellow
                                if lightStates(lp) >= 2  % Yellow or Red
                                    mustStop = true;
                                end
                                break;
                            end
                        end
                    end
                    break;
                end
            end
            
            % Determine if next cell is an intersection
            nextIsIntersection = roadGrid(nr, nc) == 3;
            
            % If car enters an intersection, mark it as having passed
            if nextIsIntersection && intersectionZones(nr, nc) > 0
                intersectionID = intersectionZones(nr, nc);
                % Check if we need to add this car-intersection pair
                carPassedThisIntersection = false;
                if ~isempty(carPassedIntersection)
                    carPassedThisIntersection = any(carPassedIntersection(:, 1) == carID & ...
                                                 carPassedIntersection(:, 2) == intersectionID);
                end
                
                % If not already marked as passed, add it
                if ~carPassedThisIntersection
                    carPassedIntersection = [carPassedIntersection; [carID intersectionID]];
                end
            end
            
            % If we're at a stop line and must stop, stay in place
            if atStopLine && mustStop
                carMoves(i, :) = [r, c, 0]; % Stay in place
                continue;
            end
            
            % Check for cars in front to maintain spacing
            carInFront = false;
            for j = 1:size(allCars, 1)
                if i ~= j && allCars(j, 4) == carType  % Same car type/direction
                    % Check if it's in front of us in the same lane
                    otherR = allCars(j, 2);
                    otherC = allCars(j, 3);
                    
                    % Calculate distance based on direction
                    if abs(carType) == 1  % Horizontal movement
                        if dr > 0 && otherC > c && otherC - c < minCarSpacing && otherR == r
                            carInFront = true;
                            break;
                        elseif dr < 0 && otherC < c && c - otherC < minCarSpacing && otherR == r
                            carInFront = true;
                            break;
                        end
                    else  % Vertical movement
                        if dc > 0 && otherR > r && otherR - r < minCarSpacing && otherC == c
                            carInFront = true;
                            break;
                        elseif dc < 0 && otherR < r && r - otherR < minCarSpacing && otherC == c
                            carInFront = true;
                            break;
                        end
                    end
                end
            end
            
            % Move only if there's no car directly in front
            if ~carInFront
                carMoves(i, :) = [nr, nc, 1]; % Move to next position
            else
                carMoves(i, :) = [r, c, 0]; % Stay in place
            end
        else
            % Car reached edge of grid - count as passed and mark for removal
            passedCars = passedCars + 1;
            carMoves(i, :) = [-1, -1, -1]; % Special marker for cars that exit
        end
    end
    
    % Second pass: apply moves with priority to forward-most cars first
    % Sort cars by direction and position for priority
    if ~isempty(allCars)
        for carType = [1, -1, 2, -2]  % Process each direction separately
            carsOfType = find(allCars(:, 4) == carType);
            
            if ~isempty(carsOfType)
                % Get positions and sort by priority based on direction
                typeCars = allCars(carsOfType, :);
                typeMoves = carMoves(carsOfType, :);
                
                if carType == 1  % Right-moving
                    [~, sortIdx] = sort(typeCars(:, 3), 'descend');  % Sort by column (rightmost first)
                elseif carType == -1  % Left-moving
                    [~, sortIdx] = sort(typeCars(:, 3), 'ascend');  % Sort by column (leftmost first)
                elseif carType == 2  % Down-moving
                    [~, sortIdx] = sort(typeCars(:, 2), 'descend');  % Sort by row (bottom first)
                else  % Up-moving
                    [~, sortIdx] = sort(typeCars(:, 2), 'ascend');  % Sort by row (top first)
                end
                
                typeCars = typeCars(sortIdx, :);
                typeMoves = typeMoves(sortIdx, :);
                
                % Apply moves in order of priority
                for j = 1:size(typeCars, 1)
                    carID = typeCars(j, 1);
                    moveRow = typeMoves(j, 1);
                    moveCol = typeMoves(j, 2);
                    shouldMove = typeMoves(j, 3);
                    
                    % Skip cars that have exited
                    if shouldMove == -1
                        continue;
                    end
                    
                    % Check if destination is already occupied
                    if occupiedPositions(moveRow, moveCol) == 0
                        % Position is free, move car
                        newGrid(moveRow, moveCol) = carType;
                        newCarIDs(moveRow, moveCol) = carID;
                        occupiedPositions(moveRow, moveCol) = 1;
                    else
                        % Try to find a backup position - this is important for cars behind stopped cars
                        r = typeCars(j, 2);
                        c = typeCars(j, 3);
                        
                        % Keep original position if it's free
                        if occupiedPositions(r, c) == 0
                            newGrid(r, c) = carType;
                            newCarIDs(r, c) = carID;
                            occupiedPositions(r, c) = 1;
                        else
                            % Find an alternative position nearby
                            dr = directionOffsets(typeCars(j, 5), 1);
                            dc = directionOffsets(typeCars(j, 5), 2);
                            
                            for dist = 1:3  % Try up to 3 cells back
                                backR = r - dist*dr;
                                backC = c - dist*dc;
                                
                                if backR >= 1 && backR <= gridSize(1) && backC >= 1 && backC <= gridSize(2) && ...
                                   roadGrid(backR, backC) > 0 && occupiedPositions(backR, backC) == 0
                                    newGrid(backR, backC) = carType;
                                    newCarIDs(backR, backC) = carID;
                                    occupiedPositions(backR, backC) = 1;
                                    break;
                                end
                            end
                            % If no position found, car is lost (simplification)
                        end
                    end
                end
            end
        end
    end
    
    % Update the grid for the next iteration
    grid = newGrid;
    carIDs = newCarIDs;
    
    % Spawn new cars at edges with proper road checks and two-way logic
    % Find the middle of the grid for reference
    centerRow = ceil(gridSize(1)/2);
    centerCol = ceil(gridSize(2)/2);
    
    % Left edge - spawn right-moving (eastbound) cars
    for r = 1:gridSize(1)
        if roadGrid(r, 1) == 1 && mod(r - centerRow, 2) == 1 && rand < carSpawnRate && grid(r, 1) == 0
            % Check if there's enough space (no car in front)
            carInFront = false;
            for c = 2:min(1+minCarSpacing, gridSize(2))
                if grid(r, c) ~= 0
                    carInFront = true;
                    break;
                end
            end
            
            if ~carInFront
                grid(r, 1) = 1; % Right-moving car
                carIDs(r, 1) = nextCarID;
                nextCarID = nextCarID + 1;
                totalCars = totalCars + 1;
            end
        end
    end
    
    % Right edge - spawn left-moving (westbound) cars
    for r = 1:gridSize(1)
        if roadGrid(r, gridSize(2)) == 1 && mod(r - centerRow, 2) == 0 && rand < carSpawnRate && grid(r, gridSize(2)) == 0
            % Check if there's enough space (no car in front)
            carInFront = false;
            for c = gridSize(2)-1:-1:max(gridSize(2)-minCarSpacing, 1)
                if grid(r, c) ~= 0
                    carInFront = true;
                    break;
                end
            end
            
            if ~carInFront
                grid(r, gridSize(2)) = -1; % Left-moving car
                carIDs(r, gridSize(2)) = nextCarID;
                nextCarID = nextCarID + 1;
                totalCars = totalCars + 1;
            end
        end
    end
    
    % Top edge - spawn down-moving (southbound) cars
    for c = 1:gridSize(2)
        if roadGrid(1, c) == 2 && mod(c - centerCol, 2) == 0 && rand < carSpawnRate && grid(1, c) == 0
            % Check if there's enough space (no car in front)
            carInFront = false;
            for r = 2:min(1+minCarSpacing, gridSize(1))
                if grid(r, c) ~= 0
                    carInFront = true;
                    break;
                end
            end
            
            if ~carInFront
                grid(1, c) = 2; % Down-moving car
                carIDs(1, c) = nextCarID;
                nextCarID = nextCarID + 1;
                totalCars = totalCars + 1;
            end
        end
    end
    
    % Bottom edge - spawn up-moving (northbound) cars
    for c = 1:gridSize(2)
        if roadGrid(gridSize(1), c) == 2 && mod(c - centerCol, 2) == 1 && rand < carSpawnRate && grid(gridSize(1), c) == 0
            % Check if there's enough space (no car in front)
            carInFront = false;
            for r = gridSize(1)-1:-1:max(gridSize(1)-minCarSpacing, 1)
                if grid(r, c) ~= 0
                    carInFront = true;
                    break;
                end
            end
            
            if ~carInFront
                grid(gridSize(1), c) = -2; % Up-moving car
                carIDs(gridSize(1), c) = nextCarID;
                nextCarID = nextCarID + 1;
                totalCars = totalCars + 1;
            end
        end
    end
    
    % Update visual grid with cars - consistent colors for directions
    carPositions = zeros(gridSize); % Reset car position tracking
    
    % Apply car colors
    for r = 1:gridSize(1)
        for c = 1:gridSize(2)
            if grid(r, c) ~= 0
                carType = grid(r, c);
                
                % Track car position for collision detection
                carPositions(r, c) = 1;
                
                % Apply consistent colors
                if abs(carType) == 1  % Horizontal movement
                    visualGrid(r, c) = 8; % White
                else  % Vertical movement
                    visualGrid(r, c) = 10; % Blue
                end
            end
        end
    end 
    
    % Check for real collisions
    collisionCount = 0;
    realCollisions = zeros(gridSize);
    
    % Only use exact position matches for collision detection
    % Two cars are in the same cell - this is a real collision
    for r = 1:gridSize(1)
        for c = 1:gridSize(2)
            % Count cars in exactly this cell
            carCount = sum(sum(grid(r, c) ~= 0));
            
            % If more than one car in exact same position
            if carCount > 1
                realCollisions(r, c) = 1;
                collisionCount = collisionCount + 1;
                visualGrid(r, c) = 12; % Mark as collision (red)
            end
        end
    end
    
    % Only count new collisions
    if collisionCount > 0
        collisions = collisions + 1;
    end
    
    set(h, 'CData', visualGrid);
    
    % Display status
    lightStatus = '';
    if numClusters > 0
        for i = 1:min(3, numClusters) % Show up to 3 clusters
            phase = currentPhases(i);
            phaseInfo = lightPhases{i}{phase}{1};
            timer = lightTimers(i);
            
            if strcmp(phaseInfo, 'H')
                phaseStr = 'H-Green';
            elseif strcmp(phaseInfo, 'HY')
                phaseStr = 'H-Yellow';
            elseif strcmp(phaseInfo, 'V')
                phaseStr = 'V-Green';
            else
                phaseStr = 'V-Yellow';
            end
            
            lightStatus = [lightStatus sprintf('I%d: %s (%ds) | ', i, phaseStr, timer)];
        end
    end
    
    efficiency = 0;
    if totalCars > 0
        efficiency = 100 * passedCars / totalCars;
    end
    
    statusStr = sprintf('Time: %d/%d sec | Cars: %d | Passed: %d (%.1f%%) | Collisions: %d | %s', ...
        t, simTime, totalCars, passedCars, efficiency, collisions, lightStatus);
    title(statusStr);
    
    drawnow;
    pause(0.8); % Animation speed
end

% Final statistics
fprintf('\n--- Simulation Complete ---\n');
fprintf('Total cars generated: %d\n', totalCars);
fprintf('Cars that passed through: %d (%.1f%%)\n', passedCars, 100 * passedCars / max(1, totalCars));
fprintf('Collisions: %d\n', collisions);