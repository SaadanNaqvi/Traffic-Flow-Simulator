% This program aims to create a traffic flow simulator

% Version 3 updates the dispay using the imshow() function and it also
% allows the user to define a custom road shape by editing a binary matrix

% Black for road/empty space, Red for car 

clear;
clc;
close all;

% Reading user input
laneNum = input("Number of lanes: ");
laneLength = input("Length of the lane in metres: ");
numCars = input("Average number of cars per minute: ");
simTime = input("Simulation time (seconds): ");

% Define the empty road
fprintf("Use 0's and 1's to create your own custom road shape! (0 for no road, 1 for road)\n")
roadGrid = zeros(laneNum, laneLength);

% Let the user input the shape of the road
for i = 1:laneNum
    rowInput = input(['Lane ', num2str(i), ' (', num2str(laneLength), ' digits of 0/1): '], 's');
    % Converting the string input into a numerical array using double,
    % which ensures its a numeric array (ASCII number)
    roadGrid(i, :) = double(rowInput - '0'); % Uses ASCII number of 0 to be subtracted from from ASCII numbers of user input (0's and 1's)
end

% Converting cars/min to cars/second
carSpawn = numCars/60;


% Creating the grid for the roads using a vector
grid = zeros(laneNum, laneLength);

% Setting up the simulation scene using imshow() function
a = imshow(grid, 'InitialMagnification', 'fit');
colormap([0 0 0; 1 0 0]); % Black for road, Red for cars
axis off;
title('Traffic Flow Simulation');

% Simulation Loop
for t=1:simTime
    % Shifting all the cars one metre forward and then removing them at the end.
    for i = 1:laneNum
        if any(grid(i, :)) % If there are cars in the lane
            % Shift cars forward only if the next position is road
            newGrid = zeros(1, laneLength);
            for j = laneLength:-1:2 % Move cars from right to left
                if grid(i, j-1) == 1 && roadGrid(i, j) == 1 % Move if road exists
                    newGrid(j) = 1;
                end
            end
            grid(i, :) = newGrid;
        end
    end

    % Spawn new cars randomly
    for i=1:laneNum
        if rand < carSpawn && roadGrid(i, 1) == 1
            grid(i, 1) = 1;
        end
    end

    % Updating display
    disp(grid)
    set(a, 'CData', grid); % Update the figure
    title(['Time: ', num2str(t)]);
    drawnow;
    pause(0.8) % Pause for better animation
end

