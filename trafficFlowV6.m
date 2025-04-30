% This program aims to create a traffic flow simulator

% Version 6 is developed to focus on a basic intersection 
% without any of the previous features (traffic lights, user input) such
% that a basline for an intersection is developed that can be tweaked in later
% versions for the older features to be readded.

%P.S really hard to implement everything (traffic lights, user input) in
%just one version with an intersection hence a split like this was
%developed.

clear; clc; close all;

% Inputs
gridSize = [30 30];
numCarsPerMin = 15;
simTime = 90;
carSpawnRate = numCarsPerMin / 60;

% Create a cross-shaped road with two lanes (two-way roads)
roadGrid = zeros(gridSize);
roadDirections = zeros(gridSize); % 1 = east-west, 2 = north-south
centerRow = ceil(gridSize(1)/2);
centerCol = ceil(gridSize(2)/2);

% Horizontal road (two lanes - two-way road)
roadGrid(centerRow-1:centerRow, :) = 1; % Two lanes
roadDirections(centerRow-1:centerRow, :) = 1; % East-west

% Vertical road (two lanes - two-way road)
roadGrid(:, centerCol-1:centerCol) = 2; % Two lanes
roadDirections(:, centerCol-1:centerCol) = 2; % North-south

% Mark intersections
roadGrid(centerRow-1:centerRow, centerCol-1:centerCol) = 3;
roadDirections(centerRow-1:centerRow, centerCol-1:centerCol) = 3;

% Initialize grid for car positions
% 0 = empty, 1 = right car, -1 = left car, 2 = down car, -2 = up car
grid = zeros(gridSize);

% Define a minimum car spacing (in cells)
minCarSpacing = 2;

% Custom colormap
cmap = [
    0.8 0.8 0.8; % 1: background (light gray)
    0.2 0.2 0.2; % 2: horizontal road
    0.3 0.3 0.3; % 3: vertical road
    0.4 0.4 0.4; % 4: intersection
    1 1 1;       % 5: right/left car (white)
    0 0.5 1;     % 6: down/up car (blue)
    0.9 0 0;     % 7: collision (red)
    0.5 0.5 0.5  % 8: stop line
];

% Initialize visualization
visualGrid = ones(gridSize);
figure('Name', 'Traffic Simulation', 'Position', [100 100 700 700]);
h = imshow(visualGrid, cmap, 'InitialMagnification', 'fit');
axis off;
title('Traffic Simulation with Two-Way Roads');

% Define movement directions
directionOffsets = [
    0 1;   % 1: Right-moving car
    0 -1;  % -1: Left-moving car
    1 0;   % 2: Down-moving car
    -1 0   % -2: Up-moving car
];

% Add stop lines near intersections
stopLinePositions = [];
[intersectRows, intersectCols] = find(roadGrid == 3);
for i = 1:length(intersectRows)
    r = intersectRows(i);
    c = intersectCols(i);
    
    % Add stop lines in all four directions (if there's a road)
    directions = [[-1 0]; [0 1]; [1 0]; [0 -1]]; % N, E, S, W
    for d = 1:4
        nr = r + 2*directions(d, 1);
        nc = c + 2*directions(d, 2);
        
        if nr >= 1 && nr <= gridSize(1) && nc >= 1 && nc <= gridSize(2)
            if (d == 1 || d == 3) && roadGrid(nr, nc) == 2 % N-S road
                stopLinePositions = [stopLinePositions; nr nc];
            elseif (d == 2 || d == 4) && roadGrid(nr, nc) == 1 % E-W road
                stopLinePositions = [stopLinePositions; nr nc];
            end
        end
    end
end
% Create a car ID system
nextCarID = 1;
carIDs = zeros(gridSize);

% Main simulation loop
for t = 1:simTime
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
        visualGrid(r, c) = 8; % Stop line
    end
    
    % Find all cars
    [carRows, carCols] = find(grid ~= 0);
    allCars = [];
    
    for i = 1:length(carRows)
        r = carRows(i);
        c = carCols(i);
        carType = grid(r, c);
        carID = carIDs(r, c);
        
        % Determine direction index
        dirIdx = find([1, -1, 2, -2] == carType);
        allCars = [allCars; carID, r, c, carType, dirIdx];
    end
    
    % Initialize new grid for next step
    newGrid = zeros(size(grid));
    newCarIDs = zeros(size(carIDs));
    
    % Track positions that will be occupied
    occupiedPositions = zeros(gridSize);
    
    % First pass: check if cars can move
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
        
        % Next position
        nr = r + dr;
        nc = c + dc;
        
        % Default: don't move
        carMoves(i, :) = [r, c, 0];
        
        % Check if next position is valid
        if nr >= 1 && nr <= gridSize(1) && nc >= 1 && nc <= gridSize(2) && roadGrid(nr, nc) > 0
            % Check if at stop line
            atStopLine = false;
            for sl = 1:size(stopLinePositions, 1)
                if r == stopLinePositions(sl, 1) && c == stopLinePositions(sl, 2)
                    atStopLine = true;
                    break;
                end
            end
            
            % Check if next cell is intersection
            nextIsIntersection = roadGrid(nr, nc) == 3;
            
            % Simple intersection rules:
            % 1. Stop at stop lines
            % 2. Wait if another car is at the intersection
            if atStopLine
                % Check if any car is in the intersection
                carInIntersection = false;
                for j = 1:size(allCars, 1)
                    ir = allCars(j, 2);
                    ic = allCars(j, 3);
                    if roadGrid(ir, ic) == 3  % Car is in intersection
                        carInIntersection = true;
                        break;
                    end
                end
                
                if carInIntersection
                    carMoves(i, :) = [r, c, 0]; % Stay in place
                    continue;
                end
            end
            
            % Check for cars ahead to maintain spacing
            carInFront = false;
            for j = 1:size(allCars, 1)
                if i ~= j && allCars(j, 4) == carType  % Same car type/direction
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
            carMoves(i, :) = [-1, -1, -1]; % Mark for removal
        end
    end
    
    % Second pass: apply moves
    for i = 1:size(allCars, 1)
        moveRow = carMoves(i, 1);
        moveCol = carMoves(i, 2);
        shouldMove = carMoves(i, 3);
        carID = allCars(i, 1);
        carType = allCars(i, 4);
        
        % Skip cars that have exited
        if shouldMove == -1
            continue;
        end
        
        % Check if destination is already occupied
        if occupiedPositions(moveRow, moveCol) == 0
            newGrid(moveRow, moveCol) = carType;
            newCarIDs(moveRow, moveCol) = carID;
            occupiedPositions(moveRow, moveCol) = 1;
        else
            % Try original position as backup
            r = allCars(i, 2);
            c = allCars(i, 3);
            
            if occupiedPositions(r, c) == 0
                newGrid(r, c) = carType;
                newCarIDs(r, c) = carID;
                occupiedPositions(r, c) = 1;
            end
            % If no position available, car is lost (simplification)
        end
    end
    
    % Update grid for next iteration
    grid = newGrid;
    carIDs = newCarIDs;
    
    % Spawn new cars at edges with two-way logic
    % Left edge - right-moving cars on upper lane
    for r = centerRow-1:centerRow-1
        if roadGrid(r, 1) == 1 && rand < carSpawnRate && grid(r, 1) == 0
            grid(r, 1) = 1; % Right-moving car
            carIDs(r, 1) = nextCarID;
            nextCarID = nextCarID + 1;
        end
    end
    
    % Right edge - left-moving cars on lower lane
    for r = centerRow:centerRow
        if roadGrid(r, gridSize(2)) == 1 && rand < carSpawnRate && grid(r, gridSize(2)) == 0
            grid(r, gridSize(2)) = -1; % Left-moving car
            carIDs(r, gridSize(2)) = nextCarID;
            nextCarID = nextCarID + 1;
        end
    end
    
    % Top edge - down-moving cars on left lane
    for c = centerCol-1:centerCol-1
        if roadGrid(1, c) == 2 && rand < carSpawnRate && grid(1, c) == 0
            grid(1, c) = 2; % Down-moving car
            carIDs(1, c) = nextCarID;
            nextCarID = nextCarID + 1;
        end
    end
    
    % Bottom edge - up-moving cars on right lane
    for c = centerCol:centerCol
        if roadGrid(gridSize(1), c) == 2 && rand < carSpawnRate && grid(gridSize(1), c) == 0
            grid(gridSize(1), c) = -2; % Up-moving car
            carIDs(gridSize(1), c) = nextCarID;
            nextCarID = nextCarID + 1;
        end
    end
    
    % Update visualization with cars
    for r = 1:gridSize(1)
        for c = 1:gridSize(2)
            if grid(r, c) ~= 0
                carType = grid(r, c);
                
                % Apply colors based on direction
                if abs(carType) == 1  % Horizontal movement
                    visualGrid(r, c) = 5; % White
                else  % Vertical movement
                    visualGrid(r, c) = 6; % Blue
                end
            end
        end
    end
    
    % Check for 
    collisionCount = 0;
    for r = 1:gridSize(1)
        for c = 1:gridSize(2)
            if grid(r, c) ~= 0
                count = 0;
                for dr = -1:1
                    for dc = -1:1
                        nr = r + dr;
                        nc = c + dc;
                        if nr >= 1 && nr <= gridSize(1) && nc >= 1 && nc <= gridSize(2) && grid(nr, nc) ~= 0
                            count = count + 1;
                        end
                    end
                end
                
                if count > 1
                    visualGrid(r, c) = 7; % Mark collision
                    collisionCount = collisionCount + 1;
                end
            end
        end
    end
    
    set(h, 'CData', visualGrid);
    
    statusStr = sprintf('Time: %d/%d sec | Cars: %d | Passed: %d (%.1f%%) | : %d', ...
        t, simTime);
    title(statusStr);
    
    drawnow;
    disp(grid);
    pause(0.6); % Animation speed
end