% This program aims to create a traffic flow simulator

% Version 5 adds support for two-way roads with cars moving in both directions
% Black = road/empty space, White = car, Green/Red = traffic light
% Blue = car moving in opposite direction
clear; clc; close all;

% Inputs
preset = input("Do you want to load a preset? (Y or N) ", "s");

if(preset == "N")
    laneNum = input("Number of lanes: ");
    laneLength = input("Length of the lane in metres: ");
    numCarsPerMin = input("Number of cars per minute (for each direction): ");
    simTime = input("Simulation time (seconds): ");
    
    carSpawnRate = numCarsPerMin / 60;

    fprintf('Define your custom road shape (1 for road, 0 for no road):\n');
    roadGrid = zeros(laneNum, laneLength);
    for i = 1:laneNum
        rowInput = input(['Lane ', num2str(i), ' (', num2str(laneLength), ' digits of 0/1): '], 's');
        for j = 1:laneLength
            roadGrid(i, j) = rowInput(j) == '1';
        end
    end
    
    % Ask for direction of each lane
    direction = zeros(laneNum, 1);
    for i = 1:laneNum
        dirInput = input(['Direction for lane ', num2str(i), ' (1 for right, -1 for left): ']);
        direction(i) = dirInput;
    end
else
    laneNum = 4;
    laneLength = 20;
    numCarsPerMin = 30;
    simTime = 30;

    carSpawnRate = numCarsPerMin / 60;

    roadGrid = ones(laneNum, laneLength); % All road for preset
    
    % Set directions (alternating lanes)
    direction = ones(laneNum, 1);
    for i = 2:2:laneNum
        direction(i) = -1; % Left direction
    end
end

% Traffic light settings
lightCol = input("Traffic light column position (e.g., 5): ");
greenDuration = input("How long should the light stay GREEN (seconds): ");
redDuration = input("How long should the light stay RED (seconds): ");
lightCycle = greenDuration + redDuration;

% Initialize the grid
grid = zeros(laneNum, laneLength); % 0 = empty, 1 = car moving right, -1 = car moving left

% Custom colormap
cmap = [
    0 0 0;       % 1: background
    0.2 0.2 0.2; % 2: road
    1 1 1;       % 3: car moving right
    0 1 0;       % 4: green light
    1 0 0;       % 5: red light
    0 0 1        % 6: car moving left
];

% Initial image display
visualGrid = ones(laneNum, laneLength); % All background (index 1)
figure;
h = imshow(visualGrid, cmap, 'InitialMagnification', 'fit');
axis off;

for t = 1:simTime
    timeInCycle = mod(t, lightCycle);
    lightGreen = timeInCycle < greenDuration;

    newGrid = zeros(laneNum, laneLength); % Start with empty grid

    % First, handle cars that are at the end of the road
    for i = 1:laneNum
        % For right-moving cars at the end
        if grid(i, laneLength) == 1
            newGrid(i, laneLength) = 0; % Remove car at the end of the lane
        end
        % For left-moving cars at the start
        if grid(i, 1) == -1
            newGrid(i, 1) = 0; % Remove car at the start of the lane
        end
    end

    % Move cars according to their direction
    for i = 1:laneNum
        if direction(i) == 1 % Right-moving lane
            for j = laneLength-1:-1:1
                if grid(i, j) == 1 && roadGrid(i, j+1) == 1 % If there's a car and road ahead
                    % Check if we're at a red light and trying to move into it
                    if (j+1 == lightCol && ~lightGreen)
                        % Don't move - car stays in current position
                        newGrid(i, j) = 1;
                    elseif newGrid(i, j+1) == 0 % Check if next position is empty
                        % Move car forward
                        newGrid(i, j+1) = 1;
                    else
                        % Keep car in current position if next position is occupied
                        newGrid(i, j) = 1;
                    end
                elseif grid(i, j) == 1
                    % Keep car in current position if no road ahead
                    newGrid(i, j) = 1;
                end
            end
        else % Left-moving lane
            for j = 2:laneLength
                if grid(i, j) == -1 && roadGrid(i, j-1) == 1 % If there's a car and road ahead
                    % Check if we're at a red light and trying to move into it
                    if (j-1 == lightCol && ~lightGreen)
                        % Don't move - car stays in current position
                        newGrid(i, j) = -1;
                    elseif newGrid(i, j-1) == 0 % Check if next position is empty
                        % Move car forward
                        newGrid(i, j-1) = -1;
                    else
                        % Keep car in current position if next position is occupied
                        newGrid(i, j) = -1;
                    end
                elseif grid(i, j) == -1
                    % Keep car in current position if no road ahead
                    newGrid(i, j) = -1;
                end
            end
        end
    end

    % Spawn cars at the beginning of the lane if there's space
    for i = 1:laneNum
        if direction(i) == 1 % Right-moving lane
            if rand < carSpawnRate && roadGrid(i, 1) == 1 && newGrid(i, 1) == 0
                newGrid(i, 1) = 1;
            end
        else % Left-moving lane
            if rand < carSpawnRate && roadGrid(i, laneLength) == 1 && newGrid(i, laneLength) == 0
                newGrid(i, laneLength) = -1;
            end
        end
    end

    grid = newGrid;

    % Build the visual grid using color indices
    visualGrid = ones(laneNum, laneLength);        % Start with background (index 1)
    visualGrid(roadGrid == 1) = 2;                 % Road (index 2)
    
    % Right-moving cars (white)
    visualGrid(grid == 1) = 3;
    % Left-moving cars (blue)
    visualGrid(grid == -1) = 6;

    % Traffic lights
    for i = 1:laneNum
        if roadGrid(i, lightCol) == 1
            if lightGreen
                visualGrid(i, lightCol) = 4;       % Green light
            else
                visualGrid(i, lightCol) = 5;       % Red light
            end
        end
    end
    disp(grid)
    set(h, 'CData', visualGrid);
    title(sprintf("Time: %d sec | Light: %s", t, ternary(lightGreen, 'GREEN', 'RED')));
    drawnow;
    pause(0.6);
end

% Ternary helper function
function out = ternary(condition, trueVal, falseVal)
    if condition
        out = trueVal;
    else
        out = falseVal;
    end
end